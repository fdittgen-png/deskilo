-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (row 11): a grocery shop's day, from the order to the shelf to the sale, walked through the commands the screens call.
-- Two pallets of yoghurt (48 pieces each) and a carton of juice are ordered at a price per pallet and per carton; one pallet and
-- the carton arrive and are put away with their lot, their best-before date and the order's price; the pallet is repacked into
-- four boxes and one box is opened; eight pieces go to the place the till sells from and the rest stays in the back store,
-- where what is still boxed cannot be taken loose; the till sells at the price, with a discount and at a changed price with its
-- reason, drawing the lot that expires first and never the expired one; the expired and a damaged piece are thrown away; then
-- the shop asks where the delivery is, what expires, what the stock is worth, and whether the facts a ranking of its products
-- needs are recorded. What the product cannot do is a skipped line that names the gap. Rolled back.
begin;
select plan(44);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
-- an answer as JSON, or the refusal under "error": a cast never ends the walk
create or replace function pg_temp.j(p text) returns jsonb language sql immutable as $f$
  select case when p like '{%' or p like '[%' then p::jsonb else jsonb_build_object('error', p) end
$f$;
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.today() returns date language sql stable as $f$
  select public.workspace_today(pg_temp.u(101))
$f$;
create or replace function pg_temp.day(p_offset int) returns text language sql stable as $f$
  select to_char(pg_temp.today() + p_offset, 'YYYY-MM-DD')
$f$;
create or replace function pg_temp.lot(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = p_code
$f$;
-- what a place holds of an item, of one lot when one is named
create or replace function pg_temp.bal(p_item int, p_loc text, p_lot text default null) returns text language sql stable as $f$
  select trim_scale(coalesce(sum(quantity), 0))::text from public.stock_balances
   where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(p_item) and location_id = pg_temp.loc(p_loc)
     and (p_lot is null or lot_id = pg_temp.lot(p_lot))
$f$;
-- a stock command as the owner calls it: the function, its request, its arguments after the request
create or replace function pg_temp.cmd(p_fn text, p_req int, p_args text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.%s(%L, %L, %s)::text', p_fn, pg_temp.u(101), pg_temp.u(p_req), p_args))
$f$;
create or replace function pg_temp.line(p_item int, p_qty text, p_from text, p_to text, p_lot text) returns text language sql stable as $f$
  select format('%L::jsonb', format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s", "lot_id": "%s", "expired_ack": true}]',
    pg_temp.u(p_item), p_qty, pg_temp.loc(p_from), pg_temp.loc(p_to), pg_temp.lot(p_lot)))
$f$;
-- a sale at the till, paid in cash for its total: the receipt's answer, or the refusal
create or replace function pg_temp.sell(p_req int, p_lines text) returns text language plpgsql as $f$
declare v_d text;
begin
  v_d := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req), '{"lines": ' || p_lines || '}'));
  if v_d like 'ERR%' then return v_d; end if;
  return pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req + 1), v_d::jsonb ->> 'receipt_id',
           format('[{"kind": "cash", "amount_minor": %s}]', (v_d::jsonb #>> '{totals,gross_minor}')::bigint)));
end
$f$;
create or replace function pg_temp.gross(p text) returns text language sql immutable as $f$
  select coalesce(pg_temp.j(p) #>> '{totals,gross_minor}', p)
$f$;
-- what "where is it" answered: the quantity at the places of one kind
create or replace function pg_temp.at_kind(p text, p_kind text) returns text language sql immutable as $f$
  select trim_scale(coalesce(sum((x ->> 'quantity')::numeric), 0))::text
    from jsonb_array_elements(coalesce(pg_temp.j(p) -> 'places', '[]'::jsonb)) x where x ->> 'location_kind' = p_kind
$f$;
-- a step of the walk kept under a name; a refused step says so in the run's notes, where a later line would only miss it
create or replace function pg_temp.keep(p_key text, p_value text) returns setof text language plpgsql as $f$
begin
  perform set_config(p_key, coalesce(p_value, ''), false);
  if p_value is null or p_value like 'ERR%' then return next diag('refused -- ' || p_key || ': ' || coalesce(p_value, 'null')); end if;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'grocery-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Grocery day', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockLots": true, "stockReceiving": true, "stockTakeOut": true, "stockHandlingUnits": true, "stockExpiryReport": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values
  ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb),
  ('workspace', pg_temp.u(101), 'counter.max_discount_percent', '50'::jsonb);
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values (pg_temp.u(401), pg_temp.u(101), '1', 'Dairy wholesale', 'active');
-- both are tracked by their date: the put-away sheet asks the lot and the best-before date of such an item
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Yoghurt', 150, true, 'piece', 'expiry', true),
  (pg_temp.u(302), pg_temp.u(101), 'Apple juice', 300, true, 'piece', 'expiry', true);
-- the carton and the pallet are units of the business; how many pieces one holds is the item's own
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1), (pg_temp.u(101), 'pallet', 'Pallet', 'package', 1, 1)
on conflict do nothing;
-- a pallet of yoghurt is four cartons of twelve; a carton of juice is six bottles
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1), (pg_temp.u(101), pg_temp.u(301), 'pallet', 48, 1), (pg_temp.u(101), pg_temp.u(302), 'carton', 6, 1);
-- the main store holds the shop floor, with a shelf below it, and the back store beside the floor; the business names the
-- floor as the place its till sells from
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(900), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR'),
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'BACK');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(902), pg_temp.u(101), pg_temp.u(900), 'shelf', 'SHELF');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.selling_place', '"FLOOR"'::jsonb);
-- last week's two yoghurts, a day past their date, are still on the sales floor
select pg_temp.keep('t.old', pg_temp.cmd('stock_move_v1', 800, format('%L::jsonb, %L',
  format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "expired_ack": true, "new_lot": {"code": "Y-0", "expires_on": "%s", "total_cost_minor": 100}}]',
    pg_temp.u(301), pg_temp.place('supplier'), pg_temp.loc('FLOOR'), pg_temp.day(-1)), 'receipt')));

