#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4170 (A) -- one authoritative stock path under concurrency.
#   (A) two OPPOSING multi-item transfers: one moves X then Y from MAIN to a
#       shelf inside it and holds its transaction open; the other moves Y then X
#       back. Every item of a request is locked in id order first, so the
#       second WAITS on a lock and then completes: no deadlock, both succeed,
#       and each item's total over the two places is unchanged.
#   (B) two sessions each taking 3 of the last 4: the second waits, then is
#       refused (DKG03); 1 is left and exactly one movement exists.
#   (D) two put-away sessions each allocate most (4 of 5) of one receipt line:
#       the second waits for the first's lock on the line, then is refused as
#       over-allocated; 4 are in stock, one allocation exists.
#   (E) two sessions each take 2 of an item with a reorder point of 8 at 10 on
#       hand: the second waits for the item, and one alert (not two) exists.
#   (C) a legacy booking confirmation (the bridge) against a customer return of
#       the same item, in both orders: the bridge takes the item's row first like
#       every stock command, so neither order deadlocks and the stock adds up:
#       return holds -> the confirmation waits, then takes what the return put
#       back; confirmation holds -> the return waits, then puts its unit back.
#   (F) two sessions each return 6 of a sale of 10 under distinct return ids: the
#       second waits for the first's lock on the sale's movement row, then is
#       refused (DKG17, 4 left to reverse); 6 are returned, one reversal exists.
#   (G) two sessions apply the same count (7 observed, 10 on hand) under different
#       request ids: the second waits for the first's lock on the item, then
#       answers the same result; exactly one adjustment of 3 exists.
#   (H) two runs of the cycle count job at once for a plan that is due: the second
#       skips the plan the first holds (it does not wait), and exactly one task,
#       with its lines, exists.
#   (H2) the last two lines of a task, on different items, counted at once: the
#       second waits for the task's lock, and the task is closed (complete), not
#       left open with nothing pending.
#   (I) a group is saved while one of its items is overridden, then while it is moved to another group:
#       the second command waits for the group's lock and is refused as stale (DKG10); no deadlock, and
#       the saved value is the one that stands.
#   (J) two sessions bind one tag code to two items: the second waits for the code's lock and
#       is refused (DKG22); one active tag, on the first item.
#   (K) a receipt naming a new piece's tag and a bind of the same code: the bind waits for the code's lock and
#       is refused (DKG22); one tag, on the piece.
#   (L) two put-aways of one receipt line naming 3 tags each of the 4 delivered piece by piece: the second
#       waits for the line's lock and is refused as over-allocated; one set of 3 pieces.
#   (M) two operators finalize one counter draft under different request ids: the second waits for the receipt's lock
#       and is refused (DKL04); one number, one tender.
#   (N) two refunds of one correction at once: the second waits for the correction's lock and is refused; one refund.
#   (O) a card authorization answered while the sale is finalized: the finalize waits, then settles with the accepted tender.
#   (P) two sessions open one till at once: one session, the other refused (DKL12).
#   (Q) a sale finalized and the close of its session at once: the close waits for the sale and counts it.
# A holder that never took its lock, or a contender that never waited, fails the
# script: nothing here can pass empty. A single pgTAP transaction cannot show a
# race, so each contender is its own psql process on CI's disposable database.
set -euo pipefail
url=${1:?usage: stock_transfer_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
owner=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  if [[ -n "${ws:-}" ]]; then
    psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.workspaces where id = '$ws';
SQL
      echo "::warning::stock transfer race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@transfer-race.test', '', now(), now(), now());
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Transfer race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"services": true, "stockManagement": true, "stockTakeOut": true, "stockReorder": true, "stockReturns": true, "stockCounts": true, "stockCycleCounts": true, "stockReceiving": true, "purchases": true, "purchaseOrders": true}' where id = :'ws';
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race X', 100, true, 'piece', 'none', true) returning id as x \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race Y', 100, true, 'piece', 'none', true) returning id as y \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race Z', 100, true, 'piece', 'none', true) returning id as z \gset
select id as main from public.stock_locations where workspace_id = :'ws' and code = 'MAIN' \gset
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values (:'ws', 'shelf', 'SHELF', 'Shelf', :'main') returning id as shelf \gset
select id as supplier from public.stock_locations where workspace_id = :'ws' and kind = 'supplier' \gset
select id as loss from public.stock_locations where workspace_id = :'ws' and kind = 'loss' \gset
select id as customer from public.stock_locations where workspace_id = :'ws' and kind = 'customer' \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race W', 100, true, 'piece', 'none', true) returning id as w \gset
select id as member from public.members where workspace_id = :'ws' and user_id = '$owner' \gset
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature)
values (:'ws', :'member', :'member', 'RACE-1', 'Race', '[]'::jsonb, 0, 'EUR', 'Member', 'Race', 'Issuer', 'race') returning id as inv \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'x', 'quantity', 10, 'from', :'supplier', 'to', :'main'),
  jsonb_build_object('item_id', :'y', 'quantity', 10, 'from', :'supplier', 'to', :'main'),
  jsonb_build_object('item_id', :'x', 'quantity', 4, 'from', :'supplier', 'to', :'shelf'),
  jsonb_build_object('item_id', :'y', 'quantity', 4, 'from', :'supplier', 'to', :'shelf'),
  jsonb_build_object('item_id', :'z', 'quantity', 4, 'from', :'supplier', 'to', :'shelf'),
  jsonb_build_object('item_id', :'w', 'quantity', 2, 'from', :'supplier', 'to', :'main')), 'receipt');
-- the charges are recorded while 2 are there (a charge of more than is on hand is refused at once);
-- one unit is then written off, so the race starts with 1 on hand and two charges waiting
select public.record_service_charge(:'ws', :'member', :'w', 2);
select public.record_service_charge(:'ws', :'member', :'w', 1);
select public.stock_loss_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'w', 'quantity', 1, 'from', :'main', 'to', :'loss')));
reset role;
commit;
-- (D) a delivery of 5 pieces, recorded; (E) an item with 10 at MAIN and a reorder point of 8
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race P', 100, true, 'piece', 'none', true) returning id as p \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race R', 100, true, 'piece', 'none', true) returning id as r \gset
insert into public.suppliers (workspace_id, supplier_number, name) values (:'ws', 'S-RACE', 'Race Co') returning id as sup \gset
insert into public.purchase_orders (workspace_id, year, number, supplier_id, state, currency, created_by_member_id)
values (:'ws', 2026, 1, :'sup', 'draft', 'EUR', :'member') returning id as ord \gset
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents)
values (:'ws', :'ord', 1, :'p', '', 5, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where id = :'ord';
select revision as ordrev from public.purchase_orders where id = :'ord' \gset
-- the business's own day, not the session's: they differ for a few hours a day (#4384)
select public.workspace_today(:'ws') as today \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.record_purchase_order_receipt_v1(:'ws', :'ord', :ordrev, :'today'::date, '[{"line_no": 1, "quantity": 5}]'::jsonb, 'dock', gen_random_uuid());
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'r', 'quantity', 10, 'from', :'supplier', 'to', :'main')), 'receipt');
select public.save_stock_reorder_point_v1(:'ws', null, null, gen_random_uuid(),
  jsonb_build_object('item_id', :'r', 'site_id', :'main', 'reorder_point', '8'));
