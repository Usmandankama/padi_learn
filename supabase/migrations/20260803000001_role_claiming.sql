-- Role becomes something a user *claims*, not something signup happens to know.
--
-- Email signup collects the role on the register form, so it arrives as auth
-- metadata. Google/Apple never can: the provider returns an identity and
-- nothing else. Rather than guess on their behalf, a profile is now allowed to
-- exist with `role` still null, which the app reads as "onboarding unfinished"
-- and answers with the role picker.

-- 1. Only ever store a role we recognise.
--
-- `raw_user_meta_data` is supplied by the client at signup, so it is user
-- input like any other. The two valid values were previously trusted on
-- arrival; anything else landed in the column verbatim and would have sent the
-- shell down the student branch by falling through the `== 'Student'` check.
alter table public.profiles
  drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role is null or role in ('Student', 'Teacher'));

-- 2. Stop defaulting the role at signup.
--
-- The old `coalesce(..., 'Student')` was harmless while email was the only way
-- in, because the form always sent one. With OAuth it would silently decide a
-- teacher is a student, with no prompt and no way back.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  claimed text := new.raw_user_meta_data ->> 'role';
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    new.raw_user_meta_data ->> 'name',
    new.email,
    -- Left null when absent or unrecognised, so the app asks.
    case when claimed in ('Student', 'Teacher') then claimed end
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- 3. A role can be claimed once, and only while unset.
--
-- Needed because step 4 takes the column away from clients. Security definer
-- so it can write the column the caller no longer can, and the `role is null`
-- predicate is what stops it from doubling as a self-promotion endpoint: a
-- student cannot call this to become a teacher, because their role is already
-- set. Returns the role now in force so a lost response can be retried without
-- the second call looking like a failure.
create or replace function public.claim_role(p_role text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  current_role_value text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  if p_role not in ('Student', 'Teacher') then
    raise exception 'Unknown role: %', p_role;
  end if;

  update public.profiles
     set role = p_role
   where id = auth.uid()
     and role is null;

  select role into current_role_value
    from public.profiles
   where id = auth.uid();

  if current_role_value is null then
    raise exception 'No profile to claim a role for';
  end if;

  return current_role_value;
end;
$function$;

revoke execute on function public.claim_role(text) from anon, public;
grant execute on function public.claim_role(text) to authenticated;

-- 4. Take `role` out of reach of direct writes.
--
-- The "Users can update their own profile" policy is `auth.uid() = id` with no
-- WITH CHECK, so until now any signed-in user could patch their own row and
-- promote themselves to Teacher — bypassing every teacher-gated policy behind
-- one client call. RLS cannot express "any column but this one", so the grant
-- is narrowed instead: same reasoning as `payout_accounts`, a column-level
-- REVOKE cannot narrow a table-level grant, so the table grant goes first.
--
-- `name` and `profile_image_url` are the only columns the app updates
-- (editprofile_screen.dart). `email` is owned by auth, `role` by claim_role.
revoke update on public.profiles from anon, authenticated;
grant update (name, profile_image_url) on public.profiles to authenticated;
