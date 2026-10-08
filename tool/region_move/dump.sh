#!/usr/bin/env bash
# Dumps the old project's database: schema, then data, then row counts to
# compare against after the restore. See docs/REGION_MOVE.md.
#
# The pg_dump flags and sed filters are the ones `supabase db dump` runs,
# printed with its --dry-run flag (CLI 2.117.0), so the result is what
# Supabase's migration guide expects. Running pg_dump directly saves needing
# Docker, which the CLI uses for this.
#
# Doubles as a backup on the free plan, which has no automatic ones:
#   bash tool/region_move/dump.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/.env"
: "${OLD_DB_URL:?Set OLD_DB_URL in tool/region_move/.env}"

out="${DUMP_DIR_ROOT:-$HOME/padilearn-backups}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"

internal='information_schema|pg_*|_analytics|_realtime|_supavisor|auth|etl|extensions|pgbouncer|realtime|storage|supabase_functions|supabase_migrations|cron|dbdev|graphql|graphql_public|net|pgmq|pgsodium|pgsodium_masks|pgtle|repack|tiger|tiger_data|timescaledb_*|_timescaledb_*|topology|vault'
data_internal='information_schema|pg_*|graphql|graphql_public|pgsodium|pgsodium_masks|pgtle|repack|tiger|tiger_data|timescaledb_*|_timescaledb_*|topology|vault|etl|extensions|pgbouncer|realtime|supabase_migrations|_analytics|_realtime|_supavisor'

echo "Dumping the schema..."
pg_dump --dbname "$OLD_DB_URL" \
    --schema-only \
    --quote-all-identifier \
    --role postgres \
    --exclude-schema "$internal" \
| sed -E 's/^\\(un)?restrict .*$/-- &/' \
| sed -E 's/^CREATE SCHEMA "/CREATE SCHEMA IF NOT EXISTS "/' \
| sed -E 's/^CREATE TABLE "/CREATE TABLE IF NOT EXISTS "/' \
| sed -E 's/^CREATE SEQUENCE "/CREATE SEQUENCE IF NOT EXISTS "/' \
| sed -E 's/^CREATE VIEW "/CREATE OR REPLACE VIEW "/' \
| sed -E 's/^CREATE FUNCTION "/CREATE OR REPLACE FUNCTION "/' \
| sed -E 's/^CREATE TRIGGER "/CREATE OR REPLACE TRIGGER "/' \
| sed -E 's/^CREATE PUBLICATION "supabase_realtime/-- &/' \
| sed -E 's/^CREATE EVENT TRIGGER /-- &/' \
| sed -E 's/^         WHEN TAG IN /-- &/' \
| sed -E 's/^   EXECUTE FUNCTION /-- &/' \
| sed -E 's/^ALTER EVENT TRIGGER /-- &/' \
| sed -E 's/^ALTER PUBLICATION "supabase_realtime_/-- &/' \
| sed -E 's/^ALTER FOREIGN DATA WRAPPER (.+) OWNER TO /-- &/' \
| sed -E 's/^ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin"/-- &/' \
| sed -E 's/^GRANT ALL ON FOREIGN DATA WRAPPER (.+) TO "postgres" WITH GRANT OPTION/-- &/' \
| sed -E "s/^GRANT (.+) ON (.+) \"($internal)\"/-- &/" \
| sed -E "s/^REVOKE (.+) ON (.+) \"($internal)\"/-- &/" \
| sed -E 's/^(CREATE EXTENSION IF NOT EXISTS "pg_tle").+/\1;/' \
| sed -E 's/^(CREATE EXTENSION IF NOT EXISTS "pgsodium").+/\1;/' \
| sed -E 's/^(CREATE EXTENSION IF NOT EXISTS "pgmq").+/\1;/' \
| sed -E 's/^COMMENT ON EXTENSION (.+)/-- &/' \
| sed -E 's/^CREATE POLICY "cron_job_/-- &/' \
| sed -E 's/^ALTER TABLE "cron"/-- &/' \
| sed -E 's/^SET transaction_timeout = 0;/-- &/' \
| sed -E '/^--/d' \
> "$out/schema.sql"

echo "Dumping the data (accounts and storage metadata included)..."
{
  echo "SET session_replication_role = replica;"
  pg_dump --dbname "$OLD_DB_URL" \
      --data-only \
      --quote-all-identifier \
      --role postgres \
      --exclude-schema "$data_internal" \
      --exclude-table "auth.schema_migrations" \
      --exclude-table "storage.migrations" \
      --exclude-table "supabase_functions.migrations" \
      --schema '*' \
      --exclude-table '"storage"."buckets_vectors"' \
      --exclude-table '"storage"."vector_indexes"' \
  | sed -E 's/^\\(un)?restrict .*$/-- &/'
  echo "RESET ALL;"
} > "$out/data.sql"

echo "Counting rows..."
psql "$OLD_DB_URL" -X -q -A -t -f "$here/counts.sql" > "$out/counts-old.txt"

echo "$out" > "$here/.last_dump"
echo
echo "Done: $out"
ls -l "$out"
