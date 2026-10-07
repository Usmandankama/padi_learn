-- Takedowns a teacher cannot undo.
--
-- `archived_at` is the teacher's own switch: they hold UPDATE on it, so a
-- course archived by PadiLearn for breaking the rules could be put straight
-- back by its owner. A takedown needs a column no client can write.
--
-- Decided 2026-10-06 (docs/ADMIN_PANEL.md, decision 2): a course removed for a
-- breach stops playing for *everyone* except its owner, including students who
-- paid. Those students are owed refunds, so the takedown reports how many
-- there are. The paywall is enforced in `get-course-video`, which runs as the
-- service role and so never sees RLS; this file only covers what RLS can.

-- ---------------------------------------------------------------------------
-- 1. The columns
-- ---------------------------------------------------------------------------

alter table public.courses
  add column if not exists removed_at timestamptz,
  add column if not exists removed_reason text;

alter table public.courses
  drop constraint if exists courses_removed_reason_check;
alter table public.courses
  add constraint courses_removed_reason_check
  check (
    -- Both or neither: a takedown always says why.
    (removed_at is null) = (removed_reason is null)
    and (removed_reason is null or char_length(removed_reason) <= 1000)
  );

-- ---------------------------------------------------------------------------
-- 2. Nobody but an admin RPC writes them
-- ---------------------------------------------------------------------------
-- UPDATE on `courses` is already column-by-column, so the new columns are not
-- updatable by clients without doing anything. INSERT was still table-wide,
-- which would have let a teacher create a course with `removed_at` set, and
-- has always let one create a course with `enrollments`, `rating_avg` and
-- `rating_count` set to anything (the counters are only recounted when an
-- enrolment or rating changes, so an invented number stuck). Narrowed to the
-- columns create_course_screen.dart actually sends.
--
-- Revoking the table privilege also revokes the column privileges it implied,
-- so the grant below is the complete list. anon never had an INSERT policy;
-- the privilege goes too.

revoke insert on public.courses from anon, authenticated;
grant insert (title, description, price, category, author, thumbnail_url, user_id)
  on public.courses to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Who can still see a removed course
-- ---------------------------------------------------------------------------
-- Same shape as archiving: gone from discovery, but still visible to its owner
-- (who should be able to see what happened to it) and to students enrolled in
-- it, so their library and the player resolve instead of breaking. Playback is
-- refused by `get-course-video`, whose error the player shows as-is. Lessons
-- follow this policy through "Lessons follow course visibility".

drop policy if exists "Courses are viewable by signed-in users" on public.courses;
create policy "Courses are viewable by signed-in users"
  on public.courses for select to authenticated
  using (
    (archived_at is null and removed_at is null)
    or user_id = auth.uid()
    or exists (
      select 1 from public.enrollments e
      where e.course_id = courses.id
        and e.user_id = auth.uid()
    )
  );

-- Admins see everything. A separate permissive policy so the consumer one above
-- stays readable on its own; `(select ...)` makes it one call per query.
drop policy if exists "Admins can see every course" on public.courses;
create policy "Admins can see every course"
  on public.courses for select to authenticated
  using ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- 4. Remove and restore
-- ---------------------------------------------------------------------------
-- Both require a reason, both lock the row, and both refuse a no-op rather
-- than log one, so the audit log only ever shows real changes.

create or replace function public.admin_remove_course(p_course_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_course record;
  v_sales integer;
  v_kobo bigint;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;

  select id, title, user_id, removed_at
    into v_course
    from public.courses
   where id = p_course_id
     for update;
  if not found then
    raise exception 'Course not found' using errcode = 'P0002';
  end if;
  if v_course.removed_at is not null then
    raise exception 'Course is already removed' using errcode = '22023';
  end if;

  -- Everyone who paid just lost access, and is owed a refund. Counted from the
  -- ledger, not from enrolments: free enrolments are owed nothing, and a paid
  -- enrolment's buyer may since have deleted their account.
  select count(*), coalesce(sum(t.amount_kobo), 0)
    into v_sales, v_kobo
    from public.transactions t
   where t.course_id = p_course_id
     and t.status = 'success';

  update public.courses
     set removed_at = now(),
         removed_reason = v_reason
   where id = p_course_id;

  perform public.log_admin_action(
    'course.remove', 'course', p_course_id, v_reason,
    jsonb_build_object(
      'title', v_course.title,
      'owner_id', v_course.user_id,
      'paid_sales', v_sales,
      'paid_kobo', v_kobo
    )
  );

  return jsonb_build_object('paid_sales', v_sales, 'paid_kobo', v_kobo);
end;
$$;

create or replace function public.admin_restore_course(p_course_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_course record;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;

  select id, title, removed_at, removed_reason
    into v_course
    from public.courses
   where id = p_course_id
     for update;
  if not found then
    raise exception 'Course not found' using errcode = 'P0002';
  end if;
  if v_course.removed_at is null then
    raise exception 'Course is not removed' using errcode = '22023';
  end if;

  update public.courses
     set removed_at = null,
         removed_reason = null
   where id = p_course_id;

  -- The takedown being reversed, kept here because the columns are now empty.
  perform public.log_admin_action(
    'course.restore', 'course', p_course_id, v_reason,
    jsonb_build_object(
      'title', v_course.title,
      'removed_at', v_course.removed_at,
      'removed_reason', v_course.removed_reason
    )
  );
end;
$$;

-- Callable by any signed-in user; assert_admin() inside is the gate.
revoke execute on function public.admin_remove_course(uuid, text) from public, anon;
revoke execute on function public.admin_restore_course(uuid, text) from public, anon;
grant execute on function public.admin_remove_course(uuid, text) to authenticated;
grant execute on function public.admin_restore_course(uuid, text) to authenticated;
