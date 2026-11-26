#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4492 (row 2; 0976) -- goods of one counter sale taken back by both doors, at once. The business received 8 mugs and
# sold 4 on each of two receipts; each sale is credited in full by a correction. (A) The holder takes one mug of the first
# sale back by the stock door (`stock_return_v1`) and keeps its transaction open; the contender takes the four of the
# correction back at the counter (`counter_goods_return_v1`) and WAITS (it locks the item's row before it reads what is
# still out), then is refused: three are left, not four (DKL08 already_back). It then takes those three back: four back
# for four sold. (B) The holder takes the four of the second sale back at the counter and keeps its transaction open; the
# contender asks the stock door for one of them and WAITS, then is refused (DKG17: nothing can still be reversed). All 8
# are on hand again and the customer holds none: nothing came back twice. A holder that never took its lock, or a
# contender that never waited, fails the script: nothing here can pass empty. A single pgTAP transaction cannot show a
# race, so each contender is its own psql process on CI's disposable database. Fresh ids per run; the cleanup removes the
# business.
set -euo pipefail
url=${1:?usage: counter_return_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
owner=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  if [[ -n "${ws:-}" ]]; then
    psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.workspaces where id = '$ws';
SQL
      echo "::warning::counter return race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@counter-race.test', '', now(), now(), now());
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Counter return race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
         || '{"invoicing": true, "standaloneInvoicing": true, "services": true, "counterReceipts": true, "stockManagement": true, "stockReturns": true}',
       vat_regime = 'vat_registered'
 where id = :'ws';
insert into public.vat_rates (workspace_id, label, percent, category, is_default, group_key)
select :'ws', 'Standard', 20, 'S', true, 'standard'
 where not exists (select 1 from public.vat_rates where workspace_id = :'ws' and is_default);
insert into public.setting_values (scope, workspace_id, key, value)
values ('workspace', :'ws', 'counter.fiscal_obligation', '"none"'::jsonb) on conflict do nothing;
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race mug', 1000, true, 'piece', 'none', true) returning id as item \gset
select id as main from public.stock_locations where workspace_id = :'ws' and code = 'MAIN' \gset
select id as supplier from public.stock_locations where workspace_id = :'ws' and kind = 'supplier' \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'item', 'quantity', 8, 'from', :'supplier', 'to', :'main')), 'receipt');
select public.counter_receipt_draft_v1(:'ws', gen_random_uuid(), null, null, jsonb_build_object('source_ref', 'race-1', 'lines',
  jsonb_build_array(jsonb_build_object('item_id', :'item', 'quantity', '4', 'supply', 'goods')))) as d1 \gset
select public.counter_receipt_draft_v1(:'ws', gen_random_uuid(), null, null, jsonb_build_object('source_ref', 'race-2', 'lines',
  jsonb_build_array(jsonb_build_object('item_id', :'item', 'quantity', '4', 'supply', 'goods')))) as d2 \gset
