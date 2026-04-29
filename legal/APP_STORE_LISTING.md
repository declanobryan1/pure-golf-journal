# App Store Listing Copy — Pure Golf Journal

This file holds the copy you'll paste into App Store Connect when submitting Pure. Each section maps to a specific field in the submission form.

> **Reviewer note for Declan:** Read these out loud once. If anything feels off, flag it — we can iterate. The "Description" is the most important; that's what users see first. The "Subtitle" sells it in 30 chars.

---

## App Name (30 char max)
```
Pure Golf Journal
```
17 chars — comfortably under the limit. Already matches your Apple Developer + Bundle ID setup.

---

## Subtitle (30 char max)
**Recommended:**
```
Rate, score, journal every round
```
30 chars exact — describes the three core features.

**Alternates if you want a different angle:**
```
Your golf rating journal
```
*(23 chars — simpler, leans on "Pure" doing the descriptive work)*

```
Track every course you play
```
*(26 chars — score-focused angle)*

---

## Promotional Text (170 char max — can update without app review)
```
The journal for golfers who care about the courses they play. Rate every track, log every score, build your handicap. No ads, no clutter, no nonsense.
```
153 chars. This is the field above the description that you can update anytime — useful for seasonal pushes ("Masters week is here…").

---

## Description (4000 char max)

```
Pure Golf Journal is a thoughtful place to record everything about the courses you play.

Rate the layout. Log your scores. Track your handicap. Build a record of your golf life — not for likes, not for leaderboards, just for yourself and the people who actually play with you.

WHY GOLFERS LOVE PURE

• Rate any course on a 1–10 scale using head-to-head comparisons. The math figures out where each course belongs in your personal ranking — no spreadsheets required.

• Log scores in seconds. Quick Log captures a round in three taps. Add tees, photos, and playing partners when you want to.

• Real handicap tracking. Pure calculates your handicap from the rounds you log, including imported scores from your handicap service via CSV.

• A bucket list for the courses you haven't played yet. Add as you go.

• Find your next round. Discover tab surfaces courses near you, courses your friends loved, and the most-rated courses across Pure.

• Friends without the noise. Follow people you actually golf with. See their ratings and scores. React with quick emojis. No follower counts, no algorithm.

CARE WENT INTO THE DETAILS

• Course data is sourced from real published scorecards and handicap-service ratings — not made up.

• Photos are sourced respectfully — Wikimedia, course tournaments, real photography of the course or its region. No random stock golf images.

• Your data is yours. Sign in with Apple, Google, or email. Export anytime. Delete anytime.

• No ads. Ever. No tracking. No selling your data.

THE COURSES YOU KNOW

Hundreds of courses are pre-loaded — from Augusta to Bandon to your local muni. Don't see yours? Request it from inside the app and we'll add it.

PROUDLY MADE BY ONE GOLFER

Pure was built by a golfer who got tired of journaling rounds in Notes and rating courses on a napkin. If you have ideas, send them — every email gets a reply.

—

Pure does NOT use:
• Background location
• Health, motion, or fitness data
• Your contacts
• Push notifications without permission
• Any analytics or tracking SDKs

What Pure DOES use:
• Your account info (email, username)
• Photos you upload to courses or rounds
• Round + rating data you create

Read our privacy policy at [PRIVACY_POLICY_URL_TBD].
```
~2400 chars — well under the 4000 limit, leaves room to add more later. Hits these emotional beats: thoughtful, anti-algorithm, anti-ads, made-by-a-golfer.

---

## Keywords (100 char max — comma-separated, no spaces around commas)

**Recommended:**
```
golf,golf course,golf rating,golf journal,golf tracker,handicap,scorecard,golf score,golf log
```
93 chars. Notes:
- "golf" alone is too competitive but has to be there
- "golf course rating" is your best long-tail (low competition)
- "golf journal" is unique to your positioning
- Don't repeat words across phrases (Apple counts each word once anyway)

---

## Support URL (required)
```
[SUPPORT_URL_TBD — set up before submission]
```
Options:
- Personal site or Notion page with a "Pure Support" section
- Custom domain like `puregolfjournal.com/support` or `support.puregolfjournal.com`
- Even a simple page hosted on GitHub Pages works fine for v1

---

## Marketing URL (optional)
```
[MARKETING_URL_TBD]
```
The main app website. Same domain as Support is fine.

---

## Privacy Policy URL (required)
```
[PRIVACY_POLICY_URL_TBD]
```
Host the privacy policy markdown (in `legal/PRIVACY_POLICY.md`) somewhere public. Options:
- GitHub Pages (free, fastest setup): https://yourusername.github.io/pure-golf-journal/privacy
- Custom domain: https://puregolfjournal.com/privacy
- Notion page made public: https://www.notion.so/PRIVACY/...

---

## Category

**Primary:** Sports
**Secondary:** Lifestyle

(Apple lets you pick a primary + one secondary — Sports is the obvious primary; Lifestyle picks up the journal/personal-record angle and exposes you to a different recommendation pool.)

---

## Age Rating

**4+** — no age-gated content. The age rating wizard in App Store Connect will ask about violence, drugs, gambling, mature themes — answer "None" to all.

---

## What's New (release notes — required for every version)

**For v1.0 (initial release):**
```
Welcome to Pure Golf Journal — a thoughtful place to record every course you play.

Sign in, rate your home course, and start building your golf life.

Find a bug or have a feature request? Email us — every message gets a real reply.
```

---

## Screenshots (required, 6.7" iPhone display = 1290 × 2796 px)

You need **3–10 screenshots** showing the core value. Suggested order:

1. **Clubhouse home** — shows your courses-played count, home course, friend activity. Sells the "your golf life" angle.
2. **A rating in progress** — head-to-head comparison screen. Sells the unique rating mechanic.
3. **Course detail** — a hero photo + your rating + sub-course breakdown. Sells the depth of data.
4. **Quick Log a round** — score input. Sells the speed.
5. **My Courses list** — a bunch of rated courses. Sells the journal feel.
6. **Profile + handicap** — your handicap card + activity stats. Sells the tracking.

**Screenshot tips:**
- Use a real-looking demo account with 10–20 ratings populated, not 1
- Show course names users will recognize: Pebble, Augusta, your local muni, etc.
- Use the iPhone 15 Pro Max simulator for screenshots — that's the 6.7" device Apple wants
- Tools that help: `xcrun simctl io booted screenshot screenshot.png` from terminal, or Xcode's built-in screenshot button

You can update screenshots anytime without re-review.

---

## App Preview Video (optional, but high-converting)

A 15–30 second video showing the rating flow + scoring flow. Optional for v1 but **massive conversion lift** — apps with previews convert ~25% better. Add it as a v1.1 update if not ready for launch day.

---

## Notes for Submission

- **Sign in with Apple is required** by Apple guideline 4.8 since you offer email + Google login. ✅ Already done.
- **Privacy labels** in App Store Connect — see `legal/PRIVACY_LABELS_GUIDE.md` (TODO: I haven't drafted this yet — Declan, ping me when you start submission and we'll fill out the privacy questionnaire together).
- **Encryption export compliance** — Pure uses standard HTTPS only (no custom crypto), so this is "exempt." Answer "No" to "Does your app use encryption?" or "Yes" + the standard exemption (option 2: only uses HTTPS).
