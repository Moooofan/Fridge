// Edge Function: OpenAI Chat Completions proxy (fridge-photo ingredient
// recognition).
//
// Same request/response shape and same OpenAI endpoint as `openai-chat` —
// vision here is just a chat completion whose `messages` contain
// `image_url` content parts, so it reuses the identical shared handler
// (../_shared/aiProxy.ts) rather than duplicating the proxy/rate-limit
// logic. Kept as a separate function (instead of a `kind` field on one
// function) to match the iOS client's two distinct call sites
// (`OpenAIService` vs `VisionIngredientService`) and give each its own
// deploy/log/rate-limit surface — see AGENT task notes.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { handleAIProxyRequest } from "../_shared/aiProxy.ts";

export default {
  fetch: withSupabase({ auth: ["user", "publishable"] }, handleAIProxyRequest),
};
