-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4435 (0928, 0929): handling units. A unit is made at a place from loose stock (never more than is loose, a piece in one unit only), moved with
-- its whole content in one request through the one stock path (lots and pieces kept, the ledger and the unit agreeing), refused when it
-- changed under the caller, unpacked loose, nested one level; whoever manages the stock acts, never an assistant. Rolled back.
begin;
select plan(25);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.today() returns date language sql stable as $f$
  select public.workspace_today(pg_temp.u(101))
$f$;
create or replace function pg_temp.day(p_offset int) returns text language sql stable as $f$
  select to_char(pg_temp.today() + p_offset, 'YYYY-MM-DD')
$f$;
create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
-- the report as a member reads it: scope, horizon, place, group, limit, cursor

create or replace function pg_temp.uid(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_handling_units where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.rev(p_code text) returns int language sql stable as $f$
  select revision from public.stock_handling_units where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.hu(p_user int, p_fn text, p_args text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.%s(%L, %s)::text', p_fn, pg_temp.u(p_ws), p_args), p_delegated)
$f$;
create or replace function pg_temp.make(p_user int, p_req int, p_unit text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.hu(p_user, 'stock_hu_make_v1', format('%L, %L::jsonb', pg_temp.u(p_req), p_unit), 101, p_delegated)
$f$;
create or replace function pg_temp.move(p_user int, p_req int, p_code text, p_to text, p_rev int default null, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.hu(p_user, 'stock_hu_move_v1', format('%L, %L, %L, %s', pg_temp.u(p_req), pg_temp.uid(p_code), pg_temp.loc(p_to), coalesce(p_rev::text, 'null')), 101, p_delegated)
$f$;
create or replace function pg_temp.unpack(p_user int, p_req int, p_code text, p_rev int default null) returns text language sql as $f$
  select pg_temp.hu(p_user, 'stock_hu_unpack_v1', format('%L, %L, %s', pg_temp.u(p_req), pg_temp.uid(p_code), coalesce(p_rev::text, 'null')))
$f$;
create or replace function pg_temp.bal(p_item int, p_loc text) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(p_item) and location_id = pg_temp.loc(p_loc)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hu-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Units A', 'FR', 'EUR', 'Europe/Paris',
   pg_temp.u(1), '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockHandlingUnits": true}', '{"admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Units B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit'),
  (pg_temp.u(304), pg_temp.u(101), 'Water', 100, true, 'piece', 'lot', true, null),
  (pg_temp.u(306), pg_temp.u(101), 'Salt', 50, true, 'piece', 'none', true, null);
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR');

select pg_temp.mv(3, 910, format('[{"item_id": "%s", "quantity": "24", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 2400, "code": "W1"}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select pg_temp.mv(3, 911, format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s"}]',
  pg_temp.u(306), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select pg_temp.mv(3, 912, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}, {"tag": "E28068940000401561D68F02"}, {"tag": "E28068940000401561D68F03"}], "new_lot": {"total_cost_minor": 3000, "code": "B1"}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
create or replace function pg_temp.piece(p_n int) returns uuid language sql stable as $f$
  select pc.id from public.stock_tagged_units pc where pc.workspace_id = pg_temp.u(101) and pc.item_id = pg_temp.u(303) order by pc.id limit 1 offset (p_n - 1)
$f$;
grant execute on function pg_temp.piece(int) to authenticated, anon;
create or replace function pg_temp.lot(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = p_code
$f$;
grant execute on function pg_temp.lot(text) to authenticated, anon;

-- a pallet of 12 water (lot W1) at MAIN
select set_config('t.p1', pg_temp.make(3, 920, format('{"code": "P1", "kind": "pallet", "label_code": "SSCC-1", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "12"}]}', pg_temp.loc('MAIN'), pg_temp.u(304), pg_temp.lot('W1'))), false);
select is((current_setting('t.p1')::jsonb -> 'unit' ->> 'code') || ' ' || (current_setting('t.p1')::jsonb -> 'unit' ->> 'revision'), 'P1 1', 'a pallet is made at a place from loose stock: its code, revision 1');
select is(pg_temp.make(3, 920, format('{"code": "P1", "kind": "pallet", "label_code": "SSCC-1", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "12"}]}', pg_temp.loc('MAIN'), pg_temp.u(304), pg_temp.lot('W1')))::jsonb, current_setting('t.p1')::jsonb, 'the same request answers the same unit and makes no second one');
select is((select count(*)::int from public.stock_handling_units where workspace_id = pg_temp.u(101)), 1, 'one unit exists');
select is(left(pg_temp.make(3, 921, format('{"code": "P2", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "13"}]}', pg_temp.loc('MAIN'), pg_temp.u(304), pg_temp.lot('W1'))), 9), 'ERR DKG03', 'only the loose stock can be claimed: 24 minus the 12 in the pallet leaves 12, not 13');
select is(left(pg_temp.make(3, 922, format('{"code": "p1", "location_id": "%s", "lines": [{"item_id": "%s", "quantity": "1"}]}', pg_temp.loc('MAIN'), pg_temp.u(306))), 9), 'ERR DKG29', 'a unit code is unique in the business, whatever its case');
select is(left(pg_temp.make(3, 923, format('{"code": "P3", "location_id": "%s", "lines": [{"item_id": "%s", "quantity": "1"}]}', pg_temp.loc('MAIN'), pg_temp.u(304))), 9), 'ERR DKG28', 'a lot-tracked item is claimed with its lot');
select is(left(pg_temp.make(3, 924, format('{"code": "P4", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "2"}]}', pg_temp.loc('MAIN'), pg_temp.u(303), pg_temp.lot('B1'))), 9), 'ERR DKG28', 'a piece-tracked line names its pieces');

-- a carton: two baskets and four salts
select set_config('t.c1', pg_temp.make(3, 925, format('{"code": "C1", "kind": "carton", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "2", "units": [{"piece_id": "%s"}, {"piece_id": "%s"}]}, {"item_id": "%s", "quantity": "4"}]}',
  pg_temp.loc('MAIN'), pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(1), pg_temp.piece(2), pg_temp.u(306))), false);
select is(current_setting('t.c1')::jsonb -> 'unit' ->> 'code', 'C1', 'a carton holds pieces and a plain quantity');
select is(left(pg_temp.make(3, 926, format('{"code": "C2", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "1", "units": [{"piece_id": "%s"}]}]}', pg_temp.loc('MAIN'), pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(1))), 9), 'ERR DKG28', 'a piece already in a unit is in no other');
select is(left(pg_temp.make(3, 927, format('{"code": "C3", "location_id": "%s", "lines": [{"item_id": "%s", "quantity": "7"}]}', pg_temp.loc('MAIN'), pg_temp.u(306))), 9), 'ERR DKG03', 'salt: 10 minus the 4 in the carton leaves 6, not 7');

-- the pallet moves to the FLOOR in one request: the ledger and the unit agree
select set_config('t.m1', pg_temp.move(3, 930, 'P1', 'FLOOR', 1), false);
select is(pg_temp.bal(304, 'FLOOR') || '/' || pg_temp.bal(304, 'MAIN'), '12.000000/12.000000', 'the pallet moved its 12 waters to the FLOOR through the stock path; 12 stay at MAIN');
select is((select location_id from public.stock_handling_units where id = pg_temp.uid('P1')) = pg_temp.loc('FLOOR') and pg_temp.rev('P1') = 2, true, 'the unit is at the FLOOR, revision 2');
select is((select count(*)::int from public.stock_movement_handling_units where unit_id = pg_temp.uid('P1')) > 0, true, 'its movements are linked to it');
select is(left(pg_temp.move(3, 931, 'P1', 'MAIN', 1), 9), 'ERR DKG27', 'a second person with the old revision is refused: the unit moved');
select is((regexp_match(pg_temp.move(3, 932, 'P1', 'MAIN', 1), 'revision": ?(\d+)'))[1], '2', 'and told its new revision');
select is(pg_temp.move(3, 930, 'P1', 'FLOOR', 1)::jsonb, current_setting('t.m1')::jsonb, 'the same request answers the same result and moves nothing twice');
select is(left(pg_temp.move(3, 933, 'P1', 'FLOOR', 2), 9), 'ERR DKG28', 'a unit is not moved to where it is');

-- the carton moves with its pieces
select pg_temp.move(3, 934, 'C1', 'FLOOR', 1);
select is((select count(*)::int from public.stock_tagged_units where id in (pg_temp.piece(1), pg_temp.piece(2)) and location_id = pg_temp.loc('FLOOR')), 2, 'the carton''s two pieces are at the FLOOR, the third stays at MAIN');
select is(pg_temp.bal(306, 'FLOOR'), 4.000000, 'and its four salts');

-- the unit never claims more than the ledger holds
select is((select count(*)::int from (
  select l.item_id, l.lot_id, u.location_id, sum(l.quantity) q from public.stock_handling_unit_lines l join public.stock_handling_units u on u.id = l.unit_id
   where u.state = 'open' and l.workspace_id = pg_temp.u(101) group by 1, 2, 3) x
  where x.q > coalesce((select sum(b.quantity) from public.stock_balances b where b.item_id = x.item_id and b.lot_id is not distinct from x.lot_id and b.location_id = x.location_id), 0)), 0, 'no place holds a unit''s claim larger than its balance');

-- unpack: the content is loose at the place
select pg_temp.unpack(3, 935, 'C1', 2);
select is((select state from public.stock_handling_units where id = pg_temp.uid('C1')) || ' ' || (select count(*)::int from public.stock_handling_unit_lines where unit_id = pg_temp.uid('C1')) || ' ' || pg_temp.bal(306, 'FLOOR'), 'unpacked 0 4.000000', 'an unpacked unit holds nothing and the ledger is unchanged');
select is(left(pg_temp.move(3, 936, 'C1', 'MAIN', 3), 9), 'ERR DKG27', 'an unpacked unit is not moved');

-- who may act
select is(left(pg_temp.move(2, 937, 'P1', 'MAIN', 2), 9), 'ERR DKN01', 'a member who may not manage the stock is refused');
select is(left(pg_temp.move(3, 938, 'P1', 'MAIN', 2, true), 9), 'ERR DKN01', 'an assistant session is refused');
select is(left(pg_temp.hu(4, 'stock_hu_make_v1', format('%L, %L::jsonb', pg_temp.u(939), '{"code": "X", "location_id": "00000000-0000-4000-8000-000000000001", "lines": [{"item_id": "00000000-0000-4000-8000-000000000001", "quantity": "1"}]}'), 102), 9), 'ERR DKG01', 'with the feature off nothing is made');

select * from finish();
rollback;
