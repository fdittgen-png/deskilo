-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (row 2; 0975): stock and money agree on a standalone invoice. What an invoice's goods lines say left is what
-- left stock, once; and what comes back, by whichever of the two doors (the customer return or correction of the sale
-- movement, `stock_return_v1`; the void of the invoice, `void_invoice`), comes back once: never more than was sold.
-- The measure is one query: what the ledger says is still at the customer for an invoice (out to the customer less
-- back from the customer) is its quantity while it stands, nothing once it is voided, and never below zero. Each
-- scenario has an item of its own, ten received. The value the business states for its stock is what was received
-- less the cost frozen on what was sold, and a void restores it. Before 0975 the two doors did not count each other:
-- A, B, C and the measure failed (a mug returned and its invoice voided: 11 on hand of 10 received). Rolled back.
begin;
select plan(23);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.today() returns date language sql stable security definer as $f$
  select public.workspace_today(pg_temp.u(101))
$f$;
-- the answer of a statement run as a user, the deferred checks included, or ERR, its code and its detail
create or replace function pg_temp.run_as(n int, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '') || ' (' || sqlerrm || ')';
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
-- The reads are volatile on purpose: they must see what a command run earlier in the same statement wrote.
create or replace function pg_temp.on_hand(p_item int) returns text language sql as $f$
  select trim_scale(coalesce(sum(quantity), 0))::text from public.stock_balances
   where item_id = pg_temp.u(p_item) and location_id = pg_temp.loc('MAIN')
$f$;
-- what the ledger says is still at the customer for an invoice: out to the customer less back from the customer
create or replace function pg_temp.still_out(p_invoice uuid) returns text language sql as $f$
  select trim_scale(coalesce(sum(case when m.to_location_id = pg_temp.place('customer') then m.quantity else 0 end)
                           - sum(case when m.from_location_id = pg_temp.place('customer') then m.quantity else 0 end), 0))::text
    from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.invoice_id = p_invoice
