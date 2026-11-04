-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3294 / 0675: items on purchase lines and the item figures, proven from a
-- hand-built March 2025 (Paris, EUR), the bills filed and decided through
-- the purchase RPCs. Bills (dated, supplier, item, units, cost; no tax):
--   B1 10 Feb Alpha coffee 100 units 20.00  (before the period: it only
--      weighs in the average)
--   B2  5 Mar Alpha coffee 100 units 30.00
--   B3 12 Mar Beta  coffee  50 units 20.00
--   B4 15 Mar Beta  paper   10 reams 40.00
--   B5  2 Apr Alpha coffee 100 units 100.00 (after the period: left out)
-- Sold in March (confirmed consumptions): coffee 60 units for 120.00 with
-- VAT 20 % (100.00 net), paper 5 units for 30.00, snacks 3 units for 6.00
-- (never bought: no cost).
-- Unit cost, average: coffee (20+30+20)/250 = 0.28, paper 4.00; last: coffee
-- 0.40 (B3), paper 4.00. Margins (average): coffee 100.00 - 16.80 = 83.20,
-- paper 30.00 - 20.00 = 10.00: 93.20, snacks apart; last: 86.00. By
-- supplier against the sale prices (coffee 1.666..., paper 6.00): Alpha
-- 166.67 - 30.00 = 136.67, Beta 83.33 - 20.00 + 60.00 - 40.00 = 83.33.
begin;
select plan(22);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000032944'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@items.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000032944b1','Items','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032944a1','dev',
  '{"moneyTab":true,"services":true,"purchases":true,"purchaseAnalytics":true,"supplyExpenses":true,"inputVat":true}'),
 ('00000000-0000-4000-8000-0000032944b2','Other','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032944a1','dev','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000032944c1','00000000-0000-4000-8000-0000032944b1','00000000-0000-4000-8000-0000032944a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000032944c2','00000000-0000-4000-8000-0000032944b1','00000000-0000-4000-8000-0000032944a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000032944c3','00000000-0000-4000-8000-0000032944b1','00000000-0000-4000-8000-0000032944a3',false,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000032944f1','00000000-0000-4000-8000-0000032944b1','1','Alpha','active'),
 ('00000000-0000-4000-8000-0000032944f2','00000000-0000-4000-8000-0000032944b1','2','Beta','active');
insert into public.services (id, workspace_id, name, price_cents, active, stock) values
 ('00000000-0000-4000-8000-0000032944d1','00000000-0000-4000-8000-0000032944b1','Coffee capsules',200,true,500),
 ('00000000-0000-4000-8000-0000032944d2','00000000-0000-4000-8000-0000032944b1','Printer paper',600,true,20),
 ('00000000-0000-4000-8000-0000032944d3','00000000-0000-4000-8000-0000032944b1','Snacks',200,true,null),
 ('00000000-0000-4000-8000-0000032944d9','00000000-0000-4000-8000-0000032944b2','Elsewhere',100,true,null);

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000032944' || p)::uuid;
$$;
create function pg_temp.as_user(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.draft(p_supplier text, p_dated date, p_item text, p_qty numeric, p_cents int,
                              p_unit text default 'unit') returns uuid language sql as $$
  select (pg_temp.as_user('a1', format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', pg_temp.u(p_supplier),
      'original_reference', p_item || p_cents, 'original_date', p_dated, 'received_on', p_dated,
      'payer_kind', 'unpaid',
      'lines', jsonb_build_array(jsonb_build_object('description', p_item, 'gross_cents', p_cents,
        'net_cents', p_cents, 'tax_cents', 0, 'service_id', pg_temp.u(p_item), 'quantity', p_qty,
        'unit', p_unit)))::text)) ->> 'purchase_id')::uuid;
$$;
-- Drafted by the owner, submitted, approved by the second admin.
create function pg_temp.bill(p_supplier text, p_dated date, p_item text, p_qty numeric, p_cents int,
                             p_unit text default 'unit') returns uuid language plpgsql as $$
declare v_id uuid; v_rev int;
begin
  v_id := pg_temp.draft(p_supplier, p_dated, p_item, p_qty, p_cents, p_unit);
  perform pg_temp.as_user('a1', format('select public.submit_purchase_v1(%L, %L, 1, %L)',
    pg_temp.u('b1'), v_id, gen_random_uuid()));
  select revision into v_rev from public.purchase_documents where id = v_id;
  perform pg_temp.as_user('a3', format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)',
    pg_temp.u('b1'), v_id, v_rev, '', gen_random_uuid()));
  return v_id;
end;
$$;
-- A confirmed consumption of an item, billed in March.
create function pg_temp.sold(p_item text, p_units int, p_cents int, p_vat numeric,
                             p_period text default '2025-03') returns void language plpgsql as $$
