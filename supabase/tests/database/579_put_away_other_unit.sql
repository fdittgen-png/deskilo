-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's
-- #4479 (0972): a delivery is put away in any unit the item converts from, not only in the unit of its order line. Water is counted in
-- pieces and ordered by the carton of 12: 24 pieces put away against a line of 2 cartons are 2 cartons against the line, the order price
-- (per carton) is applied to those 2, the allocation freezes the unit it was entered in, a piece too many is over-allocated, a kilo has no
-- conversion (unit_unmapped), and an allocation with no unit is in the line's unit as before. Rolled back.
begin;
select plan(7);

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
       'putaway-unit-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Put away units', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name) values (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Water Co');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Water', 100, true, null, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1);
insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, created_by_member_id) values
  (pg_temp.u(501), pg_temp.u(101), 2026, 1, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(502), pg_temp.u(101), 2026, 2, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201));
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents) values
  (pg_temp.u(101), pg_temp.u(501), 1, pg_temp.u(301), '', 2, 'carton', 1200),
  (pg_temp.u(101), pg_temp.u(502), 1, pg_temp.u(301), '', 2, 'carton', 1200);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where workspace_id = pg_temp.u(101);
select set_config('t.main', pg_temp.loc('MAIN')::text, false);

-- 24 pieces against a line of 2 cartons: received as 2 cartons, put away as 24 pieces; the order price is per carton
select is((pg_temp.combined(1, 701, 501, '[{"line_no": 1, "quantity": 2}]',
  '[' || pg_temp.alloc(1, 24, current_setting('t.main'), ', "unit": "piece", "cost": {"state": "order_price"}') || ']')::jsonb -> 'allocations' -> 0 ->> 'inventory_quantity'),
  '24.000000', 'a line of 2 cartons is put away as 24 pieces: 24 on hand');
select is((select entered_unit || ' ' || entered_quantity::text || ' ' || factor_num::text || '/' || factor_den::text
             from public.stock_receipt_allocations where order_line_id = (select id from public.purchase_order_lines where order_id = pg_temp.u(501))),
  'piece 24.000000 1/1', 'the allocation freezes the unit it was entered in, with its own factor');
select is((select l.total_cost_minor::text from public.stock_lots l join public.stock_receipt_allocations x on x.lot_id = l.id
               where x.order_line_id = (select id from public.purchase_order_lines where order_id = pg_temp.u(501))), '2400',
  'the order price per carton is applied to the 2 cartons, not to 24 pieces');
select set_config('t.receipt', (select id::text from public.purchase_order_receipts where order_id = pg_temp.u(501)), false);
select alike(pg_temp.putaway(1, 702, current_setting('t.receipt')::uuid, '[' || pg_temp.alloc(1, 1, current_setting('t.main'), ', "unit": "piece"') || ']'),
  'ERR DKG11%over_allocated%', 'a piece more than the 2 cartons received is over-allocated');

-- the other order: half in pieces, then a carton, then a piece too many
select pg_temp.combined(1, 703, 502, '[{"line_no": 1, "quantity": 2}]', '[' || pg_temp.alloc(1, 12, current_setting('t.main'), ', "unit": "piece"') || ']');
select set_config('t.receipt2', (select id::text from public.purchase_order_receipts where order_id = pg_temp.u(502)), false);
select is((pg_temp.putaway(1, 704, current_setting('t.receipt2')::uuid, '[' || pg_temp.alloc(1, 1, current_setting('t.main'), ', "unit": "carton"') || ']')::jsonb -> 'allocations' -> 0 ->> 'inventory_quantity'),
  '12.000000', '12 pieces then 1 carton make the 2 cartons: the carton is 12 pieces');
select alike(pg_temp.putaway(1, 705, current_setting('t.receipt2')::uuid, '[' || pg_temp.alloc(1, 1, current_setting('t.main'), ', "unit": "piece"') || ']'),
  'ERR DKG11%over_allocated%', 'and one piece more is refused');
select alike(pg_temp.putaway(1, 706, current_setting('t.receipt2')::uuid, '[' || pg_temp.alloc(1, 1, current_setting('t.main'), ', "unit": "kg"') || ']'),
  'ERR DKG11%unit_unmapped%', 'a kilo of water has no conversion: refused, naming the unit');

select * from finish();
rollback;