-- ── 1. order: in the purchase unit, at its price ──────────────────────────────────────────────────────────────────────────────
select pg_temp.keep('t.order', pg_temp.cmd('save_purchase_order_v1', 810, format('0, %L::jsonb', jsonb_build_object(
  'supplier_id', pg_temp.u(401), 'expected_on', pg_temp.day(2), 'lines', jsonb_build_array(
    jsonb_build_object('service_id', pg_temp.u(301), 'quantity', 2, 'unit', 'pallet', 'unit_price_cents', 2400),
    jsonb_build_object('service_id', pg_temp.u(302), 'quantity', 1, 'unit', 'carton', 'unit_price_cents', 600))))));
select set_config('t.oid', coalesce(pg_temp.j(current_setting('t.order')) ->> 'id', pg_temp.u(0)::text), false);
select diag('order answered: ' || left(current_setting('t.order'), 400)) where pg_temp.j(current_setting('t.order')) ->> 'state' is null;
select is((pg_temp.j(current_setting('t.order')) ->> 'state') || ' ' || (pg_temp.j(current_setting('t.order')) #>> '{lines,0,unit}') || ' '
    || (select sum(quantity * unit_price_cents)::bigint from public.purchase_order_lines where order_id = current_setting('t.oid')::uuid)::text,
  'draft pallet 5400', 'two pallets and a carton are ordered in their purchase units: the order expects 54.00');
select alike(pg_temp.cmd('save_purchase_order_v1', 811, format('0, %L::jsonb', jsonb_build_object('supplier_id', pg_temp.u(401), 'lines', jsonb_build_array(
    jsonb_build_object('service_id', pg_temp.u(301), 'quantity', 1, 'unit', 'kg', 'unit_price_cents', 100))))),
  'ERR DKG11%unit_unmapped%', 'a kilo of yoghurt has no conversion to a piece: the order is refused when it is saved');
select is(pg_temp.j(pg_temp.run_as(pg_temp.u(1), format('select public.mark_purchase_order_sent_v1(%L, %L, %s, %L)::text', pg_temp.u(101), current_setting('t.oid'),
    (select revision from public.purchase_orders where id = current_setting('t.oid')::uuid), pg_temp.u(812)))) ->> 'state', 'sent', 'the order is sent');

-- ── 2. receive: one pallet of the two and the carton, each with its lot, its date and the order's price ─────────────────────────
select pg_temp.keep('t.rcv', pg_temp.run_as(pg_temp.u(1), format('select public.record_receipt_and_put_away_v1(%L, %L, %s, %L, %L::jsonb, %L, %L, %L::jsonb)::text',
  pg_temp.u(101), current_setting('t.oid'), (select revision from public.purchase_orders where id = current_setting('t.oid')::uuid), pg_temp.today(),
  '[{"line_no": 1, "quantity": 1}, {"line_no": 2, "quantity": 1}]', 'dock', pg_temp.u(820),
  format('[{"line_no": 1, "quantity": 1, "location_id": "%s", "lot": {"code": "Y-1", "expires_on": "%s"}, "cost": {"state": "order_price"}},
           {"line_no": 2, "quantity": 1, "location_id": "%s", "lot": {"code": "J-1", "expires_on": "%s"}, "cost": {"state": "order_price"}}]',
    pg_temp.loc('BACK'), pg_temp.day(5), pg_temp.loc('FLOOR'), pg_temp.day(200)))));
