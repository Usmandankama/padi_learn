-- A house account cannot be suspended.
--
-- On 9 October the "PadiLearn" house account was suspended while trying the
-- admin panel, and every course it owns, the whole demo catalogue, vanished
-- from the web app and the APK. Suspension is meant for a teacher who broke
-- the rules; the house account is PadiLearn itself. To take one of its
-- courses off sale, take that course down instead.
--
-- Same function as 20261006000010_account_suspension.sql, with one more check
-- after the admins check. CREATE OR REPLACE keeps the existing grants.

create or replace function public.admin_suspend_user(p_user_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_role text;
  v_hidden integer;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  -- Covers suspending yourself, since the caller is an admin.
  if exists (select 1 from public.admins a where a.user_id = p_user_id) then
    raise exception 'Admins cannot be suspended' using errcode = '22023';
  end if;
  if exists (select 1 from public.house_accounts h where h.user_id = p_user_id) then
    raise exception 'This is a PadiLearn house account. Take down a course instead of suspending the account'
      using errcode = '22023';
  end if;
  if exists (select 1 from public.suspensions s where s.user_id = p_user_id) then
    raise exception 'This user is already suspended' using errcode = '22023';
  end if;

  insert into public.suspensions (user_id, reason, suspended_by)
  values (p_user_id, v_reason, auth.uid());

  select p.role into v_role from public.profiles p where p.id = p_user_id;
  select count(*) into v_hidden
    from public.courses c
   where c.user_id = p_user_id
     and c.archived_at is null
     and c.removed_at is null;

  perform public.log_admin_action(
    'user.suspend', 'user', p_user_id, v_reason,
    jsonb_build_object('role', v_role, 'courses_hidden', v_hidden)
  );

  return jsonb_build_object('courses_hidden', v_hidden);
end;
$$;
