-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3824 (0746, 0747; stock S1 of #3823): the goods ledger. Switched on, a
-- business's shelf counts open the ledger; a receipt in, a transfer and a
-- take-out move it through one command; a request id answers twice the
-- same; nothing goes below zero; movements are never edited; balances are
-- the sum of the movements; units convert exactly; the value at a date is
-- quantity times lot cost; another business, a member without the right
-- and a delegated assistant see or move nothing; with the feature off the
-- command refuses and the old shelf count works as before. Rolled back.
begin;
select plan(25);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

-- The answer to a statement run as a person: its value, or ERR, its code
-- and its message.
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare
  v text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate || ' ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

create or replace function pg_temp.refusal(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'no refusal';
exception when others then
  return sqlstate;
end
$f$;

create or replace function pg_temp.loc(p_ws int, p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;

create or replace function pg_temp.on_hand(p_item int, p_code text) returns numeric language sql stable as $f$
  select coalesce(sum(b.quantity), 0) from public.stock_balances b
   where b.item_id = pg_temp.u(p_item) and b.location_id = pg_temp.loc(101, p_code)
$f$;

-- One line of a move, as JSON.
create or replace function pg_temp.line(p_item int, p_qty numeric, p_from text, p_to text,
                                        p_unit text default null, p_extra jsonb default '{}'::jsonb)
returns jsonb language sql stable as $f$
  select jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty,
           'from', pg_temp.loc(101, p_from), 'to', pg_temp.loc(101, p_to))
         || case when p_unit is null then '{}'::jsonb else jsonb_build_object('unit', p_unit) end
         || p_extra
$f$;

create or replace function pg_temp.move(p_request int, p_lines jsonb, p_reason text,
                                        p_at timestamptz default null, p_user int default 1)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format(
    'select public.stock_move_v1(%L, %L, %L::jsonb, %L, %L)::text',
    pg_temp.u(101), pg_temp.u(p_request), p_lines, p_reason, p_at))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- A (101): owner 1, member 2 who may see the stock; B (102): owner 3, on;
-- C (103): owner 4, the feature off.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'stock-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Stock A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": false}', '{"member": ["viewStock", "manageServices"]}'),
  (pg_temp.u(102), 'Stock B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{"stockManagement": true}', '{}'),
  (pg_temp.u(103), 'Stock C', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active'),
  (pg_temp.u(204), pg_temp.u(103), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Water', 100, true, 5, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Wine', 500, true, null, 'l', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Juice', 300, true, null, 'piece', 'lot', true),
  (pg_temp.u(304), pg_temp.u(103), 'Tea', 200, true, 4, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, default_purchase, default_sale) values
  (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1, true, false),
  (pg_temp.u(101), pg_temp.u(302), 'glass', 1, 5, false, true);

-- The feature is switched on: A's places and the opening of its count.
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true}' where id = pg_temp.u(101);
insert into public.stock_locations (workspace_id, kind, code, parent_id)
values (pg_temp.u(101), 'shelf', 'SHELF-A', pg_temp.loc(101, 'MAIN'));

select is((select string_agg(kind || ':' || code, ' ' order by kind) from public.stock_locations
            where workspace_id = pg_temp.u(101) and kind <> 'shelf')
          || ' / ' || pg_temp.on_hand(301, 'MAIN')::text,
  'customer:CUSTOMER loss:LOSS opening:OPENING supplier:SUPPLIER warehouse:MAIN / 5.000000',
  'switched on, the business has its four virtual places and MAIN, and the shelf count is the opening');

-- A receipt in: 2 cartons of 12.
select set_config('t.r1', pg_temp.move(501, jsonb_build_array(pg_temp.line(301, 2, 'SUPPLIER', 'MAIN', 'carton')), 'receipt'), false);
select is(pg_temp.on_hand(301, 'MAIN'), 29.000000::numeric, '2 cartons of 12 received are 24 more on hand');
select is(pg_temp.move(501, jsonb_build_array(pg_temp.line(301, 2, 'SUPPLIER', 'MAIN', 'carton')), 'receipt')
          || ' / ' || pg_temp.on_hand(301, 'MAIN')::text,
          current_setting('t.r1') || ' / 29.000000',
  'the same request id again answers the same and moves nothing');
select ok(pg_temp.move(501, jsonb_build_array(pg_temp.line(301, 3, 'SUPPLIER', 'MAIN', 'carton')), 'receipt') like 'ERR DKG07 %',
  'the same request id for another request is refused with DKG07');

-- A transfer, a take-out.
select pg_temp.move(502, jsonb_build_array(pg_temp.line(301, 10, 'MAIN', 'SHELF-A')), 'transfer');
select is(pg_temp.on_hand(301, 'MAIN')::text || ' ' || pg_temp.on_hand(301, 'SHELF-A')::text,
  '19.000000 10.000000', 'a transfer moves from one place to the other');
select pg_temp.move(503, jsonb_build_array(pg_temp.line(301, 3, 'SHELF-A', 'CUSTOMER')), 'sale');
select is(pg_temp.on_hand(301, 'SHELF-A')::text || ' ' || (select stock from public.services where id = pg_temp.u(301))::text,
  '7.000000 26', 'a take-out leaves the shelf, and the shelf count mirrors the sum over the real places');
select is(left(pg_temp.move(504, jsonb_build_array(pg_temp.line(301, 50, 'SHELF-A', 'CUSTOMER')), 'sale'), 9)
          || ' ' || pg_temp.on_hand(301, 'SHELF-A')::text,
  'ERR DKG03 7.000000', 'a move that would go below zero is refused with DKG03 and moves nothing');

-- Units: 2 litres in, 3 glasses of a fifth of a litre out.
select pg_temp.move(505, jsonb_build_array(pg_temp.line(302, 2, 'SUPPLIER', 'MAIN', 'l')), 'receipt');
select pg_temp.move(506, jsonb_build_array(pg_temp.line(302, 3, 'MAIN', 'CUSTOMER', 'glass')), 'sale');
select is(pg_temp.on_hand(302, 'MAIN'), 1.400000::numeric, '3 glasses of 1/5 litre taken from 2 litres leave 1.4 exactly');
select is(pg_temp.on_hand(302, 'MAIN')::text || ' ' || (select entered_quantity || ' ' || entered_unit
            from public.stock_movements where request_id = pg_temp.u(506)),
  '1.400000 3.000000 glass', 'the movement keeps what was entered beside the converted quantity');
select pg_temp.move(507, jsonb_build_array(pg_temp.line(302, 50, 'SUPPLIER', 'MAIN', 'cl')), 'receipt');
select is(pg_temp.on_hand(302, 'MAIN'), 1.900000::numeric, 'a unit of the same dimension converts by the fixed table');
select ok(pg_temp.move(508, jsonb_build_array(pg_temp.line(302, 1, 'SUPPLIER', 'MAIN', 'carton')), 'receipt') like 'ERR DKG02 %',
  'a unit the item does not list is refused with DKG02');

-- History is never edited.
select is(pg_temp.refusal(format('update public.stock_movements set quantity = 1 where request_id = %L', pg_temp.u(503)))
          || ' ' || pg_temp.refusal(format('delete from public.stock_movements where request_id = %L', pg_temp.u(503))),
  'DKG08 DKG08', 'a movement can be neither edited nor deleted');

-- Two lots at different costs.
select pg_temp.move(509, jsonb_build_array(pg_temp.line(303, 10, 'SUPPLIER', 'MAIN', null,
         '{"new_lot": {"code": "A", "total_cost_minor": 1000}}')), 'receipt', '2026-01-10 10:00+01');
select pg_temp.move(510, jsonb_build_array(pg_temp.line(303, 10, 'SUPPLIER', 'MAIN', null,
         '{"new_lot": {"code": "B", "total_cost_minor": 1500}}')), 'receipt', '2026-02-10 10:00+01');
select ok(pg_temp.move(511, jsonb_build_array(pg_temp.line(303, 5, 'MAIN', 'CUSTOMER')), 'sale') like 'ERR DKG06 %',
  'an item tracked by lot does not leave without its lot');
select pg_temp.move(512, jsonb_build_array(pg_temp.line(303, 5, 'MAIN', 'CUSTOMER', null,
         jsonb_build_object('lot_id', (select id from public.stock_lots where item_id = pg_temp.u(303) and lot_code = 'A')))), 'sale');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select (public.stock_value_at_v1(%L, '2026-01-31 00:00+01') ->> 'total_minor')
            || ' ' || (public.stock_value_at_v1(%L, '2026-03-01 00:00+01') ->> 'total_minor')
            || ' ' || (public.stock_value_at_v1(%L, now()) ->> 'total_minor')$q$, pg_temp.u(101), pg_temp.u(101), pg_temp.u(101))),
  '1000 2500 2000', 'the value at a date is quantity times lot cost over the movements up to it');

