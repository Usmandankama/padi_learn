-- Payouts ledger and teacher balances (docs/ADMIN_PANEL.md, item 5).
--
-- Web checkout takes real money, and nothing recorded what PadiLearn then owes
-- each teacher or what it has already sent them. Transfers are made by hand
-- for now (automated Paystack Transfers wait for the marketplace review);
-- this records them and computes the balance they are paid from.
--
-- Rules decided 2026-10-06 (ADMIN_PANEL.md, decision 5):
--   1. A sale becomes payable 7 days after it was paid. Until then it is
--      pending, which covers early refunds and card disputes.
--   2. A refund after a payout takes the balance negative; later sales pay it
--      back. Nobody is chased for money.
--   3. Payouts go only to a Paystack-verified bank account, and the record
--      keeps a copy of the account it went to.
--   4. A payout cannot exceed what is payable.
--
-- balance   = teacher's share of every sale - refund clawbacks - payouts
-- pending   = teacher's share of unrefunded sales inside the hold
-- available = balance - pending   (what may be paid out now)

-- ---------------------------------------------------------------------------
-- 1. The holding period, in one place
-- ---------------------------------------------------------------------------

create or replace function public.payout_hold()
returns interval
language sql
immutable
set search_path = ''
as $$
  select interval '7 days';
$$;

revoke execute on function public.payout_hold() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. The table
-- ---------------------------------------------------------------------------

create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),

  -- SET NULL like the ledger: money that left stays recorded even if the
  -- teacher later closes their account.
  teacher_id uuid references auth.users(id) on delete set null,

  amount_kobo bigint not null check (amount_kobo > 0),

  -- Where it went, copied from payout_accounts at the time: the teacher may
  -- change their account later, and the record must still say where this
  -- money actually landed.
  bank_code text not null,
  bank_name text not null,
  account_number text not null check (account_number ~ '^[0-9]{10}$'),
  account_name text not null,

  -- The bank's or Paystack's reference for the transfer. Unique, so the same
  -- transfer cannot be recorded twice.
  transfer_reference text not null unique
    check (char_length(transfer_reference) between 1 and 200),
  note text check (char_length(note) <= 1000),

  -- When the money was sent, which may be before it was recorded here.
  paid_at timestamptz not null,
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists payouts_teacher_idx
  on public.payouts (teacher_id, paid_at desc);

alter table public.payouts enable row level security;

-- No policies and no grants, like `refunds`: written by admin_record_payout()
-- only, read through the admin RPCs. Teachers may see their own payouts later,
-- from the app, through policies added then.
revoke all on public.payouts from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Balances
-- ---------------------------------------------------------------------------
-- Internal; one definition shared by the list and by the payout check, so the
-- number an admin sees is the number the payout is checked against.
--
-- A refunded sale counts in `earned` and again, negatively, in `clawback`, so
-- it nets to zero; it is left out of `pending` for the same reason.

create or replace function public.teacher_balance_rows(p_teacher_id uuid default null)
returns table (
  teacher_id uuid,
  sales_count bigint,
  earned_kobo bigint,
  clawback_kobo bigint,
  paid_out_kobo bigint,
  pending_kobo bigint,
  balance_kobo bigint,
  available_kobo bigint
)
language sql
stable
set search_path = ''
as $$
  with teachers as (
    select t.teacher_id as id
      from public.transactions t
     where t.status = 'success' and t.teacher_id is not null
    union
    select p.teacher_id
      from public.payouts p
     where p.teacher_id is not null
  ),
  sales as (
    select t.teacher_id,
           count(*) as sales_count,
           sum(t.teacher_earning_kobo) as earned,
           sum(r.teacher_clawback_kobo) as clawback,
           sum(t.teacher_earning_kobo) filter (
             where r.id is null
               and coalesce(t.paid_at, t.created_at) > now() - public.payout_hold()
           ) as pending
      from public.transactions t
      left join public.refunds r on r.transaction_id = t.id
     where t.status = 'success' and t.teacher_id is not null
     group by t.teacher_id
  ),
  paid as (
    select p.teacher_id, sum(p.amount_kobo) as paid_out
      from public.payouts p
     where p.teacher_id is not null
     group by p.teacher_id
  )
  select
    tc.id,
    coalesce(s.sales_count, 0),
    coalesce(s.earned, 0)::bigint,
    coalesce(s.clawback, 0)::bigint,
    coalesce(pd.paid_out, 0)::bigint,
    coalesce(s.pending, 0)::bigint,
    (coalesce(s.earned, 0) - coalesce(s.clawback, 0) - coalesce(pd.paid_out, 0))::bigint,
    (coalesce(s.earned, 0) - coalesce(s.clawback, 0) - coalesce(pd.paid_out, 0)
      - coalesce(s.pending, 0))::bigint
  from teachers tc
  left join sales s on s.teacher_id = tc.id
  left join paid pd on pd.teacher_id = tc.id
  where p_teacher_id is null or tc.id = p_teacher_id;
$$;

revoke execute on function public.teacher_balance_rows(uuid) from public, anon, authenticated;

-- Every teacher with a sale or a payout, most payable first, with the bank
-- account an admin needs to make the transfer.
create or replace function public.admin_teacher_balances()
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
  account_verified boolean
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
    pa.verified_at is not null
  from public.teacher_balance_rows() b
  left join public.profiles p on p.id = b.teacher_id
  left join auth.users u on u.id = b.teacher_id
  left join public.payout_accounts pa on pa.user_id = b.teacher_id
  order by b.available_kobo desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Record a payout
-- ---------------------------------------------------------------------------
-- Called after the transfer has been made, with its reference. Locks the
-- teacher's bank account row, which serialises payouts per teacher, so two
-- admins cannot both pay out the same balance.

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
      'available_before_kobo', v_available
    )
  );

  return jsonb_build_object(
    'payout_id', v_payout_id,
    'amount_kobo', p_amount_kobo,
    'available_after_kobo', v_available - p_amount_kobo
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Payouts recorded so far
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_payouts(
  p_teacher_id uuid default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  paid_at timestamptz,
  created_at timestamptz,
  teacher_id uuid,
  teacher_name text,
  amount_kobo bigint,
  bank_name text,
  account_number text,
  account_name text,
  transfer_reference text,
  note text,
  recorded_by uuid,
  recorded_by_name text
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
    po.id,
    po.paid_at,
    po.created_at,
    po.teacher_id,
    teacher_p.name,
    po.amount_kobo,
    po.bank_name,
    po.account_number,
    po.account_name,
    po.transfer_reference,
    po.note,
    po.recorded_by,
    recorder_p.name
  from public.payouts po
  left join public.profiles teacher_p on teacher_p.id = po.teacher_id
  left join public.profiles recorder_p on recorder_p.id = po.recorded_by
  where p_teacher_id is null or po.teacher_id = p_teacher_id
  order by po.paid_at desc, po.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Callable by any signed-in user; assert_admin() inside is the gate.

revoke execute on function public.admin_teacher_balances() from public, anon;
revoke execute on function public.admin_record_payout(uuid, bigint, text, text, timestamptz) from public, anon;
revoke execute on function public.admin_list_payouts(uuid, integer, integer) from public, anon;
grant execute on function public.admin_teacher_balances() to authenticated;
grant execute on function public.admin_record_payout(uuid, bigint, text, text, timestamptz) to authenticated;
grant execute on function public.admin_list_payouts(uuid, integer, integer) to authenticated;
