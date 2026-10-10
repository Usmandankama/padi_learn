-- Course drafts.
--
-- Until now a course was in the marketplace the moment its row existed. The
-- create screen gains "Save to drafts" beside "Upload": a draft is a course
-- only its owner (and an admin) can see, finished over as many sittings as it
-- takes and then uploaded.
--
-- Decided 2026-10-10:
--   - Uploading is instant on the teacher's tap. No admin review yet.
--   - An uploaded course cannot go back to being a draft. Archiving already
--     hides a live course, and keeps its students.
--   - A teacher holds at most 3 drafts. A draft keeps its video and cover in
--     storage, and nothing deletes an abandoned one yet.
--
-- A new column rather than `archived_at` or `removed_at`: those two mean a
-- course that was live and is now hidden, with students who keep it. A draft
-- has never been live and has no students.
--
-- Run this before the app that offers drafts ships. Until it has run, that
-- app's "Save to drafts" fails on a column that does not exist.

-- ---------------------------------------------------------------------------
-- 1. The column
-- ---------------------------------------------------------------------------
-- Null means draft. The default is now(), not null, for the APKs already
-- installed (1.0.6 and earlier): they insert a course without this column and
-- expect it to be live, so leaving the column out has to keep meaning "live".
-- The new app sends null explicitly when it saves a draft.
--
-- Inside a guard so that running this file a second time cannot publish every
-- draft: the backfill happens only alongside the statement that adds the
-- column.

do $$
begin
  if not exists (
    select 1
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'courses'
       and column_name = 'published_at'
  ) then
    alter table public.courses
      add column published_at timestamptz default now();

    -- Every course that exists today is live, and has been since it was
    -- created.
    update public.courses
       set published_at = coalesce(created_at, now());
  end if;
end $$;

comment on column public.courses.published_at is
  'When the course went live. Null is a draft: visible to its owner and to admins only. Set by publish_course(), or by the default on insert.';

-- The draft limit counts these on every save.
create index if not exists courses_drafts_by_owner_idx
  on public.courses (user_id)
  where published_at is null;

-- ---------------------------------------------------------------------------
-- 2. Who may write it
-- ---------------------------------------------------------------------------
-- INSERT on `courses` is column by column (20261006000002), so the app cannot
-- send null without this. UPDATE is column by column too and deliberately
-- does not gain the column: a teacher cannot clear it, set it or backdate it.
-- Going live is publish_course() below, and nothing takes a course back.

grant insert (published_at) on public.courses to authenticated;

-- ---------------------------------------------------------------------------
-- 3. What a course needs before it is live
-- ---------------------------------------------------------------------------
-- One list, in the words the teacher is shown. It is what the create screen
-- has always insisted on before its one button would work, so a course
-- finished as a draft is held to the same standard as one uploaded in a
-- single sitting. lib/services/course_service.dart keeps the same list for
-- the checklist on the draft's own screen.

create or replace function private.course_draft_limit()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 3;
$$;

create or replace function private.course_publish_gaps(
  p_course public.courses,
  p_with_lessons boolean
)
returns text[]
language sql
stable
set search_path = ''
as $$
  select array_remove(array[
    case when coalesce(btrim(p_course.description), '') = '' then 'a description' end,
    case when coalesce(btrim(p_course.author), '') = '' then 'an author name' end,
    case when p_course.category is null then 'a category' end,
    case when p_course.price is null then 'a price' end,
    case when coalesce(btrim(p_course.thumbnail_url), '') = '' then 'a cover image' end,
    case when p_with_lessons and not exists (
      select 1
        from public.lessons l
       where l.course_id = p_course.id
         and coalesce(btrim(l.video_url), '') <> ''
    ) then 'a lesson with a video' end
  ], null);
$$;

-- 'a description, a category and a cover image'
create or replace function private.readable_list(p_items text[])
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(cardinality(p_items), 0) = 0 then ''
    when cardinality(p_items) = 1 then p_items[1]
    else array_to_string(p_items[1:cardinality(p_items) - 1], ', ')
         || ' and ' || p_items[cardinality(p_items)]
  end;
$$;