select :'d1'::jsonb ->> 'receipt_id' as one \gset
select :'d2'::jsonb ->> 'receipt_id' as two \gset
select public.counter_receipt_finalize_v1(:'ws', gen_random_uuid(), :'one', (:'d1'::jsonb ->> 'revision')::int,
  jsonb_build_array(jsonb_build_object('kind', 'cash', 'amount_minor', (:'d1'::jsonb #>> '{totals,gross_minor}')::bigint)));
select public.counter_receipt_finalize_v1(:'ws', gen_random_uuid(), :'two', (:'d2'::jsonb ->> 'revision')::int,
  jsonb_build_array(jsonb_build_object('kind', 'cash', 'amount_minor', (:'d2'::jsonb #>> '{totals,gross_minor}')::bigint)));
reset role;
commit;
select id as line_one from public.counter_receipt_lines where receipt_id = :'one' and line_no = 1 \gset
select id as line_two from public.counter_receipt_lines where receipt_id = :'two' and line_no = 1 \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.counter_receipt_correct_v1(:'ws', gen_random_uuid(), :'one', jsonb_build_object('lines',
  jsonb_build_array(jsonb_build_object('corrects_line_id', :'line_one', 'quantity', '4')))) ->> 'receipt_id' as corr_one \gset
select public.counter_receipt_correct_v1(:'ws', gen_random_uuid(), :'two', jsonb_build_object('lines',
  jsonb_build_array(jsonb_build_object('corrects_line_id', :'line_two', 'quantity', '4')))) ->> 'receipt_id' as corr_two \gset
reset role;
commit;
select id as cline_one from public.counter_receipt_lines where receipt_id = :'corr_one' and line_no = 1 \gset
select id as cline_two from public.counter_receipt_lines where receipt_id = :'corr_two' and line_no = 1 \gset
\echo :ws :item :main :one :two :corr_one :corr_two :cline_one :cline_two
SQL
)
read -r ws item main one two corr_one corr_two cline_one cline_two <<<"$fixture"
for v in "$ws" "$item" "$main" "$one" "$two" "$corr_one" "$corr_two" "$cline_one" "$cline_two"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
balance() { q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$item' and location_id = '$main'"; }
at_customer() {
  q "select coalesce(sum(b.quantity), 0)::int from public.stock_balances b join public.stock_locations l on l.id = b.location_id where b.item_id = '$item' and l.kind = 'customer'"
}
sale_of() { q "select id from public.stock_movements where counter_receipt_id = '$1' and reason = 'sale'"; }
# what the one record says came back of a sale, by whichever door
back_for() { q "select coalesce(sum(quantity), 0)::int from public.stock_reversals where source_movement_id = '$1'"; }
expect "the fixture: 8 mugs received, 4 sold on each of two receipts" "$(balance)/$(at_customer)" "0/8"
sale_one=$(sale_of "$one")
sale_two=$(sale_of "$two")
# stock_door SALE: one mug of a sale, by the stock door
stock_door() {
  echo "$as_owner select 'returned ' || (public.stock_return_v1('$ws', '$(uid)', '$(uid)', 'customer', jsonb_build_array(jsonb_build_object('return_line_id', '$(uid)', 'source_movement_id', '$1', 'quantity', '1', 'location', '$main'))) ->> 'kind');"
}
# counter CORRECTION LINE QUANTITY: goods of a correction's line, taken back at the counter
counter() {
  echo "$as_owner select 'taken back ' || (public.counter_goods_return_v1('$ws', '$(uid)', '$1', jsonb_build_array(jsonb_build_object('corrects_line_id', '$2', 'quantity', '$3'))) ->> 'movements');"
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

# (A) the stock door holds, the counter waits and is told what is left
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder_a" 2>&1 <<SQL &
begin;
$(stock_door "$sale_one")
reset role;
\! touch '$scratch/ready_a'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready_a"
PGAPPNAME="counter-return-race-a" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender_a" 2>&1 <<SQL &
begin;
$(counter "$corr_one" "$cline_one" 4)
commit;
SQL
contender=$!
wait_lock "counter-return-race-a"
wait "$holder"
wait "$contender" || true
grep -qx "returned customer" "$scratch/holder_a" || { echo "::error::the holder did not take the mug back" >&2; cat "$scratch/holder_a" >&2; exit 1; }
grep -q '"left": "3".*"reason": "already_back"' "$scratch/contender_a" || {
  echo "::error::the counter was not told that three are left (DKL08 already_back)" >&2; cat "$scratch/contender_a" >&2; exit 1
}
expect "(A) one came back by the stock door, and the counter took back none of the four it asked for" "$(back_for "$sale_one")/$(balance)" "1/1"
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/after_a" 2>&1 <<SQL || { echo "::error::the three that are left did not come back at the counter" >&2; cat "$scratch/after_a" >&2; exit 1; }
begin;
$(counter "$corr_one" "$cline_one" 3)
commit;
SQL
grep -qx "taken back 1" "$scratch/after_a" || { echo "::error::the counter did not take the three back" >&2; cat "$scratch/after_a" >&2; exit 1; }
expect "(A) then the three that are left come back at the counter: four for four sold" "$(back_for "$sale_one")/$(balance)" "4/4"

# (B) the counter holds, the stock door waits and is refused
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder_b" 2>&1 <<SQL &
begin;
$(counter "$corr_two" "$cline_two" 4)
reset role;
\! touch '$scratch/ready_b'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready_b"
PGAPPNAME="counter-return-race-b" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender_b" 2>&1 <<SQL &
begin;
$(stock_door "$sale_two")
commit;
SQL
contender=$!
wait_lock "counter-return-race-b"
wait "$holder"
wait "$contender" || true
grep -qx "taken back 1" "$scratch/holder_b" || { echo "::error::the holder did not take the four back" >&2; cat "$scratch/holder_b" >&2; exit 1; }
grep -q "can still be reversed" "$scratch/contender_b" || {
  echo "::error::the stock door's return of goods already back was not refused (DKG17)" >&2; cat "$scratch/contender_b" >&2; exit 1
}
expect "(B) the counter brought back four, the stock door nothing" "$(back_for "$sale_two")" "4"
expect "all 8 are on hand and the customer holds none" "$(balance)/$(at_customer)" "8/0"
echo "counter return race: the counter and the stock door wait for each other on one sale, and nothing comes back twice"
