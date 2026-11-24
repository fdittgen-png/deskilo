-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4435 (0930): repack and the reads of handling units. A repack takes content out of units (or loose stock) and makes the store's own units from
-- it, at one place: what goes out equals what comes in per item, variant and lot, the pieces are the same pieces, the on-hand total never changes,
-- and the provenance finds a lot on both sides; the reads page, show a unit with its content and pieces, and are for whoever sees the stock. Rolled back.
begin;
select plan(20);

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
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hr-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Repack A', 'FR', 'EUR', 'Europe/Paris',
   pg_temp.u(1), '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockHandlingUnits": true}', '{"admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Repack B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"services": true, "stockManagement": true}', '{}');
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
select pg_temp.make(3, 920, format('{"code": "P1", "kind": "pallet", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "24"}]}', pg_temp.loc('MAIN'), pg_temp.u(304), pg_temp.lot('W1')));
select pg_temp.make(3, 921, format('{"code": "C1", "kind": "carton", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "2", "units": [{"piece_id": "%s"}, {"piece_id": "%s"}]}]}',
  pg_temp.loc('MAIN'), pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(1), pg_temp.piece(2)));

-- one pallet of 24 into four boxes of 6
create or replace function pg_temp.w(p_qty int) returns text language sql stable as $f$
  select format('[{"item_id": "%s", "lot_id": "%s", "quantity": "%s"}]', pg_temp.u(304), pg_temp.lot('W1'), p_qty)
$f$;
grant execute on function pg_temp.w(int) to authenticated, anon;
select set_config('t.src', format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "24"}]', pg_temp.uid('P1'), pg_temp.u(304), pg_temp.lot('W1')), false);
select set_config('t.tgt', '[' || pg_temp.box('B1', pg_temp.w(6)) || ',' || pg_temp.box('B2', pg_temp.w(6)) || ',' || pg_temp.box('B3', pg_temp.w(6)) || ',' || pg_temp.box('B4', pg_temp.w(6)) || ']', false);
select set_config('t.r1', pg_temp.repack(3, 930, current_setting('t.src'), current_setting('t.tgt')), false);
select is(jsonb_array_length(current_setting('t.r1')::jsonb -> 'units'), 4, 'a pallet is repacked into four boxes');
select is((select state from public.stock_handling_units where id = pg_temp.uid('P1')) || ' ' || pg_temp.bal(304, 'MAIN'), 'unpacked 24.000000', 'the emptied pallet is unpacked and the on-hand total is unchanged');
select is((select sum(l.quantity) from public.stock_handling_unit_lines l join public.stock_handling_units u on u.id = l.unit_id where u.state = 'open' and l.item_id = pg_temp.u(304)), 24.000000, 'the boxes hold the 24');
select is(left(pg_temp.repack(3, 931, format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "6"}]', pg_temp.uid('B1'), pg_temp.u(304), pg_temp.lot('W1')),
  '[' || pg_temp.box('B5', pg_temp.w(5)) || ']'), 9), 'ERR DKG28', 'what goes in must equal what came out: 6 out, 5 in is refused');
select is((select quantity from public.stock_handling_unit_lines where unit_id = pg_temp.uid('B1')), 6.000000, 'and nothing of the refused repack stays');
select is(left(pg_temp.repack(3, 932, format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "7"}]', pg_temp.uid('B1'), pg_temp.u(304), pg_temp.lot('W1')),
  '[' || pg_temp.box('B6', pg_temp.w(7)) || ']'), 9), 'ERR DKG28', 'a box that holds 6 cannot give 7');
select is(pg_temp.repack(3, 930, current_setting('t.src'), current_setting('t.tgt'))::jsonb, current_setting('t.r1')::jsonb, 'the same request answers the same repack');
select is((select count(*)::int from public.stock_repacks where workspace_id = pg_temp.u(101)), 1, 'and one repack exists');

-- loose stock into a box
select is(jsonb_array_length(pg_temp.repack(3, 933, format('[{"item_id": "%s", "quantity": "4", "location_id": "%s"}]', pg_temp.u(306), pg_temp.loc('MAIN')),
  '[' || pg_temp.box('S1', format('[{"item_id": "%s", "quantity": "4"}]', pg_temp.u(306))) || ']')::jsonb -> 'units'), 1, 'loose salt goes into a store box');
