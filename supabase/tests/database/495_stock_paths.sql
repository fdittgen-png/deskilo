-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #4170 (0847-0849, A): one authoritative stock path. The generic move checks its reason
-- against the places; a transfer inside a site is one step (exact, fractional, converted by
-- its factor), between sites it is loaded into transit and received in part with the sum
-- unchanged at each step; consumption and loss need stockTakeOut and an acknowledged expired
-- lot; no request clips or half-applies; the legacy confirmation takes exactly from MAIN and
-- what is inside it and refuses (DKG03) when less is there; the negative policy is one setting
-- and never a lot; the count is a read-only mirror once the ledger exists and off/on again
-- changes nothing; a lost response is read again by its request id. Rolled back.
begin;
select plan(72);

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
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'ok'; exception when others then return sqlstate; end
$f$;
create or replace function pg_temp.cmd(p_user int, p_fn text, p_req int, p_args text, p_ws int default 101, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.%s(%L, %L, %s)::text', p_fn, pg_temp.u(p_ws), pg_temp.u(p_req), p_args), p_delegated)
$f$;
create or replace function pg_temp.line(p_item int, p_qty text, p_from text, p_to text, p_extra text default '') returns text language sql as $f$
  select format('{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"%s}', pg_temp.u(p_item), p_qty, pg_temp.loc(p_from), pg_temp.loc(p_to), p_extra)
$f$;
create or replace function pg_temp.arr(p_lines text) returns text language sql as $f$ select format('%L::jsonb', '[' || p_lines || ']') $f$;
create or replace function pg_temp.on_hand(p_item int, p_code text) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = pg_temp.loc(p_code)
$f$;
create or replace function pg_temp.total(p_item int) returns numeric language sql stable as $f$
  select coalesce(sum(b.quantity), 0) from public.stock_balances b join public.stock_locations l on l.id = b.location_id
   join public.stock_location_kinds k on k.key = l.kind where b.item_id = pg_temp.u(p_item) and not k.virtual
$f$;
create or replace function pg_temp.move(p_req int, p_item int, p_qty text, p_from text, p_to text, p_reason text, p_extra text default '') returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req),
    '[' || pg_temp.line(p_item, p_qty, p_from, p_to, p_extra) || ']', p_reason))
