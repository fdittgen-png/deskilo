-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4433 (0939, 0940): goods sold on a standalone invoice leave stock with a sale movement linked to the invoice and its
-- line, through the one stock path, in the issue's own transaction: from the place the setting names, the lot the stock
-- path chooses, the pieces the line names. A replay moves nothing twice; a shortage refuses the issue (number included)
-- unless the business allows less than nothing; a void takes the goods back. Rolled back.
begin;
select plan(28);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004433' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.today() returns date language sql stable security definer as $$
  select public.workspace_today(pg_temp.u(101))
$$;
-- the answer of a statement run as a user, or ERR, its code and its detail
create function pg_temp.run_as(n int, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
create function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create function pg_temp.on_hand(p_item int, p_code text default 'MAIN') returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = pg_temp.loc(p_code)
$f$;
create function pg_temp.goods(p_item int, p_qty text, p_extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('description', 'Goods', 'quantity', p_qty, 'unit_price', '10', 'basis', 'net',
    'supply', 'goods', 'item_id', pg_temp.u(p_item), 'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62'))
    || p_extra
$$;
create function pg_temp.save(p_lines jsonb, p_subject int default 203) returns uuid language plpgsql as $f$
begin
  return (pg_temp.run_as(1, format($$select public.save_standalone_invoice_draft_v1(%L, null, null, %L, %L, %L, '', '', %L)::text$$,
    pg_temp.u(101), pg_temp.u(p_subject), pg_temp.today(), pg_temp.today() + 30, p_lines))::jsonb ->> 'draft_id')::uuid;
end $f$;
create function pg_temp.issue(p_draft uuid, p_req int) returns text language sql as $$
  select pg_temp.run_as(1, format('select public.issue_standalone_invoice_v1(%L, %L, 1, %L)::text', pg_temp.u(101), p_draft, pg_temp.u(p_req)))
$$;
create function pg_temp.preview(p_draft uuid) returns jsonb language sql as $$
  select pg_temp.run_as(1, format('select public.preview_standalone_invoice_v1(%L, %L, 1)::text', pg_temp.u(101), p_draft))::jsonb
$$;
create function pg_temp.mv(p_req int, p_lines jsonb, p_reason text) returns text language sql as $$
  select pg_temp.run_as(1, format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$$;
create function pg_temp.invoices() returns int language sql stable as $$
  select count(*)::int from public.invoices where workspace_id = pg_temp.u(101)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'goods' || n || '@example.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Goods 4433', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"invoicing": true, "standaloneInvoicing": true, "services": true, "stockManagement": true, "stockLots": true, "stockTags": true}',
        '{"admin": ["manageStock"]}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, false, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
update public.profiles set display_name = 'Jan Berger', company = 'Berger GmbH', street = 'Hauptstr. 1',
       postal_code = '10115', city = 'Berlin', country_code = 'DE', vat_id = 'DE123456789'
 where id = pg_temp.u(4);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01'),
       (pg_temp.u(302), pg_temp.u(101), 'Reduced 5.5 %', 5.5, 'S', false, true, '2000-01-01');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode, vat_rate_id) values
  (pg_temp.u(401), pg_temp.u(101), 'Mugs', 1000, true, 'piece', 'none', true, 'none', pg_temp.u(302)),
  (pg_temp.u(402), pg_temp.u(101), 'Honey', 800, true, 'piece', 'expiry', true, 'none', null),
  (pg_temp.u(403), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit', null),
  (pg_temp.u(404), pg_temp.u(101), 'Advice', 5000, true, 'piece', 'none', false, 'none', null);

-- ── the stock: 5 mugs, honey in two lots (the later expiry received first), one basket piece ──
select ok(pg_temp.mv(901, jsonb_build_array(
  jsonb_build_object('item_id', pg_temp.u(401), 'quantity', '5', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(402), 'quantity', '3', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'new_lot', jsonb_build_object('code', 'LATE', 'expires_on', pg_temp.today() + 90, 'total_cost_minor', 900)),
  jsonb_build_object('item_id', pg_temp.u(402), 'quantity', '3', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'new_lot', jsonb_build_object('code', 'EARLY', 'expires_on', pg_temp.today() + 10, 'total_cost_minor', 900)),
  jsonb_build_object('item_id', pg_temp.u(403), 'quantity', '1', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'units', jsonb_build_array(jsonb_build_object('tag', 'E28068940000401561D68F01')),
                     'new_lot', jsonb_build_object('total_cost_minor', 3000))), 'receipt') like '{%', 'fixture: the goods are received at MAIN');

-- ── a goods line issues, and leaves stock linked to the invoice and its line ──
select set_config('d.a', pg_temp.save(jsonb_build_array(pg_temp.goods(401, '2')))::text, false);
select is(pg_temp.preview(current_setting('d.a')::uuid) -> 'missing', '[]'::jsonb, 'the preview of a goods line finds nothing missing');
select is((select count(*)::int from public.stock_movements where workspace_id = pg_temp.u(101) and invoice_id is not null), 0,
  'and moves nothing: its posting is rolled back');
select set_config('i.a', pg_temp.issue(current_setting('d.a')::uuid, 701), false);
select ok(current_setting('i.a') like '{%', 'a standalone invoice with a goods line is issued: ' || current_setting('i.a'));
select set_config('i.a', current_setting('i.a')::jsonb ->> 'invoice_id', false);
select is((select l ->> 'kind' || '|' || (l ->> 'supply') || '|' || (l #>> '{commercial,supply}') || '|' || (l #>> '{stock,item_id}')
             from public.invoices i, jsonb_array_elements(i.lines) l where i.id = current_setting('i.a')::uuid),
  'goods|goods|goods|' || pg_temp.u(401), 'the frozen line is goods and names the item it sells');
select is((select (vat_totals -> 0 ->> 'percent')::numeric from public.invoices where id = current_setting('i.a')::uuid), 5.5,
  'its tax is the item''s own rate');
select is((select count(*)::int || '|' || min(quantity)::text || '|' || min(from_location_id::text) || '|' || min(to_location_id::text)
             from public.stock_movements where invoice_id = current_setting('i.a')::uuid and reason = 'sale'),
  '1|2.000000|' || pg_temp.loc('MAIN') || '|' || pg_temp.place('customer'), 'one sale of 2 from MAIN to the customer');
select is((select m.invoice_line_id::text from public.stock_movements m where m.invoice_id = current_setting('i.a')::uuid),
  (select l #>> '{commercial,line_id}' from public.invoices i, jsonb_array_elements(i.lines) l where i.id = current_setting('i.a')::uuid),
  'the sale names the invoice line');
select is(pg_temp.on_hand(401), 3::numeric, 'MAIN holds 3 mugs');
select is(pg_temp.issue(current_setting('d.a')::uuid, 701)::jsonb ->> 'replayed', 'true', 'the same request replays');
select is((select count(*)::int from public.stock_movements where invoice_id = current_setting('i.a')::uuid), 1,
  'and moves nothing twice');

-- ── not enough on hand ──
select set_config('d.b', pg_temp.save(jsonb_build_array(pg_temp.goods(401, '9')))::text, false);
select is(pg_temp.preview(current_setting('d.b')::uuid) -> 'missing', '["line_1_stock_not_enough"]'::jsonb,
  'the preview tells a shortage');
select set_config('t.n', pg_temp.invoices()::text, false);
select is(pg_temp.issue(current_setting('d.b')::uuid, 702), 'ERR DKI01 line_1_stock_not_enough', 'the issue is refused');
select is(pg_temp.invoices()::text || '|' || pg_temp.on_hand(401)::text, current_setting('t.n') || '|3.000000',
  'with no invoice and no movement');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.allow_negative', 'true'::jsonb);
select ok(pg_temp.issue(current_setting('d.b')::uuid, 703) like '{%', 'where the business allows less than nothing, it is issued');
select is(pg_temp.on_hand(401), -6::numeric, 'and MAIN shows minus 6');
delete from public.setting_values where key = 'stock.allow_negative' and workspace_id = pg_temp.u(101);

-- ── the lot is the stock path's choice: the earliest expiry first ──
select set_config('d.c', pg_temp.save(jsonb_build_array(pg_temp.goods(402, '4')))::text, false);
select set_config('i.c', pg_temp.issue(current_setting('d.c')::uuid, 704)::jsonb ->> 'invoice_id', false);
select is((select string_agg(l.lot_code || ':' || trim_scale(m.quantity)::text, ',' order by m.line_no)
             from public.stock_movements m join public.stock_lots l on l.id = m.lot_id
            where m.invoice_id = current_setting('i.c')::uuid),
  'EARLY:3,LATE:1', 'a lot-tracked item leaves from the earliest expiry first, a part per lot, each recorded');

-- ── a piece named on the line ──
select set_config('d.e', pg_temp.save(jsonb_build_array(pg_temp.goods(403, '1')))::text, false);
select is(pg_temp.issue(current_setting('d.e')::uuid, 705), 'ERR DKI01 line_1_stock_pieces',
  'an item tracked piece by piece names its pieces');
select set_config('d.f', pg_temp.save(jsonb_build_array(pg_temp.goods(403, '1',
  jsonb_build_object('units', jsonb_build_array(jsonb_build_object('tag', 'e2806894-0000-4015-61d6-8f01'))))))::text, false);
select set_config('i.f', pg_temp.issue(current_setting('d.f')::uuid, 706)::jsonb ->> 'invoice_id', false);
select is((select u.state || '|' || (u.location_id = pg_temp.place('customer'))::text from public.stock_tagged_units u
            where u.item_id = pg_temp.u(403)), 'sold|true', 'the named piece is sold, at the customer');
select is((select count(*)::int from public.stock_movement_units mu join public.stock_movements m on m.id = mu.movement_id
            where m.invoice_id = current_setting('i.f')::uuid), 1, 'and the sale records it');

-- ── what is refused before a number ──
select is(pg_temp.preview(pg_temp.save(jsonb_build_array(pg_temp.goods(404, '1')))) -> 'missing', '["line_1_item"]'::jsonb,
  'an item not kept in stock is no goods line');
select is(pg_temp.preview(pg_temp.save(jsonb_build_array(pg_temp.goods(401, '1')), 204)) -> 'missing', '["line_1_goods_cross_border"]'::jsonb,
  'goods to a buyer in another country are not read as a domestic sale');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.invoice_sale_place', '"NOWHERE"'::jsonb);
select is(pg_temp.preview(pg_temp.save(jsonb_build_array(pg_temp.goods(401, '1')))) -> 'missing', '["stock_sale_place"]'::jsonb,
  'a sale place that is no place of the business is named');
delete from public.setting_values where key = 'stock.invoice_sale_place' and workspace_id = pg_temp.u(101);
select ok(pg_temp.mv(910, jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(401), 'quantity', '1', 'from', pg_temp.loc('MAIN'),
  'to', pg_temp.place('customer'), 'invoice_line_id', gen_random_uuid())), 'sale') like 'ERR DKG11%malformed%', 'the generic door never names an invoice line');

-- ── a void takes the goods back ──
select is(pg_temp.run_as(1, format('select public.void_invoice(%L)::text', current_setting('i.f'))), '', 'the invoice of the piece is voided');
select is((select m.reason || '|' || (m.from_location_id = pg_temp.place('customer'))::text || '|' || (m.to_location_id = pg_temp.loc('MAIN'))::text
                  || '|' || (m.invoice_line_id is not null)::text
             from public.stock_movements m where m.invoice_id = current_setting('i.f')::uuid and m.reason = 'return_in'),
  'return_in|true|true|true', 'its goods come back from the customer to MAIN, linked to the invoice and its line');
select is((select u.state || '|' || (u.location_id = pg_temp.loc('MAIN'))::text from public.stock_tagged_units u
            where u.item_id = pg_temp.u(403)), 'in_stock|true', 'the piece is in stock again');
select set_config('t.void', pg_temp.run_as(1, format('select public.void_invoice(%L)::text', current_setting('i.a'))), false);
select is(current_setting('t.void') || '|' || pg_temp.on_hand(401)::text, '|-4.000000', 'the mugs of the first invoice come back too');

select * from finish();
rollback;