select is(left(pg_temp.repack(3, 934, format('[{"item_id": "%s", "quantity": "7", "location_id": "%s"}]', pg_temp.u(306), pg_temp.loc('MAIN')),
  '[' || pg_temp.box('S2', format('[{"item_id": "%s", "quantity": "7"}]', pg_temp.u(306))) || ']'), 9), 'ERR DKG03', 'only 6 of the salt is still loose');

-- a piece out of a carton into a box of its own; the pieces taken are the pieces put in
select is(jsonb_array_length(pg_temp.repack(3, 935,
  format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "1", "units": [{"piece_id": "%s"}]}]', pg_temp.uid('C1'), pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(1)),
  '[' || pg_temp.box('K1', format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "units": [{"piece_id": "%s"}]}]', pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(1))) || ']')::jsonb -> 'units'), 1, 'one basket leaves the carton for a box of its own');
select is((select count(*)::int from public.stock_handling_unit_pieces p join public.stock_handling_unit_lines l on l.id = p.unit_line_id where l.unit_id = pg_temp.uid('K1') and p.piece_id = pg_temp.piece(1)), 1, 'the box holds that very piece');
select is(left(pg_temp.repack(3, 936,
  format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "1", "units": [{"piece_id": "%s"}]}]', pg_temp.uid('C1'), pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(2)),
  '[' || pg_temp.box('K2', format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "units": [{"piece_id": "%s"}]}]', pg_temp.u(303), pg_temp.lot('B1'), pg_temp.piece(3))) || ']'), 9), 'ERR DKG28', 'another piece cannot be slipped in for the one taken out');
select is(left(pg_temp.repack(3, 937, format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "6"}]', pg_temp.uid('B2'), pg_temp.u(304), pg_temp.lot('W1')),
  '[' || pg_temp.box('B7', pg_temp.w(6), 'FLOOR') || ']'), 9), 'ERR DKG28', 'a repack happens at one place: a target at another place is refused');

-- a lot followed through the repack is found on both sides
select is((select count(*)::int from jsonb_array_elements(pg_temp.run_as(pg_temp.u(3), format('select public.stock_hu_lot_trace_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(304), pg_temp.lot('W1')))::jsonb -> 'repacks')), 5, 'a lot is found in one out line (the pallet) and four in lines (the boxes)');

-- reads: a page in code order, a unit with its content
select is(pg_temp.run_as(pg_temp.u(3), format('select (select string_agg(r ->> ''code'', '','' order by r ->> ''code'') from jsonb_array_elements(public.stock_hu_page_v1(%L) -> ''rows'') r)', pg_temp.u(101))), 'B1,B2,B3,B4,C1,K1,S1', 'the open units are listed by code');
select is(pg_temp.run_as(pg_temp.u(3), format('select (public.stock_hu_v1(%L, %L) -> ''lines'' -> 0 ->> ''lot_code'') || '' '' || (public.stock_hu_v1(%L, %L) -> ''lines'' -> 0 ->> ''quantity'')', pg_temp.u(101), pg_temp.uid('B1'), pg_temp.u(101), pg_temp.uid('B1'))), 'W1 6.000000', 'a unit shows its content with the lot');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.stock_hu_page_v1(%L)::text', pg_temp.u(101))), 9), 'ERR DKN01', 'a member who may not see the stock reads nothing');

select is(left(pg_temp.repack(3, 938, format('[{"item_id": "%s", "quantity": "1", "location_id": "%s"}]', pg_temp.u(306), pg_temp.loc('MAIN')),
  '[' || pg_temp.box('S3', format('[{"item_id": "%s", "quantity": "1"}]', pg_temp.u(306))) || ']', true), 9), 'ERR DKN01', 'an assistant session is refused');
select is(pg_temp.run_as(pg_temp.u(4), format('select public.stock_hu_page_v1(%L)::text', pg_temp.u(102)))::jsonb, '{"next": null, "rows": [], "complete": true}'::jsonb, 'with the feature off the page is empty, not an error');

select * from finish();
rollback;
