# TestFlight Build 3 — Complete Fix Plan

**For:** Spawned worktree session
**Source:** Triage of original feedback + 4 parallel QA agent reports + cosmetic-controls audit (2026-05-13)
**Total items:** 109
**Working file:** `/Users/declanobryan/Claude/index.html` (~8500 lines, single-file React + Babel inline JSX wrapped via Capacitor for iOS)
**Backend:** Supabase. Migrations in `/Users/declanobryan/Claude/supabase/`. Edge function in `/Users/declanobryan/Claude/supabase/functions/push-notify/`.

---

## CRITICAL CONTEXT — read all of this before touching code

### What Pure is
A single-file React + Babel inline JSX golf course rating app, wrapped via Capacitor 6 for native iOS. Hybrid app, on the App Store via TestFlight (build 2 currently live). Photography-forward, elegant typography, anti-data-bro vibe. Letterboxd-for-golf-courses. Read these memories first:
- `~/.claude/projects/-Users-declanobryan-Claude/memory/MEMORY.md` (the index)
- `project_pure_golf_app.md`
- `project_hybrid_vs_native.md` — DO NOT suggest Swift rewrite
- `feedback_modal_keyboard_pattern.md` — bottom-sheet for tall forms
- `feedback_capacitor_resume_blank_screen.md` — never paint WKWebView UIView background
- `feedback_image_prefetch_sync.md` — image edit workflow
- `feedback_photo_sourcing.md` — photo rules
- `user_design_preferences.md` — values polish, photography, elegant fonts
- `feedback_supabase_webhook_silent_misconfig.md` — recent gotcha

