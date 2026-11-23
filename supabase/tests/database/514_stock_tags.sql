-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4362 (0884-0886): RFID tags and the resolver of a scan. A tag is an EPC or a chip UID, normalised to uppercase hex
-- and unique per business among those in force whatever it names; SGTIN-96 decodes to its GTIN-14 and serial; the
-- item's tag mode says what a tag on it names and is pinned by the first tag; a tag in force elsewhere is refused
-- with its owner named and a retired one waits out the grace period; the rights, an assistant, another business and
-- the feature off are refused; the one resolver answers place, item, variant, package unit, lot, tag and unknown for
-- barcodes and tags, scoped to the business, names only for an assistant. Rolled back.
begin;
select plan(46);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
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

create or replace function pg_temp.bind(p_user int, p_req int, p_tag text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_tag_bind_v1(%L, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_req), p_tag), p_delegated)
$f$;
create or replace function pg_temp.retire(p_user int, p_req int, p_code text, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_tag_retire_v1(%L, %L, %L, %L)::text', pg_temp.u(p_ws), pg_temp.u(p_req), p_code, 'taken off'))
$f$;
create or replace function pg_temp.res(p_user int, p_code text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_resolve_code_v1(%L, %L)::text', pg_temp.u(p_ws), p_code), p_delegated)
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tag-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Tags A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockItemGroups": true}', '{"member": ["viewStock"], "admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Tags B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 300, true, 'piece', 'none', true, null),
  (pg_temp.u(302), pg_temp.u(101), 'Apples', 100, true, 'kg', 'lot', true, 'per_batch'),
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit'),
  (pg_temp.u(304), pg_temp.u(102), 'Foreign', 100, true, 'piece', 'none', true, 'per_batch');
insert into public.item_codes (workspace_id, item_id, unit, code, kind) values
  (pg_temp.u(101), pg_temp.u(301), null, '4006381333931', 'gtin'), (pg_temp.u(101), pg_temp.u(301), null, 'MUG-OWN', 'own');
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1);
insert into public.item_codes (workspace_id, item_id, unit, code, kind) values (pg_temp.u(101), pg_temp.u(301), 'carton', 'CARTON-12', 'own');
insert into public.item_variants (id, workspace_id, item_id, canonical) values (pg_temp.u(311), pg_temp.u(101), pg_temp.u(301), 'colour:red');
insert into public.item_codes (workspace_id, item_id, variant_id, code, kind) values (pg_temp.u(101), pg_temp.u(301), pg_temp.u(311), 'MUG-RED', 'own');
insert into public.stock_lots (id, workspace_id, item_id, lot_code, total_cost_minor, quantity_received, label_code) values
  (pg_temp.u(321), pg_temp.u(101), pg_temp.u(302), 'A1', 1000, 20, 'LOT-A1');
update public.stock_locations set barcode = '2000000000015' where workspace_id = pg_temp.u(101) and code = 'MAIN';
-- an item of the other business with the same GTIN
insert into public.item_codes (workspace_id, item_id, unit, code, kind) values (pg_temp.u(102), pg_temp.u(304), null, '4006381333931', 'gtin');

