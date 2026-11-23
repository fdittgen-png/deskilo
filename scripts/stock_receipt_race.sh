#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4171 (A) -- a delivery is put away once. Two sessions each put away 18 of
# the 24 pieces a delivery brought: the put-away locks the receipt line before
# it counts what was already put away, so the second waits for the first and
# is then refused (over_allocated): 18 are on hand, one allocation exists,
# and the winner replayed under its request id answers without writing again
# while a changed payload under that id is refused.
# A holder that never took its lock or a contender that never waited fails
# the script: nothing here can pass empty. A single pgTAP transaction cannot
# show a race, so each contender is its own psql process on CI's disposable
# database. Fresh ids per run; the cleanup removes the business.
set -euo pipefail
url=${1:?usage: stock_receipt_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
owner=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  if [[ -n "${ws:-}" ]]; then
    psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.workspaces where id = '$ws';
SQL
      echo "::warning::stock receipt race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@receipt-race.test', '', now(), now(), now());
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Receipt race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true}'
 where id = :'ws';
select id as me from public.members where workspace_id = :'ws' and user_id = '$owner' \gset
insert into public.suppliers (workspace_id, supplier_number, name) values (:'ws', 'S-1', 'Race supplier') returning id as sup \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race water', 100, true, 'piece', 'none', true) returning id as item \gset
insert into public.purchase_orders (workspace_id, year, number, supplier_id, state, currency, created_by_member_id)
values (:'ws', 2026, 1, :'sup', 'draft', 'EUR', :'me') returning id as ord \gset
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, quantity, unit, unit_price_cents)
values (:'ws', :'ord', 1, :'item', 24, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where id = :'ord';
select id as main from public.stock_locations where workspace_id = :'ws' and code = 'MAIN' \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.record_purchase_order_receipt_v1(:'ws', :'ord', 1, current_date,
  '[{"line_no": 1, "quantity": 24}]'::jsonb, '', gen_random_uuid());
reset role;
commit;
select id as receipt from public.purchase_order_receipts where order_id = :'ord' \gset
\echo :ws :receipt :item :main
SQL
)
read -r ws receipt item main <<<"$fixture"
for v in "$ws" "$receipt" "$item" "$main"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
on_hand() { q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$item' and location_id = '$main'"; }
allocations() { q "select count(*) || '/' || coalesce(sum(entered_quantity), 0)::int from public.stock_receipt_allocations where receipt_id = '$receipt'"; }
expect "the fixture: a delivery of 24, nothing put away" "$(on_hand)/$(allocations)" "0/0/0"
# putaway REQUEST QUANTITY
putaway() {
  echo "$as_owner select 'put away' from (select public.put_away_receipt_v1('$ws', '$receipt', '$1', jsonb_build_array(jsonb_build_object('line_no', 1, 'quantity', $2, 'location_id', '$main')))) x;"
}
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
win=$(uid); lose=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder" 2>&1 <<SQL &
begin;
$(putaway "$win" 18)
reset role;
\! touch '$scratch/ready'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready"
PGAPPNAME="receipt-race" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender" 2>&1 <<SQL &
begin;
$(putaway "$lose" 18)
commit;
SQL
contender=$!
wait_lock "receipt-race"
wait "$holder"
wait "$contender" || true
grep -qx 'put away' "$scratch/holder" || { echo "::error::the holder did not put away" >&2; cat "$scratch/holder" >&2; exit 1; }
grep -q "over_allocated" "$scratch/contender" || {
  echo "::error::the second put-away was not refused as over_allocated" >&2; cat "$scratch/contender" >&2; exit 1
}
expect "18 are on hand, one allocation of 18" "$(on_hand)/$(allocations)" "18/1/18"
expect "the loser left no movement" "$(q "select count(*) from public.stock_movements where request_id = '$lose'")" "0"
before=$(q "select count(*) from public.stock_receipt_allocations where receipt_id = '$receipt'")
q "$(putaway "$win" 18)" >/dev/null
expect "the winner replayed under its request id writes nothing" "$(q "select count(*) from public.stock_receipt_allocations where receipt_id = '$receipt'")" "$before"
refused=$(q "$(putaway "$win" 17)" 2>&1 || true)
grep -q "already used for a different request" <<<"$refused" || {
  echo "::error::a changed payload under the winner's request id was not refused: $refused" >&2; exit 1
}
echo "stock receipt race: two sessions putting away 18 of 24: one wins, the other is refused, the winner replays"
