-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4293 (0855, G7 cut A): the places form levels - site, zone, aisle, bay, shelf or bin - a level
-- sits only under the level directly above it, a code is unique among siblings, the address is
-- composed from the parents' codes and follows a rename, a site says whether it receives from
-- suppliers, a place below it is picking or reserve, and a place made before the levels stays
-- editable. Rolled back.
begin;
select plan(25);

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

create or replace function pg_temp.save_place(p_user int, p_place uuid, p_rev int, p_req int, p_body text, p_ws int default 101)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_location_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_place, p_rev, pg_temp.u(p_req), p_body))
$f$;


create or replace function pg_temp.addr(p_code text, p_parent text default null) returns text language sql stable as $f$
  select replace(address_path, chr(31), '/') from public.stock_locations
   where workspace_id = pg_temp.u(101) and code = p_code
     and parent_id is not distinct from (select id from public.stock_locations where workspace_id = pg_temp.u(101) and address_path = p_parent)
$f$;
create or replace function pg_temp.kid(p_path text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and replace(address_path, chr(31), '/') = p_path
$f$;
create or replace function pg_temp.mk(p_req int, p_parent text, p_kind text, p_code text, p_extra text default '') returns text language sql as $f$
  select pg_temp.save_place(1, null, null, p_req, format('{"kind": "%s", "code": "%s"%s%s}', p_kind, p_code,
    case when p_parent is null then '' else format(', "parent_id": "%s"', pg_temp.kid(p_parent)) end, p_extra))
$f$;
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'ok'; exception when others then return sqlstate; end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'levels-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Levels A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": true}', '{"member": ["viewStock"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');

-- a place made before the levels: a shelf straight under a warehouse, inserted as old code did
insert into public.stock_locations (workspace_id, kind, code, name) values (pg_temp.u(101), 'warehouse', 'MAIN', 'Main')
  on conflict do nothing;
insert into public.stock_locations (workspace_id, parent_id, kind, code, name)
  values (pg_temp.u(101), pg_temp.kid('MAIN'), 'shelf', 'OLD', 'Old shelf');

-- the levels, one under the other
select is(pg_temp.mk(701, null, 'site', 'MAG1')::jsonb ->> 'revision', '1', 'a site is made at the root');
select is(pg_temp.mk(702, 'MAG1', 'zone', 'SALES')::jsonb ->> 'revision', '1', 'a zone under the site');
select is(pg_temp.mk(703, 'MAG1/SALES', 'aisle', 'A03')::jsonb ->> 'revision', '1', 'an aisle under the zone');
select is(pg_temp.mk(704, 'MAG1/SALES/A03', 'bay', 'B02')::jsonb ->> 'revision', '1', 'a bay under the aisle');
select is(pg_temp.mk(705, 'MAG1/SALES/A03/B02', 'shelf', 'S4')::jsonb ->> 'revision', '1', 'a shelf under the bay');
select is(pg_temp.addr('S4', (select address_path from public.stock_locations where code = 'B02' and workspace_id = pg_temp.u(101))), 'MAG1/SALES/A03/B02/S4',
  'its address is composed from the codes of its parents');

-- a level sits only under the level directly above it
select is(pg_temp.mk(706, 'MAG1/SALES', 'bay', 'B09'), 'ERR DKG11 {"field": "parent_id", "reason": "level_parent_wrong"}', 'a bay straight under a zone is refused');
select is(pg_temp.mk(707, null, 'shelf', 'S9'), 'ERR DKG11 {"field": "parent_id", "reason": "level_parent_missing"}', 'a shelf at the root is refused');
select is(pg_temp.mk(708, 'MAG1/SALES', 'site', 'MAG2'), 'ERR DKG11 {"field": "parent_id", "reason": "level_parent_wrong"}', 'a site under a zone is refused');
select is(pg_temp.mk(709, 'MAG1', 'counter', 'CASH')::jsonb ->> 'revision', '1', 'a place of no level (a counter) is still placed anywhere');

