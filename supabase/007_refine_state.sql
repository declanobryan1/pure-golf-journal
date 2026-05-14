-- ═══════════════════════════════════════════════════════════════════════════
-- 007_refine_state.sql — Persist refine-flow state across sessions
--
-- The "Pause (save progress)" button on the refine flow promises to save
-- progress, but refineState was useState-only — paused index + earlyRefs
-- vanished on every reload. This adds a JSONB column to store the full
-- refineState shape: {earlyRefs, promptStage, pausedIndex}.
--
-- Run order: 007 (after 006_quicklog_extras.sql)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.users
  add column if not exists refine_state jsonb default null;

-- Owner-only: covered by existing users update policy
-- (only the user can update their own row).
