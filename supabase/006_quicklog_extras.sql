-- ═══════════════════════════════════════════════════════════════════════════
-- 006_quicklog_extras.sql — Persist photos, note, and played-with on rounds
--
-- Previously dbWriteImportedRound silently dropped these fields because
-- imported_rounds had no columns for them. Users uploaded photos, wrote
-- notes, and tagged friends in QuickLog — none of it survived save.
--
-- Run order: 006 (after 005_privacy.sql)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.imported_rounds
  add column if not exists photos jsonb default '[]'::jsonb,
  add column if not exists note text,
  add column if not exists played_with jsonb default '[]'::jsonb;

-- No new index needed — these are read with the row, never queried directly.
-- RLS on imported_rounds is already owner-only, which covers these fields.
