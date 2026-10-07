-- Refund records (docs/ADMIN_PANEL.md, item 4).
--
-- A takedown (item 2) stops playback for students who paid, and they are owed
-- their money back. Refunds are issued by hand in the Paystack dashboard; this
-- records them, so the money can be reconciled and teacher balances (item 5)
-- can leave refunded sales out.
--
-- Who bears a refund was decided 2026-10-06 (ADMIN_PANEL.md, decision 4): the
-- student gets back everything they paid; the teacher loses their share of the
-- sale, because the breach was theirs; PadiLearn gives up its commission and
-- absorbs Paystack's fee, which Paystack keeps on a refund. The split is
-- computed here from the ledger, never typed by an admin, so every refund
-- splits the same way.
--
-- Scope: refunds of taken-down courses only. Refunding for any other reason
-- needs a refund policy (terms.md still has a placeholder) and its own answer
-- to who pays, so it stays in version 2.
--
-- `transactions` is not touched. The ledger stays append-only; a refund is its
-- own row, and anything summing earnings subtracts refunds.

-- ---------------------------------------------------------------------------
-- 1. The table
-- ---------------------------------------------------------------------------

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),

  -- One refund per sale; partial refunds are not a thing yet. RESTRICT so a
  -- refunded sale can never be deleted out from under its refund.
  transaction_id uuid not null unique
    references public.transactions(id) on delete restrict,

  -- What went back to the student: the whole charge.
  amount_kobo bigint not null check (amount_kobo > 0),
  -- What comes off the teacher's balance: their whole share of the sale.
  teacher_clawback_kobo bigint not null check (teacher_clawback_kobo >= 0),
  -- What PadiLearn bears: its commission plus Paystack's fee. Generated, so
  -- the three cannot disagree.
  platform_cost_kobo bigint generated always as (amount_kobo - teacher_clawback_kobo) stored,

  -- Paystack's id for the refund, to match against their records.
  paystack_reference text not null
    check (char_length(paystack_reference) between 1 and 200),
  reason text not null check (char_length(reason) between 1 and 1000),

  -- Whether recording it removed the buyer's enrolment. False when there was
  -- none left to remove (e.g. the buyer deleted their account).
  enrollment_revoked boolean not null default false,

  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),

  constraint refunds_clawback_within_amount
    check (teacher_clawback_kobo <= amount_kobo)
);

alter table public.refunds enable row level security;

-- No policies and no grants: written only by admin_record_refund(), read only
-- through the admin RPCs below. Teachers and buyers may see their refunds
-- later, from the app, through policies added then.
revoke all on public.refunds from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Who is owed
-- ---------------------------------------------------------------------------
-- Every successful sale of a taken-down course that has no refund recorded,
-- with the split it will have and the buyer's email to reach them by. The
-- email comes from auth.users, which follows email changes; profiles.email
-- does not.