select is(pg_temp.bal(301, 'BACK') || '/' || pg_temp.bal(302, 'FLOOR'), '48/6', 'a pallet is 48 yoghurts in the back store and a carton six bottles on the sales floor');
select is((select lot_code || ' ' || expires_on::text || ' ' || total_cost_minor::text || ' ' || trim_scale(quantity_received)::text from public.stock_lots where id = pg_temp.lot('Y-1')),
  'Y-1 ' || pg_temp.day(5) || ' 2400 48', 'the lot keeps its code, its best-before date and what the pallet cost at the order''s price');
select is((select o.state from public.purchase_orders o where o.id = current_setting('t.oid')::uuid) || ' '
    || (select trim_scale(received_quantity)::text || '/' || trim_scale(quantity)::text from public.purchase_order_lines where order_id = current_setting('t.oid')::uuid and line_no = 1),
  'partly_received 1/2', 'the order is partly received: one pallet of two');
select alike(pg_temp.run_as(pg_temp.u(1), format('select public.put_away_receipt_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101),
    (select id from public.purchase_order_receipts where order_id = current_setting('t.oid')::uuid), pg_temp.u(821),
    format('[{"line_no": 1, "quantity": 1, "location_id": "%s", "lot": {"code": "Y-2", "expires_on": "%s"}}]', pg_temp.loc('BACK'), pg_temp.day(5)))),
  'ERR DKG11%over_allocated%', 'no more is put away than arrived');

-- ── 3. break down: the pallet into four boxes, one box opened; the lot follows ───────────────────────────────────────────────────
select pg_temp.keep('t.pal', pg_temp.cmd('stock_hu_make_v1', 830, format('%L::jsonb',
  format('{"code": "PAL-1", "kind": "pallet", "label_code": "SSCC-001", "location_id": "%s", "lines": [{"item_id": "%s", "lot_id": "%s", "quantity": "48"}]}',
    pg_temp.loc('BACK'), pg_temp.u(301), pg_temp.lot('Y-1')))));
select set_config('t.boxes', (select jsonb_agg(jsonb_build_object('code', 'BOX-' || n, 'kind', 'box', 'location_id', pg_temp.loc('BACK'),
  'lines', jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(301), 'lot_id', pg_temp.lot('Y-1'), 'quantity', '12'))))::text from generate_series(1, 4) n), false);
select pg_temp.keep('t.repack', pg_temp.cmd('stock_hu_repack_v1', 831, format('%L::jsonb, %L::jsonb',
  format('[{"unit_id": "%s", "item_id": "%s", "lot_id": "%s", "quantity": "48"}]',
    (select id from public.stock_handling_units where workspace_id = pg_temp.u(101) and code = 'PAL-1'), pg_temp.u(301), pg_temp.lot('Y-1')),
  current_setting('t.boxes'))));
