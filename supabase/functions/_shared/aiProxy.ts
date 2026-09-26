// Shared OpenAI Chat Completions proxy used by both `openai-chat` and
// `openai-vision`. Both endpoints hit the same OpenAI Chat Completions API —
// "vision" is just a chat completion whose `messages` contain `image_url`
// content parts — so one handler covers both; the two directories exist only
// to match the iOS client's two call sites (`EdgeAIClient`), and both are
// thin `withSupabase(...)` wrappers around this file.
import type { SupabaseContext } from "@supabase/server";

const OPENAI_CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions";

// Model is fixed server-side — the client never gets to choose it.
const MODEL = "gpt-5.6-luna";

// Reject oversized / abusive payloads before they reach OpenAI.
const MAX_BODY_BYTES = 200 * 1024; // 200 KB
const MAX_IMAGES = 3;

// Simple fixed-window rate limit, enforced via the `rate_limits` table
// (service-role only, see supabase/migrations/*_rate_limits.sql).
const RATE_LIMIT_MAX_REQUESTS = 20;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 10 minutes

interface ChatMessage {
  role: string;
  content: unknown;
}

interface ProxyRequestBody {
  messages?: ChatMessage[];
  reasoning_effort?: string;
  max_completion_tokens?: number;
  response_format?: Record<string, unknown>;
}

function jsonError(message: string, status: number): Response {
  return Response.json({ error: { message } }, { status });
}

/** Counts `image_url` content parts across all messages. */
function countImageParts(messages: ChatMessage[]): number {
  let count = 0;
  for (const message of messages) {
    const content = message?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      if (part && typeof part === "object" && (part as { type?: unknown }).type === "image_url") {
        count += 1;
      }
    }
  }
  return count;
}

/**
 * Fixed-window rate limit keyed by caller. Not perfectly atomic under heavy
 * concurrency (count-then-insert), which is an acceptable tradeoff for a
 * small personal-project proxy — see task notes ("keep it simple and
 * correct").
 */
async function checkAndRecordRateLimit(
  admin: SupabaseContext["supabaseAdmin"],
  callerKey: string,
): Promise<boolean> {
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString();

  const { count, error: countError } = await admin
    .from("rate_limits")
    .select("id", { count: "exact", head: true })
    .eq("caller_key", callerKey)
    .gte("created_at", windowStart);

  if (countError) {
    // Fail open rather than blocking recipe generation on a DB hiccup, but
    // log so it's visible in `supabase functions logs`.
    console.error("rate_limits count failed", countError);
    return true;
  }

  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    return false;
  }

  const { error: insertError } = await admin
    .from("rate_limits")
    .insert({ caller_key: callerKey });
  if (insertError) {
    console.error("rate_limits insert failed", insertError);
  }

  return true;
}

function callerKeyFor(req: Request, ctx: SupabaseContext): string {
  if (ctx.userClaims?.id) {
    return `user:${ctx.userClaims.id}`;
  }
  const forwardedFor = req.headers.get("x-forwarded-for");
  const ip = forwardedFor?.split(",")[0]?.trim();
  return `ip:${ip && ip.length > 0 ? ip : "unknown"}`;
}

export async function handleAIProxyRequest(req: Request, ctx: SupabaseContext): Promise<Response> {
  if (req.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return jsonError("Request body too large", 413);
  }

  let body: ProxyRequestBody;
  try {
    body = JSON.parse(rawBody) as ProxyRequestBody;
  } catch {
    return jsonError("Invalid JSON body", 400);
  }

  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return jsonError("`messages` is required and must be a non-empty array", 400);
  }
  if (countImageParts(messages) > MAX_IMAGES) {
    return jsonError(`Too many images in request (max ${MAX_IMAGES})`, 400);
  }

  const callerKey = callerKeyFor(req, ctx);
  const allowed = await checkAndRecordRateLimit(ctx.supabaseAdmin, callerKey);
  if (!allowed) {
    return jsonError("Rate limit exceeded, please try again later", 429);
  }

  const openAIKey = Deno.env.get("OPENAI_API_KEY");
  if (!openAIKey) {
    console.error("OPENAI_API_KEY secret is not set");
    return jsonError("Server not configured", 500);
  }

  const forwardBody: Record<string, unknown> = {
    model: MODEL,
    messages,
  };
  if (body.reasoning_effort !== undefined) forwardBody.reasoning_effort = body.reasoning_effort;
  if (body.max_completion_tokens !== undefined) forwardBody.max_completion_tokens = body.max_completion_tokens;
  if (body.response_format !== undefined) forwardBody.response_format = body.response_format;

  const openaiResponse = await fetch(OPENAI_CHAT_COMPLETIONS_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(forwardBody),
  });

  // Passthrough: return OpenAI's JSON body and status code verbatim so the
  // iOS client can reuse its existing OpenAIResponse decoding + error
  // messages unchanged.
  const responseText = await openaiResponse.text();
  return new Response(responseText, {
    status: openaiResponse.status,
    headers: { "Content-Type": "application/json" },
  });
}
