# TestFlight Build 3 — Triage

**Source:** Original session feedback (21 items) + 4 parallel QA agent code reviews (~80 items, deduped to ~70 unique additions). Total: **~90 items** in master todo list.

**Goal:** Decide what ships in build 3 vs build 4 vs backlog, in priority order.

---

## 🔴 Tier 1 — MUST FIX in build 3 (data loss / privacy / "looks broken")

These tank user trust on first impression. Ship none of these = ship a broken app.

### Data integrity
1. **Ratings disappearing after sign-in** — primary fetch silently fails, wipes UI state
2. **Friends' ratings + statuses don't load** — entire Friends feature looks empty/broken
3. **Sub-course state coherency** — rating parent wipes allSubs from UI
4. **Saved tees scoped to course not sub-course** — wrong tees show
5. **Played count missing sub-courses** — Bethpage = 1 instead of 4
6. **Sub-courses not in Top 5 / course detail** — rolled up to one number
7. **Refine Now silently closes** — entire feature broken for users with missing courses

### Privacy / multi-user safety
8. **Push token NOT revoked on sign-out / reset** — privacy leak across accounts
9. **Auth state change doesn't reset per-user state** — User A's data leaks into User B's UI
10. **`window.__friendDetailsCache` leaks across users** — same bug, different vector
11. **Comments hardcode "You" as author** — multi-user notifications all attributed to you
12. **PostgREST search injection** — special chars break/leak search

### Looks-broken bugs
13. **InstallPrompt fires inside TestFlight** — tells users to install the already-installed app
14. **FriendProfile follower/following counts always 0**
15. **Friend home course not visible** — listed as available friend data but never loaded
16. **Realtime ratings handler ignores UPDATE/DELETE** — deleted ratings linger forever
17. **Activity feed React key collisions** — same friend, 2 ratings at same course
18. **Toast animation jank + stacking**
19. **Onboarding back button missing**
20. **`coursePreviews` doesn't thread to other tabs**

### Math/silent corruption
21. **GHIN CSV picks slope as score** — corrupts handicap silently
22. **Self-reported handicap with prior CSV import** — historical 50 rounds get 0% weight
23. **`setStatus(id, 'none')` keeps imported_rounds** — deleted course rounds still count
24. **Refine flow infinite-loop on 2+ consecutive missing courses**

### OAuth / sign-up
25. **OAuth 250ms race** — successful sign-in shows error toast
26. **OAuth busy-reset enables double-tap** — parallel sessions
27. **Settings username edit has no collision check** — UI/DB divergence
28. **Profile photo upload no size cap** — 13MB blob in DB + localStorage
29. **homePhotos unbounded** — silent home rating loss

**Tier 1 total: 29 items**

---

## 🟡 Tier 2 — SHOULD FIX in build 3 (polish, UX dead-ends, easy wins)

Not data loss but visibly wrong or confusing.

30. Settings: live blended handicap display
31. 9.7 rating cap relaxed
32. Welcome tour bucket list + tee time slide
33. "Refine from Settings" toast after 2nd dismissal
34. Skeleton loaders globally
35. dbWriteImportedRound dedup (Batch Add double-tap)
36. NotificationsSheet mark-all-read on realtime arrivals
37. Optimistic reaction orphan on duplicate
38. Push notification deep-link to specific target
39. Activity feed dedup
40. Activity feed reactions key includes subName
41. Contacts sync concurrency limit + fuzzy matching
42. unfollow drops items from in-memory feeds
43. addFriend triggers activity refetch
44. Notification mutation rollback on failure
45. appStateChange listener for token refresh + badge clear
46. Capacitor offline write queue
47. Airplane mode per-key rollback (not full snapshot)
48. ShareRatingModal success state wired
49. PhotoCropper canvas failure surfaces to user
50. PhotoCropper double-mount body lock fix (refcounted)
51. Refine "Initial anchor" label only on actual first
52. Refine pausedIndex tracks auto-skips
53. saveRating preserves allSubs in top-level branch
54. Reset Account clears all per-user localStorage flags
55. Welcome tour shows for unseen users on hydration
56. dbWriteRating creates parent-level row when subs exist
57. Onboarding alert → in-app banner
58. PhotoCropper handles naturalWidth=0
59. Username check error treated as "unable to verify"
60. WelcomeTour swipe reads from ref not state
61. Skip-area onboarding handles no-home case better
62. Onboarding nested scroll conflict
63. Bell badge clears on foreground
64. Email confirmation resend button
65. Friend bucket list signal (new feature, but small)
66. Realtime channel name uid suffix
67. Reaction key parser hardening
68. BatchAdd subName validation
69. parseGhinCsv quality guard threshold
70. Reaction comment whitespace-only rejection
71. Activity feed cap reconciliation (50 vs 100)
72. dbLoadFolloweeActivity stale items
73. Modal scroll restoration math
74. BatchEntry/HandicapEntry use proper body lock
75. nativeOAuth setBusy(false) on Google success
76. Same-day round excluded from handicap blend
77. 9.7 cap bypass during refine flow
78. saveRating history append-only (race-safe)
79. Settings profile photo edit
80. popstate handler audit
81. localStorage scan in LoginScreen handles Private Mode

**Tier 2 total: 52 items**

---

## 🟢 Tier 3 — PUSH TO BUILD 4 (bigger features, DB migrations, lower urgency)

82. **Global average rating** (DB migration + trigger)
83. **Community photo picker** (new feature)
84. **ToS photo license clause** (must precede #83)
85. **Handicap notification rounds 1-4 investigation** (needs new test account)

**Tier 3 total: 4 items**

---

## Build 3 scope decision

**Recommend:** Tier 1 (29) + most of Tier 2 (~40 of the 52). Skip the heaviest Tier 2 items:
- Offline write queue (#46) — substantial work, edge case
- Settings profile photo edit (#79) — new feature
- Same-day handicap blend (#76) — niche
- popstate audit (#80) — investigation, not a fix

**That's ~70 fixes in build 3.** Aggressive but doable in 2-3 focused days of work. Each is small individually.

**Build 4** adds: global avg, community photos, ToS update, anything build 3 surfaces in testing.

---

## Manual test script

Once build 3 fixes are in, I'll write a 30-min checklist script you can run + send to testers covering every blocker fix. No way to fully automate iOS testing without paid infra (per earlier discussion).

---

## What I need from you

1. **Approve scope** — Tier 1 + ~40 Tier 2 in build 3? Or tighten/loosen?
2. **Greenlight to start writing fixes** — I'll work through the Tier 1 list first (highest blast radius)
3. **Anything to skip entirely?** — Some Tier 2 items might not match your priorities (e.g., contacts fuzzy matching might be a "later" thing for you)
