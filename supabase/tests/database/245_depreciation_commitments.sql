-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2582 C2 / 0530: book depreciation and the commitments still to be billed,
-- on 244's figures (in cents): invoiced less operating costs 9.00; confirmed
-- book depreciation of March 0.20 gives 8.80 after it, and a month without
-- confirmed book values (or with two that overlap) is unknown, never 9.00
-- labelled after depreciation. A lease of 10.00 a month from January:
-- January and February generated, 6.00 of a bill matched to February, March
-- onwards not generated yet. Left to bill: February 4.00 (overdue), January
-- to March 24.00, a month a year ahead 10.00 not yet due.
begin;
select plan(10);

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

select set_config('t.march', pg_temp.kpi('2026-03', '2026-03')::text, true);
select is(current_setting('t.march')::jsonb ->> 'book_depreciation_minor', '20', 'March: the confirmed book depreciation');
select is(current_setting('t.march')::jsonb ->> 'after_depreciation_minor', '880',
  'invoiced less operating costs after book depreciation: 9.00 - 0.20');
select is(pg_temp.kpi('2026-04', '2026-04') ->> 'after_depreciation_minor', null,
  'April has no confirmed book values: unknown, never 9.00 labelled after depreciation');
select ok(pg_temp.kpi('2026-04', '2026-04') -> 'reasons' ? 'book_coverage_incomplete', 'and says why');
select is(pg_temp.kpi('2026-02', '2026-02') ->> 'unbilled_minor', '400', 'February: 10.00 expected, 6.00 billed');
select is(pg_temp.kpi('2026-02', '2026-02') ->> 'unbilled_overdue_minor', '400', 'and it is overdue');
select is(pg_temp.kpi('2026-01', '2026-03') ->> 'unbilled_minor', '2400',
  'January to March: 10.00 + 4.00 + March projected from the schedule, nothing twice');
select is(pg_temp.kpi(to_char(now() + interval '13 months', 'YYYY-MM'), to_char(now() + interval '13 months', 'YYYY-MM'))
            ->> 'unbilled_upcoming_minor', '1000', 'a month a year ahead: one rent, not yet due');
reset role;
insert into public.asset_valuation_batches (workspace_id, basis, source_system, source_hash, period_from, period_to,
                                            currency, movements, complete_scope, status, reviewed_at) values
 ('00000000-0000-4000-8000-0000025820b1','book','ledger', repeat('b', 64),'2026-03-15','2026-03-31','EUR','period',
  true,'confirmed',now());
update public.workspaces set feature_flags = feature_flags || '{"premisesLease": false}'
 where id = '00000000-0000-4000-8000-0000025820b1';
set local role authenticated;
select is(pg_temp.kpi('2026-03', '2026-03') ->> 'book_depreciation_minor', null,
  'two confirmed book sets overlapping March: unknown, never summed');
select is(pg_temp.kpi('2026-02', '2026-02') ->> 'unbilled_minor', null, 'without a lease or a rented room: unavailable');

select * from finish();
rollback;
