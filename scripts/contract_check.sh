#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #1455 — the effective SQL contract, read from the replay, not from the
# migrations.
#
# Fifty-eight migrations patch stored function bodies by text anchor. A
# reviewer of the fifty-ninth cannot see the routine it produces, its
# overloads, or who may execute it, without replaying the whole history.
# So the database job writes that answer down after the replay:
#
#   assets/instance/contract.txt   one line per routine (identity
#                                  signature, kind, definer/invoker,
#                                  volatility, execute grants, a digest
#                                  of the effective body), per constraint
#                                  and per trigger — committed, and the
#                                  job fails when the replay disagrees,
#                                  exactly as the policy manifest does;
#   report/effective-schema.sql    the full effective definitions, as an
#                                  artifact of the run, for the reviewer
#                                  who wants to read a body rather than
#                                  trust a digest.
#
# A change made by an anchored patch moves the body digest of the routine
# it touched; a stale overload, a new grant, a changed constraint each
# appear as their own line. Unstable catalogue ids never enter the file.
#
# #2584 (audit A06) — one explicit target. The catalogue queries, the
# readable dump and the provenance all describe the database named by
# <db url>, or the run fails before it produces evidence. A dump is never
# taken from "the first supabase_db container": with several local stacks
# that described another project than the contract did.
#
#   CONTRACT_TARGET_LABEL   optional safe label ([A-Za-z0-9._-]); the
#                           outputs go to report/<label>/ instead of report/
#   CONTRACT_DB_CONTAINER   optional container of the target, used when the
#                           host pg_dump is older than the server; it is
#                           verified against the queried database (same
#                           name, version and body digests) before dumping
#   PSQL_BIN PG_DUMP_BIN DOCKER_BIN   the tools (test stubs)
#
# manifest.json (target label, database, server version, a digest of the
# target identity, source sha, run id, hashes of the outputs) is written
# last, once the contract and the dump agree on one unchanged target. No
# connection string or password reaches stdout, stderr or a file.
set -uo pipefail

DB_URL=${1:?usage: contract_check.sh <db url>}
COMMITTED=assets/instance/contract.txt
PSQL=${PSQL_BIN:-psql}
PG_DUMP=${PG_DUMP_BIN:-pg_dump}
DOCKER=${DOCKER_BIN:-docker}
LABEL=${CONTRACT_TARGET_LABEL:-}
OUT=report

# Credentials never print: the URL and the password inside it are masked.
_pw=""
case "$DB_URL" in
  *://*:*@*) _pw=${DB_URL#*://}; _pw=${_pw#*:}; _pw=${_pw%%@*} ;;
esac
redact() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line//"$DB_URL"/<target>}
    [ -n "$_pw" ] && line=${line//"$_pw"/***}
    printf '%s\n' "$line"
  done
}
say() { printf '%s\n' "$*" | redact; }
fail() { say "::error::$*" >&2; exit 1; }

