-- Course categories move out of the app and into the database.
--
-- They were hardcoded in three Dart files, so widening the catalogue meant
-- editing all three and shipping a release — and nothing constrained
-- `courses.category`, which is free text.
--
-- With a table, adding a category is one INSERT and every client sees it
-- immediately. Teachers can also *suggest* one: it saves against their course
-- but stays inactive, so it never pollutes the browse filters until approved.

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),

  -- Unique because `courses.category` references it by name (see below).
  name text not null unique,

  -- Display order in pickers and filter chips; suggestions sort to the end.
  position integer not null default 100,

  -- Inactive = suggested but not approved. Visible on its own course, never in
  -- the browse filters.
  is_active boolean not null default true,

  suggested_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

insert into public.categories (name, position) values
  ('Exam Prep',            10),
  ('Programming',          20),
  ('Design',               30),
  ('Marketing',            40),
  ('Business',             50),
  ('Data Science',         60),
  ('Finance',              70),
  ('Languages',            80),
  ('Agriculture',          90),
  ('Fashion & Tailoring',  100),
  ('Beauty & Grooming',    110),
  ('Music',                120),
  ('Photography & Video',  130),
  ('Trades & Vocational',  140),
  ('Health & Fitness',     150),
  ('Writing',              160)
on conflict (name) do nothing;

-- Referential integrity without a join: the course keeps the readable name, and
-- ON UPDATE CASCADE means renaming a category rewrites every course that uses
-- it rather than orphaning them.
alter table public.courses
  drop constraint if exists courses_category_fkey;
alter table public.courses
  add constraint courses_category_fkey
  foreign key (category) references public.categories(name)
  on update cascade on delete set null;

alter table public.categories enable row level security;

-- The approved list, plus anything the caller suggested themselves (so their
-- own pending category still renders in their course's picker).
drop policy if exists "Categories are readable" on public.categories;
create policy "Categories are readable"
  on public.categories for select to authenticated
  using (is_active or suggested_by = auth.uid());

-- Teachers may propose, never self-approve: the WITH CHECK pins is_active to
-- false and the author to themselves.
drop policy if exists "Teachers can suggest categories" on public.categories;
create policy "Teachers can suggest categories"
  on public.categories for insert to authenticated
  with check (
    is_active = false
    and suggested_by = auth.uid()
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'Teacher'
    )
  );

-- Approving, renaming and removing categories is a back-office action done
-- through SQL or the dashboard, not from the app.
revoke update, delete, truncate on public.categories from anon, authenticated;
