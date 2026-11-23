-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #4171 (0840-0842, A): a delivery is received into stock exactly once. The delivery
-- of 0684 still records with receiving off; with it on, two cartons of twelve are
-- 24 pieces at a place in a new lot, the factor, unit and quantity are frozen, a lost
-- response answers the same ids, nothing more than arrived is put away, the service
-- and free-text lines are named not dropped, cost is known, known zero or unknown (never a
-- silent zero), the order price is an explicit assertion, a tracked item needs its lot
-- metadata, red and blue are separate stock, a failure rolls the delivery back with
-- the put-away, receipts and allocations are insert-only, and only a buyer who manages
-- the stock (not a delegated session) writes. Rolled back.
begin;
select plan(54);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'ok'; exception when others then return sqlstate; end
$f$;
create or replace function pg_temp.orev(p_order int) returns int language sql stable as $f$
  select revision from public.purchase_orders where id = pg_temp.u(p_order)
$f$;
create or replace function pg_temp.combined(p_user int, p_req int, p_order int, p_lines text, p_allocs text, p_ws int default 101, p_delegated boolean default false, p_rev int default null)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.record_receipt_and_put_away_v1(%L, %L, %s, current_date, %L::jsonb, ''dock'', %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_order), coalesce(p_rev, pg_temp.orev(p_order)), p_lines, pg_temp.u(p_req), p_allocs), p_delegated)
$f$;
create or replace function pg_temp.putaway(p_user int, p_req int, p_receipt uuid, p_allocs text, p_ws int default 101, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.put_away_receipt_v1(%L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_receipt, pg_temp.u(p_req), p_allocs), p_delegated)
$f$;
create or replace function pg_temp.on_hand(p_item int, p_code text default 'MAIN', p_variant uuid default null) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item)
    and location_id = pg_temp.loc(p_code) and variant_id is not distinct from p_variant
