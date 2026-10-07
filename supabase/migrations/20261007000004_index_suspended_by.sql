-- The one unindexed foreign key 20261007000003 missed: `suspensions` arrived
-- in 20261006000010, after the advisor run that listed the others.

create index if not exists suspensions_suspended_by_idx on public.suspensions (suspended_by);
