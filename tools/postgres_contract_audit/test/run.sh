#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The audit against a schema that is not an application's: a library. Needs a
# PostgreSQL server and a role that may create a database; nothing else. It
# runs from any directory.
#
#   run.sh <admin db url>      e.g. postgresql://postgres:secret@localhost:5432/postgres
#
# It proves, on a scratch database it creates and drops:
#   1. the contract names both overloads, the invoker and the definer routine,
#      the PUBLIC / role / revoked execute rights, the trigger, the constraints
#      and the policy;
#   2. the same schema built in another order gives the same contract (no OID
#      or creation order leaks in);
#   3. a revoked grant is a different contract (an effective change is seen);
#   4. two databases with the same routine names produce separately
#      identified artifacts;
#   5. an unreadable target and an unsafe output path are failures with no
#      manifest.
# Tools: PSQL_BIN, PG_DUMP_BIN (as the collector).
set -uo pipefail
ADMIN=${1:?usage: run.sh <admin db url>}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AUDIT="$HERE/../pg_contract_audit.sh"
PSQL=${PSQL_BIN:-psql}
WORK=$(mktemp -d)
SUFFIX=$$
DBS=("audit_fixture_a_$SUFFIX" "audit_fixture_b_$SUFFIX")
cleanup() {
  for d in "${DBS[@]}"; do "$PSQL" "$ADMIN" -qAt -c "drop database if exists $d" >/dev/null 2>&1; done
  rm -rf "$WORK"
}
trap cleanup EXIT

url_for() { printf '%s' "${ADMIN%/*}/$1"; }
failures=0
check() { if [ "$2" = ok ]; then echo "ok - $1"; else echo "not ok - $1"; failures=$((failures + 1)); fi; }

for d in "${DBS[@]}"; do
  "$PSQL" "$ADMIN" -qAt -v ON_ERROR_STOP=1 -c "create database $d" >/dev/null || { echo "cannot create $d"; exit 2; }
done
"$PSQL" "$(url_for "${DBS[0]}")" -qAt -v ON_ERROR_STOP=1 < "$HERE/fixture_library.sql" >/dev/null || { echo "fixture A failed"; exit 2; }

audit() { # db label [extra env...]
  local db=$1 label=$2; shift 2
  ( cd "$WORK" && env AUDIT_SCHEMAS=library AUDIT_ROLES=audit_reader,audit_clerk AUDIT_POLICIES=1 \
      AUDIT_OUT_DIR=out AUDIT_TARGET_LABEL="$label" "$@" bash "$AUDIT" "$(url_for "$db")" )
}

audit "${DBS[0]}" a >"$WORK/a.log" 2>&1; rc=$?
[ $rc -eq 0 ] && check "the audit of the fixture succeeds" ok || { check "the audit of the fixture succeeds" no; cat "$WORK/a.log"; }
lines=$WORK/out/a/contract-lines.txt
for pat in \
  'routine library.title_of(p_id integer) -> text | function | invoker | stable | exec:audit_reader' \
  'routine library.title_of(p_id integer, p_upper boolean) -> text' \
  'routine library.lend(p_book integer, p_member text) -> integer | function | definer | volatile | exec:audit_clerk' \
  'trigger library.loans.loans_touch' \
  'constraint library.books.books_copies_check' \
  'policy library.loans.loans_own'; do
  grep -qF "$pat" "$lines" && check "the contract holds: $pat" ok || check "the contract holds: $pat" no
done

# 2. another creation order, the same contract
# Same objects, the routine blocks created in the opposite order (blocks are
# separated by "-- @@" lines; roles and grants, after "-- @@@", stay last).
awk 'BEGIN{n=0; t=0} /^-- @@@$/{t=1; next} /^-- @@$/{n++; next} t{tail=tail $0 "\n"; next} {blk[n]=blk[n] $0 "\n"} END{printf "%s", blk[0]; for(i=n;i>=1;i--) printf "%s", blk[i]; printf "%s", tail}' \
  "$HERE/fixture_library.sql" > "$WORK/reordered.sql"
"$PSQL" "$(url_for "${DBS[1]}")" -qAt -v ON_ERROR_STOP=1 < "$WORK/reordered.sql" >/dev/null 2>"$WORK/reorder.err" \
  || { echo "reordered fixture failed:"; cat "$WORK/reorder.err"; }
audit "${DBS[1]}" b >"$WORK/b.log" 2>&1
cmp -s "$WORK/out/a/contract-lines.txt" "$WORK/out/b/contract-lines.txt" \
  && check "another creation order gives the same contract" ok || check "another creation order gives the same contract" no
grep -q '"database": "audit_fixture_a_' "$WORK/out/a/manifest.json" \
  && grep -q '"database": "audit_fixture_b_' "$WORK/out/b/manifest.json" \
  && check "each target's manifest names its own database" ok || check "each target's manifest names its own database" no

# 3. an effective change is seen
"$PSQL" "$(url_for "${DBS[0]}")" -qAt -v ON_ERROR_STOP=1 -c "revoke execute on function library.lend(integer, text) from audit_clerk" >/dev/null
audit "${DBS[0]}" a2 >"$WORK/a2.log" 2>&1
cmp -s "$WORK/out/a/contract-lines.txt" "$WORK/out/a2/contract-lines.txt" \
  && check "a revoked grant changes the contract" no || check "a revoked grant changes the contract" ok

# 5. failures leave no evidence
audit "no_such_db_$SUFFIX" gone >"$WORK/gone.log" 2>&1; rc=$?
{ [ $rc -ne 0 ] && [ ! -e "$WORK/out/gone/manifest.json" ]; } \
  && check "an unreadable target is a failure with no manifest" ok || check "an unreadable target is a failure with no manifest" no
( cd "$WORK" && AUDIT_OUT_DIR=../escape bash "$AUDIT" "$(url_for "${DBS[0]}")" >"$WORK/esc.log" 2>&1 ); rc=$?
{ [ $rc -ne 0 ] && [ ! -e "$WORK/../escape" ]; } \
  && check "an output path with .. is refused" ok || check "an output path with .. is refused" no
( cd "$WORK" && AUDIT_SCHEMAS="library;drop table x" bash "$AUDIT" "$(url_for "${DBS[0]}")" >"$WORK/inj.log" 2>&1 ); rc=$?
[ $rc -ne 0 ] && check "a schema name that is SQL is refused" ok || check "a schema name that is SQL is refused" no

[ $failures -eq 0 ] && echo "all checks passed" || { echo "$failures check(s) failed"; exit 1; }