reset role;
commit;
select id as rcpt from public.purchase_order_receipts where order_id = :'ord' \gset
-- (F) an item received (20) and 10 of it sold on the invoice: the sale is the movement the returns reverse
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race Q', 100, true, 'piece', 'none', true) returning id as q \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'q', 'quantity', 20, 'from', :'supplier', 'to', :'main')), 'receipt');
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'q', 'quantity', 10, 'from', :'main', 'to', :'customer')), 'sale', null,
  jsonb_build_object('invoice_id', :'inv'));
reset role;
commit;
select id as sale from public.stock_movements where workspace_id = :'ws' and item_id = :'q' and reason = 'sale' \gset
-- (G) an item with 10 at MAIN and a count of 7 recorded for it
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race C', 100, true, 'piece', 'none', true) returning id as c \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race E1', 100, true, 'piece', 'none', true) returning id as e1 \gset
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race E2', 100, true, 'piece', 'none', true) returning id as e2 \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'c', 'quantity', 10, 'from', :'supplier', 'to', :'main')), 'receipt');
select public.stock_count_record_v1(:'ws', gen_random_uuid(), gen_random_uuid(),
  jsonb_build_object('item_id', :'c', 'location_id', :'main'), '7', 'race') ->> 'count_id' as cnt \gset
-- (H) a plan that is due today, in the own day of the business, over the same item
select public.stock_count_plan_save_v1(:'ws', gen_random_uuid(), gen_random_uuid(), jsonb_build_object('name', 'Race plan', 'scope_kind', 'items',
  'item_ids', jsonb_build_array(:'c'), 'next_due_on', (now() at time zone 'Europe/Paris')::date)) ->> 'plan_id' as plan \gset
-- (H2) two items of 5 at MAIN and a plan due today over both: its task has two lines on different items
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'e1', 'quantity', 5, 'from', :'supplier', 'to', :'main'),
  jsonb_build_object('item_id', :'e2', 'quantity', 5, 'from', :'supplier', 'to', :'main')), 'receipt');
select public.stock_count_plan_save_v1(:'ws', gen_random_uuid(), gen_random_uuid(), jsonb_build_object('name', 'Race plan two', 'scope_kind', 'items',
  'item_ids', jsonb_build_array(:'e1', :'e2'), 'next_due_on', (now() at time zone 'Europe/Paris')::date)) ->> 'plan_id' as plan2 \gset
reset role;
commit;
select id as ev1 from public.events where workspace_id = :'ws' and type = 'service_charge' and (payload ->> 'quantity')::int = 2 \gset
select id as ev2 from public.events where workspace_id = :'ws' and type = 'service_charge' and (payload ->> 'quantity')::int = 1 \gset
\echo :ws :x :y :z :main :shelf :loss :customer :w :inv :ev1 :ev2 :supplier :p :r :rcpt :q :sale :c :cnt :plan :e1 :e2 :plan2
SQL
)
read -r ws x y z main shelf loss customer w inv ev1 ev2 supplier p r rcpt q sale c cnt plan e1 e2 plan2 <<<"$fixture"
# section (B) reuses the name c for a request id: the counted item keeps its own name
count_item=$c
for v in "$ws" "$x" "$y" "$z" "$main" "$shelf" "$loss" "$customer" "$w" "$inv" "$ev1" "$ev2" "$supplier" "$p" "$r" "$rcpt" "$q" "$sale" "$c" "$cnt" "$plan" "$e1" "$e2" "$plan2"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
total() { q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$1' and location_id in ('$main', '$shelf')"; }
# wait_marker MARKER HOLDER-LOG: the holder's own output is shown when it never took its lock
wait_marker() {
  local i=0
  while (( i < 100 )); do [[ -e "$1" ]] && return 0; sleep 0.1; ((i+=1)); done
  echo "::error::holder did not take its lock; its output: $(tr '\n' ' ' < "$2")" >&2
  return 1
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
# transfer REQUEST FROM TO ITEM-A ITEM-B QTY: two items in the order given
transfer() {
  echo "$as_owner select 'moved' from (select public.stock_transfer_v1('$ws', '$1', jsonb_build_array(
    jsonb_build_object('item_id', '$4', 'quantity', '$6', 'from', '$2', 'to', '$3'),
    jsonb_build_object('item_id', '$5', 'quantity', '$6', 'from', '$2', 'to', '$3')))) t;"
}
expect "the fixture: 14 of each over the two places" "$(total "$x")/$(total "$y")" "14/14"

# (A) opposing multi-item transfers
a=$(uid); b=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder" 2>&1 <<SQL &
begin;
$(transfer "$a" "$main" "$shelf" "$x" "$y" 2)
reset role;
\! touch '$scratch/ready'
select pg_sleep(4);
commit;
SQL
holder=$!
wait_marker "$scratch/ready" "$scratch/holder"
PGAPPNAME="transfer-race-opposing" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender" 2>&1 <<SQL &
begin;
$(transfer "$b" "$shelf" "$main" "$y" "$x" 1)
commit;
SQL
contender=$!
wait_lock "transfer-race-opposing"
wait "$holder"
wait "$contender" || true
grep -qx moved "$scratch/holder" || { echo "::error::the holder did not move" >&2; cat "$scratch/holder" >&2; exit 1; }
grep -qx moved "$scratch/contender" || { echo "::error::the opposing transfer did not complete (a deadlock?)" >&2; cat "$scratch/contender" >&2; exit 1; }
expect "opposing transfers: each item's total is unchanged" "$(total "$x")/$(total "$y")" "14/14"
expect "opposing transfers: four movements, none lost" "$(q "select count(*) from public.stock_movements where request_id in ('$a', '$b')")" "4"

