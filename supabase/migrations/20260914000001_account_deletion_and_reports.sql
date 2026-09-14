-- Launch blockers for Google Play: account deletion, honest counters, and
-- in-app reporting of user-generated content.
--
-- Three independent changes in one file because they ship together and the
-- `delete-account` edge function depends on the first two.

-- ---------------------------------------------------------------------------
-- 1. The ledger outlives the buyer
-- ---------------------------------------------------------------------------
-- `transactions.buyer_id` was ON DELETE CASCADE, so deleting an account would
-- have erased the record that money changed hands. That record is needed for
-- refunds, disputes, teacher payouts and tax, and a teacher's earnings would
-- silently shrink every time one of their students left. SET NULL keeps the
-- row and drops the link to a person, matching `teacher_id` and `course_id`.
-- The privacy policy has to say financial records are retained.

alter table public.transactions alter column buyer_id drop not null;

do $$
declare
  fk text;
begin
  select c.conname into fk
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
   where c.conrelid = 'public.transactions'::regclass
     and c.contype = 'f'
     and a.attname = 'buyer_id';
  if fk is not null then
    execute format('alter table public.transactions drop constraint %I', fk);
  end if;
end $$;

alter table public.transactions
  add constraint transactions_buyer_id_fkey
  foreign key (buyer_id) references auth.users(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 2. Enrolment counts are counted, not accumulated
-- ---------------------------------------------------------------------------
-- `bump_course_enrollments` only ever added one, on insert. Once accounts can
-- be deleted, their enrolments cascade away and the number would stay high
-- forever. A recount on insert *and* delete cannot drift.

create or replace function public.recount_course_enrollments()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cid uuid := coalesce(new.course_id, old.course_id);
begin
  update public.courses
     set enrollments = (select count(*) from public.enrollments where course_id = cid)
   where id = cid;
  return null;
end;
$$;

revoke execute on function public.recount_course_enrollments() from public, anon, authenticated;

drop trigger if exists on_enrollment_created on public.enrollments;
drop trigger if exists on_enrollment_changed on public.enrollments;
create trigger on_enrollment_changed
  after insert or delete on public.enrollments
  for each row execute function public.recount_course_enrollments();

drop function if exists public.bump_course_enrollments();

-- The demo seed wrote invented figures (18,140 enrolments against 10 real
-- rows; 14 rated courses backed by 3 ratings). Reset every course to what the
-- rows actually say. Idempotent, and correct in any environment.
update public.courses c
   set enrollments = (select count(*) from public.enrollments e where e.course_id = c.id);

update public.courses c
   set rating_count = sub.cnt,
       rating_avg   = sub.avg
  from (
    select c2.id,
           count(r.id)::int                         as cnt,
           coalesce(avg(r.rating), 0)::numeric(3, 2) as avg
      from public.courses c2
      left join public.course_ratings r on r.course_id = c2.id
     group by c2.id
  ) sub
 where sub.id = c.id;

-- ---------------------------------------------------------------------------
-- 3. Reports
-- ---------------------------------------------------------------------------
-- Play's User Generated Content policy expects users to be able to flag
-- objectionable content from inside the app. Reports are write-only for
-- clients: nobody reads them back through the API, they are worked from the
-- dashboard (or a service-role tool) until moderation needs its own screen.

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),

  -- SET NULL throughout: a report is evidence, and must survive the reporter
  -- deleting their account or the content being taken down because of it.
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('course', 'comment')),
  course_id   uuid references public.courses(id) on delete set null,
  comment_id  uuid references public.course_comments(id) on delete set null,

  -- What was reported, copied at report time by the trigger below, so a
  -- moderator can still see it once the original is gone.
  target_excerpt text,
  target_owner_id uuid,

  reason text not null check (reason in (
    'spam', 'harassment', 'hate', 'sexual', 'violence',
    'copyright', 'misleading', 'other'
  )),
  details text check (char_length(details) <= 1000),

  status text not null default 'open'
    check (status in ('open', 'actioned', 'dismissed')),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

-- One report per person per thing. The client treats a unique violation as
-- "already reported" rather than an error.
create unique index if not exists content_reports_one_per_reporter
  on public.content_reports (reporter_id, target_type, coalesce(comment_id, course_id));

create index if not exists content_reports_open
  on public.content_reports (created_at desc) where status = 'open';

-- Server-owned fields are set here rather than trusted from the client: who
-- reported, the status, and the snapshot of the content.
create or replace function public.fill_content_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.reporter_id := auth.uid();
  new.status := 'open';
  new.resolved_at := null;
  new.created_at := now();

  if new.target_type = 'comment' then
    select cc.body, cc.user_id, cc.course_id
      into new.target_excerpt, new.target_owner_id, new.course_id
      from public.course_comments cc
     where cc.id = new.comment_id;
  else
    new.comment_id := null;
    select c.title, c.user_id
      into new.target_excerpt, new.target_owner_id
      from public.courses c
     where c.id = new.course_id;
  end if;

  if new.target_owner_id is null then
    raise exception 'Reported content does not exist' using errcode = 'P0002';
  end if;

  new.target_excerpt := left(new.target_excerpt, 500);
  return new;
end;
$$;

revoke execute on function public.fill_content_report() from public, anon, authenticated;

drop trigger if exists before_content_report_insert on public.content_reports;
create trigger before_content_report_insert
  before insert on public.content_reports
  for each row execute function public.fill_content_report();

alter table public.content_reports enable row level security;

drop policy if exists "Signed-in users can file reports" on public.content_reports;
create policy "Signed-in users can file reports"
  on public.content_reports for insert to authenticated
  with check (
    (target_type = 'course'  and course_id  is not null)
    or (target_type = 'comment' and comment_id is not null)
  );

-- No select/update/delete policies: clients file reports and never see them.
revoke select, update, delete, truncate, references
  on public.content_reports from anon, authenticated;
grant insert (target_type, course_id, comment_id, reason, details)
  on public.content_reports to authenticated;
