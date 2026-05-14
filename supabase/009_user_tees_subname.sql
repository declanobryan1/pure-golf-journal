-- ═══════════════════════════════════════════════════════════════════════════
-- 009_user_tees_subname.sql — Scope saved tees per sub-course
--
-- Bethpage Black saved tees were bleeding into Bethpage Red's TeePicker
-- because user_tees was keyed only by (user_id, course_id, tee_name).
-- Adds sub_name + new unique key so each sub-course property can have
-- its own saved tees per user.
--
-- Run order: 009 (after 008_quicklog_tag_notifications.sql)
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.user_tees
  add column if not exists sub_name text;

-- Drop the old unique constraint so we can re-add with sub_name included.
alter table public.user_tees
  drop constraint if exists user_tees_user_id_course_id_tee_name_key;

-- New unique: same tee_name CAN exist on different sub-courses.
-- Use a partial unique index for the (sub_name IS NULL) case so single-course
-- properties still uniqueness-check correctly.
create unique index if not exists user_tees_uniq_sub
  on public.user_tees(user_id, course_id, sub_name, tee_name)
  where sub_name is not null;

create unique index if not exists user_tees_uniq_main
  on public.user_tees(user_id, course_id, tee_name)
  where sub_name is null;

-- Existing rows have sub_name=null; they remain valid as "main course" tees.
-- Client falls back to main-course tees when no per-sub entry exists, so
-- legacy data continues to work for single-course properties.
