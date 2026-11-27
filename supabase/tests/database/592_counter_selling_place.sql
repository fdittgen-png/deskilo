-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (row 11, D1): the till sells from the selling place. A shop keeps its main store MAIN with the shop floor FLOOR
-- (two shelves below it) and the back store BACK beside the floor. The front till names FLOOR as its selling place; the
-- kiosk till names none. Proven here: who may set a selling place and which places are refused; an older app's save
-- leaves it alone; the lots a till offers are those of its place and the places below; a sale draws the lot that expires
-- first wherever it lies in that tree, the place itself first for goods without a lot, and never the back store beside
-- it; a shortage is refused and nothing moves, and the same request passes once the shelf is refilled, once; a till
-- without a place sells from the business's selling place (MAIN and everything below it, or the place the setting
-- names; a code that is no place refuses the sale); a line that names its place leaves from it alone; each movement
-- of a sale keeps the place it left, which is what a return needs. Rolled back.
begin;
select plan(33);

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
-- an answer as JSON, or the refusal under "error"
create or replace function pg_temp.j(p text) returns jsonb language sql immutable as $f$
  select case when p like '{%' or p like '[%' then p::jsonb else jsonb_build_object('error', p) end
$f$;
-- a key of a refusal's detail ("ERR DKG03 {...}")
create or replace function pg_temp.d(p text, k text) returns text language sql immutable as $f$
  select case when p like 'ERR _____ {%' then substring(p from 11)::jsonb ->> k else p end
$f$;
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.day(p_offset int) returns text language sql stable as $f$
  select to_char(public.workspace_today(pg_temp.u(101)) + p_offset, 'YYYY-MM-DD')
$f$;
create or replace function pg_temp.lot(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = p_code
$f$;
-- what a place holds of an item
create or replace function pg_temp.bal(p_item int, p_loc text) returns text language sql stable as $f$
  select trim_scale(coalesce(sum(quantity), 0))::text from public.stock_balances
   where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(p_item) and location_id = pg_temp.loc(p_loc)
$f$;
-- a stock command as the owner calls it
create or replace function pg_temp.cmd(p_fn text, p_req int, p_args text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.%s(%L, %L, %s)::text', p_fn, pg_temp.u(101), pg_temp.u(p_req), p_args))
$f$;
-- goods arriving from the supplier at a place, a lot-tracked item with its lot and date
create or replace function pg_temp.arrive(p_req int, p_item int, p_qty text, p_to text, p_lot text default null, p_days int default null) returns text language sql as $f$
  select pg_temp.cmd('stock_move_v1', p_req, format('%L::jsonb, %L',
    jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty, 'from', pg_temp.place('supplier'), 'to', pg_temp.loc(p_to),
      'new_lot', case when p_lot is not null then jsonb_build_object('code', p_lot, 'expires_on', pg_temp.day(p_days), 'total_cost_minor', 100) end)))::text, 'receipt'))
$f$;
create or replace function pg_temp.shift(p_req int, p_item int, p_qty text, p_from text, p_to text, p_lot text) returns text language sql as $f$
  select pg_temp.cmd('stock_transfer_v1', p_req, format('%L::jsonb',
    jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty, 'from', pg_temp.loc(p_from), 'to', pg_temp.loc(p_to), 'lot_id', pg_temp.lot(p_lot)))::text))
$f$;
-- a till saved with its selling place, by the app of today
create or replace function pg_temp.till2(p_user int, p_req int, p_till text, p_name text, p_place uuid) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_till_save_v2(%L, %L, %L, %L, null, true, %L)::text',
    pg_temp.u(101), pg_temp.u(p_req), nullif(p_till, '')::uuid, p_name, p_place))
$f$;
create or replace function pg_temp.till_place(p_name text) returns text language sql stable as $f$
  select coalesce((select l.code from public.stock_locations l where l.id = t.selling_place_id), 'none')
    from public.counter_tills t where t.workspace_id = pg_temp.u(101) and t.name = p_name