# (B) two sessions taking 3 of the last 4 of Z, at the shelf
take() {
  echo "$as_owner select 'taken' from (select public.stock_move_v1('$ws', '$1', jsonb_build_array(jsonb_build_object('item_id', '$z', 'quantity', 3, 'from', '$2', 'to', '$loss')), 'loss')) t;"
}
c=$(uid); d=$(uid)
first_place=$shelf
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder2" 2>&1 <<SQL &
begin;
$(take "$c" "$first_place")
reset role;
\! touch '$scratch/ready2'
select pg_sleep(4);
commit;
SQL
holder2=$!
wait_marker "$scratch/ready2" "$scratch/holder2"
PGAPPNAME="transfer-race-last" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender2" 2>&1 <<SQL &
begin;
$(take "$d" "$first_place")
commit;
SQL
contender2=$!
wait_lock "transfer-race-last"
wait "$holder2"
wait "$contender2" || true
grep -qx taken "$scratch/holder2" || { echo "::error::the holder did not take" >&2; cat "$scratch/holder2" >&2; exit 1; }
grep -q "not that much on hand" "$scratch/contender2" || { echo "::error::the second take was not refused" >&2; cat "$scratch/contender2" >&2; exit 1; }
expect "exactly one of the two takes made a movement" "$(q "select count(*) from public.stock_movements where request_id in ('$c', '$d')")" "1"
# (C) the booking bridge against a customer return of the same item
wbal() { q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$w' and location_id = '$main'"; }
sold() { q "select coalesce(sum(quantity), 0)::int from public.stock_movements where item_id = '$w' and reason = 'sale' and request_id = '$1'"; }
expect "(C) the fixture: 1 of W at MAIN" "$(wbal)" "1"
# the return of one unit (from the customer, against the invoice), as its own request
give_back() {
  echo "$as_owner select 'returned' from (select public.stock_move_v1('$ws', '$1', jsonb_build_array(jsonb_build_object('item_id', '$w', 'quantity', 1, 'from', '$customer', 'to', '$main')), 'return_in', null, jsonb_build_object('invoice_id', '$inv'))) t;"
}
# (C1) the return holds its transaction open; the confirmation of a charge of 2 waits, then takes both units
r1=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder3" 2>&1 <<SQL &
begin;
$(give_back "$r1")
reset role;
\! touch '$scratch/ready3'
select pg_sleep(4);
commit;
SQL
holder3=$!
wait_marker "$scratch/ready3" "$scratch/holder3"
PGAPPNAME="transfer-race-bridge" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender3" 2>&1 <<SQL &
begin;
update public.events set status = 'confirmed' where id = '$ev1';
commit;
SQL
contender3=$!
wait_lock "transfer-race-bridge"
wait "$holder3"
wait "$contender3" || { echo "::error::the confirmation after the return failed: $(tr '\n' ' ' < "$scratch/contender3")" >&2; exit 1; }
grep -qx returned "$scratch/holder3" || { echo "::error::the return did not complete: $(tr '\n' ' ' < "$scratch/holder3")" >&2; exit 1; }
expect "(C1) the confirmation took the 2 units the return made available: none left" "$(wbal)" "0"
expect "(C1) the confirmation of the charge of 2 took 2 (one movement set)" "$(q "select coalesce(sum(quantity), 0)::int from public.stock_movements where item_id = '$w' and reason = 'sale'")" "2"
# (C2) the confirmation of a charge of 1 holds; the return waits for the item, then puts its unit back
q "$as_owner select public.stock_move_v1('$ws', '$(uid)', jsonb_build_array(jsonb_build_object('item_id', '$w', 'quantity', 1, 'from', '$supplier', 'to', '$main')), 'receipt');" >/dev/null
expect "(C2) the fixture: 1 of W again" "$(wbal)" "1"
r2=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder4" 2>&1 <<SQL &
begin;
update public.events set status = 'confirmed' where id = '$ev2';
\! touch '$scratch/ready4'
select pg_sleep(4);
commit;
SQL
holder4=$!
wait_marker "$scratch/ready4" "$scratch/holder4"
PGAPPNAME="transfer-race-return" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender4" 2>&1 <<SQL &
begin;
$(give_back "$r2")
commit;
SQL
contender4=$!
wait_lock "transfer-race-return"
wait "$holder4" || { echo "::error::the holding confirmation failed: $(tr '\n' ' ' < "$scratch/holder4")" >&2; exit 1; }
wait "$contender4" || { echo "::error::the return after the confirmation failed: $(tr '\n' ' ' < "$scratch/contender4")" >&2; exit 1; }
grep -qx returned "$scratch/contender4" || { echo "::error::the return did not complete: $(tr '\n' ' ' < "$scratch/contender4")" >&2; exit 1; }
expect "(C2) 1 - 1 (the confirmation) + 1 (the return) = 1" "$(wbal)" "1"
# (D) two put-aways of 4 of the 5 received: the second is refused once the first holds them
put_away() {
  echo "$as_owner select 'putaway' from (select public.put_away_receipt_v1('$ws', '$2', '$1', jsonb_build_array(jsonb_build_object('line_no', 1, 'quantity', 4, 'location_id', '$main')))) t;"
}
pa1=$(uid); pa2=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder5" 2>&1 <<SQL &
begin;
$(put_away "$pa1" "$rcpt")
reset role;
\\! touch '$scratch/ready5'
select pg_sleep(4);
commit;
SQL
holder5=$!
wait_marker "$scratch/ready5" "$scratch/holder5"
PGAPPNAME="transfer-race-putaway" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender5" 2>&1 <<SQL &
begin;
$(put_away "$pa2" "$rcpt")
commit;
SQL
contender5=$!
wait_lock "transfer-race-putaway"
wait "$holder5" || { echo "::error::the first put-away failed: $(tr '\n' ' ' < "$scratch/holder5")" >&2; exit 1; }
wait "$contender5" || true
grep -qx putaway "$scratch/holder5" || { echo "::error::the first put-away did not complete: $(tr '\n' ' ' < "$scratch/holder5")" >&2; exit 1; }
grep -q "over_allocated" "$scratch/contender5" || { echo "::error::the second put-away was not refused as over_allocated: $(tr '\n' ' ' < "$scratch/contender5")" >&2; exit 1; }
expect "(D) one allocation of 4 exists" "$(q "select count(*) || '/' || coalesce(sum(inventory_quantity), 0)::int from public.stock_receipt_allocations where receipt_id = '$rcpt'")" "1/4"
expect "(D) 4 of the item are in stock" "$(q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$p' and location_id = '$main'")" "4"