declare v_e uuid;
begin
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status,
                             decided_at, created_at)
  values (pg_temp.u('b1'), 'service_charge', 'submitted', pg_temp.u('c1'), pg_temp.u('c2'),
          jsonb_build_object('service_id', pg_temp.u(p_item), 'quantity', p_units, 'amount_cents', p_cents),
          'confirmed', '2025-03-20 10:00+01', '2025-03-20 09:00+01')
  returning id into v_e;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period,
                                     event_id, vat_percent)
  values (pg_temp.u('b1'), pg_temp.u('c2'), 'charge', 'service', p_cents, 'item', p_period, v_e, p_vat);
end;
$$;
create function pg_temp.kpi(p_user text, p_from text default '2025-03', p_to text default '2025-03')
returns jsonb language sql as $$
  select pg_temp.as_user(p_user, format('select public.kpi_item_margins(%L, %L, %L)', pg_temp.u('b1'), p_from, p_to));
$$;
create function pg_temp.err(p_user text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.as_user(p_user, p_sql);
  return '';
exception when others then
  return sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('t.b1', pg_temp.bill('f1', '2025-02-10', 'd1', 100, 2000)::text, true);
select set_config('t.b2', pg_temp.bill('f1', '2025-03-05', 'd1', 100, 3000)::text, true);
select set_config('t.b3', pg_temp.bill('f2', '2025-03-12', 'd1', 50, 2000)::text, true);
select set_config('t.b4', pg_temp.bill('f2', '2025-03-15', 'd2', 10, 4000, 'ream')::text, true);
select set_config('t.b5', pg_temp.bill('f1', '2025-04-02', 'd1', 100, 10000)::text, true);

-- ── the item on the line ──────────────────────────────────────────────
reset role;
select is((select (service_id, quantity, unit) from public.purchase_lines where purchase_id = current_setting('t.b4')::uuid),
  (pg_temp.u('d2'), 10::numeric, 'ream'::text), 'a bill line keeps its item, its quantity and its unit');
set local role authenticated;
select is(pg_temp.as_user('a1', format('select public.purchase_detail_v1(%L, %L)', pg_temp.u('b1'), current_setting('t.b4')))
            -> 'lines' -> 0 ->> 'service_id', pg_temp.u('d2')::text, 'the purchase detail names the item');
select ok(pg_temp.err('a1', format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('kind', 'bill', 'payer_kind', 'unpaid',
      'lines', jsonb_build_array(jsonb_build_object('gross_cents', 100, 'service_id', pg_temp.u('d9'), 'quantity', 1)))))
  like '%unknown item%', 'another space''s item is refused');
select ok(pg_temp.err('a1', format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('kind', 'bill', 'payer_kind', 'unpaid',
      'lines', jsonb_build_array(jsonb_build_object('gross_cents', 100, 'service_id', pg_temp.u('d1'), 'quantity', 0)))))
  like '%quantity above zero%', 'an item bought in no quantity is refused');

reset role;
select pg_temp.sold('d1', 40, 8000, 20);
select pg_temp.sold('d1', 20, 4000, 20);
select pg_temp.sold('d2', 5, 3000, 0);
select pg_temp.sold('d3', 3, 600, 0);
set local role authenticated;
select set_config('t.avg', pg_temp.kpi('a1')::text, true);

-- ── the figures ───────────────────────────────────────────────────────
select is(current_setting('t.avg')::jsonb -> 'unit_prices' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('item_id', pg_temp.u('d2'), 'item', 'Printer paper', 'supplier_id', pg_temp.u('f2'), 'supplier', 'Beta',
                       'units', 10, 'cost_minor', '4000', 'unit_price_minor', '400'),
    jsonb_build_object('item_id', pg_temp.u('d1'), 'item', 'Coffee capsules', 'supplier_id', pg_temp.u('f1'), 'supplier', 'Alpha',
                       'units', 100, 'cost_minor', '3000', 'unit_price_minor', '30'),
    jsonb_build_object('item_id', pg_temp.u('d1'), 'item', 'Coffee capsules', 'supplier_id', pg_temp.u('f2'), 'supplier', 'Beta',
                       'units', 50, 'cost_minor', '2000', 'unit_price_minor', '40')),
  'the unit price of each item by supplier in March; February and April are left out');
select is((current_setting('t.avg')::jsonb -> 'unit_prices' ->> 'cost_minor', current_setting('t.avg')::jsonb -> 'unit_prices' ->> 'items'),
  ('9000'::text, '2'::text), 'what the item lines of March cost');
