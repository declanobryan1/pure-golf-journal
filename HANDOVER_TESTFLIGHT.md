# Pure Golf Journal — TestFlight Handover

**Last updated:** 2026-05-06
**Current phase:** First TestFlight build uploaded, awaiting Apple processing
**Repo root:** `/Users/declanobryan/Claude/`
**Worktree (active):** `/Users/declanobryan/Claude/.claude/worktrees/goofy-kalam`
**Branch:** `claude/goofy-kalam`

---

## Current state in one sentence

The first TestFlight archive uploaded successfully to App Store Connect at ~[time of upload]; build is processing on Apple's side and not yet visible in the TestFlight tab. Everything is fine — just waiting.

---

## App identity

| Field | Value |
|---|---|
| App name | Pure Golf Journal |
| Display name (springboard) | Pure |
| Bundle ID | `com.declanobryan.puregolfjournal` |
| App Store Connect ID | `6763767372` |
| Apple Team ID | `L95DKW9826` |
| Marketing version | `0.1.0` |
| Build number | `1` |
| Min iOS | 13.0 |
| Device family | iPhone only (`TARGETED_DEVICE_FAMILY = "1"`) |
| Orientation | Portrait only |

---

## Architecture (don't relitigate)

- **Single-file React + Babel inline JSX** at `index.html` (~8500 lines). Yes really.
- **Capacitor 6** wraps it as a native iOS app for App Store distribution. Hybrid, not pure native — see `~/.claude/projects/-Users-declanobryan-Claude/memory/project_hybrid_vs_native.md`. Don't suggest a Swift rewrite for v1.
- **Supabase** for auth, Postgres+RLS, realtime, edge functions. Migrations in `/supabase/`.
- **Capacitor plugins in use:** Keyboard (resize: native), Push Notifications (APNs), Contacts (`@capacitor-community/contacts`), Media (save to camera roll), Haptics, Status Bar, Splash Screen.

---

## Pre-TestFlight work that's DONE (don't redo)

- ✅ Orientation locked to portrait (Info.plist)
- ✅ Supabase migrations 001–004 applied (initial schema, profiles, push tokens, feedback + analytics)
- ✅ App version bumped to 0.1.0 (1)
- ✅ Apple Sign In + Push Notifications capabilities enabled on bundle ID
- ✅ Batch Add and Handicap Entry modals refactored to App-level state (smooth dismiss to Scores sheet)
- ✅ Handicap modal floating top-anchored with `+` toggle for plus handicaps
- ✅ Handicap value persists to `users.self_reported_handicap` + `self_reported_at` via `dbWriteProfileFields`
- ✅ Pre-TestFlight upload errors fixed (THIS SESSION):
  - **Error 90717** (icon alpha) — stripped alpha from `AppIcon-512@2x.png`, composited onto cream `(245, 240, 232)` background. Now opaque RGB.
  - **Error 90474** (iPad orientations) — set `TARGETED_DEVICE_FAMILY = "1"` (iPhone only) in both Debug + Release configs in `App.xcodeproj/project.pbxproj`. Removed `UISupportedInterfaceOrientations~ipad` block from Info.plist.
- ✅ Archive uploaded to App Store Connect (Product → Archive → Distribute App → App Store Connect → Upload, succeeded)

---

## NEXT STEPS — pick up here

### 1. Wait for processing (15–60 min typical)

Where to look:
- **Email** — Apple sends "build completed processing" notification.
- **App Store Connect → Pure Golf Journal → TestFlight tab** → https://appstoreconnect.apple.com/apps/6763767372/testflight
- Right now shows "No Builds." That's expected during processing.

When it appears, status will be **"Missing Compliance"** (yellow) — that's normal, just means processing succeeded and Apple needs the encryption answer.

### 2. Answer export compliance

In TestFlight tab → click the new build → "Provide Export Compliance Information."

Answer:
- **Does your app use encryption?** → **No**
  - (Pure only uses standard HTTPS/TLS via Supabase + Capacitor — qualifies as exempt)

Status should flip to "Ready to Submit" / "Ready to Test."

### 3. Add internal testers

App Store Connect → **Users and Access** → **+** → invite by Apple ID email.
- Add yourself first
- Roles: any role with TestFlight access works (Admin, App Manager, or Developer)

Then in TestFlight tab → **Internal Testing** → **+** to create a group → add the build → add testers.

Internal testers don't need beta review — they get the build immediately.

### 4. Install on phone

- Install **TestFlight** app on iPhone from App Store
- Sign in with same Apple ID
- Pure appears under "Available" → tap **Install**
- Smoke test: sign in, log a round, friends search, push notif registration, etc.

