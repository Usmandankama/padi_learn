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
-- ============================== THE FOOTAGE ================================
--
-- Eleven purpose-built lesson videos, one per subject course, produced by the
-- separate `PadiLearn-lesson-videos` project and brought in by
-- `import_lesson_videos.py`. They replaced a set of Pixabay b-roll clips that
-- showed the *subject* of a course — a sewing machine, a spreadsheet — but
-- nobody teaching it. These teach something: a figure that draws itself, a
-- formula, and a takeaway, in PadiLearn's own palette.
--
-- THEY CONSTRAIN THIS FILE. Each video prints its own course name and lesson
-- number into the corner of every frame — "WAEC PHYSICS · LESSON 14". The app
-- numbers curriculum rows by their position in the list
-- (course_description_screen.dart numbers by index, not by `position`), so a
-- course whose Projectile Motion lesson is filmed as lesson 14 must actually
-- have fourteen lessons before the screen agrees with the video. That is why
-- the courses below are as long as they are, and why no lesson may be
-- reordered or removed without re-cutting the footage.
--
-- Every course title likewise begins with the exact course name its video
-- prints, so the catalogue cannot contradict what is on the board.
--
--
-- ============================ WHAT YOU MUST UPLOAD ==========================
--
-- Both trees are already laid out to mirror their buckets — drag the `demo`
-- folder in and the whole catalogue works. Nothing breaks in the meantime:
-- `CourseThumbnail` falls back to the branded placeholder when an image 404s.
--
-- THUMBNAILS -> bucket `course-thumbnails` (public), path `demo/<slug>.jpg`
--   READY in `video/out/demo-thumbs/demo/`. One per course, 1280x720, taken
--   from each lesson video at the moment its figure and formula are both on
--   the board, then inverted to dark so a near-white board does not read as a
--   broken image inside a white card.
--
-- VIDEOS -> bucket `course-media` (private), key `demo/<slug>/clip.mp4`
--   READY in `video/out/demo-clips/demo/`. Eleven lesson videos at 18s each,
--   1280x720, silent, about 0.5 MB apiece, plus the rendered ad as
--   `welcome-to-padilearn`. Roughly 9 MB in total.
--
--
-- ============================= ONE REAL LESSON =============================
--
-- Each course has exactly one filmed lesson, and it is the course's free
-- preview. The rest of its lessons point at the same clip, because a demo of
-- 120 distinct videos is not a thing anyone is about to record.
--
-- Making the filmed one the preview is what keeps the seam hidden where it
-- matters: a visitor who has not enrolled can only open preview lessons, so
-- the only video they can reach is the one whose burned-in number matches the
-- row they tapped. Enrol, open lesson 3 of WAEC Physics, and you will get the
-- Projectile Motion clip with "LESSON 14" in its corner. That is the known
-- cost of the arrangement, and it is the first thing real course content
-- fixes.
--
-- `duration_seconds` is 18 everywhere for the same reason it was 14 before:
-- it must match the file actually sitting at that key, or the progress bar
-- lies and the player seeks past the end.
--
--
-- ================================ HONESTY ==================================
--
-- The instructor names below are invented. They exist so the catalogue does
-- not read as one teacher with eleven courses. Do not let an invented name
-- survive into anything a real person might read as a real teacher on your
-- platform.
--
-- `enrollments`, `rating_avg` and `rating_count` are NOT set here. They are
-- trigger-derived from real rows, every seeded course starts at zero, and the
-- cards correctly show "New" instead of a rating. An earlier version of this
-- file invented traction and the 2026-09-14 migration took it back out.
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
  -- slug, title, category, price, author, description
  ('welcome-to-padilearn',
   'Welcome to PadiLearn',
   -- Cast because this is the first row: an uncast NULL here would leave the
   -- column's type unknown and the FK to categories(name) would not resolve.
   -- No category on purpose — a welcome tour belongs under none of them.
   null::text,
   0::numeric,
   'PadiLearn',
   'A short tour of what PadiLearn does — how to find a course, how to learn offline, and how to start teaching and get paid.'),

  ('waec-physics',
   'WAEC Physics: Motion, Forces and Energy',
   'Exam Prep',
   3000::numeric,
   'Ibrahim Yusuf',
   'The mechanics half of the syllabus, worked the way the examiner marks it. Every figure drawn out, every formula derived rather than handed to you.'),

  ('waec-mathematics',
   'WAEC Mathematics: Algebra and Quadratics',
   'Exam Prep',
   3500::numeric,
   'Ibrahim Yusuf',
   'Number bases through to probability, built around the topics that come up every single year. Heavy on quadratics, because that is where the marks are.'),

  ('waec-chemistry',
   'WAEC Chemistry: Moles and Calculations',
   'Exam Prep',
   3000::numeric,
   'Ngozi Adeyemi',
   'The calculation questions students skip. Moles, formulae, stoichiometry and redox, each reduced to a method you can repeat under time pressure.'),

  ('bookkeeping',
   'Bookkeeping: Keep Books That Balance',
   'Business',
   0::numeric,
   'Musa Danladi',
   'From the accounting equation to closing the month. Free, because a business that cannot keep records is not helped by anything else you would buy.'),

  ('pricing-and-margins',
   'Pricing & Margins: Price So You Profit',
   'Business',
   4000::numeric,
   'Tunde Bakare',
   'Work out what you actually cost, what you must sell to break even, and how to raise a price without losing the customer.'),

  ('tailoring',
   'Tailoring: Patterns That Fit',
   'Fashion & Tailoring',
   5000::numeric,
   'Grace Eze',
   'Measurement, blocks, darts and finishing. Filmed close enough to see which way the seam is pressed.'),

  ('electrical-work',
   'Practical Electrical Work: Circuits and Wiring',
   'Trades & Vocational',
   6000::numeric,
   'Emeka Okafor',
   'Ohm''s law through to fault finding, with the safety practice that comes before any of it. For the apprentice who already holds the pliers.'),

  ('excel-for-business',
   'Excel for Business: Formulas That Earn',
   'Business',
   2500::numeric,
   'Musa Danladi',
   'The formulas and habits that come up in real office work: lookups, pivot tables, and cleaning up somebody else''s spreadsheet.'),

  ('programming-fundamentals',
   'Programming Fundamentals: Algorithms That Matter',
   'Programming',
   7500::numeric,
   'Amaka Obi',
   'Variables to Big-O, in whichever language you already write. The half of programming that does not go out of date.'),

  ('graphic-design',
   'Graphic Design: Type, Scale and Layout',
   'Design',
   4500::numeric,
   'Daniel Effiong',
   'Why some layouts look designed and others look assembled. Type scales, grids, colour and white space — then preparing the file so the printer does not ruin it.'),

  ('broiler-farming',
   'Broiler Farming: Feed, Weight and Margin',
   'Agriculture',
   3500::numeric,
   'Fatima Bello',
   'A full cycle, costed. Chicks, brooding, feed conversion and biosecurity, ending with the arithmetic that says whether the batch made money.')
) as t(slug, title, category, price, author, description);

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
  -- Counters start at zero and are never the seed's to set: triggers recount
  -- enrolments and ratings from real rows. See HONESTY above.
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
--
-- Mirrored by `video/src/catalogue.ts`, which the ad renders from. If you edit
-- one, edit the other, or the ad starts advertising a catalogue that is not
-- there.
--
-- `is_filmed` marks the single lesson per course that has its own video, and
-- becomes `is_preview` on insert — see ONE REAL LESSON above. Its position is
-- printed into the footage and cannot be changed from here.

