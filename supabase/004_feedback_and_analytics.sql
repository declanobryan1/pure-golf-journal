-- 004_feedback_and_analytics.sql
-- Beta feedback collection + lightweight analytics events for TestFlight learnings.
-- Both tables are user-insert-only (no select/update/delete from client).

-- =======================
-- feedback
-- =======================
create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete set null,
  message     text not null check (char_length(message) <= 1000),
  context     jsonb,                              -- {tab, route, ratingsCount, etc.}
  app_version text,                               -- bundle/version when sent
  platform    text,                               -- "ios", "web", "android"
  created_at  timestamptz not null default now()
);

alter table public.feedback enable row level security;

-- Users can insert their own feedback. We never let the client read/update/delete.
drop policy if exists "feedback_insert_own" on public.feedback;
create policy "feedback_insert_own" on public.feedback
  for insert with check (auth.uid() = user_id);

create index if not exists feedback_user_id_idx on public.feedback (user_id);
create index if not exists feedback_created_at_idx on public.feedback (created_at desc);


-- =======================
-- analytics_events
-- =======================
create table if not exists public.analytics_events (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete set null,
  event       text not null,                     -- "onboarding_complete", "first_rating", "tab_friends", etc.
  props       jsonb,                              -- arbitrary event properties
  app_version text,
  platform    text,
  created_at  timestamptz not null default now()
);

alter table public.analytics_events enable row level security;

drop policy if exists "analytics_insert_own" on public.analytics_events;
create policy "analytics_insert_own" on public.analytics_events
  for insert with check (auth.uid() = user_id);

create index if not exists analytics_events_user_id_idx on public.analytics_events (user_id);
create index if not exists analytics_events_event_idx on public.analytics_events (event);
create index if not exists analytics_events_created_at_idx on public.analytics_events (created_at desc);
