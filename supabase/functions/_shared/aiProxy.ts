// Shared OpenAI Chat Completions proxy used by both `openai-chat` and
// `openai-vision`.
//
// Hardened 2026-09-26: the endpoints accept the public publishable key that
// ships in the app, so they must NOT behave like a general-purpose GPT proxy.
// Therefore:
//   - The system prompt is fixed server-side (any client `system` message is
//     ignored) and only the exact message shapes the iOS app sends are accepted.
//   - reasoning_effort / max_completion_tokens / response_format / model are
//     forced or clamped server-side; every other client field is dropped.
//   - Rate limits: per caller (10-minute window + daily) and a GLOBAL daily cap,
//     all recorded in the existing `rate_limits` table. The limiter fails
//     CLOSED (503) if the database is unavailable.
//
// Request/response shapes stay compatible with the shipped iOS client
// (`EdgeAIClient` + `OpenAIService` / `VisionIngredientService`): the OpenAI
// JSON body and status are passed through on success, and errors use
// `{ "error": { "message": "..." } }`, which the client surfaces verbatim.
import type { SupabaseContext } from "@supabase/server";

const OPENAI_CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions";

// Model is fixed server-side — the client never gets to choose it.
const MODEL = "gpt-5.6-luna";

// ---- Cost / abuse limits (tune here) ----
/** Per-caller fixed window. */
const RATE_LIMIT_MAX_REQUESTS = 20;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
/** Per-caller daily cap (Asia/Taipei calendar day). */
const CALLER_DAILY_MAX_REQUESTS = 60;
/** Global daily cap across ALL callers (Asia/Taipei calendar day). */
const GLOBAL_DAILY_MAX_REQUESTS = 2000;

const CHAT_MAX_BODY_BYTES = 64 * 1024;
const CHAT_MAX_USER_CHARS = 12_000;
const CHAT_DEFAULT_MAX_COMPLETION_TOKENS = 6000;
const CHAT_MAX_COMPLETION_TOKENS = 6000;

const VISION_MAX_TEXT_CHARS = 500;
const VISION_MAX_IMAGE_BYTES = 1.5 * 1024 * 1024; // decoded
const VISION_MAX_BODY_BYTES = Math.ceil(VISION_MAX_IMAGE_BYTES * 4 / 3) + 64 * 1024;
const VISION_DEFAULT_MAX_COMPLETION_TOKENS = 800;
const VISION_MAX_COMPLETION_TOKENS = 800;

// ---- Canonical system prompts (copied verbatim from the iOS app) ----
// Fridge/Services/OpenAIService.swift `systemPrompt` (Swift `\` line
// continuations => the lines are joined with no newline).
const CHAT_SYSTEM_PROMPT =
  "你是擁有 20 年經驗的台灣家常菜主廚。你的任務是依使用者冰箱裡的食材設計菜單。下方提供「專業廚師參考食譜庫」（真實廚師食譜）。規則：" +
  "(1) 只要參考庫有合適的食譜，必須以它為基礎：菜名、調味比例、步驟順序與火候都要沿用，可依人數等比例調整份量、可省略使用者沒有的次要配料；" +
  "(2) 每道從參考庫改編的食譜，在 source 欄填入該參考食譜的來源字串（原樣），並在 reason 說明用了哪些冰箱食材；" +
  "(3) 參考庫沒有合適食譜時才自行設計，此時 source 填 null，且必須是台灣常見家常作法，份量要具體（g/大匙/小匙），不得發明不存在的菜；" +
  "(4) 不得使用使用者沒有、又無法省略的主食材；" +
  "(5) 「使用者現有食材」清單中的每一項都必須至少出現在某一道菜或湯的 ingredients 裡，並盡量平均分散到不同菜色（不要全部塞進同一道），除非該項食材明顯不可能入菜（例如調味料以外的非食用品）；" +
  "(6) 只輸出 JSON。";

// Fridge/Services/VisionIngredientService.swift `systemPrompt`.
const VISION_SYSTEM_PROMPT =
  '你是食材辨識助手，辨識照片中所有可食用的食材，用台灣常見名稱（例如 高麗菜、番茄、雞蛋、豬絞肉、青蔥、蒜頭），忽略調味料罐與包裝文字以外的物件，不確定的不要列。只輸出 JSON：{"ingredients":[{"name":"高麗菜","confidence":0.9}]}';

export type AIProxyKind = "chat" | "vision";

type ChatMessage = { role: string; content: unknown };

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

function jsonError(message: string, status: number): Response {
  return Response.json({ error: { message } }, { status });
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Returns the non-system messages; system messages from the client are ignored. */
function nonSystemMessages(body: Record<string, unknown>): ChatMessage[] {
  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 4) {
    throw new HttpError(400, "請求格式錯誤：messages 不正確");
  }
  const rest: ChatMessage[] = [];
  for (const m of messages) {
    if (!isPlainObject(m) || typeof m.role !== "string") {
      throw new HttpError(400, "請求格式錯誤：messages 不正確");
    }
    if (m.role === "system") continue;
    rest.push({ role: m.role, content: m.content });
  }
  if (rest.length !== 1 || rest[0].role !== "user") {
    throw new HttpError(400, "請求格式錯誤：只接受一則使用者訊息");
  }
  return rest;
}

