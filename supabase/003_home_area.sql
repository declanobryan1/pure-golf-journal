-- ============================================================================
-- 003 — home_area column
-- ----------------------------------------------------------------------------
-- Lets a user without a home course still get accurate "Courses Near You"
-- suggestions. Stores a curated metro/state key (e.g. "los-angeles", "ca").
-- The frontend resolves the key to lat/lng via a static HOME_AREAS table.
-- ============================================================================

alter table public.users
  add column if not exists home_area text;
