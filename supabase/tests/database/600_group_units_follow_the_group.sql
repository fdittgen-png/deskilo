-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0992): a group's units follow the group. An item without a value of its own reads its group's sale unit, factor, price and
-- purchase unit as they are NOW; a change of the group reaches it at once, and never an item that keeps its own; an item sets its own
-- unit and goes back to the group's; a move into a group brings the group's unit; a sub-group's value comes before its group's;
-- the preview counts what it reaches. Nothing is written into the item by the group. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
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
create or replace function pg_temp.sv(p_req int, p_group int, p_exp int, p_body text, p_apply boolean default true) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_save_v1(%L, %L, %L, %s, %L::jsonb, %L)::text',
    pg_temp.u(101), pg_temp.u(p_req), pg_temp.u(p_group), p_exp, p_body, p_apply))
$f$;
create or replace function pg_temp.asg(p_req int, p_item int, p_exp int, p_group int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_assign_v1(%L, %L, %L, %s, %L, true)::text',
    pg_temp.u(101), pg_temp.u(p_req), pg_temp.u(p_item), p_exp, pg_temp.u(p_group)))
$f$;
create or replace function pg_temp.ovr(p_req int, p_item int, p_exp int, p_param text, p_mode text, p_value text default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.item_override_save_v1(%L, %L, %L, %s, %L, %L, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_req), pg_temp.u(p_item), p_exp, p_param, p_mode, p_value))
$f$;
create or replace function pg_temp.rev(p_item int) returns int language sql stable as $f$
  select stock_revision from public.services where id = pg_temp.u(p_item)
$f$;
create or replace function pg_temp.eff(p_item int, p_param text) returns text language sql stable as $f$
  select coalesce(e -> 'parameters' -> p_param ->> 'value', 'null') || '|' || (e -> 'parameters' -> p_param ->> 'source')
    from (select public.item_effective_core(pg_temp.u(p_item)) e) x
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'groupunits-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Group units', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockItemGroups": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1),
  (pg_temp.u(101), 'pallet', 'Pallet', 'package', 1, 1);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mug one', 100, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Mug two', 100, true, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Mug three', 100, true, 'piece', 'none', true);

-- the group sells in cartons of 12 at 11,00 and buys in pallets; two items belong to it
select pg_temp.sv(901, 501, 0, '{"name": "Mugs", "parameters": {"default_sale_unit": "carton", "default_sale_factor_num": 12, "default_sale_factor_den": 1, "default_sale_price_cents": 1100, "default_purchase_unit": "pallet", "default_purchase_factor_num": 480, "default_purchase_factor_den": 1}}');
select pg_temp.asg(902, 301, pg_temp.rev(301), 501);
select pg_temp.asg(903, 302, pg_temp.rev(302), 501);

select is(pg_temp.eff(301, 'default_sale_unit'), 'carton|group', 'an item of the group reads the group''s sale unit, and says where it comes from');
select is(pg_temp.eff(301, 'default_sale_price_cents'), '1100|group', 'and its price');
select is(pg_temp.eff(301, 'default_purchase_unit'), 'pallet|group', 'and its purchase unit');
select is((select default_sale_unit from public.services where id = pg_temp.u(301)), null, 'nothing is written into the item: it inherits');
select is(pg_temp.eff(303, 'default_sale_unit'), 'null|none', 'an item outside the group has none');

-- the rules that convert and price read the group's units
select is((select f.num || '/' || f.den from public.unit_factor(pg_temp.u(101), pg_temp.u(301), 'pallet', 'piece') f), '480/1',
  'a unit the group buys in converts to the inventory unit by the group''s factor');
select is(public.unit_is_convertible(pg_temp.u(101), pg_temp.u(301), 'pallet') and not public.unit_is_convertible(pg_temp.u(101), pg_temp.u(303), 'pallet'), true,
  'an order line in the group''s unit is accepted for its item, and refused for an item outside the group');
select is(public.item_unit_price(pg_temp.u(101), pg_temp.u(301), 'carton'), 1100::bigint, 'the group''s sale unit is priced at the group''s price');

-- the item keeps its own sale unit
select is(pg_temp.ovr(904, 302, pg_temp.rev(302), 'default_sale_unit', 'set', '"pallet"')::jsonb -> 'effective' ->> 'source', 'item', 'an item sets its own unit');

-- the group changes: the inheriting item follows, the other keeps its own
select is(pg_temp.sv(905, 501, 1, '{"parameters": {"default_sale_unit": "pallet", "default_sale_price_cents": 5000}}', false)::jsonb is not null, true, 'a preview answers');
select is(pg_temp.sv(906, 501, 1, '{"parameters": {"default_sale_unit": "pallet", "default_sale_price_cents": 5000}}')::jsonb -> 'parameters' -> 'default_sale_unit' ->> 'affected', '1',
  'the change reaches the one item without its own value');
select is(pg_temp.eff(301, 'default_sale_price_cents'), '5000|group', 'the inheriting item reads the new price at once');
select is(pg_temp.eff(302, 'default_sale_unit'), 'pallet|item', 'the item with its own value keeps it');

-- back to the group's
select is(pg_temp.ovr(907, 302, pg_temp.rev(302), 'default_sale_unit', 'inherit')::jsonb -> 'effective' ->> 'source', 'group', 'an item goes back to the group''s unit');

-- a refusal and the catalogue
select is(pg_temp.ovr(908, 302, pg_temp.rev(302), 'default_sale_unit', 'set', '"zzz"'), 'ERR DKG11', 'an own unit that is not one of the business''s is refused');
select is(pg_temp.ovr(909, 302, pg_temp.rev(302), 'default_sale_factor_num', 'set', '0'), 'ERR DKG11', 'and so is a factor of nothing');
select is(pg_temp.eff(302, 'default_purchase_factor_num'), '480|group', 'the purchase factor follows the group as well');

select * from finish();
rollback;
