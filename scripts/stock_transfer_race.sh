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
#   (C) a legacy booking confirmation (the bridge) against a customer return of
#       the same item, in both orders: the bridge takes the item's row first like
#       every stock command, so neither order deadlocks and the stock adds up:
#       return holds -> the confirmation waits, then takes what the return put
#       back; confirmation holds -> the return waits, then puts its unit back.
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
q() { psql "$url" -X -qAt -v ON_ERROR_STOP=1 -c "$1"; }
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
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"services": true, "stockManagement": true, "stockTakeOut": true}' where id = :'ws';
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
select id as ev1 from public.events where workspace_id = :'ws' and type = 'service_charge' and (payload ->> 'quantity')::int = 2 \gset
select id as ev2 from public.events where workspace_id = :'ws' and type = 'service_charge' and (payload ->> 'quantity')::int = 1 \gset
\echo :ws :x :y :z :main :shelf :loss :customer :w :inv :ev1 :ev2 :supplier
SQL
)
read -r ws x y z main shelf loss customer w inv ev1 ev2 supplier <<<"$fixture"
for v in "$ws" "$x" "$y" "$z" "$main" "$shelf" "$loss" "$customer" "$w" "$inv" "$ev1" "$ev2" "$supplier"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
expect() { [[ "$2" == "$3" ]] || { echo "::error::$1: expected '$3', got '$2'" >&2; exit 1; }; }
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
echo "stock transfer race: opposing transfers never deadlock and keep every total; the last stock is taken once; a booking confirmation and a customer return of one item serialise in both orders"
