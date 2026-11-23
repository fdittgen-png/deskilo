-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #4173 (0865, G6 A): goods are traced to documents and payments, and valued honestly. A movement
-- reaches its receipt, order, the several bills linked to that order, each bill's obligation and the
-- allocations, payments and reversals that settle it; a document reaches the exact goods put away
-- against it, a keyset page at a time; each layer is read under its own domain's right and an
-- unreadable one is `unavailable` (never "unpaid", never leaking whether it exists); the operational
-- value totals only known costs and lists the quantities whose cost is unknown. Nothing is written
-- by a read. Rolled back.
begin;
select plan(63);

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
create or replace function pg_temp.orev(p_order int) returns int language sql stable as $f$
  select revision from public.purchase_orders where id = pg_temp.u(p_order)
$f$;
create or replace function pg_temp.combined(p_req int, p_order int, p_lines text, p_allocs text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.record_receipt_and_put_away_v1(%L, %L, %s, current_date, %L::jsonb, ''dock'', %L, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_order), pg_temp.orev(p_order), p_lines, pg_temp.u(p_req), p_allocs))
$f$;
create or replace function pg_temp.alloc(p_line int, p_qty numeric, p_loc text, p_extra text default '') returns text language sql as $f$
  select format('{"line_no": %s, "quantity": %s, "location_id": "%s"%s}', p_line, p_qty, p_loc, p_extra)