$f$;
create or replace function pg_temp.detail_of(p_sql text) returns text language plpgsql as $f$
declare d text;
begin execute p_sql; return 'no refusal';
exception when others then get stacked diagnostics d = pg_exception_detail; return d;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'paths-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Paths A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true, "stockTakeOut": true, "purchases": true, "purchaseOrders": true, "stockReceiving": true}', '{"member": ["viewStock", "manageServices"]}'),
  (pg_temp.u(102), 'Paths B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{"services": true, "stockManagement": true, "stockTakeOut": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Beans', 900, true, null, 'kg', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Yoghurt', 150, true, null, 'piece', 'expiry', true),
  (pg_temp.u(303), pg_temp.u(101), 'Water', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(102), 'Foreign', 100, true, null, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (pg_temp.u(101), pg_temp.u(303), 'carton', 12, 1);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'SHELF-B', 'Shelf B', pg_temp.loc('MAIN')),
  (pg_temp.u(101), 'warehouse', 'DEPOT', 'Depot', null),
  (pg_temp.u(101), 'warehouse', 'BRANCH', 'Branch', null);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values (pg_temp.u(101), 'shelf', 'BRANCH-S1', 'Branch shelf', pg_temp.loc('BRANCH'));
select set_config('t.transit', (select id::text from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'in_transit'), false);
select pg_temp.move(900, 301, '4', 'SUPPLIER', 'DEPOT', 'receipt');
select pg_temp.move(901, 302, '5', 'SUPPLIER', 'MAIN', 'receipt', format(', "new_lot": {"code": "OLD", "expires_on": "%s", "total_cost_minor": 500}', current_date - 1));
select pg_temp.move(902, 302, '5', 'SUPPLIER', 'MAIN', 'receipt', format(', "new_lot": {"code": "NEW", "expires_on": "%s", "total_cost_minor": 600}', current_date + 30));
select pg_temp.move(903, 303, '24', 'SUPPLIER', 'SHELF-B', 'receipt');
select set_config('t.old', (select id::text from public.stock_lots where lot_code = 'OLD'), false);
select set_config('t.new', (select id::text from public.stock_lots where lot_code = 'NEW'), false);


-- fixtures of the review-in-review cases: a sent purchase order for the water, and a second business's supplier
insert into public.suppliers (id, workspace_id, supplier_number, name) values (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Water Co');
insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, created_by_member_id)
values (pg_temp.u(501), pg_temp.u(101), 2026, 1, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201));
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents)
values (pg_temp.u(101), pg_temp.u(501), 1, pg_temp.u(303), '', 5, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where id = pg_temp.u(501);

-- ONE PATH: the generic move checks its reason against the places.
select is(pg_temp.move(910, 303, '1', 'SHELF-B', 'CUSTOMER', 'sale'), 'ERR DKG11 {"field": "lines[0]", "reason": "reason_places"}', 'a sale through the generic move needs its commercial source');
select is(pg_temp.move(911, 303, '1', 'SHELF-B', 'LOSS', 'transfer'), 'ERR DKG11 {"field": "lines[0]", "reason": "reason_places"}', 'a transfer is between two real places');
select is(pg_temp.move(912, 303, '1', 'SHELF-B', 'MAIN', 'receipt'), 'ERR DKG11 {"field": "lines[0]", "reason": "reason_places"}', 'a receipt comes from a supplier');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, ''transfer'')::text', pg_temp.u(101), pg_temp.u(913),
  '[{"item_id": "' || pg_temp.u(303) || '", "quantity": "1", "from": "' || pg_temp.loc('SHELF-B') || '", "to": "' || current_setting('t.transit') || '"}]')),
  'ERR DKG11 {"field": "lines[0]", "reason": "transit_is_system"}', 'the in-transit place belongs to the two-step transfer alone');

-- TRANSFERS: one step within a site, exact and fractional; between sites only through transit.
select is(pg_temp.cmd(1, 'stock_transfer_v1', 920, pg_temp.arr(pg_temp.line(301, '0.5', 'DEPOT', 'DEPOT'))) like 'ERR DKG05%', true, 'a place is not moved onto itself');
select pg_temp.cmd(1, 'stock_transfer_v1', 921, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN')));
select is(pg_temp.on_hand(303, 'SHELF-B')::text || ' ' || pg_temp.on_hand(303, 'MAIN')::text || ' ' || pg_temp.total(303)::text, '23.000000 1.000000 24.000000',
  'a replenishment inside a site moves one piece and the site''s total stays 24');
select is(pg_temp.cmd(1, 'stock_transfer_v1', 922, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'BRANCH-S1'))),
  'ERR DKG11 {"field": "lines[0]", "reason": "transfer_needs_transit"}', 'between two sites the goods go through transit');