-- a code is unique among siblings only
select is(pg_temp.mk(710, 'MAG1/SALES/A03', 'bay', 'B03')::jsonb ->> 'revision', '1', 'a second bay');
select is(pg_temp.mk(711, 'MAG1/SALES/A03/B03', 'shelf', 'S4')::jsonb ->> 'revision', '1', 'the same shelf code under another bay is a different address');
select is(pg_temp.mk(712, 'MAG1/SALES/A03/B03', 'shelf', 'S4'), 'ERR DKG11 {"field": "code", "reason": "code_duplicate"}', 'but not twice under one bay');
select is(pg_temp.mk(713, null, 'site', 'MAIN'), 'ERR DKG11 {"field": "code", "reason": "code_duplicate"}', 'nor twice at the root (the old codes stay unique)');

-- a rename moves the addresses below
select pg_temp.save_place(1, pg_temp.kid('MAG1/SALES'), 1, 714, '{"code": "FLOOR"}');
select is(pg_temp.addr('S4', (select address_path from public.stock_locations where code = 'B02' and workspace_id = pg_temp.u(101))), 'MAG1/FLOOR/A03/B02/S4',
  'renaming a zone renames the addresses of everything below it');

-- changing the kind of a place under which levels sit
select is(pg_temp.save_place(1, pg_temp.kid('MAG1/FLOOR/A03/B02'), 1, 715, '{"kind": "counter"}'),
  'ERR DKG11 {"field": "kind", "reason": "level_children_wrong"}', 'a bay with shelves under it does not become a place of no level');

-- the flags
select pg_temp.save_place(1, pg_temp.kid('MAG1'), 1, 716, '{"receives_from_suppliers": false}');
select is((select receives_from_suppliers from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAG1'), false, 'a site can be set to transfers only');
select pg_temp.mk(717, 'MAG1/FLOOR', 'bay', 'X', '');
select is(pg_temp.mk(718, 'MAG1/FLOOR/A03', 'bay', 'B07', ', "receives_from_suppliers": false, "pick_role": "reserve"')::jsonb ->> 'revision', '1', 'a bay can be reserve');
select is((select receives_from_suppliers::text || pick_role from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'B07'), 'truereserve',
  'only a site says it receives: the flag of a bay stays on, its role is kept');
select is(pg_temp.mk(719, 'MAG1/FLOOR/A03', 'bay', 'B08', ', "pick_role": "shelf-edge"'), 'ERR DKG11 {"field": "pick_role", "reason": "pick_role_unknown"}', 'an unknown role is refused');

-- a place made before the levels stays editable, but is not moved into a wrong place
select is(pg_temp.save_place(1, pg_temp.kid('MAIN/OLD'), 1, 720, '{"name": "Old shelf, renamed"}')::jsonb ->> 'revision', '2', 'a shelf made under a warehouse before the levels is still renamed');
select is(pg_temp.save_place(1, pg_temp.kid('MAIN/OLD'), 2, 721, format('{"parent_id": "%s"}', pg_temp.kid('MAG1/FLOOR'))),
  'ERR DKG11 {"field": "parent_id", "reason": "level_parent_wrong"}', 'but moved under a zone it is refused: a shelf sits under a bay');

-- the default warehouse stays one: a second warehouse cannot take the name MAIN, whatever its parent
select is(pg_temp.try(format($s$insert into public.stock_locations (workspace_id, parent_id, kind, code, name) values (%L, %L, 'warehouse', 'MAIN', 'Second')$s$,
  pg_temp.u(101), pg_temp.kid('MAG1/FLOOR'))), '23505', 'a second warehouse called MAIN is refused');

-- barcodes of places stay unique per business
select pg_temp.save_place(1, pg_temp.kid('MAG1/FLOOR/A03/B03/S4'), 1, 722, '{"barcode": "PLACE-1"}');
select is(pg_temp.save_place(1, pg_temp.kid('MAG1/FLOOR/A03/B02/S4'), 1, 723, '{"barcode": "PLACE-1"}'),
  'ERR DKG11 {"field": "barcode", "reason": "code_duplicate"}', 'a barcode is still unique in the business');

-- who may
select is(pg_temp.run_as(pg_temp.u(2), format('select public.save_stock_location_v1(%L, null, null, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(730), '{"kind": "site", "code": "NOPE"}')) like 'ERR %', true,
  'a reader of the stock writes no place');

select * from finish();
rollback;
