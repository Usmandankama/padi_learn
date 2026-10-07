-- Overview (docs/ADMIN_PANEL.md, item 9).
--
-- The admin app's first screen: is anything waiting for me, and how is the
-- business doing. One JSON document, one round trip, read-only.
--
-- Money is in kobo, like everywhere else. The money figures reuse the same
-- sources as the screens they summarise: teacher figures come from
-- teacher_balance_rows() and refunds owed use the same rule as
-- admin_refunds_owed(), so the overview can never disagree with the detail.

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
          and not exists (
            select 1 from public.payout_accounts pa
             where pa.user_id = b.teacher_id and pa.verified_at is not null
          )
      ) as payable_without_account
    from public.teacher_balance_rows() b
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
      'teachers_payable', (
        select count(*) from public.teacher_balance_rows() b where b.available_kobo > 0
      ),
      'teachers_payable_without_bank_account', (select payable_without_account from balances)
    ),

    'accounts', jsonb_build_object(
      'total', (select count(*) from auth.users),
      'teachers', (select count(*) from public.profiles p where p.role = 'Teacher'),
      'students', (select count(*) from public.profiles p where p.role = 'Student'),
      'role_not_chosen', (select count(*) from public.profiles p where p.role is null),
      'new_7d', (select count(*) from auth.users u where u.created_at > v_week),
      'new_30d', (select count(*) from auth.users u where u.created_at > v_month),
      'suspended', (select count(*) from auth.users u where u.banned_until > now()),
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

-- Callable by any signed-in user; assert_admin() inside is the gate.
revoke execute on function public.admin_overview() from public, anon;
grant execute on function public.admin_overview() to authenticated;