select is(pg_temp.cmd(1, 'stock_transfer_v1', 923, pg_temp.arr(pg_temp.line(303, '1 carton', 'SHELF-B', 'MAIN'))) like 'ERR DKG07%', true, 'a quantity is a number, never text with a unit');
select pg_temp.cmd(1, 'stock_transfer_v1', 924, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN', ', "unit": "carton"')));
select is(pg_temp.on_hand(303, 'MAIN')::text || ' ' || pg_temp.on_hand(303, 'SHELF-B')::text, '13.000000 11.000000', 'a carton is converted by its exact factor: 12 pieces');

-- ALL-LINE ROLLBACK and NO CLIPPING.
select is(pg_temp.cmd(1, 'stock_transfer_v1', 925, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN') || ', ' || pg_temp.line(303, '500', 'SHELF-B', 'MAIN'))),
  'ERR DKG03 ', 'more than there is refuses the whole request');
select is(pg_temp.on_hand(303, 'SHELF-B')::text, '11.000000', 'and the first line of it moved nothing');

-- THE LEGACY BRIDGE: stock only inside MAIN, exact, never clipped.
select pg_temp.move(930, 301, '2.5', 'SUPPLIER', 'SHELF-B', 'receipt');
select is(pg_temp.on_hand(301, 'MAIN')::text, '0', 'the beans are only at SHELF-B, inside MAIN');
select pg_temp.run_as(pg_temp.u(1), format('select public.record_service_charge(%L, %L, %L, 2)::text', pg_temp.u(101), pg_temp.u(201), pg_temp.u(301)));
update public.events set status = 'confirmed' where workspace_id = pg_temp.u(101) and type = 'service_charge' and status <> 'confirmed';
select is(pg_temp.on_hand(301, 'SHELF-B')::text, '0.500000', 'a confirmed charge of 2 takes exactly 2 from the place inside MAIN that holds them');
select pg_temp.run_as(pg_temp.u(1), format('select public.record_service_charge(%L, %L, %L, 1)::text', pg_temp.u(101), pg_temp.u(201), pg_temp.u(301)));
select is(pg_temp.try(format($q$update public.events set status = 'confirmed' where workspace_id = %L and type = 'service_charge' and status <> 'confirmed'$q$, pg_temp.u(101))), 'DKG03',
  'less than the charge says is there: the confirmation is refused, nothing is clipped');
select is((select pg_temp.detail_of(format($q$update public.events set status = 'confirmed' where workspace_id = %L and type = 'service_charge' and status <> 'confirmed'$q$, pg_temp.u(101)))),
  format('{"held": "0.500000", "asked": "1", "scope": "main_store", "item_id": "%s"}', pg_temp.u(301)),
  'and the refusal carries what the main store holds, for the screen that says it');
select is(pg_temp.on_hand(301, 'SHELF-B')::text, '0.500000', 'and the 0.5 kg that were there are still there');

-- THE NEGATIVE POLICY: one setting, an untracked item only, never a lot.
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.allow_negative', 'true'::jsonb);
select is(pg_temp.try(format($q$update public.events set status = 'confirmed' where workspace_id = %L and type = 'service_charge' and status <> 'confirmed'$q$, pg_temp.u(101))), 'ok',
  'with the setting on, the same confirmation of an untracked item is allowed');
select is(pg_temp.on_hand(301, 'MAIN')::text, '-0.500000', 'and the shortage shows as a negative quantity at MAIN');
select is(pg_temp.cmd(1, 'stock_loss_v1', 940, pg_temp.arr(pg_temp.line(302, '20', 'MAIN', 'LOSS', format(', "lot_id": "%s", "expired_ack": true', current_setting('t.new'))))),
  'ERR DKG03 ', 'a lot never goes below zero, setting or not');
delete from public.setting_values where key = 'stock.allow_negative' and workspace_id = pg_temp.u(101);

-- TAKE OUT: consumption and loss, the feature on, replay, FEFO and expiry.
select is((pg_temp.cmd(1, 'stock_consume_v1', 951, pg_temp.arr(pg_temp.line(303, '2', 'MAIN', 'LOSS')))::jsonb -> 'movements' -> 0 ->> 'quantity'), '2', 'goods consumed leave MAIN for the loss place');
select is((pg_temp.cmd(1, 'stock_consume_v1', 951, pg_temp.arr(pg_temp.line(303, '2', 'MAIN', 'LOSS')))::jsonb -> 'movements' -> 0 ->> 'id') = (select id::text from public.stock_movements where request_id = pg_temp.u(951) limit 1),
  true, 'the same request answers the same movement');
select is(pg_temp.cmd(1, 'stock_consume_v1', 951, pg_temp.arr(pg_temp.line(303, '3', 'MAIN', 'LOSS'))) like 'ERR P0001%', true, 'the same id with another body is refused');
select is(pg_temp.cmd(1, 'stock_consume_v1', 952, pg_temp.arr(pg_temp.line(302, '1', 'MAIN', 'LOSS', format(', "lot_id": "%s"', current_setting('t.old'))))),
  'ERR DKG11 {"field": "lines[0].lot_id", "reason": "lot_expired"}', 'an expired lot needs an explicit acknowledgement');
select is((pg_temp.cmd(1, 'stock_consume_v1', 953, pg_temp.arr(pg_temp.line(302, '1', 'MAIN', 'LOSS', format(', "lot_id": "%s", "expired_ack": true', current_setting('t.old')))))::jsonb -> 'movements' -> 0 ->> 'lot_id'),
  current_setting('t.old'), 'and acknowledged, it is taken');
select is((pg_temp.cmd(1, 'stock_loss_v1', 954, pg_temp.arr(pg_temp.line(302, '1', 'MAIN', 'LOSS', format(', "lot_id": "%s"', current_setting('t.old')))))::jsonb -> 'movements' -> 0 ->> 'lot_id'),
  current_setting('t.old'), 'an expired lot written off as a loss needs no acknowledgement');
select is(pg_temp.cmd(1, 'stock_loss_v1', 955, pg_temp.arr(pg_temp.line(302, '1', 'MAIN', 'LOSS'))) like 'ERR DKG06%', true, 'a tracked item is taken from a lot the operator names');
select is((pg_temp.run_as(pg_temp.u(1), format('select (public.stock_fefo_proposal_v1(%L, %L, null, %L, 6) -> ''lots'' -> 0 ->> ''lot_code'')', pg_temp.u(101), pg_temp.u(302), pg_temp.loc('MAIN')))),
  'OLD', 'the proposal lists the soonest expiry first');
select is((pg_temp.run_as(pg_temp.u(1), format('select (public.stock_fefo_proposal_v1(%L, %L, null, %L, 6) -> ''lots'' -> 0 ->> ''expired'')', pg_temp.u(101), pg_temp.u(302), pg_temp.loc('MAIN')))),
  'true', 'and flags the lot that is past its date');
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": false}' where id = pg_temp.u(101);
select is(left(pg_temp.cmd(1, 'stock_consume_v1', 956, pg_temp.arr(pg_temp.line(303, '1', 'MAIN', 'LOSS'))), 9), 'ERR DKG01', 'with stockTakeOut off no consumption or loss is run');
select is(left(pg_temp.cmd(1, 'stock_transfer_v1', 957, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN'))), 2), '{"', 'transfers need only the ledger');
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": true}' where id = pg_temp.u(101);

-- THE TWO-STEP TRANSFER: loaded, in transit, received in part; the sum is the same at each step.
select set_config('t.sum0', pg_temp.total(301)::text, false);
select set_config('t.load', pg_temp.cmd(1, 'stock_transfer_load_v1', 960, format('%L, %s', pg_temp.loc('BRANCH-S1'), pg_temp.arr(pg_temp.line(301, '3', 'DEPOT', 'DEPOT')))), false);
select is(pg_temp.on_hand(301, 'DEPOT')::text || ' ' || pg_temp.on_hand(301, 'TRANSIT')::text || ' ' || pg_temp.total(301)::text,
  '1.000000 3.000000 ' || current_setting('t.sum0'), 'loaded: 3 kg left the depot for transit and the total is unchanged');
select set_config('t.transfer', (current_setting('t.load')::jsonb ->> 'transfer_id'), false);
select set_config('t.tline', (current_setting('t.load')::jsonb -> 'lines' -> 0 ->> 'id'), false);
select is(pg_temp.cmd(1, 'stock_transfer_receive_v1', 961, format('%L, %L::jsonb', current_setting('t.transfer')::uuid, '[{"line_id": "' || current_setting('t.tline') || '", "quantity": "3.5"}]')),
  'ERR DKG11 {"field": "lines[0].quantity", "reason": "receive_over"}', 'more than was loaded cannot be received');
select is(pg_temp.cmd(1, 'stock_transfer_receive_v1', 962, format('%L, %L::jsonb', current_setting('t.transfer')::uuid, '[{"line_id": "' || current_setting('t.tline') || '", "quantity": "1", "to": "' || pg_temp.loc('MAIN') || '"}]')),
  'ERR DKG11 {"field": "lines[0].to", "reason": "wrong_site"}', 'goods are received onto a place of the destination site only');
select set_config('t.recv', pg_temp.cmd(1, 'stock_transfer_receive_v1', 963, format('%L, %L::jsonb', current_setting('t.transfer')::uuid, '[{"line_id": "' || current_setting('t.tline') || '", "quantity": "1.25"}]')), false);
select is(pg_temp.on_hand(301, 'TRANSIT')::text || ' ' || pg_temp.on_hand(301, 'BRANCH-S1')::text || ' ' || pg_temp.total(301)::text || ' ' || (select status from public.stock_transfers where id = current_setting('t.transfer')::uuid),
  '1.750000 1.250000 ' || current_setting('t.sum0') || ' partly_received', 'received in part: 1.75 kg stay in transit, visible, and the total is unchanged');
select is(pg_temp.cmd(1, 'stock_transfer_receive_v1', 963, format('%L, %L::jsonb', current_setting('t.transfer')::uuid, '[{"line_id": "' || current_setting('t.tline') || '", "quantity": "1.25"}]')), current_setting('t.recv'),
  'a retried receive answers the same');
select is(pg_temp.on_hand(301, 'BRANCH-S1')::text, '1.250000', 'and moves nothing twice');
select pg_temp.cmd(1, 'stock_transfer_receive_v1', 964, format('%L, %L::jsonb', current_setting('t.transfer')::uuid, '[{"line_id": "' || current_setting('t.tline') || '", "quantity": "1.75"}]'));
select is(pg_temp.on_hand(301, 'TRANSIT')::text || ' ' || pg_temp.on_hand(301, 'BRANCH-S1')::text || ' ' || pg_temp.total(301)::text || ' ' || (select status from public.stock_transfers where id = current_setting('t.transfer')::uuid),
  '0.000000 3.000000 ' || current_setting('t.sum0') || ' received', 'received in full: nothing is left in transit and the total is unchanged');
select is(pg_temp.cmd(1, 'stock_transfer_load_v1', 965, format('%L, %s', pg_temp.loc('BRANCH-S1'), pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'SHELF-B') || ', ' || pg_temp.line(303, '1', 'MAIN', 'MAIN')))),
  'ERR DKG11 {"field": "lines", "reason": "one_source"}', 'one transfer has one source place');

-- THE OUTCOME OF A LOST RESPONSE.
select is((pg_temp.run_as(pg_temp.u(1), format('select (public.stock_command_outcome_v1(%L, %L) -> ''result'' ->> ''transfer_id'')', pg_temp.u(101), pg_temp.u(960)))), current_setting('t.transfer'),
  'the outcome of a load is read again by its request id, with no second effect');
select is(pg_temp.run_as(pg_temp.u(1), format('select coalesce(public.stock_command_outcome_v1(%L, %L)::text, ''none'')', pg_temp.u(101), pg_temp.u(999))), 'none', 'an unknown request has no outcome');

-- LIFECYCLE: the count is a read-only mirror; off and on again reconciles nothing.
select is(pg_temp.try(format('update public.services set stock = 99 where id = %L', pg_temp.u(303))), 'DKG13', 'once initialized, a count written from outside the ledger is refused');
select set_config('t.movements', (select count(*) from public.stock_movements where workspace_id = pg_temp.u(101))::text, false);
select set_config('t.balances', (select md5(string_agg(item_id::text || location_id::text || quantity::text, ',' order by item_id, location_id, lot_id, variant_id)) from public.stock_balances where workspace_id = pg_temp.u(101)), false);
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": false}' where id = pg_temp.u(101);
select is(pg_temp.try(format('update public.services set stock = 99 where id = %L', pg_temp.u(303))), 'DKG13', 'with the feature off the count is still refused: the history is kept');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true}' where id = pg_temp.u(101);
select is((select count(*) from public.stock_movements where workspace_id = pg_temp.u(101))::text || ' ' ||
          (select md5(string_agg(item_id::text || location_id::text || quantity::text, ',' order by item_id, location_id, lot_id, variant_id)) from public.stock_balances where workspace_id = pg_temp.u(101)),
  current_setting('t.movements') || ' ' || current_setting('t.balances'), 'switching it off and on again changes no balance and writes no opening movement');


create or replace function pg_temp.save_place_t(p_place uuid, p_rev int, p_req int, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.save_stock_location_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), p_place, p_rev, pg_temp.u(p_req), p_body))
$f$;

-- READ-IN-REVIEW (the independent read of the first candidate): each point has its case.
create or replace function pg_temp.charge(p_item int, p_qty int) returns text language plpgsql as $f$
begin
  perform pg_temp.run_as(pg_temp.u(1), format('select public.record_service_charge(%L, %L, %L, %s)::text', pg_temp.u(101), pg_temp.u(201), pg_temp.u(p_item), p_qty));
  update public.events set status = 'confirmed' where workspace_id = pg_temp.u(101) and type = 'service_charge' and status <> 'confirmed';
  return 'ok';
exception when others then return sqlstate;
end
$f$;
create or replace function pg_temp.lotq(p_code text) returns numeric language sql volatile as $f$
  select coalesce(sum(b.quantity), 0) from public.stock_balances b join public.stock_lots l on l.id = b.lot_id
   where l.lot_code = p_code and b.location_id = pg_temp.loc('MAIN')
$f$;
create or replace function pg_temp.ledger_state() returns text language sql volatile as $f$
  select (select count(*) from public.stock_movements where workspace_id = pg_temp.u(101))::text || ' ' ||
         (select md5(string_agg(item_id::text || location_id::text || quantity::text, ',' order by item_id, location_id, lot_id, variant_id)) from public.stock_balances where workspace_id = pg_temp.u(101))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- 1. The bridge with the feature OFF after initialization: it confirms, and leaves the count and the history alone.
select set_config('t.state', pg_temp.ledger_state(), false);
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": false}' where id = pg_temp.u(101);
select is(pg_temp.charge(303, 1) || ' ' || (pg_temp.ledger_state() = current_setting('t.state'))::text, 'ok true',
  'with the feature off after initialization a charge is still confirmed: no movement, no balance change');
select is(pg_temp.try(format('insert into public.services (workspace_id, name, price_cents, active, stock) values (%L, %L, 100, true, 5)', pg_temp.u(101), 'Late count')), 'DKG13',
  'and a new item cannot bring a count either: no movement would carry it');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true}' where id = pg_temp.u(101);