function clampTokens(value: unknown, fallback: number, max: number): number {
  const n = typeof value === "number" && Number.isInteger(value) && value > 0 ? value : fallback;
  return Math.min(n, max);
}

function buildChatMessages(body: Record<string, unknown>): unknown[] {
  const [user] = nonSystemMessages(body);
  if (typeof user.content !== "string" || user.content.trim().length === 0) {
    throw new HttpError(400, "請求格式錯誤：使用者訊息必須是文字");
  }
  if (user.content.length > CHAT_MAX_USER_CHARS) {
    throw new HttpError(400, "請求內容過長，請減少食材數量後再試");
  }
  return [
    { role: "system", content: CHAT_SYSTEM_PROMPT },
    { role: "user", content: user.content },
  ];
}

const IMAGE_DATA_URL = /^data:image\/(jpeg|jpg|png);base64,([A-Za-z0-9+/]+={0,2})$/;

function buildVisionMessages(body: Record<string, unknown>): unknown[] {
  const [user] = nonSystemMessages(body);
  if (!Array.isArray(user.content) || user.content.length === 0 || user.content.length > 2) {
    throw new HttpError(400, "請求格式錯誤：辨識請求內容不正確");
  }
  let text: string | undefined;
  let imageURL: string | undefined;
  for (const part of user.content) {
    if (!isPlainObject(part)) throw new HttpError(400, "請求格式錯誤：辨識請求內容不正確");
    if (part.type === "text" && text === undefined) {
      if (typeof part.text !== "string" || part.text.length > VISION_MAX_TEXT_CHARS) {
        throw new HttpError(400, "請求格式錯誤：文字說明過長");
      }
      text = part.text;
    } else if (part.type === "image_url" && imageURL === undefined) {
      const url = isPlainObject(part.image_url) ? part.image_url.url : undefined;
      const match = typeof url === "string" ? IMAGE_DATA_URL.exec(url) : null;
      if (!url || !match) {
        throw new HttpError(400, "請求格式錯誤：只接受 JPEG／PNG 圖片");
      }
      const b64 = match[2];
      const padding = b64.endsWith("==") ? 2 : b64.endsWith("=") ? 1 : 0;
      const decodedBytes = Math.floor(b64.length * 3 / 4) - padding;
      if (decodedBytes > VISION_MAX_IMAGE_BYTES) {
        throw new HttpError(413, "圖片太大，請換一張較小的照片");
      }
      imageURL = url as string;
    } else {
      throw new HttpError(400, "請求格式錯誤：辨識請求內容不正確");
    }
  }
  if (imageURL === undefined) {
    throw new HttpError(400, "請求格式錯誤：缺少圖片");
  }
  const parts: unknown[] = [];
  if (text !== undefined && text.length > 0) parts.push({ type: "text", text });
  parts.push({ type: "image_url", image_url: { url: imageURL, detail: "low" } });
  return [
    { role: "system", content: VISION_SYSTEM_PROMPT },
    { role: "user", content: parts },
  ];
}

// ---- Caller identity ----
function clientIP(req: Request): string {
  // Supabase's gateway sits behind Cloudflare; `cf-connecting-ip` is set by
  // Cloudflare and cannot be forged by the client. `x-forwarded-for` CAN be
  // forged: a client-supplied value is kept and the real address is appended,
  // so only the LAST hop is trustworthy.
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const hops = req.headers.get("x-forwarded-for")?.split(",").map((s) => s.trim()).filter(Boolean);
  if (hops && hops.length > 0) return hops[hops.length - 1];
  return "unknown";
}

function callerKeyFor(req: Request, ctx: SupabaseContext): string {
  if (ctx.userClaims?.id) return `user:${ctx.userClaims.id}`;
  return `ip:${clientIP(req)}`;
}

/** Calendar day in Asia/Taipei (UTC+8, no DST), e.g. "2026-09-26". */
function taipeiDate(now = Date.now()): { day: string; startISO: string } {
  const shifted = new Date(now + 8 * 60 * 60 * 1000);
  const day = shifted.toISOString().slice(0, 10);
  const startISO = new Date(Date.parse(`${day}T00:00:00Z`) - 8 * 60 * 60 * 1000).toISOString();
  return { day, startISO };
}

/**
 * Enforces all limits and records the request. Throws HttpError (429 / 503).
 * Not perfectly atomic (count-then-insert) — acceptable at this scale; the
 * caps are cost guards, not exact quotas. Fails CLOSED on any DB error.
 */