select is((select count(*)::text from public.stock_handling_units where workspace_id = pg_temp.u(101) and kind = 'box' and state = 'open') || ' ' || pg_temp.bal(301, 'BACK'),
  '4 48', 'the pallet became four boxes and no balance changed');
select is((select count(*)::int from public.stock_handling_unit_lines hl join public.stock_handling_units hu on hu.id = hl.unit_id
            where hu.workspace_id = pg_temp.u(101) and hu.kind = 'box' and hl.lot_id = pg_temp.lot('Y-1') and hl.quantity = 12), 4,
  'every box holds twelve of the lot, so its best-before date follows the box');
select is((select jsonb_array_length(t -> 'held') || '/' || jsonb_array_length(t -> 'repacks') from (select pg_temp.j(pg_temp.run_as(pg_temp.u(1),
    format('select public.stock_hu_lot_trace_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(301), pg_temp.lot('Y-1')))) as t) x),
  '4/5', 'the lot is found in its four boxes and through the repack: one line out of the pallet, four in');
select pg_temp.keep('t.unpack', pg_temp.cmd('stock_hu_unpack_v1', 832, format('%L, %s',
  (select id from public.stock_handling_units where workspace_id = pg_temp.u(101) and code = 'BOX-1'),
  (select revision from public.stock_handling_units where workspace_id = pg_temp.u(101) and code = 'BOX-1'))));
select is((select count(*)::text from public.stock_handling_units where workspace_id = pg_temp.u(101) and kind = 'box' and state = 'open') || ' ' || pg_temp.bal(301, 'BACK'),
  '3 48', 'one box is opened: twelve yoghurts are loose in the back store, three boxes stay closed');

-- ── 4. only part goes to the place that sells; the rest stays in the back store ──────────────────────────────────────────────────
select pg_temp.keep('t.move', pg_temp.cmd('stock_transfer_v1', 840, pg_temp.line(301, '8', 'BACK', 'FLOOR', 'Y-1')));
select is(pg_temp.bal(301, 'BACK', 'Y-1') || '/' || pg_temp.bal(301, 'FLOOR', 'Y-1'), '40/8', 'eight go to the sales floor, forty stay in the back store');
select alike(pg_temp.cmd('stock_transfer_v1', 841, pg_temp.line(301, '5', 'BACK', 'FLOOR', 'Y-1')), 'ERR DKG03%',
  'four are loose in the back store: a fifth is in a closed box and is not taken loose');

-- ── 8. sell: the till draws the lot that expires first and is not expired; a discount and a changed price are kept as such ───────
select is((select string_agg((l ->> 'code') || ':' || (l ->> 'quantity') || case when (l ->> 'expired')::boolean then ':expired' else '' end, ' ' order by o)
    from jsonb_array_elements(coalesce(pg_temp.j(pg_temp.run_as(pg_temp.u(1), format('select public.counter_item_lots_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(301)))) -> 'lots', '[]'::jsonb))
         with ordinality x (l, o)),
  'Y-0:2:expired Y-1:8', 'the till reads the yoghurt''s lots at the place it sells from, the expired one marked');
select is(pg_temp.gross(pg_temp.sell(850, format('[{"item_id": "%s", "quantity": "3"}]', pg_temp.u(301)))), '450', 'three yoghurts at the price: 4.50');
select is(pg_temp.gross(pg_temp.sell(852, format('[{"item_id": "%s", "quantity": "2", "discount_percent": "30"}]', pg_temp.u(301)))), '210',
  'two marked down by 30 % within the business''s limit: 2.10');
select pg_temp.keep('t.s3', pg_temp.sell(854, format('[{"item_id": "%s", "quantity": "1", "unit_price": "0.75", "price_reason": "short date"}]', pg_temp.u(301))));
select is(pg_temp.gross(current_setting('t.s3')), '75', 'one at a changed price: 0.75');
select is((select (l.frozen #>> '{input,list_price}') || ' / ' || (l.frozen #>> '{input,price_reason}') from public.counter_receipt_lines l
            where l.receipt_id = (pg_temp.j(current_setting('t.s3')) ->> 'receipt_id')::uuid),
  '1.5 / short date', 'the changed price keeps the item''s price and its reason beside it');
select is(pg_temp.gross(pg_temp.sell(856, format('[{"item_id": "%s", "quantity": "2"}]', pg_temp.u(302)))), '600', 'two bottles of juice: 6.00');

-- ── 9. waste: the expired lot is thrown away, and the loss says why ──────────────────────────────────────────────────────────────
select pg_temp.keep('t.loss1', pg_temp.cmd('stock_loss_v2', 860, format('%L::jsonb, %L',
  format('[{"item_id": "%s", "quantity": "2", "from": "%s", "lot_id": "%s", "expired_ack": true}]', pg_temp.u(301), pg_temp.loc('FLOOR'), pg_temp.lot('Y-0')), 'expired')));
select is(pg_temp.bal(301, 'FLOOR', 'Y-0') || ' ' || (select count(*)::text from public.stock_movements where workspace_id = pg_temp.u(101) and lot_id = pg_temp.lot('Y-0') and reason = 'loss'),
  '0 1', 'the two expired yoghurts leave as a loss');

-- ── 8 again: the till sells from the floor and the shelf below it, never from the back store beside it ───────────────────────────
select pg_temp.keep('t.shelf', pg_temp.cmd('stock_transfer_v1', 870, pg_temp.line(301, '2', 'FLOOR', 'SHELF', 'Y-1')));
select is(pg_temp.bal(301, 'FLOOR') || '/' || pg_temp.bal(301, 'SHELF') || '/' || pg_temp.bal(301, 'BACK'), '0/2/40', 'the last two go to a shelf place of their own');
select pg_temp.keep('t.s5', pg_temp.sell(872, format('[{"item_id": "%s", "quantity": "1"}]', pg_temp.u(301))));
select is(pg_temp.gross(current_setting('t.s5')) || ' ' || pg_temp.bal(301, 'SHELF'), '150 1',
  'with nothing left on the floor itself the till sells the yoghurt from the shelf below it');
select alike(pg_temp.sell(874, format('[{"item_id": "%s", "quantity": "2"}]', pg_temp.u(301))), 'ERR DKG03%',
  'two more are refused: one is left where the till sells, and the forty in the back store beside the floor are not sold from');
select pg_temp.keep('t.refill', pg_temp.cmd('stock_transfer_v1', 876, pg_temp.line(301, '4', 'BACK', 'FLOOR', 'Y-1')));
select is(pg_temp.bal(301, 'BACK') || '/' || pg_temp.bal(301, 'FLOOR'), '36/4', 'the sales floor is refilled from the back store: the four loose ones, the boxes stay');
select is((select string_agg(distinct l.lot_code, ',' order by l.lot_code) from public.stock_movements m join public.stock_lots l on l.id = m.lot_id
            where m.workspace_id = pg_temp.u(101) and m.reason = 'sale'),
  'J-1,Y-1', 'no sale ever drew the expired lot');

-- ── 9 again: a damaged piece; each loss with its cause, at the lot''s cost ───────────────────────────────────────────────────────
select pg_temp.keep('t.loss2', pg_temp.cmd('stock_loss_v2', 880, format('%L::jsonb, %L, %L',
  format('[{"item_id": "%s", "quantity": "1", "from": "%s", "lot_id": "%s"}]', pg_temp.u(301), pg_temp.loc('FLOOR'), pg_temp.lot('Y-1')), 'damaged', 'dropped while filling the shelf')));
select is((select string_agg(distinct m.reason, ',') || ' ' || count(*)::text || ' ' || string_agg(m.loss_cause || coalesce(' (' || m.loss_note || ')', ''), ', ' order by m.loss_cause)
             from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.to_location_id = pg_temp.place('loss')),
  'loss 2 damaged (dropped while filling the shelf), expired', 'both left as a loss and each says why: the damaged piece with its note, the expired lot');
select is((select round(sum(m.quantity * m.unit_cost))::text from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.reason = 'loss'),
  '150', 'each loss is frozen at its lot''s cost: three yoghurts at 0.50');

-- ── 5. where is it: the delivery''s lot, at any time ─────────────────────────────────────────────────────────────────────────────
select pg_temp.keep('t.where', pg_temp.run_as(pg_temp.u(1), format('select public.stock_where_is_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(301), pg_temp.lot('Y-1'))));
select is((select string_agg((x ->> 'location_code') || '=' || trim_scale((x ->> 'quantity')::numeric)::text, ' ' order by x ->> 'location_code')
    from jsonb_array_elements(coalesce(pg_temp.j(current_setting('t.where')) -> 'places', '[]'::jsonb)) x where not (x ->> 'virtual')::boolean),
  'BACK=36 FLOOR=3 SHELF=1', 'the lot is in the back store, on the sales floor and on the shelf');
select is(trim_scale((pg_temp.j(current_setting('t.where')) ->> 'on_hand')::numeric)::text || ' ' || pg_temp.at_kind(current_setting('t.where'), 'customer') || ' '
    || pg_temp.at_kind(current_setting('t.where'), 'loss'),
  '40 7 1', 'of the 48 received, 40 are on hand, 7 were sold and 1 was thrown away');
select is((select count(*)::int from public.stock_receipt_allocations a join public.purchase_order_lines pl on pl.id = a.order_line_id
            where pl.order_id = current_setting('t.oid')::uuid and a.lot_id in (pg_temp.lot('Y-1'), pg_temp.lot('J-1'))), 2,
  'the delivery names the lot and the place of each line it put away, so an order leads to its goods');

-- ── 6. shelf life: what expires when, per place ──────────────────────────────────────────────────────────────────────────────────
select is((select string_agg((r ->> 'location_code') || '=' || trim_scale((r ->> 'quantity')::numeric)::text || '@' || (r ->> 'days'), ' ' order by r ->> 'location_code')
    from jsonb_array_elements(coalesce(pg_temp.j(pg_temp.run_as(pg_temp.u(1), format('select public.stock_expiry_report_v1(%L)::text', pg_temp.u(101)))) -> 'rows', '[]'::jsonb)) r),
  'BACK=36@5 FLOOR=3@5 SHELF=1@5', 'the report lists the lot at each place with five days to go; the juice is beyond the 30 days and the expired lot is gone');
select is((select count(*)::int from jsonb_array_elements(coalesce(pg_temp.j(pg_temp.run_as(pg_temp.u(1),
    format('select public.stock_expiry_report_v1(%L, null, %L, 365)::text', pg_temp.u(101), 'expiring'))) -> 'rows', '[]'::jsonb)) r where r ->> 'lot_code' = 'J-1'), 1,
  'a horizon of a year reaches the juice');

-- ── 7. capital bound: on hand at each lot''s own cost ────────────────────────────────────────────────────────────────────────────
select pg_temp.keep('t.value', pg_temp.run_as(pg_temp.u(1), format('select public.stock_valuation_v1(%L)::text', pg_temp.u(101))));
select is((pg_temp.j(current_setting('t.value')) ->> 'known_total_minor') || ' ' || (pg_temp.j(current_setting('t.value')) ->> 'complete'),
  '2400 true', 'forty yoghurts at 0.50 and four bottles at 1.00 bind 24.00, and every cost is known');
select is((select count(*)::text || ' ' || coalesce(bool_or(x ? 'location_id' or x ? 'location_code' or x ? 'group_id'), false)::text
    from jsonb_array_elements(coalesce(pg_temp.j(current_setting('t.value')) -> 'lines', '[]'::jsonb)) x),
  '2 false', 'the value is listed by lot: a line names no place and no group');

-- ── 10. the facts a ranking of the products needs are recorded (read from the tables: no report reads them) ──────────────────────
select is((select string_agg(x.name || ':' || x.units || ':' || x.gross, ' ' order by x.name) from (
    select s.name, trim_scale(sum(l.quantity))::text as units, sum(l.gross_minor)::text as gross
      from public.counter_receipt_lines l join public.counter_receipts r on r.id = l.receipt_id and r.state = 'finalized' and r.kind = 'sale'
      join public.services s on s.id = l.item_id where l.workspace_id = pg_temp.u(101) group by s.name) x),
  'Apple juice:2:600 Yoghurt:7:885', 'sold most: the units and the revenue of each product are on the receipt lines');
select is((select string_agg(x.name || ':' || x.cost, ' ' order by x.name) from (
    select s.name, round(sum(m.quantity * t.total_cost_minor / t.quantity_received))::text as cost
      from public.stock_movements m join public.stock_lots t on t.id = m.lot_id join public.services s on s.id = m.item_id
     where m.workspace_id = pg_temp.u(101) and m.reason = 'sale' and m.counter_line_id is not null group by s.name) x),
  'Apple juice:200 Yoghurt:350', 'best margin: each sale''s movement names the receipt line and the lot it drew, so what was sold has its cost');
select is((select string_agg(x.name || ':' || x.units || ':' || x.cost, ' ' order by x.name) from (
    select s.name, trim_scale(sum(m.quantity))::text as units, round(sum(m.quantity * m.unit_cost))::text as cost
      from public.stock_movements m join public.services s on s.id = m.item_id
     where m.workspace_id = pg_temp.u(101) and m.reason = 'loss' group by s.name) x),
  'Yoghurt:3:150', 'least thrown away: the losses of each product are movements with a quantity and a cost');
select is((select string_agg(x.name || ':' || x.units || ':' || x.given, ' ' order by x.name) from (
    select s.name, trim_scale(sum(l.quantity))::text as units, sum(round((l.frozen #>> '{input,list_price}')::numeric * l.quantity * 100) - l.gross_minor)::text as given
      from public.counter_receipt_lines l join public.counter_receipts r on r.id = l.receipt_id and r.state = 'finalized' and r.kind = 'sale'
      join public.services s on s.id = l.item_id
     where l.workspace_id = pg_temp.u(101) and round((l.frozen #>> '{input,list_price}')::numeric * l.quantity * 100) > l.gross_minor group by s.name) x),
  'Yoghurt:3:165', 'least marked down: a line sold below the item''s price is told apart, with what was given away');
select is((select string_agg(x.lot_code || ':' || x.sold || '/' || x.received, ' ' order by x.lot_code) from (
    select t.lot_code, trim_scale(t.quantity_received)::text as received,
           trim_scale(coalesce((select sum(m.quantity) from public.stock_movements m where m.lot_id = t.id and m.reason = 'sale'), 0))::text as sold
      from public.stock_lots t where t.workspace_id = pg_temp.u(101) and t.lot_code in ('Y-1', 'J-1')) x),
  'J-1:2/6 Y-1:7/48', 'sold first: each lot has its arrival, its quantity received and the dated sales that drew it');
select is((select count(*)::int from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.reason in ('sale', 'loss') and (m.lot_id is null or m.unit_cost is null)), 0,
  'no sale and no loss of a lot-tracked product is without its lot or its cost');

-- ── what the product does not do today ───────────────────────────────────────────────────────────────────────────────────────────
select skip('GAP step 10: no function and no screen ranks the products (sold first, most, margin, waste, markdowns); kpi_item_margins reads invoiced consumptions, never a till sale or a stock movement', 1);
select is(pg_temp.cmd('stock_loss_v2', 890, format('%L::jsonb, null',
    format('[{"item_id": "%s", "quantity": "1", "from": "%s", "lot_id": "%s"}]', pg_temp.u(301), pg_temp.loc('FLOOR'), pg_temp.lot('Y-1')))) || ' ' || pg_temp.bal(301, 'FLOOR'),
  'ERR DKG11 {"field": "cause", "reason": "required"} 3', 'step 9: a loss says why: one without a cause is refused and the three yoghurts stay on the floor');
select is((select string_agg(l.code || ':' || trim_scale(m.quantity)::text, ' ') from public.stock_movements m join public.stock_locations l on l.id = m.from_location_id
            where m.workspace_id = pg_temp.u(101) and m.reason = 'sale' and m.counter_receipt_id = (pg_temp.j(current_setting('t.s5')) ->> 'receipt_id')::uuid),
  'SHELF:1', 'step 8: the till sells from the place the business names and from every place below it: that sale left the shelf');
select skip('GAP step 7: stock_valuation_v1 totals by lot only: not by place, by item group or by age', 1);

select * from finish();
rollback;