-- 2. An expired lot, loaded with its acknowledgement, is received without asking again.
select set_config('t.loadb', pg_temp.cmd(1, 'stock_transfer_load_v1', 980, format('%L, %s', pg_temp.loc('BRANCH-S1'),
  pg_temp.arr(pg_temp.line(302, '1', 'MAIN', 'MAIN', format(', "lot_id": "%s", "expired_ack": true', current_setting('t.old')))))), false);
select is(left(pg_temp.cmd(1, 'stock_transfer_receive_v1', 981, format('%L, %L::jsonb', (current_setting('t.loadb')::jsonb ->> 'transfer_id')::uuid,
  '[{"line_id": "' || (current_setting('t.loadb')::jsonb -> 'lines' -> 0 ->> 'id') || '", "quantity": "1"}]')), 2), '{"',
  'an expired lot in transit leaves the road: receiving does not ask for the acknowledgement again');

-- 3. The in-transit place is the system's.
select is(pg_temp.save_place_t(null, null, 982, '{"kind": "in_transit", "code": "X1", "name": "x"}'), 'ERR DKG11 {"field": "kind", "reason": "location_virtual"}', 'no second in-transit place can be created');
select is(pg_temp.save_place_t(current_setting('t.transit')::uuid, 1, 983, '{"name": "renamed"}'), 'ERR DKG11 {"field": "place", "reason": "location_virtual"}', 'and the in-transit place is not edited');
select is(pg_temp.try(format('insert into public.stock_locations (workspace_id, kind, code) values (%L, %L, %L)', pg_temp.u(101), 'in_transit', 'T2')), '23505', 'the database keeps one in-transit place per business');
select ok(regexp_replace(pg_get_functiondef('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure), '\s+', ' ', 'g') like '%l.kind <> ''in_transit''%',
  'a delivery is never put away into the in-transit place');
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values (pg_temp.u(103), 'Paths C', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}');
insert into public.stock_locations (workspace_id, kind, code) values (pg_temp.u(103), 'shelf', 'TRANSIT');
select set_config('t.tp', 'made:' || pg_temp.try(format('select public.stock_transit_place(%L)', pg_temp.u(103))), false);
select is((select code from public.stock_locations where workspace_id = pg_temp.u(103) and kind = 'in_transit'), 'TRANSIT-1',
  'a place the business already called TRANSIT does not stop the system from having its own');

-- 4. Two steps are for goods that change site.
select is(pg_temp.cmd(1, 'stock_transfer_load_v1', 984, format('%L, %s', pg_temp.loc('MAIN'), pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'SHELF-B')))),
  'ERR DKG11 {"field": "to_location_id", "reason": "same_site"}', 'a load onto a place of the source''s own site is refused: inside a site a transfer is one step');

