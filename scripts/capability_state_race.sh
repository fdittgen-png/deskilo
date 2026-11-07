#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3336 (0692) — admission of new work and a change of the capability's state
# serialise: the admission commits before the deactivation, or is refused
# after it. A single pgTAP transaction cannot show a race, so each contender
# is its own psql process on CI's disposable database.
#   (a) a DEACTIVATION held open; a new delivery's admission must WAIT on the
#       capability's lock, then be refused "switched off";
#   (b) an ADMISSION held open (a new delivery prepared, not yet committed); a
#       deactivation must WAIT for it, then apply, and the admitted delivery
#       stays exactly one while the next admission is refused.
# Fresh ids per run; cleanup only warns.
set -euo pipefail
url=${1:?usage: capability_state_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid); site=$(uid); conn=$(uid); d1=$(uid); d2=$(uid); d3=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.accounting_deliveries where workspace_id = '$ws';
delete from public.capability_states where workspace_id = '$ws';
SQL
    echo "::warning::capability state race fixture cleanup failed" >&2
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cap-race@deskilo.test','',now(),now(),now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('$ws', 'Capability race', 'FR', 'EUR', 'Europe/Paris', '$owner',
        '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin) values ('$ws', '$owner', true, true);
insert into public.sites (id, workspace_id, name) values ('$site', '$ws', 'Studio');
insert into public.accounting_connections (id, workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
values ('$conn', '$ws', '$site', 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now());
SQL
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\"}', true); set local role authenticated;"
prepare_sql() {
  echo "select public.record_accounting_delivery('$conn', 'invoice', '$1', date '2026-03-02', 'F-1', date '2026-01-01', date '2026-12-31', repeat('a', 64), 'generated', '{}', '')->>'outcome';"
}
wait_marker() {
  local i=0
  while (( i < 100 )); do [[ -e "$1" ]] && return 0; sleep 0.1; ((i+=1)); done
  echo "::error::holder did not take its lock" >&2; return 1
}
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1; ((i+=1))
  done
  echo "::error::contender did not wait on a lock: $1" >&2; return 1
}
# (a) a deactivation held open; an admission waits and is refused
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/a-holder" 2>&1 <<SQL &
begin;
$as_owner
select 'servicing:' || (public.set_capability_state_v1('$ws', 'accountingConnectors', 'servicing', '') ->> 'changed');
reset role;
\! touch '$scratch/a-ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/a-ready"
PGAPPNAME=cap-race-a psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/a-contender" 2>&1 <<SQL &
$(prepare_sql "$d1")
SQL
b=$!
wait_lock cap-race-a
wait "$a"
wait "$b" || true
grep -qx 'servicing:true' "$scratch/a-holder"
grep -q 'switched off' "$scratch/a-contender"
[[ "$(psql "$url" -X -qAt -c "select count(*) from public.accounting_deliveries where workspace_id = '$ws'")" == 0 ]]
# back to active for the second race
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >/dev/null <<SQL
begin;
$as_owner
select public.set_capability_state_v1('$ws', 'accountingConnectors', 'active', '');
commit;
SQL
# (b) an admission held open; a deactivation waits, then applies
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/b-holder" 2>&1 <<SQL &
begin;
$(prepare_sql "$d2")
\! touch '$scratch/b-ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/b-ready"
PGAPPNAME=cap-race-b psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/b-contender" 2>&1 <<SQL &
begin;
$as_owner
select 'servicing:' || (public.set_capability_state_v1('$ws', 'accountingConnectors', 'servicing', '') ->> 'changed');
commit;
SQL
b=$!
wait_lock cap-race-b
wait "$a"
wait "$b"
grep -qx created "$scratch/b-holder"
grep -qx 'servicing:true' "$scratch/b-contender"
[[ "$(psql "$url" -X -qAt -c "select count(*) from public.accounting_deliveries where workspace_id = '$ws'")" == 1 ]]
psql "$url" -X -qAt -v ON_ERROR_STOP=0 >"$scratch/c" 2>&1 <<SQL || true
$(prepare_sql "$d3")
SQL
grep -q 'switched off' "$scratch/c"
echo "capability state race: an admission commits before the deactivation or is refused after it"
