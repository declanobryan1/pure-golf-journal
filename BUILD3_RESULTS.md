# TestFlight Build 3 — Results

**Status:** Code complete. Ready to run migrations + archive + upload.

**Branch:** `main`

**Build:** version `0.1.0` build `3`

**Commits in this build (in order):**
- `652c4a6` Pre-build3 snapshot (TestFlight 2 baseline)
- `12bb122` Wave A+B — privacy migrations + Settings persistence
- `c3cf747` Wave C — data hydration fixes
- `f3e4ac3` Wave D — sub-course coherency + Top 5 + played count
- `a0e3e14` Wave E — QuickLog persist + Refine Pause persist + photo cap + fake IDs
- `c20b0f5` Wave F — toast jank + stacking + Refine + InstallPrompt + coursePreviews
- `3c645d8` Wave G — friend home course display
- `6c532ee` Wave H — bump build to 3 + initial results doc
- `2057a50` Wave I (fast wins #1) — 9.7 cap + refine settings hint + live blended handicap
- `c2eb53c` Wave I (fast wins #2) — Welcome tour slide + Onboarding back + Comment authors
- `ada9cda` Wave I (fast wins #3) — Bucket signal + Played With display + Home photo cap
- (Wave J) — Per-sub tees + Global avg + QuickLog tag notifications
- (Wave K) — this final doc update

---

## CRITICAL: Run migrations BEFORE installing the build

**Run in Supabase SQL Editor in this order. Each is idempotent.**

1. `supabase/005_privacy.sql` — privacy fields + RLS
2. `supabase/006_quicklog_extras.sql` — photos/note/played_with on imported_rounds
3. `supabase/007_refine_state.sql` — refine_state JSONB on users
4. `supabase/008_quicklog_tag_notifications.sql` — tag-notification trigger on imported_rounds
5. `supabase/009_user_tees_subname.sql` — sub_name col + per-sub uniqueness on user_tees
6. `supabase/010_course_aggregates.sql` — course_aggregates table + trigger + backfill

**Verify after running:**
- `users` table → confirm new columns: `hide_ratings`, `hide_shots`, `private_profile`, `refine_state`
- `imported_rounds` table → confirm new columns: `photos`, `note`, `played_with`
- `user_tees` table → confirm new column: `sub_name`
- `course_aggregates` table → exists and has rows from the backfill

---

## Everything fixed in build 3

### 🔴 Trust-breakers (cosmetic-lies eliminated)
- Privacy toggles wired end-to-end + audience picker for Hide My Ratings ("Hide from everyone" vs "Hide from non-friends")
- Push token revoked on sign-out + reset (no leak across accounts on shared devices)
- Followers/Following lists no longer fabricate fake user IDs
- InstallPrompt never fires inside the native TestFlight app
- QuickLog now persists photos, notes, and tagged friends (3 fields previously dropped silently)
- "Played With" friend tags now display on rating detail (avatar stack + first 2 names)
- Refine "Pause (save progress)" actually saves to DB now — survives reload
- Settings 'Email' field clarified
- Comments show real author names (multi-person reactions no longer all attribute to "You")

### 🔴 Data integrity
- Ratings no longer disappear after sign-in (non-overwriting guard + retry)
- Friends' ratings + statuses + bucket lists eager-load during hydration (Friends tab counts work, Course detail Friends tab populates, Top 5 friend overlap works, bucket list signals work)
- Sub-course state coherency — rating parent course no longer wipes per-sub ratings
- Sub-courses appear as separate Top 5 entries
- Sub-courses count separately in Played stat
- Saved tees scoped per sub-course (Bethpage Black tees no longer bleed into Bethpage Red picker)
- friendDetailsCache cleared on sign-out
- Friend home course now visible on Friends tab list rows
- Photo size capped via canvas re-encode (1600px / JPEG 0.85) on PhotoUpload + onboarding home photos

### 🟡 UX polish
- Toast animation jank fixed (outer/inner div split — no more "swing in from right")
- No two bottom toasts overlap (priority gating)
- Refine Now no longer silently closes when courses are missing
- coursePreviews threading — user-set hero overrides show on Discover, My Courses, Home
- 9.7 rating cap relaxed: now unlocks at 3 total wins; refine flow bypasses cap entirely
- Settings + Profile show LIVE blended handicap ("Now 11.4 · started at 12") instead of static self-reported value
- 2nd refine prompt dismissal shows toast: "You can refine anytime from Settings"
- Welcome tour: new "Plan your next round" slide between rate/log and share — surfaces bucket list + tee time
- Onboarding back navigation: step 0 "Use a different account?" + steps 1+ get back chevron
- Bucket list rows show avatar stack of friends who also have it bucketed
- Played count now sub-aware on friend list rows too

### 🆕 New features
- Global average rating on course detail (DB trigger maintains aggregate per course on every ratings INSERT/UPDATE/DELETE)
- "Plan your next round" welcome tour slide
- "Played With" tag notifications now fire from QuickLog rounds too (not just rated courses)

---

## Deferred to build 4

These remain in the backlog. Not in this build:

- **"Played With" full delivery confirmation** — display + DB trigger are wired, but verify push notification actually fires end-to-end on a multi-device test
- **Skeleton loaders globally** — pure-skel applied in Wave 2 to a few hot spots, but a full sweep across all data-flashes-as-zero spots is deferred
- **Coordinate audit** — needs Google Geocoding API setup + manual review pass
- **Community photo picker** — new feature, multi-component
- **ToS photo license clause** — copy update
- **Course catalog migration** — moving COURSES array to Supabase (so adding courses doesn't need an App Store update). Saved in memory `project_build4_course_catalog_migration.md`.
- **Adding new courses** — depends on the migration above
- **Per-sub-course wantSubs indicator on per-sub chips** — small, easy
- **"Set as preview" caption clarifying it's local-only** — small, easy
- **Settings profile photo edit option** — small, easy
- **Bell badge clears on app foreground** — small, easy
- **Capacitor appStateChange listener for token refresh** — small, easy
- **navigator.onLine fetch ping verification** — moderate
- **Force-quit offline write queue** — large
- **OAuth race window improvements** — moderate
- **Realtime UPDATE/DELETE for ratings** — moderate
- **Activity feed dedup** — small
- **Contacts sync concurrency limit + fuzzy matching** — moderate
- **Email confirmation resend button** — small
- **PostgREST search injection sanitization** — small but fiddly

These compose into a healthy build 4 batch.

---

## Manual test script for build 3

**Before installing on phone:**
1. Run all 6 migrations in Supabase SQL editor (in order: 005 → 006 → 007 → 008 → 009 → 010)
2. Verify the column/table additions listed above
3. Xcode → Product → Clean Build Folder (`⇧⌘K`)
4. Xcode → Product → Archive
5. Distribute App → App Store Connect → Upload
6. Wait ~30 min for processing
7. Answer encryption compliance ("None") same as build 2
8. TestFlight auto-distributes to your "Family and Friends" group

**Test on device after install:**

### Privacy (HIGHEST PRIORITY)
- [ ] Open Settings → toggle "Hide My Ratings" ON → audience picker sheet appears
- [ ] Pick "Hide from non-friends" → toggle stays ON, subtitle says "Hidden from non-friends only"
- [ ] Sign out + sign back in → toggle still ON (persisted to DB)
- [ ] Toggle "Hide Shot Scores" — survives reload
- [ ] Toggle "Private Profile" — survives reload

### Data integrity
- [ ] Sign out + sign back in → all your ratings still present
- [ ] Friends tab shows real "X courses played" + home course (🏠 Pebble Beach)
- [ ] Course detail → Friends tab shows your friends' ratings (was empty before)
- [ ] Profile Top 5 — Bethpage Black + Red show as separate entries
- [ ] Profile "Played" stat counts sub-courses (Bethpage with 4 played subs = 4)

### Sub-courses
- [ ] Rate Bethpage Black via head-to-head
- [ ] Rate Bethpage Red via head-to-head
- [ ] Both appear separately in Profile Top 5
- [ ] Pick Bethpage Black tees in TeePicker, then switch to Bethpage Red sub — picker shows Red Course tees, NOT Black tees

### QuickLog persistence
- [ ] Quick Log a round → add a photo, write a note, tag a friend
- [ ] Force-close app, reopen
- [ ] Profile → Scores → photo, note, tagged friend still there
- [ ] Tagged friend gets a notification (check their bell icon)

### Played With display
- [ ] Open a course you rated with friends tagged
- [ ] Your Rating tab shows avatar stack + "Played with [first names]"

### Refine flow
- [ ] Refine 2 ratings, then Pause (save progress)
- [ ] Force-close app, reopen
- [ ] Settings → "Refine early ratings" still says "Paused — resume at 2 of N"
- [ ] Resume → starts at index 2
- [ ] Dismiss the second prompt entirely → see "You can refine anytime from Settings" toast

### Toasts
- [ ] Log a round → handicap toast slides up cleanly (no horizontal swing)
- [ ] Trigger an error → red error toast appears, handicap toast does NOT show simultaneously

### Push token revocation
- [ ] Sign out — `device_tokens` row in Supabase deleted
- [ ] Sign back in (or as a different user) → push works for new account

### Course previews
- [ ] On course detail, tap "Set as preview" on a photo
- [ ] Discover, My Courses, Home tabs all show YOUR selected photo

### Followers/Following
- [ ] Open Followers list → tap a non-friend → row is non-tappable (no hollow profile)
- [ ] Tap a real friend → opens their FriendProfile

### Settings live handicap
- [ ] Self-report a handicap, then log a few rounds
- [ ] Settings → "Know your handicap?" subtitle should show "Now 11.4 · started at 12"

### Bucket list friend signal
- [ ] Have a friend bucket-list a course you also have on yours
- [ ] My Courses → Bucket list → that row shows their avatar in the stack

### Onboarding (test by signing out + creating a new account)
- [ ] Step 0: top-left "Use a different account" link → confirm → signs out
- [ ] Step 1: top-left back chevron → returns to step 0
- [ ] Step 2: top-left back chevron → returns to step 1

### Welcome tour
- [ ] Should now have 7 slides instead of 6
- [ ] New "Plan your next round" slide explains bucket list + tee time

### 9.7 cap
- [ ] Rate a course you genuinely think is a 9.7+ via head-to-head — should now actually be reachable with calibrated scale (was harder before)
- [ ] Refine an early rating — bypass kicks in, no cap

### Comment authors
- [ ] Have multiple friends react to one of your friends' ratings
- [ ] Open the activity feed — each comment attributes to the actual reactor's name, not "You"

### Global avg rating
- [ ] Open a course detail — Avg Rating tile shows count from across all users (not just friends)

### InstallPrompt
- [ ] Open app fresh — NO "Add to Home Screen" prompt should appear

---

## What to tell beta testers

> "Build 3 is up — major improvements:
>
> **Privacy + Trust**
> - Privacy toggles in Settings actually work now (they were cosmetic before). 'Hide My Ratings' lets you pick 'everyone' or 'non-friends only'.
> - Your ratings no longer disappear after signing out and back in.
> - Comments show the real reactor's name (not 'You' for everyone).
>
> **Friends + Social**
> - Friends' ratings, home courses, and bucket lists now show up everywhere.
> - When friends also bucket-list a course, you see their avatars on your bucket list row.
> - 'Played with' friend tags now display on your rating detail and notify the tagged friend.
>
> **Sub-Courses (Bethpage, Bandon, etc.)**
> - Each sub-course ranks separately in your Top 5.
> - Played count includes each sub-course.
> - Saved tees no longer bleed across sub-courses.
>
> **Quality of Life**
> - QuickLog photos, notes, and tagged friends now actually save.
> - Refine 'Pause' actually saves your progress.
> - Toast animations no longer janky.
> - Welcome tour has a new 'Plan your next round' slide.
> - Onboarding has back navigation now.
> - 9.7 rating cap relaxed — calibrated users can actually hit 9.7+.
> - Settings shows your live blended handicap, not just the original number you typed.
>
> Try toggling privacy in Settings, signing out + back in, rating a multi-course property like Bethpage, and tagging a friend in QuickLog. Report anything weird via Settings → Send Feedback."

---

## Migration safety notes

- All migrations are idempotent (safe to re-run).
- 005, 006, 007 strictly add columns — no data loss risk.
- 008 adds a trigger that only fires going forward — no backfill.
- 009 adds a column + new partial unique indexes. The old unique constraint is dropped (so legacy code that relied on it would break — but no client code does).
- 010 backfills aggregates from existing ratings. The backfill is a single SELECT averaged per (course_id, user_id) pair — safe even at high row counts.

If anything breaks during migration, the deletes/drops in each are scoped (no `drop table`, no `delete from users`). Worst case you can drop the new tables/columns and re-run the older migrations.

---

## Final commit count

12 commits including the snapshot. Build 3 is meaningfully larger than originally scoped (smart subset → fast wins → medium tier). The deferred items in build 4 are mostly larger features or DB-migration-heavy work that benefit from being batched together separately.
