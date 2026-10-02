#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1911 — the data dictionary, read from a database's catalogues.
#
#   scripts/db_dictionary.sh <db url>            operator export: writes
#                                                report/db-dictionary.json
#                                                and report/db-dictionary-run.json
#   scripts/db_dictionary.sh <db url> --check    CI: the same, then fails
#                                                when the committed
#                                                docs/database/dictionary.json
#                                                is not what the replay built
#
# READ-ONLY: one SELECT (scripts/db_dictionary.sql) inside a read-only
# transaction. It reads catalogues only — no row, no secret, no function
# body — so it is safe against a production instance; the connection
# string is taken from the argument and never written anywhere.
#
# Consistency: the extraction runs twice; two different checksums mean DDL
# ran in between and the run is refused rather than called a snapshot.
# Nothing here claims a globally atomic view of a live database: that is
# only true of the disposable replay.
#
# Regenerate the committed renderings from the committed JSON with
# `dart run tool/build_db_dictionary.dart`.
set -uo pipefail

DB_URL=${1:?usage: db_dictionary.sh <db url> [--check]}
MODE=${2:-export}
COMMITTED=docs/database/dictionary.json
OUT=report
mkdir -p "$OUT"

fail() { echo "::error::$*"; exit 1; }

extract() {
  { echo "begin transaction isolation level repeatable read read only;"
    cat scripts/db_dictionary.sql
    echo "commit;"
  } | psql "$DB_URL" -q -At -v ON_ERROR_STOP=1
}

extract > "$OUT/db-dictionary.json" || fail "the dictionary query failed"
extract > "$OUT/db-dictionary.second.json" || fail "the dictionary query failed"
cmp -s "$OUT/db-dictionary.json" "$OUT/db-dictionary.second.json" \
  || fail "the catalogue changed while it was being read (DDL in between) — nothing was recorded"
rm -f "$OUT/db-dictionary.second.json"

# What a reader of the artifact needs and the committed file must not
# carry: when, on which server build, which managed schemas existed.
psql "$DB_URL" -q -At -v ON_ERROR_STOP=1 -c "
select jsonb_pretty(jsonb_build_object(
  'snapshotAt', now(),
  'serverVersion', current_setting('server_version'),
  'managedSchemasPresent', (select coalesce(jsonb_agg(nspname order by nspname), '[]'::jsonb)
     from pg_namespace
    where nspname not in ('public', 'information_schema')
      and nspname not like 'pg\_%'),
  'consistency', 'extracted twice in read-only repeatable-read transactions; identical'))" \
  > "$OUT/db-dictionary-run.json" || fail "the run record query failed"

tables=$(grep -c '"kind": "table"' "$OUT/db-dictionary.json" || true)
[ "$tables" -gt 50 ] || fail "the dictionary names only $tables tables — the replay is not what it should be"
echo "dictionary: $tables tables, $(wc -c < "$OUT/db-dictionary.json" | tr -d ' ') bytes"

if [ "$MODE" = "--check" ]; then
  [ -s "$COMMITTED" ] || fail "$COMMITTED is empty — commit this run's $OUT/db-dictionary.json as $COMMITTED, then run dart run tool/build_db_dictionary.dart"
  if ! diff -u "$COMMITTED" "$OUT/db-dictionary.json" > "$OUT/db-dictionary.diff"; then
    head -n 200 "$OUT/db-dictionary.diff"
    fail "$COMMITTED is not what the migrations build — copy the run's db-dictionary.json (artifact quality-database) over it, then run dart run tool/build_db_dictionary.dart and commit the renderings"
  fi
  echo "dictionary: committed file equals the replay"
fi
