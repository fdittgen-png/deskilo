-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0974): ONE table of what an item costs in one of its units, run here against the server's `item_unit_price` and in
-- test/parity/unit_price_test.dart against the domain's rule (lib/features/stock/domain/unit_conversions.dart). The rows below are the
-- table's rows to the letter (test/parity/unit_price_cases.dart; the parity test finds each one here). Mugs cost 1,00 a piece, come in
-- cartons of 12 priced 11,00 and boxes of 6 with no price of their own; beans cost 0,03 a gram; a third of a litre is 1/3 of a litre of
-- 1,00. An outcome is the price in minor units, or `none` when no conversion is defined (DKG02). Rolled back.
begin;
select plan(8);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'unitprice-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Unit prices', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1),
  (pg_temp.u(101), 'box', 'Box', 'package', 1, 1),
  (pg_temp.u(101), 'third', 'Third', 'package', 1, 1);
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Beans', 3, true, null, 'g', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Thirds', 100, true, null, 'l', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, price_cents) values
  (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1, 1100),
  (pg_temp.u(101), pg_temp.u(301), 'box', 6, 1, null),
  (pg_temp.u(101), pg_temp.u(303), 'third', 1, 3, null);

-- the price of one unit of an item by name, or `none` when no conversion is defined
create or replace function pg_temp.price(p_item text, p_unit text) returns text language plpgsql as $f$
declare v bigint;
begin
  select public.item_unit_price(pg_temp.u(101), s.id, p_unit) into v
    from public.services s where s.workspace_id = pg_temp.u(101) and upper(s.name) = upper(p_item);
  return v::text;
exception when sqlstate 'DKG02' then
  return 'none';
end
$f$;

select is(pg_temp.price('MUGS', 'piece'), '100', 'p01 the inventory unit is the item''s price');
select is(pg_temp.price('MUGS', ''), '100', 'p02 no unit is the item''s price');
select is(pg_temp.price('MUGS', 'carton'), '1100', 'p03 a unit with a price of its own is that price, not twelve of the item');
select is(pg_temp.price('MUGS', 'box'), '600', 'p04 a unit with no price is the item''s price times its factor');
select is(pg_temp.price('BEANS', 'kg'), '3000', 'p05 a general conversion prices the kilo of beans');
select is(pg_temp.price('THIRDS', 'third'), '33', 'p06 a third of a litre, 33,33 rounded half up once');
select is(pg_temp.price('BEANS', 'l'), 'none', 'p07 no conversion, no price: a litre of beans');
select is(pg_temp.price('BEANS', 'carton'), 'none', 'p08 a packaging unit the item does not list has none');

select * from finish();
rollback;
