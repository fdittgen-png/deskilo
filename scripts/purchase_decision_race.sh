#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3070: two connections verify the authorization row locks. Run only on an
# isolated CI replay database: the canonical 341 setup is temporarily committed.
set -euo pipefail
DB_URL=${1:?usage: purchase_decision_race.sh disposable-db-url}
export PGOPTIONS="${PGOPTIONS:-} -c statement_timeout=15000"
WS=00000000-0000-4000-8000-0000000035a3
ACTOR=00000000-0000-4000-8000-0000000035a2
MEMBER=00000000-0000-4000-8000-0000000035a5
BILL=00000000-0000-4000-8000-0000000035a7
OWNER=00000000-0000-4000-8000-0000000035a1
REQUEST=00000000-0000-4000-8000-0000000035cf
DIR=$(mktemp -d)
created=0
cleanup() {
  local cleanup_status=0
  if [ "$created" = 1 ]; then
    psql "$DB_URL" -qX -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL || cleanup_status=1
begin;
delete from public.purchase_requests where workspace_id='$WS';
delete from public.purchase_obligations where workspace_id='$WS';
delete from public.purchase_sources where workspace_id='$WS';
delete from public.purchase_documents where workspace_id='$WS';
delete from public.suppliers where workspace_id='$WS';
alter table public.members disable trigger user;
delete from public.members where workspace_id='$WS';
alter table public.members enable trigger user;
delete from public.workspaces where id='$WS';
delete from auth.users where id in ('$OWNER','$ACTOR');
commit;
SQL
  fi
  rm -rf "$DIR"
  if [ "$cleanup_status" != 0 ]; then echo "::error::race fixture cleanup failed" >&2; fi
  return "$cleanup_status"
}
finish() {
  local rc=$?
  trap - EXIT
  cleanup || rc=1
  exit "$rc"
}
trap finish EXIT
fail() { echo "::error::$*" >&2; exit 1; }
wait_ready() {
  local n=0
  while [ "$n" -lt 100 ]; do
    n=$((n + 1))
    [ -f "$DIR/ready" ] && return 0
    kill -0 "$holder" 2>/dev/null || fail 'holder exited before acquiring lock'
    sleep 0.1
  done
  fail 'holder did not acquire lock'
}
# Derive setup directly from the one canonical pgTAP fixture. The temporary
# transaction is committed only on a disposable CI database for two sessions.
{
  echo 'begin;'
  awk '/^select set_config\('\''request.jwt.claims'\''/{exit} /^begin;$/ || /^select plan\(/{next} {print}' supabase/tests/database/341_purchase_decision_authorization.sql
  echo 'commit;'
} > "$DIR/fixture.sql"
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -f "$DIR/fixture.sql" > "$DIR/fixture.log" 2>&1 || fail 'canonical fixture could not be installed'
created=1
CLAIMS="select set_config('request.jwt.claims','{\"sub\":\"$ACTOR\",\"role\":\"authenticated\"}',false); set role authenticated;"
DECIDE="select public.decide_purchase_v1('$WS','$BILL',1,false,'No','$REQUEST');"
# A revocation holds the workspace row before B's decision starts.
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 > "$DIR/holder.log" 2>&1 <<SQL &
begin;
update public.workspaces set feature_flags=feature_flags || '{"purchases":false}' where id='$WS';
\! touch '$DIR/ready'
select pg_sleep(3);
commit;
SQL
holder=$!
wait_ready
if psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$CLAIMS set lock_timeout='500ms'; $DECIDE" > "$DIR/blocked.log" 2>&1; then
  fail 'decision did not wait for in-flight feature revocation'
fi
grep -q 'lock timeout' "$DIR/blocked.log" || fail 'decision failed for a reason other than lock timeout'
wait "$holder" || fail 'revocation transaction failed'
if psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$CLAIMS $DECIDE" > "$DIR/refused.log" 2>&1; then
  fail 'decision succeeded after feature revocation committed'
fi
grep -q 'purchase decision is not available' "$DIR/refused.log" || fail 'wrong post-revocation refusal'
state=$(psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "select state from public.purchase_documents where id='$BILL'")
[ "$state" = pending ] || fail 'refused decision changed the bill'
# Inverse order: the decision succeeds and holds its authorization rows;
# the competing member revocation must wait until that transaction commits.
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "update public.workspaces set feature_flags=feature_flags || '{\"purchases\":true}' where id='$WS'" >/dev/null
rm -f "$DIR/ready"
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 > "$DIR/holder2.log" 2>&1 <<SQL &
$CLAIMS
begin;
$DECIDE
\! touch '$DIR/ready'
select pg_sleep(3);
commit;
SQL
holder=$!
wait_ready
if psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "set lock_timeout='500ms'; update public.members set status='paused' where id='$MEMBER'" > "$DIR/blocked2.log" 2>&1; then
  fail 'member revocation did not wait for the decision transaction'
fi
grep -q 'lock timeout' "$DIR/blocked2.log" || fail 'member update failed for a reason other than lock timeout'
wait "$holder" || fail 'decision transaction failed'
psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "update public.members set status='paused' where id='$MEMBER'" >/dev/null
if psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$CLAIMS $DECIDE" > "$DIR/replay.log" 2>&1; then
  fail 'replay succeeded after member revocation'
fi
grep -q 'purchase decision is not available' "$DIR/replay.log" || fail 'wrong post-revocation replay refusal'
state=$(psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "select state from public.purchase_documents where id='$BILL'")
[ "$state" = rejected ] || fail 'decision before revocation did not persist'
echo 'purchase authorization: both revocation orderings serialized'
