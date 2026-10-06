-- User lookup (docs/ADMIN_PANEL.md, item 8).
--
-- Support starts with "who is this person, and what have they got?". The
-- answer is spread across auth.users (email, sign-ins, ban), profiles (name,
-- role), and every table that hangs off a user. Clients can read none of it
-- for anyone but themselves, by design. These two functions put it together
-- for an admin. Read-only: nothing here changes data, so nothing is logged.

-- ---------------------------------------------------------------------------
-- 1. Search
-- ---------------------------------------------------------------------------
-- Matches part of an email or name, case-insensitively, or an exact user id.
-- An empty query lists the newest accounts. LIKE wildcards in the query are
-- escaped, so "%" or "_" mean themselves.

create or replace function public.admin_search_users(
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

-- ---------------------------------------------------------------------------
-- 2. Everything about one user
-- ---------------------------------------------------------------------------
-- One JSON document for the detail page, so it is one round trip:
--   account   email, sign-up and last sign-in, confirmation, ban, providers,
--             second factors, admin
--   teaching  courses (with takedown state), balance, payout account
--   learning  enrolments, purchases (with refund state)
--   conduct   reports filed by them and against them, admin actions on them
--
-- The payout account shows the last four digits only. The full number is in
-- admin_teacher_balances(), where it is needed to make a transfer.

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

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Callable by any signed-in user; assert_admin() inside is the gate.

revoke execute on function public.admin_search_users(text, integer, integer) from public, anon;
revoke execute on function public.admin_user_detail(uuid) from public, anon;
grant execute on function public.admin_search_users(text, integer, integer) to authenticated;
grant execute on function public.admin_user_detail(uuid) to authenticated;