-- 5. The generic door asks what the typed one asks.
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": false}' where id = pg_temp.u(101);
select is(left(pg_temp.move(985, 303, '1', 'MAIN', 'LOSS', 'loss'), 9), 'ERR DKG01', 'a generic loss with stockTakeOut off is refused like the typed one');
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": true}' where id = pg_temp.u(101);
select is(pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, ''transfer'')::text', pg_temp.u(101), pg_temp.u(986),
  '[' || pg_temp.line(303, '1', 'SHELF-B', 'MAIN') || ']'), true), 'ERR DKN01 ', 'a delegated session does not move stock through the generic door either');

-- 6. The outcome reads this family, and the caller's own requests.
select is(pg_temp.run_as(pg_temp.u(1), format('select coalesce(public.stock_command_outcome_v1(%L, %L)::text, ''none'')', pg_temp.u(101), pg_temp.u(900))), 'none',
  'a generic move''s request is not this family''s outcome');
update public.workspaces set role_permissions = '{"member": ["viewStock", "manageStock"]}' where id = pg_temp.u(101);
select is(pg_temp.run_as(pg_temp.u(2), format('select coalesce(public.stock_command_outcome_v1(%L, %L)::text, ''none'')', pg_temp.u(101), pg_temp.u(960))), 'none',
  'and a request somebody else made is not read, though the reader may move stock too');