if [ -n "$LABEL" ]; then
  [[ "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || fail "CONTRACT_TARGET_LABEL is not a safe label"
  OUT=report/$LABEL
fi
mkdir -p "$OUT"
rm -f "$OUT/manifest.json"

# Everything the script writes is staged beside its destination and
# renamed once both queries and the dump succeeded.
STAGE=$(mktemp -d "$OUT/.stage.XXXXXX") || exit 1
trap 'rm -rf "$STAGE"' EXIT

IDENTITY_SQL="select current_database() || '|' || current_setting('server_version_num') || '|' || coalesce((select md5(string_agg(p.oid::regprocedure::text || ':' || md5(p.prosrc), ',' order by p.oid::regprocedure::text)) from pg_proc p where p.pronamespace = 'public'::regnamespace), '')"

CONTRACT_SQL="
with r as (
  select 'routine ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ') -> ' || pg_get_function_result(p.oid)
    || ' | ' || case p.prokind when 'f' then 'function' when 'p' then 'procedure' when 'a' then 'aggregate' else p.prokind::text end
    || ' | ' || case when p.prosecdef then 'definer' else 'invoker' end
    || ' | ' || case p.provolatile when 'i' then 'immutable' when 's' then 'stable' else 'volatile' end
    || ' | exec:' || coalesce(concat_ws(',',
         case when has_function_privilege('anon', p.oid, 'execute') then 'anon' end,
         case when has_function_privilege('authenticated', p.oid, 'execute') then 'authenticated' end,
         case when has_function_privilege('service_role', p.oid, 'execute') then 'service_role' end), '-')
    || ' | body:' || left(md5(pg_get_functiondef(p.oid)), 12) as line
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
), c as (
  select 'constraint ' || conrelid::regclass || '.' || conname || ' ' || pg_get_constraintdef(oid) as line
  from pg_constraint
  where connamespace = 'public'::regnamespace and contype in ('c', 'f', 'u', 'p', 'x')
), t as (
  select 'trigger ' || tgrelid::regclass || '.' || tgname || ' ' || pg_get_triggerdef(oid) as line
  from pg_trigger
  where not tgisinternal
    and tgrelid in (select oid from pg_class where relnamespace = 'public'::regnamespace)
)
select line from r union all select line from c union all select line from t order by 1"

# psql against the target; its stderr is masked before it is shown.
target_psql() {
  local rc
  "$PSQL" "$DB_URL" -v ON_ERROR_STOP=1 -At -c "$1" 2>"$STAGE/psql.err"
  rc=$?
  [ -s "$STAGE/psql.err" ] && redact < "$STAGE/psql.err" >&2
  return $rc
}

identity() { target_psql "$IDENTITY_SQL" | head -1; }

BEFORE=$(identity) || fail "the target is not reachable: no identity could be read"
case "$BEFORE" in
  ?*'|'?*'|'?*) ;;
  *) fail "the target identity is missing or incomplete — no evidence is produced" ;;