-- The balances are the sum of the movements.
select is((select count(*) from public.stock_balances b
            where b.workspace_id = pg_temp.u(101)
              and b.quantity <> coalesce((select sum(case when m.to_location_id = b.location_id then m.quantity else -m.quantity end)
                                            from public.stock_movements m
                                           where m.item_id = b.item_id and m.lot_id is not distinct from b.lot_id
                                             and b.location_id in (m.from_location_id, m.to_location_id)), 0)),
  0::bigint, 'after the mixed sequence every balance is the sum of its movements');

-- Who sees and moves it.
select is(pg_temp.run_as(pg_temp.u(2), format('select count(*) from public.stock_movements where workspace_id = %L', pg_temp.u(101)))
          || ' ' || pg_temp.run_as(pg_temp.u(3), format('select count(*) from public.stock_movements where workspace_id = %L', pg_temp.u(101)))
          || ' ' || pg_temp.run_as(pg_temp.u(3), format('select count(*) from public.stock_balances where workspace_id = %L', pg_temp.u(101))),
  (select count(*) from public.stock_movements where workspace_id = pg_temp.u(101))::text || ' 0 0',
  'a member who may see the stock reads it; another business sees none of its rows');
select is(pg_temp.run_as(pg_temp.u(1), format('select count(*) from public.stock_movements where workspace_id = %L', pg_temp.u(101)), true)
          || ' ' || pg_temp.run_as(pg_temp.u(1), format('select count(*) from public.stock_locations where workspace_id = %L', pg_temp.u(101)), true),
  '0 0', 'a delegated assistant session reads nothing of the ledger');
