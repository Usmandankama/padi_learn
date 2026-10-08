-- The parts of the old project that live in Supabase's own schemas, which the
-- schema dump leaves out on purpose (Supabase recreates those schemas itself).
-- Generated from the live project on 2026-10-08 with pg_get_triggerdef() and
-- pg_policies. Supabase's own storage triggers are not here: every new project
-- has them already.

-- A profile row for every new account (handle_new_user() is in the public
-- schema, so the schema dump carries it).
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Storage access rules. Public buckets are readable by anyone; course media
-- only by its owner (students get signed URLs from get-course-video); uploads
-- go into a folder named after the uploader's user id.
create policy "Public buckets are readable" on storage.objects as permissive for select to public
  using ((bucket_id = any (array['profile-images'::text, 'course-thumbnails'::text])));

create policy "Owners can read their own course media" on storage.objects as permissive for select to authenticated
  using (((bucket_id = 'course-media'::text) and ((storage.foldername(name))[1] = (auth.uid())::text)));

create policy "Users can upload to their own folder" on storage.objects as permissive for insert to authenticated
  with check (((bucket_id = any (array['course-media'::text, 'profile-images'::text, 'course-thumbnails'::text])) and ((storage.foldername(name))[1] = (auth.uid())::text)));

create policy "Users can update their own media" on storage.objects as permissive for update to authenticated
  using (((bucket_id = any (array['course-media'::text, 'profile-images'::text, 'course-thumbnails'::text])) and ((storage.foldername(name))[1] = (auth.uid())::text)))
  with check (((bucket_id = any (array['course-media'::text, 'profile-images'::text, 'course-thumbnails'::text])) and ((storage.foldername(name))[1] = (auth.uid())::text)));

create policy "Users can delete their own media" on storage.objects as permissive for delete to authenticated
  using (((bucket_id = any (array['course-media'::text, 'profile-images'::text, 'course-thumbnails'::text])) and ((storage.foldername(name))[1] = (auth.uid())::text)));

-- Suspension (docs/ADMIN_PANEL.md, decision 6): restrictive, so they cut
-- across every permissive rule above.
create policy "Suspended users cannot insert" on storage.objects as restrictive for insert to authenticated
  with check ((not private.is_suspended((select auth.uid() as uid))));

create policy "Suspended users cannot update" on storage.objects as restrictive for update to authenticated
  with check ((not private.is_suspended((select auth.uid() as uid))));

create policy "Suspended users cannot delete" on storage.objects as restrictive for delete to authenticated
  using ((not private.is_suspended((select auth.uid() as uid))));
