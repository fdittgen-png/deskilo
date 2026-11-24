-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4435 (0928-0931): the journey of the acceptance. Receive two pallets of one lot, move one, repack the other into store boxes, follow the lot
-- through the repack, and two people moving the same unit: the second is refused and told where it is. The ledger total never changes by a
-- repack and every move goes through the one stock path. Rolled back.
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

create or replace function pg_temp.repack(p_user int, p_req int, p_sources text, p_targets text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.hu(p_user, 'stock_hu_repack_v1', format('%L, %L::jsonb, %L::jsonb', pg_temp.u(p_req), p_sources, p_targets), 101, p_delegated)
$f$;
grant execute on function pg_temp.repack(int, int, text, text, boolean) to authenticated, anon;
create or replace function pg_temp.box(p_code text, p_lines text, p_loc text default 'MAIN') returns text language sql as $f$
  select format('{"code": "%s", "kind": "box", "location_id": "%s", "lines": %s}', p_code, pg_temp.loc(p_loc), p_lines)
$f$;
grant execute on function pg_temp.box(text, text, text) to authenticated, anon;
create or replace function pg_temp.piece(p_n int) returns uuid language sql stable as $f$
  select pc.id from public.stock_tagged_units pc where pc.workspace_id = pg_temp.u(101) and pc.item_id = pg_temp.u(303) order by pc.id limit 1 offset (p_n - 1)
$f$;
create or replace function pg_temp.lot(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = p_code
$f$;
grant execute on function pg_temp.piece(int), pg_temp.lot(text) to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hj-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Journey A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockHandlingUnits": true}', '{"admin": ["manageStock"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(304), pg_temp.u(101), 'Water', 100, true, 'piece', 'lot', true);
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR');
select pg_temp.mv(3, 910, format('[{"item_id": "%s", "quantity": "80", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 8000, "code": "W1"}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
create or replace function pg_temp.lot(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = p_code
$f$;
create or replace function pg_temp.line(p_qty int) returns text language sql stable as $f$
  select format('[{"item_id": "%s", "lot_id": "%s", "quantity": "%s"}]', pg_temp.u(304), pg_temp.lot('W1'), p_qty)
$f$;
grant execute on function pg_temp.lot(text), pg_temp.line(int) to authenticated, anon;

-- two pallets of 40, as delivered
select pg_temp.make(3, 920, format('{"code": "PAL-1", "kind": "pallet", "label_code": "SSCC-001", "location_id": "%s", "lines": %s}', pg_temp.loc('MAIN'), pg_temp.line(40)));
select pg_temp.make(3, 921, format('{"code": "PAL-2", "kind": "pallet", "label_code": "SSCC-002", "location_id": "%s", "lines": %s}', pg_temp.loc('MAIN'), pg_temp.line(40)));
select is((select count(*)::int from public.stock_handling_units where workspace_id = pg_temp.u(101) and state = 'open'), 2, 'two pallets were received as delivered, each with the supplier''s label');

-- one pallet moves; two people try to move it at once: the first wins, the second is told where it went
select pg_temp.move(3, 930, 'PAL-1', 'FLOOR', 1);
select is(pg_temp.bal(304, 'FLOOR') || '/' || pg_temp.bal(304, 'MAIN'), '40.000000/40.000000', 'one pallet moved to the FLOOR through the stock path');
select is(left(pg_temp.move(4, 931, 'PAL-1', 'MAIN', 1), 9), 'ERR DKG27', 'the second person moving the same unit with the revision they saw is refused');
select is((select count(*)::int from public.stock_movement_handling_units where unit_id = pg_temp.uid('PAL-1')) > 0, true, 'and the trace names the unit the movement carried');

-- the other pallet is repacked into forty store boxes of one: the lot is found through it
select set_config('t.tgt', (select jsonb_agg(jsonb_build_object('code', 'BOX-' || lpad(n::text, 2, '0'), 'kind', 'box', 'location_id', pg_temp.loc('MAIN'),
   'lines', jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(304), 'lot_id', pg_temp.lot('W1'), 'quantity', '1'))))::text from generate_series(1, 40) n), false);
select pg_temp.repack(3, 932, format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "40"}]', pg_temp.uid('PAL-2'), pg_temp.u(304), pg_temp.lot('W1')), current_setting('t.tgt'));
select is((select count(*)::int from public.stock_handling_units where workspace_id = pg_temp.u(101) and kind = 'box' and state = 'open'), 40, 'the pallet became forty store boxes');
select is(pg_temp.bal(304, 'MAIN') || '/' || pg_temp.bal(304, 'FLOOR'), '40.000000/40.000000', 'the repack changed no balance');
select is((select (jsonb_array_length(t -> 'held') || '/' || jsonb_array_length(t -> 'repacks'))
  from (select pg_temp.run_as(pg_temp.u(3), format('select public.stock_hu_lot_trace_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(304), pg_temp.lot('W1')))::jsonb as t) x),
  '41/41', 'the lot is found in 41 units (the moved pallet and the 40 boxes) and in the repack: one line out, forty in');

select * from finish();
rollback;
