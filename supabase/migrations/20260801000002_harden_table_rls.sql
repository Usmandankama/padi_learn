-- Row-level-security and privilege hardening for the public schema.
--
-- Note on column privileges: a column-level REVOKE cannot narrow a table-level
-- grant, so wherever only some columns should be writable the table grant is
-- dropped and re-issued per column.

-- ---------------------------------------------------------------------------
-- profiles
--   Was: SELECT USING (true) for role `public`, so anonymous callers could dump
--   every user's name + EMAIL. UPDATE was not column-scoped, so a Student could
--   PATCH their own `role` to 'Teacher' and start publishing.
-- ---------------------------------------------------------------------------
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles are viewable by signed-in users"
  on public.profiles for select to authenticated using (true);

revoke select on public.profiles from anon, authenticated;
grant select (id, name, role, profile_image_url, created_at)
  on public.profiles to authenticated;

revoke update on public.profiles from anon, authenticated;
grant update (name, profile_image_url) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- courses
--   Was: readable by anon (catalogue scraping), insertable by ANY authenticated
--   user regardless of role, and the trigger-maintained counters
--   (enrollments / rating_avg / rating_count) were client-writable.
-- ---------------------------------------------------------------------------
create or replace function public.is_teacher()
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'Teacher'
  );
$$;
revoke all on function public.is_teacher() from public;
grant execute on function public.is_teacher() to authenticated;

drop policy if exists "Courses are viewable by everyone" on public.courses;
create policy "Courses are viewable by signed-in users"
  on public.courses for select to authenticated using (true);

drop policy if exists "Teachers can insert their own courses" on public.courses;
create policy "Teachers can insert their own courses"
  on public.courses for insert to authenticated
  with check (auth.uid() = user_id and public.is_teacher());

drop policy if exists "Teachers can update their own courses" on public.courses;
create policy "Teachers can update their own courses"
  on public.courses for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke update on public.courses from anon, authenticated;
grant update (title, description, price, category, author, thumbnail_url, video_url)
  on public.courses to authenticated;

-- ---------------------------------------------------------------------------
-- enrollments
--   Was: UPDATE ... USING (auth.uid() = user_id) with no WITH CHECK and no
--   column scope. Postgres reuses USING as the check, which only pinned
--   user_id -- so a student could enroll in a free course and then PATCH the
--   row's course_id to any paid course.
-- ---------------------------------------------------------------------------
drop policy if exists "Users can update their own enrollments" on public.enrollments;
create policy "Users can update their own enrollments"
  on public.enrollments for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke update on public.enrollments from anon, authenticated;
grant update (progress) on public.enrollments to authenticated;

-- ---------------------------------------------------------------------------
-- course_ratings
--   Was: any authenticated user could rate any course without ever enrolling,
--   and the recompute trigger wrote that straight onto courses.rating_avg.
--
--   UPDATE keeps its table-level grant on purpose: PostgREST upserts compile to
--   ON CONFLICT DO UPDATE and re-set user_id/course_id, so column scoping would
--   break rating changes. The WITH CHECK below is what enforces correctness.
-- ---------------------------------------------------------------------------
drop policy if exists "Ratings are viewable by everyone" on public.course_ratings;
create policy "Ratings are viewable by signed-in users"
  on public.course_ratings for select to authenticated using (true);

drop policy if exists "Users can add their own rating" on public.course_ratings;
create policy "Enrolled users can add their own rating"
  on public.course_ratings for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.enrollments e
      where e.course_id = course_ratings.course_id
        and e.user_id = auth.uid()
    )
  );

drop policy if exists "Users can update their own rating" on public.course_ratings;
create policy "Enrolled users can update their own rating"
  on public.course_ratings for update to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.enrollments e
      where e.course_id = course_ratings.course_id
        and e.user_id = auth.uid()
    )
  );
