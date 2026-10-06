-- Category approval (docs/ADMIN_PANEL.md, item 7).
--
-- Teachers can suggest a category (20260802000001): it saves inactive, shows
-- on their own course, and stays out of the browse filters until approved.
-- Approving, renaming and removing were left to "SQL or the dashboard". These
-- are those actions, for admins.
--
-- Names are unique case-sensitively in the table, so "design" could sit next
-- to "Design". Every function here checks names case-insensitively, and a
-- suggestion that duplicates an existing category is meant to be merged into
-- it (admin_delete_category with p_move_to), not approved alongside it.
--
-- Category actions are low-stakes, so the reason is optional, unlike
-- takedowns and money.

-- ---------------------------------------------------------------------------
-- 1. The list
-- ---------------------------------------------------------------------------
-- Pending suggestions first, then the approved list in display order, with how
-- many courses use each, since that decides what a rename or delete touches.

create or replace function public.admin_list_categories()
returns table (
  id uuid,
  name text,
  "position" integer,
  is_active boolean,
  suggested_by uuid,
  suggested_by_name text,
  created_at timestamptz,
  course_count bigint
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
    c.id,
    c.name,
    c.position,
    c.is_active,
    c.suggested_by,
    p.name,
    c.created_at,
    (select count(*) from public.courses co where co.category = c.name)
  from public.categories c
  left join public.profiles p on p.id = c.suggested_by
  order by c.is_active, c.position, c.name;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Approve or switch off
-- ---------------------------------------------------------------------------
-- Switching a category off hides it from the browse filters; courses keep it
-- (the foreign key is by name, and the row still exists).

create or replace function public.admin_set_category_active(
  p_category_id uuid,
  p_active boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cat record;
  v_clash text;
begin
  perform public.assert_admin();

  if p_active is null then
    raise exception 'Say whether the category should be active' using errcode = '22023';
  end if;

  select c.id, c.name, c.is_active
    into v_cat
    from public.categories c
   where c.id = p_category_id
     for update;
  if not found then
    raise exception 'Category not found' using errcode = 'P0002';
  end if;
  if v_cat.is_active = p_active then
    raise exception 'Category is already %', case when p_active then 'active' else 'inactive' end
      using errcode = '22023';
  end if;

  if p_active then
    select c.name into v_clash
      from public.categories c
     where lower(c.name) = lower(v_cat.name)
       and c.id <> v_cat.id
     limit 1;
    if v_clash is not null then
      raise exception 'A category named "%" already exists; merge this one into it instead', v_clash
        using errcode = '22023';
    end if;
  end if;

  update public.categories
     set is_active = p_active
   where id = p_category_id;

  perform public.log_admin_action(
    case when p_active then 'category.approve' else 'category.deactivate' end,
    'category', p_category_id, nullif(btrim(p_reason), ''),
    jsonb_build_object('name', v_cat.name)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Rename or reorder
-- ---------------------------------------------------------------------------
-- A rename cascades to every course using the category, through the existing
-- ON UPDATE CASCADE foreign key. Pass null to leave a field as it is.

create or replace function public.admin_update_category(
  p_category_id uuid,
  p_name text default null,
  p_position integer default null,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cat record;
  v_name text := nullif(btrim(p_name), '');
  v_clash text;
begin
  perform public.assert_admin();

  if v_name is null and p_position is null then
    raise exception 'Nothing to change' using errcode = '22023';
  end if;
  if v_name is not null and char_length(v_name) > 40 then
    raise exception 'Category names are at most 40 characters' using errcode = '22023';
  end if;
  if p_position is not null and p_position < 0 then
    raise exception 'Position cannot be negative' using errcode = '22023';
  end if;

  select c.id, c.name, c.position
    into v_cat
    from public.categories c
   where c.id = p_category_id
     for update;
  if not found then
    raise exception 'Category not found' using errcode = 'P0002';
  end if;

  v_name := coalesce(v_name, v_cat.name);
  if v_name = v_cat.name and coalesce(p_position, v_cat.position) = v_cat.position then
    raise exception 'Nothing to change' using errcode = '22023';
  end if;

  if v_name <> v_cat.name then
    select c.name into v_clash
      from public.categories c
     where lower(c.name) = lower(v_name)
       and c.id <> v_cat.id
     limit 1;
    if v_clash is not null then
      raise exception 'A category named "%" already exists', v_clash using errcode = '22023';
    end if;
  end if;

  update public.categories
     set name = v_name,
         position = coalesce(p_position, v_cat.position)
   where id = p_category_id;

  perform public.log_admin_action(
    'category.update', 'category', p_category_id, nullif(btrim(p_reason), ''),
    jsonb_build_object(
      'from_name', v_cat.name, 'to_name', v_name,
      'from_position', v_cat.position, 'to_position', coalesce(p_position, v_cat.position)
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Delete, optionally merging into another category
-- ---------------------------------------------------------------------------
-- For rejecting a suggestion, or folding a duplicate into the real one. If any
-- course uses the category, p_move_to is required, so no course is silently
-- left without a category (the foreign key would set it to null).

create or replace function public.admin_delete_category(
  p_category_id uuid,
  p_move_to uuid default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cat record;
  -- Plain variables, not a record: a record left unassigned when there is no
  -- merge target would fail on first read.
  v_target_name text;
  v_target_active boolean;
  v_moved integer := 0;
  v_using bigint;
begin
  perform public.assert_admin();

  select c.id, c.name, c.is_active, c.suggested_by
    into v_cat
    from public.categories c
   where c.id = p_category_id
     for update;
  if not found then
    raise exception 'Category not found' using errcode = 'P0002';
  end if;

  select count(*) into v_using from public.courses co where co.category = v_cat.name;

  if p_move_to is not null then
    if p_move_to = p_category_id then
      raise exception 'Cannot merge a category into itself' using errcode = '22023';
    end if;
    select c.name, c.is_active
      into v_target_name, v_target_active
      from public.categories c
     where c.id = p_move_to;
    if not found then
      raise exception 'Category to move courses to not found' using errcode = 'P0002';
    end if;
    if not v_target_active then
      raise exception 'Courses can only be moved to an active category' using errcode = '22023';
    end if;

    update public.courses
       set category = v_target_name
     where category = v_cat.name;
    get diagnostics v_moved = row_count;
  elsif v_using > 0 then
    raise exception '% course(s) use this category; choose one to move them to', v_using
      using errcode = '22023';
  end if;

  delete from public.categories where id = p_category_id;

  perform public.log_admin_action(
    'category.delete', 'category', p_category_id, nullif(btrim(p_reason), ''),
    jsonb_build_object(
      'name', v_cat.name,
      'was_active', v_cat.is_active,
      'suggested_by', v_cat.suggested_by,
      'moved_to', v_target_name,
      'courses_moved', v_moved
    )
  );

  return jsonb_build_object('courses_moved', v_moved);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
-- Callable by any signed-in user; assert_admin() inside is the gate.

revoke execute on function public.admin_list_categories() from public, anon;
revoke execute on function public.admin_set_category_active(uuid, boolean, text) from public, anon;
revoke execute on function public.admin_update_category(uuid, text, integer, text) from public, anon;
revoke execute on function public.admin_delete_category(uuid, uuid, text) from public, anon;
grant execute on function public.admin_list_categories() to authenticated;
grant execute on function public.admin_set_category_active(uuid, boolean, text) to authenticated;
grant execute on function public.admin_update_category(uuid, text, integer, text) to authenticated;
grant execute on function public.admin_delete_category(uuid, uuid, text) to authenticated;
