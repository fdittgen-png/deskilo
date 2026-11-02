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
OWNER=00000000-0000-4000-8000-0000000035a1
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
  touch "$DIR/release"
  if [ -n "${waiter:-}" ] && kill -0 "$waiter" 2>/dev/null; then
    kill "$waiter" 2>/dev/null || true
    wait "$waiter" 2>/dev/null || true
  fi
  if [ -n "${holder:-}" ] && kill -0 "$holder" 2>/dev/null; then
    kill "$holder" 2>/dev/null || true
    wait "$holder" 2>/dev/null || true
  fi
  cleanup || rc=1
  exit "$rc"
}
trap finish EXIT
fail() {
  echo "::error::$*" >&2
  for log in "$DIR"/*.log; do [ ! -f "$log" ] || cat "$log" >&2; done
  exit 1
}
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
wait_for_lock() {
  local n=0 waiting
  while [ "$n" -lt 100 ]; do
    n=$((n + 1))
    waiting=$(psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "select exists(select 1 from pg_stat_activity where application_name='$APP' and wait_event_type='Lock')")
    [ "$waiting" = t ] && return 0
    kill -0 "$waiter" 2>/dev/null || fail 'second session exited before waiting on a lock'
    sleep 0.1
  done
  fail 'second session never waited on a lock'
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
APP="deskilo_3070_race_$$"
CLAIMS="select set_config('request.jwt.claims','{\"sub\":\"$ACTOR\",\"role\":\"authenticated\"}',false); set role authenticated;"

# Each caller supplies the row update that removes an authorization fact.
# pg_stat_activity verifies that the second connection actually waits.
revoke_first() {
  local label=$1 revoke=$2 restore=$3
  local bill=00000000-0000-4000-8000-0000000035a7
  local decide="select public.decide_purchase_v1('$WS','$bill',1,false,'No','$bill');"
  rm -f "$DIR/ready" "$DIR/release"
  psql "$DB_URL" -qX -v ON_ERROR_STOP=1 > "$DIR/holder.log" 2>&1 <<SQL &
begin;
$revoke
\! touch '$DIR/ready'
\! while [ ! -f '$DIR/release' ]; do sleep 0.1; done
commit;
SQL
  holder=$!
  wait_ready
  PGAPPNAME="$APP" psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$CLAIMS $decide" > "$DIR/refused.log" 2>&1 &
  waiter=$!
  wait_for_lock
  touch "$DIR/release"
  wait "$holder" || fail "$label: revocation transaction failed"
  if wait "$waiter"; then
    fail "$label: waiting decision succeeded after revocation"
  fi
  grep -q 'purchase decision is not available' "$DIR/refused.log" || fail "$label: wrong refusal"
  local result
  result=$(psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "select state || ':' || (select count(*) from public.purchase_requests where workspace_id='$WS')::text || ':' || (select count(*) from public.purchase_obligations where workspace_id='$WS')::text from public.purchase_documents where id='$bill'")
  [ "$result" = 'pending:0:0' ] || fail "$label: refusal changed state, requests or obligations: $result"
  psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$restore" >/dev/null
}

decision_first() {
  local label=$1 revoke=$2 restore=$3 bill=$4
  local decide="select public.decide_purchase_v1('$WS','$bill',1,false,'No','$bill');"
  rm -f "$DIR/ready" "$DIR/release"
  psql "$DB_URL" -qX -v ON_ERROR_STOP=1 > "$DIR/holder.log" 2>&1 <<SQL &
$CLAIMS
begin;
$decide
\! touch '$DIR/ready'
\! while [ ! -f '$DIR/release' ]; do sleep 0.1; done
commit;
SQL
  holder=$!
  wait_ready
  PGAPPNAME="$APP" psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$revoke" > "$DIR/revocation.log" 2>&1 &
  waiter=$!
  wait_for_lock
  touch "$DIR/release"
  wait "$holder" || fail "$label: decision transaction failed"
  wait "$waiter" || fail "$label: waiting revocation did not complete"
  if psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$CLAIMS $decide" > "$DIR/refused.log" 2>&1; then
    fail "$label: replay succeeded after revocation"
  fi
  grep -q 'purchase decision is not available' "$DIR/refused.log" || fail "$label: wrong replay refusal"
  local result
  result=$(psql "$DB_URL" -qtAX -v ON_ERROR_STOP=1 -c "select state || ':' || (select count(*) from public.purchase_requests where workspace_id='$WS' and request_id='$bill')::text from public.purchase_documents where id='$bill'")
  [ "$result" = 'rejected:1' ] || fail "$label: decision or replay state is wrong: $result"
  psql "$DB_URL" -qX -v ON_ERROR_STOP=1 -c "$restore" >/dev/null
}

FEATURE_OFF="update public.workspaces set feature_flags=feature_flags || '{\"purchases\":false}' where id='$WS';"
FEATURE_ON="update public.workspaces set feature_flags=feature_flags || '{\"purchases\":true}' where id='$WS';"
PERMISSION_OFF="update public.workspaces set role_permissions='{\"member\":[]}' where id='$WS';"
PERMISSION_ON="update public.workspaces set role_permissions='{\"member\":[\"approveExpenses\"]}' where id='$WS';"
MEMBER_OFF="update public.members set status='paused' where id='$MEMBER';"
MEMBER_ON="update public.members set status='active' where id='$MEMBER';"
revoke_first feature "$FEATURE_OFF" "$FEATURE_ON"
revoke_first permission "$PERMISSION_OFF" "$PERMISSION_ON"
revoke_first membership "$MEMBER_OFF" "$MEMBER_ON"
decision_first feature "$FEATURE_OFF" "$FEATURE_ON" 00000000-0000-4000-8000-0000000035a7
decision_first permission "$PERMISSION_OFF" "$PERMISSION_ON" 00000000-0000-4000-8000-0000000035d1
decision_first membership "$MEMBER_OFF" "$MEMBER_ON" 00000000-0000-4000-8000-0000000035d2
echo 'purchase authorization: feature, permission and membership serialize in both orders'
