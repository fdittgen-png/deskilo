-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (row 2): stock and money agree at the counter. Goods sold on a receipt leave stock once; what the customer
-- brings back comes back once, by whichever of the two doors: the counter's own return, which follows a correction and
-- is bounded by what it credits (`counter_goods_return_v1`), or the stock door's customer return of the sale movement
-- (`stock_return_v1`). The measure is what the ledger says is at the customer for an item: what was sold less what came
-- back, never below zero. Each scenario has an item of its own.
--
-- Since 0976 the counter's return is a customer return of the sale's own movements, in the one record both doors read
-- (`stock_reversals`): K and L the two doors in either order; M goods that left a lot come back to it, at its cost; N an
-- item tracked by lot, sold from two lots, comes back lot by lot; O a quantity in boxes is weighed as the sale weighed it,
-- and what the stock door brought back is said in boxes. Before 0976 this file measured the defect: three mugs sold, two
-- taken back at the counter, and the stock door still took back three (12 on hand of 10 received); two teas of a lot at
-- 3.00 taken back left the lot at 8 and two in no lot, the stock worth 24.00 instead of 30.00. Rolled back.
begin;
select plan(32);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
-- the answer of a statement run as a person, the deferred checks included, or ERR, its code and its detail
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
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
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '') || ' (' || sqlerrm || ')';
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.place(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and (code = p_code or kind = p_code)
   order by (code = p_code) desc, created_datetime limit 1
$f$;
-- The reads are volatile on purpose: they must see what a command run earlier in the same statement wrote.
create or replace function pg_temp.on_hand(p_item int) returns text language sql as $f$
  select trim_scale(coalesce(sum(quantity), 0))::text from public.stock_balances
   where item_id = pg_temp.u(p_item) and location_id = pg_temp.place('MAIN')
$f$;
-- what the ledger says is at the customer for an item: sold less brought back
create or replace function pg_temp.at_customer(p_item int) returns text language sql as $f$
  select trim_scale(coalesce(sum(quantity), 0))::text from public.stock_balances
   where item_id = pg_temp.u(p_item) and location_id = pg_temp.place('customer')
$f$;
-- a sale of one goods line, paid in cash: the receipt's id, or what refused it (p_more: what else the line says)
create or replace function pg_temp.sale(p_req int, p_item int, p_qty text, p_more text default '') returns text language plpgsql as $f$
declare v_draft text; v_out text;
begin
  v_draft := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('{"source_ref": "k-%s", "lines": [{"item_id": "%s", "quantity": "%s", "supply": "goods"%s}]}', p_req, pg_temp.u(p_item), p_qty, p_more)));
  if v_draft not like '{%' then return 'draft ' || v_draft; end if;
  v_out := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req + 1),
    v_draft::jsonb ->> 'receipt_id', (v_draft::jsonb ->> 'revision')::int, format('[{"kind": "cash", "amount_minor": %s}]', v_draft::jsonb #>> '{totals,gross_minor}')));
  if v_out not like '{%' then return 'finalize ' || v_out; end if;
  return v_draft::jsonb ->> 'receipt_id';
end
$f$;
create or replace function pg_temp.rec(p_key text) returns uuid language sql stable as $f$
  select case when current_setting(p_key, true) ~ '^[0-9a-f-]{36}$' then current_setting(p_key, true)::uuid end
$f$;
-- the goods of a correction's line taken back: the answer, or the refusal's code and detail without its sentence
create or replace function pg_temp.take_back(p_req int, p_correction uuid, p_qty text) returns text language sql as $f$
  select split_part(pg_temp.run_as(pg_temp.u(1), format('select public.counter_goods_return_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    p_correction, format('[{"corrects_line_id": "%s", "quantity": "%s"}]',
      (select id from public.counter_receipt_lines where receipt_id = p_correction and line_no = 1), p_qty))), ' (', 1)
$f$;
-- the counter's door: a correction crediting a quantity of the receipt's line, then the goods of it taken back (p_back:
-- the quantity taken back, when it is not the one credited); the correction is kept in r.correction
create or replace function pg_temp.credit_and_return(p_req int, p_receipt uuid, p_qty text, p_back text default null) returns text language plpgsql as $f$
declare v_corr text; v_ret text;
begin
  v_corr := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt,
    format('{"lines": [{"corrects_line_id": "%s", "quantity": "%s"}]}',
      (select id from public.counter_receipt_lines where receipt_id = p_receipt and line_no = 1), p_qty)));
  if v_corr not like '{%' then return 'correction ' || split_part(v_corr, ' (', 1); end if;
  perform set_config('r.correction', v_corr::jsonb ->> 'receipt_id', false);
  v_ret := pg_temp.take_back(p_req + 1, (v_corr::jsonb ->> 'receipt_id')::uuid, coalesce(p_back, p_qty));
  if v_ret not like '{%' then return 'credited, return ' || v_ret; end if;
  return 'credited, returned ' || (v_ret::jsonb ->> 'movements');
