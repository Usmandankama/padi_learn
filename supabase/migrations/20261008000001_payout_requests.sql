-- Teachers ask to be paid (docs/ADMIN_PANEL.md, item 15).
--
-- Until now a payout started only on the admin's side: the panel listed who
-- had money ready, and a teacher's only way to say "please send it" was an
-- email. A request is that sentence, recorded. It moves no money. The
-- transfer is still made by hand, and admin_record_payout() closes the
-- request when the transfer is recorded.
--
-- Rules:
--   1. One open request per teacher, for everything payable when it was made.
--   2. Only with a Paystack-verified bank account, only while not suspended,
--      and only from payout_minimum() up: a transfer costs the same whether
--      it carries NGN 200 or NGN 20,000.
--   3. The teacher can cancel an open request. An admin can decline one, with
--      a reason the teacher is shown.
--   4. Recording a payout closes the teacher's open request as paid, even if
--      the amount differs (a partial payout leaves the rest for a new request).
--   5. The teacher is notified when the money is recorded as sent, or when a
--      request is declined.

-- ---------------------------------------------------------------------------
-- 1. The smallest request, in one place
-- ---------------------------------------------------------------------------

create or replace function public.payout_minimum()
returns bigint
language sql
immutable
set search_path = ''
as $$
  select 100000::bigint;  -- NGN 1,000, in kobo
$$;

revoke execute on function public.payout_minimum() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. The table
-- ---------------------------------------------------------------------------

create table if not exists public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references auth.users(id) on delete cascade,

  -- What was payable when the teacher asked. The payout itself may differ.
  amount_kobo bigint not null check (amount_kobo > 0),

  status text not null default 'open'
    check (status in ('open', 'paid', 'cancelled', 'declined')),

  -- The payout that closed it, when status is 'paid'.
  payout_id uuid references public.payouts(id) on delete set null,

  -- Shown to the teacher when a request is declined.
  resolution_note text check (char_length(resolution_note) <= 1000),
  resolved_by uuid references auth.users(id) on delete set null,

  created_at timestamptz not null default now(),
  resolved_at timestamptz,

  check ((status = 'open') = (resolved_at is null))
);

-- Rule 1, enforced where two taps at once cannot get round it.
create unique index if not exists payout_requests_one_open
  on public.payout_requests (teacher_id) where status = 'open';

create index if not exists payout_requests_teacher_idx
  on public.payout_requests (teacher_id, created_at desc);
create index if not exists payout_requests_payout_idx
  on public.payout_requests (payout_id) where payout_id is not null;
create index if not exists payout_requests_resolved_by_idx
  on public.payout_requests (resolved_by) where resolved_by is not null;

alter table public.payout_requests enable row level security;

-- No policies and no grants, like `payouts`: written and read only through
-- the functions below.
revoke all on public.payout_requests from anon, authenticated;

-- A third kind of notification, for the teacher.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type in ('comment', 'enrollment', 'payout'));

-- ---------------------------------------------------------------------------
-- 3. The teacher's side
-- ---------------------------------------------------------------------------

create or replace function public.request_payout()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_available bigint;
  v_request_id uuid;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  if exists (select 1 from public.suspensions s where s.user_id = v_uid) then
    raise exception 'Payouts are on hold while your account is suspended'
      using errcode = '22023';
  end if;

  -- Locks the bank account row, as admin_record_payout() does, so a request
  -- and a payout for the same teacher cannot interleave.
  perform 1
    from public.payout_accounts pa
   where pa.user_id = v_uid and pa.verified_at is not null
     for update;
  if not found then
    raise exception 'Add a verified bank account before asking for a payout'
      using errcode = '22023';
  end if;

  if exists (
    select 1 from public.payout_requests r
     where r.teacher_id = v_uid and r.status = 'open'
  ) then
    raise exception 'You already have a payout request waiting'
      using errcode = '22023';
  end if;

  select b.available_kobo into v_available
    from public.teacher_balance_rows(v_uid) b;
  v_available := coalesce(v_available, 0);

  if v_available < public.payout_minimum() then
    raise exception 'Payouts start at NGN %. You have NGN % ready.',
      to_char(public.payout_minimum() / 100.0, 'FM999,999,990'),
      to_char(greatest(v_available, 0) / 100.0, 'FM999,999,990.00')
      using errcode = '22023';
  end if;

  insert into public.payout_requests (teacher_id, amount_kobo)
  values (v_uid, v_available)
  returning id into v_request_id;

  return jsonb_build_object('request_id', v_request_id, 'amount_kobo', v_available);
