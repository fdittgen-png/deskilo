#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #3510 — two readers record the same settlement at the same moment (the
# on-demand fetch beside a scheduled poll). A single pgTAP transaction cannot
# show a race, so each is its own psql process on CI's disposable database:
# the first records the settlement and holds its transaction open; the second
# must WAIT on the settlement's lock, then answer "unchanged". Afterwards the
# payout and each cost exist once. Fresh ids per run.
set -euo pipefail
url=${1:?usage: settlement_record_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
ws=$(uid); owner=$(uid)
stl="stl_race_$(uid | cut -c1-8)"
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.provider_settlement_costs where workspace_id = '$ws';
delete from public.provider_payouts where workspace_id = '$ws';
SQL
    echo "::warning::settlement race fixture cleanup failed" >&2
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
psql "$url" -X -q -v ON_ERROR_STOP=1 <<SQL
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@settle-race.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values ('$ws', 'Settlement race', 'FR', 'EUR', 'Europe/Paris', '$owner');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values ('$ws', '$owner', true, true, 'active');
SQL
q() { psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "$1"; }
record="select public.record_provider_settlement_v1('$ws', 'mollie', '$stl', 34000, 'EUR', date '2026-03-15', 'paid',
  '[{\"period\":\"2026-03\",\"method\":\"ideal\",\"description\":\"iDEAL\",\"cost_count\":3,\"amount_net_cents\":120},
    {\"period\":\"2026-03\",\"method\":\"creditcard\",\"description\":\"Credit card\",\"cost_count\":1,\"amount_net_cents\":55}]') ->> 'outcome'"
wait_marker() {
  local i=0
  while (( i < 100 )); do [[ -e "$1" ]] && return 0; sleep 0.1; ((i+=1)); done
  echo "::error::holder did not take its lock" >&2; return 1
}
wait_lock() {
  local i=0 result
  while (( i < 100 )); do
    result=$(q "select count(*) from pg_stat_activity where application_name = '$1' and wait_event_type = 'Lock'")
    [[ "$result" != 0 ]] && return 0
    sleep 0.1; ((i+=1))
  done
  echo "::error::contender did not wait on a lock: $1" >&2; return 1
}
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder" 2>&1 <<SQL &
begin;
$record;
\! touch '$scratch/ready'
select pg_sleep(4);
commit;
SQL
a=$!
wait_marker "$scratch/ready"
PGAPPNAME=settlement-race psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender" 2>&1 <<SQL &
$record;
SQL
b=$!
wait_lock settlement-race
wait "$a"
wait "$b"
grep -qx new "$scratch/holder"
if ! grep -qx unchanged "$scratch/contender"; then
  echo "::error::the second reader did not answer unchanged: $(cat "$scratch/contender")" >&2
  exit 1
fi
payouts=$(q "select count(*) from public.provider_payouts where workspace_id = '$ws' and payout_id = '$stl'")
costs=$(q "select count(*) from public.provider_settlement_costs where workspace_id = '$ws' and settlement_id = '$stl'")
if [[ "$payouts$costs" != 12 ]]; then
  echo "::error::settlement $stl: $payouts payout(s) and $costs cost row(s), expected 1 and 2" >&2
  exit 1
fi
echo "settlement race: one reader books, the other answers unchanged; the costs exist once"