create temporary table _seed_lessons on commit drop as
select * from (values
  -- course_slug, position, title, is_filmed
  ('welcome-to-padilearn',  1, 'What PadiLearn is',           true ),

  ('waec-physics',  1, 'How WAEC physics is marked',                false),
  ('waec-physics',  2, 'Measurement and units',                     false),
  ('waec-physics',  3, 'Scalars and vectors',                       false),
  ('waec-physics',  4, 'Distance, speed and velocity',              false),
  ('waec-physics',  5, 'Acceleration and the equations of motion',  false),
  ('waec-physics',  6, 'Newton''s laws',                            false),
  ('waec-physics',  7, 'Momentum and collisions',                   false),
  ('waec-physics',  8, 'Work, energy and power',                    false),
  ('waec-physics',  9, 'Friction',                                  false),
  ('waec-physics', 10, 'Circular motion',                           false),
  ('waec-physics', 11, 'Equilibrium and moments',                   false),
  ('waec-physics', 12, 'Simple harmonic motion',                    false),
  ('waec-physics', 13, 'Resolving vectors',                         false),
  ('waec-physics', 14, 'Projectile Motion',                         true ),
  ('waec-physics', 15, 'Density and upthrust',                      false),
  ('waec-physics', 16, 'Past paper walkthrough',                    false),

  ('waec-mathematics',  1, 'How WAEC maths is marked',                  false),
  ('waec-mathematics',  2, 'Number bases',                              false),
  ('waec-mathematics',  3, 'Fractions, indices and surds',              false),
  ('waec-mathematics',  4, 'Logarithms',                                false),
  ('waec-mathematics',  5, 'Linear equations',                          false),
  ('waec-mathematics',  6, 'Simultaneous equations',                    false),
  ('waec-mathematics',  7, 'Completing the Square',                     true ),
  ('waec-mathematics',  8, 'The quadratic formula',                     false),
  ('waec-mathematics',  9, 'Sequences and series',                      false),
  ('waec-mathematics', 10, 'Geometry and circle theorems',              false),
  ('waec-mathematics', 11, 'Trigonometry',                              false),
  ('waec-mathematics', 12, 'Statistics and probability',                false),

  ('waec-chemistry',  1, 'States of matter',                          false),
  ('waec-chemistry',  2, 'Atomic structure',                          false),
  ('waec-chemistry',  3, 'The Mole',                                  true ),
  ('waec-chemistry',  4, 'Chemical formulae and equations',           false),
  ('waec-chemistry',  5, 'Stoichiometry',                             false),
  ('waec-chemistry',  6, 'Acids, bases and salts',                    false),
  ('waec-chemistry',  7, 'Redox reactions',                           false),
  ('waec-chemistry',  8, 'Rates of reaction',                         false),
  ('waec-chemistry',  9, 'Organic chemistry basics',                  false),
  ('waec-chemistry', 10, 'Past paper walkthrough',                    false),

  ('bookkeeping',  1, 'The Accounting Equation',                   true ),
  ('bookkeeping',  2, 'Debits and credits',                        false),
  ('bookkeeping',  3, 'The cash book',                             false),
  ('bookkeeping',  4, 'Ledgers and the trial balance',             false),
  ('bookkeeping',  5, 'Invoices, receipts and keeping records',    false),
  ('bookkeeping',  6, 'The profit and loss account',               false),
  ('bookkeeping',  7, 'The balance sheet',                         false),
  ('bookkeeping',  8, 'Closing the month',                         false),

  ('pricing-and-margins',  1, 'What your product really costs',            false),
  ('pricing-and-margins',  2, 'Fixed cost and variable cost',              false),
  ('pricing-and-margins',  3, 'Markup and margin',                         false),
  ('pricing-and-margins',  4, 'Break-even Point',                          true ),
  ('pricing-and-margins',  5, 'Pricing against your competition',          false),
  ('pricing-and-margins',  6, 'Discounts that do not kill you',            false),
  ('pricing-and-margins',  7, 'Raising your price without losing customers',false),

  ('tailoring',  1, 'Tools and your workspace',                  false),
  ('tailoring',  2, 'Fabric types and grain',                    false),
  ('tailoring',  3, 'Taking measurements',                       false),
  ('tailoring',  4, 'Reading a size chart',                      false),
  ('tailoring',  5, 'Drafting a basic block',                    false),
  ('tailoring',  6, 'Seam allowance',                            false),
  ('tailoring',  7, 'Cutting cleanly',                           false),
  ('tailoring',  8, 'Darts: what they do',                       false),
  ('tailoring',  9, 'The Bust Dart',                             true ),
  ('tailoring', 10, 'Sleeves and armholes',                      false),
  ('tailoring', 11, 'Zips, buttons and finishing',               false),
  ('tailoring', 12, 'Pressing and presentation',                 false),

  ('electrical-work',  1, 'Safety first',                              false),
  ('electrical-work',  2, 'Tools and test equipment',                  false),
  ('electrical-work',  3, 'Voltage, current and resistance',           false),
  ('electrical-work',  4, 'Ohm''s law',                                false),
  ('electrical-work',  5, 'Series and Parallel',                       true ),
  ('electrical-work',  6, 'Reading a circuit diagram',                 false),
  ('electrical-work',  7, 'Cables and cable sizing',                   false),
  ('electrical-work',  8, 'Wiring a socket outlet',                    false),
  ('electrical-work',  9, 'Earthing and protection',                   false),
  ('electrical-work', 10, 'Fault finding',                             false),

  ('excel-for-business',  1, 'Getting around a spreadsheet',              false),
  ('excel-for-business',  2, 'Entering and formatting data',              false),
  ('excel-for-business',  3, 'Cell references',                           false),
  ('excel-for-business',  4, 'SUM, AVERAGE and COUNT',                    false),
  ('excel-for-business',  5, 'IF and nested IF',                          false),
  ('excel-for-business',  6, 'Sorting and filtering',                     false),
  ('excel-for-business',  7, 'Conditional formatting',                    false),
  ('excel-for-business',  8, 'Charts that communicate',                   false),
  ('excel-for-business',  9, 'Named ranges',                              false),
  ('excel-for-business', 10, 'VLOOKUP',                                   false),
  ('excel-for-business', 11, 'VLOOKUP''s One Limitation',                 true ),
  ('excel-for-business', 12, 'Pivot tables',                              false),
  ('excel-for-business', 13, 'Cleaning somebody else''s spreadsheet',     false),
  ('excel-for-business', 14, 'Printing without the mess',                 false),

  ('programming-fundamentals',  1, 'What a program is',                         false),
  ('programming-fundamentals',  2, 'Variables and types',                       false),
  ('programming-fundamentals',  3, 'Conditions',                                false),
  ('programming-fundamentals',  4, 'Loops',                                     false),
  ('programming-fundamentals',  5, 'Functions',                                 false),
  ('programming-fundamentals',  6, 'Lists and arrays',                          false),
  ('programming-fundamentals',  7, 'Linear search',                             false),
  ('programming-fundamentals',  8, 'Binary Search',                             true ),
  ('programming-fundamentals',  9, 'Sorting',                                   false),
  ('programming-fundamentals', 10, 'Big-O notation',                            false),
  ('programming-fundamentals', 11, 'Dictionaries and maps',                     false),
  ('programming-fundamentals', 12, 'Reading and writing files',                 false),

  ('graphic-design',  1, 'What design is for',                        false),
  ('graphic-design',  2, 'The Type Scale',                            true ),
  ('graphic-design',  3, 'Choosing typefaces',                        false),
  ('graphic-design',  4, 'Colour and contrast',                       false),
  ('graphic-design',  5, 'Grids and alignment',                       false),
  ('graphic-design',  6, 'White space',                               false),
  ('graphic-design',  7, 'Logos and marks',                           false),
  ('graphic-design',  8, 'Designing for print and for screen',        false),
  ('graphic-design',  9, 'Preparing files for the printer',           false),

  ('broiler-farming',  1, 'Is broiler farming for you?',               false),
  ('broiler-farming',  2, 'Housing and ventilation',                   false),
  ('broiler-farming',  3, 'Buying day-old chicks',                     false),
  ('broiler-farming',  4, 'Brooding the first two weeks',              false),
  ('broiler-farming',  5, 'Feed types and schedules',                  false),
  ('broiler-farming',  6, 'Feed Conversion Ratio',                     true ),
  ('broiler-farming',  7, 'Water and medication',                      false),
  ('broiler-farming',  8, 'Biosecurity and disease',                   false),
  ('broiler-farming',  9, 'Weighing and selling',                      false),
  ('broiler-farming', 10, 'Costing a full cycle',                      false)
) as t(course_slug, position, title, is_filmed);

