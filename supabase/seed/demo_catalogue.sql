-- Demo catalogue: courses, lessons, and one enrolled student.
--
-- Deliberately NOT in supabase/migrations/. Migrations describe the database's
-- shape and every environment must run all of them; this is sample data for
-- showing the app to people, and a production database should be able to skip
-- it. Run it by hand:
--
--   supabase db execute --file supabase/seed/demo_catalogue.sql
--
-- or paste it into the SQL editor.
--
-- Safe to re-run. Every row's id is derived from its slug (see `course_id`
-- below), so a second run updates the same rows instead of duplicating them,
-- and re-running after editing a title or price just corrects it.
--
--
-- ============================ WHAT YOU MUST UPLOAD ==========================
--
-- The seed writes URLs and object keys for files that do not exist yet. That
-- is intentional and nothing breaks in the meantime: `CourseThumbnail` falls
-- back to the branded placeholder when an image 404s, so the app looks
-- deliberate rather than broken while you gather the artwork.
--
-- THUMBNAILS -> bucket `course-thumbnails` (public), path `demo/<slug>.jpg`
--   demo/welcome-to-padilearn.jpg      demo/excel-for-office-work.jpg
--   demo/jamb-mathematics.jpg          demo/start-a-small-business.jpg
--   demo/waec-english.jpg              demo/whatsapp-marketing.jpg
--   demo/flutter-for-beginners.jpg     demo/tailoring-basics.jpg
--   demo/python-basics.jpg             demo/phone-photography.jpg
--   demo/personal-finance.jpg
--
-- Landscape, 16:9, 1280x720 is plenty. The card crops to fill, so keep the
-- subject centred.
--
-- VIDEOS -> bucket `course-media` (private), key `demo/<slug>/clip.mp4`
--   ALREADY PREPARED. `video/out/demo-clips/demo/` holds all 11 files laid out
--   in exactly this structure — drag that `demo` folder into the bucket root
--   and every seeded lesson plays. 13 MB total. See video/out/demo-clips/
--   UPLOAD.md for provenance and licence.
--
--   All lessons of a course share one clip, and `duration_seconds` above
--   matches the real file.
--
--
-- ================================ HONESTY ==================================
--
-- The instructor names below are invented, and so are `enrollments`,
-- `rating_avg` and `rating_count` — they exist so the cards do not all read
-- "0 students". They are set dressing for a demo. Do not present these numbers
-- as traction, and do not let an invented instructor name survive into
-- anything a real person might read as a real teacher on your platform.
--
-- To remove everything this file created, see the block at the very bottom.
-- ===========================================================================


begin;

-- All demo courses belong to the real Teacher account. `courses.author` is a
-- denormalised display name, so the catalogue can show a variety of
-- instructors without inventing profile rows (or auth users) for people who do
-- not exist.
create temporary table _seed_ctx on commit drop as
select
  (
    select id from public.profiles
    where role = 'Teacher'
    order by created_at
    limit 1
  ) as teacher_id,
  (
    select id from public.profiles
    where role = 'Student'
    order by created_at
    limit 1
  ) as student_id,
  'https://wnxuxplzoddadjpwfhxe.supabase.co/storage/v1/object/public/course-thumbnails/demo/'
    as thumb_base;

do $$
begin
  if (select teacher_id from _seed_ctx) is null then
    raise exception
      'No profile with role = ''Teacher'' exists. Sign up as a teacher first — '
      'the demo courses need an owner, and courses.user_id references auth.users.';
  end if;
end $$;


-- ------------------------------- courses ----------------------------------

