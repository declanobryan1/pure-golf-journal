# Pure Golf Journal — Phase 2 Handover

Updated: 2026-04-29 evening

## Where we are

**Phase 2 (Capacitor → iOS native) is complete and running on Declan's real iPhone.** Most major issues fixed. A few small UX/photo issues remain.

---

## Quick status table

| Layer | State |
|---|---|
| Backend (Supabase) | ✅ Live, 8 tables, RLS enforced |
| Auth | ✅ Email/password + Apple + Google all working |
| iOS Xcode project | ✅ Built and running on real device |
| Babel precompile | ✅ JSX → plain JS at build time |
| Capacitor plugins | ✅ Browser, App, Haptics installed (v6) |
| Native splash screen | ✅ Cream + green Pure wordmark (Pure-branded) |
| App icon | ✅ Green "P" on cream |
| Photo bundling | ✅ 183/184 prefetched locally (Bel-Air still 404) |
| Display name | ✅ "Pure" on home screen |
| OAuth deep linking | ✅ `com.declanobryan.puregolfjournal://callback` |
| URL scheme registered | ✅ Info.plist + Supabase allowlist |
| Haptics on iPhone | ✅ Rating saves, slider ticks, h2h choices only |

---

## Outstanding bugs from Declan's last test

1. **Bel-Air Country Club (id:229, line 688) has no photo on device** — Current URL: `https://commons.wikimedia.org/wiki/Special:FilePath/Bel%20Air%2C%20Los%20Angeles%2C%20California.jpg?width=1280` returns HTTP 404. Failed during prefetch (logged in `scripts/remote-image-manifest.json` console output). Already tagged `photoType:"regional"`. **Fix:** find a working Wikimedia URL for the Bel-Air area or LA hills, OR an actual aerial of the course. Then update line 688's `img:"..."`, run `npm run prefetch-images`, then `npm run cap:sync`. Alternative: use a landmark like the Bel-Air Hotel or Stone Canyon Reservoir which are nearby.

2. **Big Canyon Country Club (id:199, line 657) has no `img` field at all** — entry is missing the photo URL entirely. **Fix:** find a Wikimedia photo of Newport Beach canyon area or Big Canyon itself, add `img:"...", photoType:"regional",` between `gdUS:false,` and `tees:[...]`. Then prefetch + sync.

For both: search `commons.wikimedia.org` for "Newport Beach", "Bel Air Los Angeles", "LA Hills aerial", etc. The photo sourcing rules in memory (`feedback_photo_sourcing.md`) apply — never random generic golf photos.

