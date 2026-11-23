-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4432 (0922): a movement records the pieces it carried. A receipt of three pieces links each to the receipt
-- movement, a move of two links those two, a move back links the one moved; a piece's history is its rows in order;
-- a refused movement links nothing; the rows are read by a stock viewer of the business only. Rolled back.
begin;
select plan(9);

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
create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
create or replace function pg_temp.piece(p_tag text) returns uuid language sql stable as $f$
  select piece_id from public.stock_tags where workspace_id = pg_temp.u(101) and code = p_tag and state = 'active'
$f$;
create or replace function pg_temp.history(p_tag text) returns text language sql stable as $f$
  select string_agg(m.reason, ' > ' order by m.created_datetime, m.reason)
    from public.stock_movement_units l join public.stock_movements m on m.id = l.movement_id
   where l.unit_id = pg_temp.piece(p_tag)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mvunits-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Units A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockItemGroups": true}', '{}'),
  (pg_temp.u(102), 'Units B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2),
   '{"services": true, "stockManagement": true, "stockTags": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(102), pg_temp.u(2), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR');

-- three baskets received at MAIN
select pg_temp.mv(1, 910, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6AA01"}, {"tag": "E28068940000401561D6AA02"}, {"tag": "E28068940000401561D6AA03"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select set_config('t.lot', (select id::text from public.stock_lots where item_id = pg_temp.u(303) order by created_datetime limit 1), false);
select is((select count(*)::int from public.stock_movement_units where workspace_id = pg_temp.u(101)), 3,
  'a receipt of three pieces links each of them to its movement');
select is((select count(distinct movement_id)::int from public.stock_movement_units where workspace_id = pg_temp.u(101)), 1,
  'the three pieces are linked to the one receipt movement');

-- two of them move to FLOOR
select pg_temp.mv(1, 911, format('[{"item_id": "%s", "lot_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6AA01"}, {"tag": "E28068940000401561D6AA02"}]}]',
  pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR')), 'transfer');
select is((select count(*)::int from public.stock_movement_units l join public.stock_movements m on m.id = l.movement_id
            where l.workspace_id = pg_temp.u(101) and m.to_location_id = pg_temp.loc('FLOOR') and m.reason = 'transfer'), 2,
  'a move of two pieces links those two to the move');

-- one comes back to MAIN
select pg_temp.mv(1, 912, format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6AA01"}]}]',
  pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('FLOOR'), pg_temp.loc('MAIN')), 'transfer');
select is(pg_temp.history('E28068940000401561D6AA01'), 'receipt > transfer > transfer', 'the piece moved there and back has its three movements, in order');
select is(pg_temp.history('E28068940000401561D6AA03'), 'receipt', 'the piece that never moved has its receipt only');

-- a refused movement (a piece that is not where the movement takes it from) links nothing
select set_config('t.before', (select count(*)::text from public.stock_movement_units), false);
select ok(pg_temp.mv(1, 913, format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6AA03"}]}]',
  pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('FLOOR'), pg_temp.loc('MAIN')), 'transfer') like 'ERR DKG26%', 'a piece taken from the wrong place is refused');
select is((select count(*)::text from public.stock_movement_units), current_setting('t.before'), 'a refused movement links nothing');

-- read by the business's own stock viewers only
select is(pg_temp.run_as(pg_temp.u(1), format('select count(*)::text from public.stock_movement_units where workspace_id = %L', pg_temp.u(101))), '6',
  'the business''s manager reads the links');
select is(pg_temp.run_as(pg_temp.u(2), format('select count(*)::text from public.stock_movement_units where workspace_id = %L', pg_temp.u(101))), '0',
  'another business reads none of them');

select * from finish();
rollback;
