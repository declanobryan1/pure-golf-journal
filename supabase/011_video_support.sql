-- ═══════════════════════════════════════════════════════════════════════════
-- 011_video_support.sql — Video uploads on ratings + imported_rounds
--
-- Adds a `videos` JSONB column to ratings + imported_rounds. Each entry is
-- a tiny object: {url, thumb, duration, size, created_at} — the actual video
-- file lives in Supabase Storage bucket `pure-media`, not in the DB.
--
-- This file ONLY handles the table schema. The Storage bucket setup is
-- manual via the Supabase Dashboard — see legal/STORAGE_SETUP.md for
-- the step-by-step (can't be done via SQL).
--
-- Run order: 011 (after 010_course_aggregates.sql)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.ratings
  add column if not exists videos jsonb default '[]'::jsonb;

alter table public.imported_rounds
  add column if not exists videos jsonb default '[]'::jsonb;

-- No new index needed — videos are read alongside their parent row.
-- RLS on ratings + imported_rounds already covers the videos field
-- (it's just another column on those tables).