select ok(pg_temp.move(513, jsonb_build_array(pg_temp.line(301, 1, 'MAIN', 'SHELF-A')), 'transfer', null, 2) like 'ERR DKN01 %',
  'a member without manageStock moves nothing (DKN01)');

select is(left(pg_temp.run_as(pg_temp.u(2), format('update public.services set stock = 99 where id = %L returning stock::text', pg_temp.u(301))), 9)
          || ' ' || (select stock from public.services where id = pg_temp.u(301))::text,
  'ERR DKN01 26', 'a member who edits the catalogue but may not move stock cannot change a count');
select is(pg_temp.refusal(format($q$update public.services set inventory_unit = 'kg' where id = %L$q$, pg_temp.u(301)))
          || ' ' || pg_temp.refusal(format($q$update public.services set tracking = 'lot' where id = %L$q$, pg_temp.u(301))),
  'DKG08 DKG08', 'an item with movements keeps the unit and the tracking its history was written in');

-- With the feature off.
select is(left(pg_temp.run_as(pg_temp.u(4), format($q$select public.stock_move_v1(%L, %L, '[]'::jsonb, 'receipt')::text$q$, pg_temp.u(103), pg_temp.u(514))), 9)
          || ' ' || left(pg_temp.run_as(pg_temp.u(4), format('select public.stock_on_hand_v1(%L)::text', pg_temp.u(103))), 9),
  'ERR DKG01 ERR DKG01', 'with stockManagement off the command and the reads refuse with DKG01');
select pg_temp.run_as(pg_temp.u(4), format('select public.record_service_charge(%L, %L, %L, 1)::text',
         pg_temp.u(103), pg_temp.u(204), pg_temp.u(304)));
update public.events set status = 'confirmed'
 where workspace_id = pg_temp.u(103) and type = 'service_charge' and status <> 'confirmed';
select is((select stock from public.services where id = pg_temp.u(304))::text || ' '
          || (select count(*) from public.stock_movements where workspace_id = pg_temp.u(103))::text,
  '3 0', 'with the feature off a confirmed charge lowers the shelf count as before, and no ledger is written');

-- With it on, the old count is the ledger's.
select pg_temp.run_as(pg_temp.u(1), format('select public.record_service_charge(%L, %L, %L, 2)::text',
         pg_temp.u(101), pg_temp.u(201), pg_temp.u(301)));
update public.events set status = 'confirmed'
 where workspace_id = pg_temp.u(101) and type = 'service_charge' and status <> 'confirmed';
select is((select stock from public.services where id = pg_temp.u(301))::text || ' '
          || pg_temp.on_hand(301, 'MAIN')::text || ' '
          || (select count(*) from public.stock_movements m join public.events e on e.id = m.event_id
               where m.item_id = pg_temp.u(301) and m.reason = 'sale')::text,
  '24 17.000000 1', 'a confirmed charge is a sale out of MAIN, linked to its event, and the count follows');
select ok(pg_temp.run_as(pg_temp.u(1), format('select public.record_service_charge(%L, %L, %L, 500)::text',
         pg_temp.u(101), pg_temp.u(201), pg_temp.u(301))) like '%out of stock: 24 left%',
  'an empty shelf refuses as before');
update public.services set stock = 30 where id = pg_temp.u(301);
select is((select stock from public.services where id = pg_temp.u(301))::text || ' ' || pg_temp.on_hand(301, 'MAIN')::text
          || ' ' || (select string_agg(reason || ':' || quantity, ',') from public.stock_movements
                      where item_id = pg_temp.u(301) and from_location_id = pg_temp.loc(101, 'LOSS')),
  '30 23.000000 adjustment:6.000000', 'an edited count is an adjustment from the loss place, and the count still mirrors the ledger');

select * from finish();
rollback;
