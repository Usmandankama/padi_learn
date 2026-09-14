-- Storage hardening.
--
-- Fixes two critical findings:
--   * "Anon can upload course media" let ANY unauthenticated caller write
--     50 MB objects into the course bucket.
--   * `course-media` was a public bucket, so every paid course video was
--     downloadable by anyone holding the (shipped) publishable key.
--
-- New shape:
--   course-media       PRIVATE  videos; reachable only via short-lived signed
--                               URLs issued by the `get-course-video` function
--                               after an enrollment check.
--   course-thumbnails  PUBLIC   cover images; safe to serve directly so course
--                               listings stay fast and cacheable.
--   profile-images     PUBLIC   avatars.

-- 1. Close the anonymous upload hole.
drop policy if exists "Anon can upload course media" on storage.objects;

-- 2. Dedicated public bucket for thumbnails.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('course-thumbnails', 'course-thumbnails', true, 10485760, array['image/*'])
on conflict (id) do update set public = true;

-- 3. Course videos become private.
update storage.buckets set public = false where id = 'course-media';

-- 4. Public read now covers only the non-sensitive buckets.
drop policy if exists "Media is publicly readable" on storage.objects;
create policy "Public buckets are readable"
  on storage.objects for select to public
  using (bucket_id in ('profile-images', 'course-thumbnails'));

-- 5. A teacher can still read back their own raw uploads.
drop policy if exists "Owners can read their own course media" on storage.objects;
create policy "Owners can read their own course media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'course-media'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

-- 6. Consolidate the own-folder write policies across all three buckets.
--    (Two overlapping INSERT policies existed before.)
drop policy if exists "Users can upload to their own folder" on storage.objects;
drop policy if exists "Users upload into their own folder" on storage.objects;
create policy "Users can upload to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('course-media', 'profile-images', 'course-thumbnails')
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists "Users can update their own media" on storage.objects;
create policy "Users can update their own media"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('course-media', 'profile-images', 'course-thumbnails')
    and (storage.foldername(name))[1] = (auth.uid())::text
  )
  with check (
    bucket_id in ('course-media', 'profile-images', 'course-thumbnails')
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists "Users can delete their own media" on storage.objects;
create policy "Users can delete their own media"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('course-media', 'profile-images', 'course-thumbnails')
    and (storage.foldername(name))[1] = (auth.uid())::text
  );
