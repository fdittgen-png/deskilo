#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# #4433 (G18b) -- two invoices taking the last piece at once. The business holds ONE mug at MAIN; two standalone
# drafts sell one mug each to the same customer. The holder issues its invoice and keeps its transaction open; the
# contender issues the other and WAITS (the issue takes the business's lock, the sale the item's row), then is refused
# with the line's missing fact (DKI01 line_1_stock_not_enough): one invoice, one sale, nothing left, no number taken by
# the loser. The winner replayed under its request id answers the same invoice and moves nothing again. A holder that
# never took its lock, or a contender that never waited, fails the script: nothing here can pass empty. A single pgTAP
# transaction cannot show a race, so each contender is its own psql process on CI's disposable database. Fresh ids
# per run; the cleanup removes the business.
set -euo pipefail
url=${1:?usage: invoice_goods_race.sh DATABASE_URL}
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
      echo "::warning::invoice goods race fixture cleanup failed" >&2
  fi
  rm -rf "$scratch"
  exit "$original_status"
}
trap cleanup EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"
as_owner="select set_config('request.jwt.claims', '{\"sub\":\"$owner\",\"role\":\"authenticated\",\"aal\":\"aal2\"}', true); set local role authenticated;"
fixture=$(psql "$url" -X -qAt -v ON_ERROR_STOP=1 <<SQL | tail -1
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('$owner', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$owner@goods-race.test', '', now(), now(), now()),
       ('$buyer', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '$buyer@goods-race.test', '', now(), now(), now());
begin;
select set_config('request.jwt.claims', '{"sub":"$owner","role":"authenticated","aal":"aal2"}', true);
set local role authenticated;
select public.create_workspace('Goods race', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null) as ws \gset
reset role;
commit;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"invoicing": true, "standaloneInvoicing": true, "services": true, "stockManagement": true}',
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
  jsonb_build_object('item_id', :'item', 'quantity', 1, 'from', :'supplier', 'to', :'main')), 'receipt');
select (public.save_standalone_invoice_draft_v1(:'ws', null, null, :'customer', :'today'::date,
  (:'today'::date + 30), '', '', jsonb_build_array(jsonb_build_object('description', 'Mug', 'quantity', '1',
  'unit_price', '10', 'basis', 'net', 'supply', 'goods', 'item_id', :'item',
  'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62')))) ->> 'draft_id') as one \gset
select (public.save_standalone_invoice_draft_v1(:'ws', null, null, :'customer', :'today'::date,
  (:'today'::date + 30), '', '', jsonb_build_array(jsonb_build_object('description', 'Mug', 'quantity', '1',
  'unit_price', '10', 'basis', 'net', 'supply', 'goods', 'item_id', :'item',
  'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62')))) ->> 'draft_id') as two \gset
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
sales() { q "select count(*) from public.stock_movements where item_id = '$item' and reason = 'sale' and invoice_id is not null"; }
invoices() { q "select count(*) from public.invoices where workspace_id = '$ws'"; }
expect "the fixture: 1 mug at MAIN" "$(balance)" "1"
# issue DRAFT REQUEST
issue() {
  echo "$as_owner select 'issued ' || (public.issue_standalone_invoice_v1('$ws', '$1', 1, '$2') ->> 'replayed');"
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
$(issue "$one" "$win")
reset role;
\! touch '$scratch/ready'
select pg_sleep(5);
commit;
SQL
holder=$!
wait_marker "$scratch/ready"
PGAPPNAME="invoice-goods-race" psql "$url" -X -qAt -v ON_ERROR_STOP=1 >"$scratch/contender" 2>&1 <<SQL &
begin;
$(issue "$two" "$lose")
commit;
SQL
contender=$!
wait_lock "invoice-goods-race"
wait "$holder"
wait "$contender" || true
grep -qx "issued false" "$scratch/holder" || { echo "::error::the holder did not issue" >&2; cat "$scratch/holder" >&2; exit 1; }
grep -q "line_1_stock_not_enough" "$scratch/contender" || {
  echo "::error::the second invoice was not refused as 'line_1_stock_not_enough'" >&2; cat "$scratch/contender" >&2; exit 1
}
expect "the last mug was taken once" "$(balance)" "0"
expect "one invoice, one sale" "$(invoices)/$(sales)" "1/1"
before=$(sales)
replayed=$(q "$(issue "$one" "$win")" | tail -1)
expect "the winner replayed under its request id answers the same invoice" "$replayed" "issued true"
expect "and moves nothing again" "$(sales)" "$before"
echo "invoice goods race: two invoices taking the last mug: one sells it, the other waits and is refused"