$f$;
create or replace function pg_temp.alloc(p_line int, p_qty numeric, p_loc text, p_extra text default '') returns text language sql as $f$
  select format('{"line_no": %s, "quantity": %s, "location_id": "%s"%s}', p_line, p_qty, p_loc, p_extra)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'receiving-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Receiving A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": false}',
   '{"member": ["managePurchases"]}'),
  (pg_temp.u(102), 'Receiving B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name) values
  (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Water Co'), (pg_temp.u(402), pg_temp.u(102), 'S-1', 'Other Co');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Water', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Yoghurt', 150, true, null, 'piece', 'expiry', true),
  (pg_temp.u(303), pg_temp.u(101), 'Delivery fee', 500, true, null, 'piece', 'none', false),
  (pg_temp.u(304), pg_temp.u(101), 'Biscuits', 200, true, null, 'piece', 'none', true),
  (pg_temp.u(305), pg_temp.u(101), 'Shirt', 2500, true, null, 'piece', 'none', true),
  (pg_temp.u(306), pg_temp.u(102), 'Foreign item', 100, true, null, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1);
insert into public.stock_locations (workspace_id, kind, code, name) values (pg_temp.u(101), 'shelf', 'SHELF-A', 'Shelf A');
insert into public.item_dimensions (id, workspace_id, name) values (pg_temp.u(601), pg_temp.u(101), 'Colour');
insert into public.item_dimension_values (id, workspace_id, dimension_id, label) values
  (pg_temp.u(611), pg_temp.u(101), pg_temp.u(601), 'Red'), (pg_temp.u(612), pg_temp.u(101), pg_temp.u(601), 'Blue');
insert into public.item_variants (id, workspace_id, item_id, canonical) values
  (pg_temp.u(621), pg_temp.u(101), pg_temp.u(305), pg_temp.u(601)::text || ':' || pg_temp.u(611)::text),
  (pg_temp.u(622), pg_temp.u(101), pg_temp.u(305), pg_temp.u(601)::text || ':' || pg_temp.u(612)::text);
insert into public.item_variant_values (workspace_id, variant_id, dimension_id, value_id) values
  (pg_temp.u(101), pg_temp.u(621), pg_temp.u(601), pg_temp.u(611)), (pg_temp.u(101), pg_temp.u(622), pg_temp.u(601), pg_temp.u(612));
insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, created_by_member_id) values
  (pg_temp.u(501), pg_temp.u(101), 2026, 1, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(502), pg_temp.u(101), 2026, 2, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(504), pg_temp.u(101), 2026, 3, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(505), pg_temp.u(101), 2026, 4, pg_temp.u(401), 'draft', 'USD', pg_temp.u(201)),
  (pg_temp.u(506), pg_temp.u(101), 2026, 5, pg_temp.u(401), 'draft', 'JPY', pg_temp.u(201)),
  (pg_temp.u(507), pg_temp.u(101), 2026, 6, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(503), pg_temp.u(102), 2026, 1, pg_temp.u(402), 'draft', 'EUR', pg_temp.u(204));
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents) values
  (pg_temp.u(101), pg_temp.u(501), 1, pg_temp.u(301), '', 2, 'carton', 1200),
  (pg_temp.u(101), pg_temp.u(501), 2, pg_temp.u(304), '', 24, 'piece', 50),
  (pg_temp.u(101), pg_temp.u(501), 3, pg_temp.u(302), '', 10, 'piece', 80),
  (pg_temp.u(101), pg_temp.u(501), 4, pg_temp.u(303), '', 1, 'piece', 500),
  (pg_temp.u(101), pg_temp.u(501), 5, null, 'Pallet deposit', 1, 'piece', 2000),
  (pg_temp.u(101), pg_temp.u(501), 6, pg_temp.u(305), '', 6, 'piece', 1000),
  (pg_temp.u(101), pg_temp.u(502), 1, pg_temp.u(301), '', 3, 'piece', 100),
  (pg_temp.u(101), pg_temp.u(504), 1, pg_temp.u(302), '', 5, 'piece', 80),
  (pg_temp.u(101), pg_temp.u(504), 2, pg_temp.u(304), '', 4, 'piece', 50),
  (pg_temp.u(101), pg_temp.u(505), 1, pg_temp.u(304), '', 2, 'piece', 50),
  (pg_temp.u(101), pg_temp.u(506), 1, pg_temp.u(304), '', 1, 'piece', 1000),
  (pg_temp.u(101), pg_temp.u(507), 1, pg_temp.u(304), '', 1, 'piece', 50),
  (pg_temp.u(102), pg_temp.u(503), 1, pg_temp.u(306), '', 1, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where workspace_id in (pg_temp.u(101), pg_temp.u(102));
select set_config('t.main', pg_temp.loc('MAIN')::text, false);
select set_config('t.shelf', pg_temp.loc('SHELF-A')::text, false);

-- With receiving off, the delivery of 0684 still records and no stock is made; the new commands refuse.
select is(left(pg_temp.combined(1, 701, 502, '[{"line_no": 1, "quantity": 3}]', '[' || pg_temp.alloc(1, 3, current_setting('t.main')) || ']'), 9), 'ERR DKG01',
  'with receiving off the combined command refuses (DKG01)');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select (public.record_purchase_order_receipt_v1(%L, %L, %s, current_date, '[{"line_no": 1, "quantity": 3}]'::jsonb, '', %L)::jsonb ->> 'state')$q$,
            pg_temp.u(101), pg_temp.u(502), pg_temp.orev(502), pg_temp.u(702))) || ' ' || (select count(*) from public.stock_movements where workspace_id = pg_temp.u(101))::text,
  'received 0', 'the plain delivery of 0684 still records, and no stock row is fabricated');
update public.workspaces set feature_flags = feature_flags || '{"stockReceiving": true}' where id = pg_temp.u(101);