3. **`photoType:"regional"` label removal when user uploads** — currently the regional-photo notice always shows when `course.photoType==="regional"`. Should hide when:
   - On Discover cards: when there's a user-uploaded photo via `coursePreview` (per-user override) or when a friend's rating photo could be used as the hero
   - On course detail: already gates on `!coursePreview` (line ~2895), but should ALSO hide if any user has uploaded a photo to the rating
   - Cleanest fix: also gate on `course.userPhotoUrl` (a future field where we'd promote a community-favorite uploaded photo to the course's hero) — this can be wired up when we build the photo gallery feature (already in the launch TODO list as item #5)

4. **Rating screen still drags side to side** — user said "I can still move it to the side a little." We added `touchAction:"pan-y"` on the Sheet container and `touchAction:"none"` + `stopPropagation` on sliders, but on real iPhone there's still some horizontal slack. May need to also stop propagation on the modal backdrop or use `passive:false` + `preventDefault` more aggressively.

---

## Key files Phase 2 added/touched

```
Claude/
├── index.html                    # SOURCE — JSX + babel-standalone (web preview)
├── capacitor.config.json         # Capacitor settings (URL scheme, WebView config)
├── package.json                  # npm scripts: build, prefetch-images, cap:sync, cap:open
├── scripts/
│   ├── build-www.sh              # Assembles www/ for iOS bundle
│   ├── precompile-babel.js       # Compiles JSX → JS, rewrites remote img URLs to local
│   ├── prefetch-remote-images.js # Downloads all Wikimedia photos, resizes, caches
│   ├── remote-image-manifest.json# URL → local path mapping (committed)
│   └── gen-apple-jwt.js          # Apple OAuth secret JWT generator (legacy from Phase 1b)
├── ios/                          # Generated Xcode project (committed)
│   └── App/App/
│       ├── Info.plist            # CFBundleDisplayName="Pure", URL scheme, etc.
│       ├── Base.lproj/
│       │   └── LaunchScreen.storyboard  # Cream bg + Splash imageset
│       ├── Assets.xcassets/
│       │   ├── AppIcon.appiconset/      # Green P on cream
│       │   └── Splash.imageset/          # Cream + green Pure wordmark
│       └── public/                # Built bundle (gitignored, regenerated from www/)
├── www/                           # Build output (gitignored)
├── images/courses/
│   ├── *.jpg                      # Hand-curated user-uploaded local photos
│   └── remote/                    # 183 prefetched Wikimedia photos (1200px max, q80 JPEG)
└── legal/
    ├── PRIVACY_POLICY.md          # Drafted, needs SUPPORT_EMAIL/COMPANY/ADDRESS filled
    └── APP_STORE_LISTING.md       # Title/subtitle/description/keywords drafted
```

## Key commands

```bash
# Build web bundle + sync to iOS (run after any source change)
npm run cap:sync

# Just download new remote images (incremental, idempotent)
npm run prefetch-images

# Open Xcode for the iOS project
npm run cap:open

# Just rebuild the www/ bundle (no iOS sync)
npm run build
```

After `npm run cap:sync`, in Xcode press **⏹ Stop** then **▶️ Play** to push the new build to device.

## Quirks / gotchas

- **CocoaPods needs UTF-8 locale** — npm scripts already set `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8` (Ruby 4.0/CocoaPods 1.16 incompatibility). If running pod commands manually, prefix with the env vars.
- **`window.supabase` was renamed to `_supabaseClient`** in source so the precompile doesn't redeclare a global. `window.supabase` is reassigned to the authenticated client below for downstream compatibility.
- **`html.is-native` class** is added by an inline `<script>` in index.html when running inside Capacitor. CSS uses this for full-bleed layouts.
- **Web preview** (browser) loads index.html with babel-standalone (live JSX). **iOS** uses precompiled `www/index.html` with the babel-standalone tag stripped + remote img URLs rewritten to local paths. Source stays clean.
- **iOS bundle size: 269MB.** Apple's cellular-download warning at 200MB is the only cost. Not a blocker, but bundle-size CDN trigger memory exists for ~400 courses.

## Phase 2 audit results (still pending)

From the pre-Phase-2 code review (memory: project_prelaunch_qa_backlog.md):
- 🔴 5 BLOCKERS — ✅ all fixed
- 🟠 4 HIGH — 3 fixed, 1 deferred (modal stacking, pending real-device verification)
- 🟡 5 MEDIUM — 1 fixed (course preview persistence), 4 remain
- 🟢 8 LOW — 2 fixed (hydration skeleton, error boundary), 6 remain

## OAuth / Supabase config snapshot

- **Project URL:** `https://kririlpmfsgvgklhykkr.supabase.co`
- **Publishable key:** `sb_publishable_MyKonA4E5WMFUh8BnJ_jWg_t7_Ty43o`
- **OAuth callback:** `https://kririlpmfsgvgklhykkr.supabase.co/auth/v1/callback`
- **Native deep link:** `com.declanobryan.puregolfjournal://callback`
- **Apple Services ID:** `com.declanobryan.puregolfjournal.signin`
- **Apple Team ID:** `L95DKW9826`
- **Apple Key ID:** `K4F69888L9`
- **Google Client ID:** `795522733170-o21q30cfkv3i7p6e5nb3pa2h7dn1r910.apps.googleusercontent.com`
- **Google OAuth:** in **Testing** mode → must flip to Production before launch (see launch TODO #5b)

## Next session immediate priorities

1. Fix Bel-Air photo (find new Wikimedia URL, run `npm run prefetch-images`, sync)
2. Add Big Canyon photo (it has no `img` field at all)
3. Fix the residual horizontal slack on the rating screen sheet on real iPhone
4. Decide on photoType:"regional" auto-removal logic (probably wait until photo gallery feature is built — see launch TODO #5)

## Saved memories that will surface next session

These are in `~/.claude/projects/-Users-declanobryan-Claude/memory/`:
- Pure Golf App overview
- Design preferences
- Production-ready mindset (App Store-bound)
- Photo sourcing rules + HEIC conversion workflow
- New course workflow (NCRDB/R&A tee data)
- Pre-launch TODOs (with backend already done, hosted course JSON pending)
- Feature backlog (Google sign-in done, others pending)
- Apple capabilities (Sign in with Apple done, Push Notifications still pending Phase 3)
- TestFlight beta comms (don't delete TestFlight before App Store launch)
- Pre-launch QA backlog (5 blockers fixed, see above)
- Launch + marketing checklist (waitlist, screenshots, Reddit strategy, custom domain)
- Bundle size CDN trigger (~400 courses)
- USGA NCRDB + R&A handicap calculator (course rating sources)
- Test workflow (test users, reset data button)

## Phases roadmap

- ✅ Phase 1: Backend (Supabase + 3 auth methods)
- ✅ Phase 2: Capacitor wrap + iOS native polish
- 🔜 Phase 3: Native polish — Push Notifications, Status Bar, more haptics, biometrics
- 🔜 Phase 4: Visual polish + final QA pass
- 🔜 Phase 5: TestFlight + App Store submission
- 🔜 Hosted course JSON migration (deferrable but launch TODO #2)
