// Edge Function: OpenAI Chat Completions proxy (recipe generation).
//
// POST body: { messages: [system?, { role: "user", content: string }] , ... }.
// The system prompt, model, reasoning_effort, response_format and token cap
// are all fixed/clamped server-side; the OpenAI key never leaves the server.
//
// Auth: `["user", "publishable"]` — a signed-in caller's Supabase JWT
// (Authorization: Bearer <jwt>) is tried first (so rate limiting can key on
// user id); a guest falls back to the publishable/anon key in the `apikey`
// header (guests must still get recipes — see AGENT task notes). See
// ../_shared/aiProxy.ts for the actual proxy/rate-limit logic, shared with
// `openai-vision` since both are the same underlying Chat Completions call.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createAIProxyHandler } from "../_shared/aiProxy.ts";

export default {
  fetch: withSupabase({ auth: ["user", "publishable"] }, createAIProxyHandler("chat")),
};
