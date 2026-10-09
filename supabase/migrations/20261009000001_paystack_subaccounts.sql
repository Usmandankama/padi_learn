-- Teachers are paid by Paystack split payments (docs/STATUS.md, payments).
--
-- Until now every sale settled into PadiLearn's Paystack account and teachers
-- were paid by hand from a balance. Paystack approved PadiLearn (9 October
-- 2026) on the split model: each teacher has a Paystack *subaccount*, and a
-- sale is split at checkout, the teacher's 85% going to their own bank.
--
-- What this adds:
--   1. `paystack_subaccounts`: the subaccount Paystack created for a teacher.
--      Created or updated by the `payout-account` edge function whenever the
--      teacher saves a verified bank account. Its own table rather than a
--      column on `payout_accounts`, because a teacher can delete that row and
--      re-adding a bank must update the same subaccount, not orphan it.
--   2. `house_accounts`: PadiLearn's own teaching accounts. Their sales stay
--      wholly in the company account, with no subaccount.
--   3. Selling a paid course needs a subaccount (or a house account). Checked
--      at checkout by `initialize-payment`, and when a course is created paid
--      or turned from free to paid, by the trigger below.
--   4. The ledger records what Paystack settled straight to the teacher
--      (`settled_direct_kobo`), so the balance PadiLearn owes leaves it out.
--
-- The balance keeps its meaning: what PadiLearn itself owes the teacher.
--
--   balance   = teacher's share of every sale - what Paystack settled to them
--               - refund clawbacks - payouts
--   pending   = PadiLearn-held share of unrefunded sales inside the hold
--   available = balance - pending
--
-- A split sale adds its share and its settlement, so it nets to zero. A refund
-- of a split sale takes the balance negative (the teacher already has the
-- money); `checkout_terms()` reports that as debt and `initialize-payment`
-- keeps it back from the teacher's next sales, as rule 2 of
-- 20261006000005_payouts_ledger.sql always said.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.paystack_subaccounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  subaccount_code text not null unique
    check (char_length(subaccount_code) between 5 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.paystack_subaccounts enable row level security;

-- No policies: written by the `payout-account` function (service role), read
-- through the functions below.
revoke all on public.paystack_subaccounts from anon, authenticated;
grant select, insert, update, delete on public.paystack_subaccounts to service_role;

create table if not exists public.house_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now()
);

alter table public.house_accounts enable row level security;
revoke all on public.house_accounts from anon, authenticated;
grant select, insert, update, delete on public.house_accounts to service_role;

-- The "PadiLearn" teacher that owns the demo catalogue. No-op on a project
-- that does not have it.
insert into public.house_accounts (user_id, note)
select u.id, 'The PadiLearn house account: demo catalogue and own courses'
  from auth.users u
 where u.id = 'f7c2beac-4f9f-442d-ba5b-49291a82b722'
on conflict (user_id) do nothing;

alter table public.transactions
  add column if not exists subaccount_code text,
  add column if not exists settled_direct_kobo bigint not null default 0;

alter table public.transactions
  drop constraint if exists transactions_settled_direct_check;
alter table public.transactions
  add constraint transactions_settled_direct_check
  check (settled_direct_kobo >= 0 and settled_direct_kobo <= amount_kobo);

-- ---------------------------------------------------------------------------
-- 2. Who may sell
-- ---------------------------------------------------------------------------

-- A house account, or a teacher with a verified bank account and a
-- subaccount. One definition for the trigger, checkout and the app.
create or replace function public.can_sell_paid(p_teacher_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_teacher_id is not null and (
    exists (select 1 from public.house_accounts h where h.user_id = p_teacher_id)
    or exists (
      select 1
        from public.payout_accounts pa
        join public.paystack_subaccounts s on s.user_id = pa.user_id
       where pa.user_id = p_teacher_id and pa.verified_at is not null
    )
  );
$$;

revoke execute on function public.can_sell_paid(uuid) from public, anon, authenticated;
grant execute on function public.can_sell_paid(uuid) to service_role;

-- What the app needs to explain why a price cannot be set yet.
create or replace function public.my_selling_status()
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
    'can_sell', public.can_sell_paid(v_uid),
    'has_bank', exists (
      select 1 from public.payout_accounts pa
       where pa.user_id = v_uid and pa.verified_at is not null
    )
  );
end;
$$;

revoke execute on function public.my_selling_status() from public, anon;
grant execute on function public.my_selling_status() to authenticated;