# (E) two sessions each take 2 of the item (10 on hand, the point 8): one alert
rb=$(uid); rc=$(uid)
take_r() {
  echo "$as_owner select 'taken' from (select public.stock_consume_v1('$ws', '$1', jsonb_build_array(jsonb_build_object('item_id', '$r', 'quantity', 2, 'from', '$main', 'to', '$loss')))) t;"
}
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder6" 2>&1 <<SQL &
begin;
$(take_r "$rb")
reset role;
\\! touch '$scratch/ready6'
select pg_sleep(4);
commit;
SQL
holder6=$!
wait_marker "$scratch/ready6" "$scratch/holder6"
PGAPPNAME="transfer-race-reorder" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender6" 2>&1 <<SQL &
begin;
$(take_r "$rc")
commit;
SQL
contender6=$!
wait_lock "transfer-race-reorder"
wait "$holder6" || { echo "::error::the first take failed: $(tr '\n' ' ' < "$scratch/holder6")" >&2; exit 1; }
wait "$contender6" || { echo "::error::the second take failed: $(tr '\n' ' ' < "$scratch/contender6")" >&2; exit 1; }
grep -qx taken "$scratch/contender6" || { echo "::error::the second take did not complete: $(tr '\n' ' ' < "$scratch/contender6")" >&2; exit 1; }
expect "(E) 10 - 2 - 2 = 6 of the item on hand" "$(q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$r' and location_id = '$main'")" "6"
expect "(E) the point was crossed by both and raised exactly one open alert" "$(q "select count(*) from public.events where workspace_id = '$ws' and type = 'stock_low' and payload ->> 'item_id' = '$r' and not (payload ? 'ended')")" "1"
# (F) two sessions each return 6 of the sale of 10, under distinct return ids
return_q() {
  echo "$as_owner select 'returned' from (select public.stock_return_v1('$ws', gen_random_uuid(), '$1', 'customer', jsonb_build_array(jsonb_build_object('return_line_id', '$2', 'source_movement_id', '$sale', 'quantity', '6', 'location', '$main')))) t;"
}
ra=$(uid); rla=$(uid); rb2=$(uid); rlb=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder7" 2>&1 <<SQL &
begin;
$(return_q "$ra" "$rla")
reset role;
\\! touch '$scratch/ready7'
select pg_sleep(4);
commit;
SQL
holder7=$!
wait_marker "$scratch/ready7" "$scratch/holder7"
PGAPPNAME="transfer-race-reversal" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender7" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$(return_q "$rb2" "$rlb")
commit;
SQL
contender7=$!
wait_lock "transfer-race-reversal"
wait "$holder7" || { echo "::error::the first return failed: $(tr '\n' ' ' < "$scratch/holder7")" >&2; exit 1; }
wait "$contender7" || true
grep -qx returned "$scratch/holder7" || { echo "::error::the first return did not complete: $(tr '\n' ' ' < "$scratch/holder7")" >&2; exit 1; }
grep -q "DKG17" "$scratch/contender7" || { echo "::error::the second return was not refused as beyond the sale: $(tr '\n' ' ' < "$scratch/contender7")" >&2; exit 1; }
expect "(F) 6 of the sale were reversed, by one return" "$(q "select count(*) || '/' || coalesce(sum(quantity), 0)::int from public.stock_reversals where source_movement_id = '$sale'")" "1/6"
expect "(F) 20 - 10 + 6 = 16 of the item on hand" "$(q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$q' and location_id = '$main'")" "16"

# (G) two sessions apply the same count of 7 (10 on hand) under different request ids
apply_count() {
  echo "$as_owner select 'decided' || ' ' || (public.stock_count_decide_v1('$ws', '$1', '$cnt', 'apply', 'race') ->> 'state');"
}
ga=$(uid); gb=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder8" 2>&1 <<SQL &
begin;
$(apply_count "$ga")
reset role;
\\! touch '$scratch/ready8'
select pg_sleep(4);
commit;
SQL
holder8=$!
wait_marker "$scratch/ready8" "$scratch/holder8"
PGAPPNAME="transfer-race-count" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender8" 2>&1 <<SQL &
begin;
$(apply_count "$gb")
commit;
SQL
contender8=$!
wait_lock "transfer-race-count"
wait "$holder8" || { echo "::error::the first apply failed: $(tr '\n' ' ' < "$scratch/holder8")" >&2; exit 1; }
wait "$contender8" || { echo "::error::the second apply failed: $(tr '\n' ' ' < "$scratch/contender8")" >&2; exit 1; }
grep -qx "decided applied" "$scratch/holder8" || { echo "::error::the first apply did not apply: $(tr '\n' ' ' < "$scratch/holder8")" >&2; exit 1; }
grep -qx "decided applied" "$scratch/contender8" || { echo "::error::the second apply did not answer the same result: $(tr '\n' ' ' < "$scratch/contender8")" >&2; exit 1; }
expect "(G) one adjustment of 3 exists" "$(q "select count(*) || '/' || coalesce(sum(quantity), 0)::int from public.stock_movements where item_id = '$count_item' and reason = 'adjustment'")" "1/3"
expect "(G) 10 - 3 = 7 of the item on hand" "$(q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$count_item' and location_id = '$main'")" "7"

# (H) two runs of the cycle count job at once for a plan that is due: the second skips the plan the first holds
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder9" 2>&1 <<SQL &
begin;
select 'made ' || public.stock_cycle_counts_due('$ws');
\\! touch '$scratch/ready9'
select pg_sleep(3);
commit;
SQL
holder9=$!
wait_marker "$scratch/ready9" "$scratch/holder9"
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender9" 2>&1 <<SQL
begin;
select 'made ' || public.stock_cycle_counts_due('$ws');
commit;
SQL
wait "$holder9" || { echo "::error::the first run failed: $(tr '\n' ' ' < "$scratch/holder9")" >&2; exit 1; }
# both plans of the fixture business are due: the first run makes their two tasks, the second skips both
grep -qx "made 2" "$scratch/holder9" || { echo "::error::the first run did not make the two tasks: $(tr '\n' ' ' < "$scratch/holder9") | plans (id:active:next_due_on:today:feature): $(q "select string_agg(p.id || ':' || p.active || ':' || p.next_due_on || ':' || public.workspace_today(p.workspace_id) || ':' || public.feature_effective(p.workspace_id, 'stockCycleCounts'), ' ') from public.stock_count_plans p where p.workspace_id = '$ws'") | tuple locks: $(q "select count(*) from pg_locks where locktype = 'tuple'")" >&2; exit 1; }
grep -qx "made 0" "$scratch/contender9" || { echo "::error::the second run did not skip the plan: $(tr '\n' ' ' < "$scratch/contender9")" >&2; exit 1; }
expect "(H) one task with its lines exists for the plan" "$(q "select count(*) || '/' || (select count(*) from public.stock_count_task_lines x join public.stock_count_tasks t2 on t2.id = x.task_id where t2.plan_id = '$plan') from public.stock_count_tasks where plan_id = '$plan'")" "1/1"