create temporary table _seed_courses on commit drop as
select * from (values
  -- slug, title, category, price, author, enrollments, rating, rating_count, description
  ('welcome-to-padilearn',
   'Welcome to PadiLearn',
   -- Cast because this is the first row: an uncast NULL here would leave the
   -- column's type unknown and the FK to categories(name) would not resolve.
   -- No category on purpose — a welcome tour belongs under none of them.
   null::text,
   0::numeric,
   'PadiLearn',
   4820, 5.0, 96,
   'A short tour of what PadiLearn does — how to find a course, how to learn offline, and how to start teaching and get paid.'),

  ('jamb-mathematics',
   'JAMB Mathematics: Past Questions Solved',
   'Exam Prep',
   3500::numeric,
   'Ibrahim Yusuf',
   1240, 4.8, 213,
   'Ten years of JAMB maths past questions, worked step by step. Covers algebra, indices, sequences, geometry and probability — the topics that come up every single year.'),

  ('waec-english',
   'WAEC English: Comprehension and Summary',
   'Exam Prep',
   3000::numeric,
   'Ngozi Adeyemi',
   980, 4.6, 154,
   'The two sections students lose the most marks on. Learn how examiners mark summary answers, and practise on real past papers.'),

  ('flutter-for-beginners',
   'Flutter for Beginners: Build Your First App',
   'Programming',
   7500::numeric,
   'Amaka Obi',
   860, 4.7, 121,
   'From zero to a working app on your own phone. No prior mobile experience needed — if you can write a little Dart, you can follow this.'),

  ('python-basics',
   'Python Basics for Absolute Beginners',
   'Programming',
   5000::numeric,
   'Samuel Okonkwo',
   1510, 4.5, 268,
   'Variables, loops, functions and files, taught by building small useful scripts rather than toy examples.'),

  ('excel-for-office-work',
   'Excel for Office Work',
   'Business',
   2500::numeric,
   'Musa Danladi',
   1980, 4.5, 341,
   'The formulas and shortcuts that actually come up in an office job: lookups, pivot tables, and cleaning up somebody else''s spreadsheet.'),

  ('start-a-small-business',
   'Start a Small Business in Nigeria',
   'Business',
   0::numeric,
   'Tunde Bakare',
   3120, 4.6, 402,
   'Registration, pricing, record-keeping and finding your first customers. Free, because the barrier should not be the course.'),

  ('whatsapp-marketing',
   'Digital Marketing with WhatsApp',
   'Marketing',
   4000::numeric,
   'Chioma Nwosu',
   1450, 4.7, 199,
   'Turn a WhatsApp contact list into repeat customers — catalogues, broadcast lists, status strategy and what gets you blocked.'),

  ('tailoring-basics',
   'Tailoring: From Measurement to Finish',
   'Fashion & Tailoring',
   5000::numeric,
   'Grace Eze',
   640, 4.9, 88,
   'Take accurate measurements, cut a clean pattern, and finish a garment that fits. Filmed close enough to see the stitches.'),

  ('phone-photography',
   'Photography With the Phone You Already Have',
   'Photography & Video',
   4500::numeric,
   'Daniel Effiong',
   1120, 4.6, 167,
   'Light, framing and editing — no camera required. Shoot product photos good enough to sell with.'),

  ('personal-finance',
   'Personal Finance in Naira',
   'Finance',
   15000::numeric,
   'Fatima Bello',
   410, 4.8, 62,
   'Budgeting, saving and investing against real Nigerian inflation, exchange rates and interest. The premium course in the catalogue, and priced like one.')
) as t(slug, title, category, price, author, enrollments, rating_avg, rating_count, description);

/*
 * A course's id is derived from its slug rather than generated, which is what
 * makes this file re-runnable: the same slug always produces the same uuid, so
 * a second run lands on `do update` instead of inserting a duplicate. The
 * 'a0000000-…' prefix also makes every seeded row identifiable, which the
 * teardown at the bottom depends on.
 */
insert into public.courses (
  id, title, description, price, category, author,
  thumbnail_url, user_id, enrollments, rating_avg, rating_count
)
select
  ('a0000000-0000-4000-8000-' || substr(md5(c.slug), 1, 12))::uuid,
  c.title,
  c.description,
  c.price,
  c.category,
  c.author,
  ctx.thumb_base || c.slug || '.jpg',
  ctx.teacher_id,
  -- Counters start at zero. The invented figures in `_seed_courses` used to
  -- be written here, and real users would have read them as traction; the
  -- 2026-09-14 migration reset them. Triggers now recount enrolments and
  -- ratings from real rows, so these columns are never the seed's to set.
  0,
  0,
  0