update public.workspaces set role_permissions = '{"member": ["viewStock", "manageServices"]}' where id = pg_temp.u(101);

-- 7. The bridge never takes a lot past its date, and says which refusal it is.
select is(pg_temp.charge(302, 3) || ' NEW ' || pg_temp.lotq('NEW')::text || ' OLD ' || pg_temp.lotq('OLD')::text, 'ok NEW 2.000000 OLD 2.000000',
  'a confirmed charge of a tracked item takes from the lots fit to sell: the expired one is never touched');
select is(pg_temp.charge(302, 4), 'DKG15', 'when what is left is past its date, the refusal says so (not "not enough")');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable)
values (pg_temp.u(305), pg_temp.u(101), 'Shirt', 2000, true, null, 'piece', 'none', true);
insert into public.item_variants (workspace_id, item_id, canonical) values (pg_temp.u(101), pg_temp.u(305), 'colour:red');
select is(pg_temp.charge(305, 1), 'DKG12', 'a sale that names no variant of an item with variants is refused as that (0837), not as "not enough"');

select ok(regexp_replace(pg_get_functiondef('public.apply_stock_on_confirm()'::regprocedure), '\s+', ' ', 'g') like '%from public.services s where s.id = v_service_id for update%',
  'the legacy bridge locks the item first, as every stock command does: no deadlock with a return');