# (H2) the two lines of the second plan's task, counted at once
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL
select public.stock_cycle_counts_due('$ws');
SQL
read -r la lb <<<"$(q "select string_agg(x.id::text, ' ' order by x.id) from public.stock_count_task_lines x join public.stock_count_tasks t on t.id = x.task_id where t.plan_id = '$plan2'")"
for v in "$la" "$lb"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::the task of the second plan has no two lines: '$la' '$lb'" >&2; exit 1; }
done
count_line() {
  echo "$as_owner select 'counted ' || (public.stock_cycle_count_line_v1('$ws', gen_random_uuid(), '$1', '5') ->> 'task_state');"
}
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder10" 2>&1 <<SQL &
begin;
$(count_line "$la")
reset role;
\\! touch '$scratch/ready10'
select pg_sleep(4);
commit;
SQL
holder10=$!
wait_marker "$scratch/ready10" "$scratch/holder10"
PGAPPNAME="transfer-race-taskclose" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender10" 2>&1 <<SQL &
begin;
$(count_line "$lb")
commit;
SQL
contender10=$!
wait_lock "transfer-race-taskclose"
wait "$holder10" || { echo "::error::the first count failed: $(tr '\n' ' ' < "$scratch/holder10")" >&2; exit 1; }
wait "$contender10" || { echo "::error::the second count failed: $(tr '\n' ' ' < "$scratch/contender10")" >&2; exit 1; }
expect "(H2) the task is complete, with nothing pending" "$(q "select t.state || '/' || (select count(*) from public.stock_count_task_lines x where x.task_id = t.id and x.state = 'pending') from public.stock_count_tasks t where t.plan_id = '$plan2'")" "complete/0"

# (I) a group is saved while one of its items is overridden, and while it is moved to another group: the
# second command waits for the group's lock, then is refused as stale (DKG10): never a deadlock, and the saved
# value is not overwritten by what the second read before the save.
q "update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{\"stockItemGroups\": true}' where id = '$ws'" >/dev/null
ig1=$(uid); ig2=$(uid)
iitem=$(q "insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values ('$ws', 'Race group item', 100, true, 'piece', 'none', true) returning id" | head -1)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL
begin;
$as_owner
select public.item_group_save_v1('$ws', gen_random_uuid(), '$ig1', 0, '{"name": "Race group", "parameters": {"shelf_life_days": 7}}'::jsonb);
select public.item_group_save_v1('$ws', gen_random_uuid(), '$ig2', 0, '{"name": "Race group two"}'::jsonb);
select public.item_group_assign_v1('$ws', gen_random_uuid(), '$iitem', (select stock_revision from public.services where id = '$iitem'), '$ig1');
commit;
SQL
expect "(I) the item took its group's shelf life" "$(q "select shelf_life_days from public.services where id = '$iitem'")" "7"
irev=$(q "select stock_revision from public.services where id = '$iitem'")
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder11" 2>&1 <<SQL &
begin;
$as_owner
select 'saved ' || (public.item_group_save_v1('$ws', gen_random_uuid(), '$ig1', 1, '{"parameters": {"shelf_life_days": 10}}'::jsonb) ->> 'revision');
reset role;
\\! touch '$scratch/ready11'
select pg_sleep(4);
commit;
SQL
holder11=$!
wait_marker "$scratch/ready11" "$scratch/holder11"
PGAPPNAME="transfer-race-override" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender11" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$as_owner
select public.item_override_save_v1('$ws', gen_random_uuid(), '$iitem', $irev, 'shelf_life_days', 'set', '21'::jsonb);
commit;
SQL
contender11=$!
wait_lock "transfer-race-override"
wait "$holder11" || { echo "::error::the group save failed: $(tr '\n' ' ' < "$scratch/holder11")" >&2; exit 1; }
wait "$contender11" || true
grep -qx "saved 2" "$scratch/holder11" || { echo "::error::the group did not save: $(tr '\n' ' ' < "$scratch/holder11")" >&2; exit 1; }
grep -q "DKG10" "$scratch/contender11" || { echo "::error::the override was not refused as stale: $(tr '\n' ' ' < "$scratch/contender11")" >&2; exit 1; }
expect "(I) the saved shelf life stands, the override was not applied" "$(q "select shelf_life_days || '/' || cardinality(group_overrides) from public.services where id = '$iitem'")" "10/0"
irev=$(q "select stock_revision from public.services where id = '$iitem'")
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder12" 2>&1 <<SQL &
begin;
$as_owner
select 'saved ' || (public.item_group_save_v1('$ws', gen_random_uuid(), '$ig1', 2, '{"parameters": {"shelf_life_days": 12}}'::jsonb) ->> 'revision');
reset role;
\\! touch '$scratch/ready12'
select pg_sleep(4);
commit;
SQL
holder12=$!
wait_marker "$scratch/ready12" "$scratch/holder12"
PGAPPNAME="transfer-race-move" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender12" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$as_owner
select public.item_group_assign_v1('$ws', gen_random_uuid(), '$iitem', $irev, '$ig2');
commit;
SQL
contender12=$!
wait_lock "transfer-race-move"
wait "$holder12" || { echo "::error::the second group save failed: $(tr '\n' ' ' < "$scratch/holder12")" >&2; exit 1; }
wait "$contender12" || true
grep -q "DKG10" "$scratch/contender12" || { echo "::error::the move was not refused as stale: $(tr '\n' ' ' < "$scratch/contender12")" >&2; exit 1; }
expect "(I) the item stays in its group with the saved value" "$(q "select (group_id = '$ig1')::text || '/' || shelf_life_days from public.services where id = '$iitem'")" "true/12"

