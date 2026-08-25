-- Payment ledger.
--
-- Until now a successful payment produced only an `enrollments` row: the
-- Paystack reference, the amount actually charged, and the platform/teacher
-- split were all discarded. That leaves nothing to reconcile against Paystack,
-- nothing to pay teachers from, and nothing to answer a dispute with.
--
-- This table is the financial record. It is append-only from the client's point
-- of view — only the service_role (i.e. the `verify-payment` edge function)
-- writes to it.

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),

  -- Paystack's transaction reference. Unique so a replayed verification is
  -- idempotent rather than double-counting a sale.
  reference text not null unique,

  buyer_id uuid not null references auth.users(id) on delete cascade,

  -- Deliberately ON DELETE SET NULL, not CASCADE: deleting a course or closing
  -- a teacher account must not erase the money that changed hands. The
  -- denormalised title keeps the row readable afterwards.
  teacher_id uuid references auth.users(id) on delete set null,
  course_id uuid references public.courses(id) on delete set null,
  course_title text,

  -- Money is stored in kobo (integer minor units) so nothing is lost to
  -- floating point. `amount_kobo` is what Paystack says was actually charged,
  -- not what the course was listed at.
  amount_kobo bigint not null,
  currency text not null default 'NGN',

  -- Paystack's cut comes off the top before settlement, so `amount_kobo` alone
  -- overstates what was received. `net_kobo` is generated, so it cannot drift.
  paystack_fee_kobo bigint not null default 0,
  net_kobo bigint generated always as (amount_kobo - paystack_fee_kobo) stored,

  platform_fee_kobo bigint not null default 0,
  teacher_earning_kobo bigint not null default 0,

  status text not null default 'success',
  channel text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists transactions_teacher_id_idx
  on public.transactions (teacher_id, paid_at desc);
create index if not exists transactions_buyer_id_idx
  on public.transactions (buyer_id, paid_at desc);
create index if not exists transactions_course_id_idx
  on public.transactions (course_id);

alter table public.transactions enable row level security;

-- A buyer sees what they paid; a teacher sees what they sold.
drop policy if exists "Buyers can see their own transactions" on public.transactions;
create policy "Buyers can see their own transactions"
  on public.transactions for select to authenticated
  using (buyer_id = auth.uid());

drop policy if exists "Teachers can see sales of their courses" on public.transactions;
create policy "Teachers can see sales of their courses"
  on public.transactions for select to authenticated
  using (teacher_id = auth.uid());

-- No client writes, ever. Supabase grants ALL by default on new tables in the
-- public schema, so these have to be taken back explicitly. TRUNCATE is
-- included because it is *not* filtered by RLS — PostgREST never issues it, so
-- this is defence in depth on the one table that holds money.
revoke insert, update, delete, truncate, references
  on public.transactions from anon, authenticated;
