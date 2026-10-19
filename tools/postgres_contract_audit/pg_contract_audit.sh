#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# pg_contract_audit.sh -- the effective contract of a PostgreSQL database,
# read from the catalogues of ONE explicit target.
#
#   pg_contract_audit.sh <db url>
#
# It writes, into $AUDIT_OUT_DIR (default ./audit-out, or <dir>/<label>/):
#   contract-lines.txt     one sorted line per routine (identity signature,
#                          kind, definer/invoker, volatility, execute grants
#                          of the inspected roles, a digest of the effective
#                          body), per constraint, per trigger and, when asked
#                          for, per row-level-security policy;
#   contract.txt           the same lines under a header;
#   effective-schema.sql   the readable effective definitions (pg_dump);
#   manifest.json          written LAST, once the contract and the dump agree
#                          on one unchanged target: target label, database,
#                          server version, a digest of the target identity,
#                          schemas, roles, source label, run id, and the
#                          digests of the outputs.
#
# Nothing here knows an application. It is read-only (SELECT on the
# catalogues, pg_dump --schema-only), runs with bash, psql and pg_dump only
# (PostgreSQL 12 or newer on the target), and needs no other runtime.
# A target that cannot be read, that changes while it is read, or that is not
# the database a dump container holds is a FAILURE: no manifest, no accepted
# schema, never an empty "compatible" answer. No connection string or password
# reaches stdout, stderr or a file.
#
# Input (environment; every value is validated, none is trusted):
#   AUDIT_SCHEMAS          comma list of schemas to inspect      (public)
#   AUDIT_ROLES            comma list of roles whose EXECUTE right is shown
#                          on every routine, in that order       (none)
#   AUDIT_POLICIES         1 adds a line per row-level-security policy (0)
#   AUDIT_OUT_DIR          relative output directory, no ".."   (audit-out)
#   AUDIT_TARGET_LABEL     optional safe label ([A-Za-z0-9._-]); outputs go
#                          to <out dir>/<label>/
#   AUDIT_HEADER_FILE      text placed at the top of contract.txt
#   AUDIT_MIN_LINES        refuse a contract with fewer lines    (1)
#   AUDIT_SOURCE_LABEL     what the run describes (a commit, a build); else
#                          GITHUB_SHA, else `git rev-parse HEAD`, else unknown
#   AUDIT_DB_CONTAINER     container of the target, used when the host
#                          pg_dump is older than the server; verified against
#                          the queried database (same name, version and body
#                          digests) before it is dumped
#   AUDIT_CONTAINER_PREFIX prefix of the containers to look through when
#                          none is named                         (none)
#   AUDIT_CONTAINER_USER / AUDIT_CONTAINER_DB   how psql/pg_dump reach the
#                          database inside a container     (postgres/postgres)
#   AUDIT_PRINT_SQL        1 prints the contract query and stops          (0)
#   PSQL_BIN PG_DUMP_BIN DOCKER_BIN   the tools (test stubs)
set -uo pipefail

DB_URL=${1:?usage: pg_contract_audit.sh <db url>}
PSQL=${PSQL_BIN:-psql}
PG_DUMP=${PG_DUMP_BIN:-pg_dump}
DOCKER=${DOCKER_BIN:-docker}
LABEL=${AUDIT_TARGET_LABEL:-}
OUT=${AUDIT_OUT_DIR:-audit-out}
SCHEMAS=${AUDIT_SCHEMAS:-public}
ROLES=${AUDIT_ROLES:-}
POLICIES=${AUDIT_POLICIES:-0}
MIN_LINES=${AUDIT_MIN_LINES:-1}
CONTAINER_PREFIX=${AUDIT_CONTAINER_PREFIX:-}
CONTAINER_USER=${AUDIT_CONTAINER_USER:-postgres}
CONTAINER_DB=${AUDIT_CONTAINER_DB:-postgres}

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

# The inputs that reach SQL or the file system are checked before anything is
# read or written.
[[ "$SCHEMAS" =~ ^[A-Za-z_][A-Za-z0-9_]*(,[A-Za-z_][A-Za-z0-9_]*)*$ ]] \
  || fail "AUDIT_SCHEMAS is not a comma list of plain schema names"