end;
$$;

create or replace function public.cancel_payout_request()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  update public.payout_requests r
     set status = 'cancelled', resolved_at = now(), resolved_by = v_uid
   where r.teacher_id = v_uid and r.status = 'open';

  if not found then
    raise exception 'There is no payout request to cancel' using errcode = 'P0002';
  end if;
end;
$$;

-- Everything the teacher's payouts screen shows, for the caller only: the
-- open request, the last closed one (so a declined request's reason reaches
-- them), and the transfers made. The admin's note on a payout stays internal.
create or replace function public.my_payouts()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'minimum_kobo', public.payout_minimum(),

    'open_request', (
      select jsonb_build_object(
               'id', r.id, 'amount_kobo', r.amount_kobo, 'created_at', r.created_at)
        from public.payout_requests r
       where r.teacher_id = v_uid and r.status = 'open'
    ),

    'last_closed_request', (
      select jsonb_build_object(
               'status', r.status,
               'amount_kobo', r.amount_kobo,
               'created_at', r.created_at,
               'resolved_at', r.resolved_at,
               'resolution_note', r.resolution_note)
        from public.payout_requests r
       where r.teacher_id = v_uid and r.status <> 'open'
       order by r.resolved_at desc, r.created_at desc
       limit 1
    ),

    'payouts', coalesce((
      select jsonb_agg(p order by p.paid_at desc)
        from (
          select po.amount_kobo,
                 po.paid_at,
                 po.bank_name,
                 right(po.account_number, 4) as account_last4,
                 po.transfer_reference
            from public.payouts po
           where po.teacher_id = v_uid
           order by po.paid_at desc
           limit 50
        ) p
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.request_payout() from public, anon;
revoke execute on function public.cancel_payout_request() from public, anon;
revoke execute on function public.my_payouts() from public, anon;
grant execute on function public.request_payout() to authenticated;
grant execute on function public.cancel_payout_request() to authenticated;
grant execute on function public.my_payouts() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. The admin's side
-- ---------------------------------------------------------------------------

-- Balances gain the open request, and teachers who asked come first, oldest
-- request first. The return type changes, so the function is replaced whole.
drop function if exists public.admin_teacher_balances();

create function public.admin_teacher_balances()
returns table (
  teacher_id uuid,
  teacher_name text,
  teacher_email text,
  sales_count bigint,
  earned_kobo bigint,
  clawback_kobo bigint,
  paid_out_kobo bigint,
  pending_kobo bigint,
  balance_kobo bigint,
  available_kobo bigint,
  bank_name text,
  account_number text,
  account_name text,
  account_verified boolean,
  suspended boolean,
  request_id uuid,
  requested_kobo bigint,
  requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.assert_admin();

  return query
  select
    b.teacher_id,
    p.name,
    coalesce(u.email::text, p.email),
    b.sales_count,
    b.earned_kobo,
    b.clawback_kobo,
    b.paid_out_kobo,
    b.pending_kobo,
    b.balance_kobo,
    b.available_kobo,
    pa.bank_name,
    pa.account_number,
    pa.account_name,
    pa.verified_at is not null,
    exists (select 1 from public.suspensions s where s.user_id = b.teacher_id),
    r.id,
    r.amount_kobo,
    r.created_at
  from public.teacher_balance_rows() b
  left join public.profiles p on p.id = b.teacher_id
  left join auth.users u on u.id = b.teacher_id
  left join public.payout_accounts pa on pa.user_id = b.teacher_id
  left join public.payout_requests r
    on r.teacher_id = b.teacher_id and r.status = 'open'
  order by (r.id is not null) desc, r.created_at asc nulls last, b.available_kobo desc;
end;
$$;

revoke execute on function public.admin_teacher_balances() from public, anon;
grant execute on function public.admin_teacher_balances() to authenticated;

-- Unchanged up to the insert; then closes the open request and tells the
-- teacher the money is on its way.
create or replace function public.admin_record_payout(
  p_teacher_id uuid,
  p_amount_kobo bigint,
  p_transfer_reference text,
  p_note text default null,
  p_paid_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ref text := nullif(btrim(p_transfer_reference), '');
  v_note text := nullif(btrim(p_note), '');
  v_paid_at timestamptz := coalesce(p_paid_at, now());
  v_account record;
  v_available bigint;
  v_payout_id uuid;
  v_request_id uuid;
begin
  perform public.assert_admin();

  if v_ref is null then
    raise exception 'The transfer reference is required' using errcode = '22023';
  end if;
  if p_amount_kobo is null or p_amount_kobo <= 0 then
    raise exception 'The amount must be more than zero' using errcode = '22023';
  end if;
  if v_paid_at > now() + interval '5 minutes' then
    raise exception 'The payment date cannot be in the future' using errcode = '22023';
  end if;
  if exists (select 1 from public.suspensions s where s.user_id = p_teacher_id) then
    raise exception 'Payouts are held while this teacher is suspended' using errcode = '22023';
  end if;

  select pa.bank_code, pa.bank_name, pa.account_number, pa.account_name, pa.verified_at
    into v_account
    from public.payout_accounts pa
   where pa.user_id = p_teacher_id
     for update;
  if not found or v_account.verified_at is null then
    raise exception 'This teacher has no verified bank account' using errcode = '22023';
  end if;

  if exists (select 1 from public.payouts p where p.transfer_reference = v_ref) then
    raise exception 'This transfer reference is already recorded' using errcode = '22023';
  end if;

  select b.available_kobo into v_available
    from public.teacher_balance_rows(p_teacher_id) b;
  v_available := coalesce(v_available, 0);

  if p_amount_kobo > v_available then
    raise exception 'Amount is more than the available balance of NGN %',
      to_char(v_available / 100.0, 'FM999,999,999,990.00')
      using errcode = '22023';
  end if;

  insert into public.payouts (
    teacher_id, amount_kobo, bank_code, bank_name, account_number, account_name,
    transfer_reference, note, paid_at, recorded_by
  )
  values (
    p_teacher_id, p_amount_kobo, v_account.bank_code, v_account.bank_name,
    v_account.account_number, v_account.account_name,
    v_ref, v_note, v_paid_at, auth.uid()
  )
  returning id into v_payout_id;

  update public.payout_requests r
     set status = 'paid', payout_id = v_payout_id,
         resolved_at = now(), resolved_by = auth.uid()
   where r.teacher_id = p_teacher_id and r.status = 'open'
  returning r.id into v_request_id;

  insert into public.notifications (recipient_id, type, message)
  select p_teacher_id, 'payout',
         'NGN ' || to_char(p_amount_kobo / 100.0, 'FM999,999,999,990.00')
           || ' has been sent to your ' || v_account.bank_name
           || ' account ending ' || right(v_account.account_number, 4) || '.'
   where exists (select 1 from public.profiles pr where pr.id = p_teacher_id);

  perform public.log_admin_action(
    'payout.record', 'payout', v_payout_id, v_note,
    jsonb_build_object(
      'teacher_id', p_teacher_id,
      'amount_kobo', p_amount_kobo,
      'transfer_reference', v_ref,
      'bank_name', v_account.bank_name,
      'account_last4', right(v_account.account_number, 4),
      'account_name', v_account.account_name,
      'paid_at', v_paid_at,
      'available_before_kobo', v_available,
      'request_id', v_request_id
    )
  );

  return jsonb_build_object(
    'payout_id', v_payout_id,
    'amount_kobo', p_amount_kobo,
    'available_after_kobo', v_available - p_amount_kobo,
    'request_id', v_request_id
  );
end;
$$;

create or replace function public.admin_decline_payout_request(
  p_request_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_request record;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required: the teacher is shown it' using errcode = '22023';
  end if;

  update public.payout_requests r
     set status = 'declined', resolution_note = v_reason,
         resolved_at = now(), resolved_by = auth.uid()
   where r.id = p_request_id and r.status = 'open'
  returning r.teacher_id, r.amount_kobo into v_request;

  if not found then
    if exists (select 1 from public.payout_requests r where r.id = p_request_id) then
      raise exception 'This request is no longer open' using errcode = '22023';
    end if;
    raise exception 'No such payout request' using errcode = 'P0002';
  end if;

  insert into public.notifications (recipient_id, type, message)
  select v_request.teacher_id, 'payout',
         'Your payout request for NGN '
           || to_char(v_request.amount_kobo / 100.0, 'FM999,999,999,990.00')
           || ' was declined: ' || v_reason
   where exists (select 1 from public.profiles pr where pr.id = v_request.teacher_id);

  perform public.log_admin_action(
    'payout_request.decline', 'payout_request', p_request_id, v_reason,
    jsonb_build_object(
      'teacher_id', v_request.teacher_id,
      'amount_kobo', v_request.amount_kobo
    )
  );
end;
$$;

revoke execute on function public.admin_decline_payout_request(uuid, text) from public, anon;
grant execute on function public.admin_decline_payout_request(uuid, text) to authenticated;

-- The overview's "Waiting for you" gains the open requests. Otherwise the
-- live definition (20261006000010) unchanged.
create or replace function public.admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_week timestamptz := now() - interval '7 days';
  v_month timestamptz := now() - interval '30 days';
  v_overview jsonb;
begin
  perform public.assert_admin();

  with
  sales as (
    select
      count(*) as sales,
      count(*) filter (where coalesce(t.paid_at, t.created_at) > v_week) as sales_7d,
      count(*) filter (where coalesce(t.paid_at, t.created_at) > v_month) as sales_30d,
      coalesce(sum(t.amount_kobo), 0) as gross,
      coalesce(sum(t.amount_kobo) filter (where coalesce(t.paid_at, t.created_at) > v_month), 0) as gross_30d,
      coalesce(sum(t.paystack_fee_kobo), 0) as paystack_fees,
      coalesce(sum(t.platform_fee_kobo), 0) as platform_fees,
      coalesce(sum(t.teacher_earning_kobo), 0) as teacher_earnings
    from public.transactions t
    where t.status = 'success'
  ),
  refunded as (
    select
      count(*) as refunds,
      coalesce(sum(r.amount_kobo), 0) as amount,
      coalesce(sum(r.teacher_clawback_kobo), 0) as clawback,
      coalesce(sum(r.platform_cost_kobo), 0) as platform_cost
    from public.refunds r
  ),
  owed as (
    select count(*) as sales, coalesce(sum(t.amount_kobo), 0) as amount
    from public.transactions t
    join public.courses c on c.id = t.course_id
    where t.status = 'success'
      and c.removed_at is not null
      and not exists (select 1 from public.refunds r where r.transaction_id = t.id)
  ),
  balances as (
    select
      coalesce(sum(greatest(b.balance_kobo, 0)), 0) as owed_total,
      coalesce(sum(greatest(b.available_kobo, 0)), 0) as available_total,
      coalesce(sum(b.pending_kobo), 0) as pending_total,
      -- Teachers whose refunds outran their earnings; recovered from later sales.
      coalesce(sum(least(b.balance_kobo, 0)), 0) as negative_total,
      count(*) filter (
        where b.available_kobo > 0
          and not exists (select 1 from public.suspensions s where s.user_id = b.teacher_id)
      ) as payable,
      count(*) filter (
        where b.available_kobo > 0
          and not exists (select 1 from public.suspensions s where s.user_id = b.teacher_id)
          and not exists (
            select 1 from public.payout_accounts pa
             where pa.user_id = b.teacher_id and pa.verified_at is not null
          )
      ) as payable_without_account,
      count(*) filter (
        where b.available_kobo > 0
          and exists (select 1 from public.suspensions s where s.user_id = b.teacher_id)
      ) as held
    from public.teacher_balance_rows() b
  ),
  requested as (
    select count(*) as requests, coalesce(sum(r.amount_kobo), 0) as amount
    from public.payout_requests r
    where r.status = 'open'
  ),
  paid as (
    select count(*) as payouts, coalesce(sum(p.amount_kobo), 0) as amount
    from public.payouts p
  )
  select jsonb_build_object(
    'generated_at', now(),

    'waiting', jsonb_build_object(
      'open_reports', (select count(*) from public.content_reports cr where cr.status = 'open'),
      'category_suggestions', (select count(*) from public.categories c where not c.is_active),
      'refunds_owed', (select sales from owed),
      'refunds_owed_kobo', (select amount from owed),
      'payout_requests', (select requests from requested),
      'payout_requests_kobo', (select amount from requested),
      'teachers_payable', (select payable from balances),
      'teachers_payable_without_bank_account', (select payable_without_account from balances),
      'teachers_payouts_held', (select held from balances)
    ),

    'accounts', jsonb_build_object(
      'total', (select count(*) from auth.users),
      'teachers', (select count(*) from public.profiles p where p.role = 'Teacher'),
      'students', (select count(*) from public.profiles p where p.role = 'Student'),
      'role_not_chosen', (select count(*) from public.profiles p where p.role is null),
      'new_7d', (select count(*) from auth.users u where u.created_at > v_week),
      'new_30d', (select count(*) from auth.users u where u.created_at > v_month),
      'suspended', (select count(*) from public.suspensions),
      'admins', (select count(*) from public.admins)
    ),

    'catalogue', jsonb_build_object(
      'courses', (select count(*) from public.courses),
      'live', (select count(*) from public.courses c where c.archived_at is null and c.removed_at is null),
      'archived', (select count(*) from public.courses c where c.archived_at is not null and c.removed_at is null),
      'taken_down', (select count(*) from public.courses c where c.removed_at is not null),
      'paid', (select count(*) from public.courses c where coalesce(c.price, 0) > 0),
      'lessons', (select count(*) from public.lessons),
      'teachers_with_live_courses', (
        select count(distinct c.user_id) from public.courses c
         where c.archived_at is null and c.removed_at is null
      )
    ),

    'learning', jsonb_build_object(
      'enrollments', (select count(*) from public.enrollments),
      'paid_enrollments', (select count(*) from public.enrollments e where not e.is_free),
      'enrollments_7d', (select count(*) from public.enrollments e where e.enrolled_at > v_week)
    ),

    'money', (
      select jsonb_build_object(
        'sales', s.sales,
        'sales_7d', s.sales_7d,
        'sales_30d', s.sales_30d,
        'gross_kobo', s.gross,
        'gross_30d_kobo', s.gross_30d,
        'paystack_fees_kobo', s.paystack_fees,
        'platform_fees_kobo', s.platform_fees,
        'teacher_earnings_kobo', s.teacher_earnings,
        'refunds', rf.refunds,
        'refunded_kobo', rf.amount,
        'refund_clawbacks_kobo', rf.clawback,
        'refund_cost_to_platform_kobo', rf.platform_cost,
        -- What PadiLearn actually kept: commission, less what refunds cost it.
        'platform_net_kobo', s.platform_fees - rf.platform_cost,
        'payouts', pd.payouts,
        'paid_out_kobo', pd.amount,
        'teachers_owed_kobo', b.owed_total,
        'teachers_available_kobo', b.available_total,
        'teachers_pending_kobo', b.pending_total,
        'teachers_negative_kobo', b.negative_total
      )
      from sales s, refunded rf, paid pd, balances b
    )
  )
  into v_overview;

  return v_overview;
end;
$$;