esac
DBNAME=${BEFORE%%|*}
REST=${BEFORE#*|}
SERVER_NUM=${REST%%|*}
say "target: database $DBNAME, server $SERVER_NUM${LABEL:+, label $LABEL}"

target_psql "$CONTRACT_SQL" > "$STAGE/contract-lines.txt" \
  || fail "the contract query failed"

{
  echo '# GENERATED by `quality · database` (#1455): the effective SQL contract'
  echo '# of the public schema, read from the replay onto an empty Postgres.'
  echo '# One line per routine (identity signature, kind, definer/invoker,'
  echo '# volatility, execute grants, digest of the effective body), per'
  echo '# constraint and per trigger. A migration that patches a body by anchor'
  echo '# moves that routine'"'"'s digest here; a stale overload or a new grant is a'
  echo '# line of its own. The full definitions are the run'"'"'s'
  echo '# `effective-schema.sql` artifact.'
  echo '#'
  echo '# Update: run the database job; it writes this file and fails when it'
  echo '# differs. Copy the + side (keep this header).'
  cat "$STAGE/contract-lines.txt"
} > "$STAGE/contract.txt"

lines=$(grep -vc '^#' "$STAGE/contract.txt")
[ "$lines" -gt 100 ] || fail "the contract has only $lines lines — the replay is not what it should be"
echo "contract: $lines lines (routines, constraints, triggers)"

# The readable half: every effective definition, for the reviewer. It is
# taken from the SAME database the queries above described.
DUMP_ARGS=(--schema-only --schema=public --no-owner --no-privileges --no-comments)
dump_filter() {
  grep -vE '^(--|SET |SELECT pg_catalog\.set_config|\\restrict|\\unrestrict|$)'
}

host_dump_usable() {
  command -v "$PG_DUMP" >/dev/null 2>&1 || return 1
  local v major
  v=$("$PG_DUMP" --version 2>/dev/null) || return 1
  major=$(printf '%s' "$v" | sed -n 's/[^0-9]*\([0-9][0-9]*\).*/\1/p' | head -1)
  [ -n "$major" ] && [ "$major" -ge $((SERVER_NUM / 10000)) ]
}

container_dump() {
  local candidates=() matches=() c ident
  if [ -n "${CONTRACT_DB_CONTAINER:-}" ]; then
    candidates=("$CONTRACT_DB_CONTAINER")
  else
    while IFS= read -r c; do
      [ -n "$c" ] && candidates+=("$c")
    done < <("$DOCKER" ps --format '{{.Names}}' 2>/dev/null | grep -E '^supabase_db')
  fi
  [ "${#candidates[@]}" -gt 0 ] \
    || fail "no readable dump: pg_dump is older than the server and no database container is named"
  for c in "${candidates[@]}"; do
    ident=$("$DOCKER" exec "$c" psql -U postgres -d postgres -At -c "$IDENTITY_SQL" 2>/dev/null | head -1)
    [ "$ident" = "$BEFORE" ] && matches+=("$c")
  done
  [ "${#matches[@]}" -eq 1 ] \
    || fail "the dump target is ambiguous or is not the queried database (${#matches[@]} of ${#candidates[@]} containers match)"
  "$DOCKER" exec "${matches[0]}" pg_dump -U postgres -d postgres "${DUMP_ARGS[@]}" \
    2>"$STAGE/dump.err"
}

if host_dump_usable; then
  "$PG_DUMP" --dbname="$DB_URL" "${DUMP_ARGS[@]}" 2>"$STAGE/dump.err" > "$STAGE/dump.raw"
  rc=$?
else
  container_dump > "$STAGE/dump.raw"
  rc=$?
fi
[ -s "$STAGE/dump.err" ] && redact < "$STAGE/dump.err" >&2
[ "$rc" -eq 0 ] || fail "effective-schema.sql could not be dumped (exit $rc) — the readable schema is required evidence"
dump_filter < "$STAGE/dump.raw" > "$STAGE/effective-schema.sql"
[ -s "$STAGE/effective-schema.sql" ] || fail "the dump of the target is empty"

# One unchanged target: the identity and the contract are read again.
AFTER=$(identity) || fail "the target stopped answering during the dump"
[ "$AFTER" = "$BEFORE" ] || fail "the target changed while the evidence was taken (identity differs)"
target_psql "$CONTRACT_SQL" > "$STAGE/contract-again.txt" \
  || fail "the contract query failed on the second read"
cmp -s "$STAGE/contract-lines.txt" "$STAGE/contract-again.txt" \
  || fail "the contract changed while the evidence was taken"

mv "$STAGE/contract-lines.txt" "$OUT/contract-lines.txt"
mv "$STAGE/contract.txt" "$OUT/contract.txt"
mv "$STAGE/effective-schema.sql" "$OUT/effective-schema.sql"
echo "effective-schema.sql: $(wc -l < "$OUT/effective-schema.sql" | tr -d ' ') lines"

digest() { { shasum -a 256 "$1" 2>/dev/null || sha256sum "$1"; } | cut -d' ' -f1; }
SHA=${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}
IDENT_DIGEST=$(printf '%s' "$BEFORE" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)
cat > "$STAGE/manifest.json" <<MANIFEST
{
  "target": "${LABEL:-default}",
  "database": "$DBNAME",
  "server_version_num": "$SERVER_NUM",
  "identity_sha256": "$IDENT_DIGEST",
  "schemas": ["public"],
  "source_sha": "$SHA",
  "run_id": "${GITHUB_RUN_ID:-local}",
  "contract_sha256": "$(digest "$OUT/contract.txt")",
  "effective_schema_sha256": "$(digest "$OUT/effective-schema.sql")"
}
MANIFEST
mv "$STAGE/manifest.json" "$OUT/manifest.json"

if [ ! -s "$COMMITTED" ] || ! grep -qv '^#' "$COMMITTED"; then
  fail "$COMMITTED is empty — download this run's quality-database artifact and commit report/contract.txt as $COMMITTED"
fi

if ! diff -u <(grep -v '^#' "$COMMITTED") <(grep -v '^#' "$OUT/contract.txt"); then
  fail "$COMMITTED is not what the migrations build — the diff above is the review; copy the + side into the file (keep its header)"
fi
echo "contract: committed file equals the replay"
