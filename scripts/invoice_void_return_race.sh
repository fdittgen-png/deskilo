#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4492 (row 2; 0975) -- a return and a void of the same sale, at once. The business received 8 mugs and sold 4 on each
# of two invoices. (A) The holder takes one mug of the first invoice back by the stock door (`stock_return_v1`) and
# keeps its transaction open; the contender voids that invoice and WAITS (the void locks the item's row before it reads
# what is still out), then brings back the three that are left: four back for four sold. (B) The holder voids the second
# invoice and keeps its transaction open; the contender asks the stock door for one of its mugs and WAITS, then is
# refused (DKG17: nothing can still be reversed). All 8 are on hand again and the customer holds none: nothing came back
# twice. A holder that never took its lock, or a contender that never waited, fails the script: nothing here can pass
# empty. A single pgTAP transaction cannot show a race, so each contender is its own psql process on CI's disposable
# database. Fresh ids per run; the cleanup removes the business.
set -euo pipefail
url=${1:?usage: invoice_void_return_race.sh DATABASE_URL}
uid() { uuidgen | tr 'A-Z' 'a-z'; }
owner=$(uid)
buyer=$(uid)
scratch=$(mktemp -d)
cleanup() {
  local original_status=$?
  if [[ -n "${ws:-}" ]]; then
    psql "$url" -X -q -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<SQL ||
delete from public.workspaces where id = '$ws';
SQL
      echo "::warning::invoice void return race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@void-race.test', '', now(), now(), now()),
       ('$buyer', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$buyer@void-race.test', '', now(), now(), now());
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Void race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
         || '{"invoicing": true, "standaloneInvoicing": true, "services": true, "stockManagement": true, "stockReturns": true}',
       vat_regime = 'vat_registered', vat_id = 'FR40303265045', legal_id = '30326504500014',
       street = '4 avenue de Castelnau', city = 'Pézenas', postal_code = '34120', address = '4 avenue de Castelnau, 34120 Pézenas'
 where id = :'ws';
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (:'ws', '$buyer', false, false, 'active', '2026-01-01') returning id as customer \gset
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = '$buyer';
insert into public.vat_rates (workspace_id, label, percent, category, is_default, active, valid_from)
values (:'ws', 'Normal 20 %', 20, 'S', true, true, '2000-01-01');
insert into public.services (workspace_id, name, price_cents, active, inventory_unit, tracking, stockable)
values (:'ws', 'Race mug', 1000, true, 'piece', 'none', true) returning id as item \gset
select id as main from public.stock_locations where workspace_id = :'ws' and code = 'MAIN' \gset
select id as supplier from public.stock_locations where workspace_id = :'ws' and kind = 'supplier' \gset
-- the day of the business, read before the session takes the member role (workspace_today is a server helper)
select public.workspace_today(:'ws') as today \gset
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.stock_move_v1(:'ws', gen_random_uuid(), jsonb_build_array(
  jsonb_build_object('item_id', :'item', 'quantity', 8, 'from', :'supplier', 'to', :'main')), 'receipt');
select (public.save_standalone_invoice_draft_v1(:'ws', null, null, :'customer', :'today'::date,
  (:'today'::date + 30), '', '', jsonb_build_array(jsonb_build_object('description', 'Mug', 'quantity', '4',
  'unit_price', '10', 'basis', 'net', 'supply', 'goods', 'item_id', :'item',
  'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62')))) ->> 'draft_id') as d1 \gset
select (public.save_standalone_invoice_draft_v1(:'ws', null, null, :'customer', :'today'::date,
  (:'today'::date + 30), '', '', jsonb_build_array(jsonb_build_object('description', 'Mug', 'quantity', '4',
  'unit_price', '10', 'basis', 'net', 'supply', 'goods', 'item_id', :'item',
  'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62')))) ->> 'draft_id') as d2 \gset