$f$;
create or replace function pg_temp.draft(p_req int, p_till text, p_lines text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    jsonb_build_object('lines', p_lines::jsonb, 'till_id', p_till)::text))
$f$;
-- the draft finalized, paid in cash for its total
create or replace function pg_temp.fin(p_req int, p_draft text) returns text language sql as $f$
  select case when p_draft like 'ERR%' then p_draft else
    pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
      p_draft::jsonb ->> 'receipt_id', format('[{"kind": "cash", "amount_minor": %s}]', (p_draft::jsonb #>> '{totals,gross_minor}')::bigint))) end
$f$;
create or replace function pg_temp.sell(p_req int, p_till text, p_lines text) returns text language sql as $f$
  select pg_temp.fin(p_req + 1, pg_temp.draft(p_req, p_till, p_lines))
$f$;
create or replace function pg_temp.one(p_item int, p_qty text, p_extra jsonb default '{}'::jsonb) returns text language sql immutable as $f$
  select jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty) || p_extra)::text
$f$;
-- what a receipt moved: place:lot:quantity of each movement, in the order of the lines (the place the goods left, or
-- came back to)
create or replace function pg_temp.moves(p_receipt text, p_reason text default 'sale') returns text language sql stable as $f$
  select coalesce(string_agg(
           (select l.code from public.stock_locations l where l.id = case when p_reason = 'sale' then m.from_location_id else m.to_location_id end)
           || ':' || coalesce((select t.lot_code from public.stock_lots t where t.id = m.lot_id), '') || ':' || trim_scale(m.quantity)::text,
           ' ' order by m.line_no, m.part), 'nothing')
    from public.stock_movements m
   where m.workspace_id = pg_temp.u(101) and m.reason = p_reason
     and m.counter_receipt_id = nullif(pg_temp.j(p_receipt) ->> 'receipt_id', '')::uuid
