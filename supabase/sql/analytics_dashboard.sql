-- Ready-made reporting queries for public.analytics_events / crash_reports.
-- Run with a service-role/dashboard connection (SQL editor, `psql`, etc.) —
-- there are no SELECT policies for anon/authenticated, by design (see
-- supabase/migrations/20260926102642_analytics.sql).

-- 1) Daily active installs (distinct install_id per day, any event).
select
  date_trunc('day', created_at) as day,
  count(distinct install_id) as active_installs
from public.analytics_events
group by 1
order by 1 desc;

-- 2) Funnel: onboarding_complete -> recipes_generated -> recipe_favorited
--    (distinct installs reaching each step, all-time).
with steps as (
  select install_id,
    max((event = 'onboarding_complete')::int) as did_onboarding,
    max((event = 'recipes_generated')::int) as did_generate,
    max((event = 'recipe_favorited')::int) as did_favorite
  from public.analytics_events
  group by install_id
)
select
  sum(did_onboarding) as onboarding_complete,
  sum(case when did_onboarding = 1 then did_generate else 0 end) as recipes_generated,
  sum(case when did_onboarding = 1 and did_generate = 1 then did_favorite else 0 end) as recipe_favorited
from steps;

-- 3) Login method split (counts by props->>'method').
select
  props ->> 'method' as method,
  count(*) as logins
from public.analytics_events
where event = 'login'
group by 1
order by 2 desc;

-- 4) AI vs local_fallback vs local ratio for recipe generation.
select
  props ->> 'source' as source,
  count(*) as count
from public.analytics_events
where event = 'recipes_generated'
group by 1
order by 2 desc;

-- 5) Crash count per app_version.
select
  app_version,
  count(*) as crash_reports
from public.crash_reports
group by 1
order by 1 desc;
