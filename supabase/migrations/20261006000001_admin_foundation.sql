-- Admin foundation: who is an admin, and a record of what admins do.
--
-- PadiLearn had no notion of an admin. Every back-office action ran through
-- Supabase Studio as the database owner, which works for one operator and
-- leaves no trace of who did what. Every admin feature rests on the pieces
-- here, so they land first. The plan is docs/ADMIN_PANEL.md.
--
-- Nothing in this file changes an existing table or policy: the app behaves
-- exactly as before until an admin RPC is added on top.

-- ---------------------------------------------------------------------------
-- 1. Who is an admin
-- ---------------------------------------------------------------------------
-- A table, not a value in `profiles.role`:
--   - profiles are readable by every signed-in user, so a flag there would
--     publish the list of accounts worth phishing;
--   - `role` is the product role, and an admin may be a teacher or a student;
--   - the app branches on `role`, and an unknown value would fall through to
--     the student shell.
-- And not a JWT claim in `app_metadata`: a claim lives until the token
-- expires, so revoking an admin would take up to an hour. A deleted row is
-- gone on the next request.

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);

alter table public.admins enable row level security;

-- No policies and no grants. Membership is managed from SQL (see the doc), and
-- is_admin() is the only way a client learns anything from this table, and
-- then only about itself.
revoke all on public.admins from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. The one check
-- ---------------------------------------------------------------------------
-- Membership is not enough on its own: the session must also have passed a
-- second factor (aal2). An admin can take courses down and suspend accounts,
-- so a leaked password must not be sufficient. The admin app enrols and
-- challenges a TOTP factor before it calls anything.
--
-- Security definer so it can read `admins`, which the caller cannot. It only
-- ever answers for auth.uid(), so exposing it reveals nothing about anyone
-- else; the admin app calls it to decide whether to render at all.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
     and exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- The first line of every admin RPC: `perform public.assert_admin();`.
-- 42501 is insufficient_privilege, which PostgREST maps to 403.
--
-- Not callable by clients. Admin RPCs are security definer, so they run as the
-- owner and can call it; nobody else needs to.

create or replace function public.assert_admin()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.assert_admin() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. What admins did
-- ---------------------------------------------------------------------------
-- Every admin RPC writes one row here in the same transaction as its change,
-- so the log can neither miss an action that committed nor record one that
-- rolled back. Append-only: clients cannot write it, and nothing updates or
-- deletes it.

create table if not exists public.admin_actions (
  id bigint generated always as identity primary key,

  -- SET NULL so the record outlives the admin's account, like the ledger.
  admin_id uuid references auth.users(id) on delete set null,

  -- Dotted verb, e.g. 'course.remove', 'report.dismiss', 'payout.record'.
  action text not null,
  -- 'course', 'comment', 'report', 'user', 'category', 'payout'.
  target_type text not null,
  -- Every target in this schema has a uuid key. Not a foreign key: the log
  -- must survive the target being deleted, which is often the action itself.
  target_id uuid,

  reason text check (char_length(reason) <= 1000),
  -- Whatever the action needs to be understood later: the old value, the
  -- amount, the report it resolved.
  details jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

create index if not exists admin_actions_created_at_idx
  on public.admin_actions (created_at desc);
create index if not exists admin_actions_target_idx
  on public.admin_actions (target_type, target_id);

alter table public.admin_actions enable row level security;

drop policy if exists "Admins can read the audit log" on public.admin_actions;
create policy "Admins can read the audit log"
  on public.admin_actions for select to authenticated
  using ((select public.is_admin()));

-- Supabase grants ALL on new public tables by default. Take back everything
-- but SELECT from authenticated (still gated by the policy above), and
-- everything from anon. TRUNCATE is not filtered by RLS, hence explicit.
revoke all on public.admin_actions from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.admin_actions from authenticated;

-- Writes the row. admin_id comes from the session, never from an argument, so
-- an RPC cannot attribute its action to someone else.
--
-- Not callable by clients, for the same reason as assert_admin().

create or replace function public.log_admin_action(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_reason text default null,
  p_details jsonb default '{}'::jsonb
)
returns void
language sql
set search_path = ''
as $$
  insert into public.admin_actions (admin_id, action, target_type, target_id, reason, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_reason, coalesce(p_details, '{}'::jsonb));
$$;

revoke execute on function public.log_admin_action(text, text, uuid, text, jsonb)
  from public, anon, authenticated;
