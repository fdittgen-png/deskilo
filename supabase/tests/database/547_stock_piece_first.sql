-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4364 (0925): a contender is told where the piece went. A second move of a piece that already left is refused with
-- the piece's new place (DKG26) even though the quantity check would refuse it too (DKG03); a line without units keeps
-- the quantity refusal; a piece that is still there moves as before. Rolled back.
begin;
select plan(7);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
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
create or replace function pg_temp.mv(p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(3), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'piecefirst-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'First A', 'FR', 'EUR', 'Europe/Paris',  pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockItemGroups": true}', '{"admin": ["manageStock"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit'),
  (pg_temp.u(304), pg_temp.u(101), 'Mugs', 900, true, 'piece', 'none', true, 'none');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR'),
  (pg_temp.u(902), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'ANNEX');

-- one basket piece, tagged, received at MAIN, then moved to FLOOR (the winner of the race)
select ok(pg_temp.mv(910, format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt') like '{%', 'fixture: the piece is received at MAIN');
select set_config('t.lot', (select id::text from public.stock_lots where item_id = pg_temp.u(303) limit 1), false);
select ok(pg_temp.mv(911, format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "lot_id": "%s", "units": [{"tag": "E28068940000401561D68F01"}]}]',
  pg_temp.u(303), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR'), current_setting('t.lot')), 'transfer') like '{%', 'fixture: the winner moved it to FLOOR');

-- the contender asks for the same piece at MAIN: MAIN holds nothing, so the quantity check would refuse first
select set_config('t.late', pg_temp.mv(912, format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "lot_id": "%s", "units": [{"tag": "E28068940000401561D68F01"}]}]',
  pg_temp.u(303), pg_temp.loc('MAIN'), pg_temp.loc('ANNEX'), current_setting('t.lot')), 'transfer'), false);
select is(left(current_setting('t.late'), 10), 'ERR DKG26 ', 'the contender is refused with the piece check, not the quantity check');
select is((substr(current_setting('t.late'), 11))::jsonb ->> 'place', 'FLOOR', 'and the refusal names the place the piece went to');
select is((substr(current_setting('t.late'), 11))::jsonb ->> 'line', '1', 'and the line');

-- a line without units keeps the quantity refusal
select is(left(pg_temp.mv(913, format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s"}]', pg_temp.u(304), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR')), 'transfer'), 9), 'ERR DKG03', 'a line without units keeps the quantity refusal');
-- a piece that is still there moves as before
select ok(pg_temp.mv(914, format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "lot_id": "%s", "units": [{"tag": "E28068940000401561D68F01"}]}]',
  pg_temp.u(303), pg_temp.loc('FLOOR'), pg_temp.loc('MAIN'), current_setting('t.lot')), 'transfer') like '{%', 'a piece that is still there moves as before');

select * from finish();
rollback;
