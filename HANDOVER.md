# Pure Golf Journal — Handover

**Project:** Single-file React 18 + Babel PWA at `/Users/declanobryan/Claude/index.html`
**Goal:** Ship on the App Store — production-ready mindset throughout.

Persistent context already lives in memory files at `~/.claude/projects/-Users-declanobryan-Claude/memory/` — a fresh session will auto-load MEMORY.md which indexes:
- Pure Golf App overview · Design preferences · Production-ready mindset · Photo sourcing rules · Pre-launch TODOs · Feature backlog
- Reference: USGA NCRDB (ncrdb.usga.org) for US tee data, R&A calculator (randa.org/en/course-handicap-calculator) for international
- Feedback rule: when adding a new course, always populate `tees[]` via NCRDB/R&A as part of the standard entry process

---

## Catalog state

- **226 courses** total, IDs 1–226 (missing IDs 21 and 44 — deleted historically)
- **~160 `tees[]` arrays populated** across top-level and sub-course entries
- Multi-course properties fully covered (all subs have tees): Bethpage, Pinehurst (flagship), Kiawah, Bandon, Oakland Hills, Baltusrol, Medinah, Oak Hill, Winged Foot, Merion, Streamsong, Pelican Hill, Newcastle (Coal Creek)
- Home course baseline is excluded from handicap calc (`if(r.isHomeCourse)return;` filter in `getRoundsFromRatings`)

## Tee data gaps (for future batches)

**US still outstanding:** most are minor/muni; high-value remainders are mostly international

**International without USGA/WHS-format data publicly available:**
- Augusta National, Ohoopee (private, no public ratings)
- Sunningdale Old/New (R&A provides rating/slope but no yardage)
- Most Ireland/UK secondary courses (Lahinch Castle, Royal Portrush Valley, RCD Annesley, Portmarnock, Tralee, Waterville, Prestwick, Cruden Bay, Machrihanish, Old Head, County Louth, Portstewart, Enniscrone)
- Australia: NSW GC, Royal Adelaide, Victoria, Ellerston, Metropolitan, The Lakes, Tara Iti, Jack's Point
- Japan: Hirono, Tokyo GC, Naruo, Kawana Fuji
- Europe: Morfontaine, Valderrama, Le Golf National, Les Bordes (only flagship done), Falsterbo, Halmstad, PGA Catalunya
- Africa: Leopard Creek, Durban CC, Sun City Lost City
- Other: Shanqin Bay, Mission Hills Shenzhen, Aphrodite Hills, Cabot Saint Lucia, Te Arai N/S, Koninklijke Haagsche, Utrecht de Pan, Nine Bridges, Cape Wickham, Lofoten, Cabot Highlands Old Petty

**Workflow for next batches:** the agent-based research pattern works well. Dispatch with specific source priorities (NCRDB → R&A → BlueGolf/GolfLink → club PDFs → flag honestly if not found). Apply per sub-course for multi-course properties.

## Recent architectural changes (this session)

### TeePicker refactor
- Accepts `course`, `subName`, `userTees`, `value`, `onChange` props
- For multi-course properties, reads `course.subcourses[n].tees` when `subName` matches, falls back to `course.tees`
- "Enter rating & slope" manual fallback includes Tee Name input
- Renders yardage as optional display (`opt.yardage?` conditional)
- Fixed a subtle bug: `selectedKey` was checking `value._source` but select stores `value.source` — one-char fix, was causing pills to not appear selected after tap

### Rating flow additions
- All 3 rating flows (FirstImpressionModal, BaselineRatingModal, HeadToHeadModal) accept `userTees`
- Each flow now uses a `tee` state (replaced the old `userRating`/`userSlope` raw inputs)
- `RoundFields` shows the TeePicker only when a shot score has been typed: "Tees Played (optional) — Pick your tees for a more accurate handicap estimate. We'll remember them next time."
- Save payload includes `{teeName, courseRating, slope, tee}` from the tee object
- `saveRating` now persists manual tees to `profile.userTees[courseId]` so they appear in the picker next visit
- `getRoundsFromRatings` prefers user-entered `courseRating`/`slope` over course defaults

