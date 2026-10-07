-- Account suspension (docs/ADMIN_PANEL.md, item 10).
--
-- Decided 2026-10-06 (ADMIN_PANEL.md, decision 6):
--   - A suspension lasts until an admin lifts it, on appeal.
--   - The user can still sign in. What stops is acting: creating or editing
--     courses and lessons, uploading, commenting, rating, reporting,
--     suggesting categories, editing their profile, enrolling or buying, and
--     changing bank details. Watching what they already own, saving progress,
--     reading notifications, deleting their own comments and ratings, and
--     deleting their account all still work.
--   - A suspended teacher's courses leave the catalogue. Students who already
--     enrolled keep them, so a suspension owes nobody a refund; if the content
--     itself is the problem, that is a takedown (item 2).
--   - Payouts to a suspended teacher are held. The balance is kept.
--   - Admins cannot be suspended.
--
-- This is not Supabase's auth ban. A ban blocks sign-in, which was not
-- wanted, and only bites when the access token expires. Every rule here is
-- checked on each request, so a suspension takes effect immediately.

-- ---------------------------------------------------------------------------
-- 1. Who is suspended
-- ---------------------------------------------------------------------------
-- One row per currently suspended user; lifting deletes it. The history of
-- both lives in admin_actions.

create table if not exists public.suspensions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 1000),
  suspended_at timestamptz not null default now(),
  suspended_by uuid references auth.users(id) on delete set null
);

alter table public.suspensions enable row level security;

-- A user can see their own suspension, so the app can say why and how to
-- appeal. Not who suspended them.
drop policy if exists "Users can see their own suspension" on public.suspensions;
create policy "Users can see their own suspension"
  on public.suspensions for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.suspensions from anon, authenticated;
grant select (user_id, reason, suspended_at) on public.suspensions to authenticated;

-- ---------------------------------------------------------------------------
-- 2. The check, out of the API's reach
-- ---------------------------------------------------------------------------
-- Policies run as the caller, so the check must be executable by every
-- signed-in user, and it must see every row of `suspensions`, so it is
-- security definer. In `public` that would make it an RPC anyone could call to
-- ask whether any user is suspended. `private` is not exposed by PostgREST,
-- so policies can call it and the API cannot.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.is_suspended(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.suspensions s where s.user_id = p_user_id);
$$;