revoke execute on function private.course_draft_limit() from public, anon, authenticated;
revoke execute on function private.course_publish_gaps(public.courses, boolean) from public, anon, authenticated;
revoke execute on function private.readable_list(text[]) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Creating a course: as a draft, or live
-- ---------------------------------------------------------------------------
-- Scoped to a signed-in user coming through the API, like the delete rule in
-- 20261007000002: the SQL editor, the service role and the demo seed are
-- left alone.
--
-- A draft: refused when the teacher already holds the limit. The message is
-- shown by the app as it is.
--
-- A live course (the column left out, which is every installed APK, or sent
-- with a value): stamped now() whatever was sent, and held to the list above
-- except for the lesson. The lesson cannot be asked for here: those apps
-- insert the course first and its first lesson a moment later, and so does
-- the new app's "Upload". Every one of them has always required the rest of
-- the list before it would insert, so this refuses nothing they send.

create or replace function private.course_insert_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_gaps text[];
begin
  if coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb
                ->> 'role', '') <> 'authenticated' then
    return new;
  end if;
  -- Someone else's course: row-level security refuses it next. Counting that
  -- person's drafts first would tell the caller how many they have.
  if new.user_id is distinct from auth.uid() then
    return new;
  end if;

  if new.published_at is null then
    -- One teacher's saves queue here, so two at once cannot both count two.
    perform pg_advisory_xact_lock(
      hashtextextended('course_drafts:' || new.user_id::text, 0)
    );
    if (select count(*)
          from public.courses c
         where c.user_id = new.user_id
           and c.published_at is null) >= private.course_draft_limit() then
      raise exception 'You already have % drafts. Upload or delete one before saving another.',
        private.course_draft_limit()
        using errcode = '22023';
    end if;
  else
    new.published_at := now();
    v_gaps := private.course_publish_gaps(new, false);
    if cardinality(v_gaps) > 0 then
      raise exception 'This course cannot be uploaded yet. It still needs %.',
        private.readable_list(v_gaps)
        using errcode = '22023';
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function private.course_insert_rules() from public, anon, authenticated;

drop trigger if exists before_course_insert_rules on public.courses;
create trigger before_course_insert_rules
  before insert on public.courses
  for each row execute function private.course_insert_rules();

-- A draft may carry a price before its teacher has a bank account: someone
-- halfway through a course should not lose their work to a payouts form. The
-- rule is checked when the draft is uploaded instead (publish_course below).
-- Otherwise the function of 20261009000001.
create or replace function private.require_payouts_for_paid_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.published_at is not null
     and coalesce(new.price, 0) > 0
     and (tg_op = 'INSERT' or coalesce(old.price, 0) <= 0)
     and not public.can_sell_paid(new.user_id) then
    raise exception 'Add your bank account under Profile, Payouts before charging for a course'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Uploading a draft
-- ---------------------------------------------------------------------------
-- The only way a draft goes live. Refuses, saying what is missing, unless the
-- course has everything in the list above including a lesson with a video,
-- and, when it has a price, its teacher may sell (20261009000001).
--
-- Security definer because the teacher holds no UPDATE on the column, so the
-- owner and suspension checks that row-level security would have made are
-- made here.