$f$;
-- a take-out (a movement with no purchase behind it), optionally dated: request, item, quantity, from, when
create or replace function pg_temp.mv(p_req int, p_item int, p_qty text, p_from text, p_at text default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_consume_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"}]', pg_temp.u(p_item), p_qty, pg_temp.loc(p_from), pg_temp.loc('LOSS')), p_at))
$f$;
create or replace function pg_temp.trace(p_user int, p_movement uuid, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_goods_trace_v1(%L, %L)::text', pg_temp.u(p_ws), p_movement), p_delegated)
$f$;
create or replace function pg_temp.docgoods(p_user int, p_kind text, p_id uuid, p_limit int default 50, p_after jsonb default null, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_document_goods_v1(%L, %L, %L, %s, %L)::text', pg_temp.u(p_ws), p_kind, p_id, p_limit, p_after))
$f$;
create or replace function pg_temp.valuation(p_user int, p_at text default null, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_valuation_v1(%L, %L)::text', pg_temp.u(101), p_at), p_delegated)
$f$;
create or replace function pg_temp.mvof(p_line int, p_order int default 501) returns uuid language sql stable as $f$
  select a.movement_id from public.stock_receipt_allocations a
    join public.purchase_order_lines l on l.id = a.order_line_id
   where l.order_id = pg_temp.u(p_order) and l.line_no = p_line order by a.created_datetime limit 1
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'trace-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
-- owner (everything) · admin: the stock only · member: the stock and the finances · co-owner: the stock and the purchases
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Trace A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true, "stockTakeOut": true}',
   '{"admin": ["viewStock"], "member": ["viewStock", "viewFinances"], "co_owner": ["viewStock", "managePurchases"]}'),
  (pg_temp.u(102), 'Trace B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(5),
   '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, co_owner, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'none', 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'none', 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'none', 'active'),
  (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, false, 'active', 'active'),
  (pg_temp.u(205), pg_temp.u(102), pg_temp.u(5), true, true, 'none', 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name) values
  (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Water Co'), (pg_temp.u(402), pg_temp.u(102), 'S-1', 'Other Co');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Water', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(101), 'Biscuits', 200, true, null, 'piece', 'none', true),
  (pg_temp.u(306), pg_temp.u(102), 'Foreign item', 100, true, null, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(301), 'carton', 12, 1);
insert into public.stock_locations (workspace_id, kind, code, name) values (pg_temp.u(101), 'shelf', 'SHELF-A', 'Shelf A');
insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, created_by_member_id) values
  (pg_temp.u(501), pg_temp.u(101), 2026, 1, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(502), pg_temp.u(101), 2026, 2, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201)),
  (pg_temp.u(503), pg_temp.u(102), 2026, 1, pg_temp.u(402), 'draft', 'EUR', pg_temp.u(205));
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents) values
  (pg_temp.u(101), pg_temp.u(501), 1, pg_temp.u(301), '', 2, 'carton', 1200),
  (pg_temp.u(101), pg_temp.u(501), 2, pg_temp.u(304), '', 24, 'piece', 50),
  (pg_temp.u(101), pg_temp.u(502), 1, pg_temp.u(301), '', 3, 'piece', 100),
  (pg_temp.u(102), pg_temp.u(503), 1, pg_temp.u(306), '', 1, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where workspace_id in (pg_temp.u(101), pg_temp.u(102));
select set_config('t.main', pg_temp.loc('MAIN')::text, false);
select set_config('t.shelf', pg_temp.loc('SHELF-A')::text, false);

-- Goods: two cartons of water at a known cost (2400), 24 biscuits with no cost, and three more water
-- at a KNOWN ZERO. A transfer is a movement with no purchase behind it.
select is((pg_temp.combined(701, 501, '[{"line_no": 1, "quantity": 2}, {"line_no": 2, "quantity": 24}]',
  '[' || pg_temp.alloc(1, 2, current_setting('t.main'), ', "cost": {"state": "known", "total_cost_minor": 2400}') || ',' || pg_temp.alloc(2, 24, current_setting('t.main')) || ']')::jsonb #>> '{order,state}'),
  'received', 'the delivery is received and put away');
select is((pg_temp.combined(702, 502, '[{"line_no": 1, "quantity": 3}]',
  '[' || pg_temp.alloc(1, 3, current_setting('t.shelf'), ', "cost": {"state": "known", "total_cost_minor": 0}') || ']')::jsonb #>> '{order,state}'),
  'received', 'a second delivery at a known zero cost');
select set_config('t.take1', left(pg_temp.mv(703, 301, '4', 'MAIN'), 3), false);
select is(current_setting('t.take1') || ' ' || (select count(*) from public.stock_movements where reason <> 'receipt')::text, '{"m 1',
  'four are taken out of the main place: a movement with no purchase behind it');

-- Bills linked to the order (two: a list, not a one-to-one), one obligation each, one payment split over both,
-- with one allocation reversed. A third bill names no order.
insert into public.purchase_documents (id, workspace_id, kind, state, supplier_id, original_reference, currency, submitter_member_id, payer_kind, purchase_order_id) values
  (pg_temp.u(801), pg_temp.u(101), 'bill', 'draft', pg_temp.u(401), 'INV-1', 'EUR', pg_temp.u(201), 'unpaid', pg_temp.u(501)),
  (pg_temp.u(802), pg_temp.u(101), 'bill', 'draft', pg_temp.u(401), 'INV-2', 'EUR', pg_temp.u(201), 'unpaid', pg_temp.u(501)),
  (pg_temp.u(803), pg_temp.u(101), 'bill', 'draft', pg_temp.u(401), 'INV-3', 'EUR', pg_temp.u(201), 'unpaid', null);
insert into public.purchase_obligations (id, workspace_id, purchase_id, creditor_kind, creditor_supplier_id, amount_cents, currency) values
  (pg_temp.u(811), pg_temp.u(101), pg_temp.u(801), 'supplier', pg_temp.u(401), 1000, 'EUR'),
  (pg_temp.u(812), pg_temp.u(101), pg_temp.u(802), 'supplier', pg_temp.u(401), 400, 'EUR');
insert into public.outgoing_payments (id, workspace_id, payee_kind, payee_supplier_id, currency, amount_cents, method, reported_paid_on, state, actor_member_id, request_id) values
  (pg_temp.u(901), pg_temp.u(101), 'supplier', pg_temp.u(401), 'EUR', 1000, 'bank_transfer', '2026-02-01', 'reported', pg_temp.u(201), pg_temp.u(951)),
  (pg_temp.u(902), pg_temp.u(101), 'supplier', pg_temp.u(401), 'EUR', 50, 'cash', '2026-02-02', 'reported', pg_temp.u(201), pg_temp.u(952));
insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, period) values
  (pg_temp.u(961), pg_temp.u(101), pg_temp.u(201), 'credit', 'adjustment', 600, '2026-02'),
  (pg_temp.u(962), pg_temp.u(101), pg_temp.u(201), 'credit', 'adjustment', 400, '2026-02'),
  (pg_temp.u(963), pg_temp.u(101), pg_temp.u(201), 'credit', 'adjustment', 600, '2026-02');
insert into public.purchase_settlement_allocations (id, workspace_id, obligation_id, payment_id, kind, amount_cents, ledger_entry_id, request_id, actor_member_id) values
  (pg_temp.u(821), pg_temp.u(101), pg_temp.u(811), pg_temp.u(901), 'payment', 600, pg_temp.u(961), pg_temp.u(971), pg_temp.u(201)),
  (pg_temp.u(822), pg_temp.u(101), pg_temp.u(812), pg_temp.u(901), 'payment', 400, pg_temp.u(962), pg_temp.u(972), pg_temp.u(201));
insert into public.purchase_settlement_allocations (id, workspace_id, obligation_id, payment_id, kind, amount_cents, original_allocation_id, ledger_entry_id, request_id, actor_member_id) values
  (pg_temp.u(823), pg_temp.u(101), pg_temp.u(811), pg_temp.u(901), 'reversal', -600, pg_temp.u(821), pg_temp.u(963), pg_temp.u(973), pg_temp.u(201));

select set_config('t.water', pg_temp.mvof(1)::text, false);
select set_config('t.biscuits', pg_temp.mvof(2)::text, false);
select set_config('t.zero', pg_temp.mvof(1, 502)::text, false);
select set_config('t.transfer', (select id::text from public.stock_movements where reason <> 'receipt' order by created_datetime limit 1), false);
create temp table pg_temp.before_counts as
  select (select count(*) from public.stock_movements) m, (select count(*) from public.stock_receipt_allocations) a,
         (select count(*) from public.purchase_settlement_allocations) s;
grant select on pg_temp.before_counts to authenticated;

-- ── from a movement ───────────────────────────────────────────────────
select is((pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,state}'), 'linked',
  'the owner traces a received movement to its purchase');
select is((pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,order,reference}')
          || ' ' || (pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,order,supplier_name}'),
  '2026-0001 Water Co', 'the order and its supplier, as recorded when the goods were put away');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,movement,quantity}', '24.000000',
  'the quantity travels as text, in the inventory unit (two cartons of twelve)');
