-- ═══════════════════════════════════════════════════════════════════════════
-- Pure Golf Journal — initial schema
-- Run this in Supabase Studio → SQL Editor → New Query → paste → Run
-- Tables, indexes, RLS policies, and realtime publication all in one shot.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ─── Helpers ─────────────────────────────────────────────────────────────────
-- Auto-update `updated_at` on row change
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ═══════════════════════════════════════════════════════════════════════════
-- USERS — profile data, 1:1 with Supabase auth.users via id
-- ═══════════════════════════════════════════════════════════════════════════
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  username text unique not null,
  name text not null,
  profile_photo_url text,
  profile_photo_pos jsonb,
  home_course_id integer,
  self_reported_handicap numeric,
  self_reported_at timestamptz,
  welcome_tour_seen boolean default false,
  is_test_user boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_users_username on public.users(username);
create trigger users_updated_at before update on public.users
  for each row execute function public.set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- FRIENDSHIPS — directional follow graph
-- ═══════════════════════════════════════════════════════════════════════════
create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.users(id) on delete cascade,
  followee_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(follower_id, followee_id),
  check(follower_id <> followee_id)
);

create index idx_friendships_follower on public.friendships(follower_id);
create index idx_friendships_followee on public.friendships(followee_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- RATINGS — main user ratings (incl. multi-course sub_name)
-- ═══════════════════════════════════════════════════════════════════════════
create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_id integer not null,
  sub_name text,                    -- null for single-course properties
  overall numeric not null,         -- 1.0–10.0
  review text,
  tee_name text,
  course_rating numeric,            -- nullable for score-only rounds
  slope integer,
  shot_score integer,
  personal_best integer,
  is_home_course boolean default false,
  is_early boolean default false,   -- baseline rating, low confidence
  first_impression boolean default false,
  impression_label text,
  played_with jsonb default '[]'::jsonb,  -- array of friend user_ids
  photos jsonb default '[]'::jsonb,        -- array of storage URLs
  comparisons jsonb default '[]'::jsonb,
  history jsonb default '[]'::jsonb,
  tee jsonb,                        -- {teeName, rating, slope, source}
  date date,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, course_id, sub_name)  -- one rating per user/course/sub
);

create index idx_ratings_user on public.ratings(user_id);
create index idx_ratings_course on public.ratings(course_id);
create index idx_ratings_user_created on public.ratings(user_id, created_at desc);
create trigger ratings_updated_at before update on public.ratings
  for each row execute function public.set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- IMPORTED_ROUNDS — raw scores (manual entry, batch, quick-log, score-only)
-- ═══════════════════════════════════════════════════════════════════════════
create table public.imported_rounds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_id integer,                -- nullable for unmatched typed-in courses
  course_name text,
  sub_name text,
  score integer not null,
  holes integer default 18,
  course_rating numeric,            -- null for score-only
  slope integer,                    -- null for score-only
  tee_name text,
  source text not null,             -- 'manual' | 'ghin' | 'quick' | 'score-only'
  date date,
  created_at timestamptz default now()
);

create index idx_imported_rounds_user on public.imported_rounds(user_id);
create index idx_imported_rounds_user_date on public.imported_rounds(user_id, date desc);

-- ═══════════════════════════════════════════════════════════════════════════
-- STATUSES — played / bucket-list per course
-- ═══════════════════════════════════════════════════════════════════════════
create table public.statuses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_id integer not null,
  play text not null,               -- 'played' | 'want' | 'none'
  want_subs jsonb default '[]'::jsonb,
  updated_at timestamptz default now(),
  unique(user_id, course_id)
);

create index idx_statuses_user on public.statuses(user_id);
create trigger statuses_updated_at before update on public.statuses
  for each row execute function public.set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- USER_TEES — saved manual tee entries per user/course
-- ═══════════════════════════════════════════════════════════════════════════
create table public.user_tees (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_id integer not null,
  tee_name text not null,
  course_rating numeric not null,
  slope integer not null,
  created_at timestamptz default now(),
  unique(user_id, course_id, tee_name)
);

create index idx_user_tees_user_course on public.user_tees(user_id, course_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- REACTIONS — friend reactions/comments on YOUR ratings
-- (enables the friends-commenting-on-your-ratings feature gap)
-- ═══════════════════════════════════════════════════════════════════════════
create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,        -- who reacted
  target_user_id uuid not null references public.users(id) on delete cascade, -- whose rating
  course_id integer not null,
  sub_name text,
  text text,
  emoji text,
  created_at timestamptz default now(),
  check(user_id <> target_user_id)
);

