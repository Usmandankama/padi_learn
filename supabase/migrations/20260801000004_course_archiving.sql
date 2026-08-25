-- Course archiving.
--
-- Deleting a course cascades to `enrollments`, which silently destroys the
-- access of every student who paid for it. Archiving replaces deletion as the
-- normal "take it down" action: the course disappears from the marketplace, but
-- anyone already enrolled keeps what they bought.

alter table public.courses
  add column if not exists archived_at timestamptz;

-- Teachers may set/clear it; the column list is explicit because the table-level
-- UPDATE grant was revoked in 20260801000002.
grant update (archived_at) on public.courses to authenticated;

-- Archived courses are hidden from discovery but stay visible to their owner
-- (so they can be un-archived) and to students who already enrolled (so the
-- course still resolves in "Continue learning" and the player).
drop policy if exists "Courses are viewable by signed-in users" on public.courses;
create policy "Courses are viewable by signed-in users"
  on public.courses for select to authenticated
  using (
    archived_at is null
    or user_id = auth.uid()
    or exists (
      select 1 from public.enrollments e
      where e.course_id = courses.id
        and e.user_id = auth.uid()
    )
  );

-- Marketplace listings filter on this constantly.
create index if not exists courses_archived_at_idx
  on public.courses (archived_at)
  where archived_at is null;