from _seed_courses c cross join _seed_ctx ctx
on conflict (id) do update set
  title         = excluded.title,
  description   = excluded.description,
  price         = excluded.price,
  category      = excluded.category,
  author        = excluded.author,
  thumbnail_url = excluded.thumbnail_url;
  -- enrollments / rating_avg / rating_count are deliberately NOT touched on
  -- re-run: they are derived from real rows by triggers.


-- ------------------------------- lessons ----------------------------------

create temporary table _seed_lessons on commit drop as
select * from (values
  ('welcome-to-padilearn', 1, 'What PadiLearn is', 24, true),

  ('jamb-mathematics', 1, 'How JAMB maths is marked', 380, true),
  ('jamb-mathematics', 2, 'Simultaneous equations', 495, false),
  ('jamb-mathematics', 3, 'Quadratic equations', 720, false),
  ('jamb-mathematics', 4, 'Indices and logarithms', 610, false),
  ('jamb-mathematics', 5, 'Sequences and series', 840, false),
  ('jamb-mathematics', 6, 'Probability basics', 545, false),

  ('waec-english', 1, 'What the examiner is looking for', 410, true),
  ('waec-english', 2, 'Comprehension: finding the answer', 660, false),
  ('waec-english', 3, 'Summary: cutting without losing marks', 720, false),
  ('waec-english', 4, 'Practice paper walkthrough', 900, false),

  ('flutter-for-beginners', 1, 'Setting up Flutter', 540, true),
  ('flutter-for-beginners', 2, 'Widgets and layout', 780, false),
  ('flutter-for-beginners', 3, 'State and interaction', 690, false),
  ('flutter-for-beginners', 4, 'Running on your own phone', 420, false),

  ('python-basics', 1, 'Installing Python', 300, true),
  ('python-basics', 2, 'Variables and types', 520, false),
  ('python-basics', 3, 'Loops and conditions', 640, false),
  ('python-basics', 4, 'Functions', 580, false),
  ('python-basics', 5, 'Reading and writing files', 610, false),

  ('excel-for-office-work', 1, 'Getting around a spreadsheet', 360, true),
  ('excel-for-office-work', 2, 'Formulas that matter', 620, false),
  ('excel-for-office-work', 3, 'VLOOKUP and XLOOKUP', 540, false),
  ('excel-for-office-work', 4, 'Pivot tables', 700, false),

  ('start-a-small-business', 1, 'Is your idea a business?', 420, true),
  ('start-a-small-business', 2, 'Registering with CAC', 510, false),
  ('start-a-small-business', 3, 'Pricing so you actually profit', 660, false),
  ('start-a-small-business', 4, 'Finding your first customers', 580, false),

  ('whatsapp-marketing', 1, 'Setting up WhatsApp Business', 340, true),
  ('whatsapp-marketing', 2, 'Building a catalogue', 480, false),
  ('whatsapp-marketing', 3, 'Broadcast without getting blocked', 560, false),

  ('tailoring-basics', 1, 'Tools you need', 300, true),
  ('tailoring-basics', 2, 'Taking measurements', 720, false),
  ('tailoring-basics', 3, 'Cutting the pattern', 840, false),
  ('tailoring-basics', 4, 'Finishing and pressing', 600, false),

  ('phone-photography', 1, 'Light is everything', 400, true),
  ('phone-photography', 2, 'Framing your shot', 520, false),
  ('phone-photography', 3, 'Editing on your phone', 610, false),

  ('personal-finance', 1, 'Where your money actually goes', 480, true),
  ('personal-finance', 2, 'Building a budget in naira', 700, false),
  ('personal-finance', 3, 'Saving against inflation', 780, false),
  ('personal-finance', 4, 'First steps into investing', 820, false)
) as t(course_slug, position, title, duration_seconds, is_preview);