end
$f$;
-- the stock door: a customer return of the receipt's sale movement (p_nth: which of them, in the order the sale made them)
create or replace function pg_temp.stock_back(p_req int, p_receipt uuid, p_qty text, p_nth int default 1) returns text language sql as $f$
  select left(pg_temp.run_as(pg_temp.u(1), format('select public.stock_return_v1(%L, %L, %L, ''customer'', %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    pg_temp.u(p_req + 10000), jsonb_build_array(jsonb_build_object(
      'return_line_id', pg_temp.u(p_req + 20000),
      'source_movement_id', (select m.id from public.stock_movements m where m.counter_receipt_id = p_receipt and m.reason = 'sale' order by m.line_no, m.part offset p_nth - 1 limit 1),
      'quantity', p_qty, 'location', pg_temp.place('MAIN'))))), 9)
$f$;
-- what the read of what can still be reversed says of a receipt's sale movements, in the order the sale made them:
-- reversed/remaining/number of reversals, each
create or replace function pg_temp.reversible(p_receipt uuid) returns text language sql as $f$
  select string_agg(trim_scale((x.value ->> 'reversed')::numeric)::text || '/' || trim_scale((x.value ->> 'remaining')::numeric)::text
           || '/' || jsonb_array_length(x.value -> 'reversals'), ' ' order by m.line_no, m.part)
    from jsonb_array_elements(pg_temp.run_as(pg_temp.u(1), format('select public.stock_reversible_v1(%L, %L::uuid[])::text', pg_temp.u(101),
           (select array_agg(id) from public.stock_movements where counter_receipt_id = p_receipt and reason = 'sale')))::jsonb) x
    join public.stock_movements m on m.id = (x.value ->> 'movement_id')::uuid
$f$;
-- what MAIN holds of an item, lot by lot (`-` is stock in no lot)
create or replace function pg_temp.lots(p_item int) returns text language sql as $f$
  select coalesce(string_agg(coalesce(l.lot_code, '-') || ':' || trim_scale(b.quantity)::text, ',' order by l.lot_code nulls last), 'nothing')
    from public.stock_balances b left join public.stock_lots l on l.id = b.lot_id
   where b.item_id = pg_temp.u(p_item) and b.location_id = pg_temp.place('MAIN') and b.quantity <> 0
$f$;
create or replace function pg_temp.stock_value() returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select trim_scale((public.stock_value_at_v1(%L, null) ->> ''total_minor'')::numeric)::text', pg_temp.u(101)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'counter-once-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counter once', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true, "stockReturns": true}', '{"member": ["manageStock"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mug', 500, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Cup', 400, true, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Tea', 600, true, 'piece', 'none', true),
  (pg_temp.u(304), pg_temp.u(101), 'Honey', 700, true, 'piece', 'lot', true),
  (pg_temp.u(305), pg_temp.u(101), 'Rice', 100, true, 'piece', 'lot', true);
-- a box of rice is six pieces
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (pg_temp.u(101), pg_temp.u(305), 'box', 6, 1);

select ok(pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'')::text', pg_temp.u(101), pg_temp.u(900), jsonb_build_array(
  jsonb_build_object('item_id', pg_temp.u(301), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(302), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(303), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN'),
                     'new_lot', jsonb_build_object('code', 'T1', 'total_cost_minor', 3000))))) like '{%',
  'fixture: ten mugs, ten cups and a lot of ten teas at 3.00 are received at MAIN');

-- ── K: the counter's return first, then the stock door ──
do $d$ begin perform set_config('r.k', pg_temp.sale(1001, 301, '3'), false); end $d$;
select is(pg_temp.on_hand(301) || '|' || pg_temp.at_customer(301), '7|3', 'K three mugs sold leave stock, once: ' || current_setting('r.k'));
select is(pg_temp.credit_and_return(1011, pg_temp.rec('r.k'), '2') || '|' || pg_temp.on_hand(301) || '|' || pg_temp.at_customer(301),
  'credited, returned 1|9|1', 'K two are credited and taken back at the counter: one is still at the customer');
select is(pg_temp.credit_and_return(1011, pg_temp.rec('r.k'), '2') || '|' || pg_temp.on_hand(301) || '|' || pg_temp.at_customer(301),
  'credited, returned 1|9|1', 'K the same two requests sent again answer the same and move nothing');
