// Edge Function: OpenAI Chat Completions proxy (fridge-photo ingredient
// recognition).
//
// Same OpenAI endpoint and shared handler as `openai-chat`
// (../_shared/aiProxy.ts), in "vision" mode: accepts exactly one user message
// with one data: JPEG/PNG image (+ optional short text); the system prompt
// and all generation parameters are fixed server-side.
// Kept as a separate function (instead of a `kind` field on one function)
// to match the iOS client's two distinct call sites (`OpenAIService` vs
// `VisionIngredientService`) and give each its own deploy/log surface — see AGENT task notes.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { createAIProxyHandler } from "../_shared/aiProxy.ts";

export default {
  fetch: withSupabase({ auth: ["user", "publishable"] }, createAIProxyHandler("vision")),
};
