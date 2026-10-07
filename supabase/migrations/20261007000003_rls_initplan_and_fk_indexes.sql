-- Performance tidy-up before traffic (docs/ADMIN_PANEL.md, item 9 note).
--
-- Two findings from Supabase's performance advisor, mostly older than the
-- admin panel. Neither changes what anyone can see or do.
--
-- 1. 27 RLS policies called auth.uid() bare, so Postgres evaluated it once per
--    row. Wrapped as (select auth.uid()) it becomes an InitPlan, evaluated
--    once per statement. Same value, same rules: the only change to each
--    expression below is that wrapping. The statements were generated from
--    the live pg_policies text, not retyped, and checked by comparing what
--    every account can see before and after.
--
-- 2. 14 foreign keys had no index, so a delete on the referenced table, or a
--    join on the key, scans the referencing table.
--
-- Left alone: the advisor's "multiple permissive policies" on courses,
-- lessons and transactions. Those are separate rules on purpose (an admin's,
-- a teacher's, a buyer's) and cost little at this size.

-- ---------------------------------------------------------------------------
-- 1. auth.uid() once per statement
-- ---------------------------------------------------------------------------

alter policy "Categories are readable" on public.categories
  using ((is_active OR (suggested_by = (select auth.uid()))));

alter policy "Teachers can suggest categories" on public.categories
  with check (((is_active = false) AND (suggested_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = (select auth.uid())) AND (p.role = 'Teacher'::text))))));

alter policy comments_delete_author_or_owner on public.course_comments
  using (((user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = course_comments.course_id) AND (c.user_id = (select auth.uid())))))));

alter policy comments_insert_self_enrolled_or_owner on public.course_comments
  with check (((user_id = (select auth.uid())) AND ((EXISTS ( SELECT 1
   FROM enrollments e
  WHERE ((e.course_id = course_comments.course_id) AND (e.user_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = course_comments.course_id) AND (c.user_id = (select auth.uid()))))))));

alter policy comments_select_enrolled_or_owner on public.course_comments
  using (((EXISTS ( SELECT 1
   FROM enrollments e
  WHERE ((e.course_id = course_comments.course_id) AND (e.user_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = course_comments.course_id) AND (c.user_id = (select auth.uid())))))));

alter policy comments_update_author_or_owner on public.course_comments
  using (((user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = course_comments.course_id) AND (c.user_id = (select auth.uid())))))))
  with check (((user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = course_comments.course_id) AND (c.user_id = (select auth.uid())))))));

alter policy "Enrolled users can add their own rating" on public.course_ratings
  with check ((((select auth.uid()) = user_id) AND (EXISTS ( SELECT 1
   FROM enrollments e
  WHERE ((e.course_id = course_ratings.course_id) AND (e.user_id = (select auth.uid())))))));

alter policy "Enrolled users can update their own rating" on public.course_ratings
  using (((select auth.uid()) = user_id))
  with check ((((select auth.uid()) = user_id) AND (EXISTS ( SELECT 1
   FROM enrollments e
  WHERE ((e.course_id = course_ratings.course_id) AND (e.user_id = (select auth.uid())))))));

alter policy "Users can delete their own rating" on public.course_ratings
  using (((select auth.uid()) = user_id));

alter policy "Courses are viewable by signed-in users" on public.courses
  using ((((archived_at IS NULL) AND (removed_at IS NULL) AND (NOT private.is_suspended(user_id))) OR (user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM enrollments e
  WHERE ((e.course_id = courses.id) AND (e.user_id = (select auth.uid())))))));

alter policy "Teachers can delete their own courses" on public.courses
  using (((select auth.uid()) = user_id));

alter policy "Teachers can insert their own courses" on public.courses
  with check ((((select auth.uid()) = user_id) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = (select auth.uid())) AND (p.role = 'Teacher'::text))))));

alter policy "Teachers can update their own courses" on public.courses
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));

alter policy "Users can self-enroll in free courses" on public.enrollments
  with check ((((select auth.uid()) = user_id) AND (EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = enrollments.course_id) AND (COALESCE(c.price, (0)::numeric) = (0)::numeric))))));

alter policy "Users can update their own enrollments" on public.enrollments
  using (((select auth.uid()) = user_id))
  with check (((select auth.uid()) = user_id));

alter policy "Users can view their own enrollments" on public.enrollments
  using (((select auth.uid()) = user_id));

alter policy "Users manage their own lesson progress" on public.lesson_progress
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

alter policy "Teachers manage lessons on their own courses" on public.lessons
  using ((EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = lessons.course_id) AND (c.user_id = (select auth.uid()))))))
  with check ((EXISTS ( SELECT 1
   FROM courses c
  WHERE ((c.id = lessons.course_id) AND (c.user_id = (select auth.uid()))))));

alter policy notifications_delete_own on public.notifications
  using ((recipient_id = (select auth.uid())));

alter policy notifications_select_own on public.notifications
  using ((recipient_id = (select auth.uid())));

alter policy notifications_update_own on public.notifications
  using ((recipient_id = (select auth.uid())))
  with check ((recipient_id = (select auth.uid())));

alter policy "Owners can read their payout account" on public.payout_accounts
  using ((user_id = (select auth.uid())));

alter policy "Owners can remove their payout account" on public.payout_accounts
  using ((user_id = (select auth.uid())));

alter policy "Users can insert their own profile" on public.profiles
  with check (((select auth.uid()) = id));

alter policy "Users can update their own profile" on public.profiles
  using (((select auth.uid()) = id));

alter policy "Buyers can see their own transactions" on public.transactions
  using ((buyer_id = (select auth.uid())));

alter policy "Teachers can see sales of their courses" on public.transactions
  using ((teacher_id = (select auth.uid())));

-- ---------------------------------------------------------------------------
-- 2. Indexes for unindexed foreign keys
-- ---------------------------------------------------------------------------

create index if not exists admin_actions_admin_id_idx on public.admin_actions (admin_id);
create index if not exists categories_suggested_by_idx on public.categories (suggested_by);
create index if not exists content_reports_comment_id_idx on public.content_reports (comment_id);
create index if not exists content_reports_course_id_idx on public.content_reports (course_id);
create index if not exists content_reports_resolved_by_idx on public.content_reports (resolved_by);
create index if not exists course_comments_user_id_idx on public.course_comments (user_id);
create index if not exists enrollments_course_id_idx on public.enrollments (course_id);
create index if not exists lesson_progress_course_id_idx on public.lesson_progress (course_id);
create index if not exists lesson_progress_lesson_id_idx on public.lesson_progress (lesson_id);
create index if not exists notifications_actor_id_idx on public.notifications (actor_id);
create index if not exists notifications_comment_id_idx on public.notifications (comment_id);
create index if not exists notifications_course_id_idx on public.notifications (course_id);
create index if not exists payouts_recorded_by_idx on public.payouts (recorded_by);
create index if not exists refunds_recorded_by_idx on public.refunds (recorded_by);
