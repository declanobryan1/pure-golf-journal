-- ═══════════════════════════════════════════════════════════════════════════
-- 010_course_aggregates.sql — Global average rating per course
--
-- Build 3: shows "Avg Rating across all users" on course detail. Maintained
-- automatically by a trigger on ratings INSERT/UPDATE/DELETE so the read
-- side is a fast indexed lookup, not an aggregate scan.
--
-- Course catalog itself stays in index.html (in-app COURSES array) for now;
-- the table here only holds the aggregate per course_id. The full catalog
-- migration to Supabase is a build 4 item.
--
-- Run order: 010 (after 009_user_tees_subname.sql)
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.course_aggregates (
  course_id integer primary key,
  avg_rating numeric(3,1),
  rating_count integer not null default 0,
  updated_at timestamptz default now()
);

-- Anyone authenticated can read aggregates (they're already aggregated, no
-- per-user privacy concern).
alter table public.course_aggregates enable row level security;
drop policy if exists "course_aggregates readable to authenticated" on public.course_aggregates;
create policy "course_aggregates readable to authenticated"
  on public.course_aggregates for select
  to authenticated
  using (true);

-- Backfill from existing ratings.
-- Use a property-level avg: for sub-course ratings, we average the sub
-- overalls within the property to get one number per course_id (matches
-- how the in-app rolled-up overall is computed).
insert into public.course_aggregates(course_id, avg_rating, rating_count)
select
  course_id,
  round(avg(per_user_overall)::numeric, 1) as avg_rating,
  count(*)::integer as rating_count
from (
  select course_id, user_id, avg(overall) as per_user_overall
  from public.ratings
  group by course_id, user_id
) t
group by course_id
on conflict (course_id) do update
  set avg_rating = excluded.avg_rating,
      rating_count = excluded.rating_count,
      updated_at = now();

-- Trigger function: recompute aggregate for the affected course_id(s).
create or replace function public.refresh_course_aggregate(p_course_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg numeric;
  v_cnt integer;
begin
  select round(avg(per_user_overall)::numeric, 1), count(*)::integer
    into v_avg, v_cnt
  from (
    select user_id, avg(overall) as per_user_overall
    from public.ratings
    where course_id = p_course_id
    group by user_id
  ) t;

  if v_cnt is null or v_cnt = 0 then
    delete from public.course_aggregates where course_id = p_course_id;
  else
    insert into public.course_aggregates(course_id, avg_rating, rating_count, updated_at)
    values (p_course_id, v_avg, v_cnt, now())
    on conflict (course_id) do update
      set avg_rating = excluded.avg_rating,
          rating_count = excluded.rating_count,
          updated_at = excluded.updated_at;
  end if;
end;
$$;

create or replace function public.on_rating_change_aggregate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (tg_op = 'DELETE') then
    perform public.refresh_course_aggregate(old.course_id);
    return old;
  end if;
  perform public.refresh_course_aggregate(new.course_id);
  -- If course_id changed (rare), refresh the old one too.
  if (tg_op = 'UPDATE' and old.course_id is distinct from new.course_id) then
    perform public.refresh_course_aggregate(old.course_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_rating_aggregate on public.ratings;
create trigger trg_rating_aggregate
  after insert or update or delete on public.ratings
  for each row execute function public.on_rating_change_aggregate();
