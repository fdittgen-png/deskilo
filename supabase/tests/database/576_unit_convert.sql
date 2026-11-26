-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479: ONE table of unit conversions, run here against the server's `unit_convert` (0968) and in test/parity/unit_convert_test.dart
-- against the domain's rule (lib/features/stock/domain/unit_conversions.dart). The rows below are the table's rows to the letter
-- (test/parity/unit_convert_cases.dart; the parity test finds each one here). The world: a business with the thirteen built-in
-- units, a drum (a length: 50 m) and two packaging units, a sack and a carton. Beans are counted in grams and come in sacks of 60000 g;
-- coffee is counted in grams and its kilo is 900 g; mugs are counted in pieces and come in cartons of 12. A row's outcome is the
-- quantity in the unit asked for, or `none` when no conversion is defined (DKG02). Rolled back.
begin;
select plan(23);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'convert-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Conversions', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
update public.workspaces set feature_flags = '{"unitsOfMeasure": true}' where id = pg_temp.u(101);
-- the units the business makes (the built-ins were given with the business, and their conversions with them)
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'drum', 'Drum', 'length', 50, 1),
  (pg_temp.u(101), 'sack', 'Sack', 'package', 1, 1),
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1);
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Beans', 100, true, null, 'g', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Coffee', 100, true, null, 'g', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Mugs', 100, true, null, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(301), 'sack', 60000, 1),
  (pg_temp.u(101), pg_temp.u(302), 'kg', 900, 1),
  (pg_temp.u(101), pg_temp.u(303), 'carton', 12, 1);

-- a command as the owner of the business: its answer as text, or `ERR sqlstate detail`
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
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
create or replace function pg_temp.save(p_req int, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.unit_conversion_save_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(900 + p_req), p_body))
$f$;
create or replace function pg_temp.drop_pair(p_req int, p_from text, p_to text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.unit_conversion_delete_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(900 + p_req), p_from, p_to))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- the quantity of an item in another unit, as text without trailing zeros, or `none` when no conversion is defined (DKG02)
create or replace function pg_temp.conv(p_item text, p_from text, p_to text, p_qty text) returns text language plpgsql as $f$
declare v numeric;
begin
  v := public.unit_convert(pg_temp.u(101), pg_temp.u(case p_item when 'BEANS' then 301 when 'COFFEE' then 302 else 303 end), p_from, p_to, p_qty::numeric);
  return trim_scale(v)::text;
exception when sqlstate 'DKG02' then
  return 'none';
end
$f$;

select is(pg_temp.conv('BEANS', 'g', 'g', '5'), '5', 'c01 the same unit is itself');
select is(pg_temp.conv('BEANS', 'kg', 'g', '2'), '2000', 'c02 a general conversion');
select is(pg_temp.conv('BEANS', 'g', 'kg', '1500'), '1.5', 'c03 a general conversion the other way round');
select is(pg_temp.conv('BEANS', 'sack', 'g', '2'), '120000', 'c04 an item''s own conversion');
select is(pg_temp.conv('BEANS', 'g', 'sack', '120000'), '2', 'c05 an item''s own conversion the other way round');
select is(pg_temp.conv('COFFEE', 'kg', 'g', '1'), '900', 'c06 the item''s own conversion wins over the general one');
select is(pg_temp.conv('COFFEE', 'g', 'kg', '900'), '1', 'c07 and the other way round');
select is(pg_temp.conv('BEANS', 'sack', 'kg', '1'), 'none', 'c08 one step, never chained: a sack is grams, grams are kilos, a sack is not kilos');
select is(pg_temp.conv('BEANS', 'l', 'g', '1'), 'none', 'c09 no conversion by dimension: a litre is not grams');
select is(pg_temp.conv('BEANS', 'carton', 'g', '1'), 'none', 'c10 a packaging unit the item does not list has no conversion');
select is(pg_temp.conv('MUGS', 'carton', 'piece', '3'), '36', 'c11 a packaging unit converts through the item''s own factor');
select is(pg_temp.conv('MUGS', 'carton', 'g', '1'), 'none', 'c12 an item''s conversion holds toward its own unit only');
select is(pg_temp.conv('BEANS', 'm', 'drum', '100'), '2', 'c13 a unit the business made has its conversions');
select is(pg_temp.conv('BEANS', 'km', 'drum', '1'), '20', 'c14 and to the larger units');
select is(pg_temp.conv('MUGS', 'kg', 'g', '1'), '1000', 'c15 a general conversion serves any item');

-- ── the commands of the Settings screen ──
select is(pg_temp.save(1, '{"from_unit": "kg", "to_unit": "g", "factor_num": 999, "factor_den": 1}')::jsonb ->> 'factor_num', '999',
  'the owner changes a general conversion');
select is(pg_temp.save(2, '{"from_unit": "g", "to_unit": "kg", "factor_num": 1, "factor_den": 1000}')::jsonb ->> 'from_unit', 'g',
  'written the other way round, it replaces the one that was');
select is((select count(*)::int from public.unit_conversions where workspace_id = pg_temp.u(101) and least(from_unit, to_unit) = 'g' and greatest(from_unit, to_unit) = 'kg'), 1,
  'one definition per pair of units, whichever way it was written');
select alike(pg_temp.save(3, '{"from_unit": "kg", "to_unit": "kg", "factor_num": 1, "factor_den": 1}'), 'ERR DKG11%conversion_same_unit%', 'a unit is not converted to itself');
select alike(pg_temp.save(4, '{"from_unit": "sack", "to_unit": "g", "factor_num": 1, "factor_den": 1}'), 'ERR DKG11%package_unit%',
  'a packaging unit has no general conversion: it converts through an item''s own factor');
select alike(pg_temp.save(5, '{"from_unit": "nope", "to_unit": "g", "factor_num": 1, "factor_den": 1}'), 'ERR DKG11%unit_unknown%', 'a unit the business does not have is refused');
select alike(pg_temp.save(6, '{"from_unit": "kg", "to_unit": "g", "factor_num": 0, "factor_den": 1}'), 'ERR DKG11%factor_invalid%', 'a factor above zero');
select is(pg_temp.drop_pair(7, 'kg', 'g')::jsonb ->> 'from_unit', 'kg', 'a conversion is taken away, whichever way round it is named');
select alike(pg_temp.drop_pair(8, 'kg', 'g'), 'ERR DKG11%conversion_unknown%', 'one that is not defined cannot be taken away');

select * from finish();
rollback;
