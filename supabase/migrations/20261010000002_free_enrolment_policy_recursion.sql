-- Free self-enrolment was refused by the database.
--
-- A signed-in student tapping Enrol on a free course got
--
--   ERROR 42P17: infinite recursion detected in policy for relation "enrollments"
--
-- Two row-level security policies read each other:
--
--   "Users can self-enroll in free courses" on enrollments (INSERT) reads
--     courses, to check the price and that the course has been uploaded.
--   "Courses are viewable by signed-in users" on courses (SELECT) reads
--     enrollments, for its "you are enrolled" branch. That branch arrived with
--     20260801000004_course_archiving.sql and every later version kept it.
--
-- Postgres expands policies before it runs anything. Expanding the first it
-- reaches courses, expanding the second it reaches enrollments again, and it
-- refuses on meeting a table twice in one chain. It does not look at whether
-- the inner read would have been harmless (it would: a student's own rows).
-- Paid enrolment never met this, because verify-payment and the webhook write
-- with the service role, which row-level security does not apply to.
--
-- The fix takes the read of enrollments out of the courses policy and puts it
-- behind a function. Who can see which course is unchanged.
--
-- Why this side of the cycle: the enrolment policy reads courses *through*
-- row-level security on purpose. That is what stops a student enrolling in a
-- free course they cannot see (archived, taken down, a suspended teacher's,
-- someone else's draft). Putting that read behind a function instead would
-- mean restating all of those rules in a second place.
--
-- Run after 20261010000001_course_drafts.sql: the policy below keeps that
-- migration's `published_at is not null`. Safe to run twice.
--
-- Careful: 20261010000001 recreates this same policy with the direct read of
-- enrollments. Running that file again after this one brings the bug back;
-- run this one again after it.

-- ---------------------------------------------------------------------------
-- 1. The caller's own enrolments, readable from inside a policy
-- ---------------------------------------------------------------------------
-- Security definer, so the read does not go back through row-level security.
-- It takes no argument and answers only for auth.uid(), which is exactly what
-- "Users can view their own enrollments" already lets the caller read. In
-- `private`, which PostgREST does not expose, so it is not an RPC.
--
-- Returns the set rather than answering "is this user enrolled in course X":
-- a policy that asks per course calls its function once per row of courses,
-- and this is evaluated once per statement.

create or replace function private.my_enrolled_course_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select e.course_id from public.enrollments e where e.user_id = auth.uid();
$$;

revoke execute on function private.my_enrolled_course_ids() from public, anon;
grant execute on function private.my_enrolled_course_ids() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. The courses policy stops reading enrollments directly
-- ---------------------------------------------------------------------------
-- The same three branches as 20261010000001: in the catalogue, or yours, or
-- one you are enrolled in. Only the third is written differently.
-- `alter policy`, so there is no moment without the policy.

alter policy "Courses are viewable by signed-in users" on public.courses
  using (
    (published_at is not null
      and archived_at is null
      and removed_at is null
      and not private.is_suspended(user_id))
    or user_id = (select auth.uid())
    or id in (select private.my_enrolled_course_ids())
  );
