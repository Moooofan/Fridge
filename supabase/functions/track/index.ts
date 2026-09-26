// Edge Function: analytics events + crash reports ingestion.
//
// POST body (JSON):
//   Events (default, `kind` omitted or "events"):
//     { install_id, app_version?, os_version?, device_model?,
//       events: [{ event, props?, ts? }, ...] }   // 1..50 events, body <= 64 KB
//   Crash / non-fatal report (`kind: "crash"`):
//     { kind: "crash", install_id, app_version?, os_version?, payload }
//
// Auth: ["user", "publishable"] — a signed-in caller's Supabase JWT attaches
// user_id (see ctx.userClaims.id below); a guest falls back to the
// publishable/anon key in the `apikey` header. Inserts always go through
// ctx.supabaseAdmin (service role), since analytics_events / crash_reports
// have RLS enabled with no policies for anon/authenticated — see
// supabase/migrations/20260926102642_analytics.sql.
//
// Event names and per-event prop keys are validated against an allowlist
// that mirrors Fridge/Services/Analytics.swift's `AnalyticsEvent` enum —
// unknown events are rejected, unknown prop keys are silently stripped, so
// a client bug can never widen what gets stored server-side.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { SupabaseContext } from "@supabase/server";

const MAX_BODY_BYTES = 64 * 1024; // 64 KB
const MAX_EVENTS_PER_BATCH = 50;
const MAX_CRASH_PAYLOAD_BYTES = 64 * 1024; // 64 KB, matches crash_reports.payload check

// Simple fixed-window rate limit, same mechanism (and table) as the
// openai-chat / openai-vision proxies — see ../_shared/aiProxy.ts — but
// keyed per install (not per user/IP) and with a much higher ceiling since
// this endpoint is meant to absorb frequent small batches.
const RATE_LIMIT_MAX_REQUESTS = 300;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 10 minutes

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Keep in sync with `AnalyticsEvent` in Fridge/Services/Analytics.swift.
// Each entry lists the exact prop keys that event is allowed to carry;
// anything else on the incoming `props` object is dropped before insert.
const EVENT_PROP_ALLOWLIST: Record<string, string[]> = {
  onboarding_complete: [],
  login: ["method"],
  login_skip_guest: [],
  ingredients_added: ["count", "source"],
  recipes_generated: ["dishes", "soups", "source"],
  recipe_viewed: ["from_curated"],
  recipe_favorited: [],
  photo_recognition: ["success", "count"],
  account_deleted: [],
  app_error: ["domain", "code"],
};

interface IncomingEvent {
  event?: string;
  props?: Record<string, unknown>;
  ts?: string;
}

interface TrackRequestBody {
  kind?: "events" | "crash";
  install_id?: string;
  app_version?: string;
  os_version?: string;
  device_model?: string;
  events?: IncomingEvent[];
  payload?: Record<string, unknown>;
}

function jsonError(message: string, status: number): Response {
  return Response.json({ error: { message } }, { status });
}

/** Drops any prop key not in that event's allowlist. Returns `{}` for an unknown event. */
function sanitizeProps(event: string, props: Record<string, unknown> | undefined): Record<string, unknown> {
  const allowed = EVENT_PROP_ALLOWLIST[event];
  if (!allowed || !props || typeof props !== "object") return {};
  const out: Record<string, unknown> = {};
  for (const key of allowed) {
    if (key in props) out[key] = props[key];
  }
  return out;
}

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
    console.error("rate_limits count failed", countError);
    return true; // fail open, same tradeoff as aiProxy.ts
  }
  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    return false;
  }

  const { error: insertError } = await admin.from("rate_limits").insert({ caller_key: callerKey });
  if (insertError) {
    console.error("rate_limits insert failed", insertError);
  }
  return true;
}

async function handleTrackRequest(req: Request, ctx: SupabaseContext): Promise<Response> {
  if (req.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  const rawBody = await req.text();
  if (new TextEncoder().encode(rawBody).length > MAX_BODY_BYTES) {
    return jsonError("Request body too large", 413);
  }

  let body: TrackRequestBody;
  try {
    body = JSON.parse(rawBody) as TrackRequestBody;
  } catch {
    return jsonError("Invalid JSON body", 400);
  }

  if (typeof body.install_id !== "string" || !UUID_RE.test(body.install_id)) {
    return jsonError("`install_id` must be a UUID", 400);
  }

  const userId = ctx.userClaims?.id ?? null;
  const callerKey = `install:${body.install_id}`;
  const allowed = await checkAndRecordRateLimit(ctx.supabaseAdmin, callerKey);
  if (!allowed) {
    return jsonError("Rate limit exceeded, please try again later", 429);
  }

  const appVersion = typeof body.app_version === "string" ? body.app_version.slice(0, 32) : null;
  const osVersion = typeof body.os_version === "string" ? body.os_version.slice(0, 32) : null;
  const deviceModel = typeof body.device_model === "string" ? body.device_model.slice(0, 64) : null;

  if (body.kind === "crash") {
    if (!body.payload || typeof body.payload !== "object") {
      return jsonError("`payload` is required for kind \"crash\"", 400);
    }
    const payloadJSON = JSON.stringify(body.payload);
    if (new TextEncoder().encode(payloadJSON).length > MAX_CRASH_PAYLOAD_BYTES) {
      return jsonError("`payload` too large", 413);
    }

    const { error } = await ctx.supabaseAdmin.from("crash_reports").insert({
      install_id: body.install_id,
      user_id: userId,
      app_version: appVersion,
      os_version: osVersion,
      payload: body.payload,
    });
    if (error) {
      console.error("crash_reports insert failed", error);
      return jsonError("Failed to store crash report", 500);
    }
    return Response.json({ ok: true }, { status: 200 });
  }

  // Default: batch of analytics events.
  if (!Array.isArray(body.events) || body.events.length === 0) {
    return jsonError("`events` is required and must be a non-empty array", 400);
  }
  if (body.events.length > MAX_EVENTS_PER_BATCH) {
    return jsonError(`Too many events in one batch (max ${MAX_EVENTS_PER_BATCH})`, 400);
  }

  const rows: Record<string, unknown>[] = [];
  for (const item of body.events) {
    const eventName = item?.event;
    if (typeof eventName !== "string" || !(eventName in EVENT_PROP_ALLOWLIST)) {
      return jsonError(`Unknown event: ${String(eventName)}`, 400);
    }
    rows.push({
      install_id: body.install_id,
      user_id: userId,
      event: eventName,
      props: sanitizeProps(eventName, item.props),
      app_version: appVersion,
      os_version: osVersion,
      device_model: deviceModel,
    });
  }

  const { error } = await ctx.supabaseAdmin.from("analytics_events").insert(rows);
  if (error) {
    console.error("analytics_events insert failed", error);
    return jsonError("Failed to store events", 500);
  }

  return Response.json({ ok: true, inserted: rows.length }, { status: 200 });
}

export default {
  fetch: withSupabase({ auth: ["user", "publishable"] }, handleTrackRequest),
};