select is(jsonb_array_length(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #> '{traces,0,purchase,bills,items}'), 2,
  'an order linked to two bills lists both: a list, not an invented one-to-one');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,items,0,original_reference}', 'INV-1', 'the bills keep their own references');
select is(jsonb_array_length(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #> '{traces,0,purchase,bills,items,0,obligations,0,settlement,items}'), 2,
  'a bill''s obligation lists its payment AND its reversal, both independently navigable');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,items,1,obligations,0,settlement,items,0,payment_id}',
  pg_temp.u(901)::text, 'one payment funds both bills: its id is on each obligation''s allocation');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,lot,cost,state}' || ' ' || (pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,lot,cost,total_cost_minor}'),
  'known 2400', 'a known cost shows its amount');
select is(pg_temp.trace(1, current_setting('t.biscuits')::uuid)::jsonb #>> '{traces,0,lot,cost,state}', 'unknown',
  'a lot with no cost says unknown (never zero)');
select is(pg_temp.trace(1, current_setting('t.zero')::uuid)::jsonb #>> '{traces,0,lot,cost,state}' || ' ' || (pg_temp.trace(1, current_setting('t.zero')::uuid)::jsonb #>> '{traces,0,lot,cost,total_cost_minor}'),
  'known 0', 'a known zero is distinct from unknown');
