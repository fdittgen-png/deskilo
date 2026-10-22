-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2582 C2 / 0532: the forecast ladder on 245's figures (in cents). The
-- bill of 10 March is 26.10 owed (cleaning 1.20, rent 10.00, the machine
-- 14.40, sundries 0.50), 6.00 of its rent matched to February's 10.00 rent.
-- February: nothing owed yet, 4.00 still expected. March: 26.10 owed plus
-- March's projected rent 10.00. January to March: 26.10 + 24.00, the
-- matched 6.00 counted once (in what is owed). No contract: unavailable.
begin;
select plan(5);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025820'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@costs.test','',now(),now(),now()
  from unnest(array['a1','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000025820b1','Costs','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025820a1','dev',
  '{"moneyTab":true,"invoicing":true,"purchases":true,"purchaseAnalytics":true,"assetRegister":true,"supplyExpenses":true,"inputVat":true,"scheduledExpenses":true,"premisesLease":true,"externalRooms":false}');
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

select set_config('t.lease', gen_random_uuid()::text, true);
reset role;
-- The lease's rent schedule, January and February already generated.
insert into public.expense_schedules (id, workspace_id, member_id, title, amount_cents, starts_on, unit, every,
                                      status, occurrences_done, next_due, origin, contract_id) values
 ('00000000-0000-4000-8000-0000025820d1','00000000-0000-4000-8000-0000025820b1',
  '00000000-0000-4000-8000-0000025820c1','Rent',1000,'2026-01-01','month',1,'active',2,'2026-03-01',
  'workspace_contract', current_setting('t.lease')::uuid);
insert into public.expense_occurrences (id, schedule_id, workspace_id, member_id, due_on, amount_cents) values
 ('00000000-0000-4000-8000-0000025820d2','00000000-0000-4000-8000-0000025820d1','00000000-0000-4000-8000-0000025820b1',
  '00000000-0000-4000-8000-0000025820c1','2026-01-01',1000),
 ('00000000-0000-4000-8000-0000025820d3','00000000-0000-4000-8000-0000025820d1','00000000-0000-4000-8000-0000025820b1',
  '00000000-0000-4000-8000-0000025820c1','2026-02-01',1000);
insert into public.purchase_commitment_matches (workspace_id, occurrence_id, purchase_id, purchase_line_id, kind,
                                                allocated_cents, currency, request_id, actor_member_id)
select '00000000-0000-4000-8000-0000025820b1', '00000000-0000-4000-8000-0000025820d3', l.purchase_id, l.id, 'match',
       600, 'EUR', gen_random_uuid(), '00000000-0000-4000-8000-0000025820c1'
  from public.purchase_lines l where l.purchase_id = current_setting('t.bill')::uuid and l.line_no = 2;
-- March's confirmed book values: the machine depreciates 0.20.
insert into public.asset_valuation_batches (id, workspace_id, basis, source_system, source_hash, period_from, period_to,
                                            currency, movements, complete_scope, status, reviewed_at) values
 ('00000000-0000-4000-8000-0000025820e7','00000000-0000-4000-8000-0000025820b1','book','ledger',
  repeat('a', 64),'2026-03-01','2026-03-31','EUR','period',true,'confirmed',now());
insert into public.asset_valuation_rows (workspace_id, batch_id, asset_id, depreciation_minor) values
 ('00000000-0000-4000-8000-0000025820b1','00000000-0000-4000-8000-0000025820e7',current_setting('t.asset')::uuid,20);
set local role authenticated;

select is(pg_temp.kpi('2026-02', '2026-02') ->> 'forecast_minor', '400',
  'February: nothing owed by its end, 4.00 still expected');
select is(pg_temp.kpi('2026-03', '2026-03') ->> 'forecast_minor', '3610',
  'March: 26.10 owed plus the projected rent');
select is(pg_temp.kpi('2026-01', '2026-03') ->> 'forecast_minor', '5010',
  'January to March: 26.10 + 10.00 + 4.00 + 10.00, the matched 6.00 once');
select is((pg_temp.kpi('2026-03', '2026-03') ->> 'forecast_minor')::bigint,
  (pg_temp.call(pg_temp.u('a1'), format('select public.kpi_purchases_summary(%L, %L, %L)',
     '00000000-0000-4000-8000-0000025820b1', '2026-03', '2026-03')) ->> 'ap_outstanding_minor')::bigint
  + (pg_temp.kpi('2026-03', '2026-03') ->> 'unbilled_minor')::bigint,
  'the ladder is what is owed plus what is still expected, nothing else');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"premisesLease": false}'
 where id = '00000000-0000-4000-8000-0000025820b1';
set local role authenticated;
select is(pg_temp.kpi('2026-03', '2026-03') ->> 'forecast_minor', null,
  'without a lease or a rented room: unavailable');

select * from finish();
rollback;