# (J) two sessions bind the same tag code to two different items: the second waits for the code's lock, then is
# refused (DKG22, bound elsewhere); one active tag exists, on the first item.
q "update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{\"stockTags\": true}' where id = '$ws'" >/dev/null
jitem1=$(q "insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values ('$ws', 'Race tag item one', 100, true, 'piece', 'none', true, 'per_batch') returning id" | head -1)
jitem2=$(q "insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values ('$ws', 'Race tag item two', 100, true, 'piece', 'none', true, 'per_batch') returning id" | head -1)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder13" 2>&1 <<SQL &
begin;
$as_owner
select 'bound ' || (public.stock_tag_bind_v1('$ws', gen_random_uuid(), '{"code": "3074257BF7194E4000001A85", "owner": {"kind": "item", "item_id": "$jitem1"}}'::jsonb) ->> 'owner_kind');
reset role;
\\! touch '$scratch/ready13'
select pg_sleep(4);
commit;
SQL
holder13=$!
wait_marker "$scratch/ready13" "$scratch/holder13"
PGAPPNAME="transfer-race-bind" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender13" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$as_owner
select public.stock_tag_bind_v1('$ws', gen_random_uuid(), '{"code": "3074257BF7194E4000001A85", "owner": {"kind": "item", "item_id": "$jitem2"}}'::jsonb);
commit;
SQL
contender13=$!
wait_lock "transfer-race-bind"
wait "$holder13" || { echo "::error::the first bind failed: $(tr '\n' ' ' < "$scratch/holder13")" >&2; exit 1; }
wait "$contender13" || true
grep -qx "bound item" "$scratch/holder13" || { echo "::error::the first bind did not complete: $(tr '\n' ' ' < "$scratch/holder13")" >&2; exit 1; }
grep -q "DKG22" "$scratch/contender13" || { echo "::error::the second bind was not refused as bound elsewhere: $(tr '\n' ' ' < "$scratch/contender13")" >&2; exit 1; }
expect "(J) one active tag exists for the code, on the first item" "$(q "select count(*) || '/' || bool_and(item_id = '$jitem1')::text from public.stock_tags where workspace_id = '$ws' and state = 'active' and item_id in ('$jitem1', '$jitem2')")" "1/true"

# (K) a receipt that names a new piece's tag, and a bind of the same code to a place: the bind waits for the
# code's lock the receipt holds, then is refused (DKG22, the code is on the piece), never a raw unique violation.
kitem=$(q "insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values ('$ws', 'Race piece item', 100, true, 'piece', 'serial', true, 'per_unit') returning id" | head -1)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder14" 2>&1 <<SQL &
begin;
$as_owner
select 'received ' || jsonb_typeof(public.stock_move_v1('$ws', gen_random_uuid(), '[{"item_id": "$kitem", "quantity": "1", "from": "$supplier", "to": "$main", "units": [{"tag": "E28068940000401561D68B01"}], "new_lot": {"total_cost_minor": 100}}]'::jsonb, 'receipt'));
reset role;
\\! touch '$scratch/ready14'
select pg_sleep(4);
commit;
SQL
holder14=$!
wait_marker "$scratch/ready14" "$scratch/holder14"
PGAPPNAME="transfer-race-piece-bind" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender14" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$as_owner
select public.stock_tag_bind_v1('$ws', gen_random_uuid(), '{"code": "E28068940000401561D68B01", "owner": {"kind": "place", "location_id": "$shelf"}}'::jsonb);
commit;
SQL
contender14=$!
wait_lock "transfer-race-piece-bind"
wait "$holder14" || { echo "::error::the receipt failed: $(tr '\n' ' ' < "$scratch/holder14")" >&2; exit 1; }
wait "$contender14" || true
grep -q "^received" "$scratch/holder14" || { echo "::error::the receipt did not complete: $(tr '\n' ' ' < "$scratch/holder14")" >&2; exit 1; }
grep -q "DKG22" "$scratch/contender14" || { echo "::error::the bind was not refused as bound to the piece: $(tr '\n' ' ' < "$scratch/contender14")" >&2; exit 1; }
expect "(K) the code is on the received piece only" "$(q "select count(*) || '/' || bool_and(owner_kind = 'piece')::text from public.stock_tags where workspace_id = '$ws' and state = 'active' and code = 'E28068940000401561D68B01'")" "1/true"

