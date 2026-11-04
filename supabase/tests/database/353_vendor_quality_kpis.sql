-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3294 / 0673: the vendor figures, each proven from a hand-built March 2025
-- (Paris, EUR), filed and decided through the purchase RPCs. Bills (dated,
-- received, due, amount; cost = net, no tax):
--   b1 Alpha rent      2nd, 5th,  20th, 100.00 paid the 18th            -> on time, -2 days
--   b2 Alpha repairs  10th, 20th, 25th,  50.00 paid 4 April             -> late, +10 days
--   b3 Beta  cleaning  1st, 1st,  31st,  40.00 15.00 paid the 15th      -> partial
--   b4 Beta  cleaning 12th, 14th, 28th,  20.00 on hold                  -> held
--   b5 Gamma energy   15th, 15th, 15 April, 30.00                       -> not due in March
--   b6 Gamma energy    5th, 6th,  15th,  15.00 unpaid                   -> open
--   b7 Beta  cleaning 20th, 22nd, none,    5.00                         -> no due date
--   d8 Gamma energy   a credit note of b5, 10.00, the 25th (filed directly).
-- Cost 250.00: Alpha 150.00, Beta 65.00, Gamma 35.00; by category rent
-- 100.00, cleaning 65.00, repairs 50.00, energy 35.00. On time 1 of 2
-- settled; median -2, P90 10, weighted (-2*10000+10*5000)/15000 = 2.0 days.
-- Billing lag over 7 bills: 18 days, median 2, P90 10. A plain member reads
-- nothing; a dollar bill leaves every amount unknown (currency_mix) while
-- the counts stay; with the flag off nothing is read.
begin;
select plan(18);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000032942'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@vendors.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000032942b1','Vendors','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032942a1','dev',
  '{"moneyTab":true,"purchases":true,"purchaseAnalytics":true,"supplyExpenses":true,"inputVat":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000032942c1','00000000-0000-4000-8000-0000032942b1','00000000-0000-4000-8000-0000032942a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000032942c2','00000000-0000-4000-8000-0000032942b1','00000000-0000-4000-8000-0000032942a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000032942c3','00000000-0000-4000-8000-0000032942b1','00000000-0000-4000-8000-0000032942a3',false,true,'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000032942f1','00000000-0000-4000-8000-0000032942b1','1','Alpha','active'),
 ('00000000-0000-4000-8000-0000032942f2','00000000-0000-4000-8000-0000032942b1','2','Beta','active'),
 ('00000000-0000-4000-8000-0000032942f3','00000000-0000-4000-8000-0000032942b1','3','Gamma','active');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000032942' || p)::uuid;
$$;
create function pg_temp.as_user(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
-- A document drafted by the owner, submitted, and approved by the second admin.
create function pg_temp.doc(p_kind text, p_supplier text, p_category text, p_dated date, p_received date,
                            p_due date, p_cents int) returns uuid language plpgsql as $$
declare v_id uuid; v_rev int;
begin
  v_id := (pg_temp.as_user('a1', format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)',
    pg_temp.u('b1'), gen_random_uuid(), jsonb_build_object('kind', p_kind, 'supplier_id', pg_temp.u(p_supplier),
      'category', p_category, 'original_reference', p_category || p_cents, 'original_date', p_dated,
      'received_on', p_received, 'due_on', p_due, 'payer_kind', 'unpaid',
      'lines', jsonb_build_array(jsonb_build_object('description', p_category, 'gross_cents', p_cents,
        'net_cents', p_cents, 'tax_cents', 0)))::text)) ->> 'purchase_id')::uuid;
  perform pg_temp.as_user('a1', format('select public.submit_purchase_v1(%L, %L, 1, %L)',
    pg_temp.u('b1'), v_id, gen_random_uuid()));
  select revision into v_rev from public.purchase_documents where id = v_id;
  perform pg_temp.as_user('a3', format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)',
    pg_temp.u('b1'), v_id, v_rev, '', gen_random_uuid()));
  return v_id;
end;
$$;
create function pg_temp.pay(p_doc uuid, p_cents int, p_on date) returns void language plpgsql as $$
begin
  perform pg_temp.as_user('a1', format(
    'select public.record_supplier_payment_v1(%L, %L, %s, %s, %L, %L, ''bank_transfer'', ''wire'')',
    pg_temp.u('b1'), o.id, p_cents, o.revision, gen_random_uuid(), p_on))
    from public.purchase_obligations o where o.purchase_id = p_doc;
end;
$$;
create function pg_temp.kpi(p_user text, p_from text default '2025-03', p_to text default '2025-03')
returns jsonb language sql as $$
  select pg_temp.as_user(p_user, format('select public.kpi_vendor_quality(%L, %L, %L)', pg_temp.u('b1'), p_from, p_to));
$$;
create function pg_temp.err(p_user text, p_from text default '2025-03', p_to text default '2025-03')
returns text language plpgsql as $$
begin
  perform pg_temp.kpi(p_user, p_from, p_to);
  return '';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

