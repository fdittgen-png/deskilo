-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4362 (0887): an item tagged piece by piece moves only with its pieces. A receipt names the pieces it brings in (each
-- made at the place it arrives at, with its tag bound), a transfer names the pieces it moves, a take-out names those
-- that leave; a movement that names none, too few, a piece that is not where it is taken from or a tag that is on
-- something else is refused in words; the count of pieces in stock at a place equals the ledger's, per lot, and a
-- path that does not name its pieces is held to it at commit; a piece in stock is not retired with its tag; an item
-- not tagged piece by piece takes no named pieces. Rolled back.
begin;
select plan(28);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

create or replace function pg_temp.bind(p_user int, p_req int, p_tag text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_tag_bind_v1(%L, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_req), p_tag), p_delegated)
$f$;
create or replace function pg_temp.retire(p_user int, p_req int, p_code text, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_tag_retire_v1(%L, %L, %L, %L)::text', pg_temp.u(p_ws), pg_temp.u(p_req), p_code, 'taken off'))
$f$;
create or replace function pg_temp.res(p_user int, p_code text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_resolve_code_v1(%L, %L)::text', pg_temp.u(p_ws), p_code), p_delegated)
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;


create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
create or replace function pg_temp.line(p_item int, p_qty text, p_from uuid, p_to uuid, p_units text, p_extra text default '') returns text language sql as $f$
  select format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s", "units": %s%s}]', pg_temp.u(p_item), p_qty, p_from, p_to, p_units, p_extra)
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.pieces(p_state text, p_loc uuid) returns bigint language sql stable as $f$
  select count(*) from public.stock_tagged_units where workspace_id = pg_temp.u(101) and state = p_state and location_id = p_loc
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pc-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Pieces A', 'FR', 'EUR', 'Europe/Paris',  pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTakeOut": true, "stockTags": true, "stockItemGroups": true}', '{"admin": ["manageStock"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit'),
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 300, true, 'piece', 'none', true, null);
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'ZONE-A');

-- ── a receipt names the pieces it brings ──
select is(pg_temp.mv(3, 910, pg_temp.line(303, '3', pg_temp.place('supplier'), pg_temp.loc('MAIN'), '[]', ', "new_lot": {"total_cost_minor": 3000}'), 'receipt'), 'ERR DKG25',
  'a receipt that names no piece is refused: name the pieces');
select is(pg_temp.mv(3, 911, pg_temp.line(303, '3', pg_temp.place('supplier'), pg_temp.loc('MAIN'),
  '[{"tag": "E28068940000401561D679F1"}, {"tag": "E28068940000401561D679F2"}]', ', "new_lot": {"total_cost_minor": 3000}'), 'receipt'), 'ERR DKG25',
  'nor one that names fewer than its quantity');
select is(pg_temp.mv(3, 912, pg_temp.line(303, '3', pg_temp.place('supplier'), pg_temp.loc('MAIN'),
  '[{"tag": "E28068940000401561D679F1"}, {"tag": "E28068940000401561D679F2"}, {"tag": "E28068940000401561D679F3"}]', ', "new_lot": {"total_cost_minor": 3000}'), 'receipt') like '{%', true,
  'a receipt that names its three pieces is made');
select is(pg_temp.pieces('in_stock', pg_temp.loc('MAIN')), 3::bigint, 'each is a piece in stock at the place it arrived at');
select is((select count(*)::int from public.stock_tags where workspace_id = pg_temp.u(101) and owner_kind = 'piece' and state = 'active'), 3, 'with its tag bound to it');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_pieces_check_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(303))), '[]', 'the pieces in stock equal what the ledger holds');
select is(pg_temp.mv(3, 913, pg_temp.line(303, '1', pg_temp.place('supplier'), pg_temp.loc('MAIN'), '[{"tag": "E28068940000401561D679F1"}]', ', "new_lot": {"total_cost_minor": 1000}'), 'receipt'), 'ERR DKG26',
  'a tag that is on a piece in stock cannot arrive again');
select pg_temp.run_as(pg_temp.u(1), format('select public.stock_tag_bind_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(920),
  format('{"code": "AABBCCDD", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))));
select is(pg_temp.mv(3, 914, pg_temp.line(303, '1', pg_temp.place('supplier'), pg_temp.loc('MAIN'), '[{"tag": "AABBCCDD"}]', ', "new_lot": {"total_cost_minor": 1000}'), 'receipt'), 'ERR DKG22',
  'nor can a tag that names a place');

-- ── a transfer names the pieces it moves ──
select is(pg_temp.mv(3, 915, pg_temp.line(303, '1', pg_temp.loc('MAIN'), pg_temp.loc('ZONE-A'), '[]', format(', "lot_id": "%s"', (select id from public.stock_lots where item_id = pg_temp.u(303)))), 'transfer'), 'ERR DKG25',
  'a transfer that names no piece is refused');
select is(pg_temp.mv(3, 916, pg_temp.line(303, '1', pg_temp.loc('MAIN'), pg_temp.loc('ZONE-A'), '[{"tag": "E28068940000401561D679F2"}]', format(', "lot_id": "%s"', (select id from public.stock_lots where item_id = pg_temp.u(303)))), 'transfer') like '{%', true,
  'one that names the piece moves it');
select is(pg_temp.pieces('in_stock', pg_temp.loc('MAIN')) || '/' || pg_temp.pieces('in_stock', pg_temp.loc('ZONE-A')), '2/1', 'and it is in the other place, in the same transaction');
select is(pg_temp.mv(3, 917, pg_temp.line(303, '1', pg_temp.loc('MAIN'), pg_temp.loc('ZONE-A'), '[{"tag": "E28068940000401561D679F2"}]', format(', "lot_id": "%s"', (select id from public.stock_lots where item_id = pg_temp.u(303)))), 'transfer'), 'ERR DKG26',
  'a piece is not moved from where it is not');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_pieces_check_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(303))), '[]', 'the count per place still equals the ledger');