-- One clip per course, shared by all its lessons, with the real duration of
-- the file sitting at that key.
--
-- Not one video per lesson: nobody in a demo opens six lessons of the same
-- course, and 11 clips keep the whole set at 13 MB rather than 42 files.
-- `duration_seconds` must match the actual file or the progress bar lies and
-- the player tries to seek past the end.
create temporary table _seed_clips on commit drop as
select * from (values
  ('excel-for-office-work', 14), ('flutter-for-beginners', 15),
  ('jamb-mathematics',      14), ('personal-finance',      12),
  ('phone-photography',      5), ('python-basics',         15),
  ('start-a-small-business',  7), ('tailoring-basics',     10),
  ('waec-english',          15), ('welcome-to-padilearn',  24),
  ('whatsapp-marketing',     8)
) as t(course_slug, clip_seconds);

insert into public.lessons (
  id, course_id, title, position, video_url, duration_seconds, is_preview
)
select
  ('b0000000-0000-4000-8000-' ||
    substr(md5(l.course_slug || ':' || l.position), 1, 12))::uuid,
  ('a0000000-0000-4000-8000-' || substr(md5(l.course_slug), 1, 12))::uuid,
  l.title,
  l.position,
  -- Object key in the private course-media bucket, never a URL.
  'demo/' || l.course_slug || '/clip.mp4',
  c.clip_seconds,
  l.is_preview
from _seed_lessons l
join _seed_clips c on c.course_slug = l.course_slug
on conflict (id) do update set
  title            = excluded.title,
  position         = excluded.position,
  video_url        = excluded.video_url,
  duration_seconds = excluded.duration_seconds,
  is_preview       = excluded.is_preview;


-- ------------------ one student, part-way through a course ------------------
--
-- Without this the student dashboard is empty, which is the first screen after
-- signing in and a poor thing to demo. Enrols the oldest Student account in
-- three courses and marks some lessons watched.
--
-- Progress is NOT set directly: inserting into lesson_progress fires the
-- recompute trigger, so the percentage the app shows is the one the app would
-- have calculated itself.

insert into public.enrollments (user_id, course_id, title, image, is_free)
select
  ctx.student_id,
  co.id,
  co.title,
  co.thumbnail_url,
  co.price <= 0
from _seed_ctx ctx
join public.courses co
  on co.id in (
    ('a0000000-0000-4000-8000-' || substr(md5('jamb-mathematics'), 1, 12))::uuid,
    ('a0000000-0000-4000-8000-' || substr(md5('excel-for-office-work'), 1, 12))::uuid,
    ('a0000000-0000-4000-8000-' || substr(md5('start-a-small-business'), 1, 12))::uuid
  )
where ctx.student_id is not null
  and not exists (
    select 1 from public.enrollments e
    where e.user_id = ctx.student_id and e.course_id = co.id
  );

-- Two lessons finished and one part-watched, so the course opens on a real
-- "Resume from 4:12" rather than at zero.
insert into public.lesson_progress (
  user_id, lesson_id, course_id, position_seconds, completed_at
)
select
  ctx.student_id,
  le.id,
  le.course_id,
  case when p.completed then le.duration_seconds else p.seconds end,
  case when p.completed then now() else null end
from _seed_ctx ctx
cross join (values
  ('jamb-mathematics', 1, true, 0),
  ('jamb-mathematics', 2, true, 0),
  -- Inside the clip, not the 4:12 a full-length lesson would have had — the
  -- player would otherwise try to seek past the end of a 14-second file.
  ('jamb-mathematics', 3, false, 6)
) as p(course_slug, position, completed, seconds)
join public.lessons le
  on le.id = ('b0000000-0000-4000-8000-' ||
       substr(md5(p.course_slug || ':' || p.position), 1, 12))::uuid
where ctx.student_id is not null
on conflict (user_id, lesson_id) do update set
  position_seconds = excluded.position_seconds,
  completed_at     = excluded.completed_at;

commit;


-- =============================== TEARDOWN ==================================
--
-- Removes everything above and nothing else. The uuid prefixes are what make
-- this safe: real courses and lessons get random ids and cannot collide with
-- 'a0000000-…' / 'b0000000-…'.
--
-- Lessons, enrollments and lesson_progress cascade from the course delete, so
-- one statement is enough.
--
--   delete from public.courses
--    where id::text like 'a0000000-0000-4000-8000-%';
