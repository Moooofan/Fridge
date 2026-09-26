-- Analytics + crash reporting storage for the `track` Edge Function.
--
-- Both tables have RLS enabled with NO policies: anon/authenticated callers
-- are denied entirely (same pattern as public.rate_limits, see
-- 20260911060707_rate_limits.sql). Only the `track` Edge Function, using
-- ctx.supabaseAdmin (service role, RLS-exempt), may insert rows. There are
-- intentionally no SELECT policies either — reporting happens via the SQL
-- in supabase/sql/analytics_dashboard.sql run with a service-role/dashboard
-- connection, never from the client.

create table if not exists public.analytics_events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  install_id uuid not null,
  user_id uuid references auth.users (id) on delete set null,
  event text not null check (length(event) <= 64),
  props jsonb not null default '{}'::jsonb check (pg_column_size(props) <= 2048),
  app_version text,
  os_version text,
  device_model text
);

create index if not exists analytics_events_event_created_at_idx
  on public.analytics_events (event, created_at);
create index if not exists analytics_events_created_at_idx
  on public.analytics_events (created_at);

alter table public.analytics_events enable row level security;
-- Intentionally no policies — see header comment.

create table if not exists public.crash_reports (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  install_id uuid not null,
  user_id uuid references auth.users (id) on delete set null,
  app_version text,
  os_version text,
  -- MXDiagnosticPayload JSON (crash) or a lightweight {domain, code} object
  -- (non-fatal `app_error` events) — see Fridge/Services/Analytics.swift.
  payload jsonb not null check (pg_column_size(payload) <= 65536)
);

create index if not exists crash_reports_created_at_idx
  on public.crash_reports (created_at);
create index if not exists crash_reports_app_version_idx
  on public.crash_reports (app_version);

alter table public.crash_reports enable row level security;
-- Intentionally no policies — see header comment.