set local role authenticated;
select set_config('t.b1', pg_temp.doc('bill', 'f1', 'rent', '2025-03-02', '2025-03-05', '2025-03-20', 10000)::text, true);
select set_config('t.b2', pg_temp.doc('bill', 'f1', 'repairs', '2025-03-10', '2025-03-20', '2025-03-25', 5000)::text, true);
select set_config('t.b3', pg_temp.doc('bill', 'f2', 'cleaning', '2025-03-01', '2025-03-01', '2025-03-31', 4000)::text, true);
select set_config('t.b4', pg_temp.doc('bill', 'f2', 'cleaning', '2025-03-12', '2025-03-14', '2025-03-28', 2000)::text, true);
select set_config('t.b5', pg_temp.doc('bill', 'f3', 'energy', '2025-03-15', '2025-03-15', '2025-04-15', 3000)::text, true);
select set_config('t.b6', pg_temp.doc('bill', 'f3', 'energy', '2025-03-05', '2025-03-06', '2025-03-15', 1500)::text, true);
select set_config('t.b7', pg_temp.doc('bill', 'f2', 'cleaning', '2025-03-20', '2025-03-22', null, 500)::text, true);
select pg_temp.pay(current_setting('t.b1')::uuid, 10000, '2025-03-18');
select pg_temp.pay(current_setting('t.b2')::uuid, 5000, '2025-04-04');
select pg_temp.pay(current_setting('t.b3')::uuid, 1500, '2025-03-15');
reset role;
update public.purchase_obligations set state = 'held', hold_reason = 'disputed'
 where purchase_id = current_setting('t.b4')::uuid;
-- The credit note: no RPC submits one yet (it is applied to its bill in a
-- later step), so it is filed approved here.
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id,
                                       payer_kind, original_date, received_on, category, original_document_id)
values (pg_temp.u('d8'), pg_temp.u('b1'), 'credit_note', 'draft', 'EUR', pg_temp.u('f3'), pg_temp.u('c1'),
        'unpaid', '2025-03-25', '2025-03-25', 'energy', current_setting('t.b5')::uuid);
insert into public.purchase_lines (workspace_id, purchase_id, line_no, description, gross_cents, net_cents, tax_cents)
values (pg_temp.u('b1'), pg_temp.u('d8'), 1, 'energy', 1000, 1000, 0);
update public.purchase_documents set state = 'approved', decided_by_member_id = pg_temp.u('c3'), decided_at = now()
 where id = pg_temp.u('d8');
set local role authenticated;

select set_config('t.owner', pg_temp.kpi('a1')::text, true);

select is(current_setting('t.owner')::jsonb -> 'spend' ->> 'cost_minor', '25000',
  'the cost of the approved documents of March, the credit note subtracted');
select is((current_setting('t.owner')::jsonb -> 'spend' ->> 'documents', current_setting('t.owner')::jsonb -> 'spend' ->> 'credit_notes',
           current_setting('t.owner')::jsonb -> 'spend' ->> 'credited_minor'),
  ('7'::text, '1'::text, '1000'::text), 'seven bills and one credit note of 10.00');
select is(current_setting('t.owner')::jsonb -> 'spend' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('rank', 1, 'supplier_id', pg_temp.u('f1'), 'name', 'Alpha', 'documents', 2, 'cost_minor', '15000'),
    jsonb_build_object('rank', 2, 'supplier_id', pg_temp.u('f2'), 'name', 'Beta', 'documents', 3, 'cost_minor', '6500'),
    jsonb_build_object('rank', 3, 'supplier_id', pg_temp.u('f3'), 'name', 'Gamma', 'documents', 3, 'cost_minor', '3500')),
  'the cost by supplier, the largest first, a credit note counted and subtracted under its supplier');
select is((current_setting('t.owner')::jsonb -> 'spend' ->> 'top_cost_minor', current_setting('t.owner')::jsonb -> 'spend' ->> 'suppliers'),
  ('25000'::text, '3'::text), 'the five largest suppliers make all of it: there are three');
select is(current_setting('t.owner')::jsonb -> 'spend' -> 'months',
  '[{"month":"2025-03","cost_minor":"25000"}]'::jsonb, 'by the document''s month');
select is(current_setting('t.owner')::jsonb -> 'categories' -> 'rows',
  '[{"category":"rent","documents":1,"cost_minor":"10000"},{"category":"cleaning","documents":3,"cost_minor":"6500"},
    {"category":"repairs","documents":1,"cost_minor":"5000"},{"category":"energy","documents":3,"cost_minor":"3500"}]'::jsonb,
  'the cost by category, the largest first');