-- Receive two cartons of twelve and put them away; the fee and the free text arrive but are not stock.
select is((pg_temp.combined(1, 703, 501,
  '[{"line_no": 1, "quantity": 2}, {"line_no": 2, "quantity": 24}, {"line_no": 3, "quantity": 10}, {"line_no": 4, "quantity": 1}, {"line_no": 5, "quantity": 1}]',
  '[' || pg_temp.alloc(1, 2, current_setting('t.main'), ', "cost": {"state": "known", "total_cost_minor": 2400}') || ','
      || pg_temp.alloc(2, 12, current_setting('t.main')) || ','
      || pg_temp.alloc(3, 10, current_setting('t.shelf'), ', "lot": {"code": "Y1", "expires_on": "2020-01-31"}') || ']')::jsonb -> 'allocations' -> 0 ->> 'inventory_quantity'),
  '24.000000', 'two cartons of twelve are 24 pieces, once');
select set_config('t.receipt', (select id::text from public.purchase_order_receipts where order_id = pg_temp.u(501)), false);
select is(pg_temp.on_hand(301)::text || ' ' || (select count(*) from public.stock_receipt_allocations where receipt_id = current_setting('t.receipt')::uuid)::text
          || ' ' || (select count(*) from public.stock_movements m join public.stock_receipt_allocations a on a.movement_id = m.id where m.receipt_line_id is not null)::text,
  '24.000000 3 3', '24 are on hand at MAIN, three allocations, each linked to its movement and its receipt line');
select is((select factor_num::text || '/' || factor_den::text || ' ' || entered_unit || ' ' || entered_quantity::text || ' ' || order_reference || ' ' || supplier_name
             from public.stock_receipt_allocations where order_line_id = (select id from public.purchase_order_lines where order_id = pg_temp.u(501) and line_no = 1)),
  '12/1 carton 2.000000 2026-0001 Water Co', 'the allocation freezes the factor, the entered unit and quantity, the order and the supplier');
select is((select count(*) from public.purchase_order_receipt_lines where receipt_id = current_setting('t.receipt')::uuid)::int, 5,
  'the delivery recorded all five lines');
select is((pg_temp.combined(1, 703, 501,
  '[{"line_no": 1, "quantity": 2}, {"line_no": 2, "quantity": 24}, {"line_no": 3, "quantity": 10}, {"line_no": 4, "quantity": 1}, {"line_no": 5, "quantity": 1}]',
  '[' || pg_temp.alloc(1, 2, current_setting('t.main'), ', "cost": {"state": "known", "total_cost_minor": 2400}') || ','
      || pg_temp.alloc(2, 12, current_setting('t.main')) || ','
      || pg_temp.alloc(3, 10, current_setting('t.shelf'), ', "lot": {"code": "Y1", "expires_on": "2020-01-31"}') || ']', 101, false, 1)::jsonb ->> 'replayed')
          || ' ' || (select count(*) from public.stock_receipt_allocations)::text || ' ' || (select count(*) from public.purchase_order_receipts where order_id = pg_temp.u(501))::text,
  'true 3 1', 'a lost response retried under the same id answers the same and writes nothing');

-- Cost is never guessed.
select is((select string_agg(cost_state || ':' || total_cost_minor::text || ':' || coalesce(cost_source, '-'), ',' order by total_cost_minor, cost_state)
             from public.stock_lots where workspace_id = pg_temp.u(101)),
  'unknown:0:-,unknown:0:-,known:2400:entered', 'the lot with a cost assertion is known; the lots with none are unknown, never a silent zero');
select is((select count(*) from public.stock_movements where item_id = pg_temp.u(302) and unit_cost is null)::int, 1,
  'the movement of an unknown-cost lot has no unit cost');
select is((select to_char(expires_on, 'YYYY-MM-DD') from public.stock_lots where lot_code = 'Y1'), '2020-01-31',
  'a past expiry is kept as entered (a captured date is not a certification)');

