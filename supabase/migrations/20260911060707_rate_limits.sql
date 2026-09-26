-- Rate-limit ledger for the openai-chat / openai-vision Edge Functions.
-- One row per accepted request. RLS is enabled with NO policies: only the
-- service role (used internally by the Edge Functions via
-- ctx.supabaseAdmin, which bypasses RLS) can read or write this table —
-- anon and authenticated callers are denied entirely, they never touch it
-- directly.
create table if not exists public.rate_limits (
  id bigint generated always as identity primary key,
  caller_key text not null,
  created_at timestamptz not null default now()
);

-- Supports the "count requests for this caller within the last N minutes"
-- query the Edge Functions run on every call.
create index if not exists rate_limits_caller_key_created_at_idx
  on public.rate_limits (caller_key, created_at desc);

alter table public.rate_limits enable row level security;
-- Intentionally no policies: RLS with zero policies denies all access to
-- anon/authenticated roles. Only service_role (RLS-exempt) can touch this
-- table, which is exactly what the Edge Functions use.
