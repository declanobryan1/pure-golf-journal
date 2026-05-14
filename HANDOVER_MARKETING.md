# Pure Golf Journal — Marketing Handover

**Last updated:** 2026-05-06
**Purpose:** Standalone context for a marketing-focused chat. No engineering work expected here.
**Repo root:** `/Users/declanobryan/Claude/` (mostly irrelevant for marketing — included for reference)

---

## What is Pure?

**Pure Golf Journal** (display name: **Pure**) is an iOS app for golfers to:
- Rate every course they play (the central loop)
- Log rounds + track handicap
- Follow friends, see their activity
- Build a personal "course collection"

Think Letterboxd, but for golf courses. Photography-forward, elegant typography, designed for golfers who care about course architecture — not score-obsessed launch-monitor types.

---

## Current stage

- **Phase:** First TestFlight build uploaded 2026-05-06, processing on Apple's side
- **App Store launch:** Not yet scheduled — after internal beta + external beta + App Review
- **Realistic public launch:** weeks away, not days
- **Marketing should start NOW** so there's a warm audience by App Store launch day

---

## Brand identity

| Element | Value |
|---|---|
| Vibe | Photography-forward, elegant, considered. Not bro-y, not stat-obsessed. |
| Typography | Elegant serif (script "P" wordmark) |
| Color palette | Cream `(245, 240, 232)` background, deep green accents |
| Logo | Script "P" in green on cream — opaque, used as app icon |
| Reference apps | Letterboxd (for the rating-things-you-experienced loop), Strava (for friends/social) |
| Anti-references | DECADE, Arccos, 18Birdies (too data-heavy, too commercial) |

---

## Target audience

**Primary:** Golfers who care about course architecture and travel to play notable courses. The "course collector" archetype.
- r/coursecollectors is the bullseye subreddit
- People who follow @no_laying_up, @fried_egg_golf, @top100golfcourses
- Tournament-watchers who can name 50+ courses

**Secondary:** Casual golfers who play the same 3–5 local courses but love the idea of remembering every round.

**Not the audience:** Pure score-trackers, swing-improvement obsessives, simulator nerds.

---

## Key value props (use these in copy)

1. "Rate every course you play."
2. "Your golf, journaled."
3. "Track your handicap. Remember every round."
4. "Built for golfers who collect courses."

---

## Marketing infrastructure — what exists vs what's missing

### Drafted / done
- App Store listing copy: title, subtitle, description, keywords → `/Users/declanobryan/Claude/legal/APP_STORE_LISTING.md`
- Privacy policy + terms drafted (need a domain to host them)
- App icon (cream + green script P, opaque, App Store ready)
- The app itself is photogenic — every course detail page = a usable Instagram asset

### Still missing (in priority order)
1. **Domain** (`puregolf.app`, `puregolfjournal.com`, or similar — ~$15/yr)
2. **Landing page** — privacy policy + waitlist + "coming soon" badge. Framer template ~4hr build
3. **Waitlist** — Tally.so form, name + email only
4. **Support email** — `puregolfjournal@gmail.com` works, or `hello@` on the new domain via Cloudflare Email Routing
5. **Killer App Store screenshots** — 5–8 with text overlay captions ("Rate every course", "Track your handicap"). Real iPhone 17 Pro Max screenshots from a populated demo account, not empty install
6. **Instagram presence** (see below)
7. **PostHog analytics** wired into the app (engineering task — flag to other chat)
8. **Reddit karma building** — start commenting on r/golf now so when you post about Pure later, you're not flagged as a self-promoter

---

## Instagram strategy (discussed 2026-05-06)

### Timing
**Start NOW**, while TestFlight is processing. You need 3–4 weeks of baseline content + followers so launch-day posts hit a warm audience. Algorithm rewards consistency over time, not a single big day.

Sequence:
- **This week** → set up @puregolfjournal, bio with waitlist link, 3 polished launch posts
- **Next 3–4 weeks (TestFlight beta)** → post 3×/week, build to 200–500 followers
- **Launch day** → coordinated post + Reels + Stories with App Store link

### What to post

1. **"Course of the day" carousels** — single course, 3–5 photos, 1 fact, "rate this on Pure" CTA. App's photo library is already curated and Wikimedia-licensed
2. **Reels of the app in action** — 15s screen recordings of logging a round, tapping through a course detail page. Animations + photography read well on phone
3. **Course architecture posts** — overlap with r/coursecollectors audience. "Why the road hole at St Andrews works" content
4. **Build-in-public** — single founder, ship to App Store, niche but golf+tech crowd loves it