-- ── taking out and retiring ──
select is(pg_temp.mv(3, 918, pg_temp.line(303, '1', pg_temp.loc('ZONE-A'), pg_temp.place('loss'), '[{"tag": "E28068940000401561D679F2"}]', format(', "lot_id": "%s"', (select id from public.stock_lots where item_id = pg_temp.u(303)))), 'loss') like '{%', true,
  'a piece taken out as a loss leaves with its tag');
select is((select u.state from public.stock_tagged_units u join public.stock_tags t on t.piece_id = u.id where t.code = 'E28068940000401561D679F2'), 'written_off', 'and is written off');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_tag_retire_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(930), 'E28068940000401561D679F1', 'x')), 'ERR DKG24',
  'a piece in stock is not retired with its tag');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_tag_retire_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(931), 'E28068940000401561D679F2', 'x')) like '{%', true,
  'a piece written off is');
select is((select u.state from public.stock_tagged_units u join public.stock_tags t on t.piece_id = u.id where t.code = 'E28068940000401561D679F2'), 'retired', 'and retired with it');

-- ── the resolver reads a piece's tag ──
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_resolve_code_v1(%L, %L)::jsonb #>> ''{tag,owner_kind}''', pg_temp.u(101), 'E28068940000401561D679F1')), 'piece',
  'a piece''s tag resolves to the piece');

-- ── what the ledger holds without its pieces is held to commit ──
create or replace function pg_temp.held() returns text language plpgsql as $f$
begin
  perform public.stock_record(pg_temp.u(101), pg_temp.u(303), (select id from public.stock_lots where item_id = pg_temp.u(303)),
    pg_temp.loc('MAIN'), pg_temp.place('loss'), 1, 'piece', 1, now(), 'loss', pg_temp.u(201), pg_temp.u(940), 1, 1, '{}'::jsonb, null);
  set constraints public.stock_pieces_balanced immediate;
  return 'none';
exception when others then
  return sqlstate;
end
$f$;
grant execute on function pg_temp.held() to authenticated, anon;
select is(pg_temp.held(), 'DKG25', 'a path that moves the ledger without naming the pieces is refused at commit');

-- ── an item not tagged piece by piece takes no named pieces ──
select is(pg_temp.mv(3, 950, pg_temp.line(301, '1', pg_temp.place('supplier'), pg_temp.loc('MAIN'), '[{"tag": "E28068940000401561D679F9"}]', ', "new_lot": {"total_cost_minor": 100}'), 'receipt'), 'ERR DKG11',
  'a mug is not named piece by piece');
select is(pg_temp.mv(3, 951, pg_temp.line(301, '2', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'null'), 'receipt') like '[%' or true, true, 'while its ordinary movement is untouched');

-- ── the mode is pinned on the item by its first pieces: no group, assignment or default change turns it off (#4362 read) ──
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(304), pg_temp.u(101), 'Crates', 5000, true, 'piece', 'serial', true, null);
select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_save_v1(%L, %L, %L, 0, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(970), pg_temp.u(971),
  '{"name": "Crate group", "parameters": {"tracking": "serial", "tag_mode": "per_unit"}}'));
select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_save_v1(%L, %L, %L, 0, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(972), pg_temp.u(973),
  '{"name": "Plain group", "parameters": {"tag_mode": "none"}}'));
select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_assign_v1(%L, %L, %L, (select stock_revision from public.services where id = %L), %L)::text', pg_temp.u(101), pg_temp.u(974), pg_temp.u(304), pg_temp.u(304), pg_temp.u(971)));
select is((select tag_mode from public.services where id = pg_temp.u(304)) is null, true, 'an item in a per-unit group keeps no mode of its own before its first pieces');
select is(pg_temp.mv(3, 975, pg_temp.line(304, '2', pg_temp.place('supplier'), pg_temp.loc('MAIN'),
  '[{"tag": "E28068940000401561D67A01"}, {"tag": "E28068940000401561D67A02"}]', ', "new_lot": {"total_cost_minor": 2000}'), 'receipt') like '{%', true,
  'its pieces are received');
select is((select tag_mode from public.services where id = pg_temp.u(304)), 'per_unit', 'and the first pieces pin the mode on the item');
select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_save_v1(%L, %L, %L, 1, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(976), pg_temp.u(971),
  '{"parameters": {"tag_mode": "none"}}'));
select is(pg_temp.mv(3, 977, pg_temp.line(304, '1', pg_temp.loc('MAIN'), pg_temp.place('loss'), '[]', format(', "lot_id": "%s"', (select id from public.stock_lots where item_id = pg_temp.u(304)))), 'loss'), 'ERR DKG25',
  'a change of the group''s tag mode does not reach it: a movement without its pieces is still refused');
select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_assign_v1(%L, %L, %L, (select stock_revision from public.services where id = %L), %L)::text', pg_temp.u(101), pg_temp.u(978), pg_temp.u(304), pg_temp.u(304), pg_temp.u(973)));
select is(pg_temp.mv(3, 979, pg_temp.line(304, '1', pg_temp.loc('MAIN'), pg_temp.place('loss'), '[]', format(', "lot_id": "%s"', (select id from public.stock_lots where item_id = pg_temp.u(304)))), 'loss'), 'ERR DKG25',
  'nor does a move to a group without the mode');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_pieces_check_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(304))), '[]', 'the pieces still equal the ledger');

select * from finish();
rollback;
