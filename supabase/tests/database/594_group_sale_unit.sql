-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0983): an item group carries the unit its items are sold in, what one of it makes of the inventory unit and its price, as it
-- carries the purchase unit: proposals, stored with the group, never inherited. A sale unit that is not one of the business's units is
-- refused; a price that is no whole number of minor units is refused; the factor is both parts or none; the groups' catalogue names
-- the four as proposals. Rolled back.
begin;
select plan(8);

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
create or replace function pg_temp.sv(p_req int, p_group int, p_exp int, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.item_group_save_v1(%L, %L, %L, %s, %L::jsonb, true)::text',
    pg_temp.u(101), pg_temp.u(p_req), pg_temp.u(p_group), p_exp, p_body))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'groupsale-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Group sale units', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockItemGroups": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1);

select is(pg_temp.sv(901, 501, 0, '{"name": "Mugs", "parameters": {"default_sale_unit": "carton", "default_sale_factor_num": 12, "default_sale_factor_den": 1, "default_sale_price_cents": 1100}}')::jsonb ->> 'revision', '1',
  'a group is created with its sale unit, factor and price');
select is((select default_sale_unit || ' ' || default_sale_factor_num || '/' || default_sale_factor_den || ' ' || default_sale_price_cents
             from public.item_groups where id = pg_temp.u(501)), 'carton 12/1 1100', 'they are stored with the group');
select is(pg_temp.sv(902, 502, 0, '{"name": "Plates", "parameters": {"default_sale_unit": "zzz"}}'), 'ERR DKG11', 'a sale unit that is not one of the business''s units is refused');
select is(pg_temp.sv(903, 503, 0, '{"name": "Cups", "parameters": {"default_sale_unit": "carton", "default_sale_price_cents": "abc"}}'), 'ERR DKG11', 'a price that is no amount is refused');
select is(pg_temp.sv(904, 504, 0, '{"name": "Pots", "parameters": {"default_sale_unit": "carton", "default_sale_factor_num": 12}}'), 'ERR DKG11', 'a factor is both parts or none');
select is(public.item_group_param_kind('default_sale_unit') || ' ' || public.item_group_param_kind('default_sale_price_cents'), 'proposal proposal',
  'the catalogue names them proposals: copied into a new item, never inherited');
select ok('default_sale_factor_num' = any (public.item_group_params()) and 'default_sale_factor_den' = any (public.item_group_params()),
  'and lists them among the parameters');
select is((select count(*)::int from public.item_groups where workspace_id = pg_temp.u(101)), 1, 'a refused group is not made');

select * from finish();
rollback;
