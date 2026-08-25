-- `is_teacher()` (added in 20260801000002) was a SECURITY DEFINER function in
-- the PostgREST-exposed `public` schema, so it was reachable as an RPC at
-- /rest/v1/rpc/is_teacher — flagged by the Supabase security advisor.
--
-- The check can simply be inlined: policy expressions are evaluated as the
-- calling user, and `profiles` is already selectable by signed-in users, so no
-- elevated function is needed.
drop policy if exists "Teachers can insert their own courses" on public.courses;
create policy "Teachers can insert their own courses"
  on public.courses for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'Teacher'
    )
  );

drop function if exists public.is_teacher();
