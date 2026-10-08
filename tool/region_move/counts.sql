-- Row counts and structure checks, run against both projects so the two can
-- be compared line by line. Exact counts: the tables are small.
select 'rows ' || table_schema || '.' || table_name || ' = ' ||
       (xpath('/row/c/text()',
              query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name),
                           false, true, '')))[1]::text
  from information_schema.tables
 where table_type = 'BASE TABLE'
   and (table_schema in ('public', 'private')
        or (table_schema = 'auth' and table_name in ('users', 'identities', 'mfa_factors'))
        or (table_schema = 'storage' and table_name in ('buckets', 'objects')))
 order by table_schema, table_name;

select 'policies ' || schemaname || ' = ' || count(*)
  from pg_policies where schemaname in ('public', 'private', 'storage')
 group by schemaname order by schemaname;

select 'functions ' || n.nspname || ' = ' || count(*)
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname in ('public', 'private')
 group by n.nspname order by n.nspname;

select 'triggers ' || n.nspname || ' = ' || count(*)
  from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace
 where not t.tgisinternal and n.nspname in ('public', 'private', 'auth')
 group by n.nspname order by n.nspname;

select 'realtime = ' || coalesce(string_agg(schemaname || '.' || tablename, ', ' order by tablename), '(none)')
  from pg_publication_tables where pubname = 'supabase_realtime';
