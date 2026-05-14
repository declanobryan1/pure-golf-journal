# TestFlight Build 5 — Results

**Status:** Code complete. Ready to archive + upload.

**Branch:** `main`

**Build:** version `0.1.0` build `5`

**No new migrations required.** All build 3 migrations (005-010) already in place.

---

## Why we skipped build 5 = no, we did

Build 4 was the hotfix for the build 3 splash-screen freeze (the missing `useCallback` destructure). Build 5 = build 4 fixes + new feedback round.

---

## Commits in build 5 (on top of the build 4 hotfix)

- `6a1c096` Cluster 1 — Bugs #1, #2, #4, #8: Clubhouse played count, simultaneous notifications, Played With chip avatars, + Score scrollable
- `49b623b` Cluster 2 — Bugs #5, #6, #7 + Backlog A, B, G
- `6dd1ae7` Cluster 3 — Bug #3 (rounds drilldown) + Backlog C, D, F, H
- (this commit) Cluster 4 — Backlog I (ToS) + bump to build 5

---

## What got fixed in build 5

### TestFlight feedback bugs
- **#1 Clubhouse "courses played" rolled-up sub count** — HomeTab now sub-aware (Bethpage with 4 played subs counts as 4, matches Profile + MyCourses)
- **#2 "Round saved" + "Logged to handicap" simultaneous toasts** — handicapToast now suppressed when quickLogToast is present (they conveyed the same thing)
- **#3 Make "X rounds" pill clickable** — opens new sheet with each round's score, date, played-with friends, sub-course, and note
- **#4 Played With chips show avatars** — both chip selectors (rate flow + Quick Log) now pass `photo` + `photoPos` so friend profile photos render
- **#5 Friends list "X courses played" skeleton loader** — shows `pure-skel` placeholder while tertiary hydration loads, instead of flashing "0"
- **#6 9.7+ cap tightened + auto-refine bumped to first 7** — cap now requires more wins (9.7 needs 4 wins, 9.8 needs 2 topWins+5 wins, 9.9 needs 3 topWins, 10.0 needs 4 topWins+6 wins). Refine bypasses cap. isEarly now flags ratings 4-7 (was 4-5).
- **#7 Refine "Pause (save progress)" trap** — handlers extracted into named functions for clarity; logic was correct but inline closures were fragile
- **#8 + Score course picker scrollable** — added `WebkitOverflowScrolling`, `overscroll-behavior:contain`, `touch-action:pan-y` so the inner list catches the iOS gesture

### Backlog adds
- **A "Set as preview" caption** — banner now includes "Visible to you on this device only"
- **B Per-sub wantSubs ★ indicator** — sub chips on CourseDetail show ★ when sub is on bucket list
- **C Bell badge clears on app foreground** — Capacitor `appStateChange` listener clears delivered notifications + badge
- **D Email confirmation resend button** — "Didn't get it? Resend confirmation" link calls `supabase.auth.resend`
- **F Activity feed dedup** — realtime reconnects no longer create duplicate cards
- **G PostgREST search injection sanitization** — strips `,()*%_` before interpolating user input into `.or()` filter
- **H Capacitor appStateChange token refresh** — calls `refreshSession()` on foreground to avoid stale-JWT after long backgrounding (combined with C in one listener)
- **I ToS photo license clause** — new section 4a in PRIVACY_POLICY.md covering display rights for uploaded photos, including future community photo picker

---

## Manual test script

### Before installing
- Xcode → Product → Clean Build Folder
- Xcode → Product → Archive
- Distribute → App Store Connect → Upload
- Wait ~30 min for processing
- Encryption compliance: "None"
- TestFlight auto-distributes to your Family and Friends group

### On device — focused on what changed in build 5

#### Highest-priority spot-checks (5 min)
- [ ] **Clubhouse stat:** Profile-tab → home → "Courses Played" number now matches My Courses (sub-courses count separately)
- [ ] **No simultaneous toasts:** Quick Log a round → only ONE notification appears, not both "Logged" + "Round saved"
- [ ] **Played With avatars:** Quick Log → tap a friend chip → their profile photo shows in the chip avatar
- [ ] **+ Score scrolls:** Open + Score → search a partial term that returns 8+ results → list scrolls

#### Rating drill-down (NEW feature)
- [ ] On a course you've logged 2+ rounds at → open Your Rating tab
- [ ] The "X rounds" pill should now have a chevron and be tappable
- [ ] Tap → sheet shows each round with score, date, friends tagged

#### Refine
- [ ] Rate 4 calibration courses (your existing baseline + a few more)
- [ ] Rate a 5th, 6th, 7th course → these should now be flagged as "early ratings" (~ icon)
- [ ] At 15 ratings, refine prompt should include them

#### 9.7+ cap
- [ ] Try to rate a course you'd give a 10 — without a strong calibrated scale (3 topWins, 6 total wins), it should cap at 9.9 not let you reach 10
- [ ] In refine flow → cap doesn't apply, can hit 10

#### Refine pause
- [ ] Start refining → tap close → Pause confirm appears
- [ ] Tap "Pause (save progress)" → should fully exit refine flow (not loop back)
- [ ] Settings → Refine row says "Paused — resume at N of M"

#### Backlog adds
- [ ] Settings → Privacy banner if Hide Ratings is on shows "Visible to you on this device only" caption
- [ ] On Bethpage course detail, if you've bucket-listed Black Course → ★ icon appears next to "Black Course" in the chip
- [ ] Quit app → reopen → bell badge clears immediately
- [ ] Sign up with a new email → "Check your email" notice → "Didn't get it? Resend confirmation" link works
- [ ] Search a friend with special chars in name (commas, parentheses) → no error, results filtered safely

---

## Beta tester message

> "Build 5 — second round of fixes from your beta feedback:
>
> **From your reports**
> - Clubhouse 'Courses Played' number now matches Profile (was rolled-up incorrectly)
> - No more double 'Round saved' + 'Handicap updated' notifications stacking
> - 'Played With' friend chips now show their profile photos
> - + Score course picker actually scrolls now
> - Tap the 'X rounds' pill on a rating to see each round's score, date, and who you played with
> - 9.7+ ratings now require more calibrated comparisons (10.0 was too easy)
> - First 7 ratings are now flagged as early/refinable (was 5)
> - Refine 'Pause' should no longer trap you in a loop
> - Friends-list count shows a loading shimmer while data loads
>
> **Polish**
> - 'Set as preview' note clarifies it's just for your device
> - ★ shows on sub-courses you've bucket-listed
> - Bell badge clears when you reopen the app
> - 'Resend confirmation email' link if you didn't get the signup email
>
> Try the rounds drilldown — tap any course where you've logged multiple rounds → 'X rounds' pill on Your Rating tab. Should show the full list."

---

## What's still deferred to build 6+

- Course catalog migration (COURSES → Supabase table)
- Adding new courses (depends on catalog migration)
- Community photo picker (now legally covered by ToS update; just needs UI work)
- Coordinate audit (geocoding script)
- Force-quit offline write queue
- Realtime UPDATE/DELETE for ratings
- Skeleton loaders globally (just the friend list this build)
- Settings profile photo edit option
- OAuth race window improvements
- Contacts sync concurrency limit + fuzzy matching
- "Played With" full delivery confirmation (verify push fires end-to-end)
