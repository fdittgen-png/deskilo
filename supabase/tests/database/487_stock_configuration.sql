-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4169 (0836, A1): the stock configuration is edited by commands. Units are
-- exact and per item (1 carton = 12 pieces, 1 glass = 1/5 litre), a used
-- factor is frozen with each movement, the first movement fixes the unit and
-- the tracking, codes are unique per business and a GTIN has its check digit,
-- a stale revision changes nothing, a request id answers once, places form a
-- tree with no cycle and are deactivated, never deleted, and only a stock
-- manager of the business writes. Rolled back.
begin;
select plan(38);

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

create or replace function pg_temp.rev(p_item int) returns int language sql stable as $f$
  select stock_revision from public.services where id = pg_temp.u(p_item)
$f$;

-- save_stock_item_v1 as a person; the request ids are numbers
create or replace function pg_temp.save_item(p_user int, p_item int, p_rev int, p_req int, p_body text, p_ws int default 101, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_item_v1(%L, %L, %s, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_item), p_rev, pg_temp.u(p_req), p_body), p_delegated)
$f$;

create or replace function pg_temp.save_place(p_user int, p_place uuid, p_rev int, p_req int, p_body text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_location_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_place, p_rev, pg_temp.u(p_req), p_body))
$f$;

create or replace function pg_temp.move(p_req int, p_item int, p_qty numeric, p_from text, p_to text, p_unit text default null)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, '||(case when p_from = 'SUPPLIER' then '''receipt''' when p_to in ('CUSTOMER', 'LOSS') then '''loss''' else '''transfer''' end)||')::text',
    pg_temp.u(101), pg_temp.u(p_req), jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty,
      'from', pg_temp.loc(p_from), 'to', pg_temp.loc(case when p_to = 'CUSTOMER' then 'LOSS' else p_to end)) || case when p_unit is null then '{}'::jsonb else jsonb_build_object('unit', p_unit) end)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- A (101): owner 1, member 2; B (102): owner 3; C (103): owner 4, the feature off.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'config-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Config A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": false}', '{"member": ["viewStock"]}'),
  (pg_temp.u(102), 'Config B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{"stockManagement": true}', '{}'),
  (pg_temp.u(103), 'Config C', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active'),
  (pg_temp.u(204), pg_temp.u(103), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Beans', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Wine', 500, true, null, 'l', 'none', true),
  (pg_temp.u(303), pg_temp.u(102), 'Tea', 200, true, null, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(103), 'Rice', 200, true, null, 'kg', 'none', true);
-- #4471: an item's own unit is one of the business's units, so the fixtures say which
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'count', 1, 1),
  (pg_temp.u(101), 'glass', 'Glass', 'count', 1, 1),
  (pg_temp.u(101), 'box', 'Box', 'count', 1, 1),
  (pg_temp.u(101), 'tray', 'Tray', 'count', 1, 1);
update public.workspaces set feature_flags = '{"stockManagement": true, "stockTakeOut": true}' where id = pg_temp.u(101);
update public.workspaces set feature_flags = '{"stockManagement": true}' where id = pg_temp.u(102);

-- Units are exact and per item.
select is(pg_temp.save_item(1, 301, 1, 501, '{"units": [{"unit": "carton", "factor_num": 12, "factor_den": 1, "default_purchase": true}]}'),
  jsonb_build_object('item_id', pg_temp.u(301), 'revision', 2, 'replayed', false)::text, '1 carton = 12 pieces is saved, the revision moves by one');
select is(public.stock_to_inventory(pg_temp.u(301), 'carton', 2) = 24, true, 'and 2 cartons are 24 pieces');
select pg_temp.save_item(1, 302, 1, 502, '{"units": [{"unit": "glass", "factor_num": 1, "factor_den": 5}]}');
select is(public.stock_to_inventory(pg_temp.u(302), 'glass', 3) = 0.6, true, '1 glass = 1/5 litre: 3 glasses are 0.6 l');
select is(pg_temp.save_item(1, 301, 2, 503, '{"units": [{"unit": "box", "factor_num": 6, "factor_den": 0}]}'),
  'ERR DKG11 {"field": "units[0].factor_den", "reason": "factor_invalid"}', 'a zero denominator is refused under its field');
select is(pg_temp.save_item(1, 301, 2, 504, '{"units": [{"unit": "box", "factor_num": -6, "factor_den": 1}]}'),
  'ERR DKG11 {"field": "units[0].factor_num", "reason": "factor_invalid"}', 'a negative factor is refused');
select is(pg_temp.save_item(1, 301, 2, 505, '{"units": [{"unit": "bogus", "factor_num": 1, "factor_den": 1}]}'),
  'ERR DKG11 {"field": "units[0].unit", "reason": "unit_unknown"}', '#4471: a package unit is one of the business''s units: a name that is none is refused');
select is(pg_temp.save_item(1, 301, 2, 514, '{"units": [{"unit": "piece", "factor_num": 1, "factor_den": 1}]}'),
  'ERR DKG11 {"field": "units[0].unit", "reason": "registry_unit"}', 'and the item''s own inventory unit is not a package of itself');
select is(pg_temp.save_item(1, 302, 2, 506, '{"inventory_unit": "kg"}'),
  'ERR DKG11 {"field": "inventory_unit", "reason": "dimension_mismatch"}', 'an inventory unit of another dimension under package units is refused');
select is(pg_temp.save_item(1, 302, 2, 507, '{"inventory_unit": "nonsense"}'),
  'ERR DKG11 {"field": "inventory_unit", "reason": "unit_unknown"}', 'an unknown unit is refused');
select is(pg_temp.save_item(1, 301, 2, 508, '{"units": [{"unit": "box", "factor_num": 6, "factor_den": 1, "default_purchase": true}, {"unit": "tray", "factor_num": 3, "factor_den": 1, "default_purchase": true}]}'),
  'ERR DKG11 {"field": "units", "reason": "default_purchase_twice"}', 'two default purchase units are refused');

-- A used factor is frozen with the movement; a later change affects the future only.
select pg_temp.move(601, 301, 2, 'SUPPLIER', 'MAIN', 'carton');
select pg_temp.save_item(1, 301, 2, 509, '{"units": [{"unit": "carton", "factor_num": 10, "factor_den": 1, "default_purchase": true}]}');
select pg_temp.move(602, 301, 1, 'SUPPLIER', 'MAIN', 'carton');
select is((select string_agg(quantity::text || ' ' || entered_factor_num::text || '/' || entered_factor_den::text, ', ' order by request_id)
             from public.stock_movements where item_id = pg_temp.u(301) and request_id in (pg_temp.u(601), pg_temp.u(602))),
  '24.000000 12/1, 10.000000 10/1', 'the first receipt keeps 24 pieces at 12/1, the next uses 10/1: an old quantity is never reinterpreted');
select is(pg_temp.save_item(1, 301, 3, 510, '{"inventory_unit": "kg"}') like 'ERR DKG08%'
          and pg_temp.save_item(1, 301, 3, 511, '{"tracking": "lot"}') like 'ERR DKG08%', true,
  'the inventory unit and the tracking of an item with movements stay as written');

-- Codes.
select is(pg_temp.save_item(1, 301, 3, 512, '{"units": [{"unit": "carton", "factor_num": 10, "factor_den": 1}], "codes": [{"code": "BEAN-1", "kind": "own"}, {"code": "4006381333931", "kind": "gtin", "unit": "carton"}]}'),
  jsonb_build_object('item_id', pg_temp.u(301), 'revision', 4, 'replayed', false)::text, 'an own code and a valid GTIN on a package unit are saved');
select is(pg_temp.save_item(1, 302, 2, 513, '{"units": [{"unit": "glass", "factor_num": 1, "factor_den": 5}], "codes": [{"code": "BEAN-1", "kind": "own"}]}'),
  'ERR DKG11 {"field": "codes[0].code", "reason": "code_duplicate"}', 'a code another item of the business has is refused');
select is(pg_temp.save_item(3, 303, 1, 514, '{"codes": [{"code": "BEAN-1", "kind": "own"}]}', 102),
  jsonb_build_object('item_id', pg_temp.u(303), 'revision', 2, 'replayed', false)::text, 'the same code in another business does not collide');
select is(pg_temp.save_item(1, 302, 2, 515, '{"units": [{"unit": "glass", "factor_num": 1, "factor_den": 5}], "codes": [{"code": "1234567", "kind": "gtin"}]}'),
  'ERR DKG11 {"field": "codes[0].code", "reason": "gtin_length"}', 'a GTIN of 7 digits is refused');
select is(pg_temp.save_item(1, 302, 2, 516, '{"units": [{"unit": "glass", "factor_num": 1, "factor_den": 5}], "codes": [{"code": "4006381333932", "kind": "gtin"}]}'),
  'ERR DKG11 {"field": "codes[0].code", "reason": "gtin_check"}', 'a GTIN with a wrong check digit is refused');

-- Revision and request id.
select is(pg_temp.save_item(1, 302, 2, 517, '{"stockable": true}') like 'ERR DKG10%' = false
          and pg_temp.save_item(1, 302, 2, 518, '{"shelf_life_days": 30}') like 'ERR DKG10%', true,
  'two saves of one revision: only the first wins, the second changes nothing');
select is((select shelf_life_days from public.services where id = pg_temp.u(302)), null, 'and what the stale save carried is not written');
select pg_temp.save_item(1, 302, 3, 519, '{"shelf_life_days": 30}');
select is(pg_temp.save_item(1, 302, 3, 519, '{"shelf_life_days": 30}') like '%"replayed": true%'
          and pg_temp.save_item(1, 302, 3, 519, '{"shelf_life_days": 31}') like 'ERR DKG07%', true,
  'the same request id with the same body answers replayed, with another body it refuses');

-- Places.
select is((pg_temp.save_place(1, null, null, 520, '{"kind": "zone", "code": "S1", "parent_id": "' || pg_temp.loc('MAIN') || '"}')::jsonb ->> 'revision'), '1',
  'a place is created under MAIN');
select is(pg_temp.save_place(1, pg_temp.loc('MAIN'), 1, 521, '{"parent_id": "' || pg_temp.loc('S1') || '"}'),
  'ERR DKG11 {"field": "parent_id", "reason": "location_cycle"}', 'a place cannot go under its own child');
select is(pg_temp.save_place(1, pg_temp.loc('S1'), 1, 522, '{"parent_id": "' || pg_temp.loc('S1') || '"}'),
  'ERR DKG11 {"field": "parent_id", "reason": "location_cycle"}', 'nor under itself');
select is(pg_temp.save_place(1, pg_temp.loc('S1'), 1, 523, format('{"parent_id": "%s"}', (select id from public.stock_locations where workspace_id = pg_temp.u(102) limit 1))),
  'ERR DKG11 {"field": "parent_id", "reason": "location_parent_foreign"}', 'a parent of another business is refused');
select is(pg_temp.save_place(1, pg_temp.loc('SUPPLIER'), 1, 524, '{"name": "mine"}'),
  'ERR DKG11 {"field": "place", "reason": "location_virtual"}', 'a virtual place is the server''s');
select pg_temp.move(603, 301, 5, 'MAIN', 'S1');
select is(pg_temp.save_place(1, pg_temp.loc('S1'), 1, 525, '{"active": false}'),
  'ERR DKG11 {"field": "active", "reason": "location_occupied"}', 'a place with stock is not deactivated');
select is(pg_temp.save_place(1, pg_temp.loc('MAIN'), 1, 526, '{"active": false}'),
  'ERR DKG11 {"field": "active", "reason": "location_default"}', 'the default place is not deactivated');
select is((select (select count(*) from public.stock_locations where id = pg_temp.loc('S1')) = 1
           and (pg_temp.run_as(pg_temp.u(1), format('delete from public.stock_locations where id = %L', pg_temp.loc('S1'))) like 'ERR %')), true,
  'and it cannot be deleted by a client');

-- Who writes.
update public.workspaces set role_permissions = '{"member": ["viewStock"]}' where id = pg_temp.u(101);
select is(pg_temp.save_item(2, 302, 4, 530, '{"shelf_life_days": 20}') like 'ERR DKN01%', true, 'a member who only sees the stock writes nothing');
update public.workspaces set role_permissions = '{"member": ["manageServices"]}' where id = pg_temp.u(101);
select is(pg_temp.save_item(2, 302, 4, 531, '{"shelf_life_days": 20}') like 'ERR DKN01%'
          and pg_temp.save_place(2, null, null, 532, '{"kind": "shelf", "code": "S9"}') like 'ERR DKN01%', true, 'a manager of services and prices holds nothing here');
update public.workspaces set role_permissions = '{"member": ["manageStock"]}' where id = pg_temp.u(101);
select is((pg_temp.save_item(2, 302, 4, 533, '{"shelf_life_days": 20}')::jsonb ->> 'revision'), '5', 'a stock manager writes the stock configuration');
select is((select name || ' ' || price_cents::text from public.services where id = pg_temp.u(302)), 'Wine 500', 'and the service''s name and price are untouched');
select is(pg_temp.save_item(3, 302, 5, 534, '{"shelf_life_days": 20}') like 'ERR DKN01%'
          and pg_temp.save_item(1, 302, 5, 535, '{"shelf_life_days": 20}', 101, true) like 'ERR DKN01%'
          and pg_temp.save_item(4, 304, 1, 536, '{"shelf_life_days": 20}', 103) like 'ERR DKG01%', true,
  'another business, a delegated assistant session and the feature off are refused');

-- A value of the wrong type is a refusal of its field, never a raw cast error.
select is(pg_temp.save_item(1, 302, pg_temp.rev(302), 901, '{"stockable": "abc"}'),
  'ERR DKG11 {"field": "stockable", "reason": "malformed"}', 'a stockable flag that is not a boolean answers DKG11 with its field');
select is(pg_temp.save_place(1, pg_temp.loc('MAIN'), (select revision from public.stock_locations where id = pg_temp.loc('MAIN')), 902, '{"active": "x"}'),
  'ERR DKG11 {"field": "active", "reason": "malformed"}', 'a place flag that is not a boolean answers DKG11 with its field');

-- A code is checked against the units the item will have, and a unit a kept code names stays.
select is(pg_temp.save_item(1, 302, pg_temp.rev(302), 903, '{"units": [{"unit": "glass", "factor_num": 1, "factor_den": 5}], "codes": [{"code": "GLASS-1", "kind": "own", "unit": "glass"}]}') like '%"replayed": false%', true,
  'a code naming a unit of the same request is saved');
select is(pg_temp.save_item(1, 302, pg_temp.rev(302), 904, '{"codes": [{"code": "GLASS-2", "kind": "own", "unit": "glass"}]}') like '%"replayed": false%', true,
  'a code naming a unit the item already has is saved without resending the units');
select is(pg_temp.save_item(1, 302, pg_temp.rev(302), 905, '{"units": []}'),
  'ERR DKG11 {"field": "units", "reason": "code_unit_removed"}', 'removing a unit a kept code names answers DKG11, not a raw foreign-key error');

select * from finish();
rollback;
