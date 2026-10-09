#!/usr/bin/env bash
# Restores the last dump into the new project, in one transaction: if any
# statement fails, nothing is written and it can simply be run again.
# See docs/REGION_MOVE.md.
#
#   bash tool/region_move/restore.sh [dump folder]
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/.env"
: "${NEW_DB_URL:?Set NEW_DB_URL in tool/region_move/.env}"
: "${OLD_REF:?Set OLD_REF in tool/region_move/.env}"
: "${NEW_REF:?Set NEW_REF in tool/region_move/.env}"

dir="${1:-$(cat "$here/.last_dump")}"
for f in schema.sql data.sql counts-old.txt; do
  [[ -f "$dir/$f" ]] || { echo "Missing $dir/$f: run dump.sh first." >&2; exit 1; }
done

# A new project grants anon and authenticated everything on each table and
# function created in public. pg_dump only writes grants, never those
# defaults' undoing, so restoring on top of them silently reopened what the
# old project had locked down (9 October: 42 functions callable signed out,
# every column of profiles writable). Switch the defaults off for the
# restore; the schema dump switches them back on at its end.
defaults_off='
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated, service_role;'

echo "Restoring $dir into $NEW_REF..."
psql "$NEW_DB_URL" -X -q \
    --single-transaction \
    --variable ON_ERROR_STOP=1 \
    --variable old_host="$OLD_REF.supabase.co" \
    --variable new_host="$NEW_REF.supabase.co" \
    --command "$defaults_off" \
    --file "$dir/schema.sql" \
    --command 'SET session_replication_role = replica' \
    --file "$dir/data.sql" \
    --file "$here/auth_storage.sql" \
    --file "$here/rewrite_urls.sql"

echo "Counting rows in the new project..."
psql "$NEW_DB_URL" -X -q -A -t -f "$here/counts.sql" > "$dir/counts-new.txt"

if diff -u "$dir/counts-old.txt" "$dir/counts-new.txt"; then
  echo
  echo "Counts match: every table, policy, function, trigger and realtime table."
else
  echo
  echo "Counts differ (above). Send Claude the diff before going further." >&2
  exit 1
fi