select is(pg_temp.take_back(1013, pg_temp.rec('r.correction'), '1') || '|' || pg_temp.on_hand(301),
  'ERR DKL08 {"left": "0", "line": 1, "reason": "return_beyond"}|9', 'K no more comes back than the correction credits, as before');
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.counter_goods_return_v1(%L, %L, %L, ''[]''::jsonb)::text', pg_temp.u(101), pg_temp.u(1014),
  pg_temp.rec('r.correction'))), 9) || '|' || pg_temp.on_hand(301), 'ERR DKL02|9', 'K a return that names no line is refused with a code of the counter''s own');
select is(pg_temp.stock_back(1021, pg_temp.rec('r.k'), '3') || '|' || pg_temp.on_hand(301) || '|' || pg_temp.at_customer(301),
  'ERR DKG17|9|1', 'K the stock door does not take back the three sold: two of them are back already');
select is(pg_temp.stock_back(1022, pg_temp.rec('r.k'), '1') || '|' || pg_temp.on_hand(301) || '|' || pg_temp.at_customer(301),
  '{"kind": |10|0', 'K it takes back the one still at the customer');
select is(pg_temp.credit_and_return(1031, pg_temp.rec('r.k'), '1') || '|' || pg_temp.on_hand(301) || '|' || pg_temp.at_customer(301),
  'credited, return ERR DKL08 {"left": "0", "line": 1, "reason": "already_back"}|10|0', 'K and the counter takes nothing back after it: all three are back');
select is(pg_temp.reversible(pg_temp.rec('r.k')), '3/0/2', 'K the one record holds both: three reversed on the sale, none left, by two returns');
select is((select count(*)::int || '|' || min(r.kind) || '|' || (min(t.result ->> 'counter_receipt_id') = min(m.counter_receipt_id::text))::text
                  || '|' || (min(m.counter_line_id::text) is not null)::text
             from public.stock_reversals r
             join public.stock_returns t on t.workspace_id = r.workspace_id and t.return_id = r.return_id
             join public.stock_movements m on m.id = r.movement_id
            where r.workspace_id = pg_temp.u(101) and m.counter_receipt_id is not null), '1|customer|true|true',
  'K the counter''s return is a customer return in that record, its movement linked to the correction and its line');

-- ── L: the stock door first, then the counter's return ──
do $d$ begin perform set_config('r.l', pg_temp.sale(2001, 302, '2'), false); end $d$;
select is(pg_temp.on_hand(302) || '|' || pg_temp.at_customer(302), '8|2', 'L two cups sold leave stock, once: ' || current_setting('r.l'));
select is(pg_temp.stock_back(2021, pg_temp.rec('r.l'), '2') || '|' || pg_temp.on_hand(302) || '|' || pg_temp.at_customer(302),
  '{"kind": |10|0', 'L both come back by the stock door');
select is(pg_temp.credit_and_return(2011, pg_temp.rec('r.l'), '2') || '|' || pg_temp.on_hand(302) || '|' || pg_temp.at_customer(302),
  'credited, return ERR DKL08 {"left": "0", "line": 1, "reason": "already_back"}|10|0', 'L the counter credits them and takes nothing back a second time');

-- ── M: goods that left a lot come back to it, at its cost ──
do $d$ begin perform set_config('r.m', pg_temp.sale(3001, 303, '2'), false); end $d$;
select is(pg_temp.lots(303) || '|' || pg_temp.stock_value(), 'T1:8|2400', 'M two teas sold leave their lot: ' || current_setting('r.m'));
select is(pg_temp.credit_and_return(3011, pg_temp.rec('r.m'), '2') || '|' || pg_temp.lots(303) || '|' || pg_temp.stock_value(),
  'credited, returned 1|T1:10|3000', 'M taken back at the counter, they are in their lot again and the stock is worth what it was');

-- ── N: an item tracked by lot, sold from two lots, comes back lot by lot ──
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'')::text', pg_temp.u(101), pg_temp.u(901), jsonb_build_array(
  jsonb_build_object('item_id', pg_temp.u(304), 'quantity', '2', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN'),
                     'new_lot', jsonb_build_object('code', 'H1', 'expires_on', '2099-01-31', 'total_cost_minor', 200)),
  jsonb_build_object('item_id', pg_temp.u(304), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN'),
                     'new_lot', jsonb_build_object('code', 'H2', 'expires_on', '2099-06-30', 'total_cost_minor', 2000)),
  jsonb_build_object('item_id', pg_temp.u(305), 'quantity', '4', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN'),
                     'new_lot', jsonb_build_object('code', 'R1', 'expires_on', '2099-01-31', 'total_cost_minor', 400)),
  jsonb_build_object('item_id', pg_temp.u(305), 'quantity', '20', 'from', pg_temp.place('supplier'), 'to', pg_temp.place('MAIN'),
                     'new_lot', jsonb_build_object('code', 'R2', 'expires_on', '2099-06-30', 'total_cost_minor', 4000))))), 1)
  || '|' || pg_temp.stock_value(), '{|9600',
  'fixture: honey in a lot of two at 1.00 and a lot of ten at 2.00, rice in a lot of four at 1.00 and a lot of twenty at 2.00');
