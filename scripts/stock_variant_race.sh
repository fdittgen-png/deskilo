#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4169 (A2) -- two sessions moving the SAME variant (taken out as a consumption to
# the loss place since #4170: the generic move checks its reason against the places). The ledger's balance of
# an item, a variant, a lot and a place is one row (stock_balances, unique on
# the four, nulls not distinct), and a move updates it under that row's lock,
# so the second session waits for the first and then finds the stock gone:
#   (A) 4 red at MAIN; the holder moves 3 red out and keeps its transaction
#       open; the contender asks for 3 red too and WAITS on a lock, then is
#       refused (not that much on hand, DKG03): one movement, 1 red left;
#   (B) a session moving 3 BLUE of the same item at the same place meanwhile:
#       every move of one item serialises on the item's row (the ledger's
#       mirror of the shelf count is written under it), so the blue move WAITS
#       for the holder too, and then completes: blue ends at 1 as well;
# Afterwards red and blue each hold 1, the loser left no movement, and the
# winner replayed under its request id answers without a new row. A holder
# that never took its lock, or a contender or blue move that never waited or
# never completed, fails the script: nothing here can pass empty. A single pgTAP
# transaction cannot show a race, so each contender is its own psql process on
# CI's disposable database. Fresh ids per run; the cleanup removes the business.
set -euo pipefail
url=${1:?usage: stock_variant_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
owner=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  if [[ -n "${ws:-}" ]]; then
    psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.workspaces where id = '$ws';
SQL
      echo "::warning::stock variant race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@variant-race.test', '', now(), now(), now());
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Variant race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"stockManagement": true, "stockTakeOut": true}' where id = :'ws';
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race shirt', 2500, true, 'piece', 'none', true) returning id as item \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.save_item_dimension_v1(:'ws', null, null, gen_random_uuid(),
  '{"name": "Colour", "values": [{"label": "Red"}, {"label": "Blue"}]}'::jsonb);
reset role;
select id as dim from public.item_dimensions where workspace_id = :'ws' \gset
select id as red from public.item_dimension_values where dimension_id = :'dim' and label = 'Red' \gset
select id as blue from public.item_dimension_values where dimension_id = :'dim' and label = 'Blue' \gset
set local role authenticated;
select public.save_item_variants_v1(:'ws', :'item', 1, gen_random_uuid(),
  jsonb_build_array(jsonb_build_object('values', jsonb_build_object(:'dim', :'red')),
                    jsonb_build_object('values', jsonb_build_object(:'dim', :'blue'))));
reset role;
commit;
select id as vred from public.item_variants where item_id = :'item' and canonical = :'dim' || ':' || :'red' \gset
select id as vblue from public.item_variants where item_id = :'item' and canonical = :'dim' || ':' || :'blue' \gset
select id as main from public.stock_locations where workspace_id = :'ws' and code = 'MAIN' \gset
select id as supplier from public.stock_locations where workspace_id = :'ws' and kind = 'supplier' \gset
select id as customer from public.stock_locations where workspace_id = :'ws' and kind = 'loss' \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'item', 'quantity', 4, 'from', :'supplier', 'to', :'main', 'variant_id', :'vred'),
  jsonb_build_object('item_id', :'item', 'quantity', 4, 'from', :'supplier', 'to', :'main', 'variant_id', :'vblue')), 'receipt');
reset role;
commit;
\echo :ws :item :vred :vblue :main :customer
SQL
)
read -r ws item vred vblue main customer <<<"$fixture"
for v in "$ws" "$item" "$vred" "$vblue" "$main" "$customer"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
balance() { q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$item' and variant_id = '$1' and location_id = '$main'"; }
movements() { q "select count(*) from public.stock_movements where request_id = '$1'"; }
expect "the fixture: 4 red and 4 blue at MAIN" "$(balance "$vred")/$(balance "$vblue")" "4/4"
# take REQUEST VARIANT QUANTITY
take() {
  echo "$as_owner select 'moved' from (select public.stock_move_v1('$ws', '$1', jsonb_build_array(jsonb_build_object('item_id', '$item', 'quantity', $3, 'from', '$main', 'to', '$customer', 'variant_id', '$2')), 'consumption')) x;"
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
win=$(uid); lose=$(uid); other=$(uid)
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder" 2>&1 <<SQL &
begin;
$(take "$win" "$vred" 3)
reset role;
\! touch '$scratch/ready'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready"
PGAPPNAME="variant-race-red" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender" 2>&1 <<SQL &
begin;
$(take "$lose" "$vred" 3)
commit;
SQL
contender=$!
wait_lock "variant-race-red"
# (B) the other variant of the same item at the same place: it waits on the
# item's row for the holder (per-item serialisation is the decided design), then moves
PGAPPNAME="variant-race-blue" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/blue" 2>&1 <<SQL &
begin;
$(take "$other" "$vblue" 3)
commit;
SQL
blue=$!
wait_lock "variant-race-blue"
wait "$holder"
wait "$contender" || true
wait "$blue" || { echo "::error::the blue move failed" >&2; cat "$scratch/blue" >&2; exit 1; }
grep -qx moved "$scratch/blue" || { echo "::error::the blue move did not complete" >&2; cat "$scratch/blue" >&2; exit 1; }
grep -qx moved "$scratch/holder" || { echo "::error::the holder did not move" >&2; cat "$scratch/holder" >&2; exit 1; }
grep -q "not that much on hand" "$scratch/contender" || {
  echo "::error::the second red move was not refused as 'not that much on hand'" >&2; cat "$scratch/contender" >&2; exit 1
}
expect "red: 4 - 3 = 1 (the loser moved nothing)" "$(balance "$vred")" "1"
expect "blue: 4 - 3 = 1 (the blue move waited for the item, then moved)" "$(balance "$vblue")" "1"
expect "one movement for the winner, none for the loser, one for blue" "$(movements "$win")/$(movements "$lose")/$(movements "$other")" "1/0/1"
before=$(q "select count(*) from public.stock_movements where workspace_id = '$ws'")
q "$(take "$win" "$vred" 3)" >/dev/null
expect "the winner replayed under its request id writes nothing" "$(q "select count(*) from public.stock_movements where workspace_id = '$ws'")" "$before"
refused=$(q "$(take "$win" "$vred" 2)" 2>&1 || true)
grep -q "already used for a different request" <<<"$refused" || {
  echo "::error::a changed payload under the winner's request id was not refused: $refused" >&2; exit 1
}
echo "stock variant race: two sessions moving one variant: one wins, the other is refused, the other variant waited, then moved"