### Format priority
Reels >>> Carousels >>> Static. Reels get 5–10× the reach of static posts. Don't waste time static-only.

### Hashtags / tagging
- Tag courses themselves — they often repost, free reach
- Tag publications: @golfdigest, @golfmagazine, @no_laying_up, @fried_egg_golf, @top100golfcourses
- `#golfcoursearchitecture #linksgolf #publicgolf #golfcoursecollector` — niche tags > mega tags

### Bio + CTA
- Bio: "Rate every course you play. Coming soon to iOS."
- Link in bio → waitlist landing page (depends on landing page existing first)
- Story highlights: "Sneak peek" (screenshots), "Courses" (featured), "Beta" (TestFlight invite for select followers)

---

## Reddit strategy (saved earlier)

**Why:** r/golf has 2M+ subscribers. Strict on self-promotion — direct ads = ban.

**The Pure-specific play:**
- Spend 2–3 weeks BEFORE launch genuinely participating (comment, contribute, build karma)
- When posting Pure, lead with the problem ("I got tired of journaling rounds in Notes…") not the product
- Story format: "Here's what I built for myself, want to share"
- Screenshots prominent, App Store link last
- Other good subs: r/golfing, r/coursecollectors

**When:** Day 1 public App Store launch (NOT TestFlight launch — boost only triggers on App Store).

---

## Day-1 launch playbook (when App Store goes live)

Cluster everything into a 48-hour window, not weeks. Algorithms reward concentration.

- **Hour 0** — Instagram launch post (carousel: 3 screenshots + value prop), Reel of app in action
- **Hour 0** — Email the waitlist with App Store link
- **Hour 0** — Reddit posts to r/golf, r/coursecollectors, r/golfing (one per sub, spaced 4hr apart)
- **Hour 0–48** — Story takeover (BTS, "we're live," screenshots, user reactions if any)
- **Hour 24** — Twitter/X thread if you have a presence there (low priority if you don't)
- **Hour 48** — Recap post on Instagram, thank waitlist signups

---

## Skip until later (don't pre-build)

- **Email automation sequences** — wait until v1.5+, hundreds of users
- **Dedicated feedback board** (Canny, Featurebase) — TestFlight built-in feedback + in-app course requests + Settings → Send Feedback are sufficient until 50+ active users
- **TikTok** — golf audience is older, Instagram + Reddit > TikTok for this niche
- **Paid ads** — wait until you have organic conversion data from PostHog

---

## Things NOT to do

- Don't post on r/golf until you've built karma — instant ban risk
- Don't use generic "play the best golf of your life" copy — Pure is for journaling, not improvement
- Don't run paid ads before you can measure conversion (PostHog must ship first)
- Don't tell beta testers to delete TestFlight before App Store launch — they should keep it installed for seamless transition (saved as `project_testflight_beta_comms.md`)
- Don't use random/generic golf stock photos — Pure's whole brand is course-specific photography. If you wouldn't put it in the app, don't put it on Instagram
- Don't promise features that aren't built (keep messaging tight to what ships in 1.0)

---

## Memory pointers (key context)

The user's persistent memory lives at `~/.claude/projects/-Users-declanobryan-Claude/memory/`. Most relevant for marketing:

- `project_pure_golf_app.md` — app overview
- `project_launch_marketing_checklist.md` — full launch checklist (waitlist, screenshots, analytics, Reddit)
- `project_testflight_beta_comms.md` — beta tester communication rules
- `project_share_universal_links.md` — share-link infrastructure (replaces netlify before App Store)
- `user_design_preferences.md` — values polish, photography-forward, elegant fonts
- `feedback_photo_sourcing.md` — course-specific > area > aerial; never random generic
- `project_apple_capabilities.md` — Sign in with Apple + Push Notifications enabled

The full index is in `~/.claude/projects/-Users-declanobryan-Claude/memory/MEMORY.md`.

---

## Engineering handover (separate)

If anything in this marketing chat needs an engineering change (analytics wiring, landing page hosting on the same domain, in-app banners, etc.), flag it to the engineering chat. Engineering context is in `/Users/declanobryan/Claude/HANDOVER_TESTFLIGHT.md`.

---

## Quick "where do I start?" for new marketing chat

1. Has a domain been bought yet? If no → start there, everything else depends on it
2. Has the landing page been built? If no → second priority, hosts privacy policy + waitlist
3. Has @puregolfjournal Instagram been set up? If no → third priority, can run in parallel with above
4. Are App Store screenshots done? If no → highest-leverage single asset for conversion
5. Reddit karma building started? If no → start commenting on r/golf today

When all 5 are in motion → execute the day-1 launch playbook on App Store approval day.