create or replace function public.publish_course(p_course_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_course public.courses;
  v_gaps text[];
  v_now timestamptz := now();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  select c.*
    into v_course
    from public.courses c
   where c.id = p_course_id
     and c.user_id = v_uid
     for update;
  if not found then
    raise exception 'Course not found' using errcode = 'P0002';
  end if;

  if private.is_suspended(v_uid) then
    raise exception 'Your account is suspended. Email hello@padilearn.com to appeal.'
      using errcode = '42501';
  end if;

  -- Already live: a second tap changes nothing, and the date does not move.
  if v_course.published_at is not null then
    return v_course.published_at;
  end if;

  v_gaps := private.course_publish_gaps(v_course, true);
  if cardinality(v_gaps) > 0 then
    raise exception 'This course cannot be uploaded yet. It still needs %.',
      private.readable_list(v_gaps)
      using errcode = '22023';
  end if;

  if coalesce(v_course.price, 0) > 0 and not public.can_sell_paid(v_uid) then
    raise exception 'Add your bank account under Profile, Payouts before charging for a course'
      using errcode = '22023';
  end if;

  update public.courses
     set published_at = v_now
   where id = p_course_id;

  return v_now;
end;
$$;

revoke execute on function public.publish_course(uuid) from public, anon;
grant execute on function public.publish_course(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Who can see a draft
-- ---------------------------------------------------------------------------
-- Same policy as 20261006000010 with "has been uploaded" added to the
-- discovery branch. The owner sees their drafts through the second branch.
-- Admins see them through "Admins can see every course" (20261006000002),
-- which is untouched. Lessons follow through "Lessons follow course
-- visibility", so a draft's curriculum is hidden with it. The marketplace
-- lists whatever this policy allows, by query and by realtime, so a draft
-- reaches no other account either way.

drop policy if exists "Courses are viewable by signed-in users" on public.courses;
create policy "Courses are viewable by signed-in users"
  on public.courses for select to authenticated
  using (
    (published_at is not null
      and archived_at is null
      and removed_at is null
      and not private.is_suspended(user_id))
    or user_id = (select auth.uid())
    or exists (
      select 1 from public.enrollments e
      where e.course_id = courses.id
        and e.user_id = (select auth.uid())
    )
  );

-- Nobody enrols in a draft, its owner included: the subquery already hid
-- other people's, and this closes the owner's own. It keeps "a draft has no
-- students" true, which is what lets a draft always be deleted.
alter policy "Users can self-enroll in free courses" on public.enrollments
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.courses c
      where c.id = enrollments.course_id
        and coalesce(c.price, 0) = 0
        and c.published_at is not null
    )
  );

-- ---------------------------------------------------------------------------
-- 7. The admin screens learn about drafts
-- ---------------------------------------------------------------------------
-- A course is one of: taken down, draft, archived, live, in that order of
-- precedence, so the four always add up to the total.
--
--   admin_suspend_user   `courses_hidden` no longer counts drafts, which were
--                        never in the catalogue to leave it.
--   admin_search_users   `course_count` counts uploaded courses only.
--   admin_user_detail    each course carries `published_at`, so the screen
--                        can label a draft.
--   admin_overview       `catalogue` gains `drafts`; live, archived, paid,
--                        lessons and teachers_with_live_courses leave drafts
--                        out.
--
-- Left alone on purpose: admin_set_role still counts drafts when it refuses
-- to turn a teacher with courses into a student, and the category functions
-- still count them, because a draft holds its category like any course.
--
-- Each body below is the live one (named in its comment) with only those
-- lines changed. CREATE OR REPLACE keeps the grants.

-- Was 20261009000004.
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
  if exists (select 1 from public.house_accounts h where h.user_id = p_user_id) then
    raise exception 'This is a PadiLearn house account. Take down a course instead of suspending the account'
      using errcode = '22023';
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
     and c.published_at is not null
     and c.archived_at is null
     and c.removed_at is null;

  perform public.log_admin_action(
    'user.suspend', 'user', p_user_id, v_reason,
    jsonb_build_object('role', v_role, 'courses_hidden', v_hidden)
  );

  return jsonb_build_object('courses_hidden', v_hidden);
end;
$$;

-- Was 20261006000010.
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
    (select count(*) from public.courses c where c.user_id = u.id and c.published_at is not null),
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

-- Was 20261006000010.
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
               'published_at', c.published_at,
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

-- Was 20261008000001.
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
      'live', (select count(*) from public.courses c where c.published_at is not null and c.archived_at is null and c.removed_at is null),
      'archived', (select count(*) from public.courses c where c.published_at is not null and c.archived_at is not null and c.removed_at is null),
      'taken_down', (select count(*) from public.courses c where c.removed_at is not null),
      'drafts', (select count(*) from public.courses c where c.published_at is null and c.removed_at is null),
      'paid', (select count(*) from public.courses c where c.published_at is not null and coalesce(c.price, 0) > 0),
      'lessons', (
        select count(*) from public.lessons l
          join public.courses c on c.id = l.course_id
         where c.published_at is not null
      ),
      'teachers_with_live_courses', (
        select count(distinct c.user_id) from public.courses c
         where c.published_at is not null and c.archived_at is null and c.removed_at is null
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
