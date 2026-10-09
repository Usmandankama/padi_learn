-- Lesson videos up to 300 MB (docs/STATUS.md, the Supabase account).
--
-- The free plan capped every upload at 50 MB, which held tutors to short,
-- heavily compressed lessons. The organisation went to Pro on 9 October
-- 2026, where the global limit can go to 500 GB. 300 MB covers a 20 to 25
-- minute lesson in compressed 720p.
--
-- Not higher, for two reasons. Uploads go up in one request with no resume,
-- so on a dropped mobile connection a big file starts again from zero. And
-- every view is egress: Pro includes 250 GB a month, so a bigger file uses
-- the allowance up faster.
--
-- The project's global limit (Storage → Settings) must be at least this; it
-- caps every bucket. `kMaxVideoBytes` in the app mirrors this number.

update storage.buckets
   set file_size_limit = 314572800  -- 300 MiB
 where id = 'course-media';