select is(current_setting('t.avg')::jsonb ->> 'cost_method', 'average', 'the average by default');
select is(current_setting('t.avg')::jsonb -> 'products' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('item_id', pg_temp.u('d1'), 'item', 'Coffee capsules', 'units', 60, 'revenue_minor', '10000',
                       'unit_cost_minor', '28', 'cost_minor', '1680', 'margin_minor', '8320'),
    jsonb_build_object('item_id', pg_temp.u('d2'), 'item', 'Printer paper', 'units', 5, 'revenue_minor', '3000',
                       'unit_cost_minor', '400', 'cost_minor', '2000', 'margin_minor', '1000'),
    jsonb_build_object('item_id', pg_temp.u('d3'), 'item', 'Snacks', 'units', 3, 'revenue_minor', '600',
                       'unit_cost_minor', null, 'cost_minor', null, 'margin_minor', null)),
  'each product sold: net revenue, the average unit cost (February weighs in), the margin; one never bought has none');
select is((current_setting('t.avg')::jsonb -> 'products' ->> 'margin_minor', current_setting('t.avg')::jsonb -> 'products' ->> 'uncosted',
           current_setting('t.avg')::jsonb -> 'products' ->> 'revenue_minor',
           current_setting('t.avg')::jsonb -> 'products' ->> 'costed_revenue_minor'),
  ('9320'::text, '1'::text, '13600'::text, '13000'::text),
  'mixed: the margin over the costed products beside their own revenue, the uncosted one counted apart');
select is(current_setting('t.avg')::jsonb -> 'vendors' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('supplier_id', pg_temp.u('f2'), 'supplier', 'Beta', 'items', 2, 'compared_items', 1, 'units', 60,
                       'cost_minor', '6000', 'premium_minor', '500'),
    jsonb_build_object('supplier_id', pg_temp.u('f1'), 'supplier', 'Alpha', 'items', 1, 'compared_items', 1, 'units', 100,
                       'cost_minor', '3000', 'premium_minor', '0')),
  'two suppliers of coffee: Beta''s 50 capsules cost 10 above Alpha''s lowest price; paper has no second offer');
select ok(current_setting('t.avg')::jsonb -> 'vendors' -> 'margin_minor' = 'null'::jsonb
          and current_setting('t.avg')::jsonb -> 'reasons' ? 'no_consumption_link',
  '150 capsules bought against 60 sold: no supplier margin is made up from units nothing consumed');
select is((current_setting('t.avg')::jsonb -> 'quality', current_setting('t.avg')::jsonb -> 'reasons'),
  ('["partial"]'::jsonb, '["no_consumption_link", "uncosted_items"]'::jsonb),
  'a past month in one currency is partial only by its uncosted product');

reset role;
insert into public.setting_values (scope, workspace_id, key, value) values
 ('workspace', pg_temp.u('b1'), 'purchase.item_cost_method', '"last"');
set local role authenticated;
select set_config('t.last', pg_temp.kpi('a1')::text, true);
select is((current_setting('t.last')::jsonb ->> 'cost_method',
           current_setting('t.last')::jsonb -> 'products' -> 'rows' -> 0 ->> 'unit_cost_minor',
           current_setting('t.last')::jsonb -> 'products' ->> 'margin_minor'),
  ('last'::text, '40'::text, '8600'::text), 'with the last purchase, coffee costs what Beta charged on 12 March');

-- A February supply named only by its text, before the months: the unit
-- cost of coffee reads February, so the cost figures are partial though no
-- line of March is unresolved.
reset role;
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id,
                                       payer_kind, original_date, received_on)
values (pg_temp.u('e7'), pg_temp.u('b1'), 'bill', 'draft', 'EUR', pg_temp.u('f1'), pg_temp.u('c1'),
        'unpaid', '2025-02-20', '2025-02-20');
insert into public.purchase_lines (workspace_id, purchase_id, line_no, description, gross_cents, net_cents, tax_cents,
                                   quantity, supply)
values (pg_temp.u('b1'), pg_temp.u('e7'), 1, 'capsules', 50, 50, 0, 1, '{"name": "Coffee capsules", "quantity": "5"}');
update public.purchase_documents set state = 'approved', decided_by_member_id = pg_temp.u('c3'), decided_at = now()
 where id = pg_temp.u('e7');
set local role authenticated;
select is((select jsonb_build_array(k -> 'unit_prices' ->> 'unresolved_lines', k -> 'products' ->> 'unresolved_cost_lines',
                                    k -> 'reasons' ? 'unresolved_items', k -> 'quality' ? 'partial',
                                    k -> 'products' -> 'rows' -> 0 ->> 'unit_cost_minor')
             from pg_temp.kpi('a1') k),
  jsonb_build_array('0', '1', true, true, '40'),
  'an unresolved purchase before the months still makes the cost figures partial; the known prices stay');