select is(pg_temp.trace(1, current_setting('t.zero')::uuid)::jsonb #>> '{traces,0,purchase,bills,state}', 'not_linked',
  'an order with no bill says not linked: not refused, not unavailable');
select is(pg_temp.trace(1, current_setting('t.transfer')::uuid)::jsonb #>> '{traces,0,purchase,state}', 'not_linked',
  'a transfer has no purchase behind it: not linked');
select is(jsonb_array_length(pg_temp.run_as(pg_temp.u(1), format('select public.stock_goods_trace_v1(%L, null, %L)::text', pg_temp.u(101),
            (select lot_id from public.stock_movements where id = current_setting('t.water')::uuid)))::jsonb -> 'traces'), 1,
  'from a lot: the movement that put it away');

-- Each layer under its own right.
select is(pg_temp.trace(2, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,state}', 'unavailable',
  'a reader of the stock only gets the physical trace: the purchase is unavailable');
select is(pg_temp.trace(2, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,lot,cost,state}', 'unavailable',
  'and what the goods cost is unavailable, not zero');
select is(position('Water Co' in pg_temp.trace(2, current_setting('t.water')::uuid)) + position('2026-0001' in pg_temp.trace(2, current_setting('t.water')::uuid))
          + position('INV-1' in pg_temp.trace(2, current_setting('t.water')::uuid)), 0,
  'nothing of the supplier, the order or the bills leaks to a reader of the stock only');
select is(pg_temp.trace(2, current_setting('t.transfer')::uuid)::jsonb #>> '{traces,0,purchase}', pg_temp.trace(2, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase}',
  'the unavailable answer is the same whether or not a purchase exists');
select is(pg_temp.trace(4, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,state}' || ' ' || (pg_temp.trace(4, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,state}'),
  'linked listed', 'who manages the purchases (stock and purchases) sees the order and the bills');
select is(pg_temp.trace(4, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,items,0,obligations,0,settlement,state}', 'unavailable',
  'without the right to payments the settlement is unavailable: not unpaid');
