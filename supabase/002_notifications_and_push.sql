-- ============================================================================
-- 002 — Notifications + push device tokens
-- ----------------------------------------------------------------------------
-- Adds:
--   • notifications table (in-app inbox, drives bell icon + Sheet)
--   • device_tokens table (per-device APNs/FCM tokens for push)
--   • Triggers that fan out notification rows automatically when:
--        - someone follows you (friendships INSERT)
--        - someone reacts/comments on your rating (reactions INSERT)
--        - someone tags you in played_with on a rating (ratings INSERT/UPDATE)
--   • RLS so each user only sees their own notifications + tokens
--   • Realtime publication of notifications (drives live bell updates)
--
-- Run order: AFTER 001_initial_schema.sql is in place (depends on users,
-- friendships, reactions, ratings).
-- ============================================================================

-- ── NOTIFICATIONS ──────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,  -- recipient
  type text not null check (type in ('follow','reaction','comment','tag')),
  actor_id uuid references public.users(id) on delete cascade,           -- who triggered it (nullable if user deleted)
  course_id integer,
  sub_name text,
  emoji text,
  text text,
  read boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_notifications_user_created
  on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_user_unread
  on public.notifications(user_id) where read = false;

alter table public.notifications enable row level security;

-- Recipient can read + update (mark-read) their own notifications
drop policy if exists "notifications readable to recipient" on public.notifications;
create policy "notifications readable to recipient"
  on public.notifications for select
  using (auth.uid() = user_id);

drop policy if exists "notifications updatable by recipient" on public.notifications;
create policy "notifications updatable by recipient"
  on public.notifications for update
  using (auth.uid() = user_id);

drop policy if exists "notifications deletable by recipient" on public.notifications;
create policy "notifications deletable by recipient"
  on public.notifications for delete
  using (auth.uid() = user_id);

-- Inserts come from triggers (security definer); no INSERT policy needed for clients.

-- Realtime: bell icon updates live when triggers fire
alter publication supabase_realtime add table public.notifications;

-- ── DEVICE TOKENS (push) ───────────────────────────────────────────────────
create table if not exists public.device_tokens (
  user_id uuid not null references public.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios','android')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (user_id, token)
);

create index if not exists idx_device_tokens_user
  on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

-- Each user manages only their own tokens
drop policy if exists "device_tokens own only" on public.device_tokens;
create policy "device_tokens own only"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ── TRIGGER FUNCTIONS ──────────────────────────────────────────────────────

-- Follow → notify the followee
create or replace function public.notify_on_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications(user_id, type, actor_id)
  values (new.followee_id, 'follow', new.follower_id);
  return new;
end;
$$;

drop trigger if exists trg_notify_on_follow on public.friendships;
create trigger trg_notify_on_follow
  after insert on public.friendships
  for each row execute function public.notify_on_follow();

-- Reaction (emoji or comment) → notify the rating's owner
-- Uses 'comment' type when text is non-null, 'reaction' when only emoji.
create or replace function public.notify_on_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Don't notify yourself (self-reaction is allowed by policy but shouldn't ping)
  if new.user_id = new.target_user_id then
    return new;
  end if;
  insert into public.notifications(user_id, type, actor_id, course_id, sub_name, emoji, text)
  values (
    new.target_user_id,
    case when nullif(new.text, '') is not null then 'comment' else 'reaction' end,
    new.user_id,
    new.course_id,
    new.sub_name,
    new.emoji,
    new.text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_on_reaction on public.reactions;
create trigger trg_notify_on_reaction
  after insert on public.reactions
  for each row execute function public.notify_on_reaction();

-- Played-with tag → notify each tagged user (excluding the rater themselves).
-- Fires on INSERT and on UPDATE (when a user edits their rating to add new tags).
-- We compare new.played_with vs old.played_with on UPDATE so re-saving the same
-- rating doesn't spam notifications.
create or replace function public.notify_on_tag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tagged jsonb;
  prev jsonb;
  uid uuid;
begin
  tagged := coalesce(new.played_with, '[]'::jsonb);
  if tg_op = 'UPDATE' then
    prev := coalesce(old.played_with, '[]'::jsonb);
  else
    prev := '[]'::jsonb;
  end if;

  if jsonb_array_length(tagged) = 0 then
    return new;
  end if;

  -- For each new tag (in tagged but not in prev), fan out a notification.
  for uid in
    select distinct (value::text)::uuid
    from jsonb_array_elements_text(tagged) as t(value)
    where t.value <> ''
      and not (prev ? t.value)
  loop
    if uid <> new.user_id then
      insert into public.notifications(user_id, type, actor_id, course_id, sub_name)
      values (uid, 'tag', new.user_id, new.course_id, new.sub_name);
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_on_tag on public.ratings;
create trigger trg_notify_on_tag
  after insert or update of played_with on public.ratings
  for each row execute function public.notify_on_tag();

-- ── DEVICE TOKENS updated_at trigger ───────────────────────────────────────
drop trigger if exists device_tokens_updated_at on public.device_tokens;
create trigger device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();