-- Only creating a paid course, or turning a free one paid, is refused: a
-- teacher who later removes their bank account can still edit their course,
-- and checkout refuses to sell it until the account is back.
create or replace function private.require_payouts_for_paid_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.price, 0) > 0
     and (tg_op = 'INSERT' or coalesce(old.price, 0) <= 0)
     and not public.can_sell_paid(new.user_id) then
    raise exception 'Add your bank account under Profile, Payouts before charging for a course'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke execute on function private.require_payouts_for_paid_course() from public, anon, authenticated;

drop trigger if exists before_course_price_needs_payouts on public.courses;
create trigger before_course_price_needs_payouts
  before insert or update of price on public.courses
  for each row execute function private.require_payouts_for_paid_course();

-- ---------------------------------------------------------------------------
-- 3. Balances
-- ---------------------------------------------------------------------------
-- Same as 20261006000005, plus what Paystack settled directly. The new column
-- goes last; every caller reads columns by name or through to_jsonb().

drop function if exists public.teacher_balance_rows(uuid);

create function public.teacher_balance_rows(p_teacher_id uuid default null)
returns table (
  teacher_id uuid,
  sales_count bigint,
  earned_kobo bigint,
  clawback_kobo bigint,
  paid_out_kobo bigint,
  pending_kobo bigint,
  balance_kobo bigint,
  available_kobo bigint,
  settled_direct_kobo bigint
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
           sum(t.settled_direct_kobo) as direct,
           sum(r.teacher_clawback_kobo) as clawback,
           sum(t.teacher_earning_kobo - t.settled_direct_kobo) filter (
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
    (coalesce(s.earned, 0) - coalesce(s.direct, 0) - coalesce(s.clawback, 0)
      - coalesce(pd.paid_out, 0))::bigint,
    (coalesce(s.earned, 0) - coalesce(s.direct, 0) - coalesce(s.clawback, 0)
      - coalesce(pd.paid_out, 0) - coalesce(s.pending, 0))::bigint,
    coalesce(s.direct, 0)::bigint
  from teachers tc
  left join sales s on s.teacher_id = tc.id
  left join paid pd on pd.teacher_id = tc.id
  where p_teacher_id is null or tc.id = p_teacher_id;
$$;

revoke execute on function public.teacher_balance_rows(uuid) from public, anon, authenticated;
grant execute on function public.teacher_balance_rows(uuid) to service_role;

-- What `initialize-payment` needs to split one sale. `debt_kobo` is what the
-- teacher owes back after a refund of money Paystack already settled to them.
create or replace function public.checkout_terms(p_teacher_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_balance bigint;
begin
  if p_teacher_id is null then
    return jsonb_build_object('house', false, 'subaccount_code', null, 'debt_kobo', 0);
  end if;

  select b.balance_kobo into v_balance
    from public.teacher_balance_rows(p_teacher_id) b;

  return jsonb_build_object(
    'house', exists (select 1 from public.house_accounts h where h.user_id = p_teacher_id),
    'subaccount_code', (
      select s.subaccount_code
        from public.paystack_subaccounts s
        join public.payout_accounts pa
          on pa.user_id = s.user_id and pa.verified_at is not null
       where s.user_id = p_teacher_id
    ),
    'debt_kobo', greatest(0, -coalesce(v_balance, 0))
  );
end;
$$;

revoke execute on function public.checkout_terms(uuid) from public, anon, authenticated;
grant execute on function public.checkout_terms(uuid) to service_role;

-- The teacher's own figures, now with what Paystack settled to them.
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
           'available_kobo', 0,
           'settled_direct_kobo', 0
         ))
         || jsonb_build_object(
           'payouts_held',
           exists (select 1 from public.suspensions s where s.user_id = v_uid)
         );
end;
$$;

revoke execute on function public.my_teacher_balance() from public, anon;
grant execute on function public.my_teacher_balance() to authenticated;

-- The admin list, as in 20261008000001, plus the Paystack side.
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
  requested_at timestamptz,
  settled_direct_kobo bigint,
  subaccount_code text,
  house boolean
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
    r.created_at,
    b.settled_direct_kobo,
    sa.subaccount_code,
    exists (select 1 from public.house_accounts h where h.user_id = b.teacher_id)
  from public.teacher_balance_rows() b
  left join public.profiles p on p.id = b.teacher_id
  left join auth.users u on u.id = b.teacher_id
  left join public.payout_accounts pa on pa.user_id = b.teacher_id
  left join public.paystack_subaccounts sa on sa.user_id = b.teacher_id
  left join public.payout_requests r
    on r.teacher_id = b.teacher_id and r.status = 'open'
  order by (r.id is not null) desc, r.created_at asc nulls last, b.available_kobo desc;
end;
$$;

revoke execute on function public.admin_teacher_balances() from public, anon;
grant execute on function public.admin_teacher_balances() to authenticated;