select (public.issue_standalone_invoice_v1(:'ws', :'d1', 1, gen_random_uuid()) ->> 'invoice_id') as one \gset
select (public.issue_standalone_invoice_v1(:'ws', :'d2', 1, gen_random_uuid()) ->> 'invoice_id') as two \gset
reset role;
commit;
\echo :ws :item :main :one :two
SQL
)
read -r ws item main one two <<<"$fixture"
for v in "$ws" "$item" "$main" "$one" "$two"; do
  [[ "$v" =~ ^[0-9a-f-]{36}$ ]] || { echo "::error::fixture incomplete: '$fixture'" >&2; exit 1; }
done
balance() { q "select coalesce(sum(quantity), 0)::int from public.stock_balances where item_id = '$item' and location_id = '$main'"; }
at_customer() {
  q "select coalesce(sum(b.quantity), 0)::int from public.stock_balances b join public.stock_locations l on l.id = b.location_id where b.item_id = '$item' and l.kind = 'customer'"
}
sale_of() { q "select id from public.stock_movements where invoice_id = '$1' and reason = 'sale'"; }
back_for() { q "select coalesce(sum(quantity), 0)::int from public.stock_movements where invoice_id = '$1' and reason = 'return_in'"; }
expect "the fixture: 8 mugs received, 4 sold on each of two invoices" "$(balance)/$(at_customer)" "0/8"
sale_one=$(sale_of "$one")
sale_two=$(sale_of "$two")
# take_back SALE: one mug of a sale, by the stock door
take_back() {
  echo "$as_owner select 'returned ' || (public.stock_return_v1('$ws', '$(uid)', '$(uid)', 'customer', jsonb_build_array(jsonb_build_object('return_line_id', '$(uid)', 'source_movement_id', '$1', 'quantity', '1', 'location', '$main'))) ->> 'kind');"
}
void() {
  echo "$as_owner select 'voided' || coalesce(public.void_invoice('$1')::text, '');"
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

# (A) the return holds, the void waits and brings back what is left
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder_a" 2>&1 <<SQL &
begin;
$(take_back "$sale_one")
reset role;
\! touch '$scratch/ready_a'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready_a"
PGAPPNAME="invoice-void-race-a" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender_a" 2>&1 <<SQL &
begin;
$(void "$one")
commit;
SQL
contender=$!
wait_lock "invoice-void-race-a"
wait "$holder"
wait "$contender" || true
grep -qx "returned customer" "$scratch/holder_a" || { echo "::error::the holder did not take the mug back" >&2; cat "$scratch/holder_a" >&2; exit 1; }
grep -qx "voided" "$scratch/contender_a" || { echo "::error::the void did not go through" >&2; cat "$scratch/contender_a" >&2; exit 1; }
expect "(A) one came back by the stock door and three by the void: four for four sold" "$(back_for "$one")/$(balance)" "4/4"

# (B) the void holds, the return waits and is refused
psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/holder_b" 2>&1 <<SQL &
begin;
$(void "$two")
reset role;
\! touch '$scratch/ready_b'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready_b"
PGAPPNAME="invoice-void-race-b" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender_b" 2>&1 <<SQL &
begin;
$(take_back "$sale_two")
commit;
SQL
contender=$!
wait_lock "invoice-void-race-b"
wait "$holder"
wait "$contender" || true
grep -qx "voided" "$scratch/holder_b" || { echo "::error::the holder did not void" >&2; cat "$scratch/holder_b" >&2; exit 1; }
grep -q "can still be reversed" "$scratch/contender_b" || {
  echo "::error::the return of a voided sale was not refused (DKG17)" >&2; cat "$scratch/contender_b" >&2; exit 1
}
expect "(B) the void brought back four, the return nothing" "$(back_for "$two")" "4"
expect "all 8 are on hand and the customer holds none" "$(balance)/$(at_customer)" "8/0"
echo "invoice void return race: a return and a void of the same sale wait for each other, and nothing comes back twice"