create or replace function public.admin_refunds_owed()
returns table (
  transaction_id uuid,
  reference text,
  paid_at timestamptz,
  buyer_id uuid,
  buyer_name text,
  buyer_email text,
  course_id uuid,
  course_title text,
  removed_at timestamptz,
  removed_reason text,
  teacher_id uuid,
  teacher_name text,
  amount_kobo bigint,
  teacher_clawback_kobo bigint,
  platform_cost_kobo bigint
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
    t.id,
    t.reference,
    t.paid_at,
    t.buyer_id,
    buyer_p.name,
    coalesce(buyer_u.email::text, buyer_p.email),
    t.course_id,
    coalesce(c.title, t.course_title),
    c.removed_at,
    c.removed_reason,
    t.teacher_id,
    teacher_p.name,
    t.amount_kobo,
    t.teacher_earning_kobo,
    t.amount_kobo - t.teacher_earning_kobo
  from public.transactions t
  join public.courses c on c.id = t.course_id
  left join public.profiles buyer_p on buyer_p.id = t.buyer_id
  left join auth.users buyer_u on buyer_u.id = t.buyer_id
  left join public.profiles teacher_p on teacher_p.id = t.teacher_id
  where t.status = 'success'
    and c.removed_at is not null
    and not exists (select 1 from public.refunds r where r.transaction_id = t.id)
  order by c.removed_at, t.paid_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Record a refund
-- ---------------------------------------------------------------------------
-- Called after the refund has been issued in Paystack, with Paystack's
-- reference for it. Locks the sale, so two admins cannot record it twice.
--
-- Also removes the buyer's enrolment. A refunded sale grants nothing, and
-- without this a course restored on appeal would hand the student both their
-- money and the course.

create or replace function public.admin_record_refund(
  p_transaction_id uuid,
  p_paystack_reference text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ref text := nullif(btrim(p_paystack_reference), '');
  v_reason text := nullif(btrim(p_reason), '');
  v_tx record;
  v_removed_at timestamptz;
  v_revoked integer := 0;
  v_refund record;
begin
  perform public.assert_admin();

  if v_ref is null then
    raise exception 'The Paystack refund reference is required' using errcode = '22023';
  end if;
  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;

  select t.id, t.reference, t.status, t.buyer_id, t.course_id, t.course_title,
         t.teacher_id, t.amount_kobo, t.teacher_earning_kobo
    into v_tx
    from public.transactions t
   where t.id = p_transaction_id
     for update;
  if not found then
    raise exception 'Payment not found' using errcode = 'P0002';
  end if;
  if v_tx.status <> 'success' then
    raise exception 'Only successful payments can be refunded' using errcode = '22023';
  end if;
  if exists (select 1 from public.refunds r where r.transaction_id = v_tx.id) then
    raise exception 'This payment is already refunded' using errcode = '22023';
  end if;

  select c.removed_at into v_removed_at
    from public.courses c
   where c.id = v_tx.course_id;
  if v_removed_at is null then
    raise exception 'Only payments for taken-down courses can be refunded here for now'
      using errcode = '22023';
  end if;

  if v_tx.buyer_id is not null then
    delete from public.enrollments e
     where e.user_id = v_tx.buyer_id
       and e.course_id = v_tx.course_id;
    get diagnostics v_revoked = row_count;
  end if;

  insert into public.refunds (
    transaction_id, amount_kobo, teacher_clawback_kobo,
    paystack_reference, reason, enrollment_revoked, recorded_by
  )
  values (
    v_tx.id, v_tx.amount_kobo, v_tx.teacher_earning_kobo,
    v_ref, v_reason, v_revoked > 0, auth.uid()
  )
  returning id, amount_kobo, teacher_clawback_kobo, platform_cost_kobo, enrollment_revoked
    into v_refund;

  perform public.log_admin_action(
    'refund.record', 'transaction', v_tx.id, v_reason,
    jsonb_build_object(
      'refund_id', v_refund.id,
      'reference', v_tx.reference,
      'paystack_refund_reference', v_ref,
      'course_id', v_tx.course_id,
      'course_title', v_tx.course_title,
      'buyer_id', v_tx.buyer_id,
      'teacher_id', v_tx.teacher_id,
      'amount_kobo', v_refund.amount_kobo,
      'teacher_clawback_kobo', v_refund.teacher_clawback_kobo,
      'platform_cost_kobo', v_refund.platform_cost_kobo,
      'enrollment_revoked', v_refund.enrollment_revoked
    )
  );

  return jsonb_build_object(
    'refund_id', v_refund.id,
    'amount_kobo', v_refund.amount_kobo,
    'teacher_clawback_kobo', v_refund.teacher_clawback_kobo,
    'platform_cost_kobo', v_refund.platform_cost_kobo,
    'enrollment_revoked', v_refund.enrollment_revoked
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Refunds recorded so far
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_refunds(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  created_at timestamptz,
  transaction_id uuid,
  reference text,
  paystack_reference text,
  course_id uuid,
  course_title text,
  buyer_id uuid,
  buyer_name text,
  teacher_id uuid,
  teacher_name text,
  amount_kobo bigint,
  teacher_clawback_kobo bigint,
  platform_cost_kobo bigint,
  enrollment_revoked boolean,
  reason text,
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
    r.id,
    r.created_at,
    r.transaction_id,
    t.reference,
    r.paystack_reference,
    t.course_id,
    coalesce(c.title, t.course_title),
    t.buyer_id,
    buyer_p.name,
    t.teacher_id,
    teacher_p.name,
    r.amount_kobo,
    r.teacher_clawback_kobo,
    r.platform_cost_kobo,
    r.enrollment_revoked,
    r.reason,
    r.recorded_by,
    recorder_p.name
  from public.refunds r
  join public.transactions t on t.id = r.transaction_id
  left join public.courses c on c.id = t.course_id
  left join public.profiles buyer_p on buyer_p.id = t.buyer_id
  left join public.profiles teacher_p on teacher_p.id = t.teacher_id
  left join public.profiles recorder_p on recorder_p.id = r.recorded_by
  order by r.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Callable by any signed-in user; assert_admin() inside is the gate.

revoke execute on function public.admin_refunds_owed() from public, anon;
revoke execute on function public.admin_record_refund(uuid, text, text) from public, anon;
revoke execute on function public.admin_list_refunds(integer, integer) from public, anon;
grant execute on function public.admin_refunds_owed() to authenticated;
grant execute on function public.admin_record_refund(uuid, text, text) to authenticated;
grant execute on function public.admin_list_refunds(integer, integer) to authenticated;