$f$;
create or replace function pg_temp.lots(p_till text) returns text language sql as $f$
  select coalesce((select string_agg((l ->> 'code') || ':' || (l ->> 'quantity'), ' ' order by o)
                     from jsonb_array_elements(pg_temp.j(x.a) -> 'lots') with ordinality y (l, o)), x.a)
    from (select pg_temp.run_as(pg_temp.u(1), format('select public.counter_item_lots_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(301), nullif(p_till, '')::uuid)) a) x
$f$;
-- a step kept under a name; a refused step says so in the run's notes
create or replace function pg_temp.keep(p_key text, p_value text) returns setof text language plpgsql as $f$
begin
  perform set_config(p_key, coalesce(p_value, ''), false);
  if p_value is null or p_value like 'ERR%' then return next diag('refused -- ' || p_key || ': ' || coalesce(p_value, 'null')); end if;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'selling-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Selling place', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "stockManagement": true, "stockLots": true, "stockReceiving": true, "stockTakeOut": true, "counterReceipts": true, "counterTillSessions": true}',
   '{"member": ["issueInvoices"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
-- yoghurt is tracked by its date, bread by nothing
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Yoghurt', 150, true, 'piece', 'expiry', true),
  (pg_temp.u(302), pg_temp.u(101), 'Bread', 200, true, 'piece', 'none', true);
-- the main store holds the shop floor, with two shelves, and the back store beside the floor; OLD is no longer in use
insert into public.stock_locations (id, workspace_id, parent_id, kind, code, active) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR', true),
  (pg_temp.u(904), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'BACK', true),
  (pg_temp.u(905), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'OLD', false);
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(902), pg_temp.u(101), pg_temp.u(901), 'shelf', 'SHELF-A'),
  (pg_temp.u(903), pg_temp.u(101), pg_temp.u(901), 'shelf', 'SHELF-B');
select pg_temp.keep('t.a1', pg_temp.arrive(8001, 301, '2', 'SHELF-B', 'L-EARLY', 3));
select pg_temp.keep('t.a2', pg_temp.arrive(8002, 301, '5', 'FLOOR', 'L-LATE', 10));
select pg_temp.keep('t.a3', pg_temp.arrive(8003, 301, '10', 'BACK', 'L-BACK', 1));
select pg_temp.keep('t.a4', pg_temp.arrive(8004, 301, '4', 'MAIN', 'L-MAIN', 5));
select pg_temp.keep('t.a5', pg_temp.arrive(8005, 302, '2', 'FLOOR'));
select pg_temp.keep('t.a6', pg_temp.arrive(8006, 302, '3', 'SHELF-A'));
select pg_temp.keep('t.a7', pg_temp.arrive(8007, 302, '6', 'BACK'));

-- ── a till is given its selling place by whoever manages the tills, and only a place that holds stock and is in use ──────────
select pg_temp.keep('t.front', pg_temp.till2(1, 8101, '', 'Front', pg_temp.loc('FLOOR')));
select pg_temp.keep('t.kiosk', pg_temp.till2(1, 8102, '', 'Kiosk', null));
select set_config('t.t1', pg_temp.j(current_setting('t.front')) ->> 'till_id', false);
select set_config('t.t2', pg_temp.j(current_setting('t.kiosk')) ->> 'till_id', false);
select is((pg_temp.j(current_setting('t.front')) ->> 'selling_place_id') || ' ' || pg_temp.till_place('Front') || ' ' || pg_temp.till_place('Kiosk'),
  pg_temp.loc('FLOOR')::text || ' FLOOR none', 'the front till sells from the shop floor; the kiosk names no place of its own');
select is(pg_temp.till2(1, 8103, current_setting('t.t2'), 'Kiosk', pg_temp.place('customer')), 'ERR DKL12 {"reason": "selling_place_unknown"}',
  'the place the customers are is no place to sell from');
select is(pg_temp.till2(1, 8104, current_setting('t.t2'), 'Kiosk', pg_temp.loc('OLD')) || ' / ' || pg_temp.till2(1, 8105, current_setting('t.t2'), 'Kiosk', pg_temp.u(999)),
  'ERR DKL12 {"reason": "selling_place_unknown"} / ERR DKL12 {"reason": "selling_place_unknown"}',
  'nor is a place no longer in use, nor one the business does not have');
select is(pg_temp.till_place('Kiosk'), 'none', 'a refused place changes nothing on the till');
select is(left(pg_temp.till2(2, 8106, current_setting('t.t1'), 'Front', pg_temp.loc('BACK')), 9) || ' ' || pg_temp.till_place('Front'), 'ERR DKN01 FLOOR',
  'a cashier who does not manage the tills moves no selling place');
-- an app of the last release saves the till without the place: the place stays
select pg_temp.keep('t.v1', pg_temp.run_as(pg_temp.u(1), format('select public.counter_till_save_v1(%L, %L, %L, %L, null, true)::text', pg_temp.u(101), pg_temp.u(8107), current_setting('t.t1'), 'Front counter')));
select is(pg_temp.till_place('Front counter'), 'FLOOR', 'renamed by an app that does not know the selling place, the till keeps it');
select is((select (a ->> 'default_code') || ' ' || ((a ->> 'default_place_id')::uuid = pg_temp.loc('MAIN'))::text || ' '
                  || (select string_agg(p ->> 'code', ',' order by p ->> 'code') from jsonb_array_elements(a -> 'places') p)
             from (select pg_temp.j(pg_temp.run_as(pg_temp.u(1), format('select public.counter_selling_places_v1(%L)::text', pg_temp.u(101)))) a) x),
  'MAIN true BACK,FLOOR,MAIN,SHELF-A,SHELF-B', 'the places a till may be given are those in use that hold stock; the business sells from MAIN when a till names none');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.counter_selling_places_v1(%L)::text', pg_temp.u(101))), 9), 'ERR DKN01', 'the cashier does not read them');
select is(has_function_privilege('authenticated', 'public.counter_selling_place(uuid, uuid)', 'execute')::text || ' '
    || has_function_privilege('authenticated', 'public.counter_goods_parts(uuid, uuid, uuid, uuid, text, text, jsonb, jsonb, boolean)', 'execute')::text || ' '
    || has_function_privilege('anon', 'public.counter_till_save_v2(uuid, uuid, uuid, text, uuid, boolean, uuid)', 'execute')::text || ' '
    || has_function_privilege('anon', 'public.counter_selling_places_v1(uuid)', 'execute')::text || ' '
    || has_function_privilege('anon', 'public.counter_item_lots_v1(uuid, uuid, uuid)', 'execute')::text,
  'false false false false false', 'the rule and the plan are the server''s own; nobody signed out calls the commands');

-- ── the lots a till offers are those of its selling place and the places below it ───────────────────────────────────────────
select pg_temp.keep('t.s1', pg_temp.run_as(pg_temp.u(1), format('select public.counter_session_open_v1(%L, %L, %L, 10000, null)::text', pg_temp.u(101), pg_temp.u(8201), current_setting('t.t1'))));
select pg_temp.keep('t.s2', pg_temp.run_as(pg_temp.u(1), format('select public.counter_session_open_v1(%L, %L, %L, 10000, null)::text', pg_temp.u(101), pg_temp.u(8202), current_setting('t.t2'))));
select is(pg_temp.lots(current_setting('t.t1')), 'L-EARLY:2 L-LATE:5', 'the front till offers the lots on the floor and its shelves, not the back store''s');
select is(pg_temp.lots(current_setting('t.t2')) || ' / ' || pg_temp.lots(''), 'L-BACK:10 L-EARLY:2 L-MAIN:4 L-LATE:5 / L-BACK:10 L-EARLY:2 L-MAIN:4 L-LATE:5',
  'a till without a place, and a call that names no till, read the business''s selling place: MAIN and everything below it');
select is(pg_temp.lots(pg_temp.u(999)::text), 'ERR DKL12 {"reason": "till_unknown"}', 'a till the business does not have reads nothing');

-- ── a sale draws the lot that expires first wherever it lies in the till''s tree, and never the back store beside it ────────
select pg_temp.keep('t.r1', pg_temp.sell(8300, current_setting('t.t1'), pg_temp.one(301, '3')));
select is(pg_temp.moves(current_setting('t.r1')), 'SHELF-B:L-EARLY:2 FLOOR:L-LATE:1',
  'three yoghurts at the front till: the two that expire first leave the shelf, the third the floor; the back store''s lot expires sooner and is not touched');
select pg_temp.keep('t.r2', pg_temp.sell(8302, current_setting('t.t2'), pg_temp.one(301, '1')));
select is(pg_temp.moves(current_setting('t.r2')), 'BACK:L-BACK:1',
  'the kiosk names no place: it sells from MAIN and everything below it, the lot that expires first, which lies in the back store');

-- ── refusal: more than the tree holds; recovery: the same request once the shelf is refilled, and only once ─────────────────
select pg_temp.keep('t.d3', pg_temp.draft(8304, current_setting('t.t1'), pg_temp.one(301, '5')));
select set_config('t.f3', pg_temp.fin(8305, current_setting('t.d3')), false);
select is(left(current_setting('t.f3'), 9) || ' ' || pg_temp.d(current_setting('t.f3'), 'reason') || ' ' || pg_temp.d(current_setting('t.f3'), 'held') || '/' || pg_temp.d(current_setting('t.f3'), 'asked'),
  'ERR DKG03 not_enough 4/5', 'five yoghurts are refused: four are in the till''s tree, whatever the back store and the main store hold');
select is(pg_temp.bal(301, 'FLOOR') || '/' || pg_temp.bal(301, 'BACK') || ' ' || (select state from public.counter_receipts where id = (pg_temp.j(current_setting('t.d3')) ->> 'receipt_id')::uuid)
    || ' ' || pg_temp.moves(current_setting('t.d3')), '4/9 draft nothing', 'the refused sale moved nothing and issued nothing');
select pg_temp.keep('t.refill', pg_temp.shift(8306, 301, '2', 'BACK', 'SHELF-A', 'L-BACK'));
select pg_temp.keep('t.f3b', pg_temp.fin(8305, current_setting('t.d3')));
select is(pg_temp.moves(current_setting('t.f3b')), 'SHELF-A:L-BACK:2 FLOOR:L-LATE:3',
  'two are brought from the back store to a shelf and the same sale passes: the refilled lot expires first and leaves first');
select is((pg_temp.j(pg_temp.fin(8305, current_setting('t.d3'))) ->> 'replayed') || ' ' || (select count(*)::text from public.stock_movements m
     where m.counter_receipt_id = (pg_temp.j(current_setting('t.d3')) ->> 'receipt_id')::uuid and m.reason = 'sale'), 'true 2', 'sent again, the sale answers as issued and moves nothing more');

-- ── goods without a lot: the selling place itself first, then the places below it ────────────────────────────────────────────
select pg_temp.keep('t.r4', pg_temp.sell(8310, current_setting('t.t1'), pg_temp.one(302, '4')));
select is(pg_temp.moves(current_setting('t.r4')), 'FLOOR::2 SHELF-A::2', 'four loaves: the two on the floor, then two from the shelf');
select is(left(pg_temp.sell(8312, current_setting('t.t1'), pg_temp.one(302, '2')), 9) || ' ' || pg_temp.bal(302, 'FLOOR') || '/' || pg_temp.bal(302, 'SHELF-A') || '/' || pg_temp.bal(302, 'BACK'),
  'ERR DKG03 0/1/6', 'two more are refused with one left on the shelf: the six in the back store are not the till''s to sell, and nothing moved');
-- a business that lets its stock go below zero: what the tree does not hold is asked of the selling place itself, as it always was
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.allow_negative', 'true'::jsonb);
select pg_temp.keep('t.r5', pg_temp.sell(8314, current_setting('t.t1'), pg_temp.one(302, '2')));
select is(pg_temp.moves(current_setting('t.r5')) || ' ' || pg_temp.bal(302, 'FLOOR') || '/' || pg_temp.bal(302, 'SHELF-A') || '/' || pg_temp.bal(302, 'BACK'),
  'FLOOR::1 SHELF-A::1 -1/0/6', 'where the business allows it the missing loaf is taken on the floor itself, which goes below zero; the back store is left alone');
delete from public.setting_values where workspace_id = pg_temp.u(101) and key = 'stock.allow_negative';

-- ── a lot the seller names leaves from the places of the tree that hold it; a line that names its place from that place alone ─
select pg_temp.keep('t.a8', pg_temp.arrive(8320, 301, '3', 'SHELF-A', 'L-NAMED', 20));
select pg_temp.keep('t.sh', pg_temp.shift(8321, 301, '1', 'SHELF-A', 'FLOOR', 'L-NAMED'));
select pg_temp.keep('t.r6', pg_temp.sell(8322, current_setting('t.t1'), pg_temp.one(301, '3', jsonb_build_object('lot_id', pg_temp.lot('L-NAMED')))));
select is(pg_temp.moves(current_setting('t.r6')), 'FLOOR:L-NAMED:1 SHELF-A:L-NAMED:2', 'three of a named lot: the one on the floor and the two on the shelf');
select is(left(pg_temp.sell(8324, current_setting('t.t1'), pg_temp.one(301, '1', jsonb_build_object('lot_id', pg_temp.lot('L-MAIN')))), 9) || ' ' || pg_temp.bal(301, 'MAIN'),
  'ERR DKG03 4', 'a lot that lies outside the till''s tree is not sold at this till');
select pg_temp.keep('t.r7', pg_temp.sell(8326, current_setting('t.t1'), pg_temp.one(301, '1', jsonb_build_object('from_location_id', pg_temp.loc('BACK')))));
select is(pg_temp.moves(current_setting('t.r7')), 'BACK:L-BACK:1', 'a line that names its place leaves from that place alone, as before');

-- ── a till without a place follows the business''s selling place; a code that is no place refuses the sale ───────────────────
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.selling_place', '"FLOOR"'::jsonb);
select is(pg_temp.lots(current_setting('t.t2')), 'L-LATE:1', 'the business names the floor: the kiosk offers the floor''s lots');
select pg_temp.keep('t.r8', pg_temp.sell(8330, current_setting('t.t2'), pg_temp.one(301, '1')));
select is(pg_temp.moves(current_setting('t.r8')), 'FLOOR:L-LATE:1', 'and sells from the floor, not the lot in the back store that expires sooner');
update public.setting_values set value = '"NOPE"'::jsonb where workspace_id = pg_temp.u(101) and key = 'counter.selling_place';
select set_config('t.f9', pg_temp.sell(8332, current_setting('t.t2'), pg_temp.one(301, '1')), false);
select is(current_setting('t.f9') || ' ' || pg_temp.bal(301, 'MAIN') || '/' || pg_temp.bal(301, 'BACK'), 'ERR DKL07 from_place 4/6',
  'a code that is no place of the business refuses the sale: it never falls back to another place');
select is(left(pg_temp.sell(8336, current_setting('t.t1'), pg_temp.one(301, '1')), 9), 'ERR DKG03',
  'the front till has a place of its own and is asked there, whatever the business names: it has sold its tree empty and is refused for that');
delete from public.setting_values where workspace_id = pg_temp.u(101) and key = 'counter.selling_place';
select pg_temp.keep('t.r10', pg_temp.sell(8334, current_setting('t.t2'), pg_temp.one(301, '1')));
select is(pg_temp.moves(current_setting('t.r10')), 'BACK:L-BACK:1', 'the setting taken back, the kiosk sells from MAIN and everything below it again');

-- ── two lines of one item plan around each other across the places ───────────────────────────────────────────────────────────
select pg_temp.keep('t.a9', pg_temp.arrive(8340, 301, '2', 'SHELF-B', 'L-TWO-A', 2));
select pg_temp.keep('t.a10', pg_temp.arrive(8341, 301, '3', 'FLOOR', 'L-TWO-B', 4));
select pg_temp.keep('t.r12', pg_temp.sell(8342, current_setting('t.t1'), jsonb_build_array(
  jsonb_build_object('item_id', pg_temp.u(301), 'quantity', '1'), jsonb_build_object('item_id', pg_temp.u(301), 'quantity', '3'))::text));
select is(pg_temp.moves(current_setting('t.r12')), 'SHELF-B:L-TWO-A:1 SHELF-B:L-TWO-A:1 FLOOR:L-TWO-B:2',
  'one and three of the same yoghurt: the second line takes what the first left on the shelf, then the floor; no lot is drawn twice');
select is(pg_temp.bal(301, 'SHELF-B') || '/' || pg_temp.bal(301, 'FLOOR'), '0/1', 'and the places hold what is left');

-- ── what a return needs: each movement of a sale names its receipt line and the place it left ─────────────────────────────────────────
select is((select string_agg(l.code || ':' || trim_scale(m.quantity)::text, ' ' order by m.line_no, m.part)
             from public.stock_movements m join public.stock_locations l on l.id = m.from_location_id
            where m.workspace_id = pg_temp.u(101) and m.reason = 'sale'
              and m.counter_line_id = (select x.id from public.counter_receipt_lines x
                                        where x.receipt_id = (pg_temp.j(current_setting('t.r4')) ->> 'receipt_id')::uuid and x.line_no = 1)),
  'FLOOR:2 SHELF-A:2', 'the sale of the four loaves left two movements, each with the line it belongs to and the place it left: goods taken back can be put where they were');

-- ── a business that set nothing and keeps nothing below MAIN: a sale posts what it posted ────────────────────────────────────
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(102), 'Flat shop', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "stockManagement": true, "stockLots": true, "stockReceiving": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(203), pg_temp.u(102), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values (pg_temp.u(802), pg_temp.u(102), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(102), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(311), pg_temp.u(102), 'Milk', 120, true, 'piece', 'expiry', true), (pg_temp.u(312), pg_temp.u(102), 'Bag', 30, true, 'piece', 'none', true);
select pg_temp.keep('t.flat', pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(102), pg_temp.u(8401),
  format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "new_lot": {"code": "M-1", "expires_on": "%s", "total_cost_minor": 100}},
           {"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "new_lot": {"code": "M-2", "expires_on": "%s", "total_cost_minor": 150}},
           {"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s"}]',
    pg_temp.u(311), (select id from public.stock_locations where workspace_id = pg_temp.u(102) and kind = 'supplier'), (select id from public.stock_locations where workspace_id = pg_temp.u(102) and code = 'MAIN'), pg_temp.day(2),
    pg_temp.u(311), (select id from public.stock_locations where workspace_id = pg_temp.u(102) and kind = 'supplier'), (select id from public.stock_locations where workspace_id = pg_temp.u(102) and code = 'MAIN'), pg_temp.day(6),
    pg_temp.u(312), (select id from public.stock_locations where workspace_id = pg_temp.u(102) and kind = 'supplier'), (select id from public.stock_locations where workspace_id = pg_temp.u(102) and code = 'MAIN')), 'receipt')));
