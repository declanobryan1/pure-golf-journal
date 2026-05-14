-- ═══════════════════════════════════════════════════════════════════════════
-- 008_quicklog_tag_notifications.sql — Fire tag notifications from imported_rounds too
--
-- Migration 002 added a trigger that fans out 'tag' notifications when a
-- ratings row's played_with changes. But QuickLog-style rounds go through
-- imported_rounds (different table), so tagging a friend in a Quick Log
-- never produced a notification.
--
-- Build 3 fix: mirror the same trigger on imported_rounds so any tagged
-- friend gets pinged regardless of which path the round came from.
--
-- Run order: 008 (after 007_refine_state.sql)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.notify_on_round_tag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tagged jsonb;
  prev   jsonb;
  uid    uuid;
begin
  tagged := coalesce(new.played_with, '[]'::jsonb);
  if (tg_op = 'UPDATE') then
    prev := coalesce(old.played_with, '[]'::jsonb);
  else
    prev := '[]'::jsonb;
  end if;

  if jsonb_array_length(tagged) = 0 then
    return new;
  end if;

  -- For each new tag (in tagged but not in prev), fan out a notification.
  for uid in
    select distinct (value::text)::uuid
    from jsonb_array_elements_text(tagged) as t(value)
    where t.value <> ''
      and not (prev ? t.value)
  loop
    if uid <> new.user_id then
      insert into public.notifications(user_id, type, actor_id, course_id, sub_name)
      values (uid, 'tag', new.user_id, new.course_id, new.sub_name);
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_on_round_tag on public.imported_rounds;
create trigger trg_notify_on_round_tag
  after insert or update of played_with on public.imported_rounds
  for each row execute function public.notify_on_round_tag();