### 5. After internal smoke test passes

External beta testers (up to 10,000) → requires beta app review (~24 hr, but usually faster).

**Beta tester comms reminder** (from memory `project_testflight_beta_comms.md`):
> Tell beta testers NOT to delete TestFlight before App Store launch. Keeping the TestFlight build installed lets them seamlessly transition.

---

## Pre-launch QA backlog (still open)

See `~/.claude/projects/-Users-declanobryan-Claude/memory/project_prelaunch_qa_backlog.md` — 4 HIGH + 5 MED + 8 LOW issues from earlier code review. Review after first round of TestFlight feedback to decide which block 1.0 vs ship to App Store as v1.0.1.

---

## Pre-launch TODOs (before App Store submission)

See `~/.claude/projects/-Users-declanobryan-Claude/memory/project_prelaunch_todos.md`.

**Top priority:** Migrate course data to hosted JSON before App Store submission (currently ~hundreds of courses bundled in `index.html` — bundle size will hit CDN threshold soon).

Also see `project_share_universal_links.md` (replace netlify share links with real Universal Links on custom domain) and `project_launch_marketing_checklist.md` (waitlist, landing page, screenshots, analytics, Reddit strategy).

---

## Key files reference

| File | Purpose |
|---|---|
| `/Users/declanobryan/Claude/index.html` | Entire app — React + Babel single file |
| `/Users/declanobryan/Claude/ios/App/App/Info.plist` | iOS bundle config (portrait-only, contacts/photos descriptions, push background mode) |
| `/Users/declanobryan/Claude/ios/App/App.xcodeproj/project.pbxproj` | Xcode build settings (now iPhone-only) |
| `/Users/declanobryan/Claude/ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png` | 1024×1024 universal app icon (opaque cream + green script P) |
| `/Users/declanobryan/Claude/capacitor.config.json` | Capacitor plugin config |
| `/Users/declanobryan/Claude/package.json` | npm deps + scripts (`cap:sync`, `prefetch-images`, etc.) |
| `/Users/declanobryan/Claude/supabase/*.sql` | DB migrations (001 schema, 002 profiles, 003 push, 004 feedback+analytics) |

---

## Common workflows

### Push code change to device

```bash
cd /Users/declanobryan/Claude
PATH="/opt/homebrew/bin:$PATH" npm run cap:sync
# Then in Xcode: Stop → Play
```

### After editing any image with `img:` URL in courses

```bash
npm run prefetch-images && npm run cap:sync
```

### Re-archive for TestFlight

1. Xcode → Product → Clean Build Folder (`⇧⌘K`)
2. Xcode → Product → Archive
3. Organizer (auto-opens) → Distribute App → App Store Connect → Upload
4. Bump build number first if previous upload of same number was accepted (not just rejected)

---

## Memory pointers (key context lives here)

`~/.claude/projects/-Users-declanobryan-Claude/memory/MEMORY.md` is the full index. Highlights:

- `project_pure_golf_app.md` — overview
- `project_hybrid_vs_native.md` — don't suggest Swift rewrite
- `feedback_modal_keyboard_pattern.md` — bottom-sheet for tall forms, floating-top for short
- `feedback_capacitor_resume_blank_screen.md` — never paint WKWebView's UIView backgroundColor
- `feedback_image_prefetch_sync.md` — image edit workflow
- `project_apple_capabilities.md` — Sign in with Apple + Push enabled
- `project_test_workflow.md` — "Reset all my data" + test users for safe testing
- `user_design_preferences.md` — values polish, photography-forward UI

---

## Quick "are we good?" checklist for next session

- [ ] Build appeared in TestFlight tab?
- [ ] Export compliance answered (No encryption)?
- [ ] Status = "Ready to Test"?
- [ ] Internal tester group created + you added?
- [ ] TestFlight app installed on phone?
- [ ] Pure build installed and launches?
- [ ] Sign in works on real device?
- [ ] Push notification permission prompt fires?

When all checked → ready to invite external beta testers and start collecting feedback.

---

## Things explicitly NOT to do in next session

- Don't suggest rewriting in Swift/SwiftUI for v1
- Don't apply bottom-sheet modal pattern globally — short forms need floating-top
- Don't paint WKWebView's UIView backgroundColor in AppDelegate
- Don't add random/generic course photos — course-specific > area > aerial
- Don't add new features beyond what's asked — Pure is in ship-and-stabilize mode
- Don't downgrade `MARKETING_VERSION` or skip build number when re-archiving