-- ── the settings and the scanning flag ──
select is((select (default_value #>> '{}') || ' ' || min_value || '..' || max_value || ' ' || unit from public.setting_definitions where key = 'stock.tag_rebind_grace_days'),
  '30 0..365 days', 'the grace period of a retired tag is a business setting of 30 days');
select is((select (default_value #>> '{}') || ' ' || array_to_string(array(select jsonb_array_elements_text(choices)), ',') from public.setting_definitions where key = 'stock.repeated_scan'),
  'add_one add_one,ask_quantity', 'what a repeated scan does is a business setting: add one, or ask the quantity');
select is(public.feature_effective(pg_temp.u(101), 'stockScanning'), false, 'scanning is asked for: off until it is chosen');
update public.workspaces set feature_flags = feature_flags || '{"stockScanning": true}' where id = pg_temp.u(101);
select is(public.feature_effective(pg_temp.u(101), 'stockScanning'), true, 'and on once chosen, under the goods ledger');

-- ── the code, read ──
select is(public.stock_sgtin96_decode('3074257BF7194E4000001A85') ->> 'gtin14', '80614141123458', 'SGTIN-96: the standard example decodes to its GTIN-14');
select is(public.stock_sgtin96_decode('3074257BF7194E4000001A85') ->> 'serial', '6789', 'and its serial');
select is(public.stock_sgtin96_decode('3574257BF7194E4000001A85')::text, null, 'another header is not an SGTIN-96');
select is(public.stock_sgtin96_decode('3074257BF7194E4000001A8')::text, null, 'nor a code of the wrong length');
select is(public.stock_tag_normalize(' e2:80-68 94 00 00 40 15 61 d6 79 fa '), 'E28068940000401561D679FA', 'a tag read is normalised to uppercase hex without separators');
select is(public.stock_tag_normalize('ZZ12345678')::text, null, 'a code that is not hex is no tag');
select is(public.stock_tag_kind('04A2243B') || ' ' || public.stock_tag_kind('3074257BF7194E4000001A85'), 'uid epc', 'a chip UID and an EPC');

-- ── binding ──
select is(pg_temp.f(pg_temp.bind(3, 910, format('{"code": "04A2243B", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))), 'owner_kind'), 'place', 'a place carries a tag');
select is(pg_temp.bind(3, 911, format('{"code": "04a2243b", "owner": {"kind": "item", "item_id": "%s"}}', pg_temp.u(302))), 'ERR DKG22',
  'a tag in force on a place is refused on an item, whatever the case it was read in');
select is(pg_temp.f(pg_temp.bind(3, 910, format('{"code": "04A2243B", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))), 'owner_kind'), 'place',
  'the same bind again answers the same');
select is(pg_temp.f(pg_temp.bind(3, 912, format('{"code": "04A2243B", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))), 'replayed'), 'true',
  'and under a new request id says it was bound already');
select is(pg_temp.bind(3, 913, format('{"code": "AABBCCDD", "owner": {"kind": "item", "item_id": "%s"}}', pg_temp.u(301))), 'ERR DKG11', 'an item with no tag mode takes no tag');
select is(pg_temp.bind(3, 914, format('{"code": "AABBCCDD", "owner": {"kind": "item", "item_id": "%s"}}', pg_temp.u(303))), 'ERR DKG11', 'an item tagged piece by piece takes tags only with its pieces');
select is(pg_temp.f(pg_temp.bind(3, 915, format('{"code": "AABBCCDD", "owner": {"kind": "lot", "item_id": "%s", "lot_id": "%s"}}', pg_temp.u(302), pg_temp.u(321))), 'owner_kind'), 'lot',
  'a batch carries a tag where the item is tagged by batch');
select is(pg_temp.bind(3, 916, 'not json'), 'ERR 22P02', 'a request that is not JSON is refused');
select is(pg_temp.bind(3, 917, '{"code": "XYZ", "owner": {"kind": "place"}}'), 'ERR DKG11', 'a code that is no tag is refused');
select is(pg_temp.bind(3, 918, format('{"code": "11223344", "owner": {"kind": "lot", "item_id": "%s", "lot_id": "%s"}}', pg_temp.u(301), pg_temp.u(321))), 'ERR DKG11', 'a lot of another item is refused');
select is(pg_temp.bind(2, 919, format('{"code": "55667788", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))), 'ERR DKN01', 'a member who only sees the stock cannot bind');
select is(pg_temp.bind(3, 920, format('{"code": "55667788", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN')), 101, true), 'ERR DKN01', 'nor can an assistant');
select is(pg_temp.run_as(pg_temp.u(4), format('select public.stock_tag_bind_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(921),
  format('{"code": "55667788", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN')))), 'ERR P0001', 'nor a person of another business');
select is((select tag_mode from public.services where id = pg_temp.u(302)), 'per_batch', 'the first tag pinned the tag mode on the item');
select is(pg_temp.f(pg_temp.bind(4, 922, format('{"code": "04A2243B", "owner": {"kind": "item", "item_id": "%s"}}', pg_temp.u(304)), 102), 'owner_kind'), 'item',
  'another business binds the same code to its own item: codes are unique per business');

-- ── retiring ──
select is(pg_temp.f(pg_temp.retire(3, 930, '04a2243b'), 'retired'), 'true', 'a tag is retired');
select is(pg_temp.bind(3, 931, format('{"code": "04A2243B", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))), 'ERR DKG23', 'and waits out the grace period before it is bound again');
select is((select state from public.stock_tags where workspace_id = pg_temp.u(101) and code = '04A2243B'), 'retired', 'it stays as history');
insert into public.setting_values (scope, workspace_id, key, value, note) values ('workspace', pg_temp.u(101), 'stock.tag_rebind_grace_days', '0'::jsonb, 'test');
select is(pg_temp.f(pg_temp.bind(3, 932, format('{"code": "04A2243B", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))), 'replayed'), 'false', 'with no grace it is bound at once');
select is(pg_temp.retire(3, 933, 'FFEEDDCC'), 'ERR DKG04', 'a tag not in force cannot be retired');
select is(pg_temp.retire(3, 934, '04A2243B') like '{%', true, 'it can be retired again');

-- ── an item with tags keeps its tag mode ──
select is(pg_temp.run_as(pg_temp.u(1), format('select public.item_override_save_v1(%L, %L, %L, %s, %L, %L, %L::jsonb)::text',
  pg_temp.u(101), pg_temp.u(940), pg_temp.u(302), (select stock_revision from public.services where id = pg_temp.u(302)), 'tag_mode', 'set', '"none"')), 'ERR DKG11',
  'the tag mode of an item with tags in force is not changed');

-- ── the resolver ──
select is(pg_temp.f(pg_temp.res(2, '2000000000015'), 'kind') || ' ' || pg_temp.f(pg_temp.res(2, '2000000000015'), 'matched_by'), 'place place_barcode', 'a place by its barcode');
select is(pg_temp.f(pg_temp.res(2, 'MAIN'), 'matched_by'), 'place_code', 'and by its code');
select is(pg_temp.f(pg_temp.res(2, '4006381333931'), 'kind') || ' ' || pg_temp.f(pg_temp.res(2, '4006381333931'), 'matched_by'), 'item gtin', 'an item by its GTIN');
select is(pg_temp.f(pg_temp.res(2, '04006381333931'), 'matched_by'), 'gtin', 'whatever the length it was read in');
select is(pg_temp.res(2, 'MUG-OWN')::jsonb #>> '{item,name}', 'Mugs', 'an item by its own code');
select is(pg_temp.res(2, 'CARTON-12')::jsonb #>> '{unit,factor_num}', '12', 'a package unit with its factor');
select is(pg_temp.f(pg_temp.res(2, 'MUG-RED'), 'kind') || ' ' || (pg_temp.res(2, 'MUG-RED')::jsonb #>> '{variant,label}'), 'variant colour:red', 'a variant');
select is(pg_temp.f(pg_temp.res(2, 'LOT-A1'), 'kind') || ' ' || (pg_temp.res(2, 'LOT-A1')::jsonb #>> '{lot,code}'), 'lot A1', 'a lot by its label');
select is(pg_temp.f(pg_temp.res(2, 'AABBCCDD'), 'kind') || ' ' || (pg_temp.res(2, 'AABBCCDD')::jsonb #>> '{tag,owner_kind}'), 'tag lot', 'a tag, with what it names');
select is(pg_temp.f(pg_temp.res(2, 'NOPE-NOT-HERE'), 'kind'), 'unknown', 'an unknown code is unknown, not an error');
select is(pg_temp.f(pg_temp.res(4, '4006381333931', 101), 'kind'), 'ERR DKN01', 'another business cannot ask about this one');
select is(pg_temp.res(4, '4006381333931', 102)::jsonb #>> '{item,name}', 'Foreign', 'and finds its own item under the same code');
select is((pg_temp.res(3, 'MUG-OWN', 101, true)::jsonb -> 'item') ? 'id', false, 'an assistant is told the name and no identifier');

select * from finish();
rollback;