create index idx_reactions_target on public.reactions(target_user_id, created_at desc);
create index idx_reactions_target_course on public.reactions(target_user_id, course_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- COURSE_REQUESTS — users asking for courses we don't have yet
-- ═══════════════════════════════════════════════════════════════════════════
create table public.course_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_name text not null,
  location text,
  note text,
  status text default 'pending',           -- 'pending' | 'added' | 'declined'
  added_course_id integer,
  source text,                              -- 'scores_row_unmatched' | 'onboarding_home_course' | 'discover_empty_state'
  vote_count integer default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_course_requests_status on public.course_requests(status);
create index idx_course_requests_name_lower on public.course_requests(lower(course_name));
create trigger course_requests_updated_at before update on public.course_requests
  for each row execute function public.set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY — every table locked down by default,
--   then we open up exactly what each policy needs.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.users enable row level security;
alter table public.friendships enable row level security;
alter table public.ratings enable row level security;
alter table public.imported_rounds enable row level security;
alter table public.statuses enable row level security;
alter table public.user_tees enable row level security;
alter table public.reactions enable row level security;
alter table public.course_requests enable row level security;

-- ─── USERS policies ─────────────────────────────────────────────────────────
-- Anyone authenticated can read public profile data (name, username, photo)
-- so we can display friend names without granting full profile access.
create policy "users readable to authenticated"
  on public.users for select
  to authenticated
  using (true);

-- A user can insert / update only their own row
create policy "users insert own row"
  on public.users for insert
  to authenticated
  with check (auth.uid() = id);

create policy "users update own row"
  on public.users for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ─── FRIENDSHIPS policies ───────────────────────────────────────────────────
-- A user can see friendships where they're either side
create policy "friendships visible to participants"
  on public.friendships for select
  to authenticated
  using (auth.uid() = follower_id or auth.uid() = followee_id);

-- A user can create / delete only their own follow rows (where they're the follower)
create policy "friendships insert own follow"
  on public.friendships for insert
  to authenticated
  with check (auth.uid() = follower_id);

create policy "friendships delete own follow"
  on public.friendships for delete
  to authenticated
  using (auth.uid() = follower_id);

-- ─── RATINGS policies ───────────────────────────────────────────────────────
-- A user can read their own ratings + ratings of users they follow
create policy "ratings readable to self and followers"
  on public.ratings for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.friendships f
      where f.follower_id = auth.uid() and f.followee_id = ratings.user_id
    )
  );

create policy "ratings insert own"
  on public.ratings for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "ratings update own"
  on public.ratings for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "ratings delete own"
  on public.ratings for delete
  to authenticated
  using (auth.uid() = user_id);

-- ─── IMPORTED_ROUNDS policies ───────────────────────────────────────────────
-- Private to the owner — friends shouldn't see every round you've ever logged.
create policy "imported_rounds owner only"
  on public.imported_rounds for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── STATUSES policies ──────────────────────────────────────────────────────
-- Visible to self + people you follow (so they can see your bucket list)
create policy "statuses readable to self and followers"
  on public.statuses for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.friendships f
      where f.follower_id = auth.uid() and f.followee_id = statuses.user_id
    )
  );

create policy "statuses insert own"
  on public.statuses for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "statuses update own"
  on public.statuses for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "statuses delete own"
  on public.statuses for delete
  to authenticated
  using (auth.uid() = user_id);

-- ─── USER_TEES policies ─────────────────────────────────────────────────────
-- Private — these are the user's saved manual tee entries
create policy "user_tees owner only"
  on public.user_tees for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─── REACTIONS policies ─────────────────────────────────────────────────────
-- A user can see reactions on their own ratings + reactions they made
create policy "reactions visible to participants"
  on public.reactions for select
  to authenticated
  using (auth.uid() = user_id or auth.uid() = target_user_id);

-- A user can create reactions where they're the reactor
create policy "reactions insert own"
  on public.reactions for insert
  to authenticated
  with check (auth.uid() = user_id);

-- A user can delete their own reactions
create policy "reactions delete own"
  on public.reactions for delete
  to authenticated
  using (auth.uid() = user_id);

-- ─── COURSE_REQUESTS policies ───────────────────────────────────────────────
-- A user can see their own requests + create requests
create policy "course_requests readable to self"
  on public.course_requests for select
  to authenticated
  using (auth.uid() = user_id);

create policy "course_requests insert own"
  on public.course_requests for insert
  to authenticated
  with check (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- REALTIME — push updates to the app for the social/feed surfaces
-- ═══════════════════════════════════════════════════════════════════════════
alter publication supabase_realtime add table public.ratings;
alter publication supabase_realtime add table public.reactions;
alter publication supabase_realtime add table public.friendships;

-- ═══════════════════════════════════════════════════════════════════════════
-- Done. Verify in Supabase Studio → Table Editor that all 8 tables exist:
--   users, friendships, ratings, imported_rounds, statuses,
--   user_tees, reactions, course_requests
-- ═══════════════════════════════════════════════════════════════════════════
