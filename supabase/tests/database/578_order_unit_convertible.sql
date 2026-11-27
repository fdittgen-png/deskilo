-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0971): an order line of a stocked item is in a unit the item converts from, refused when the order is SAVED, not when the goods
-- arrive. Mugs are counted in pieces and come in cartons of 12 (the item's own conversion); a kilo has no conversion to a piece; a
-- carton of an item that lists none is refused; a service (no stock) takes any unit of the business; a line with no item or no unit is
-- unchanged. Rolled back.
begin;
select plan(8);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'orderunit-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Order units', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"moneyTab":true,"services":true,"purchases":true,"purchaseOrders":true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values (pg_temp.u(401), pg_temp.u(101), '1', 'Alpha', 'active');
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1);
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Plates', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Consulting', 100, true, null, 'piece', 'none', false);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1);

create or replace function pg_temp.save(p_req int, p_line jsonb) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    select public.save_purchase_order_v1(pg_temp.u(101), pg_temp.u(900 + p_req), 0,
      jsonb_build_object('supplier_id', pg_temp.u(401), 'expected_on', '2026-12-01', 'recipient_email', 'orders@alpha.test',
                         'lines', jsonb_build_array(p_line)))::text into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(pg_temp.save(1, jsonb_build_object('service_id', pg_temp.u(301), 'quantity', 2, 'unit', 'carton', 'unit_price_cents', 100))::jsonb -> 'lines' -> 0 ->> 'unit', 'carton',
  'an item''s own conversion: mugs are ordered by the carton');
select is(pg_temp.save(2, jsonb_build_object('service_id', pg_temp.u(301), 'quantity', 2, 'unit', 'piece', 'unit_price_cents', 100))::jsonb -> 'lines' -> 0 ->> 'unit', 'piece',
  'and in the unit it is counted in');
select alike(pg_temp.save(3, jsonb_build_object('service_id', pg_temp.u(301), 'quantity', 2, 'unit', 'kg', 'unit_price_cents', 100)), 'ERR DKG11%unit_unmapped%',
  'a kilo of mugs has no conversion: refused when the order is saved');
select alike(pg_temp.save(4, jsonb_build_object('service_id', pg_temp.u(302), 'quantity', 2, 'unit', 'carton', 'unit_price_cents', 100)), 'ERR DKG11%unit_unmapped%',
  'a carton of plates, which lists none, is refused (not read as one piece)');
select is(pg_temp.save(5, jsonb_build_object('service_id', pg_temp.u(303), 'quantity', 2, 'unit', 'carton', 'unit_price_cents', 100))::jsonb -> 'lines' -> 0 ->> 'unit', 'carton',
  'a service has no stock to convert into: any unit of the business');
select is(pg_temp.save(6, jsonb_build_object('description', 'Paper', 'quantity', 2, 'unit', 'carton', 'unit_price_cents', 100))::jsonb -> 'lines' -> 0 ->> 'unit', 'carton',
  'a line with no item is unchanged');
select is(pg_temp.save(7, jsonb_build_object('service_id', pg_temp.u(302), 'quantity', 2, 'unit_price_cents', 100))::jsonb -> 'lines' -> 0 ->> 'description', 'Plates',
  'a line with no unit is unchanged');
select ok(not has_function_privilege('authenticated', 'public.unit_is_convertible(uuid,uuid,text)', 'execute'), 'a client cannot ask what another business''s items convert');

select * from finish();
rollback;