-- One clip per course, shared by all its lessons. Every file at these keys is
-- 18 seconds, except the welcome tour, which is the rendered ad.
create temporary table _seed_clips on commit drop as
select
  slug,
  case when slug = 'welcome-to-padilearn' then 24 else 18 end as clip_seconds
from _seed_courses;

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
  l.is_filmed
from _seed_lessons l
join _seed_clips c on c.slug = l.course_slug
on conflict (id) do update set
  title            = excluded.title,
  position         = excluded.position,
  video_url        = excluded.video_url,
  duration_seconds = excluded.duration_seconds,
  is_preview       = excluded.is_preview;

-- A course that was longer in an earlier run would keep its surplus rows, and
-- because the curriculum screen numbers lessons by their index in the list,
-- those leftovers would push the filmed lesson past the number printed in its
-- own footage.
--
-- Scoped to the courses THIS run writes, not to every course the seed has
-- ever created. Matching on the 'a0000000-…' prefix alone would also empty
-- out courses from a previous catalogue that this file no longer mentions,
-- leaving them in the marketplace with no lessons at all — worse than leaving
-- them alone, and not this statement's job. Retiring an old course is the
-- teardown's job, at the bottom of this file.
--
-- A teacher's real lessons cannot be caught either way: both prefixes have to
-- match, and real rows get random uuids.
delete from public.lessons le
where le.id::text like 'b0000000-0000-4000-8000-%'
  and le.course_id in (
    select ('a0000000-0000-4000-8000-' || substr(md5(slug), 1, 12))::uuid
    from _seed_courses
  )
  and not exists (
    select 1 from _seed_lessons l
    where ('b0000000-0000-4000-8000-' ||
            substr(md5(l.course_slug || ':' || l.position), 1, 12))::uuid = le.id
  );


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
    ('a0000000-0000-4000-8000-' || substr(md5('waec-mathematics'), 1, 12))::uuid,
    ('a0000000-0000-4000-8000-' || substr(md5('excel-for-business'), 1, 12))::uuid,
    ('a0000000-0000-4000-8000-' || substr(md5('bookkeeping'), 1, 12))::uuid
  )
where ctx.student_id is not null
  and not exists (
    select 1 from public.enrollments e
    where e.user_id = ctx.student_id and e.course_id = co.id
  );

-- Six lessons finished and the seventh part-watched, so the course opens on a
-- real resume point rather than at zero.
--
-- The seventh is deliberate: it is WAEC Mathematics' filmed lesson, so the
-- student's resume point is the one lesson in the course that has its own
-- video. Tapping straight into the dashboard's "continue" therefore plays
-- Completing the Square, which is also the lesson number printed in the clip.
-- Any other stopping place would resume into footage of a different lesson.
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
  ('waec-mathematics', 1, true, 0),
  ('waec-mathematics', 2, true, 0),
  ('waec-mathematics', 3, true, 0),
  ('waec-mathematics', 4, true, 0),
  ('waec-mathematics', 5, true, 0),
  ('waec-mathematics', 6, true, 0),
  -- Nine seconds in, not the 4:12 a full-length lesson would have had: the
  -- player would otherwise try to seek past the end of an 18-second file.
  -- Halfway, and far enough in that resuming lands on a drawn board rather
  -- than a blank one. `LessonMock.RESUME_AT` in the ad matches this.
  ('waec-mathematics', 7, false, 9)
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
