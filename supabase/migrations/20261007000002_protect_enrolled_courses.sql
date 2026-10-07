-- A teacher cannot delete a course that has students (docs/ADMIN_PANEL.md,
-- item 4, "known gaps").
--
-- `enrollments.course_id` cascades, so deleting a course silently removes
-- every student's access, including access they paid for. The app has always
-- refused (course_service.dart: "Archive it instead"), but only the app: a
-- hand-made API call could still do it, and leave its buyers owed refunds
-- against a course that no longer exists.
--
-- Scoped to a signed-in user deleting through the API, deliberately:
--   - Deleting an account (the delete-account function, via Supabase Auth)
--     removes the teacher's courses by cascade. A teacher whose only students
--     enrolled free must still be able to delete their account, which Google
--     Play requires; delete-account already refuses when students paid.
--   - The SQL editor and the service role are unaffected, so PadiLearn can
--     still remove a course by hand if it ever has to.
--
-- A trigger rather than a policy because it must see enrolments the teacher
-- cannot (RLS shows each user their own only), and because a refused delete
-- should say why. A policy would just match no rows.

create or replace function private.refuse_deleting_enrolled_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Who is asking: the request's role, not current_user, which inside a
  -- security definer function is always the owner. nullif because a
  -- connection that once carried a request reads back '' rather than null,
  -- and ''::jsonb would throw on every delete there, account deletion's
  -- cascade included. auth.jwt() guards the same way.
  if coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb
                ->> 'role', '') = 'authenticated'
     and exists (select 1 from public.enrollments e where e.course_id = old.id)
  then
    raise exception 'This course has students. Archive it instead so they keep their access.'
      using errcode = '23503';
  end if;
  return old;
end;
$$;

revoke execute on function private.refuse_deleting_enrolled_course() from public, anon, authenticated;

drop trigger if exists before_course_delete_keep_students on public.courses;
create trigger before_course_delete_keep_students
  before delete on public.courses
  for each row execute function private.refuse_deleting_enrolled_course();