if [ -n "$ROLES" ]; then
  [[ "$ROLES" =~ ^[A-Za-z_][A-Za-z0-9_]*(,[A-Za-z_][A-Za-z0-9_]*)*$ ]] \
    || fail "AUDIT_ROLES is not a comma list of plain role names"
fi
[[ "$MIN_LINES" =~ ^[0-9]+$ ]] || fail "AUDIT_MIN_LINES is not a number"
case "$POLICIES" in 0|1) ;; *) fail "AUDIT_POLICIES is 0 or 1" ;; esac
case "$OUT" in
  /*|*..*) fail "AUDIT_OUT_DIR must be a relative path without '..'" ;;
esac
[[ "$OUT" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "AUDIT_OUT_DIR holds characters that are not plain path characters"

if [ -n "$LABEL" ]; then
  [[ "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || fail "AUDIT_TARGET_LABEL is not a safe label"
fi

# The schema allow-list as SQL, and the role columns of the routine lines.
_q="'"
SCHEMA_ARRAY="array[${_q}${SCHEMAS//,/${_q},${_q}}${_q}]"
SCHEMA_OIDS="(select oid from pg_namespace where nspname = any($SCHEMA_ARRAY))"
SCHEMAS_JSON="[\"${SCHEMAS//,/\",\"}\"]"
ROLES_JSON="[]"
EXEC_CASES=""
if [ -n "$ROLES" ]; then
  ROLES_JSON="[\"${ROLES//,/\",\"}\"]"
  IFS=',' read -r -a _role_list <<< "$ROLES"
  for _r in "${_role_list[@]}"; do
    EXEC_CASES="$EXEC_CASES,
         case when has_function_privilege('$_r', p.oid, 'execute') then '$_r' end"
  done
fi
EXEC_SQL="coalesce(concat_ws(','${EXEC_CASES}), '-')"
[ -n "$ROLES" ] || EXEC_SQL="'-'"

IDENTITY_SQL="select current_database() || '|' || current_setting('server_version_num') || '|' || coalesce((select md5(string_agg(p.oid::regprocedure::text || ':' || md5(p.prosrc), ',' order by p.oid::regprocedure::text)) from pg_proc p where p.pronamespace in $SCHEMA_OIDS), '')"

POLICY_UNION=""
if [ "$POLICIES" = 1 ]; then
  POLICY_UNION="
  union all
  select 'policy ' || schemaname || '.' || tablename || '.' || policyname || ' ' || permissive || ' ' || cmd
    || ' roles:' || array_to_string(roles, ',')
    || ' using:' || coalesce(qual, '-') || ' check:' || coalesce(with_check, '-') as line
  from pg_policies where schemaname = any($SCHEMA_ARRAY)"
fi

CONTRACT_SQL="
with r as (
  select 'routine ' || n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ') -> ' || pg_get_function_result(p.oid)
    || ' | ' || case p.prokind when 'f' then 'function' when 'p' then 'procedure' when 'a' then 'aggregate' else p.prokind::text end
    || ' | ' || case when p.prosecdef then 'definer' else 'invoker' end
    || ' | ' || case p.provolatile when 'i' then 'immutable' when 's' then 'stable' else 'volatile' end
    || ' | exec:' || $EXEC_SQL
    || ' | body:' || left(md5(pg_get_functiondef(p.oid)), 12) as line
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = any($SCHEMA_ARRAY)
), c as (
  select 'constraint ' || conrelid::regclass || '.' || conname || ' ' || pg_get_constraintdef(oid) as line
  from pg_constraint
  where connamespace in $SCHEMA_OIDS and contype in ('c', 'f', 'u', 'p', 'x')
), t as (
  select 'trigger ' || tgrelid::regclass || '.' || tgname || ' ' || pg_get_triggerdef(oid) as line
  from pg_trigger
  where not tgisinternal
    and tgrelid in (select oid from pg_class where relnamespace in $SCHEMA_OIDS)
)
select line from r union all select line from c union all select line from t$POLICY_UNION order by 1"

# AUDIT_PRINT_SQL=1 prints the contract query this configuration runs and
# stops: no connection, no file. A tool that predicts a contract from a
# migration reads its query from here instead of keeping a copy.
if [ "${AUDIT_PRINT_SQL:-0}" = 1 ]; then
  printf '%s\n' "$CONTRACT_SQL"
  exit 0
fi

[ -z "$LABEL" ] || OUT=$OUT/$LABEL
mkdir -p "$OUT"
rm -f "$OUT/manifest.json"

# Everything the script writes is staged beside its destination and
# renamed once both queries and the dump succeeded.
STAGE=$(mktemp -d "$OUT/.stage.XXXXXX") || exit 1
trap 'rm -rf "$STAGE"' EXIT

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
  if [ -n "${AUDIT_HEADER_FILE:-}" ]; then
    cat "$AUDIT_HEADER_FILE" || fail "AUDIT_HEADER_FILE cannot be read"
  else
    echo '# The effective contract of the inspected schemas: one line per routine,'
    echo '# constraint and trigger. Generated; never edited by hand.'
  fi
  cat "$STAGE/contract-lines.txt"
} > "$STAGE/contract.txt"

lines=$(grep -vc '^#' "$STAGE/contract.txt")
[ "$lines" -ge "$MIN_LINES" ] || fail "the contract has only $lines lines — the replay is not what it should be"
echo "contract: $lines lines"

# The readable half: every effective definition, for the reviewer. It is
# taken from the SAME database the queries above described.
DUMP_ARGS=(--schema-only --no-owner --no-privileges --no-comments)
IFS=',' read -r -a _schema_list <<< "$SCHEMAS"
for _s in "${_schema_list[@]}"; do DUMP_ARGS+=("--schema=$_s"); done
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
  if [ -n "${AUDIT_DB_CONTAINER:-}" ]; then
    candidates=("$AUDIT_DB_CONTAINER")
  else
    [ -n "$CONTAINER_PREFIX" ] \
      || fail "no readable dump: pg_dump is older than the server and no database container is named"
    while IFS= read -r c; do
      [ -n "$c" ] && candidates+=("$c")
    done < <("$DOCKER" ps --format '{{.Names}}' 2>/dev/null | grep -E "^${CONTAINER_PREFIX}")
  fi
  [ "${#candidates[@]}" -gt 0 ] \
    || fail "no readable dump: pg_dump is older than the server and no database container is named"
  for c in "${candidates[@]}"; do
    ident=$("$DOCKER" exec "$c" psql -U "$CONTAINER_USER" -d "$CONTAINER_DB" -At -c "$IDENTITY_SQL" 2>/dev/null | head -1)
    [ "$ident" = "$BEFORE" ] && matches+=("$c")
  done
  [ "${#matches[@]}" -eq 1 ] \
    || fail "the dump target is ambiguous or is not the queried database (${#matches[@]} of ${#candidates[@]} containers match)"
  "$DOCKER" exec "${matches[0]}" pg_dump -U "$CONTAINER_USER" -d "$CONTAINER_DB" "${DUMP_ARGS[@]}" \
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
SHA=${AUDIT_SOURCE_LABEL:-${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}}
IDENT_DIGEST=$(printf '%s' "$BEFORE" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)
cat > "$STAGE/manifest.json" <<MANIFEST
{
  "target": "${LABEL:-default}",
  "database": "$DBNAME",
  "server_version_num": "$SERVER_NUM",
  "identity_sha256": "$IDENT_DIGEST",
  "schemas": $SCHEMAS_JSON,
  "roles": $ROLES_JSON,
  "source_sha": "$SHA",
  "run_id": "${GITHUB_RUN_ID:-local}",
  "contract_sha256": "$(digest "$OUT/contract.txt")",
  "effective_schema_sha256": "$(digest "$OUT/effective-schema.sql")"
}
MANIFEST
mv "$STAGE/manifest.json" "$OUT/manifest.json"
