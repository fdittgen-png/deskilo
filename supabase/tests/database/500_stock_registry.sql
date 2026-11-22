-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4293 (0860, G7 cut B): an item or a variant names the place it belongs at. The place is a real
-- one of the same business (not virtual), only a stock manager sets it, it is advice - changing it
-- moves no stock and writes no movement - and a variant without a home has its item's. The
-- registry shows barcode, unit, price, home address and on hand; the cost only to whoever may see
-- finances, and an unknown cost stays null; it is filtered by place and by no home place and is
-- read in bounded pages. Rolled back.
begin;
select plan(24);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
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

create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;


create or replace function pg_temp.sethome(p_user int, p_item int, p_variant uuid, p_place uuid, p_req int, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.set_stock_home_v1(%L, %L, %L, %L, %L)::text',
    pg_temp.u(101), pg_temp.u(p_item), p_variant, p_place, pg_temp.u(p_req)), p_delegated)
$f$;
create or replace function pg_temp.registry(p_user int, p_place uuid default null, p_nohome boolean default false, p_limit int default 50, p_after jsonb default null)
returns jsonb language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_registry_page_v1(%L, %L, %L, %s, %L)::text',
    pg_temp.u(101), p_place, p_nohome, p_limit, p_after))::jsonb
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create or replace function pg_temp.row_of(p_page jsonb, p_name text, p_variant uuid default null) returns jsonb language sql stable as $f$
  select r from jsonb_array_elements(p_page -> 'rows') r
   where r ->> 'item_name' = p_name and (r ->> 'variant_id') is not distinct from p_variant::text limit 1
