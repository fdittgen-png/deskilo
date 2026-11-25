-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4294 (0856-0858): reorder points per item and site, low-stock alerts, the replenishment list and the
-- draft order. A point is set by one guarded command; low is read from the ledger per site; one alert
-- per point while it stays low (a repeated movement changes nothing), ended when the stock rises above
-- it; two sites with their own levels alert separately; a second business sees nothing; the list
-- groups by the preferred article in whole purchase units; the draft order carries the article and the
-- unit and is idempotent. Rolled back.
begin;
select plan(41);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
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
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'ok'; exception when others then return sqlstate; end
$f$;
-- a point: user, point id (null: new), revision, request, body
create or replace function pg_temp.point(p_user int, p_point uuid, p_rev int, p_req int, p_body text, p_ws int default 101, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.save_stock_reorder_point_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), p_point, p_rev, pg_temp.u(p_req), p_body), p_delegated)
$f$;
create or replace function pg_temp.mv(p_req int, p_item int, p_qty text, p_from text, p_to text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"}]', pg_temp.u(p_item), p_qty, pg_temp.loc(p_from), pg_temp.loc(p_to)), p_reason))
$f$;
create or replace function pg_temp.consume(p_req int, p_item int, p_qty text, p_from text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_consume_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"}]', pg_temp.u(p_item), p_qty, pg_temp.loc(p_from), pg_temp.loc('LOSS'))))
$f$;
create or replace function pg_temp.alerts(p_item int default null, p_open boolean default null) returns int language sql volatile as $f$
  select count(*)::int from public.events e where e.workspace_id = pg_temp.u(101) and e.type = 'stock_low'
     and (p_item is null or e.payload ->> 'item_id' = pg_temp.u(p_item)::text)
     and (p_open is null or p_open = not (e.payload ? 'ended'))
$f$;
create or replace function pg_temp.low(p_user int, p_fn text default 'stock_low_v1', p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.%s(%L)::text', p_fn, pg_temp.u(p_ws)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'reorder-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Reorder A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockTakeOut": true, "stockReorder": true, "purchases": true, "purchaseOrders": true}', '{"member": ["viewStock"]}'),
  (pg_temp.u(102), 'Reorder B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true, "stockReorder": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Beans', 900, true, 'kg', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Mugs', 300, true, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Filters', 100, true, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(102), 'Foreign', 100, true, 'piece', 'none', true);
-- #4471: an item's own unit is one of the business's units, so the fixtures say which
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'count', 1, 1);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (pg_temp.u(101), pg_temp.u(302), 'carton', 6, 1);
insert into public.suppliers (id, workspace_id, supplier_number, name) values
  (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Roaster Co'), (pg_temp.u(402), pg_temp.u(101), 'S-2', 'Other Co');
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'SHELF-A', 'Shelf A', pg_temp.loc('MAIN')),
  (pg_temp.u(101), 'warehouse', 'BRANCH', 'Branch', null);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values (pg_temp.u(101), 'shelf', 'BRANCH-S1', 'Branch shelf', pg_temp.loc('BRANCH'));
select pg_temp.mv(900, 301, '10', 'SUPPLIER', 'MAIN', 'receipt');
select pg_temp.mv(901, 302, '10', 'SUPPLIER', 'MAIN', 'receipt');
select pg_temp.mv(902, 302, '10', 'SUPPLIER', 'BRANCH', 'receipt');
select pg_temp.mv(903, 303, '2', 'SUPPLIER', 'MAIN', 'receipt');
-- the preferred articles: beans from S-1 in kg, mugs from S-1 in cartons of 6 (a second, unpreferred one at S-2)
select pg_temp.run_as(pg_temp.u(1), format($q$select public.save_supplier_item_mapping_v1(%L, null, null, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(910),
  format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "BEAN-1", "preferred": true}', pg_temp.u(401), pg_temp.u(301))));
select pg_temp.run_as(pg_temp.u(1), format($q$select public.save_supplier_item_mapping_v1(%L, null, null, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(911),
  format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "MUG-6", "purchase_unit": "carton", "preferred": true}', pg_temp.u(401), pg_temp.u(302))));
select set_config('t.map2', pg_temp.run_as(pg_temp.u(1), format($q$select public.save_supplier_item_mapping_v1(%L, null, null, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(912),
  format('{"supplier_id": "%s", "item_id": "%s", "article_ref": "MUG-O"}', pg_temp.u(402), pg_temp.u(302)))), false);

-- ── setting a point ──
select set_config('t.p1', pg_temp.point(1, null, null, 920, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5", "reorder_quantity": "20"}', pg_temp.u(301), pg_temp.loc('MAIN'))), false);
select is((current_setting('t.p1')::jsonb ->> 'revision') || ' ' || (current_setting('t.p1')::jsonb ->> 'replayed'), '1 false', 'the owner sets a point for the beans at the main site');
select is((pg_temp.point(1, null, null, 920, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5", "reorder_quantity": "20"}', pg_temp.u(301), pg_temp.loc('MAIN')))::jsonb ->> 'replayed'), 'true',
  'the same request answers the same point');
select is(pg_temp.point(1, null, null, 920, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "6"}', pg_temp.u(301), pg_temp.loc('MAIN'))) like 'ERR P0001%' or
          pg_temp.point(1, null, null, 920, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "6"}', pg_temp.u(301), pg_temp.loc('MAIN'))) like 'ERR DKG07%', true,
  'another body under that request id is refused');
select is(pg_temp.point(2, null, null, 921, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5"}', pg_temp.u(302), pg_temp.loc('MAIN'))), 'ERR DKN01 ', 'a member who only sees the stock sets nothing');
select is(pg_temp.point(1, null, null, 922, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5"}', pg_temp.u(302), pg_temp.loc('MAIN')), 101, true), 'ERR DKN01 ', 'an assistant session sets nothing');
select is(pg_temp.point(1, null, null, 923, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5"}', pg_temp.u(304), pg_temp.loc('MAIN'))),
  'ERR DKG11 {"field": "item_id", "reason": "item_foreign"}', 'an item of another business is refused');
select is(pg_temp.point(1, null, null, 924, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5"}', pg_temp.u(302), pg_temp.loc('SHELF-A'))),
  'ERR DKG11 {"field": "site_id", "reason": "site_unknown"}', 'a shelf is not a site');
select is(pg_temp.point(1, null, null, 925, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5", "reorder_quantity": "6", "target_quantity": "20"}', pg_temp.u(302), pg_temp.loc('MAIN'))),
  'ERR DKG11 {"field": "target_quantity", "reason": "quantity_and_target"}', 'an order quantity and a target together are refused');
select is(pg_temp.point(1, null, null, 926, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5", "target_quantity": "4"}', pg_temp.u(302), pg_temp.loc('MAIN'))),
  'ERR DKG11 {"field": "target_quantity", "reason": "target_below_point"}', 'a target at or below the point is refused');
select is(pg_temp.point(1, null, null, 927, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5.1234567"}', pg_temp.u(302), pg_temp.loc('MAIN'))),
  'ERR DKG11 {"field": "reorder_point", "reason": "quantity_invalid"}', 'a quantity has at most six decimals');
select is(pg_temp.point(1, null, null, 928, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5"}', pg_temp.u(301), pg_temp.loc('MAIN'))),
  'ERR DKG11 {"field": "item_id", "reason": "point_twice"}', 'one point per item and site');
select is(pg_temp.point(1, (current_setting('t.p1')::jsonb ->> 'point_id')::uuid, 7, 929, '{"reorder_point": "6"}'), 'ERR DKG10 ', 'a stale revision is refused');
select is(pg_temp.point(1, (current_setting('t.p1')::jsonb ->> 'point_id')::uuid, 1, 930, format('{"site_id": "%s"}', pg_temp.loc('BRANCH'))),
  'ERR DKG11 {"field": "item_id", "reason": "point_fixed"}', 'what a point is for does not change');
update public.workspaces set feature_flags = feature_flags || '{"stockReorder": false}' where id = pg_temp.u(101);
select is(left(pg_temp.point(1, null, null, 931, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5"}', pg_temp.u(302), pg_temp.loc('MAIN'))), 9), 'ERR DKG01', 'with the feature off no point is set');
update public.workspaces set feature_flags = feature_flags || '{"stockReorder": true}' where id = pg_temp.u(101);
select is((select count(*) from public.stock_reorder_points where workspace_id = pg_temp.u(101))::int, 1, 'and the refused ones wrote nothing: one point');

-- ── the alert: one while low, ended above, a new one when low again ──
select is(pg_temp.alerts(301), 0, '10 of 5: not low, no alert');
select pg_temp.consume(940, 301, '3', 'MAIN');
select is(pg_temp.alerts(301), 0, '7 of 5: not low');
select pg_temp.consume(941, 301, '2', 'MAIN');
select is(pg_temp.alerts(301) || '/' || pg_temp.alerts(301, true), '1/1', 'at the point (5): exactly one alert, open');
select pg_temp.consume(942, 301, '1', 'MAIN');
select is(pg_temp.alerts(301), 1, 'a further take-out while low raises no second alert');
select pg_temp.mv(943, 301, '4', 'SUPPLIER', 'MAIN', 'receipt');
select is(pg_temp.alerts(301, true) || '/' || pg_temp.alerts(301, false), '0/1', 'a receipt lifting it above the point ends the alert');
select pg_temp.consume(944, 301, '3', 'MAIN');
select is(pg_temp.alerts(301) || '/' || pg_temp.alerts(301, true), '2/1', 'low again: a new alert while the first stays ended');

-- ── two sites with their own levels ──
select pg_temp.point(1, null, null, 950, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "8", "target_quantity": "20"}', pg_temp.u(302), pg_temp.loc('MAIN')));
select pg_temp.point(1, null, null, 951, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "3", "target_quantity": "20"}', pg_temp.u(302), pg_temp.loc('BRANCH')));
select is(pg_temp.alerts(302), 0, 'mugs: 10 at each site, points 8 and 3: none low');
select pg_temp.consume(952, 302, '3', 'MAIN');
select is((select string_agg(e.payload ->> 'site_id', ',') from public.events e where e.type = 'stock_low' and e.payload ->> 'item_id' = pg_temp.u(302)::text),
  pg_temp.loc('MAIN')::text, '3 taken at the main site (7 of 8): only the main site alerts, not the branch (10 of 3)');
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_transfer_load_v1(%L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(953), pg_temp.loc('BRANCH'),
  format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s"}]', pg_temp.u(302), pg_temp.loc('MAIN'), pg_temp.loc('MAIN'))));
select is(pg_temp.alerts(302), 1, 'goods loaded onto the road leave the site''s count but raise no second alert while it is already low');
-- a point set on a stock already low raises its alert at once
select pg_temp.point(1, null, null, 954, format('{"item_id": "%s", "site_id": "%s", "reorder_point": "5", "reorder_quantity": "10"}', pg_temp.u(303), pg_temp.loc('MAIN')));
select is(pg_temp.alerts(303), 1, 'a point set on a stock already at or below it alerts at once (2 of 5)');

-- ── who sees what ──
select is((select count(*) from public.events where type = 'stock_low' and workspace_id = pg_temp.u(101))::int > 0, true, 'the alerts exist');
select is(pg_temp.run_as(pg_temp.u(2), $q$select count(*)::text from public.events where type = 'stock_low'$q$), '0', 'a member who only sees the stock does not read them');
select is(pg_temp.run_as(pg_temp.u(4), $q$select count(*)::text from public.events where type = 'stock_low'$q$), '0', 'nor does another business');
select is(pg_temp.run_as(pg_temp.u(1), $q$select (count(*) > 0)::text from public.events where type = 'stock_low'$q$), 'true', 'the owner does');
select is(left(pg_temp.low(4), 9), 'ERR DKN01', 'another business reads no list of this one');
select is(jsonb_array_length(pg_temp.low(2)::jsonb -> 'rows') >= 3, true, 'a member who sees the stock reads what is low');
update public.workspaces set role_permissions = '{"member": ["managePurchases"]}' where id = pg_temp.u(101);
select is(jsonb_array_length(pg_temp.low(2)::jsonb -> 'rows') >= 3, true, 'and so does one who manages the purchases');
update public.workspaces set role_permissions = '{"member": ["viewStock"]}' where id = pg_temp.u(101);

-- ── the replenishment list and the draft order ──
select set_config('t.list', pg_temp.low(1, 'stock_replenishment_v1'), false);
select is((select string_agg(l ->> 'article_ref' || ':' || (l ->> 'purchase_unit') || ':' || (l ->> 'quantity'), ',' order by l ->> 'article_ref')
             from jsonb_array_elements(current_setting('t.list')::jsonb -> 'groups') g, jsonb_array_elements(g -> 'lines') l),
  'BEAN-1:kg:20.000000,MUG-6:carton:3', 'the list proposes the reorder quantity (20 kg) and up to the target in whole cartons (13 of 6 = 3)');
select is(jsonb_array_length(current_setting('t.list')::jsonb -> 'no_supplier'), 1, 'Filters (no preferred article) are listed under "no supplier chosen"');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.save_supplier_item_mapping_v1(%L, %L, 1, %L, %L::jsonb)::text$q$, pg_temp.u(101), (current_setting('t.map2')::jsonb ->> 'mapping_id')::uuid, pg_temp.u(913), '{"preferred": true}')) like 'ERR DKG11 {"field": "preferred", "reason": "preferred_twice"}',
  true, 'a second preferred article for one item is refused');
select set_config('t.draft', pg_temp.run_as(pg_temp.u(1), format($q$select public.create_replenishment_draft_v1(%L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(960), pg_temp.u(401),
  format('[{"item_id": "%s", "quantity": "20"}, {"item_id": "%s", "quantity": "3"}]', pg_temp.u(301), pg_temp.u(302)))), false);
select is((select count(*)::int from public.purchase_orders where workspace_id = pg_temp.u(101) and state = 'draft')
          || '/' || (select string_agg(l.description || ':' || l.unit || ':' || l.quantity::text, ',' order by l.description) from public.purchase_order_lines l where l.workspace_id = pg_temp.u(101)),
  '1/BEAN-1 Beans:kg:20,MUG-6 Mugs:carton:3', 'the draft order carries the preferred articles, their units and quantities, and is only a draft');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.create_replenishment_draft_v1(%L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(960), pg_temp.u(401),
  format('[{"item_id": "%s", "quantity": "20"}, {"item_id": "%s", "quantity": "3"}]', pg_temp.u(301), pg_temp.u(302)))), current_setting('t.draft'), 'the same request answers the same draft: no second order');
select is((select count(*)::int from public.purchase_orders where workspace_id = pg_temp.u(101)), 1, 'and makes no second order');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.create_replenishment_draft_v1(%L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(961), pg_temp.u(402),
  format('[{"item_id": "%s", "quantity": "1"}]', pg_temp.u(301)))), 'ERR DKG11 {"field": "lines[0]", "reason": "mapping_unknown"}', 'a line that is not that supplier''s preferred article is refused');
select is(left(pg_temp.run_as(pg_temp.u(2), format($q$select public.create_replenishment_draft_v1(%L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(962), pg_temp.u(401),
  format('[{"item_id": "%s", "quantity": "1"}]', pg_temp.u(301)))), 7), 'ERR 425', 'a member without managePurchases makes no draft');

-- ── cheap ──
select ok(regexp_replace(pg_get_functiondef('public.stock_movements_reorder()'::regprocedure), '\s+', ' ', 'g') like '%not exists (select 1 from public.stock_reorder_points p where p.item_id = new.item_id and p.active) then return null%',
  'the movement trigger leaves at once for an item without an active point');

select * from finish();
rollback;
