-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4185 (0896, 0897): goods at the counter. A goods line of a sale leaves through the one stock path in the finalize's own
-- transaction, linked to the receipt: once, whatever the replays; a line that cannot leave rolls the sale back, number
-- included; a correction moves nothing; the physical return is its own command by someone who may manage the stock, bounded
-- by what the correction credits, and refunds and credits nothing; stock-only people cannot sell. Rolled back.
begin;
select plan(15);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
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
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.draft(p_user int, p_ws int, p_req int, p_receipt uuid, p_rev int, p_body text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_draft_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt, p_rev, p_body), p_delegated)
$f$;
create or replace function pg_temp.fin(p_user int, p_ws int, p_req int, p_receipt uuid, p_rev int, p_tenders text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt, p_rev, p_tenders))
$f$;
create or replace function pg_temp.corr(p_user int, p_ws int, p_req int, p_orig uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_orig, p_body))
$f$;
create or replace function pg_temp.line(p_desc text, p_qty text, p_price text, p_extra text default '') returns text language sql as $f$
  select format('{"description": "%s", "quantity": "%s", "unit_price": "%s", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}%s}', p_desc, p_qty, p_price, p_extra)
$f$;
create or replace function pg_temp.seq() returns text language sql stable as $f$
  select coalesce((select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), 'none')
$f$;
create or replace function pg_temp.treq(p_user int, p_req int, p_receipt uuid, p_amount bigint) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_tender_request_v1(%L, %L, %L, %L, %s)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt, 'card', p_amount))
$f$;
create or replace function pg_temp.tres(p_user int, p_req int, p_tender uuid, p_outcome text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_tender_resolve_v1(%L, %L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_tender, p_outcome, 'prov-' || p_req))
$f$;
create or replace function pg_temp.trec(p_user int, p_req int, p_tender uuid) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_tender_reconcile_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_tender))
$f$;
create or replace function pg_temp.refund(p_user int, p_req int, p_correction uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_correction, p_body))
$f$;
create or replace function pg_temp.newdraft(p_req int, p_ref text) returns text language sql as $f$
  select pg_temp.f(pg_temp.draft(1, 101, p_req, null, null, '{"source_ref": "' || p_ref || '", "lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), 'receipt_id')
$f$;
create or replace function pg_temp.goodsline(p_item int, p_qty text) returns text language sql as $f$
  select format('{"item_id": "%s", "quantity": "%s", "supply": "goods"}', pg_temp.u(p_item), p_qty)
$f$;
create or replace function pg_temp.onhand() returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(301) and location_id = (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN')
$f$;
create or replace function pg_temp.ret(p_user int, p_req int, p_correction uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_goods_return_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_correction, p_body))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cproducer-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counter FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true}', '{"member": ["manageStock"]}'),
  (pg_temp.u(102), 'Counter IT', 'IT', 'EUR', 'Europe/Rome', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(103), 'Counter JP', 'FR', 'JPY', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(104), 'Counter KW', 'FR', 'KWD', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
select pg_temp.u(200 + w), pg_temp.u(100 + w), pg_temp.u(1), true, true, 'active' from generate_series(1, 4) w;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
select pg_temp.u(800 + w), pg_temp.u(100 + w), 'Standard', 20, 'S', true, 'standard' from generate_series(1, 4) w;
insert into public.setting_values (scope, workspace_id, key, value)
select 'workspace', pg_temp.u(100 + w), 'counter.fiscal_obligation', '"none"'::jsonb from generate_series(1, 4) w;



insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mug', 500, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(102), 'Foreign mug', 500, true, 'piece', 'none', true);
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_move_v1(%L, %L, jsonb_build_array(jsonb_build_object('item_id', %L, 'quantity', 10, 'from', (select id from public.stock_locations where workspace_id = %L and kind = 'supplier'), 'to', (select id from public.stock_locations where workspace_id = %L and code = 'MAIN'))), 'receipt')::text$q$,
  pg_temp.u(101), pg_temp.u(1300), pg_temp.u(301), pg_temp.u(101), pg_temp.u(101)));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(298), pg_temp.u(101), pg_temp.u(3), false, false, 'active');

