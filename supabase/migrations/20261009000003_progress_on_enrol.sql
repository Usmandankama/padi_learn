-- Count lessons finished before the course was bought.
--
-- A student can finish a course's free preview lesson before paying. The
-- course percentage on `enrollments` is recomputed only when `lesson_progress`
-- changes, and when the preview was watched there was no enrolment to update,
-- so a newly bought course showed 0% until another lesson was finished.
--
-- recompute_enrollment_progress() reads user_id and course_id from NEW (OLD is
-- null on an insert), and `enrollments` has both, so the same function
-- recomputes the new row. Its UPDATE does not fire this trigger again: it is
-- on INSERT only.

drop trigger if exists on_enrollment_created_recompute_progress on public.enrollments;
create trigger on_enrollment_created_recompute_progress
  after insert on public.enrollments
  for each row execute function public.recompute_enrollment_progress();
