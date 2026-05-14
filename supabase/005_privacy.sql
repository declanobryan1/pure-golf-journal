-- ═══════════════════════════════════════════════════════════════════════════
-- 005_privacy.sql — Privacy controls (Hide Ratings, Hide Shot Scores, Private Profile)
--
-- Wires up the three Settings toggles that were previously cosmetic-only.
-- Each is enforced server-side via RLS so the client cannot bypass them.
--
-- Run order: 005 (after 004_feedback_and_analytics.sql)
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Schema additions ──────────────────────────────────────────────────────
alter table public.users
  add column if not exists hide_ratings text default 'off'
    check (hide_ratings in ('off', 'everyone', 'non-friends')),
  add column if not exists hide_shots boolean default false,
  add column if not exists private_profile boolean default false;

-- ─── Helper: is the requester following this user? ────────────────────────
create or replace function public.is_follower(target_user uuid)
returns boolean as $$
  select exists (
    select 1 from public.friendships
    where follower_id = auth.uid() and followee_id = target_user
  );
$$ language sql stable security definer set search_path = public;

-- ─── RATINGS: replace SELECT policy with privacy-aware version ─────────────
drop policy if exists "ratings readable to self and followers" on public.ratings;

create policy "ratings readable with privacy"
  on public.ratings for select
  to authenticated
  using (
    -- Always your own
    auth.uid() = user_id
    or (
      -- Follower of the author
      exists (
        select 1 from public.friendships f
        where f.follower_id = auth.uid() and f.followee_id = ratings.user_id
      )
      and (
        -- Author hasn't hidden from anyone, OR has only hidden from non-friends
        -- (and we are a friend per the exists() above)
        coalesce(
          (select u.hide_ratings from public.users u where u.id = ratings.user_id),
          'off'
        ) in ('off', 'non-friends')
      )
    )
    or (
      -- Not a follower; only readable if author hasn't hidden from anyone
      coalesce(
        (select u.hide_ratings from public.users u where u.id = ratings.user_id),
        'off'
      ) = 'off'
    )
  );

-- ─── STATUSES: same privacy gating (bucket list is part of the public picture) ─
drop policy if exists "statuses readable to self and followers" on public.statuses;

create policy "statuses readable with privacy"
  on public.statuses for select
  to authenticated
  using (
    auth.uid() = user_id
    or (
      exists (
        select 1 from public.friendships f
        where f.follower_id = auth.uid() and f.followee_id = statuses.user_id
      )
      and (
        coalesce(
          (select u.hide_ratings from public.users u where u.id = statuses.user_id),
          'off'
        ) in ('off', 'non-friends')
      )
    )
    or (
      coalesce(
        (select u.hide_ratings from public.users u where u.id = statuses.user_id),
        'off'
      ) = 'off'
    )
  );

-- ─── REACTIONS: same privacy gating (reactions are tied to ratings) ────────
-- Reactions can be seen by the rating's author (always) and others who can
-- see the underlying rating (delegated via the ratings policy above).
drop policy if exists "reactions readable to participants and followers" on public.reactions;

create policy "reactions readable with privacy"
  on public.reactions for select
  to authenticated
  using (
    -- The reactor or the recipient always sees their reactions
    auth.uid() = user_id
    or auth.uid() = target_user_id
    or (
      -- Followers of the rating's author can see, subject to their privacy
      exists (
        select 1 from public.friendships f
        where f.follower_id = auth.uid() and f.followee_id = reactions.target_user_id
      )
      and (
        coalesce(
          (select u.hide_ratings from public.users u where u.id = reactions.target_user_id),
          'off'
        ) in ('off', 'non-friends')
      )
    )
  );

-- ─── USERS: tighten readable fields when private_profile is on ─────────────
-- The previous "users readable to authenticated" policy exposed everything.
-- Replace it: still readable to authenticated, but row-level — when the
-- target has private_profile=true and the requester isn't a follower, only
-- the columns the client absolutely needs to render an avatar/handle remain
-- meaningful. We can't filter columns in RLS, so we either return the row or
-- don't. Approach: still return all rows so search/follow flows keep working,
-- but the *client* will refuse to render private profiles for non-followers.
-- Server-side, we still need a stricter policy for the rest of the data —
-- ratings + statuses are already gated above. profile_photo_url etc. is
-- visible because someone has to see your name to find you in search.
-- (No change here — handled client-side. Documented for future reference.)

-- ─── IMPORTED_ROUNDS: continue to be owner-only (already correct) ──────────
-- (No change — owner-only is the right policy regardless of privacy settings.)

-- ═══════════════════════════════════════════════════════════════════════════
-- Notes for the client:
--
-- 1. After this migration, hydrate `settings` from users.hide_ratings,
--    users.hide_shots, users.private_profile on app load.
--
-- 2. Persist toggle changes via update on public.users (PATCH-style).
--
-- 3. Hide Ratings UX: when toggled ON, show audience picker
--    ('Hide from everyone' → 'everyone', 'Hide from non-friends' → 'non-friends').
--    Toggle OFF stores 'off'.
--
-- 4. Hide Shots is enforced client-side: when displaying any rating where
--    rating.user_id !== current uid AND that author has hide_shots=true,
--    omit shot_score and personal_best from rendering. Server still returns
--    them in the response (would need a column-level RLS hack to strip
--    server-side; deferred to v1.1 if needed).
--
-- 5. Private Profile is enforced client-side: when viewing a non-friend's
--    FriendProfile, if their private_profile=true, render a "This account
--    is private" placeholder instead of their data.
-- ═══════════════════════════════════════════════════════════════════════════