select is(pg_temp.onhand(), 10::numeric, 'ten mugs are on hand');
select is((select (e -> 'lines' -> 0 ->> 'supply') || ' ' || (e -> 'lines' -> 0 ->> 'amount_cents') || ' ' || (e -> 'lines' -> 0 #>> '{commercial,quantity}')
             from (select pg_temp.draft(1, 101, 1299, null, null, format('{"lines": [{"item_id": "%s", "quantity": "3"}]}', pg_temp.u(301)))::jsonb e) x),
  'goods 1500 3', 'a goods line needs only its item and its quantity: price, unit, rate and kind come from the server');
select set_config('t.d', pg_temp.draft(1, 101, 1301, null, null, '{"source_ref": "g-1", "lines": [' || pg_temp.goodsline(301, '2') || ']}'), false);
select is((current_setting('t.d')::jsonb #>> '{lines,0,supply}') || ' ' || (current_setting('t.d')::jsonb #>> '{totals,gross_minor}'), 'goods 1000', 'a goods line takes the item''s price and is frozen as goods: 2 x 5.00');
select set_config('t.r', pg_temp.f(current_setting('t.d'), 'receipt_id'), false);
select is(left(pg_temp.fin(3, 101, 1302, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 1000}]'), 9), 'ERR DKN01', 'a person who only manages the stock cannot sell');
select set_config('t.f', pg_temp.fin(1, 101, 1303, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 1000}]'), false);
select is(pg_temp.onhand()::text || ' ' || (select count(*) from public.stock_movements where counter_receipt_id = current_setting('t.r')::uuid and reason = 'sale')::text, '8.000000 1', 'finalizing takes the goods out once, with a movement linked to the receipt');
select is(pg_temp.f(pg_temp.fin(1, 101, 1303, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 1000}]'), 'replayed') || ' ' || pg_temp.onhand()::text || ' ' || (select count(*) from public.stock_movements where counter_receipt_id = current_setting('t.r')::uuid)::text, 'true 8.000000 1', 'a lost answer retried moves nothing twice');
select set_config('t.seq', pg_temp.seq(), false);
select set_config('t.d2', pg_temp.draft(1, 101, 1304, null, null, '{"source_ref": "g-2", "lines": [' || pg_temp.goodsline(301, '20') || ']}'), false);
select is(left(pg_temp.fin(1, 101, 1305, pg_temp.f(current_setting('t.d2'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 10000}]'), 9), 'ERR DKG03', 'a goods line that cannot leave refuses the sale');
select is(pg_temp.seq() || ' ' || pg_temp.onhand()::text, current_setting('t.seq') || ' 8.000000', 'and the number is not consumed and the stock is untouched (the atomic part rolled back)');
select is(pg_temp.draft(1, 101, 1306, null, null, '{"lines": [' || pg_temp.goodsline(302, '1') || ']}'), 'ERR DKT02 line_1_item', 'an item of another business is refused');
select is(pg_temp.draft(1, 101, 1307, null, null, '{"lines": [{"quantity": "1", "unit_price": "1.00", "supply": "goods", "description": "x", "unit": {"code": "u", "label": "u"}}]}'), 'ERR DKT02 line_1_item', 'a goods line with no item is refused');
select set_config('t.line', (select id::text from public.counter_receipt_lines where receipt_id = current_setting('t.r')::uuid and line_no = 1), false);
select set_config('t.c', pg_temp.corr(1, 101, 1308, current_setting('t.r')::uuid, format('{"lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))), false);
select is(pg_temp.onhand(), 8::numeric, 'a correction of goods is a credit document: no stock moves');
select set_config('t.cline', (select id::text from public.counter_receipt_lines where receipt_id = pg_temp.f(current_setting('t.c'), 'receipt_id')::uuid and line_no = 1), false);
select is(left(pg_temp.ret(2, 1309, pg_temp.f(current_setting('t.c'), 'receipt_id')::uuid, format('[{"corrects_line_id": "%s", "quantity": "1"}]', current_setting('t.cline'))), 9), 'ERR DKN01', 'a person who cannot manage the stock takes nothing back');
select set_config('t.ret', pg_temp.ret(1, 1310, pg_temp.f(current_setting('t.c'), 'receipt_id')::uuid, format('[{"corrects_line_id": "%s", "quantity": "1"}]', current_setting('t.cline'))), false);
select is(pg_temp.f(current_setting('t.ret'), 'movements') || ' ' || pg_temp.onhand()::text, '1 9.000000', 'the physical return takes the goods back, linked to the correction');
select is(pg_temp.ret(1, 1311, pg_temp.f(current_setting('t.c'), 'receipt_id')::uuid, format('[{"corrects_line_id": "%s", "quantity": "1"}]', current_setting('t.cline'))), 'ERR DKT08 {"left": "0", "line": 1, "reason": "return_beyond"}', 'no more comes back than the correction credits');
select is((select count(*)::int from public.counter_refunds) || ' ' || (select count(*)::int from public.counter_receipts where kind = 'correction'), '0 1', 'and a return neither refunds nor credits');

select * from finish();
rollback;