select is(pg_temp.trace(4, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,lot,cost,state}', 'known', 'managing the purchases shows the cost');
select is(pg_temp.trace(3, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,items,0,obligations,0,settlement,state}', 'listed',
  'a reader of the finances sees the payments');
select is(left(pg_temp.trace(5, current_setting('t.water')::uuid), 9), 'ERR DKN01', 'another business''s owner reads nothing of this one (DKN01)');
select is(left(pg_temp.trace(1, current_setting('t.water')::uuid, 101, true), 9), 'ERR DKN01', 'a delegated assistant session reads nothing (DKN01)');
select is(left(pg_temp.trace(1, pg_temp.u(999)), 9), 'ERR DKG07', 'an unknown movement is refused (DKG07)');
select is(left(pg_temp.trace(1, (select id from public.stock_movements limit 1), 102), 9), 'ERR DKN01', 'a movement of this business asked under another (DKN01)');
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.stock_goods_trace_v1(%L)::text', pg_temp.u(101))), 9), 'ERR DKG09', 'neither a movement nor a lot is refused (DKG09)');

-- Disable and re-enable: the evidence is preserved, only the view of it changes.
update public.workspaces set feature_flags = feature_flags || '{"purchases": false}' where id = pg_temp.u(101);
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,state}', 'unavailable', 'with purchases off the purchase side is unavailable (the orders hang under it)');
update public.workspaces set feature_flags = feature_flags || '{"purchases": true}' where id = pg_temp.u(101);
select is(jsonb_array_length(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #> '{traces,0,purchase,bills,items}'), 2, 'and back on, the same evidence is there');
-- A bill or a payment reaches the goods only through the order and the receipt: with the orders off, nothing of them (ids included) comes back.
update public.workspaces set feature_flags = feature_flags || '{"purchaseOrders": false}' where id = pg_temp.u(101);
select is(pg_temp.docgoods(1, 'bill', pg_temp.u(801))::jsonb ->> 'state' || ' ' || (pg_temp.docgoods(1, 'payment', pg_temp.u(901))::jsonb ->> 'state'), 'unavailable unavailable',
  'with the orders off, a bill and a payment do not reach the goods through them');
update public.workspaces set feature_flags = feature_flags || '{"purchaseOrders": true}' where id = pg_temp.u(101);
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": false}' where id = pg_temp.u(101);
select is(left(pg_temp.trace(1, current_setting('t.water')::uuid), 9), 'ERR DKG01', 'with the goods ledger off nothing is traced (DKG01)');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true}' where id = pg_temp.u(101);

-- ── from a document ──────────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.docgoods(1, 'order', pg_temp.u(501))::jsonb -> 'goods'), 2, 'an order reaches the goods put away against it');
select is(jsonb_array_length(pg_temp.docgoods(1, 'bill', pg_temp.u(801))::jsonb -> 'goods'), 2, 'a bill linked to that order reaches the same goods');
select is(jsonb_array_length(pg_temp.docgoods(1, 'payment', pg_temp.u(901))::jsonb -> 'goods'), 2, 'a payment reaches the goods through its allocations, the obligations and the bills');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb ->> 'truncated', 'false', 'a trace says when it is cut short: here it is not');
select is(pg_temp.valuation(1)::jsonb ->> 'lines_truncated' || ' ' || (pg_temp.valuation(1)::jsonb ->> 'uncosted_truncated'), 'false false', 'the value says when a list is cut short: here neither is');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,items,0,obligations_truncated}', 'false', 'a bill says when its obligations are cut short');
select is(pg_temp.trace(1, current_setting('t.water')::uuid)::jsonb #>> '{traces,0,purchase,bills,items,0,obligations,0,settlement,truncated}', 'false', 'an obligation says when its settlement is cut short');
-- A payments clerk (and a bill-only reader) learn nothing of the orders and receipts the goods hang under.
update public.workspaces set role_permissions = role_permissions || '{"admin": ["viewStock", "recordOutgoingPayments"]}' where id = pg_temp.u(101);
select is(pg_temp.docgoods(2, 'payment', pg_temp.u(901))::jsonb ->> 'state', 'unavailable', 'a caller holding only the payment right reaches no goods (nor an order or receipt id)');
update public.workspaces set role_permissions = role_permissions || '{"admin": ["viewStock"]}' where id = pg_temp.u(101);
select is(pg_temp.docgoods(1, 'bill', pg_temp.u(803))::jsonb ->> 'state', 'not_linked', 'a bill that names no order is not linked: not "no goods"');
select is(pg_temp.docgoods(1, 'payment', pg_temp.u(902))::jsonb ->> 'state', 'not_linked', 'a payment with no allocation is not linked');
select is(pg_temp.docgoods(2, 'order', pg_temp.u(501)), pg_temp.docgoods(2, 'order', pg_temp.u(999)),
  'for a reader without the order right, a real order and an invented id answer the same: unavailable');
select is(pg_temp.docgoods(2, 'payment', pg_temp.u(901))::jsonb ->> 'state', 'unavailable', 'payments are unavailable to a reader of the stock only');
select is(pg_temp.docgoods(4, 'payment', pg_temp.u(901))::jsonb ->> 'state', 'unavailable', 'and to who manages purchases without the right to payments');
select is(left(pg_temp.docgoods(1, 'order', pg_temp.u(999)), 9), 'ERR DKG07', 'a caller with the right who names no such document is refused (DKG07)');
select is(left(pg_temp.docgoods(1, 'order', (select id from public.purchase_orders where workspace_id = pg_temp.u(102))), 9), 'ERR DKG07',
  'another business''s order is unknown here (DKG07)');
select is(pg_temp.docgoods(1, 'order', pg_temp.u(501), 1)::jsonb ->> 'more', 'true', 'a page of one says more follows');
select is(jsonb_array_length(pg_temp.docgoods(1, 'order', pg_temp.u(501), 1, (pg_temp.docgoods(1, 'order', pg_temp.u(501), 1)::jsonb -> 'next'))::jsonb -> 'goods') || '/'
          || (pg_temp.docgoods(1, 'order', pg_temp.u(501), 1, (pg_temp.docgoods(1, 'order', pg_temp.u(501), 1)::jsonb -> 'next'))::jsonb ->> 'more'), '1/false',
  'the cursor continues with the other movement and ends');
select is(left(pg_temp.docgoods(1, 'order', pg_temp.u(501), 0), 9), 'ERR DKG09', 'a page of zero is refused (DKG09)');
select is(left(pg_temp.docgoods(1, 'invoice', pg_temp.u(501)), 9), 'ERR DKG09', 'an unknown kind is refused (DKG09)');

-- ── the operational value ───────────────────────────────────────────
select is(pg_temp.valuation(1)::jsonb ->> 'known_total_minor', '2000', 'the value totals the known costs only: 20 of the 24 pieces at 100 each (four were taken out; a known zero adds nothing)');
select is(pg_temp.valuation(1)::jsonb ->> 'complete', 'false', 'it is not complete while goods of unknown cost are on hand');
select is(pg_temp.valuation(1)::jsonb #>> '{uncosted,0,quantity}' || ' ' || (pg_temp.valuation(1)::jsonb #>> '{uncosted,0,reason}'), '24.000000 cost_unknown',
  'the 24 biscuits of unknown cost are listed by quantity');
select is((select count(*)::int from jsonb_array_elements(pg_temp.valuation(1)::jsonb -> 'lines') l where l ->> 'value_minor' = '0'), 1,
  'the known zero is a priced line of value 0, not an uncosted one');
select is(pg_temp.valuation(1)::jsonb ->> 'currency', 'EUR', 'the currency is the business''s, shown');
select is(pg_temp.valuation(1, (now() - interval '1 day')::text)::jsonb ->> 'complete', 'true',
  'before any movement there is nothing uncosted: complete, and a total of zero');
select is(left(pg_temp.valuation(2), 9) || ' ' || left(pg_temp.valuation(1, null, true), 9), 'ERR DKN01 ERR DKN01',
  'a reader of the stock only, and a delegated session, are refused the value (DKN01)');
select is((select b.m || ' ' || b.a || ' ' || b.s from pg_temp.before_counts b),
  (select count(*)::text from public.stock_movements) || ' ' || (select count(*)::text from public.stock_receipt_allocations) || ' ' || (select count(*)::text from public.purchase_settlement_allocations),
  'opening every trace and value above wrote nothing');

-- A permitted backdated movement changes a LATER calculation, with its own context.
create temp table pg_temp.val_before as select pg_temp.valuation(1)::jsonb v;
select set_config('t.take2', left(pg_temp.mv(704, 301, '1', 'MAIN', (now() - interval '3 hours')::text), 3), false);
select is(current_setting('t.take2') || ' ' || (select count(*) from public.stock_movements where reason <> 'receipt')::text, '{"m 2', 'a backdated take-out is accepted');
select isnt((select v ->> 'movements_counted' from pg_temp.val_before), pg_temp.valuation(1)::jsonb ->> 'movements_counted',
  'a later calculation counts the backdated movement: the calculation context moves, the original facts do not');

select is((select has_function_privilege('anon', 'public.stock_goods_trace_v1(uuid, uuid, uuid)', 'execute'))::text || ' ' ||
          (select has_function_privilege('authenticated', 'public.stock_trace_bills(uuid, uuid)', 'execute'))::text, 'false false',
  'anon cannot call the trace and the helpers are not callable by a client');

select * from finish();
rollback;