# (L) two put-aways of the same receipt line, each naming 3 tags of the 4 delivered piece by piece: the second waits
# for the line's lock, then is refused as over-allocated (DKG11); one set of 3 pieces exists, never a second.
psql "$url" -X -qAt -v ON_ERROR_STOP=1 -v ws="$ws" -v member="$(q "select id from public.members where workspace_id = '$ws' and user_id = '$owner'")" >"$scratch/setup15" 2>&1 <<SQL
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode)
values (:'ws', 'Race pieces', 100, true, 'piece', 'serial', true, 'per_unit') returning id as pu \gset
insert into public.purchase_orders (workspace_id, year, number, supplier_id, state, currency, created_by_member_id)
values (:'ws', 2026, 9, (select id from public.suppliers where workspace_id = :'ws' limit 1), 'draft', 'EUR', :'member') returning id as ord2 \gset
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents)
values (:'ws', :'ord2', 1, :'pu', '', 4, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where id = :'ord2';
select revision as ordrev2 from public.purchase_orders where id = :'ord2' \gset
select public.workspace_today(:'ws') as today2 \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.record_purchase_order_receipt_v1(:'ws', :'ord2', :ordrev2, :'today2'::date, '[{"line_no": 1, "quantity": 4}]'::jsonb, 'dock', gen_random_uuid());
reset role;
commit;
select 'receipt ' || id from public.purchase_order_receipts where order_id = :'ord2';
select 'item ' || :'pu';
SQL
rcpt2=$(grep '^receipt ' "$scratch/setup15" | cut -d' ' -f2)
pitem=$(grep '^item ' "$scratch/setup15" | cut -d' ' -f2)
[[ -n "$rcpt2" && -n "$pitem" ]] || { echo "::error::the piece delivery was not set up: $(tr '\n' ' ' < "$scratch/setup15")" >&2; exit 1; }
put_away_units() { # REQUEST TAG-PREFIX
  echo "$as_owner select 'putaway' from (select public.put_away_receipt_v1('$ws', '$rcpt2', '$1', jsonb_build_array(jsonb_build_object('line_no', 1, 'quantity', 3, 'location_id', '$main', 'units', jsonb_build_array(jsonb_build_object('tag', '${2}01'), jsonb_build_object('tag', '${2}02'), jsonb_build_object('tag', '${2}03'))))) ) t;"
}
pb1=$(uid); pb2=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder15" 2>&1 <<SQL &
begin;
$(put_away_units "$pb1" "E28068940000401561D69A")
reset role;
\\! touch '$scratch/ready15'
select pg_sleep(4);
commit;
SQL
holder15=$!
wait_marker "$scratch/ready15" "$scratch/holder15"
PGAPPNAME="transfer-race-putaway-pieces" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender15" 2>&1 <<SQL &
begin;
$(put_away_units "$pb2" "E28068940000401561D69B")
commit;
SQL
contender15=$!
wait_lock "transfer-race-putaway-pieces"
wait "$holder15" || { echo "::error::the first piece put-away failed: $(tr '\n' ' ' < "$scratch/holder15")" >&2; exit 1; }
wait "$contender15" || true
grep -qx putaway "$scratch/holder15" || { echo "::error::the first piece put-away did not complete: $(tr '\n' ' ' < "$scratch/holder15")" >&2; exit 1; }
grep -q "over_allocated" "$scratch/contender15" || { echo "::error::the second piece put-away was not refused as over_allocated: $(tr '\n' ' ' < "$scratch/contender15")" >&2; exit 1; }
expect "(L) three pieces exist, with their tags, once" "$(q "select count(*) || '/' || (select count(*) from public.stock_tags where workspace_id = '$ws' and owner_kind = 'piece' and state = 'active' and item_id = '$pitem') from public.stock_tagged_units where workspace_id = '$ws' and item_id = '$pitem'")" "3/3"

# (M) two operators finalize the same counter draft under different request ids: the second waits for the receipt's
# lock, then is refused (DKL04, no longer an open draft); one number is drawn, one set of tenders exists.
q "update public.workspaces set vat_regime = 'vat_registered', feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{\"invoicing\": true, \"standaloneInvoicing\": true, \"counterReceipts\": true}' where id = '$ws'" >/dev/null
q "insert into public.vat_rates (workspace_id, label, percent, category, is_default, group_key) select '$ws', 'Standard', 20, 'S', true, 'standard' where not exists (select 1 from public.vat_rates where workspace_id = '$ws' and is_default)" >/dev/null
q "insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', '$ws', 'counter.fiscal_obligation', '\"none\"'::jsonb) on conflict do nothing" >/dev/null
cdraft=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; select (public.counter_receipt_draft_v1('$ws', gen_random_uuid(), null, null, '{\"lines\": [{\"description\": \"Race service\", \"quantity\": \"1\", \"unit_price\": \"12.00\", \"supply\": \"general\", \"unit\": {\"code\": \"unit\", \"label\": \"unit\", \"un_ece_code\": \"C62\"}}]}'::jsonb) ->> 'receipt_id'); commit;" | grep -E '^[0-9a-f-]{36}$' | head -1)
[[ -n "$cdraft" ]] || { echo "::error::the counter draft was not made" >&2; exit 1; }
cf() { echo "$as_owner select 'finalized' from (select public.counter_receipt_finalize_v1('$ws', '$1', '$cdraft', 1, '[{\"kind\": \"cash\", \"amount_minor\": 1200}]'::jsonb)) t;"; }
cf1=$(uid); cf2=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder16" 2>&1 <<SQL &
begin;
$(cf "$cf1")
reset role;
\\! touch '$scratch/ready16'
select pg_sleep(4);
commit;
SQL
holder16=$!
wait_marker "$scratch/ready16" "$scratch/holder16"
PGAPPNAME="transfer-race-counter" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender16" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$(cf "$cf2")
commit;
SQL
contender16=$!
wait_lock "transfer-race-counter"
wait "$holder16" || { echo "::error::the first finalize failed: $(tr '\n' ' ' < "$scratch/holder16")" >&2; exit 1; }
wait "$contender16" || true
grep -qx finalized "$scratch/holder16" || { echo "::error::the first finalize did not complete: $(tr '\n' ' ' < "$scratch/holder16")" >&2; exit 1; }
grep -q "DKL04" "$scratch/contender16" || { echo "::error::the second finalize was not refused as no longer open: $(tr '\n' ' ' < "$scratch/contender16")" >&2; exit 1; }
expect "(M) one receipt number and one tender" "$(q "select count(distinct r.number) || '/' || (select count(*) from public.counter_tenders t where t.receipt_id = r.id) from public.counter_receipts r where r.id = '$cdraft' group by r.id")" "1/1"

# (N) two refunds of the whole correction at once: the second waits for the correction's lock and is refused (DKL08, beyond
# what the correction credits); one refund exists.
cline=$(q "select id from public.counter_receipt_lines where receipt_id = '$cdraft' and line_no = 1" | head -1)
ccorr=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; select (public.counter_receipt_correct_v1('$ws', gen_random_uuid(), '$cdraft', jsonb_build_object('reason', 'race', 'lines', jsonb_build_array(jsonb_build_object('corrects_line_id', '$cline', 'quantity', '1'))))) ->> 'receipt_id'; commit;" | grep -E '^[0-9a-f-]{36}$' | head -1)
[[ -n "$ccorr" ]] || { echo "::error::the correction was not made" >&2; exit 1; }
rf() { echo "$as_owner select 'refunded' from (select public.counter_refund_v1('$ws', '$1', '$ccorr', '[{\"kind\": \"cash\", \"amount_minor\": 1200}]'::jsonb)) t;"; }
rf1=$(uid); rf2=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder17" 2>&1 <<SQL &
begin;
$(rf "$rf1")
reset role;
\\! touch '$scratch/ready17'
select pg_sleep(4);
commit;
SQL
holder17=$!
wait_marker "$scratch/ready17" "$scratch/holder17"
PGAPPNAME="transfer-race-refund" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender17" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$(rf "$rf2")
commit;
SQL
contender17=$!
wait_lock "transfer-race-refund"
wait "$holder17" || { echo "::error::the first refund failed: $(tr '\n' ' ' < "$scratch/holder17")" >&2; exit 1; }
wait "$contender17" || true
grep -qx refunded "$scratch/holder17" || { echo "::error::the first refund did not complete: $(tr '\n' ' ' < "$scratch/holder17")" >&2; exit 1; }
grep -q "DKL08" "$scratch/contender17" || { echo "::error::the second refund was not refused as beyond: $(tr '\n' ' ' < "$scratch/contender17")" >&2; exit 1; }
expect "(N) one refund of 12.00 exists" "$(q "select count(*) || '/' || coalesce(sum(amount_minor), 0) from public.counter_refunds where receipt_id = '$ccorr'")" "1/1200"

# (O) a card authorization is answered while the sale is finalized: the finalize waits for the answer's lock on the receipt,
# then settles the sale with the accepted tender; or, asked first, refuses it as still open. Never both a tender and a
# finalize that disagree: one number, one accepted card tender.
odraft=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; select (public.counter_receipt_draft_v1('$ws', gen_random_uuid(), null, null, '{\"lines\": [{\"description\": \"Race card\", \"quantity\": \"1\", \"unit_price\": \"12.00\", \"supply\": \"general\", \"unit\": {\"code\": \"unit\", \"label\": \"unit\", \"un_ece_code\": \"C62\"}}]}'::jsonb) ->> 'receipt_id'); commit;" | grep -E '^[0-9a-f-]{36}$' | head -1)
otender=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; select (public.counter_tender_request_v1('$ws', gen_random_uuid(), '$odraft', 'card', 1200)) ->> 'tender_id'; commit;" | grep -E '^[0-9a-f-]{36}$' | head -1)
[[ -n "$odraft" && -n "$otender" ]] || { echo "::error::the card draft was not made" >&2; exit 1; }
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder18" 2>&1 <<SQL &
begin;
$as_owner
select 'answered ' || (public.counter_tender_resolve_v1('$ws', gen_random_uuid(), '$otender', 'accepted', 'prov-race') ->> 'state');
reset role;
\\! touch '$scratch/ready18'
select pg_sleep(4);
commit;
SQL
holder18=$!
wait_marker "$scratch/ready18" "$scratch/holder18"
PGAPPNAME="transfer-race-resolve" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender18" 2>&1 <<SQL &
begin;
$as_owner
select 'finalized ' || (public.counter_receipt_finalize_v1('$ws', gen_random_uuid(), '$odraft', 1, jsonb_build_array(jsonb_build_object('tender_id', '$otender'))) ->> 'tenders');
commit;
SQL
contender18=$!
wait_lock "transfer-race-resolve"
wait "$holder18" || { echo "::error::the answer failed: $(tr '\n' ' ' < "$scratch/holder18")" >&2; exit 1; }
wait "$contender18" || { echo "::error::the finalize failed: $(tr '\n' ' ' < "$scratch/contender18")" >&2; exit 1; }
grep -qx "answered accepted" "$scratch/holder18" || { echo "::error::the answer was not recorded: $(tr '\n' ' ' < "$scratch/holder18")" >&2; exit 1; }
grep -qx "finalized 1" "$scratch/contender18" || { echo "::error::the finalize did not settle with the accepted tender: $(tr '\n' ' ' < "$scratch/contender18")" >&2; exit 1; }
expect "(O) one number, one accepted card tender" "$(q "select (r.number is not null)::text || '/' || (select count(*) from public.counter_tenders t where t.receipt_id = r.id and t.state = 'accepted' and t.kind = 'card') from public.counter_receipts r where r.id = '$odraft'")" "true/1"

# (P) two sessions open the same till at once: one session, the other refused (DKL12 already_open).
q "update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{\"counterTillSessions\": true}' where id = '$ws'" >/dev/null
tillid=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; select (public.counter_till_save_v1('$ws', gen_random_uuid(), null, 'Race till', null, true)) ->> 'till_id'; commit;" | grep -E '^[0-9a-f-]{36}$' | head -1)
[[ -n "$tillid" ]] || { echo "::error::the till was not made" >&2; exit 1; }
op() { echo "$as_owner select 'opened' from (select public.counter_session_open_v1('$ws', '$1', '$tillid', 10000, null)) t;"; }
op1=$(uid); op2=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder19" 2>&1 <<SQL &
begin;
$(op "$op1")
reset role;
\\! touch '$scratch/ready19'
select pg_sleep(4);
commit;
SQL
holder19=$!
wait_marker "$scratch/ready19" "$scratch/holder19"
PGAPPNAME="transfer-race-open" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender19" 2>&1 <<SQL &
\\set VERBOSITY verbose
begin;
$(op "$op2")
commit;
SQL
contender19=$!
wait_lock "transfer-race-open"
wait "$holder19" || { echo "::error::the first open failed: $(tr '\n' ' ' < "$scratch/holder19")" >&2; exit 1; }
wait "$contender19" || true
grep -qx opened "$scratch/holder19" || { echo "::error::the first open did not complete: $(tr '\n' ' ' < "$scratch/holder19")" >&2; exit 1; }
grep -q "DKL12" "$scratch/contender19" || { echo "::error::the second open was not refused as already open: $(tr '\n' ' ' < "$scratch/contender19")" >&2; exit 1; }
expect "(P) one open session on the till" "$(q "select count(*) from public.counter_till_sessions where till_id = '$tillid' and state = 'open'")" "1"

# (Q) a sale finalized and the close of its session at once: the sale holds the session for share, the close takes it for
# update and waits; the close then counts the sale (one ordering: the sale committed first).
qsession=$(q "select id from public.counter_till_sessions where till_id = '$tillid' and state = 'open'" | head -1)
qdraft=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "begin; select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated; select (public.counter_receipt_draft_v1('$ws', gen_random_uuid(), null, null, '{\"till_id\": \"$tillid\", \"lines\": [{\"description\": \"Race sale\", \"quantity\": \"1\", \"unit_price\": \"12.00\", \"supply\": \"general\", \"unit\": {\"code\": \"unit\", \"label\": \"unit\", \"un_ece_code\": \"C62\"}}]}'::jsonb) ->> 'receipt_id'); commit;" | grep -E '^[0-9a-f-]{36}$' | head -1)
[[ -n "$qdraft" ]] || { echo "::error::the sale draft was not made" >&2; exit 1; }
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder20" 2>&1 <<SQL &
begin;
$as_owner
select 'sold ' || (public.counter_receipt_finalize_v1('$ws', gen_random_uuid(), '$qdraft', 1, '[{"kind": "cash", "amount_minor": 1200}]'::jsonb) ->> 'number');
reset role;
\\! touch '$scratch/ready20'
select pg_sleep(4);
commit;
SQL
holder20=$!
wait_marker "$scratch/ready20" "$scratch/holder20"
PGAPPNAME="transfer-race-close" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender20" 2>&1 <<SQL &
begin;
$as_owner
select 'closed ' || (public.counter_session_close_v1('$ws', gen_random_uuid(), '$qsession', 11200, null, 'race', 0) ->> 'expected_minor');
commit;
SQL
contender20=$!
wait_lock "transfer-race-close"
wait "$holder20" || { echo "::error::the sale failed: $(tr '\n' ' ' < "$scratch/holder20")" >&2; exit 1; }
wait "$contender20" || { echo "::error::the close failed: $(tr '\n' ' ' < "$scratch/contender20")" >&2; exit 1; }
grep -q "^sold " "$scratch/holder20" || { echo "::error::the sale did not complete: $(tr '\n' ' ' < "$scratch/holder20")" >&2; exit 1; }
grep -qx "closed 11200" "$scratch/contender20" || { echo "::error::the close did not count the sale (expected 11200): $(tr '\n' ' ' < "$scratch/contender20")" >&2; exit 1; }
expect "(Q) the sale is in the closed session" "$(q "select count(*) from public.counter_receipts where till_session_id = '$qsession' and state = 'finalized'")" "1"

echo "stock transfer race: opposing transfers never deadlock and keep every total; the last stock is taken once; a booking confirmation and a customer return of one item serialise in both orders; two put-aways cannot over-allocate a line; two sessions crossing a reorder point raise one alert"