async function enforceRateLimits(admin: SupabaseContext["supabaseAdmin"], callerKey: string): Promise<void> {
  const { day, startISO } = taipeiDate();
  const dayKey = `day:${callerKey}:${day}`;
  const globalKey = `global:ai:${day}`;
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString();

  const countRows = (key: string, since: string) =>
    admin.from("rate_limits").select("id", { count: "exact", head: true })
      .eq("caller_key", key).gte("created_at", since);

  const [windowRes, dayRes, globalRes] = await Promise.all([
    countRows(callerKey, windowStart),
    countRows(dayKey, startISO),
    countRows(globalKey, startISO),
  ]);
  for (const res of [windowRes, dayRes, globalRes]) {
    if (res.error || res.count === null || res.count === undefined) {
      console.error("rate_limits count failed", res.error);
      throw new HttpError(503, "服務忙碌，請稍後再試");
    }
  }

  if ((globalRes.count ?? 0) >= GLOBAL_DAILY_MAX_REQUESTS) {
    throw new HttpError(429, "今日 AI 服務使用量已達上限，請明天再試");
  }
  if ((dayRes.count ?? 0) >= CALLER_DAILY_MAX_REQUESTS) {
    throw new HttpError(429, "你今天的 AI 使用次數已達上限，請明天再試");
  }
  if ((windowRes.count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    throw new HttpError(429, "請求太頻繁，請 10 分鐘後再試");
  }

  const { error: insertError } = await admin.from("rate_limits").insert([
    { caller_key: callerKey },
    { caller_key: dayKey },
    { caller_key: globalKey },
    // The project has no generated DB types, so the table's row type is `never`.
  ] as never);
  if (insertError) {
    console.error("rate_limits insert failed", insertError);
    throw new HttpError(503, "服務忙碌，請稍後再試");
  }

  // Retention: the privacy policy says these rows are short-lived. On ~2% of
  // requests, purge anything older than 2 days (limits only look back 1 day).
  // Best-effort: a failure here must never block the user's request.
  if (Math.random() < 0.02) {
    const cutoff = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    const { error: purgeError } = await admin.from("rate_limits").delete().lt("created_at", cutoff);
    if (purgeError) console.error("rate_limits purge failed", purgeError);
  }
}

export function createAIProxyHandler(kind: AIProxyKind) {
  const maxBodyBytes = kind === "chat" ? CHAT_MAX_BODY_BYTES : VISION_MAX_BODY_BYTES;

  return async function handleAIProxyRequest(req: Request, ctx: SupabaseContext): Promise<Response> {
    try {
      if (req.method !== "POST") throw new HttpError(405, "不支援的請求方法");

      const rawBody = await req.text();
      if (new TextEncoder().encode(rawBody).length > maxBodyBytes) {
        throw new HttpError(413, "請求內容過大");
      }

      let body: unknown;
      try {
        body = JSON.parse(rawBody);
      } catch {
        throw new HttpError(400, "請求格式錯誤：不是合法的 JSON");
      }
      if (!isPlainObject(body)) throw new HttpError(400, "請求格式錯誤");

      // Only these fields are forwarded; everything else from the client is dropped.
      const forwardBody = kind === "chat"
        ? {
          model: MODEL,
          messages: buildChatMessages(body),
          reasoning_effort: "low",
          max_completion_tokens: clampTokens(
            body.max_completion_tokens,
            CHAT_DEFAULT_MAX_COMPLETION_TOKENS,
            CHAT_MAX_COMPLETION_TOKENS,
          ),
          response_format: { type: "json_object" },
        }
        : {
          model: MODEL,
          messages: buildVisionMessages(body),
          reasoning_effort: "low",
          max_completion_tokens: clampTokens(
            body.max_completion_tokens,
            VISION_DEFAULT_MAX_COMPLETION_TOKENS,
            VISION_MAX_COMPLETION_TOKENS,
          ),
          response_format: { type: "json_object" },
        };

      await enforceRateLimits(ctx.supabaseAdmin, callerKeyFor(req, ctx));

      const openAIKey = Deno.env.get("OPENAI_API_KEY");
      if (!openAIKey) {
        console.error("OPENAI_API_KEY secret is not set");
        throw new HttpError(500, "伺服器尚未設定完成");
      }

      let openaiResponse: Response;
      try {
        openaiResponse = await fetch(OPENAI_CHAT_COMPLETIONS_URL, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${openAIKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(forwardBody),
        });
      } catch (err) {
        console.error("OpenAI fetch failed", err);
        throw new HttpError(502, "AI 服務暫時無法連線，請稍後再試");
      }

      // Passthrough: OpenAI's JSON body and status verbatim, so the iOS client
      // keeps its existing OpenAIResponse decoding.
      const responseText = await openaiResponse.text();
      return new Response(responseText, {
        status: openaiResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    } catch (err) {
      if (err instanceof HttpError) return jsonError(err.message, err.status);
      console.error("AI proxy unexpected error", err);
      return jsonError("服務忙碌，請稍後再試", 503);
    }
  };
}
