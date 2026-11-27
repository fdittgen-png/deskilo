-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4442 (0952): a business's own units are the units of its stock. A custom unit (a cable drum of 50 m) is an item's inventory
-- unit; a packaging unit (a spool of 2 drums) converts through it into a stock move; the metre and the kilometre convert to drums
-- through the base unit; another business has no such unit; a packaging unit may not take the code of any unit of the business; a
-- built-in unit behaves exactly as it did (a wine counted in litres, received in centilitres); a unit is bound to its business by
-- the key. Rolled back.
begin;
select plan(25);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
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
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'done';
exception when others then
  return 'ERR ' || sqlstate;
end $f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create or replace function pg_temp.save_item(p_user int, p_item int, p_rev int, p_req int, p_body text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_item), p_rev, pg_temp.u(p_req), p_body))
$f$;
create or replace function pg_temp.save_unit(p_user int, p_req int, p_unit text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.workspace_unit_save_v1(%L, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_req), p_unit))
$f$;
create or replace function pg_temp.rev(p_item int) returns int language sql stable as $f$
  select stock_revision from public.services where id = pg_temp.u(p_item)
$f$;
create or replace function pg_temp.receive(p_req int, p_item int, p_qty numeric, p_unit text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'')::text', pg_temp.u(101), pg_temp.u(p_req),
    jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty, 'unit', p_unit,
      'from', pg_temp.loc('SUPPLIER'), 'to', pg_temp.loc('MAIN')))))
$f$;
create or replace function pg_temp.held(p_item int) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = pg_temp.loc('MAIN')
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'perunit-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Cable A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}', '{}'),
  (pg_temp.u(102), 'Cable B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Cable', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Wine', 500, true, null, 'l', 'none', true),
  (pg_temp.u(303), pg_temp.u(102), 'Tea', 200, true, null, 'piece', 'none', true);
update public.workspaces set feature_flags = '{"stockManagement": true, "unitsOfMeasure": true}' where id = pg_temp.u(101);
update public.workspaces set feature_flags = '{"stockManagement": true}' where id = pg_temp.u(102);

-- ── a unit is the business's own ──
select is(pg_temp.try(format($q$update public.services set inventory_unit = 'ghost' where id = %L$q$, pg_temp.u(301))), 'ERR 23503',
  'an item cannot be counted in a unit its business does not have');
select is(pg_temp.try(format($q$update public.services set inventory_unit = 'kg' where id = %L$q$, pg_temp.u(303))), 'done',
  'a built-in is every business''s own');
select is(pg_temp.save_unit(1, 901, '{"code": "drum", "label": "Cable drum", "dimension": "length", "factor_num": 50, "factor_den": 1}')::jsonb ->> 'code', 'drum',
  'the owner of A makes a cable drum of 50 m');
select is(pg_temp.save_item(1, 301, pg_temp.rev(301), 501, '{"inventory_unit": "drum"}')::jsonb ->> 'replayed', 'false',
  'and counts the cable in drums');
select is((select inventory_unit from public.services where id = pg_temp.u(301)), 'drum', 'which is what it is stored in');
select alike(pg_temp.save_item(3, 303, pg_temp.rev(303), 502, '{"inventory_unit": "drum"}', 102), 'ERR DKG11%unit_unknown%',
  'B has no such unit: its item cannot be counted in drums');

-- ── used, so frozen ──
select is(public.workspace_unit_uses(pg_temp.u(101), 'drum'), 1::bigint, 'the item uses the drum');
select alike(pg_temp.save_unit(1, 902, '{"code": "drum", "factor_num": 60}'), 'ERR DKG11%unit_in_use%', 'so the drum keeps its factor');

-- ── a packaging unit converts through it ──
-- #4471: a packaging unit is a unit of the business, so the spool is made first (one code keeps one meaning)
select pg_temp.save_unit(1, 9030, '{"code": "spool", "label": "Spool", "dimension": "count", "factor_num": 1, "factor_den": 1}');
select is(pg_temp.save_item(1, 301, pg_temp.rev(301), 503, '{"units": [{"unit": "spool", "factor_num": 2, "factor_den": 1}]}')::jsonb ->> 'replayed', 'false',
  'a spool of 2 drums is a packaging unit of the cable');
select alike(pg_temp.save_item(1, 301, pg_temp.rev(301), 504, '{"units": [{"unit": "spool", "factor_num": 2, "factor_den": 1}, {"unit": "bogus", "factor_num": 5, "factor_den": 1}]}'),
  'ERR DKG11%unit_unknown%', 'a packaging unit that is not a unit of the business is refused');
select alike(pg_temp.save_item(1, 301, pg_temp.rev(301), 505, '{"units": [{"unit": "spool", "factor_num": 2, "factor_den": 1}, {"unit": "drum", "factor_num": 5, "factor_den": 1}]}'),
  'ERR DKG11%registry_unit%', 'and the item''s own inventory unit (the drum) is not a package of itself');
select alike(pg_temp.save_unit(1, 903, '{"code": "spool", "label": "Spool", "dimension": "length", "factor_num": 3, "factor_den": 1}'), 'ERR DKG11%',
  'a unit the cable''s packaging uses (the spool) does not change its dimension: one code keeps one meaning');
select is(public.stock_to_inventory(pg_temp.u(301), 'spool', 3), 6::numeric, '3 spools are 6 drums');
select is(public.stock_to_inventory(pg_temp.u(301), 'm', 100), 2::numeric, '100 m are 2 drums');
select is(public.stock_to_inventory(pg_temp.u(301), 'km', 1), 20::numeric, '1 km is 20 drums');
select is(pg_temp.try(format($q$select public.stock_to_inventory(%L, 'kg', 1)$q$, pg_temp.u(301))), 'ERR DKG02', 'a mass is not a length: the item does not list it');
-- #4479: a packaging unit has no ratio to any unit: it converts only through an item's own factor
select pg_temp.save_unit(1, 9040, '{"code": "pallet", "label": "Pallet", "dimension": "package", "factor_num": 1, "factor_den": 1}');
select is(pg_temp.try(format($q$select public.stock_to_inventory(%L, 'pallet', 1)$q$, pg_temp.u(301))), 'ERR DKG02',
  'a package unit is not converted by ratio: with no factor of the item it is refused, never read as one drum');
select is((select num::text || '/' || den::text from public.stock_unit_factor(pg_temp.u(301), 'm')), '1/50', 'the factor of a metre in drums is 1/50');
select is(pg_temp.receive(601, 301, 3, 'spool') like '{%', true, 'a delivery of 3 spools is received');
select is(pg_temp.held(301), 6::numeric, 'and the cable holds 6 drums');

-- ── a built-in behaves exactly as before ──
select is(public.stock_to_inventory(pg_temp.u(302), 'cl', 500), 5::numeric, '500 cl of wine are 5 l');
select is(pg_temp.receive(602, 302, 500, 'cl') like '{%', true, 'received in centilitres');
select is(pg_temp.held(302), 5::numeric, 'and the wine holds 5 l');

-- ── the groups ──
select is(pg_temp.try(format($q$select public.item_group_check_value(%L, 'inventory_unit', '"drum"'::jsonb)$q$, pg_temp.u(101))), 'done',
  'a group may be counted in A''s drum');
select is(pg_temp.try(format($q$select public.item_group_check_value(%L, 'inventory_unit', '"drum"'::jsonb)$q$, pg_temp.u(102))), 'ERR DKG11',
  'and not in B''s');

select * from finish();
rollback;