-- A supply named only by its text is never matched by name: one name with a
-- single namesake stays unresolved, one shared by two items is ambiguous.
reset role;
insert into public.services (id, workspace_id, name, price_cents, active, stock) values
 (pg_temp.u('d4'), pg_temp.u('b1'), 'Toner', 900, true, null),
 (pg_temp.u('d5'), pg_temp.u('b1'), 'toner ', 950, true, null);
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id,
                                       payer_kind, original_date, received_on)
values (pg_temp.u('e8'), pg_temp.u('b1'), 'bill', 'draft', 'EUR', pg_temp.u('f1'), pg_temp.u('c1'),
        'unpaid', '2025-03-09', '2025-03-09');
insert into public.purchase_lines (workspace_id, purchase_id, line_no, description, gross_cents, net_cents, tax_cents,
                                   quantity, supply)
values (pg_temp.u('b1'), pg_temp.u('e8'), 1, 'toner', 1800, 1800, 0, 1, '{"name": "Toner", "quantity": "2"}'),
       (pg_temp.u('b1'), pg_temp.u('e8'), 2, 'capsules', 100, 100, 0, 1, '{"name": "Coffee capsules", "quantity": "10"}');
update public.purchase_documents set state = 'approved', decided_by_member_id = pg_temp.u('c3'), decided_at = now()
 where id = pg_temp.u('e8');
select pg_temp.sold('d3', 3, 600, 0, '2025-05');
set local role authenticated;
select set_config('t.names', pg_temp.kpi('a1')::text, true);
select is((current_setting('t.names')::jsonb -> 'unit_prices' ->> 'unresolved_lines',
           current_setting('t.names')::jsonb -> 'unit_prices' ->> 'ambiguous_lines',
           current_setting('t.names')::jsonb -> 'reasons' ? 'unresolved_items'),
  ('1'::text, '1'::text, true), 'supplies named only by text are counted apart: one unresolved, one ambiguous');
select is(current_setting('t.names')::jsonb -> 'unit_prices' -> 'rows', current_setting('t.avg')::jsonb -> 'unit_prices' -> 'rows',
  '... and no unit price takes them in by their name');
select is((select jsonb_build_array(k -> 'products' ->> 'uncosted', k -> 'products' ->> 'revenue_minor',
                                    k -> 'products' -> 'cost_minor', k -> 'products' -> 'margin_minor')
             from pg_temp.kpi('a1', '2025-05', '2025-05') k),
  jsonb_build_array('1', '600', null, null), 'every product sold uncosted: the cost and the margin are unknown, never 0');

select ok(pg_temp.err('a2', format('select public.kpi_item_margins(%L, %L, %L)', pg_temp.u('b1'), '2025-03', '2025-03'))
  like '%not allowed%', 'a plain member reads no item figure');
select ok(pg_temp.err('a1', format('select public.kpi_item_margins(%L, %L, %L)', pg_temp.u('b1'), '2025-03', '2027-03'))
  like '%at most 24 months%', 'more than 24 months is refused');

-- A dollar bill of March, approved with its recorded rate.
reset role;
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id,
                                       payer_kind, original_date, received_on)
values (pg_temp.u('e9'), pg_temp.u('b1'), 'bill', 'draft', 'USD', pg_temp.u('f1'), pg_temp.u('c1'),
        'unpaid', '2025-03-08', '2025-03-08');
insert into public.purchase_lines (workspace_id, purchase_id, line_no, description, gross_cents, net_cents, tax_cents,
                                   quantity, service_id)
values (pg_temp.u('b1'), pg_temp.u('e9'), 1, 'coffee', 700, 700, 0, 10, pg_temp.u('d1'));
insert into public.document_exchange_rates (workspace_id, document_kind, document_id, currency, functional_currency, rate, rate_date, source)
values (pg_temp.u('b1'), 'purchase', pg_temp.u('e9'), 'USD', 'EUR', 0.92, '2025-03-08', 'bank');
update public.purchase_documents set state = 'approved', decided_by_member_id = pg_temp.u('c3'), decided_at = now()
 where id = pg_temp.u('e9');
set local role authenticated;
select set_config('t.mixed', pg_temp.kpi('a1')::text, true);
select ok(current_setting('t.mixed')::jsonb -> 'reasons' ? 'currency_mix'
          and current_setting('t.mixed')::jsonb -> 'products' ->> 'margin_minor' is null
          and current_setting('t.mixed')::jsonb -> 'unit_prices' ->> 'cost_minor' is null,
  'a dollar bill leaves every amount unknown, never summed');
select is(current_setting('t.mixed')::jsonb -> 'products' ->> 'items', '3', '... while the counts stay');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchaseAnalytics": false}' where id = pg_temp.u('b1');
set local role authenticated;
select ok(pg_temp.err('a1', format('select public.kpi_item_margins(%L, %L, %L)', pg_temp.u('b1'), '2025-03', '2025-03'))
  like '%not enabled%', 'with the purchase figures off, nothing is read');

select * from finish();
rollback;
