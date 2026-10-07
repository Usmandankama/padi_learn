-- A teacher's own balance (docs/ADMIN_PANEL.md, item 13).
--
-- The app's earnings card summed `transactions.teacher_earning_kobo`, so it
-- never knew about refund clawbacks (item 4) or payouts (item 5): a teacher
-- whose sale was refunded still saw the money, and one who had been paid saw
-- nothing change. This returns the same figures the admin panel pays from,
-- from the same definition, for the caller only.
--
-- teacher_balance_rows() returns *every* teacher when given null, so a call
-- with no signed-in user must stop here rather than pass null through.

create or replace function public.my_teacher_balance()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_balance jsonb;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  select to_jsonb(b) - 'teacher_id'
    into v_balance
    from public.teacher_balance_rows(v_uid) b;

  -- A teacher with no sale and no payout has no row; that is all zeros.
  return coalesce(v_balance, jsonb_build_object(
           'sales_count', 0,
           'earned_kobo', 0,
           'clawback_kobo', 0,
           'paid_out_kobo', 0,
           'pending_kobo', 0,
           'balance_kobo', 0,
           'available_kobo', 0
         ))
         || jsonb_build_object(
           'payouts_held',
           exists (select 1 from public.suspensions s where s.user_id = v_uid)
         );
end;
$$;

-- Any signed-in user may call it; it only ever answers about the caller.
revoke execute on function public.my_teacher_balance() from public, anon;
grant execute on function public.my_teacher_balance() to authenticated;