$f$;
-- a write straight to the table as a given person (the role stays the test's own: the trigger
-- is what is asked)
create or replace function pg_temp.table_write_as(p_user int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  begin execute p_sql; v := 'ok'; exception when others then v := sqlstate; end;
  perform set_config('request.jwt.claims', '', true);
  return v;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'registry-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Registry A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": true}', '{"member": ["viewStock"], "admin": ["viewStock", "viewFinances"]}'),
  (pg_temp.u(102), 'Registry B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.stock_locations (workspace_id, kind, code, name) values
  (pg_temp.u(101), 'warehouse', 'MAIN', 'Main'), (pg_temp.u(101), 'site', 'DEPOT', 'Depot'),
  (pg_temp.u(101), 'supplier', 'SUPPLIER', ''), (pg_temp.u(102), 'warehouse', 'OTHER', 'Other')
  on conflict do nothing;
insert into public.stock_locations (workspace_id, parent_id, kind, code, name) values
  (pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'SALES', ''),
  (pg_temp.u(101), pg_temp.loc('DEPOT'), 'zone', 'BACK', '');
insert into public.stock_locations (workspace_id, parent_id, kind, code, name) values
  (pg_temp.u(101), pg_temp.loc('SALES'), 'aisle', 'A1', '');
insert into public.stock_locations (workspace_id, parent_id, kind, code, name) values
  (pg_temp.u(101), pg_temp.loc('A1'), 'bay', 'B1', '');
insert into public.stock_locations (workspace_id, parent_id, kind, code, name) values
  (pg_temp.u(101), pg_temp.loc('B1'), 'shelf', 'S1', '');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Beans', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Wine', 500, true, null, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Consulting', 9000, true, null, 'piece', 'none', false);
insert into public.item_variants (id, workspace_id, item_id, canonical, price_cents, active) values
  (pg_temp.u(401), pg_temp.u(101), pg_temp.u(302), 'colour:red', 550, true),
  (pg_temp.u(402), pg_temp.u(101), pg_temp.u(302), 'colour:white', 600, true);
insert into public.item_codes (workspace_id, item_id, code, kind) values (pg_temp.u(101), pg_temp.u(301), 'BEANS-1', 'own');
insert into public.stock_lots (workspace_id, item_id, quantity_received, total_cost_minor, cost_state)
  values (pg_temp.u(101), pg_temp.u(301), 10, 500, 'known');
insert into public.stock_balances (workspace_id, item_id, location_id, quantity) values (pg_temp.u(101), pg_temp.u(301), pg_temp.loc('MAIN'), 7);

-- the home place
select is(pg_temp.sethome(1, 301, null, pg_temp.loc('S1'), 801)::jsonb ->> 'home_location_id', pg_temp.loc('S1')::text, 'a stock manager gives an item its home shelf');
select is(replace(pg_temp.row_of(pg_temp.registry(3), 'Beans') ->> 'home_address_path', chr(31), '/'), 'MAIN/SALES/A1/B1/S1', 'the registry shows its address');
select is(pg_temp.sethome(1, 301, null, pg_temp.loc('OTHER', 102), 802), 'ERR DKG11 {"field": "home_location_id", "reason": "home_invalid"}', 'a place of another business is refused');
select is(pg_temp.sethome(1, 301, null, pg_temp.loc('SUPPLIER'), 803), 'ERR DKG11 {"field": "home_location_id", "reason": "home_invalid"}', 'a virtual place is refused');
select is(pg_temp.sethome(1, 303, null, pg_temp.loc('S1'), 804) like 'ERR DKG04%', true, 'a service that is not stock has no home');
select is(pg_temp.sethome(2, 301, null, pg_temp.loc('S1'), 805) like 'ERR DKN01%', true, 'a reader of the stock does not set it');
select is(pg_temp.sethome(1, 301, null, pg_temp.loc('S1'), 806, true) like 'ERR DKN01%', true, 'nor an assistant');

-- the rule holds for a write straight to the table too
select is(pg_temp.table_write_as(2, format($s$update public.services set home_location_id = %L where id = %L$s$, pg_temp.loc('S1'), pg_temp.u(302))), 'DKN01',
  'a reader of the stock cannot set a home place by writing to the table');
select is(pg_temp.table_write_as(1, format($s$update public.item_variants set home_location_id = %L where id = %L$s$, pg_temp.loc('S1'), pg_temp.u(401))), 'ok',
  'a stock manager can, the same rules applying');

-- it is advice: nothing moves
select is((select count(*) from public.stock_movements where workspace_id = pg_temp.u(101)), 0::bigint, 'no movement was written');
select pg_temp.sethome(1, 301, null, pg_temp.loc('DEPOT'), 807);
select is((select quantity from public.stock_balances where item_id = pg_temp.u(301) and location_id = pg_temp.loc('MAIN')), 7::numeric, 'changing the home moved no stock');
select is((select count(*) from public.stock_movements where workspace_id = pg_temp.u(101)), 0::bigint, 'and wrote no history');

-- a request answers once
select is(pg_temp.sethome(1, 301, null, pg_temp.loc('DEPOT'), 807)::jsonb ->> 'replayed', 'true', 'the same request answers the same');
select is(pg_temp.sethome(1, 301, null, pg_temp.loc('S1'), 807) like 'ERR DKG07%', true, 'a request id reused for another place is refused');

-- the registry: price, unit, barcode, on hand, cost
select is(pg_temp.row_of(pg_temp.registry(3), 'Beans') ->> 'barcode', 'BEANS-1', 'the registry shows the barcode');
select is(((pg_temp.row_of(pg_temp.registry(3), 'Beans') ->> 'cost')::numeric, (pg_temp.row_of(pg_temp.registry(3), 'Beans') ->> 'on_hand')::numeric, pg_temp.row_of(pg_temp.registry(3), 'Beans') ->> 'unit'),
  (50::numeric, 7::numeric, 'piece'::text), 'the last known cost, what is on hand and the unit');
select is((pg_temp.row_of(pg_temp.registry(2), 'Beans') -> 'cost') = 'null'::jsonb and (pg_temp.row_of(pg_temp.registry(2), 'Beans') ->> 'cost_visible') = 'false', true,
  'a stock-only reader sees no cost');
select is(pg_temp.row_of(pg_temp.registry(3), 'Wine', pg_temp.u(401)) is null, false, 'an item with variants has a row per variant');
select is((pg_temp.row_of(pg_temp.registry(3), 'Wine', pg_temp.u(401)) -> 'cost') = 'null'::jsonb, true, 'an unknown cost stays unknown, never 0');

-- a variant without a home has its item's
select pg_temp.sethome(1, 302, null, pg_temp.loc('S1'), 808);
select pg_temp.sethome(1, 302, pg_temp.u(402), pg_temp.loc('BACK'), 809);
select is((pg_temp.row_of(pg_temp.registry(3), 'Wine', pg_temp.u(401)) ->> 'home_location_id', pg_temp.row_of(pg_temp.registry(3), 'Wine', pg_temp.u(402)) ->> 'home_location_id'),
  (pg_temp.loc('S1')::text, pg_temp.loc('BACK')::text), 'a variant has the item''s home until it has its own');

-- the filters
select is((select jsonb_agg(r ->> 'item_name' order by r ->> 'item_name') from jsonb_array_elements(pg_temp.registry(3, pg_temp.loc('MAIN')) -> 'rows') r), '["Wine"]'::jsonb,
  'filtered by a place, the registry shows what is homed in it and below it (the red wine at the shelf, not the white one at the depot)');
select pg_temp.sethome(1, 301, null, null, 810);
select is((select jsonb_agg(r ->> 'item_name' order by r ->> 'item_name') from jsonb_array_elements(pg_temp.registry(3, null, true) -> 'rows') r), '["Beans"]'::jsonb, 'filtered by no home place, only what has none');

-- bounded pages
select is((pg_temp.registry(3, null, false, 1) ->> 'complete', jsonb_array_length(pg_temp.registry(3, null, false, 1) -> 'rows')), ('false'::text, 1), 'a page of one says there is more');
select is(pg_temp.run_as(pg_temp.u(3), format('select public.stock_registry_page_v1(%L, %L, false, 50, null)::text', pg_temp.u(101), pg_temp.loc('OTHER', 102))) like 'ERR DKG05%', true, 'a place of another business is refused as a filter');

select * from finish();
rollback;