do $d$ begin perform set_config('r.n', pg_temp.sale(4001, 304, '3'), false); end $d$;
select is(pg_temp.lots(304) || '|' || pg_temp.stock_value(), 'H2:9|9200', 'N three jars sold take the lot that expires first, then the next: ' || current_setting('r.n'));
select is(pg_temp.credit_and_return(4011, pg_temp.rec('r.n'), '2') || '|' || pg_temp.lots(304) || '|' || pg_temp.stock_value(),
  'credited, returned 1|H1:2,H2:9|9400', 'N two taken back at the counter are in the first lot again, at its cost');
select is(pg_temp.stock_back(4021, pg_temp.rec('r.n'), '1') || '|' || pg_temp.lots(304), 'ERR DKG17|H1:2,H2:9',
  'N the stock door takes nothing back of the first lot''s sale: both jars of it are back');
select is(pg_temp.credit_and_return(4031, pg_temp.rec('r.n'), '1') || '|' || pg_temp.lots(304) || '|' || pg_temp.stock_value(),
  'credited, returned 1|H1:2,H2:10|9600', 'N the third comes back to the second lot, and the stock is worth what it was');
select is(pg_temp.reversible(pg_temp.rec('r.n')), '2/0/1 1/0/1', 'N each of the sale''s two movements is reversed in full, once');

-- ── O: a quantity in boxes is weighed as the sale weighed it ──
do $d$ begin perform set_config('r.o', pg_temp.sale(5001, 305, '2', ', "unit": {"code": "box", "label": "box", "un_ece_code": "BX"}'), false); end $d$;
select is(pg_temp.lots(305) || '|' || pg_temp.at_customer(305), 'R2:12|12', 'O two boxes sold are twelve pieces, four of the first lot and eight of the second: ' || current_setting('r.o'));
select is(pg_temp.credit_and_return(5011, pg_temp.rec('r.o'), '1') || '|' || pg_temp.lots(305) || '|' || pg_temp.at_customer(305),
  'credited, returned 2|R1:4,R2:14|6', 'O one box taken back is six pieces: the four of the first lot and two of the second, each in its lot');
select is(pg_temp.take_back(5013, pg_temp.rec('r.correction'), '1') || '|' || pg_temp.at_customer(305),
  'ERR DKL08 {"left": "0", "line": 1, "reason": "return_beyond"}|6', 'O the correction credited one box, and one box is back');
select is(pg_temp.stock_back(5021, pg_temp.rec('r.o'), '3', 2) || '|' || pg_temp.lots(305) || '|' || pg_temp.at_customer(305),
  '{"kind": |R1:4,R2:17|3', 'O the stock door takes three pieces of the second lot back');
select is(pg_temp.credit_and_return(5031, pg_temp.rec('r.o'), '1') || '|' || pg_temp.lots(305) || '|' || pg_temp.at_customer(305),
  'credited, return ERR DKL08 {"left": "0.5", "line": 1, "reason": "already_back"}|R1:4,R2:17|3',
  'O the second box is credited, and half a box of it is all the customer still has');
select is(left(pg_temp.take_back(5033, pg_temp.rec('r.correction'), '0.5'), 1) || '|' || pg_temp.lots(305) || '|' || pg_temp.at_customer(305),
  '{|R1:4,R2:20|0', 'O that half box comes back at the counter: every piece is in its lot again');
select is(pg_temp.reversible(pg_temp.rec('r.o')), '4/0/1 8/0/3', 'O the first lot''s sale is reversed once, the second''s by the counter, the stock door and the counter');

-- ── the measure ──
select is((select count(*)::int from public.stock_balances b
            where b.workspace_id = pg_temp.u(101) and b.location_id = pg_temp.place('customer') and b.quantity <> 0), 0,
  'for no item does the ledger say the customer holds anything, or brought back more than was sold');
select is(pg_temp.on_hand(301) || '|' || pg_temp.on_hand(302) || '|' || pg_temp.on_hand(303) || '|' || pg_temp.on_hand(304) || '|' || pg_temp.on_hand(305),
  '10|10|10|12|24', 'and no more is on hand than was received');
select is((select count(*)::int from public.stock_balances b
            where b.workspace_id = pg_temp.u(101) and b.location_id = pg_temp.place('MAIN') and b.lot_id is null
              and b.item_id in (pg_temp.u(303), pg_temp.u(304), pg_temp.u(305)) and b.quantity <> 0), 0,
  'and nothing that left a lot sits in no lot');

select * from finish();
rollback;
