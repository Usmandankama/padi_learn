-- Reports queue (docs/ADMIN_PANEL.md, item 3).
--
-- Reports have been write-only since they were added: students file them from
-- the app, and nobody could read them except through Studio. This gives an
-- admin the queue and the three things a report can lead to: delete the
-- comment, take the course down (item 2), or dismiss it. Acting on the content
-- closes every open report about it at once, so ten people flagging the same
-- comment is one decision, not ten.

-- ---------------------------------------------------------------------------
-- 1. Who resolved a report, and why
-- ---------------------------------------------------------------------------
-- Also in `admin_actions`, but the queue shows them on every row, and a join
-- into the audit log per report is the wrong way round.

alter table public.content_reports
  add column if not exists resolved_by uuid references auth.users(id) on delete set null,
  add column if not exists resolution_note text;

alter table public.content_reports
  drop constraint if exists content_reports_resolution_check;
alter table public.content_reports
  add constraint content_reports_resolution_check
  check (
    (status = 'open') = (resolved_at is null)
    and (resolution_note is null or char_length(resolution_note) <= 1000)
  );

-- ---------------------------------------------------------------------------
-- 2. Close the insert grant the reports migration meant to narrow
-- ---------------------------------------------------------------------------
-- 20260914000001 granted INSERT on five columns but never revoked the
-- table-wide INSERT Supabase gives every new table, so the column grant
-- narrowed nothing. The fill trigger overwrote most server-owned fields
-- anyway, which is why it never mattered, but it does not know about the two
-- columns above. Same fix as `courses` in 20261006000002: revoke the table
-- privilege (which takes its implied column privileges with it), then grant
-- exactly what report_service.dart sends. anon has no INSERT policy and loses
-- the privilege too.

revoke insert on public.content_reports from anon, authenticated;
grant insert (target_type, course_id, comment_id, reason, details)
  on public.content_reports to authenticated;

-- And the trigger learns the new columns, so the rule "server-owned fields are
-- set here" stays true in one place even if a grant is ever widened again.
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
  new.resolved_by := null;
  new.resolution_note := null;
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

-- ---------------------------------------------------------------------------
-- 3. Close every open report about one thing
-- ---------------------------------------------------------------------------
-- Internal: called by the admin RPCs that act on content. Returns the ids it
-- closed so the caller can log them. Must run *before* a comment is deleted,
-- because `comment_id` is ON DELETE SET NULL and the match would be lost.

create or replace function public.resolve_reports_for(
  p_target_type text,
  p_target_id uuid,
  p_status text,
  p_note text
)
returns uuid[]
language sql
set search_path = ''
as $$
  with closed as (
    update public.content_reports r
       set status = p_status,
           resolved_at = now(),
           resolved_by = auth.uid(),
           resolution_note = p_note
     where r.status = 'open'
       and r.target_type = p_target_type
       and case p_target_type
             when 'comment' then r.comment_id
             else r.course_id
           end = p_target_id
    returning r.id
  )
  select coalesce(array_agg(id), '{}'::uuid[]) from closed;
$$;

