-- Role correction (docs/ADMIN_PANEL.md, item 6).
--
-- `claim_role()` lets a user pick a role once, while it is unset, and
-- 20260803000001 took `role` away from client writes so nobody can promote
-- themselves. That leaves no way back for someone who tapped the wrong one at
-- signup, short of SQL in Studio. This is that way back, for admins.
--
-- A role can be set to Student, to Teacher, or cleared. Clearing sends the
-- user back to the role picker on their next launch, where `claim_role()`
-- lets them choose for themselves.
--
-- One refusal: a teacher who owns courses cannot be turned into a student or
-- cleared. The student shell has nowhere to manage courses, so they would be
-- stranded with their sales and students attached.

create or replace function public.admin_set_role(
  p_user_id uuid,
  p_role text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_old text;
  v_courses integer;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;
  if p_role is not null and p_role not in ('Student', 'Teacher') then
    raise exception 'Unknown role: %', p_role using errcode = '22023';
  end if;

  select p.role into v_old
    from public.profiles p
   where p.id = p_user_id
     for update;
  if not found then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if v_old is not distinct from p_role then
    raise exception 'This user already has that role' using errcode = '22023';
  end if;

  if v_old = 'Teacher' then
    select count(*) into v_courses
      from public.courses c
     where c.user_id = p_user_id;
    if v_courses > 0 then
      raise exception 'This teacher owns % course(s), which a student account cannot manage',
        v_courses using errcode = '22023';
    end if;
  end if;

  update public.profiles
     set role = p_role
   where id = p_user_id;

  perform public.log_admin_action(
    'user.set_role', 'user', p_user_id, v_reason,
    jsonb_build_object('from', v_old, 'to', p_role)
  );
end;
$$;

-- Callable by any signed-in user; assert_admin() inside is the gate.
revoke execute on function public.admin_set_role(uuid, text, text) from public, anon;
grant execute on function public.admin_set_role(uuid, text, text) to authenticated;