select ok(regexp_replace(pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure), '\s+', ' ', 'g') like '%stock = case when public.stock_initialized(p_workspace_id) then stock else%',
  'a configuration file''s counts are ignored once the ledger exists: the import does not write them');


-- 8. A shelf cannot be made inside the in-transit place: it would become that place's site.
select is(pg_temp.save_place_t(null, null, 990, format('{"kind": "shelf", "code": "UNDER", "parent_id": "%s"}', current_setting('t.transit'))),
  'ERR DKG11 {"field": "parent_id", "reason": "location_virtual"}', 'no place is made inside the in-transit place');

-- 9. A real put-away aimed at the in-transit place is refused.
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.record_receipt_and_put_away_v1(%L, %L, (select revision from public.purchase_orders where id = %L), current_date,
    '[{"line_no": 1, "quantity": 5}]'::jsonb, 'dock', %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(501), pg_temp.u(501), pg_temp.u(991),
    format('[{"line_no": 1, "quantity": 5, "location_id": "%s"}]', current_setting('t.transit')))),
  'ERR DKG11 {"field": "allocations[0].location_id", "reason": "location_foreign"}', 'a delivery is not put away into the in-transit place');

-- 10. A supply confirmed with the feature OFF after initialization: no movement, and the count column unchanged.
select set_config('t.cnt', (select stock::text from public.services where id = pg_temp.u(303)), false);
select set_config('t.state2', pg_temp.ledger_state(), false);
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": false}' where id = pg_temp.u(101);
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(992), pg_temp.u(101), 'expense', 'submitted', pg_temp.u(201), pg_temp.u(201),
        format('{"supply": {"service_id": "%s", "quantity": 3, "unit_price_cents": 100}}', pg_temp.u(303))::jsonb, 'pending');
