# TestFlight Build 3 — Results

**Status:** Code complete. Ready to run migrations + archive + upload.

**Branch:** `main` (committed directly because the worktree was missing the recent uncommitted work; using main's actual current code)

**Build:** version `0.1.0` build `3` (bumped from build 2)

**Commits in this build (in order):**
- `652c4a6` Pre-build3 snapshot (TestFlight 2 baseline)
- `12bb122` Wave A+B — privacy migrations + Settings persistence
- `c3cf747` Wave C — data hydration fixes
- `f3e4ac3` Wave D — sub-course coherency + Top 5 + played count
- `a0e3e14` Wave E — QuickLog persist + Refine Pause persist + photo cap + fake IDs
- `c20b0f5` Wave F — toast jank + stacking + Refine + InstallPrompt + coursePreviews
- `3c645d8` Wave G — friend home course display
- (next) Wave H — build number bump + this doc

---

## Critical: Run migrations BEFORE installing the build

The new build reads new columns. If a tester opens build 3 before the migrations run, the app will throw errors querying `users.hide_ratings` etc.

**Run in Supabase SQL Editor in this order:**

1. **`supabase/005_privacy.sql`** — adds hide_ratings/hide_shots/private_profile to users + RLS policies
2. **`supabase/006_quicklog_extras.sql`** — adds photos/note/played_with cols to imported_rounds
3. **`supabase/007_refine_state.sql`** — adds refine_state JSONB col on users

Each is idempotent (`if not exists` etc.) so safe to re-run.

---

## What got fixed in build 3

### 🔴 Trust-breakers fixed
- **Privacy toggles wired end-to-end** (cosmetic-lie eliminated). Hide My Ratings now shows audience picker (Hide from everyone / Hide from non-friends). Server-side RLS enforces. ✅
- **Push token revoked on sign-out + reset** — next user on shared device no longer inherits previous user's APNs. ✅
- **Followers/Following lists no longer fabricate fake user IDs** — non-friend rows render non-tappably instead of opening a hollow shell. ✅
- **InstallPrompt no longer fires inside TestFlight** — the "Add to Home Screen" prompt was confusing testers. ✅
- **QuickLog now persists photos, notes, and tagged friends** (3 fields previously dropped silently). ✅
- **Refine "Pause (save progress)" actually saves** to DB now — survives reload. ✅
- **Settings 'Email' field clarified** as display-only (not auth email).

### 🟡 Data integrity fixed
- **Ratings no longer disappear after sign-in** — primary fetch now has non-overwriting guard + 1.5s retry on first error. ✅
- **Friends' ratings + statuses eager-load** during hydration. Friends tab counts, course detail Friends tab, Top 5 friend overlap, and bucket-list signals all populate now. ✅
- **Sub-course coherency** — rating parent course no longer wipes per-sub ratings from local state. ✅
- **Profile Top 5 Rankings** expand sub-courses into separate ranked entries. Bethpage Black + Red show as 2 distinct rankings, not 1 averaged "Bethpage." ✅
- **Played count includes sub-courses** — Bethpage with 4 played subs = 4, not 1. Same logic now in Profile tab + friend list rows. ✅
- **friendDetailsCache cleared on sign-out** — no cross-account leak. ✅
- **Friend home course visible** on Friends tab list rows (🏠 home course name). ✅
- **Photo size capped via canvas re-encode** at max 1600px / JPEG 0.85 — no more silent Supabase row-size failures from 8-12MB iPhone photos. ✅

### 🟡 UX polish
- **Toast animation jank fixed** — outer/inner div split prevents the slideUp transform from clobbering the centering translateX(-50%). ✅
- **No two toasts overlap** — priority order: ratePrompt > dbErrorToast > isOffline > handicapToast. ✅
- **Refine Now no longer silently closes** when all earlyRefs reference missing courses — prompt is suppressed entirely instead. ✅
- **coursePreviews threading** — user-selected hero overrides now show on Discover, My Courses, and Home tabs (not just CourseDetail). ✅

---

## Deferred to build 4

These were in the "smart subset" plan but require larger surgery:

- **"Played With" tagging full wiring** — saved data still doesn't display anywhere, no notification fires. Needs render changes in activity feed + course detail + push-notify edge function.
- **Per-sub-course saved tees** — needs DB migration on user_tees + sub_name column + 4 call site updates. Roll into build 4 alongside courses table migration.
- **Comment author lookup** — comments still show "You" hardcoded. Needs reactorId → friend lookup across multiple components.
- **Onboarding back button** — small but multiple flow cases.
- **Skeleton loaders globally** — sprawls across many components.
- **Bucket list friend signal** — depends on UI design pass.
- **Welcome tour bucket-list slide** — copy + slide ordering pass.
- **Settings live blended handicap** — small, clear fix.
- **9.7 cap relaxation** — small, clear fix.
- **Coordinate audit** — needs Google Geocoding API setup + manual review pass.
- **Global avg rating + DB trigger** — DB migration + trigger + render.
- **Community photo picker** — new feature.
- **ToS photo license clause** — copy update.
- **All remaining ~50 items** from the original 109-item triage.

These compose well into a single build 4 batch.

---

## Manual test script for build 3

**Before installing on phone:**
1. Run migrations 005, 006, 007 in Supabase SQL editor (in that order)
2. Verify in Supabase Table Editor → users table that `hide_ratings`, `hide_shots`, `private_profile`, `refine_state` columns exist
3. Verify in Supabase Table Editor → imported_rounds table that `photos`, `note`, `played_with` columns exist
4. Archive in Xcode (Product → Clean Build Folder, then Product → Archive)
5. Distribute App → App Store Connect → Upload
6. Wait for processing (~30 min)
7. Answer encryption compliance ("None") same as build 2
8. TestFlight auto-distributes to your "Family and Friends" group

**Test on device after install:**

### Privacy (HIGHEST PRIORITY — core trust fix)
- [ ] Open Settings → toggle "Hide My Ratings" ON → audience picker sheet appears
- [ ] Pick "Hide from non-friends" → toggle stays ON, subtitle says "Hidden from non-friends only"
- [ ] Sign out + sign back in → toggle is still ON (persisted to DB)
- [ ] Toggle OFF → subtitle says "Others can see your ratings"
- [ ] Have a non-friend account try to view your profile → ratings should be empty (need 2 accounts to verify)
- [ ] Toggle "Hide Shot Scores" — survives reload
- [ ] Toggle "Private Profile" — survives reload

### Data integrity
- [ ] Sign out + sign back in → all your ratings still present (this was the disappearing-ratings bug)
- [ ] Open Friends tab → real "X courses played" counts appear for each friend (was always 0 in build 2)
- [ ] Open course detail → Friends tab shows your friends who've rated it (was empty before)
- [ ] Friends tab list rows show friend's home course alongside played count
- [ ] Profile Top 5 — multi-course properties show sub-courses as separate entries (e.g., Bethpage Black ranked separately from Bethpage Red)
- [ ] Profile "Played" stat includes sub-courses (Bethpage with 4 played subs = 4, not 1)

### Sub-courses
- [ ] Rate Bethpage Black via head-to-head
- [ ] Rate Bethpage Red via head-to-head
- [ ] Both should appear in Profile Top 5 separately
- [ ] Rating Bethpage as a parent (no sub) should not wipe the sub ratings from UI

### QuickLog persistence
- [ ] Quick Log a round → add a photo, write a note, tag a friend
- [ ] Force-close app, reopen
- [ ] Open Profile → Scores → the photo, note, tagged friend should still be there

### Refine flow
- [ ] Tap "Refine Now" — should now actually open the flow (not silently close)
- [ ] Refine 2 ratings, then Pause (save progress)
- [ ] Force-close app, reopen
- [ ] Settings → "Refine early ratings" should still say "Paused — resume at 2 of N"
- [ ] Resume → starts at index 2

### Toasts
- [ ] Log a round to trigger handicap toast → it should slide up from the bottom WITHOUT shifting horizontally
- [ ] Trigger an error (e.g., toggle airplane mode then save) → red error toast should appear, handicap toast should NOT show simultaneously

### Push token revocation
- [ ] Sign out — your `device_tokens` row in Supabase should be deleted
- [ ] Sign back in (or as a different user) → push works for the new account, not the old one

### Course previews
- [ ] On a course detail page, tap "Set as preview" on a photo
- [ ] Go to Discover tab → that course's card should show YOUR selected photo (not the default)
- [ ] Same on My Courses + Home tab

### InstallPrompt
- [ ] Open app fresh — NO "Add to Home Screen" prompt should ever appear (it would in build 2)

### Followers/Following lists
- [ ] Open your Followers list → tap a non-friend → should NOT open a hollow profile shell. Row is non-tappable for non-friends.
- [ ] Tap a friend → opens their real FriendProfile

---

## What to tell beta testers

Sample message for the TestFlight invite update:

> "Build 3 is up — biggest fixes:
> - Privacy toggles in Settings actually work now (they were cosmetic before)
> - Your ratings no longer disappear after signing out and back in
> - Friends' ratings + home courses now show up in the Friends tab
> - Sub-course properties (Bethpage etc.) show each course separately in Top 5
> - QuickLog photos, notes, and tagged friends now save properly
> - Refine 'Pause' actually saves your progress now
> - Toast animations are no longer janky
>
> Try toggling privacy in Settings, signing out + back in, and rating a multi-course property like Bethpage. Report anything weird via Settings → Send Feedback."

---

## Final commit

After this doc lands, one more commit bumps build to 3 + commits this doc.
