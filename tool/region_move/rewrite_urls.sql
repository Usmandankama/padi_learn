-- Public image URLs are stored whole, so they name the old project's host.
-- Course media is stored as a bare object path and needs nothing.
-- Run by restore.sh with -v old_host=... -v new_host=...
--
-- Triggers stay off for these updates: none of them is a real edit.
set session_replication_role = replica;

update public.courses
   set thumbnail_url = replace(thumbnail_url, :'old_host', :'new_host')
 where thumbnail_url like '%' || :'old_host' || '%';

update public.profiles
   set profile_image_url = replace(profile_image_url, :'old_host', :'new_host')
 where profile_image_url like '%' || :'old_host' || '%';

update public.enrollments
   set image = replace(image, :'old_host', :'new_host')
 where image like '%' || :'old_host' || '%';

reset session_replication_role;
