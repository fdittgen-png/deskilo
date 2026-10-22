-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2582 C2 / 0529: the cost side of the analytics page, worked by hand from
-- the issue's own figures (in cents): sales net 20.00 (an invoice of 24.00 at
-- 20 %); cleaning net 1.00 + 0.20 deductible tax and rent 10.00, both
-- operating; a machine net 12.00 + 2.40 deductible tax, capitalised; a line
-- nobody classified. Operating costs 11.00, invoiced less them 9.00 (never a
-- result), capital additions 12.00; the unclassified line is counted, not
-- costed. Without the equipment register the additions are unavailable.
begin;
select plan(8);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025820'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@costs.test','',now(),now(),now()
  from unnest(array['a1','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000025820b1','Costs','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025820a1','dev',
  '{"moneyTab":true,"invoicing":true,"purchases":true,"purchaseAnalytics":true,"assetRegister":true,"supplyExpenses":true,"inputVat":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000025820c1','00000000-0000-4000-8000-0000025820b1','00000000-0000-4000-8000-0000025820a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000025820c3','00000000-0000-4000-8000-0000025820b1','00000000-0000-4000-8000-0000025820a3',false,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000025820f1','00000000-0000-4000-8000-0000025820b1','1','Fournitures SA','active');
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, period, vat_totals) values
 ('00000000-0000-4000-8000-0000025820e1','00000000-0000-4000-8000-0000025820b1','00000000-0000-4000-8000-0000025820c1',
  '00000000-0000-4000-8000-0000025820c1','INV-1','T',
  '[{"kind":"subscription","label":"Desk","amount_cents":2400,"vat_percent":20}]', 2400,'EUR','Ana','w','Flo','sig',
  '2026-03-05 10:00+00','2026-03',
  '[{"percent":20,"category":"S","gross_cents":2400,"net_cents":2000,"vat_cents":400}]');

create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000025820' || p)::uuid;
$$;
create function pg_temp.line(p_what text, p_net int, p_tax int, p_kind text) returns jsonb language sql as $$
  select jsonb_build_object('description', p_what, 'gross_cents', p_net + p_tax, 'net_cents', p_net,
    'tax_cents', p_tax, 'tax_rate_percent', case when p_tax = 0 then 0 else 20 end,
    'recoverable_tax_cents', p_tax, 'nonrecoverable_tax_cents', 0, 'recognition_kind', p_kind);
$$;
create function pg_temp.kpi(p_from text, p_to text) returns jsonb language sql as $$
  select pg_temp.call(pg_temp.u('a1'),
    format('select public.kpi_costs_summary(%L, %L, %L)', '00000000-0000-4000-8000-0000025820b1', p_from, p_to));
$$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000025820a1","role":"authenticated"}',true);
set local role authenticated;

-- One bill of 10 March: cleaning, rent, the machine and a line nobody
-- classified, approved by a second admin.
select set_config('t.bill', pg_temp.call(pg_temp.u('a1'),
  format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', '00000000-0000-4000-8000-0000025820b1',
    gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000025820f1',
      'original_reference', 'F-1', 'original_date', '2026-03-10', 'due_on', '2026-04-30', 'payer_kind', 'unpaid',
      'lines', jsonb_build_array(
        pg_temp.line('Cleaning', 100, 20, 'operating'),
        pg_temp.line('Rent', 1000, 0, 'operating'),
        pg_temp.line('Machine', 1200, 240, 'asset'),
        pg_temp.line('Sundries', 50, 0, 'unresolved')))::text)) ->> 'purchase_id', true);
select pg_temp.call(pg_temp.u('a1'),
  format('select public.submit_purchase_v1(%L, %L, 1, %L)', '00000000-0000-4000-8000-0000025820b1',
    current_setting('t.bill'), gen_random_uuid()));
select pg_temp.call(pg_temp.u('a3'),
  format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)', '00000000-0000-4000-8000-0000025820b1',
    current_setting('t.bill'), (select revision from public.purchase_documents where id = current_setting('t.bill')::uuid),
    '', gen_random_uuid()));
-- The machine is registered and capitalised.
select set_config('t.asset', pg_temp.call(pg_temp.u('a1'),
  format('select public.register_asset_candidate_v1(%L, %L, '''', %L)', '00000000-0000-4000-8000-0000025820b1',
    (select id from public.purchase_lines where purchase_id = current_setting('t.bill')::uuid and line_no = 3),
    gen_random_uuid())) ->> 'id', true);
select pg_temp.call(pg_temp.u('a1'),
  format('select public.decide_asset_v1(%L, %L, %s, %L, %L, %L, null, null, '''', %L)',
    '00000000-0000-4000-8000-0000025820b1', current_setting('t.asset'),
    (select revision from public.workspace_assets where id = current_setting('t.asset')::uuid),
    'capitalise', 'IAS 16', '2026-03-15', gen_random_uuid()));

select set_config('t.march', pg_temp.kpi('2026-03', '2026-03')::text, true);

select is(current_setting('t.march')::jsonb ->> 'operating_costs_minor', '1100',
  'operating costs: cleaning 1.00 and rent 10.00, the deductible tax left out');
select is(current_setting('t.march')::jsonb ->> 'net_sales_minor', '2000', 'the sales of March, net of their tax');
select is(current_setting('t.march')::jsonb ->> 'contribution_minor', '900',
  'invoiced less recorded operating costs: 9.00, never -3.00 with the machine counted as a cost');
select is(current_setting('t.march')::jsonb ->> 'acquisitions_minor', '1200', 'the capitalised machine at its cost');
select is((current_setting('t.march')::jsonb ->> 'unresolved_lines')::int, 1, 'the line nobody classified is counted');
select ok(current_setting('t.march')::jsonb -> 'reasons' ? 'unresolved_lines', 'and named among the reasons');
select is(pg_temp.kpi('2026-04', '2026-04') ->> 'operating_costs_minor', '0', 'April: nothing dated in it');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"assetRegister": false}'
 where id = '00000000-0000-4000-8000-0000025820b1';
set local role authenticated;
select is(pg_temp.kpi('2026-03', '2026-03') ->> 'acquisitions_minor', null,
  'without the equipment register the additions are unavailable, never 0');

select * from finish();
rollback;