select is(pg_temp.try(format($q$update public.events set status = 'confirmed' where id = %L$q$, pg_temp.u(992))) || ' ' || (pg_temp.ledger_state() = current_setting('t.state2'))::text
          || ' ' || ((select stock::text from public.services where id = pg_temp.u(303)) = current_setting('t.cnt'))::text,
  'ok true true', 'a supply confirmed with the feature off after initialization writes no movement and leaves services.stock as it was');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true}' where id = pg_temp.u(101);

-- 11. A viewer who may edit the catalogue but not move stock hears that first (DKN01), not the ledger's refusal.
select is(left(pg_temp.run_as(pg_temp.u(2), format('update public.services set stock = 99 where id = %L returning stock::text', pg_temp.u(303))), 9), 'ERR DKN01',
  'a catalogue editor who may not move stock is told so before the ledger keeps the count');

-- 12. The outcome of a take-out is refused when its feature is off.
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": false}' where id = pg_temp.u(101);
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.stock_command_outcome_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(951))), 9), 'ERR DKG01',
  'the outcome of a consumption is not read with stockTakeOut off');
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": true}' where id = pg_temp.u(101);

-- 13. A real import onto an initialized business: the file's counts are ignored, and an item new from it is stocked.
select set_config('t.cnt2', (select stock::text from public.services where id = pg_temp.u(303)), false);
select pg_temp.run_as(pg_temp.u(1), format($q$select public.import_workspace_configuration(%L, %L::jsonb)::text$q$, pg_temp.u(101),
  '{"tables": {"services": [{"name": "Water", "price_cents": 100, "active": true, "stock": 999}, {"name": "Imported", "price_cents": 100, "active": true, "stock": 7}]}}'));
select is((select stock::text from public.services where id = pg_temp.u(303)) || ' ' ||
          (select (stockable)::text || ' ' || coalesce(stock::text, 'null') from public.services where workspace_id = pg_temp.u(101) and name = 'Imported'),
  current_setting('t.cnt2') || ' true null', 'the import ignores the counts of the file once the ledger exists, and an item new from it is stocked');

-- WHO MAY, AND WHERE.
select is(pg_temp.cmd(2, 'stock_transfer_v1', 970, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN'))), 'ERR DKN01 ', 'a member who only sees the stock moves nothing');
select is(pg_temp.cmd(1, 'stock_transfer_v1', 971, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN')), 101, true), 'ERR DKN01 ', 'a delegated assistant session moves nothing');
select is(pg_temp.cmd(3, 'stock_transfer_v1', 972, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN')), 102) like 'ERR DKG0%', true, 'a place and an item of another business are not moved');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": false}' where id = pg_temp.u(101);
select is(left(pg_temp.cmd(1, 'stock_transfer_v1', 973, pg_temp.arr(pg_temp.line(303, '1', 'SHELF-B', 'MAIN'))), 9), 'ERR DKG01', 'with the ledger off no command runs');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true}' where id = pg_temp.u(101);
select ok(regexp_replace(pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure), '\s+', ' ', 'g') like '%order by id for update%',
  'every item of a request is locked in id order before anything is taken');

select * from finish();
rollback;