revoke execute on function private.is_suspended(uuid) from public, anon;
grant execute on function private.is_suspended(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Writes a suspended user cannot make
-- ---------------------------------------------------------------------------
-- Restrictive policies, ANDed onto whatever the permissive policies allow, so
-- not one existing policy is touched. Triggers and admin RPCs run as the table
-- owner, which bypasses RLS, so cascades and recounts are unaffected: a
-- suspended user deleting their rating still lets the rating trigger recount
-- the course.
--
-- INSERT and UPDATE use WITH CHECK only, which fails loudly ("new row violates
-- row-level security policy") instead of silently matching no rows. DELETE
-- can only filter, so a suspended teacher's delete quietly does nothing; the
-- app should not offer it (item 13).
--
-- Deliberately absent, because they stay allowed: enrollments UPDATE
-- (progress), lesson_progress, notifications, course_comments DELETE,
-- course_ratings DELETE.

do $$
declare
  t record;
  v_check text := 'not private.is_suspended((select auth.uid()))';
begin
  for t in
    select *
      from (values
        ('public',  'profiles',        'insert'),
        ('public',  'profiles',        'update'),
        ('public',  'courses',         'insert'),
        ('public',  'courses',         'update'),
        ('public',  'courses',         'delete'),
        ('public',  'lessons',         'insert'),
        ('public',  'lessons',         'update'),
        ('public',  'lessons',         'delete'),
        ('public',  'course_comments', 'insert'),
        ('public',  'course_comments', 'update'),
        ('public',  'course_ratings',  'insert'),
        ('public',  'course_ratings',  'update'),
        ('public',  'enrollments',     'insert'),
        ('public',  'content_reports', 'insert'),
        ('public',  'categories',      'insert'),
        ('public',  'payout_accounts', 'delete'),
        ('storage', 'objects',         'insert'),
        ('storage', 'objects',         'update'),
        ('storage', 'objects',         'delete')
      ) as v(schema_name, table_name, command)
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      'Suspended users cannot ' || t.command, t.schema_name, t.table_name
    );
    execute format(
      'create policy %I on %I.%I as restrictive for %s to authenticated %s',
      'Suspended users cannot ' || t.command, t.schema_name, t.table_name, t.command,
      case t.command
        when 'delete' then format('using (%s)', v_check)
        else format('with check (%s)', v_check)
      end
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. A suspended teacher's courses leave the catalogue
-- ---------------------------------------------------------------------------
-- Same policy as 20261006000002 with the owner's suspension added to the
-- discovery branch. The owner still sees their courses; enrolled students
-- still resolve the ones they have. Lessons follow through "Lessons follow
-- course visibility". `get-course-video` refuses previews of these courses,
-- since the service role sees past RLS.

drop policy if exists "Courses are viewable by signed-in users" on public.courses;
create policy "Courses are viewable by signed-in users"
  on public.courses for select to authenticated
  using (
    (archived_at is null and removed_at is null and not private.is_suspended(user_id))
    or user_id = auth.uid()
    or exists (
      select 1 from public.enrollments e
      where e.course_id = courses.id
        and e.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Suspend and lift
-- ---------------------------------------------------------------------------

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

create or replace function public.admin_lift_suspension(p_user_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_suspension record;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;

  delete from public.suspensions s
   where s.user_id = p_user_id
  returning s.reason, s.suspended_at, s.suspended_by
    into v_suspension;
  if not found then
    raise exception 'This user is not suspended' using errcode = '22023';
  end if;

  -- The suspension being lifted, kept here because its row is now gone.
  perform public.log_admin_action(
    'user.unsuspend', 'user', p_user_id, v_reason,
    jsonb_build_object(
      'suspended_reason', v_suspension.reason,
      'suspended_at', v_suspension.suspended_at,
      'suspended_by', v_suspension.suspended_by
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Payouts are held while a teacher is suspended
-- ---------------------------------------------------------------------------
-- Same function as 20261006000005, plus the hold.

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
-- 7. The admin screens learn about suspensions
-- ---------------------------------------------------------------------------
-- Two functions gain a `suspended` column, which changes their return type,
-- so they are dropped and recreated rather than replaced. Their bodies are
-- otherwise those of 20261006000005 and 20261006000008.

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
  suspended boolean
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
    exists (select 1 from public.suspensions s where s.user_id = b.teacher_id)
  from public.teacher_balance_rows() b
  left join public.profiles p on p.id = b.teacher_id
  left join auth.users u on u.id = b.teacher_id
  left join public.payout_accounts pa on pa.user_id = b.teacher_id
  order by b.available_kobo desc;
end;
$$;

drop function if exists public.admin_search_users(text, integer, integer);
create function public.admin_search_users(
  p_query text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  name text,
  email text,
  role text,
  is_admin boolean,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed boolean,
  banned_until timestamptz,
  suspended boolean,
  course_count bigint,
  enrollment_count bigint,
  purchase_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_q text := nullif(btrim(p_query), '');
  v_pattern text;
  v_id uuid;
begin
  perform public.assert_admin();

  if v_q is not null then
    v_pattern := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
    begin
      v_id := v_q::uuid;
    exception when invalid_text_representation then
      v_id := null;
    end;
  end if;

  return query
  select
    u.id,
    p.name,
    u.email::text,
    p.role,
    exists (select 1 from public.admins a where a.user_id = u.id),
    u.created_at,
    u.last_sign_in_at,
    u.email_confirmed_at is not null,
    u.banned_until,
    exists (select 1 from public.suspensions s where s.user_id = u.id),
    (select count(*) from public.courses c where c.user_id = u.id),
    (select count(*) from public.enrollments e where e.user_id = u.id),
    (select count(*) from public.transactions t where t.buyer_id = u.id and t.status = 'success')
  from auth.users u
  left join public.profiles p on p.id = u.id
  where v_q is null
     or u.id = v_id
     or u.email ilike v_pattern
     or p.name ilike v_pattern
  order by u.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- Same as 20261006000008, plus `suspension`.
create or replace function public.admin_user_detail(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_detail jsonb;
begin
  perform public.assert_admin();

  select jsonb_build_object(
    'id', u.id,
    'email', u.email,
    'name', p.name,
    'role', p.role,
    'profile_image_url', p.profile_image_url,
    'is_admin', exists (select 1 from public.admins a where a.user_id = u.id),
    'created_at', u.created_at,
    'last_sign_in_at', u.last_sign_in_at,
    'email_confirmed_at', u.email_confirmed_at,
    'banned_until', u.banned_until,
    'suspension', (
      select jsonb_build_object(
               'reason', s.reason,
               'suspended_at', s.suspended_at,
               'suspended_by', s.suspended_by
             )
        from public.suspensions s
       where s.user_id = u.id
    ),
    'providers', coalesce(u.raw_app_meta_data -> 'providers', '[]'::jsonb),
    'verified_mfa_factors', (
      select count(*) from auth.mfa_factors f
       where f.user_id = u.id and f.status = 'verified'
    ),

    'courses', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id,
               'title', c.title,
               'price', c.price,
               'enrollments', c.enrollments,
               'created_at', c.created_at,
               'archived_at', c.archived_at,
               'removed_at', c.removed_at,
               'removed_reason', c.removed_reason
             ) order by c.created_at desc)
        from public.courses c
       where c.user_id = u.id
    ), '[]'::jsonb),
    'balance', (
      select to_jsonb(b) - 'teacher_id'
        from public.teacher_balance_rows(u.id) b
    ),
    'payout_account', (
      select jsonb_build_object(
               'bank_name', pa.bank_name,
               'account_name', pa.account_name,
               'account_last4', right(pa.account_number, 4),
               'verified', pa.verified_at is not null
             )
        from public.payout_accounts pa
       where pa.user_id = u.id
    ),

    'enrollments', coalesce((
      select jsonb_agg(jsonb_build_object(
               'course_id', e.course_id,
               'title', e.title,
               'is_free', e.is_free,
               'progress', e.progress,
               'enrolled_at', e.enrolled_at
             ) order by e.enrolled_at desc)
        from public.enrollments e
       where e.user_id = u.id
    ), '[]'::jsonb),
    'purchases', coalesce((
      select jsonb_agg(jsonb_build_object(
               'transaction_id', t.id,
               'reference', t.reference,
               'course_id', t.course_id,
               'course_title', t.course_title,
               'amount_kobo', t.amount_kobo,
               'status', t.status,
               'paid_at', t.paid_at,
               'refunded', r.id is not null
             ) order by t.paid_at desc nulls last)
        from public.transactions t
        left join public.refunds r on r.transaction_id = t.id
       where t.buyer_id = u.id
    ), '[]'::jsonb),

    'reports_filed', (
      select count(*) from public.content_reports cr where cr.reporter_id = u.id
    ),
    'reports_against', (
      select jsonb_build_object(
               'open', count(*) filter (where cr.status = 'open'),
               'total', count(*)
             )
        from public.content_reports cr
       where cr.target_owner_id = u.id
    ),
    'admin_actions', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
        from (
          select aa.action, aa.reason, aa.details, aa.admin_id, aa.created_at
            from public.admin_actions aa
           where aa.target_type = 'user'
             and aa.target_id = u.id
           order by aa.created_at desc
           limit 20
        ) x
    ), '[]'::jsonb)
  )
  into v_detail
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = p_user_id;

  if v_detail is null then
    raise exception 'User not found' using errcode = 'P0002';
  end if;

  return v_detail;
end;
$$;

-- Same as 20261006000009, with suspensions counted from the table and
-- suspended teachers left out of "payable", since their payouts are held.
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

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Callable by any signed-in user; assert_admin() inside is the gate. The two
-- recreated functions lost their grants when dropped.

revoke execute on function public.admin_suspend_user(uuid, text) from public, anon;
revoke execute on function public.admin_lift_suspension(uuid, text) from public, anon;
revoke execute on function public.admin_teacher_balances() from public, anon;
revoke execute on function public.admin_search_users(text, integer, integer) from public, anon;
grant execute on function public.admin_suspend_user(uuid, text) to authenticated;
grant execute on function public.admin_lift_suspension(uuid, text) to authenticated;
grant execute on function public.admin_teacher_balances() to authenticated;
grant execute on function public.admin_search_users(text, integer, integer) to authenticated;