revoke execute on function public.resolve_reports_for(text, uuid, text, text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. The queue
-- ---------------------------------------------------------------------------
-- One row per report, with what the admin needs to decide without opening
-- anything else: the snapshot taken at report time *and* the content as it is
-- now (a comment may have been edited or deleted since), who is involved, and
-- how many other open reports point at the same thing.
--
-- Open reports come oldest first, so the queue is worked in order; resolved
-- ones most recently resolved first. Offset paging is fine at this volume.

create or replace function public.admin_list_reports(
  p_status text default 'open',
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  status text,
  reason text,
  details text,
  created_at timestamptz,
  target_type text,
  course_id uuid,
  course_title text,
  course_removed_at timestamptz,
  comment_id uuid,
  comment_exists boolean,
  target_excerpt text,
  current_body text,
  target_owner_id uuid,
  owner_name text,
  reporter_id uuid,
  reporter_name text,
  open_reports_on_target bigint,
  resolved_at timestamptz,
  resolved_by uuid,
  resolved_by_name text,
  resolution_note text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.assert_admin();

  if p_status is null or p_status not in ('open', 'actioned', 'dismissed') then
    raise exception 'Unknown report status: %', p_status using errcode = '22023';
  end if;

  return query
  select
    r.id,
    r.status,
    r.reason,
    r.details,
    r.created_at,
    r.target_type,
    r.course_id,
    c.title,
    c.removed_at,
    r.comment_id,
    cc.id is not null,
    r.target_excerpt,
    case when r.target_type = 'comment' then cc.body else c.title end,
    r.target_owner_id,
    owner_p.name,
    r.reporter_id,
    reporter_p.name,
    (
      select count(*)
        from public.content_reports o
       where o.status = 'open'
         and o.target_type = r.target_type
         and case r.target_type when 'comment' then o.comment_id else o.course_id end
           = case r.target_type when 'comment' then r.comment_id else r.course_id end
    ),
    r.resolved_at,
    r.resolved_by,
    resolver_p.name,
    r.resolution_note
  from public.content_reports r
  left join public.courses c on c.id = r.course_id
  left join public.course_comments cc on cc.id = r.comment_id
  left join public.profiles owner_p on owner_p.id = r.target_owner_id
  left join public.profiles reporter_p on reporter_p.id = r.reporter_id
  left join public.profiles resolver_p on resolver_p.id = r.resolved_by
  where r.status = p_status
  order by
    case when p_status = 'open' then r.created_at end asc,
    r.resolved_at desc,
    r.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Resolve, dismiss or reopen one report
-- ---------------------------------------------------------------------------
-- For decisions that do not touch the content: dismissing, marking a report
-- actioned when the owner already fixed it, or reopening a mistake. Acting on
-- the content goes through admin_delete_comment / admin_remove_course, which
-- close the reports themselves.

create or replace function public.admin_set_report_status(
  p_report_id uuid,
  p_status text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_report record;
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;
  if p_status is null or p_status not in ('open', 'actioned', 'dismissed') then
    raise exception 'Unknown report status: %', p_status using errcode = '22023';
  end if;

  select r.id, r.status, r.target_type, r.course_id, r.comment_id, r.resolution_note
    into v_report
    from public.content_reports r
   where r.id = p_report_id
     for update;
  if not found then
    raise exception 'Report not found' using errcode = 'P0002';
  end if;
  if v_report.status = p_status then
    raise exception 'Report is already %', p_status using errcode = '22023';
  end if;

  update public.content_reports
     set status = p_status,
         resolved_at = case when p_status = 'open' then null else now() end,
         resolved_by = case when p_status = 'open' then null else auth.uid() end,
         resolution_note = case when p_status = 'open' then null else v_reason end
   where id = p_report_id;

  perform public.log_admin_action(
    case p_status when 'open' then 'report.reopen' else 'report.' || p_status end,
    'report', p_report_id, v_reason,
    jsonb_build_object(
      'from', v_report.status,
      'target_type', v_report.target_type,
      'course_id', v_report.course_id,
      'comment_id', v_report.comment_id,
      -- Reopening clears the note on the row; keep what it said.
      'previous_note', v_report.resolution_note
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Delete a comment
-- ---------------------------------------------------------------------------
-- Works on any comment, reported or not. Its open reports are closed as
-- actioned first (see resolve_reports_for), its notifications cascade away,
-- and the text survives in the reports' snapshot and in the audit log.

create or replace function public.admin_delete_comment(p_comment_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_comment record;
  v_closed uuid[];
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;

  select cc.id, cc.course_id, cc.user_id, cc.body
    into v_comment
    from public.course_comments cc
   where cc.id = p_comment_id
     for update;
  if not found then
    raise exception 'Comment not found' using errcode = 'P0002';
  end if;

  v_closed := public.resolve_reports_for('comment', p_comment_id, 'actioned', v_reason);

  delete from public.course_comments where id = p_comment_id;

  perform public.log_admin_action(
    'comment.delete', 'comment', p_comment_id, v_reason,
    jsonb_build_object(
      'course_id', v_comment.course_id,
      'author_id', v_comment.user_id,
      'body', left(v_comment.body, 500),
      'closed_reports', to_jsonb(v_closed)
    )
  );

  return jsonb_build_object('closed_reports', coalesce(array_length(v_closed, 1), 0));
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Taking a course down closes its reports too
-- ---------------------------------------------------------------------------
-- Same function as 20261006000002, plus the resolve_reports_for call and its
-- count in the log and the result. Reports about *comments* on the course stay
-- open: they are about someone else's words, and need their own decision.

create or replace function public.admin_remove_course(p_course_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(p_reason), '');
  v_course record;
  v_sales integer;
  v_kobo bigint;
  v_closed uuid[];
begin
  perform public.assert_admin();

  if v_reason is null then
    raise exception 'A reason is required' using errcode = '22023';
  end if;

  select id, title, user_id, removed_at
    into v_course
    from public.courses
   where id = p_course_id
     for update;
  if not found then
    raise exception 'Course not found' using errcode = 'P0002';
  end if;
  if v_course.removed_at is not null then
    raise exception 'Course is already removed' using errcode = '22023';
  end if;

  -- Everyone who paid just lost access, and is owed a refund. Counted from the
  -- ledger, not from enrolments: free enrolments are owed nothing, and a paid
  -- enrolment's buyer may since have deleted their account.
  select count(*), coalesce(sum(t.amount_kobo), 0)
    into v_sales, v_kobo
    from public.transactions t
   where t.course_id = p_course_id
     and t.status = 'success';

  update public.courses
     set removed_at = now(),
         removed_reason = v_reason
   where id = p_course_id;

  v_closed := public.resolve_reports_for('course', p_course_id, 'actioned', v_reason);

  perform public.log_admin_action(
    'course.remove', 'course', p_course_id, v_reason,
    jsonb_build_object(
      'title', v_course.title,
      'owner_id', v_course.user_id,
      'paid_sales', v_sales,
      'paid_kobo', v_kobo,
      'closed_reports', to_jsonb(v_closed)
    )
  );

  return jsonb_build_object(
    'paid_sales', v_sales,
    'paid_kobo', v_kobo,
    'closed_reports', coalesce(array_length(v_closed, 1), 0)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Callable by any signed-in user; assert_admin() inside is the gate.

revoke execute on function public.admin_list_reports(text, integer, integer) from public, anon;
revoke execute on function public.admin_set_report_status(uuid, text, text) from public, anon;
revoke execute on function public.admin_delete_comment(uuid, text) from public, anon;
revoke execute on function public.admin_remove_course(uuid, text) from public, anon;
grant execute on function public.admin_list_reports(text, integer, integer) to authenticated;
grant execute on function public.admin_set_report_status(uuid, text, text) to authenticated;
grant execute on function public.admin_delete_comment(uuid, text) to authenticated;
grant execute on function public.admin_remove_course(uuid, text) to authenticated;