select is(current_setting('t.owner')::jsonb -> 'payment' -> 'cohorts',
  '{"on_time":{"count":1,"minor":"10000"},"late":{"count":1,"minor":"5000"},"undated":{"count":0,"minor":"0"},
    "partial":{"count":1,"minor":"4000"},"open":{"count":1,"minor":"1500"},"held":{"count":1,"minor":"2000"},
    "unknown_due":{"count":1,"minor":"500"}}'::jsonb,
  'each supplier payable due in March (or undated on a March bill) is in one cohort; the April one is not');
select is((current_setting('t.owner')::jsonb -> 'payment' ->> 'median_days', current_setting('t.owner')::jsonb -> 'payment' ->> 'p90_days',
           current_setting('t.owner')::jsonb -> 'payment' ->> 'weighted_days'),
  ('-2'::text, '10'::text, '2.0'::text), 'the delay from the due date to the reported payment: median, P90, weighted');
select is(current_setting('t.owner')::jsonb -> 'payment' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('supplier_id', pg_temp.u('f2'), 'name', 'Beta', 'due', 3, 'on_time', 0, 'late', 0, 'median_days', null),
    jsonb_build_object('supplier_id', pg_temp.u('f1'), 'name', 'Alpha', 'due', 2, 'on_time', 1, 'late', 1, 'median_days', -2),
    jsonb_build_object('supplier_id', pg_temp.u('f3'), 'name', 'Gamma', 'due', 1, 'on_time', 0, 'late', 0, 'median_days', null)),
  'how punctually each supplier is paid');
select is((current_setting('t.owner')::jsonb -> 'billing_lag' ->> 'documents', current_setting('t.owner')::jsonb -> 'billing_lag' ->> 'lag_days',
           current_setting('t.owner')::jsonb -> 'billing_lag' ->> 'median_days', current_setting('t.owner')::jsonb -> 'billing_lag' ->> 'p90_days'),
  ('7'::text, '18'::text, '2'::text, '10'::text), 'how late the bills reach the space: 7 bills, 18 days, median 2, P90 10');
select is(current_setting('t.owner')::jsonb -> 'billing_lag' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('supplier_id', pg_temp.u('f2'), 'name', 'Beta', 'documents', 3, 'lag_days', 4, 'median_days', 2),
    jsonb_build_object('supplier_id', pg_temp.u('f1'), 'name', 'Alpha', 'documents', 2, 'lag_days', 13, 'median_days', 3),
    jsonb_build_object('supplier_id', pg_temp.u('f3'), 'name', 'Gamma', 'documents', 2, 'lag_days', 1, 'median_days', 0)),
  'by supplier');
select is(current_setting('t.owner')::jsonb -> 'quality', '[]'::jsonb, 'a past month in one currency is whole');
select is(pg_temp.err('a2'), '42501', 'a plain member reads no vendor figure');
select is(pg_temp.err('a1', '2025-03', '2027-03'), '22023', 'more than 24 months is refused');
select is(pg_temp.err('a1', '2025-04', '2025-03'), '22023', 'a period that ends before it starts is refused');

-- A dollar bill of March, approved with its recorded rate.
reset role;
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id,
                                       payer_kind, original_date, received_on, category, decided_by_member_id, decided_at)
values (pg_temp.u('d9'), pg_temp.u('b1'), 'bill', 'draft', 'USD', pg_temp.u('f1'), pg_temp.u('c1'),
        'unpaid', '2025-03-08', '2025-03-08', 'rent', null, null);
insert into public.purchase_lines (workspace_id, purchase_id, line_no, description, gross_cents, net_cents, tax_cents)
values (pg_temp.u('b1'), pg_temp.u('d9'), 1, 'rent', 700, 700, 0);
insert into public.document_exchange_rates (workspace_id, document_kind, document_id, currency, functional_currency, rate, rate_date, source)
values (pg_temp.u('b1'), 'purchase', pg_temp.u('d9'), 'USD', 'EUR', 0.92, '2025-03-08', 'bank');
update public.purchase_documents set state = 'approved', decided_by_member_id = pg_temp.u('c3'), decided_at = now()
 where id = pg_temp.u('d9');
set local role authenticated;
select set_config('t.mixed', pg_temp.kpi('a1')::text, true);
select ok(current_setting('t.mixed')::jsonb -> 'reasons' ? 'currency_mix'
          and current_setting('t.mixed')::jsonb -> 'spend' ->> 'cost_minor' is null
          and current_setting('t.mixed')::jsonb -> 'payment' -> 'cohorts' -> 'on_time' ->> 'minor' is null,
  'a dollar bill leaves every amount unknown, never summed');
select is((current_setting('t.mixed')::jsonb -> 'spend' ->> 'documents', current_setting('t.mixed')::jsonb -> 'payment' ->> 'median_days'),
  ('8'::text, '-2'::text), '... while the counts and the days stay');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchaseAnalytics": false}' where id = pg_temp.u('b1');
set local role authenticated;
select is(pg_temp.err('a1'), '42501', 'with the purchase figures off, nothing is read');

select * from finish();
rollback;
