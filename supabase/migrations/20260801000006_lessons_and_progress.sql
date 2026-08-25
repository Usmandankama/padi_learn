-- Courses become multi-lesson.
--
-- `courses.video_url` made a course exactly one MP4, which is not what anyone
-- means by "course". This introduces lessons, per-lesson progress, and free
-- preview lessons, then migrates the single video into a first lesson.
--
-- Run while the catalogue is still tiny — migrating a populated one is far
-- uglier.

-- ---------------------------------------------------------------------------
-- lessons
-- ---------------------------------------------------------------------------
create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,

  -- Ordering within the course. Not unique: reordering rewrites the whole set
  -- in one statement, and a unique constraint would require juggling temps.
  position integer not null default 1,

  -- Object key in the private `course-media` bucket, never a public URL.
  video_url text,
  duration_seconds integer,

  -- A preview lesson plays for anyone signed in, enrolled or not.
  is_preview boolean not null default false,

  created_at timestamptz not null default now()
);

create index if not exists lessons_course_position_idx
  on public.lessons (course_id, position);

alter table public.lessons enable row level security;

-- Curriculum is marketing material: any signed-in user can read the lesson
-- list of a course they can see. The subquery inherits the courses SELECT
-- policy, so archived courses stay hidden from everyone but owner/enrolled.
-- `video_url` is only an object key, useless without a signed URL.
drop policy if exists "Lessons follow course visibility" on public.lessons;
create policy "Lessons follow course visibility"
  on public.lessons for select to authenticated
  using (
    exists (select 1 from public.courses c where c.id = lessons.course_id)
  );

drop policy if exists "Teachers manage lessons on their own courses" on public.lessons;
create policy "Teachers manage lessons on their own courses"
  on public.lessons for all to authenticated
  using (
    exists (
      select 1 from public.courses c
      where c.id = lessons.course_id and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.courses c
      where c.id = lessons.course_id and c.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- lesson_progress
-- ---------------------------------------------------------------------------
create table if not exists public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,

  -- Denormalised so the recompute trigger doesn't need to join back.
  course_id uuid not null references public.courses(id) on delete cascade,

  position_seconds integer not null default 0,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),

  unique (user_id, lesson_id)
);

create index if not exists lesson_progress_user_course_idx
  on public.lesson_progress (user_id, course_id);

alter table public.lesson_progress enable row level security;

drop policy if exists "Users manage their own lesson progress" on public.lesson_progress;
create policy "Users manage their own lesson progress"
  on public.lesson_progress for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- enrollments.progress stays, as a derived cache
-- ---------------------------------------------------------------------------
-- Keeping the single percentage means the Continue Learning cards, the offline
-- cache and the student dashboard keep working untouched. It is now recomputed
-- rather than written by the client.

create or replace function public.recompute_enrollment_progress()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_user   uuid := coalesce(new.user_id, old.user_id);
  v_course uuid := coalesce(new.course_id, old.course_id);
  v_total  integer;
  v_done   integer;
begin
  select count(*) into v_total from public.lessons where course_id = v_course;
  select count(*) into v_done
    from public.lesson_progress
   where user_id = v_user
     and course_id = v_course
     and completed_at is not null;

  update public.enrollments
     set progress = case
                      when v_total = 0 then 0
                      else least(100, round((v_done::numeric / v_total) * 100)::integer)
                    end
   where user_id = v_user and course_id = v_course;

  return null;
end;
$$;

drop trigger if exists on_lesson_progress_changed on public.lesson_progress;
create trigger on_lesson_progress_changed
  after insert or update or delete on public.lesson_progress
  for each row execute function public.recompute_enrollment_progress();

-- Adding or removing a lesson changes the denominator for everyone enrolled.
create or replace function public.recompute_progress_for_course()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_course uuid := coalesce(new.course_id, old.course_id);
  v_total  integer;
begin
  select count(*) into v_total from public.lessons where course_id = v_course;

  update public.enrollments e
     set progress = case
                      when v_total = 0 then 0
                      else least(100, round((
                        select count(*)
                          from public.lesson_progress lp
                         where lp.user_id = e.user_id
                           and lp.course_id = v_course
                           and lp.completed_at is not null
                      )::numeric / v_total * 100)::integer)
                    end
   where e.course_id = v_course;

  return null;
end;
$$;

drop trigger if exists on_lessons_changed on public.lessons;
create trigger on_lessons_changed
  after insert or delete on public.lessons
  for each row execute function public.recompute_progress_for_course();

-- Trigger functions are invoked by the trigger mechanism, not by the calling
-- user, so they need no EXECUTE grant. Leaving the default in place would
-- expose them at /rest/v1/rpc/...
revoke all on function public.recompute_enrollment_progress() from public, anon, authenticated;
revoke all on function public.recompute_progress_for_course() from public, anon, authenticated;

-- Progress is derived now; the client must not write it directly.
revoke update on public.enrollments from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Migrate the existing single video into a first lesson, then drop the columns
-- ---------------------------------------------------------------------------
insert into public.lessons (course_id, title, position, video_url)
select c.id, 'Lesson 1', 1, c.video_url
  from public.courses c
 where c.video_url is not null
   and btrim(c.video_url) <> ''
   and not exists (select 1 from public.lessons l where l.course_id = c.id);

alter table public.courses drop column if exists video_url;

-- Was already dead: nothing has written it since playback moved to signed URLs.
alter table public.enrollments drop column if exists video_url;