$f$;
-- the invoices whose goods at the customer are not what the invoice says (in the item's inventory unit): its quantity
-- while it stands, nothing once voided
create or replace function pg_temp.disagreeing() returns text language sql as $f$
  select coalesce(string_agg(x.item || ' sold ' || trim_scale(x.sold)::text || case when x.voided then ' (voided)' else '' end
                             || ', at the customer ' || trim_scale(x.out_now)::text, '; ' order by x.item), '')
    from (select s.name as item, i.voided_at is not null as voided,
                 (select sum(public.stock_to_inventory((l #>> '{stock,item_id}')::uuid, l #>> '{commercial,unit,code}', (l #>> '{commercial,quantity}')::numeric))
                    from jsonb_array_elements(i.lines) l where l ->> 'supply' = 'goods') as sold,
                 pg_temp.still_out(i.id)::numeric as out_now
            from public.invoices i
            join public.services s on s.id = (select (l #>> '{stock,item_id}')::uuid from jsonb_array_elements(i.lines) l where l ->> 'supply' = 'goods' limit 1)
           where i.workspace_id = pg_temp.u(101)) x
   where x.out_now < 0 or x.out_now > x.sold or (x.voided and x.out_now <> 0)
$f$;
create or replace function pg_temp.goods(p_item int, p_qty text, p_unit text default 'piece', p_units jsonb default null) returns jsonb language sql as $f$
  select jsonb_strip_nulls(jsonb_build_object('description', 'Goods', 'quantity', p_qty, 'unit_price', '10', 'basis', 'net',
    'supply', 'goods', 'item_id', pg_temp.u(p_item), 'unit', jsonb_build_object('code', p_unit, 'label', p_unit, 'un_ece_code', 'C62'),
    'units', p_units))
$f$;
-- an invoice of one goods line, issued: its id, or what refused it
create or replace function pg_temp.invoice(p_req int, p_item int, p_qty text, p_unit text default 'piece', p_units jsonb default null) returns text language plpgsql as $f$
declare v_draft text; v_out text;
begin
  v_draft := pg_temp.run_as(1, format($q$select public.save_standalone_invoice_draft_v1(%L, null, null, %L, %L, %L, '', '', %L)::text$q$,
    pg_temp.u(101), pg_temp.u(203), pg_temp.today(), pg_temp.today() + 30, jsonb_build_array(pg_temp.goods(p_item, p_qty, p_unit, p_units))));
  if v_draft not like '{%' then return 'draft ' || v_draft; end if;
  v_out := pg_temp.run_as(1, format('select public.issue_standalone_invoice_v1(%L, %L, 1, %L)::text', pg_temp.u(101), v_draft::jsonb ->> 'draft_id', pg_temp.u(p_req)));
  if v_out not like '{%' then return 'issue ' || v_out; end if;
  return v_out::jsonb ->> 'invoice_id';
end $f$;
create or replace function pg_temp.inv(p_key text) returns uuid language sql stable as $f$
  select case when current_setting(p_key, true) ~ '^[0-9a-f-]{36}$' then current_setting(p_key, true)::uuid end
$f$;
-- a return of an invoice's first sale movement, by the stock door: `customer` (back to MAIN) or `correction`
create or replace function pg_temp.back(p_req int, p_kind text, p_invoice uuid, p_qty text, p_units jsonb default null) returns text language sql as $f$
  select left(pg_temp.run_as(1, format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    pg_temp.u(p_req + 10000), p_kind, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'return_line_id', pg_temp.u(p_req + 20000),
      'source_movement_id', (select m.id from public.stock_movements m where m.invoice_id = p_invoice and m.reason = 'sale' order by m.line_no, m.part limit 1),
      'quantity', p_qty, 'location', case when p_kind = 'customer' then pg_temp.loc('MAIN') end, 'units', p_units))))), 9)
$f$;
create or replace function pg_temp.void(p_invoice uuid) returns text language sql as $f$
  select pg_temp.run_as(1, format('select public.void_invoice(%L)::text', p_invoice))
$f$;
create or replace function pg_temp.stock_value() returns text language sql as $f$
  select pg_temp.run_as(1, format('select trim_scale((public.stock_value_at_v1(%L, null) ->> ''total_minor'')::numeric)::text', pg_temp.u(101)))
$f$;
-- the cost frozen on what an invoice sold, less what came back for it
create or replace function pg_temp.cost_of(p_invoice uuid) returns text language sql as $f$
  select trim_scale(round(coalesce(sum(case when m.to_location_id = pg_temp.place('customer') then m.quantity * m.unit_cost
                                            else -m.quantity * m.unit_cost end), 0)))::text
    from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.invoice_id = p_invoice
$f$;
-- what MAIN holds of an item, lot by lot
create or replace function pg_temp.lots(p_item int) returns text language sql as $f$
  select string_agg(l.lot_code || ':' || trim_scale(b.quantity)::text, ',' order by l.lot_code)
    from public.stock_balances b join public.stock_lots l on l.id = b.lot_id
   where b.item_id = pg_temp.u(p_item) and b.location_id = pg_temp.loc('MAIN')
$f$;
-- the pieces of an item that are at MAIN, and those at the customer
create or replace function pg_temp.pieces(p_item int) returns text language sql as $f$
  select count(*) filter (where location_id = pg_temp.loc('MAIN')) || ' at MAIN, '
         || count(*) filter (where location_id = pg_temp.place('customer')) || ' at the customer'
    from public.stock_tagged_units where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(p_item)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'once' || n || '@example.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Goods once', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"invoicing": true, "standaloneInvoicing": true, "services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockReturns": true}',
        '{"admin": ["manageStock"]}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode, vat_rate_id) values
  (pg_temp.u(401), pg_temp.u(101), 'Mugs', 1000, true, 'piece', 'none', true, 'none', null),
  (pg_temp.u(402), pg_temp.u(101), 'Cups', 1000, true, 'piece', 'none', true, 'none', null),
  (pg_temp.u(403), pg_temp.u(101), 'Plates', 1000, true, 'piece', 'none', true, 'none', null),
  (pg_temp.u(404), pg_temp.u(101), 'Honey', 800, true, 'piece', 'expiry', true, 'none', null),
  (pg_temp.u(405), pg_temp.u(101), 'Glasses', 1000, true, 'piece', 'none', true, 'none', null),
  (pg_temp.u(406), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit', null);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (pg_temp.u(101), pg_temp.u(405), 'box', 6, 1);

-- ── the stock: ten of each, the honey in two lots at 3.00 a jar ──
select ok(pg_temp.run_as(1, format('select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'')::text', pg_temp.u(101), pg_temp.u(901), jsonb_build_array(
  jsonb_build_object('item_id', pg_temp.u(401), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(402), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(403), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(405), 'quantity', '10', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(404), 'quantity', '5', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'new_lot', jsonb_build_object('code', 'LATE', 'expires_on', pg_temp.today() + 90, 'total_cost_minor', 1500)),
  jsonb_build_object('item_id', pg_temp.u(404), 'quantity', '5', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'new_lot', jsonb_build_object('code', 'EARLY', 'expires_on', pg_temp.today() + 10, 'total_cost_minor', 1500)),
  jsonb_build_object('item_id', pg_temp.u(406), 'quantity', '3', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'units', jsonb_build_array(jsonb_build_object('tag', 'E28068940000401561D6A001'), jsonb_build_object('tag', 'E28068940000401561D6A002'),
                                                jsonb_build_object('tag', 'E28068940000401561D6A003')),
                     'new_lot', jsonb_build_object('code', 'BASKETS', 'total_cost_minor', 9000))))) like '{%',
  'fixture: the goods are received at MAIN');

-- ── A: a part comes back by the stock door, then the invoice is voided ──
do $d$ begin perform set_config('i.a', pg_temp.invoice(701, 401, '4'), false); end $d$;
select is(pg_temp.on_hand(401) || '|' || pg_temp.still_out(pg_temp.inv('i.a')), '6|4',
  'A the four mugs of the invoice left stock, once: ' || current_setting('i.a'));
select is(pg_temp.back(702, 'customer', pg_temp.inv('i.a'), '1') || '|' || pg_temp.on_hand(401) || '|' || pg_temp.still_out(pg_temp.inv('i.a')),
  '{"kind": |7|3', 'A the customer brings one back: seven on hand, three at the customer');
select is(pg_temp.void(pg_temp.inv('i.a')) || '|' || pg_temp.on_hand(401) || '|' || pg_temp.still_out(pg_temp.inv('i.a')), '|10|0',
  'A the void brings back the three still at the customer, not the four sold');
select is(pg_temp.back(703, 'customer', pg_temp.inv('i.a'), '1') || '|' || pg_temp.on_hand(401), 'ERR DKG17|10',
  'A and nothing more comes back for a voided invoice');
select is(pg_temp.run_as(1, format('select public.stock_reversible_v1(%L, array[%L]::uuid[]) -> 0 ->> ''remaining''', pg_temp.u(101),
    (select m.id from public.stock_movements m where m.invoice_id = pg_temp.inv('i.a') and m.reason = 'sale'))), '0.000000',
  'A the read of what can still be reversed on that sale says nothing: the void is a return in the one record');

-- ── B: the invoice is voided, then a return is asked for by the stock door ──
do $d$ begin perform set_config('i.b', pg_temp.invoice(711, 402, '3'), false); end $d$;
select is(pg_temp.void(pg_temp.inv('i.b')) || '|' || pg_temp.on_hand(402) || '|' || pg_temp.still_out(pg_temp.inv('i.b')), '|10|0',
  'B a void brings back the three cups: ' || current_setting('i.b'));
select is(pg_temp.back(712, 'customer', pg_temp.inv('i.b'), '3') || '|' || pg_temp.on_hand(402) || '|' || pg_temp.still_out(pg_temp.inv('i.b')),
  'ERR DKG17|10|0', 'B and the same three do not come back a second time as a customer return');
select is(pg_temp.back(713, 'correction', pg_temp.inv('i.b'), '3') || '|' || pg_temp.on_hand(402), 'ERR DKG17|10',
  'B nor as a correction of the sale');

-- ── C: the sale is corrected in full by the stock door, then the invoice is voided ──
do $d$ begin perform set_config('i.c', pg_temp.invoice(721, 403, '2'), false); end $d$;
select is(pg_temp.back(722, 'correction', pg_temp.inv('i.c'), '2') || '|' || pg_temp.on_hand(403) || '|' || pg_temp.still_out(pg_temp.inv('i.c')),
  '{"kind": |10|0', 'C the sale of two plates is corrected in full: ' || current_setting('i.c'));
select is(pg_temp.void(pg_temp.inv('i.c')) || '|' || pg_temp.on_hand(403) || '|' || pg_temp.still_out(pg_temp.inv('i.c')), '|10|0',
  'C the void of that invoice has nothing left to bring back');

-- ── the value of the stock and the cost of what was sold ──
select is(pg_temp.stock_value(), '12000', 'V ten jars at 3.00 and three baskets at 30.00 are the value the business states');
do $d$ begin perform set_config('i.v', pg_temp.invoice(731, 404, '7'), false); end $d$;
select is((select string_agg(l.lot_code || ':' || trim_scale(m.quantity)::text, ',' order by m.line_no, m.part)
             from public.stock_movements m join public.stock_lots l on l.id = m.lot_id
            where m.invoice_id = pg_temp.inv('i.v') and m.reason = 'sale'), 'EARLY:5,LATE:2',
  'V seven jars leave from the earliest expiry first: ' || current_setting('i.v'));
select is(pg_temp.stock_value() || '+' || pg_temp.cost_of(pg_temp.inv('i.v')), '9900+2100',
  'V what is left and the cost frozen on what was sold are together what was received');
select is(pg_temp.void(pg_temp.inv('i.v')) || '|' || pg_temp.stock_value() || '+' || pg_temp.cost_of(pg_temp.inv('i.v')) || '|'
          || pg_temp.lots(404),
  '|12000+0|EARLY:5,LATE:5', 'V the void puts each jar back in its lot at its cost');

-- ── a line in another unit of the item ──
do $d$ begin perform set_config('i.u', pg_temp.invoice(741, 405, '1', 'box'), false); end $d$;
select is(pg_temp.on_hand(405) || '|' || pg_temp.still_out(pg_temp.inv('i.u')), '4|6',
  'U a box on the invoice leaves stock as its six glasses: ' || current_setting('i.u'));
select is((select trim_scale(m.entered_quantity)::text || ' ' || m.entered_unit || ' x ' || m.entered_factor_num || '/' || m.entered_factor_den
             from public.stock_movements m where m.invoice_id = pg_temp.inv('i.u') and m.reason = 'sale'), '1 box x 6/1',
  'U the movement keeps the invoice''s own quantity, unit and factor');
select is(pg_temp.void(pg_temp.inv('i.u')) || '|' || pg_temp.on_hand(405) || '|' || pg_temp.still_out(pg_temp.inv('i.u')), '|10|0',
  'U and its void brings the six back');

-- ── pieces: one of two comes back by the stock door, then the invoice is voided ──
do $d$ begin perform set_config('i.p', pg_temp.invoice(751, 406, '2', 'piece', jsonb_build_array(
  jsonb_build_object('tag', 'E28068940000401561D6A001'), jsonb_build_object('tag', 'E28068940000401561D6A002'))), false); end $d$;
select is(pg_temp.on_hand(406) || '|' || pg_temp.still_out(pg_temp.inv('i.p')) || '|' || pg_temp.pieces(406), '1|2|1 at MAIN, 2 at the customer',
  'P two named baskets are sold: ' || current_setting('i.p'));
select is(pg_temp.back(752, 'customer', pg_temp.inv('i.p'), '1', jsonb_build_array(jsonb_build_object('tag', 'E28068940000401561D6A001')))
          || '|' || pg_temp.on_hand(406) || '|' || pg_temp.pieces(406), '{"kind": |2|2 at MAIN, 1 at the customer',
  'P the customer brings one of them back');
select is(pg_temp.void(pg_temp.inv('i.p')) || '|' || pg_temp.on_hand(406) || '|' || pg_temp.still_out(pg_temp.inv('i.p')) || '|' || pg_temp.pieces(406),
  '|3|0|3 at MAIN, 0 at the customer', 'P the void brings back the other one, and only that one');

-- ── the measure over every invoice of the business ──
select is((select count(*)::int from public.invoices where workspace_id = pg_temp.u(101)), 6, 'six invoices were issued');
select is(pg_temp.disagreeing(), '', 'for every invoice the goods at the customer are its quantity while it stands and nothing once voided');

select * from finish();
rollback;