### QuickLog modal
- Now searches ALL courses, not just rated (rated sort to top, unrated show a "NOT RATED" chip)
- After save at an unrated course, a small bottom-center popup appears: "Rate [Course Name]?" with "Not now" / "Rate it" buttons (portal, z-index 190)
- Sub-course picker renders when the selected course has `subcourses`
- Modal z-index bumped from 110 → 180 (fixes it being hidden behind SettingsView which is z-150)

### Handicap page (scores Sheet)
- Per-round list no longer shows "Imported" or "GHIN" badges (removed entirely)
- Home course baseline hidden from rounds list (`if(r.isHomeCourse)return;`)
- Three round-logging buttons added: Quick Log (opens QuickLogModal), Add Round (opens Settings→manual), Add Multiple (opens Settings→batch)
- SettingsView accepts `initialModal="manual"|"batch"|"handicap"` prop and auto-opens on mount; when that modal closes, auto-calls `onBack()` to return to handicap page (not leave user stranded in Settings)

### Other UX
- "Personal Best" label (instead of "Shot") shown on: home course rating, any course with 2+ rounds, Best Round card on profile
- `@supports (-webkit-touch-callout:none)` CSS rule forces inputs to 16px on iOS only → prevents zoom-on-focus that was making the Quick Log modal feel pannable/draggable
- GHIN references scrubbed throughout UI and comments (legal/trademark safety). Internal state variable names like `ghinRounds`, `ghinError`, `source:"ghin"` intentionally left (not user-visible, refactor too invasive for the benefit)
- Country flags added: Costa Rica 🇨🇷, Saint Lucia 🇱🇨

### Photo work (per photo sourcing rules in memory)
Recently updated: Merion, Casa de Campo, Childress Hall, Old Town Club, Omni La Costa, Sand Valley, Shoreacres, Strawberry Farms, Paraparaumu Beach, Southern Hills crop. 6–8 new-catalog courses still have no photo (Old Town → Reynolda Gardens area, Casa de Campo → La Romana coastline, etc.)

### 24 new courses added (IDs 203–226)
Trump National LA · Southern Hills · Shoreacres · Sand Valley Resort · Oak Hill · Childress Hall · Old Town Club · CapRock Ranch · Myopia Hunt · Rock Creek Cattle · California GC of SF · Sunningdale · Swinley Forest · St. George's Hill · Woodhall Spa · Rye · Lofoten · Cabot Saint Lucia · Te Arai · Koninklijke Haagsche · Casa de Campo · Nine Bridges · Utrecht de Pan · Cape Wickham. All have entries + facts. Most have tees (US + a few international).

## Known issues / flagged items

- **Bethpage Red course** — agent data flagged as "anomalous" in one batch; currently populated but worth verifying against NCRDB directly
- **Ballybunion, Lahinch Castle, Royal Portrush Valley, RCD Annesley, Cape Wickham, Cabot Highlands Old Petty** — couldn't find reliable WHS rating/slope yet (R&A has rating/slope but doesn't publish yardage; have to cross-ref each club's scorecard)
- **Several new international courses** still use area/adjacent Wikimedia photos rather than course-specific (flagged pre-launch)

## Open questions / next obvious work

1. **More tee batches** — Cabos/Mexico resort courses (Cabo Real, El Cortés, Reserva Conchal, Hacienda Pinilla, Solmar), Pinehurst subs 1/3/5/6/7, Cowboys Golf / Lions Muni
2. **Course data migration to hosted JSON** — top pre-launch TODO (surfaces when user mentions launch/submission)
3. **Course request feature** — deferred until backend
4. **Crowdsourced tee data consolidation** — deferred until backend (see feature backlog memory)
5. **Pinehurst subcourses No. 1/3/5/6/7** — no tees yet (No. 2/4/8/9/10 done)
6. **Augusta National** — no public rating data; skip or fake-it-with-Masters-setup?

---

## How to start a new chat with this context

Paste this into the new session:

> I'm continuing work on Pure Golf Journal. Check memory first (MEMORY.md and its linked files), then read `/Users/declanobryan/Claude/HANDOVER.md` for recent session state. The catalog is at `/Users/declanobryan/Claude/index.html`. Use NCRDB for US tee data and R&A calculator for international.

That plus the memory files gives the new session everything it needs.