select pg_temp.keep('t.fd', pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text', pg_temp.u(102), pg_temp.u(8402),
  format('{"lines": [{"item_id": "%s", "quantity": "3"}, {"item_id": "%s", "quantity": "2"}]}', pg_temp.u(311), pg_temp.u(312)))));
select pg_temp.keep('t.ff', pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text', pg_temp.u(102), pg_temp.u(8403),
  pg_temp.j(current_setting('t.fd')) ->> 'receipt_id', format('[{"kind": "cash", "amount_minor": %s}]', (pg_temp.j(current_setting('t.fd')) #>> '{totals,gross_minor}')::bigint))));
select is((select string_agg(l.code || ':' || coalesce(t.lot_code, '') || ':' || trim_scale(m.quantity)::text || ':' || m.entered_unit, ' ' order by m.line_no, m.part)
             from public.stock_movements m join public.stock_locations l on l.id = m.from_location_id left join public.stock_lots t on t.id = m.lot_id
            where m.workspace_id = pg_temp.u(102) and m.reason = 'sale'),
  'MAIN:M-1:2:piece MAIN:M-2:1:piece MAIN::2:piece',
  'with no till, no setting and nothing below MAIN the sale leaves MAIN as it always did: the lot that expires first, then the next, and the goods without a lot in one movement');

select * from finish();
rollback;
