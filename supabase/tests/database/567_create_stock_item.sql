-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4402 (0955): a new item from the Stock page is one command with one request id. The service, its stock settings
-- (kept in stock, its unit, its barcode) and its home place are made in one transaction: a refusal of any step
-- leaves nothing, the same request answers the item it first made and makes nothing, the same request id with other
-- content is refused, and only a member who may manage both the services and the stock makes one (an assistant
-- never). Rolled back.
begin;
select plan(17);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
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

create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;

create or replace function pg_temp.make(p_user int, p_req int, p_item jsonb, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.create_stock_item_v1(%L, %L, %L)::text',
    pg_temp.u(101), pg_temp.u(p_req), p_item), p_delegated)
$f$;

-- an answer as JSON, or a refusal as a JSON string (a refused call is a failed case, never an aborted file)
create or replace function pg_temp.j(p text) returns jsonb language plpgsql as $f$
begin
  return p::jsonb;
exception when others then
  return to_jsonb(p);
end
$f$;

create or replace function pg_temp.named(p_name text) returns bigint language sql stable as $f$
  select count(*) from public.services where workspace_id = pg_temp.u(101) and name = p_name
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'new-item-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'New item A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": true}',
   '{"member": ["viewStock"], "admin": ["viewStock", "manageStock"]}'),
  (pg_temp.u(102), 'New item B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{"stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values
  (pg_temp.u(501), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard'),
  (pg_temp.u(502), pg_temp.u(102), 'Other', 20, 'S', true, 'standard');
insert into public.stock_locations (workspace_id, kind, code, name) values
  (pg_temp.u(101), 'warehouse', 'MAIN', 'Main'), (pg_temp.u(101), 'supplier', 'SUPPLIER', '')
  on conflict do nothing;

-- the item, its settings and its home, in one command
select is(pg_temp.j(pg_temp.make(1, 801, jsonb_build_object('name', 'Tea', 'price_cents', 450, 'vat_rate_id', pg_temp.u(501),
  'inventory_unit', 'kg', 'barcode', 'TEA-1', 'home_location_id', pg_temp.loc('MAIN')))) ->> 'replayed', 'false',
  'an owner makes a new item in one command');
select is((select row(s.price_cents, s.vat_rate_id, s.stockable, s.purchasable, s.sellable, s.inventory_unit, s.tracking)::text
             from public.services s where s.workspace_id = pg_temp.u(101) and s.name = 'Tea'),
  row(450, pg_temp.u(501), true, true, true, 'kg', 'none')::text, 'it is a service kept in stock, bought and sold, in its unit');
select is((select c.code from public.item_codes c join public.services s on s.id = c.item_id where s.name = 'Tea' and s.workspace_id = pg_temp.u(101)),
  'TEA-1', 'its barcode is its own code');
select is((select s.home_location_id from public.services s where s.name = 'Tea' and s.workspace_id = pg_temp.u(101)),
  pg_temp.loc('MAIN'), 'its home is the place chosen');
select is(pg_temp.j(pg_temp.make(1, 802, jsonb_build_object('name', 'Rice', 'inventory_unit', 'piece'))) ->> 'item_id' is not null, true,
  'a price, a rate, a barcode and a home may be left out');
select is((select s.home_location_id from public.services s where s.name = 'Rice' and s.workspace_id = pg_temp.u(101)), null,
  'without a home chosen it has none');

-- one request id answers once
select is(pg_temp.j(pg_temp.make(1, 801, jsonb_build_object('name', 'Tea', 'price_cents', 450, 'vat_rate_id', pg_temp.u(501),
  'inventory_unit', 'kg', 'barcode', 'TEA-1', 'home_location_id', pg_temp.loc('MAIN')))) ->> 'item_id',
  (select s.id::text from public.services s where s.name = 'Tea' and s.workspace_id = pg_temp.u(101)),
  'the same request answers the item it made');
select is(pg_temp.named('Tea'), 1::bigint, 'and makes no second one');
select is(pg_temp.make(1, 801, jsonb_build_object('name', 'Coffee', 'inventory_unit', 'kg')) like 'ERR DKG07%', true,
  'a request id used for other content is refused');

-- a refusal of any step leaves nothing
select is(pg_temp.make(1, 803, jsonb_build_object('name', 'Mugs', 'inventory_unit', 'piece', 'home_location_id', pg_temp.loc('SUPPLIER'))),
  'ERR DKG11 {"field": "home_location_id", "reason": "home_invalid"}', 'a home that is no place to keep goods is refused');
select is(pg_temp.named('Mugs'), 0::bigint, 'and no service is left behind');
select is(pg_temp.make(1, 804, jsonb_build_object('name', 'Cups', 'inventory_unit', 'piece', 'vat_rate_id', pg_temp.u(502))),
  'ERR DKG11 {"field": "vat_rate_id", "reason": "vat_rate_unknown"}', 'a VAT rate of another business is refused');
select is(pg_temp.make(1, 805, jsonb_build_object('name', 'Jars', 'inventory_unit', 'no-such-unit')) like 'ERR DKG11%unit_unknown%', true,
  'a unit the business does not know is refused');
select is(pg_temp.named('Jars'), 0::bigint, 'and no service is left behind');
select is(pg_temp.make(1, 806, jsonb_build_object('name', 'Lids', 'inventory_unit', 'piece', 'colour', 'red')),
  'ERR DKG11 {"field": "colour", "reason": "malformed"}', 'a field the command does not take is refused');

-- who may
select is(pg_temp.make(2, 807, jsonb_build_object('name', 'Pans', 'inventory_unit', 'piece')) like 'ERR DKN01%', true,
  'a stock manager who may not manage the services makes no item');
select is(pg_temp.make(1, 808, jsonb_build_object('name', 'Pots', 'inventory_unit', 'piece'), true) like 'ERR DKN01%', true,
  'nor does an assistant');

select * from finish();
rollback;