### Engineering rules
- **No new files unless absolutely necessary.** This is a single-file app on purpose. Add features inline.
- **No "improvements" beyond what's asked.** No refactors, no reorganization. Fix what's listed; leave the rest.
- **No comments on existing code you didn't change.** Add comments only where logic isn't self-evident.
- **No backwards-compatibility hacks.** If removing dead code (#106-108), remove it cleanly.
- **NEVER skip git hooks** (no `--no-verify`).
- **Match existing code style** — minified-looking inline React, semicolons, no trailing commas inside function args.
- The `index.html` file mixes a HUGE inline COURSES array (lines 897+, ~273 courses) with React components. Don't reformat the COURSES array.

### Existing patterns to reuse
- **DB writes:** `dbWriteX` helpers in lines 500-800. They handle errors via `_dbFail` + `pure-db-error` event. Follow this pattern for new writes.
- **State guard pattern:** `{rows, _error}` shape with retry on null (see `dbLoadFollowing` line 657). Use this for any new fetch.
- **Modal lifecycle:** `useModalExit` hook (around line 3165). Use for any new modal.
- **Body scroll lock:** Already in `useModalExit`. Don't roll your own.
- **Pure-skel skeleton:** `.pure-skel` CSS class at line 128. Apply liberally during data load (see #17).
- **Toast pattern:** Bottom-anchored portals around line 8479. Use existing styles.
- **Realtime subscriptions:** Around line 7182. Each channel needs uid suffix (per #38).

### Decisions already made by the user (don't re-ask)
- Privacy toggles: Hide Ratings has audience picker (`'off' | 'everyone' | 'non-friends'`); Hide Shot Scores + Private Profile are simple booleans. Show "Hidden" badge on own ratings so user sees what others can't.
- Played count: each sub-course counts separately (Bethpage = 4 not 1).
- Friend ratings: eager-load during secondary hydration (one extra query, fine for 10-50 friend graph size).
- Global avg: DB trigger maintains `avg_rating + rating_count` columns on courses table.
- Friend bucket signal: avatar stack of up to 3 + "+N", tap → sheet with full list. Friends only.
- Skeleton style: existing soft pulse (`.pure-skel`), no shimmer variant.
- 9.7 cap: relax to 3 total wins for 9.7, require 2 topWins for 9.8, 3 for 9.9, 4 for 10.0. Bypass entirely during refine flow (per #47).
- Onboarding back: step 0 → "Use a different account?" → confirm → signOut → LoginScreen. Steps 1+ → standard back chevron.
- Photo picker: friends only for v1. ToS clause: "By uploading photos you grant Pure a license to display them within the app, including to other users who follow you."
- Tee time button: rename to "Visit Course Website" OR wire to GolfNow if quick — your call, recommend rename for v1.
- Set as preview: add explicit "for me, this device" copy.
- Email field in Settings: rename to "Display email" + add caption clarifying it's NOT auth login.
- Course coords: hybrid audit (geocode all 273, manually verify flagged).
- Course catalog migration: NOT in this build. Saved for build 4.

### Git workflow
- Worktree branch: whatever was created
- **Commit after each wave** (4 waves below). Use Heredoc for commit messages.
- DO NOT push, DO NOT create PR, DO NOT merge. User will review locally.
- DO NOT amend or rebase commits.

### Build/verify workflow
- After each wave, run: `npm run prefetch-images && npm run cap:sync` from the worktree root if you touched any course photo URLs or `images/courses/` paths.
- Don't run Xcode builds — user will archive when ready.
- Don't run the dev server — this is a Capacitor iOS app, not a web preview target.

### Migration workflow
- Write SQL files into `supabase/` directory: `005_privacy.sql`, `006_played_with_quicklog.sql`, `007_refine_state.sql`, `008_course_avg_trigger.sql`, etc.
- Each migration must include the schema change + RLS updates if applicable.
- Number them sequentially after the existing 001-004.
- The user runs them manually in Supabase SQL editor. List the migrations + the order to run them at the end of each wave.

---

## WAVE 1 — Trust-breakers (the privacy-lie tier)

These violate user trust most directly. Ship these or pull from TestFlight.

1. **Privacy toggles wired end-to-end (#91, #96)**
   - Migration `005_privacy.sql`: add `hide_ratings TEXT DEFAULT 'off' CHECK (hide_ratings IN ('off','everyone','non-friends'))`, `hide_shots BOOLEAN DEFAULT FALSE`, `private_profile BOOLEAN DEFAULT FALSE` to `users` table.
   - Update RLS on `ratings` table: SELECT policy allows row read only if (`auth.uid() = user_id`) OR (author's `hide_ratings = 'off'`) OR (author's `hide_ratings = 'non-friends'` AND requester is in `friendships` where author is followee).
   - Update RLS on `users` table: when `private_profile = true`, non-friends can SELECT only `id, username, name, profile_photo_url, profile_photo_pos`.
   - Hydrate `settings` from `users` row on app load. Replace `useState({hideScores:false,hideShots:false,privateProfile:false})` (line 7363) with init that reads from profile after hydration.
   - Persist via `dbWriteProfileFields` on every toggle.
   - Add audience picker modal triggered when Hide Ratings toggled ON. Modal: "Hide from everyone" / "Hide from non-friends" + Cancel.
   - Apply client-side filters everywhere friend ratings/profile data renders (defense in depth).
   - Show small "Hidden" badge on own ratings UI when hideRatings is on, so user can see what others can't.

2. **Played With friend tagging completely wired (#92)**
   - Display tagged friends on rating detail (CourseDetail "Your Rating" + Friends tab activity card).
   - Send tag-type notification to each tagged friend on rating save (insert into `notifications` with `type='tag'`, `actor_id=current user`, `user_id=tagged friend`, `course_id`).
   - Renderer for `n.type==='tag'` already exists at line 2549 — verify it shows correctly.
   - Activity feed item for friend: "X played [Course] with you" if you were tagged.

3. **QuickLog persistence for photos/note/playedWith (#93)**
   - Migration `006_quicklog_extras.sql`: add `photos JSONB DEFAULT '[]'`, `note TEXT`, `played_with JSONB DEFAULT '[]'` to `imported_rounds` table.
   - Extend `dbWriteImportedRound` (line 531-540) to include these fields.
   - Extend hydration map (line 7091) to read them.
   - Display photos + note + tagged friends on the round row in Profile → Scores sheet.

4. **Refine "Pause (save progress)" actually persists (#94)**
   - Migration `007_refine_state.sql`: add `refine_state JSONB DEFAULT NULL` to `users` table.
   - Persist `refineState` to DB on every change (debounced ~500ms).
   - Hydrate from DB on app load.
   - Settings row "Paused — resume at N of M" must survive reload.

5. **Followers/Following list real UUIDs (#95)**
   - Lines 4952-4954 (FriendProfile) and 6445-6447 (ProfileTab): when building friendLike for a non-friend, fetch real user data via Supabase users query keyed by friendship row's other-side ID.
   - Synthetic `id:"u"+i` is NEVER acceptable. Use real UUIDs only.
   - If user can't be loaded (deleted account?), don't render the row.

6. **Settings persistence foundation (#96)**
   - Already covered in #1 above (privacy toggles foundation). Verify settings hydration + persistence pattern is generalized, not privacy-specific.

7. **Settings 'Email' field clarified (#97)**
   - Rename label to "Display email"
   - Add helper text under input: "This is for display only. To change your sign-in email, contact support."
   - OR if quick: wire actual edit to `supabase.auth.updateUser({email:...})`. Recommend display-only path for v1.

8. **Misleading button labels (#100, #101)**
   - "Book a Tee Time" (line 3800) → rename to "Visit Course Website"
   - "Set as preview" — add caption "(only on this device)" near the button

9. **InstallPrompt gate (#22)**
   - InstallPrompt component (line 6947): add `if (IS_NATIVE) return null;` at top. The PWA install prompt should never fire inside the TestFlight/native app.

10. **Push token revocation (#23)**
    - In `handleSignOut`: before `supabase.auth.signOut()`, DELETE from `device_tokens` where token matches the current registration.
    - In `handleResetAccount`: same deletion before reload.
    - Need a way to identify the current device's token — store it in a ref when registration fires (line 7315).

11. **handleSignOut awaits in-flight writes (#24)**
    - Add a small in-flight promise registry. Before `signOut() + reload`, await all pending dbWrite promises.
    - Or simpler: add 500ms delay before reload to let in-flight requests complete.

12. **Profile photo size cap (#25, #35)**
    - In photo handlers (PhotoCropper save + onboarding home photo + profile photo): if base64 string length > 500KB, reject with toast "Photo too large — please use a smaller photo or let us re-encode."
    - Better: always pass through canvas re-encode at max 1024×1024 to enforce ≤500KB output.
    - Apply to `handlePhoto` (~5243), `handleHomePhotos` (5234), PhotoCropper save (~2945).

13. **Settings username collision check + rollback (#26)**
    - In Settings username `saveEdit` (line 5848-5866): before calling `dbWriteProfileFields`, run the same realtime availability check used in onboarding (line 5316-5327).
    - On DB error from `dbWriteProfileFields`, rollback `profile.username` to previous value.

14. **Comment author labels (#27)**
    - Lines 4625-4628 + 6602-6605: replace hardcoded "You" with lookup by `comment.reactorId` against `friends` array + own `profile`. If reactorId === own profile.id → "You", else → friend.name.
    - Skeleton-load if friend not yet hydrated.

15. **FriendProfile follower/following counts (#28)**
    - In `dbLoadFriendDetails`: add two more queries — `select count from friendships where followee_id = friendId` (followers count) + same with follower_id (following count).
    - Or use a single RPC if cleaner.
    - Surface real counts on FriendProfile.

16. **Friend details cache cleared on sign-out (#29, #41)**
    - In `handleSignOut`: `delete window.__friendDetailsCache;`
    - In `onAuthStateChange` handler: when session changes, reset all per-user state (friends, notifications, activity, reactions, settings, coursePreviews, refineState, pendingRequests, pendingHomeRate). Use a single resetAllState() helper.

17. **Realtime channels uid suffix (#38)**
    - `rt-ratings-followees` channel (line 7257) → rename to `rt-ratings-followees-${uid}`
    - Audit other channels that may share names.

**Wave 1 commit message:**
```
Build 3 Wave 1: Fix trust-breakers (privacy lies + dead features)

- Wire privacy toggles end-to-end (RLS + audience picker)
- "Played With" tagging now displays + notifies tagged friend
- QuickLog persists photos/note/playedWith
- Refine "Pause" actually saves to DB
- Followers/Following lists use real UUIDs
- Settings persists to users table
- Photo size cap enforced (500KB max via canvas re-encode)
- Username collision check + rollback in Settings
- Comments show real author names
- Friend follower/following counts populated
- Per-user state reset on sign-out / account switch
- Push token revoked on sign-out + reset
- InstallPrompt no longer fires in native app
- Misleading "Book a Tee Time" → "Visit Course Website"

Migrations to run: 005_privacy.sql, 006_quicklog_extras.sql, 007_refine_state.sql
```

---

## WAVE 2 — Data integrity / "looks broken"

The "data appears lost / broken" tier. Bugs that make users distrust the app.

18. **Ratings disappearing after sign-in (#2)**
    - Apply non-overwriting guard + retry pattern (same shape as `dbLoadFollowing`'s `{rows, _error}`) to primary ratings + statuses fetches at lines 7062-7065.
    - Retry with backoff (1s/2s/4s). After 3 failures, toast "Couldn't load your data — pull to retry."
    - Critical: `setRatings({})` must NOT happen if fetch errored. Only happens on confirmed-empty (success with empty array).

19. **Friends ratings + statuses eager load (#12)**
    - Extend `dbLoadFollowing` SELECT to include all fields needed for friend ratings + statuses.
    - Or add a separate `dbLoadAllFriendsData(uids)` that fetches ratings + statuses for the full friend graph in one query.
    - Run during secondary hydration wave (line 7081).
    - Verify in: Friends tab "X courses played" counts, CourseDetail Friends tab, Profile Top 5 friend overlap badges, Friend bucket list signal (#21).

20. **Sub-course state coherency (#36, #74)**
    - `setRatings` in `saveRating` (line 7886): top-level branch must preserve existing `allSubs` from prev state. Spread it explicitly: `{...enrichedTopLevel, allSubs: prev[id]?.allSubs}`.

21. **Sub-courses as separate Top 5 entries (#7)**
    - Profile Top 5 (line 6502): expand sub-courses into separate ranking entries. Each Bethpage sub-course gets its own row.
    - Course detail rating display: show per-sub-course numbers separately, not just rolled-up overall.

22. **Saved tees per sub-course (#8)**
    - Change userTees key from `course.id` to `course.id + ':' + (subName || '_main')`.
    - Migration: backfill existing rows OR leave legacy data orphaned (acceptable for v1).
    - Update TeePicker (line 2609) to use composite key.
    - Update `dbWriteUserTee` writes accordingly.

23. **Played count sub-courses (#19)**
    - Lines 6173, 6288, 6626: instead of `played = COURSES.filter(c => statuses[c.id]?.play === 'played')`, sum sub-courses too. Each played sub-course counts as 1; courses without subs count once if played.
    - Build a helper: `getPlayedCount(statuses, ratings)` that returns the right number.

24. **Friend home course visible (#20)**
    - Add `home_course_id` to `dbLoadFollowing` + `dbLoadFollowers` SELECT.
    - Add `homeCourseId: u.home_course_id || null` to `_userToFriend` (line 644).
    - Display on FriendProfile near top.
    - Display as subtitle on Friends tab list rows: "Pebble Beach · 12 played"

25. **Toast jank (#3)**
    - Lines 8480, 8494, 8506: 3 toasts with conflicting `transform: translateX(-50%)` + animation transform.
    - Wrap each in outer (positioning + translateX) + inner (animation only).

26. **Toast stacking (#5)**
    - Add priority gating: ratePrompt > dbErrorToast > isOffline > handicapToast.
    - Lower-priority toasts get suppressed when higher one shows; redisplay on clear.

27. **Skeleton loaders globally (#17)**
    - Apply `.pure-skel` class wherever data flashes 0 / — / blank during hydration.
    - Targets: Profile stats, Friends list "X courses played", Course detail rating numbers + friend avg + global avg, Home/Clubhouse activity feed, My Courses counts, Friend profile.

28. **coursePreviews threading (#14)**
    - Pass `coursePreviews` map into DiscoverTab, MyCoursesTab, HomeTab, FriendProfile.
    - Each `course.img` lookup becomes `coursePreviews[course.id] || course.img`.

29. **Onboarding back button (#18)**
    - Step 0: top-left "Use a different account?" link → confirm modal → signOut → LoginScreen.
    - Steps 1+: standard back chevron → setStep(step-1).
    - Top-left, safe area.

30. **OAuth fixes (#33, #34, #67, #68)**
    - 250ms reject timer → increase to 1.5s.
    - Track `oauthInFlight` ref. Don't reset busy on visibilitychange if oauthInFlight is true.
    - signInWithGoogle native success path: setBusy(false) after appUrlOpen completes.

31. **Auth state change resets per-user state (#41)**
    - Already partially in Wave 1 #16.
    - In `onAuthStateChange`: if session changes (sign in OR out), reset friends, notifications, activity, reactions, settings, coursePreviews, refineState, pendingRequests, pendingHomeRate, friendDetailsCache. ALL of it.

32. **Realtime UPDATE/DELETE for ratings (#30)**
    - Subscribe to UPDATE + DELETE events on ratings table.
    - On DELETE: remove activity items + remove from friend.ratings.
    - On UPDATE: replace in-place.

33. **Activity feed React keys (#54, #53)**
    - Activity card key: include subName (or rating ID) so two ratings at same course don't collide.
    - Reactions key: include subName so sub-course bleeds don't happen.

34. **Activity feed dedup (#57)**
    - Before `setActivity(prev=>[item,...prev])`, check if item with matching (course_id, user_id, date, subName) already exists. Skip if so.

35. **unfollow + addFriend updates (#58, #59)**
    - On unfollow: filter activity + reactions to drop unfollowed user's items.
    - On addFriend: trigger immediate `dbLoadFolloweeActivity(uid)` to pull new friend's existing rounds.

36. **Notification mutation rollback (#61)**
    - dbDeleteNotification + dbMarkNotificationsRead: on failure, rollback local state.

37. **Bell badge clears on foreground (#90)**
    - Add Capacitor `App.addListener('appStateChange', ({isActive}) => { if(isActive) Push.removeAllDeliveredNotifications() + setBadgeCount({count:0}) })`.

38. **Push notification deep-link to target (#52)**
    - `pushNotificationActionPerformed` listener: read `ev.notification.data` (already populated in `pure` field from edge function). Navigate to specific course + scroll to specific rating/comment.

39. **NotificationsSheet mark-read on new arrivals (#50)**
    - Change `useEffect(...,[])` to watch `notifications.length`. New items arriving while sheet is open get marked read.

40. **Realtime reaction orphans (#51)**
    - dbToggleReactionEmoji 23505: client-side detect duplicate, remove the optimistic temp row.

41. **PostgREST search injection (#37)**
    - dbSearchUsers: sanitize `q` — strip `,`, `(`, `)`, `%`, `_` before interpolation.

42. **Email confirmation resend (#49)**
    - LoginScreen "check your email" notice: add "Resend confirmation email" link that calls `supabase.auth.resend({type:'signup', email})`.

43. **calcScore relax + refine bypass (#11, #47)**
    - Lines 1884-1889: relax thresholds. 9.7 unlocks at 3 total wins (any score). 9.8 needs 2 topWins. 9.9 needs 3 topWins. 10.0 needs 4 topWins.
    - Refine flow: pass `bypassCap: true` flag to `calcScore`. When true, skip the 9.7+ cap entirely.

44. **resolveHandicap same-day blend (#46)**
    - Line 1751: change `r.date > selfAt` to `r.date >= selfAt`.

45. **Self-report + historical CSV warning (#32)**
    - In handicap UI: if user has 20+ pre-self-report rounds, show banner: "Your imported rounds before today won't count toward this self-reported value. Log new rounds to refine your handicap."

46. **GHIN CSV fixes (#31, #48)**
    - Score detection: if score and slope candidates overlap, prefer the LATER position in the row (slope typically comes before score in NCRDB exports — flip the heuristic).
    - Quality guard: if `skipped > rounds * 0.5` (more than half garbage), reject with warning.

47. **Cascade status='none' to imported_rounds (#39)**
    - When user marks course as "haven't played", DELETE from imported_rounds where user_id + course_id match.
    - Local state: filter `profile.ghinRounds` to drop matching rounds.

48. **dbWriteImportedRound dedup (#40)**
    - In `handleBatchSave` (line 7620): set `saving=true` before forEach, reset after Promise.all completes. Guard double-tap on the Save button.
    - Add visual disable on the button while saving.

49. **Refine flow infinite-loop guard (#43, #73)**
    - Lines 8290-8294: if `f.index + 1 >= total`, jump straight to completion path instead of incrementing. Prevent infinite loop on consecutive missing courses.
    - On auto-skip: also update `refineState.pausedIndex` (currently only updates refineFlow.index).

50. **Refine "Initial anchor" duplicates (#66)**
    - Line 7864: only attach "Initial anchor" label if `prevSub.history.length === 0` (this is the actual first save).

51. **Refine Now silently closes (#9)**
    - Filter `earlyRefs` at prompt time to only courses present in COURSES.
    - If filtered list is empty, don't show the prompt at all.
    - Show toast on empty: "No early ratings to refine."
    - console.warn for missing courses (debug aid for production).

52. **Refine 2nd dismissal toast (#10)**
    - When promptStage transitions from 'pending-20' to 'done' via dismissal, show toast: "You can refine anytime from Settings."

53. **Settings live blended handicap (#6)**
    - Lines 5993, 6403: replace static `Set to ${selfReportedHandicap}` with live `resolveHandicap(...).value`. Display: "Now 11.4 · started at 12 · refined over 8 rounds" (where applicable).
    - Pass `resolveHandicap` result down to Settings via prop.

54. **Welcome tour bucket list slide (#4)**
    - Insert new slide between current slides 2 and 3 ("Rate it, or log it" and "Share your rounds").
    - Two-options layout (reuse handicap slide pattern at line 6853).
    - Options: "🎯 Bucket list — Save courses you want to play. See when friends rate them." + "🗓️ Book a tee time — Public courses link straight to their booking page."

55. **Welcome tour swipe (#82)**
    - Use `dragXRef.current` instead of `dragX` state in onTouchEnd. Avoid stale read.

56. **Welcome tour re-show on hydration (#77)**
    - In hydration `useEffect`: if `!u.data.welcome_tour_seen` after hydration, also `setShowWelcomeTour(true)`. Currently only fires from `handleOnboardingComplete`.

57. **Onboarding alert → toast (#79)**
    - Replace `alert(...)` at line 8010 with `pure-db-error` event dispatch + show in the existing toast.

58. **Onboarding nested scroll (#84)**
    - Outer Onboarding wrapper at line 8121: change `overflowY:auto` to `overflow:hidden`. Inner panels manage their own scroll.

59. **Onboarding skip-area copy (#83)**
    - When user skips both home course AND area: tour copy referencing "near you" should be conditional. Substitute with generic "Browse from the world's best" or similar.

60. **Onboarding area-picker "Skip for now" (#88)**
    - Line 5505: add explicit `homeArea: null` to onComplete payload.

61. **Username availability check error path (#81)**
    - Line 5324: when Supabase error, set status to `'error'` (not `'idle'`). Add `'error'` to the canContinue blocklist.

62. **PhotoCropper edge cases (#69, #80)**
    - On `naturalWidth === 0`: dispatch error toast, don't allow save.
    - On canvas.toDataURL exception: dispatch error toast, don't fall back silently.

63. **PhotoCropper double-mount lock (#45)**
    - Refactor body-scroll lock to refcounted pattern. Two simultaneous mounts → one effective lock. Both unmount → unlock.

64. **BatchEntry/HandicapEntry useModalExit (#86)**
    - Migrate from `overflow:hidden` only pattern to `useModalExit` hook (which uses position:fixed pattern).

65. **BatchAdd subName validation (#44)**
    - When `batchSetup.courseId` changes, reset `subName` to null.

66. **dbInsertReactionComment whitespace reject (#89)**
    - Check `text.trim().length === 0` → return false without insert.

67. **Capacitor appStateChange listener (#63)**
    - On resume: call `supabase.auth.refreshSession()` to handle stale tokens after long backgrounding.
    - Also handles bell badge clear (#37 above).

68. **navigator.onLine fetch ping (#72)**
    - When `isOffline` becomes true, run a background fetch ping every 30s. If ping succeeds, flip to online.

69. **Force-quit offline queue (#70)**
    - Add localStorage-backed write queue. On any dbWrite, also persist the operation to `pure-pending-writes-${uid}`.
    - On app load, replay queue.
    - On successful network write, remove from queue.
    - Cap queue at 100 ops.

70. **Per-key save rollback (#71)**
    - In saveRating: instead of full snapshot rollback, rollback ONLY the affected key.

71. **saveRating history append-only (#65)**
    - Don't include `history` in the saveRating payload. Use a Postgres trigger or RPC that appends to history server-side, preventing the overwrite race.
    - Migration `008_history_append.sql` adds the trigger.

72. **dbWriteRating parent row (#78)**
    - When user saves a sub-course rating and no parent row exists, INSERT a stub parent row (`sub_name=null` with `overall = avg of subs`). Future writes targeting parent fields will UPSERT correctly.

73. **Settings profile photo edit (#62)**
    - Add "Edit Photo" row in Settings → reuses PhotoUpload + PhotoCropper. Saves via dbWriteProfileFields.

74. **Sub-course Ratings list tappable (#98)**
    - Lines 3873-3883: wrap each sub-course rating row in a `pressable` button that triggers re-rate flow for that sub.

75. **wantSubs indicator on per-sub chips (#99)**
    - On CourseDetail per-sub chips (line 3772): if `statuses[course.id].wantSubs.includes(sub.name)`, render a small ★ icon.

76. **impressionLabel display OR remove (#102)**
    - Render impressionLabel as a small caption on rating detail. E.g., "Considered ★ Top-Tier."
    - If keeping, surface on share card too.

77. **comparisons display OR remove (#103)**
    - Render on rating detail: "Beat Pebble Beach, lost to Augusta, tied with Pinehurst" — small text under the score.

78. **Remove baseline:true (#104)**
    - Remove from save payload at line 3521. Dead field.

79. **firstImpression badge persistent (#105)**
    - Render "Anchor rating" badge on stored ratings in the "Your Rating" tab, not just on H2H reveal screen.

80. **Bucket list friend signal (#21)**
    - On bucket list rows + course detail bucket button area: avatar stack of up to 3 friends who also have it bucketed, "+N" if more. Tap → sheet with full list.
    - Depends on Wave 2 #19 (eager-load friend statuses).

81. **Cleanup dead code (#106, #107, #108)**
    - Remove `toggleEmoji` prop drilling.
    - Remove `view==="add"` reference from FriendsTab comment.
    - Decide tag-notification renderer: KEEP (since #2 above wires tag notifications).

82. **Reset Account clears all per-user localStorage (#75)**
    - In handleResetAccount: enumerate localStorage keys matching `pure-*-${uid}` pattern, delete all. Don't just delete coursePreviews.

83. **popstate handler audit (#85)**
    - Audit pushState calls vs popstate handler. Ensure no duplicate pushes during rapid navigation.

84. **InstallPrompt private-mode (#87)**
    - Wrap localStorage scan in try/catch + null check.

**Wave 2 commit message:**
```
Build 3 Wave 2: Data integrity + "looks broken" fixes (~65 items)

[summarize the major buckets]

Migrations to run: 008_history_append.sql (+ any others added in this wave)
```

---

## WAVE 3 — Polish + Features

The remaining smaller polish items + new feature additions.

85. **Global average rating (#13)**
    - Migration `009_course_avg.sql`: add `avg_rating NUMERIC(3,1)` and `rating_count INTEGER` to a new `courses` table (since current courses are array-only — this is the start of the catalog migration deferred to build 4).
    - WAIT — user explicitly said catalog migration is build 4. So instead: store this on a new `course_aggregates` table keyed by course_id (number).
    - Trigger on ratings INSERT/UPDATE/DELETE: recompute avg + count for that course_id.
    - Display in CourseDetail "Avg Rating" pill (currently shows friends+self only).
    - Hydrate aggregates with one batch query on app load (or lazy-load per course view).

86. **Community photo picker (#15)**
    - Course detail Photos tab: aggregate friends' + own photos for that course.
    - Each photo: "Set as my hero" button (writes to coursePreviews) + "Report" button.
    - New table `photo_reports` (migration `010_photo_reports.sql`).
    - Photo credit overlay on hero when user-picked.
    - Friends only for v1.

87. **ToS photo license (#16)**
    - Update `legal/PRIVACY_POLICY.md` and any in-app legal text.
    - Add: "By uploading photos to Pure, you grant us a license to display them within the app, including to other users who follow you."

88. **Coordinate audit (#109)**
    - Write `scripts/audit-course-coords.js` (Node script).
    - For each course in COURSES: call Google Geocoding API with `${name}, ${city}, ${state}, USA`.
    - Compare returned lat/lng to current. Flag deltas > 0.01° (~0.7 mi).
    - Output a JSON report of flagged courses.
    - For each flagged: manually cross-check via Wikidata + Google Maps satellite of actual clubhouse.
    - Update lat/lng in COURSES inline.
    - Run `npm run prefetch-images && npm run cap:sync` if any image keys changed (shouldn't, since only coords changed).

**Wave 3 commit message:**
```
Build 3 Wave 3: New features + polish

- Global avg rating per course (DB trigger + course_aggregates table)
- Community photo picker on course detail (friends-only for v1)
- ToS update with photo license clause
- Coordinate audit: fixed ~XX courses with inaccurate coords

Migrations: 009_course_aggregates.sql, 010_photo_reports.sql
```

---

## WAVE 4 — Build prep

89. **Bump version to build 3**
    - `ios/App/App.xcodeproj/project.pbxproj`: bump `CURRENT_PROJECT_VERSION` from 2 → 3 (both Debug + Release configs).
    - Keep `MARKETING_VERSION = 0.1.0`.

90. **Manual test script (#110)**
    - Write `BUILD3_TEST_SCRIPT.md` covering all blocker fixes. Sectioned by feature area. Estimated 30-45 min to run end-to-end.
    - User runs script + sends to beta testers.

91. **Final cap:sync**
    - Run `npm run prefetch-images && npm run cap:sync` from worktree root.

92. **Investigation item (#1)**
    - Handicap notification rounds 1-4: requires creating a fresh test account. Document a reproduction script in `BUILD3_TEST_SCRIPT.md`. Don't fix without repro.

**Wave 4 commit message:**
```
Build 3 Wave 4: Build prep

- Bump build to 3
- Manual test script covering all blocker fixes
- cap:sync run
```

---

## Summary at end of session

When all waves are committed, write a final summary to `BUILD3_RESULTS.md` covering:
- All 109 items: ✅ done / ⏭️ skipped (with reason) / ❌ blocked (with what's blocking)
- All migrations created (in order to run)
- Any new files added
- Anything user must do manually before re-archive

DO NOT push, DO NOT create PR. Leave everything on the worktree branch for user review.