-- The value on hand leaves the unknown-cost lots out of its total and counts them.
select is((pg_temp.run_as(pg_temp.u(1), format('select public.stock_value_at_v1(%L, now())::text', pg_temp.u(101)))::jsonb ->> 'total_minor')
          || ' ' || (pg_temp.run_as(pg_temp.u(1), format('select public.stock_value_at_v1(%L, now())::text', pg_temp.u(101)))::jsonb ->> 'rows_without_cost'),
  '2400 2', 'the value on hand is the known cost only (24 pieces of water at 2400), and says two rows have no cost');

-- Over-allocation: 12 put away of 24; 13 is refused, 12 is accepted, one more is refused.
select is(pg_temp.putaway(1, 711, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(2, 13, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "allocations[0].quantity", "reason": "over_allocated"}', 'putting away 13 after 12 of 24 is refused');
select is((pg_temp.putaway(1, 712, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(2, 12, current_setting('t.shelf'), ', "lot": {"code": "B1"}, "cost": {"state": "known", "total_cost_minor": 0}') || ']')::jsonb -> 'allocations' -> 0 ->> 'entered_quantity'),
  '12', 'the remaining 12 are put away at another place');
select is(pg_temp.putaway(1, 713, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(2, 1, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "allocations[0].quantity", "reason": "over_allocated"}', 'nothing more than arrived is ever put away');
select is((select count(distinct lot_id) from public.stock_receipt_allocations where order_line_id = (select id from public.purchase_order_lines where order_id = pg_temp.u(501) and line_no = 2))::int, 2,
  'each put-away makes its own lot');
select is((select cost_state || ':' || total_cost_minor::text from public.stock_lots where lot_code = 'B1'), 'known:0', 'a known zero stays a known zero, distinct from unknown');

-- Mixed lines: the fee and the free text are named, not dropped.
select is(pg_temp.putaway(1, 715, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(4, 1, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "allocations[0].line", "reason": "item_not_stocked"}', 'a service line is named as not stock');
select is(pg_temp.putaway(1, 716, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(5, 1, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "allocations[0].line", "reason": "item_not_stocked"}', 'a free-text line is named as not stock');

-- Lot metadata of a tracked item, and the order price as an explicit cost.
select is(pg_temp.combined(1, 721, 504, '[{"line_no": 1, "quantity": 5}]', '[' || pg_temp.alloc(1, 5, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "allocations[0].lot.code", "reason": "lot_code_required"}', 'a tracked item needs its lot code');
select is(pg_temp.combined(1, 722, 504, '[{"line_no": 1, "quantity": 5}]', '[' || pg_temp.alloc(1, 5, current_setting('t.main'), ', "lot": {"code": "Y2"}') || ']'),
  'ERR DKG11 {"field": "allocations[0].lot.expires_on", "reason": "expiry_required"}', 'an item tracked by expiry needs its date');
select is(pg_temp.combined(1, 723, 504, '[{"line_no": 1, "quantity": 5}]', '[' || pg_temp.alloc(1, 5, current_setting('t.main'), ', "lot": {"code": "Y2", "expires_on": "2026-13-45"}') || ']'),
  'ERR DKG11 {"field": "allocations[0].lot.expires_on", "reason": "expiry_malformed"}', 'a malformed date is refused');
select is(pg_temp.combined(1, 724, 504, '[{"line_no": 1, "quantity": 5}]', '[' || pg_temp.alloc(1, 5, current_setting('t.main'), ', "lot": {"code": "Y2", "expires_on": "2027-01-31"}, "cost": {"state": "known", "total_cost_minor": 9, "source_currency": "USD"}') || ']'),
  'ERR DKG11 {"field": "allocations[0].cost", "reason": "cost_invalid"}', 'a currency without its rate is refused');
select is((select count(*) from public.purchase_order_receipts where order_id = pg_temp.u(504))::int, 0, 'every refusal above left no receipt behind: the combined command is all or nothing');
select is((pg_temp.combined(1, 725, 504, '[{"line_no": 1, "quantity": 5}, {"line_no": 2, "quantity": 4}]',
  '[' || pg_temp.alloc(1, 5, current_setting('t.main'), ', "lot": {"code": "Y2", "expires_on": "2027-01-31"}') || ','
      || pg_temp.alloc(2, 4, current_setting('t.main'), ', "cost": {"state": "order_price"}') || ']')::jsonb -> 'allocations' -> 1 ->> 'entered_quantity'),
  '4', 'the order price can be asserted as the cost, explicitly');
select is((select cost_state || ':' || total_cost_minor::text || ':' || cost_source from public.stock_lots where item_id = pg_temp.u(304) and cost_source = 'order_price'),
  'known:200:order_price', 'and is the line price times the quantity, labelled as the order price');
select is(pg_temp.combined(1, 726, 505, '[{"line_no": 1, "quantity": 2}]', '[' || pg_temp.alloc(1, 2, current_setting('t.main'), ', "cost": {"state": "order_price"}') || ']'),
  'ERR DKG11 {"field": "allocations[0].cost", "reason": "cost_rate_missing"}', 'an order price in another currency needs its rate');

-- An entry naming a receipt line AND a line number that disagree is refused, and the lines are read once, by id.
select is(pg_temp.putaway(1, 761, current_setting('t.receipt')::uuid, format('[{"receipt_line_id": "%s", "line_no": 2, "quantity": 1, "location_id": "%s"}]',
            (select rl.id from public.purchase_order_receipt_lines rl join public.purchase_order_lines ol on ol.id = rl.order_line_id where rl.receipt_id = current_setting('t.receipt')::uuid and ol.line_no = 1), current_setting('t.main'))),
  'ERR DKG11 {"field": "allocations[0].line", "reason": "line_conflict"}', 'a receipt line id and a line number that disagree are refused');

-- A malformed quantity, rate or id is a refusal of its field, never a raw cast error.
select is(pg_temp.putaway(1, 762, current_setting('t.receipt')::uuid, format('[{"line_no": 2, "quantity": "abc", "location_id": "%s"}]', current_setting('t.main'))),
  'ERR DKG11 {"field": "allocations[0].quantity", "reason": "quantity_invalid"}', 'a quantity that is not a number is refused under its field');
select is(pg_temp.combined(1, 763, 507, '[{"line_no": 1, "quantity": 1}]', format('[{"line_no": 1, "quantity": 1, "location_id": "%s", "cost": {"state": "known", "total_cost_minor": 5, "source_currency": "USD", "source_rate": 0}}]', current_setting('t.main'))),
  'ERR DKG11 {"field": "allocations[0].cost", "reason": "cost_invalid"}', 'a rate of zero or below is refused as an invalid cost');
select is(pg_temp.combined(1, 764, 507, '[{"line_no": 1, "quantity": 1}]', '[{"line_no": 1, "quantity": 1, "location_id": "not-a-uuid"}]'),
  'ERR DKG11 {"field": "allocations[0].location_id", "reason": "location_foreign"}', 'a place id that is not a uuid is refused under its field');

-- The inventory quantity is computed from the very factor that is stored.
select is((select bool_and(inventory_quantity = round(entered_quantity * factor_num::numeric / factor_den, 6)) from public.stock_receipt_allocations)::text, 'true',
  'every allocation''s inventory quantity is its entered quantity times its stored factor');

-- The order price follows each currency''s own minor digits; a rate is never for the business''s own currency.
select is((pg_temp.combined(1, 771, 505, '[{"line_no": 1, "quantity": 2}]', '[' || pg_temp.alloc(1, 2, current_setting('t.main'), ', "cost": {"state": "order_price", "source_rate": 0.9}') || ']')::jsonb -> 'allocations' -> 0 ->> 'entered_quantity'), '2',
  'the order price of an order in dollars is converted by its rate');
select is((select cost_state || ':' || total_cost_minor::text || ':' || source_currency || ':' || source_rate::text from public.stock_lots where cost_source = 'order_price' and source_currency = 'USD'),
  'known:90:USD:0.9', '50 cents times 2 at 0.9 is 90 euro cents');
select is((pg_temp.combined(1, 772, 506, '[{"line_no": 1, "quantity": 1}]', '[' || pg_temp.alloc(1, 1, current_setting('t.main'), ', "cost": {"state": "order_price", "source_rate": 0.0065}') || ']')::jsonb -> 'allocations' -> 0 ->> 'entered_quantity'), '1',
  'the order price of an order in yen is converted');
select is((select total_cost_minor::text from public.stock_lots where cost_source = 'order_price' and source_currency = 'JPY'), '650',
  '1000 yen (no minor digits) at 0.0065 euro per yen is 650 euro cents (two minor digits)');
select is(pg_temp.combined(1, 773, 507, '[{"line_no": 1, "quantity": 1}]', '[' || pg_temp.alloc(1, 1, current_setting('t.main'), ', "cost": {"state": "order_price", "source_rate": 0.9}') || ']'),
  'ERR DKG11 {"field": "allocations[0].cost", "reason": "cost_invalid"}', 'a rate given for an order in the business''s own currency is refused');

-- The lot of a trace: an unknown cost is null, never 0.
select is((pg_temp.run_as(pg_temp.u(1), format('select (public.stock_movement_trace_v1(%L, %L) -> ''lot'' -> ''total_cost_minor'')::text', pg_temp.u(101),
            (select id from public.stock_movements where item_id = pg_temp.u(302) limit 1)))), 'null', 'the trace shows the cost of an unknown-cost lot as null');
select is((pg_temp.run_as(pg_temp.u(1), format('select (public.stock_movement_trace_v1(%L, %L) -> ''lot'' -> ''total_cost_minor'')::text', pg_temp.u(101),
            (select m.id from public.stock_movements m join public.stock_lots l on l.id = m.lot_id where m.item_id = pg_temp.u(301) and l.cost_state = 'known' limit 1)))), '2400', 'and the cost of a known lot as it is');

-- Variants: red and blue are separate stock; none, or a stranger, is refused; a failure rolls the delivery back.
select is(pg_temp.combined(1, 731, 501, '[{"line_no": 6, "quantity": 6}]', '[' || pg_temp.alloc(6, 6, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "allocations[0].variant_id", "reason": "variant_required"}', 'an item with variants is put away by variant');
select is(pg_temp.combined(1, 732, 501, '[{"line_no": 6, "quantity": 6}]', '[' || pg_temp.alloc(6, 6, current_setting('t.main'), ', "variant_id": "' || pg_temp.u(699) || '"') || ']'),
  'ERR DKG11 {"field": "allocations[0].variant_id", "reason": "variant_unknown"}', 'a variant that is not of this item is refused');
select is(pg_temp.combined(1, 733, 501, '[{"line_no": 6, "quantity": 6}]',
  '[' || pg_temp.alloc(6, 3, current_setting('t.main'), ', "variant_id": "' || pg_temp.u(621) || '"') || ','
      || pg_temp.alloc(6, 3, pg_temp.loc('MAIN', 102)::text, ', "variant_id": "' || pg_temp.u(622) || '"') || ']'),
  'ERR DKG11 {"field": "allocations[1].location_id", "reason": "location_foreign"}', 'a place of another business is refused');
select is((select count(*) from public.purchase_order_receipts where order_id = pg_temp.u(501))::int || ' ' || pg_temp.on_hand(305, 'MAIN', pg_temp.u(621))::text,
  '1 0', 'the failure on the second line rolled back the delivery and the first line''s movement');
select is((pg_temp.combined(1, 734, 501, '[{"line_no": 6, "quantity": 6}]',
  '[' || pg_temp.alloc(6, 3, current_setting('t.main'), ', "variant_id": "' || pg_temp.u(621) || '"') || ','
      || pg_temp.alloc(6, 3, current_setting('t.main'), ', "variant_id": "' || pg_temp.u(622) || '"') || ']')::jsonb -> 'allocations' -> 0 ->> 'inventory_quantity'),
  '3.000000', 'red and blue are put away');
select is(pg_temp.on_hand(305, 'MAIN', pg_temp.u(621))::text || ' ' || pg_temp.on_hand(305, 'MAIN', pg_temp.u(622))::text, '3.000000 3.000000', 'three red and three blue are two balances');

-- Who may, and where.
select is(pg_temp.combined(3, 741, 502, '[]', '[]'), 'ERR DKN01 ', 'a buyer who does not manage the stock is refused');
select is(pg_temp.combined(1, 742, 502, '[]', '[]', 101, true), 'ERR DKN01 ', 'a delegated assistant session is refused');
select is(pg_temp.putaway(1, 743, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(2, 1, current_setting('t.main')) || ']', 101, true), 'ERR DKN01 ', 'and cannot put away either');
select is(pg_temp.putaway(1, 744, pg_temp.u(699), '[' || pg_temp.alloc(2, 1, current_setting('t.main')) || ']'),
  'ERR DKG11 {"field": "receipt", "reason": "receipt_unknown"}', 'a receipt that is not this business''s is unknown');

-- The allocations carry the order and the supplier: read like the receipts (managePurchases or viewFinances), not by a reader of the stock alone.
select is(pg_temp.run_as(pg_temp.u(3), 'select (select count(*) from public.stock_receipt_allocations)::text'), (select count(*) from public.stock_receipt_allocations where workspace_id = pg_temp.u(101))::text,
  'a buyer (managePurchases) reads the allocations');
update public.workspaces set role_permissions = '{"member": ["viewStock"]}' where id = pg_temp.u(101);
select is(pg_temp.run_as(pg_temp.u(3), 'select (select count(*) from public.stock_receipt_allocations)::text'), '0',
  'a reader of the stock alone reads none (they name the order and the supplier)');
update public.workspaces set role_permissions = '{"member": ["managePurchases"]}' where id = pg_temp.u(101);

-- History is kept, and a later edit of a unit does not reinterpret what was put away.
select is(pg_temp.try(format('update public.purchase_order_receipts set note = %L where id = %L', 'x', current_setting('t.receipt')))
          || ' ' || pg_temp.try(format('delete from public.purchase_order_receipt_lines where receipt_id = %L', current_setting('t.receipt')))
          || ' ' || pg_temp.try(format('delete from public.purchase_orders where id = %L', pg_temp.u(501)))
          || ' ' || pg_temp.try(format('update public.stock_receipt_allocations set entered_quantity = 1 where receipt_id = %L', current_setting('t.receipt'))),
  'DKG08 DKG08 DKG08 DKG08', 'a receipt, its lines, an order that received goods and an allocation are never edited or deleted');
select pg_temp.run_as(pg_temp.u(1), format($q$select public.save_stock_item_v1(%L, %L, (select stock_revision from public.services where id = %L), %L, '{"units": [{"unit": "carton", "factor_num": 6, "factor_den": 1}]}'::jsonb)::text$q$,
  pg_temp.u(101), pg_temp.u(301), pg_temp.u(301), pg_temp.u(751)));
select is((select a.factor_num::text || ' ' || a.inventory_quantity::text || ' ' || m.quantity::text from public.stock_receipt_allocations a join public.stock_movements m on m.id = a.movement_id
            where a.order_line_id = (select id from public.purchase_order_lines where order_id = pg_temp.u(501) and line_no = 1)),
  '12 24.000000 24.000000', 'a carton edited to six pieces later cannot reinterpret the delivery already put away');

-- The business's own deletion still removes everything, history included.
alter table public.members disable trigger members_protect_last_owner;
select is(pg_temp.try(format('delete from public.workspaces where id = %L', pg_temp.u(101))), 'ok',
  'deleting the whole business is not blocked by the guards (they yield only to the business itself)');
select is((select count(*) from public.stock_receipt_allocations where workspace_id = pg_temp.u(101))::int + (select count(*) from public.purchase_order_receipts where workspace_id = pg_temp.u(101))::int, 0,
  'and removes its receipts and allocations');
alter table public.members enable trigger members_protect_last_owner;

select * from finish();
rollback;
