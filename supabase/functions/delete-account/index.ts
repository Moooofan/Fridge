// Edge Function: in-app account deletion (App Store Guideline 5.1.1(v)).
//
// POST, Authorization: Bearer <user access token>. `auth: "user"` means only a
// valid Supabase user JWT is accepted — the publishable/anon key (no user) is
// rejected with 401 by @supabase/server before this handler runs.
//
// Optional JSON body: { "apple_authorization_code": "<fresh SIWA code>" }.
// If present AND the Apple key env vars are configured, the Sign in with Apple
// grant is revoked per Apple's REST API:
//   1. POST https://appleid.apple.com/auth/token  (grant_type=authorization_code)
//      -> refresh_token
//   2. POST https://appleid.apple.com/auth/revoke (token=<refresh_token>,
//      token_type_hint=refresh_token)
// Both form-encoded with client_id + client_secret (ES256 JWT: iss=team id,
// sub=client id, aud=https://appleid.apple.com, exp <= 15777000 s / 6 months).
// Source: developer.apple.com/documentation/signinwithapplerestapi/
//   generate-and-validate-tokens, revoke-tokens, and "Creating a client secret".
//
// Then deletes the user's rows in public tables (rate_limits keyed by
// `user:<id>`; analytics_events / crash_reports by user_id) and finally the auth
// user via the admin API (ctx.supabaseAdmin uses the project's secret key,
// which Supabase injects into Edge Functions by default).
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import type { SupabaseContext } from "@supabase/server";
import { importPKCS8, SignJWT } from "jose";

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const APPLE_AUDIENCE = "https://appleid.apple.com";
// Apple rejects exp more than 15777000 s in the future; we only need minutes.
const CLIENT_SECRET_TTL_SECONDS = 5 * 60;

interface DeleteAccountBody {
  apple_authorization_code?: string;
}

type AppleRevokeResult =
  | { revoked: true }
  | { revoked: false; reason: string };

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

async function makeAppleClientSecret(
  teamId: string,
  keyId: string,
  clientId: string,
  privateKeyPem: string,
): Promise<string> {
  // Secrets set via `supabase secrets set` often carry literal "\n".
  const pem = privateKeyPem.includes("\\n") ? privateKeyPem.replace(/\\n/g, "\n") : privateKeyPem;
  const key = await importPKCS8(pem.trim(), "ES256");
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setSubject(clientId)
    .setAudience(APPLE_AUDIENCE)
    .setIssuedAt(now)
    .setExpirationTime(now + CLIENT_SECRET_TTL_SECONDS)
    .sign(key);
}

async function revokeAppleGrant(authorizationCode: string): Promise<AppleRevokeResult> {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APPLE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY");
  const clientId = Deno.env.get("APPLE_CLIENT_ID");
  if (!teamId || !keyId || !privateKey || !clientId) {
    return { revoked: false, reason: "apple_key_not_configured" };
  }

  let clientSecret: string;
  try {
    clientSecret = await makeAppleClientSecret(teamId, keyId, clientId, privateKey);
  } catch (error) {
    console.error("apple client_secret signing failed", error);
    return { revoked: false, reason: "apple_client_secret_failed" };
  }

  // Native iOS authorization: no redirect_uri was used, so none is sent.
  const tokenResponse = await fetch(APPLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenResponse.ok) {
    console.error("apple token exchange failed", tokenResponse.status, await tokenResponse.text());
    return { revoked: false, reason: "apple_token_exchange_failed" };
  }
  const tokenJson = await tokenResponse.json() as { refresh_token?: string; access_token?: string };
  const token = tokenJson.refresh_token ?? tokenJson.access_token;
  const hint = tokenJson.refresh_token ? "refresh_token" : "access_token";
  if (!token) {
    return { revoked: false, reason: "apple_no_token" };
  }

  const revokeResponse = await fetch(APPLE_REVOKE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: hint,
    }),
  });
  if (!revokeResponse.ok) {
    console.error("apple revoke failed", revokeResponse.status, await revokeResponse.text());
    return { revoked: false, reason: "apple_revoke_failed" };
  }
  return { revoked: true };
}

async function handleDeleteAccount(req: Request, ctx: SupabaseContext): Promise<Response> {
  if (req.method !== "POST") {
    return json({ error: { message: "Method not allowed" } }, 405);
  }

  const userId = ctx.userClaims?.id;
  if (!userId) {
    return json({ error: { message: "Unauthorized" } }, 401);
  }

  let body: DeleteAccountBody = {};
  const raw = await req.text();
  if (raw.trim().length > 0) {
    try {
      body = JSON.parse(raw) as DeleteAccountBody;
    } catch {
      return json({ error: { message: "Invalid JSON body" } }, 400);
    }
  }

  // 1. Apple revocation (best effort — never blocks the deletion itself).
  let apple: AppleRevokeResult = { revoked: false, reason: "no_apple_code" };
  const code = typeof body.apple_authorization_code === "string" ? body.apple_authorization_code.trim() : "";
  if (code.length > 0) {
    try {
      apple = await revokeAppleGrant(code);
    } catch (error) {
      console.error("apple revoke threw", error);
      apple = { revoked: false, reason: "apple_revoke_error" };
    }
  }

  // 2. Public-table rows keyed to this user.
  const { error: rateLimitError } = await ctx.supabaseAdmin
    .from("rate_limits")
    .delete()
    .eq("caller_key", `user:${userId}`);
  if (rateLimitError) {
    console.error("rate_limits delete failed", rateLimitError);
    return json({ error: { message: "Failed to delete user data" } }, 500);
  }

  // 2b. Analytics / crash rows tied to this user (tables from
  // *_analytics.sql; FK is ON DELETE SET NULL, so delete them explicitly).
  // Best effort: a table that doesn't exist yet must not block deletion.
  for (const table of ["analytics_events", "crash_reports"]) {
    const { error } = await ctx.supabaseAdmin.from(table).delete().eq("user_id", userId);
    if (error) console.error(`${table} delete failed (ignored)`, error.code, error.message);
  }

  // 3. The auth user itself (hard delete).
  const { error: deleteError } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error("auth admin deleteUser failed", deleteError);
    return json({ error: { message: "Failed to delete account" } }, 500);
  }

  return json(
    apple.revoked
      ? { deleted: true, appleRevoked: true }
      : { deleted: true, appleRevoked: false, reason: apple.reason },
  );
}

export default {
  fetch: withSupabase({ auth: "user" }, handleDeleteAccount),
};
