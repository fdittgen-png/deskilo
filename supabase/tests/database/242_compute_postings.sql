-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2365 / 0518: the posting engine over the seeded year of the Dart rules
-- (test/features/money/posting_rules_test.dart), same entries to the cent:
-- INV-1 at 20 % and 5.5 % with a netted payment (40.00) and a netted
-- expense (30.00), paid 155.50; INV-2 part-paid; INV-3 paid 60.00 and the
-- rest written off; CN-1 a credit note. Every entry balances; the reduced
-- rate books to its qualified accounts; a period keeps only its own events;
-- an issuer with no chart is blocked with the role named; a plain member
-- reads nothing. 0521: the year is on the debits, but INV-4 printed « on
-- receipts »: its tax waits on 44574 and half of it is released when half
-- is paid. 0524: the member's receipt of 60.00 (20 %, fully recoverable)
-- books its expense against the member's account on its day, and is paid
-- back on 20 August; INV-1's netted expense books nothing. 0526: INV-4's
-- open half is written off on 25 July and its tax leaves 44574. The year's
-- VAT return equals the collected-VAT lines the books carry, write-off relief
-- apart (a separate line of the return, the accountant's) and the other
-- issuer's ANX-1 (2.00) apart (its book has no chart, so no line).
begin;
select plan(24);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002365'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@postings.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000002365b1','Postings','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002365a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"purchases":true,"supplyExpenses":true,
    "scheduledExpenses":true,"inputVat":true,"vatManagement":true}', '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002365c1','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002365c2','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002365c3','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a3',false,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000002365d1','00000000-0000-4000-8000-0000002365b1','Atelier','111','FR',true),
 ('00000000-0000-4000-8000-0000002365d2','00000000-0000-4000-8000-0000002365b1','Annexe','222','FR',false);
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000002365f1','00000000-0000-4000-8000-0000002365b1','1','Fournitures SA','active');

create function pg_temp.vt(p numeric, g int, n int, v int) returns jsonb language sql as $$
  select jsonb_build_object('percent', p, 'category', 'S', 'gross_cents', g, 'net_cents', n, 'vat_cents', v);
$$;
create function pg_temp.ln(k text, a int, v numeric default 0) returns jsonb language sql as $$
  select jsonb_build_object('kind', k, 'label', k, 'amount_cents', a, 'vat_percent', v);
$$;
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals) values
 ('00000000-0000-4000-8000-0000002365e1','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c1',
  '00000000-0000-4000-8000-0000002365c1','INV-1','T',
  jsonb_build_array(pg_temp.ln('subscription',12000,20), pg_temp.ln('accessories',10550,5.5),
                    pg_temp.ln('payment',-4000), pg_temp.ln('expense',-3000)),
  15550,'EUR','Ana','w','Flo','sig','2026-03-05 10:00+00','00000000-0000-4000-8000-0000002365d1',
  jsonb_build_array(pg_temp.vt(20,12000,10000,2000), pg_temp.vt(5.5,10550,10000,550))),
 ('00000000-0000-4000-8000-0000002365e2','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c1',
  '00000000-0000-4000-8000-0000002365c1','INV-2','T', jsonb_build_array(pg_temp.ln('subscription',20000,20)),
  20000,'EUR','Ana','w','Flo','sig','2026-04-05 10:00+00','00000000-0000-4000-8000-0000002365d1',
  jsonb_build_array(pg_temp.vt(20,20000,16667,3333))),
 ('00000000-0000-4000-8000-0000002365e3','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c1',
  '00000000-0000-4000-8000-0000002365c1','INV-3','T', jsonb_build_array(pg_temp.ln('subscription',10000,20)),
  10000,'EUR','Ana','w','Flo','sig','2026-05-05 10:00+00','00000000-0000-4000-8000-0000002365d1',
  jsonb_build_array(pg_temp.vt(20,10000,8333,1667))),
 ('00000000-0000-4000-8000-0000002365e4','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c1',
  '00000000-0000-4000-8000-0000002365c1','CN-1','T', jsonb_build_array(pg_temp.ln('adjustment',-5000,20)),
  -5000,'EUR','Ana','w','Flo','sig','2026-06-05 10:00+00','00000000-0000-4000-8000-0000002365d1',
  jsonb_build_array(pg_temp.vt(20,-5000,-4167,-833))),
 ('00000000-0000-4000-8000-0000002365e5','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c1',
  '00000000-0000-4000-8000-0000002365c1','ANX-1','T', jsonb_build_array(pg_temp.ln('subscription',1200,20)),
  1200,'EUR','Ana','w','Flo','sig','2026-03-05 10:00+00','00000000-0000-4000-8000-0000002365d2',
  jsonb_build_array(pg_temp.vt(20,1200,1000,200)));
-- The space returns to the French default (on receipts) before INV-4: the
-- invoice freezes it in its legal snapshot.
update public.workspaces set invoice_legal = '{}' where id = '00000000-0000-4000-8000-0000002365b1';
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals) values
 ('00000000-0000-4000-8000-0000002365e6','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c1',
  '00000000-0000-4000-8000-0000002365c1','INV-4','T', jsonb_build_array(pg_temp.ln('subscription',12000,20)),
  12000,'EUR','Ana','w','Flo','sig','2026-07-05 10:00+00','00000000-0000-4000-8000-0000002365d1',
  jsonb_build_array(pg_temp.vt(20,12000,10000,2000)));
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at, writeoff_at) values
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e6',6000,'under_accepted','2026-07-20 10:00+00','2026-07-25 10:00+00'),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e1',15550,'exact','2026-03-20 10:00+00',null),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e2',12000,'under_accepted','2026-04-20 10:00+00',null),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e3',6000,'under_accepted','2026-05-20 10:00+00','2026-05-25 10:00+00');

-- 0524: an approved expense of the plain member; the bridge files its
-- receipt, the approval's credit completes its claim.
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status,
                           decided_at, created_at) values
 ('00000000-0000-4000-8000-0000002365a9','00000000-0000-4000-8000-0000002365b1','expense','submitted',
  '00000000-0000-4000-8000-0000002365c2','00000000-0000-4000-8000-0000002365c2',
  '{"amount_cents": 6000, "category": "coffee", "note": "Coffee", "vat": {"percent": 20, "deductible_pct": 100}}',
  'confirmed', '2026-08-11 10:00+00', '2026-08-10 10:00+00');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
values ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365c2','credit','expense',6000,
        'Coffee','2026-08','00000000-0000-4000-8000-0000002365a9');

create function pg_temp.acc(code text, kind text) returns text language sql as $$
  select public.save_book_account('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365d1',
    null, code, code, kind, true, 'manual', 0) ->> 'id';
$$;
create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365d1',
    role, pg_temp.acc(code, kind)::uuid, '2020-01-01', 0);
$$;
create function pg_temp.lines(p_number text, p_kind text, p_date text default null) returns text language sql as $$
  select string_agg((l ->> 'account_code') || ':' ||
           case when (l ->> 'debit_cents')::bigint > 0 then 'D' || (l ->> 'debit_cents') else 'C' || (l ->> 'credit_cents') end,
           ',' order by n)
    from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
         jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
   where p ->> 'document_number' = p_number and p ->> 'kind' = p_kind
     and (p_date is null or p ->> 'date' = p_date);
$$;

create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002365a1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.map('customers','411','asset');
select pg_temp.map('bank','512','asset');
select pg_temp.map('revenue','706','income');
select pg_temp.map('revenue:reduced','7061','income');
select pg_temp.map('vat_output','44571','liability');
select pg_temp.map('vat_output:reduced','445712','liability');
select pg_temp.map('expenses','625','expense');
select pg_temp.map('write_off','654','expense');

select pg_temp.map('suppliers','401','liability');
select pg_temp.map('vat_input','44566','asset');
select pg_temp.map('vat_pending','44574','liability');

-- 0519: a supplier bill of 180.00 dated 10 March, decided by a second admin,
-- paid 180.00 on 2 April; a second bill left in draft posts nothing.
select set_config('t.bill', pg_temp.call('00000000-0000-4000-8000-0000002365a1',
  format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', '00000000-0000-4000-8000-0000002365b1',
    gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000002365f1',
      'original_reference', 'F-77', 'original_date', '2026-03-10', 'due_on', '2026-04-30', 'payer_kind', 'unpaid',
      'lines', jsonb_build_array(
        jsonb_build_object('description', 'Paper', 'gross_cents', 12000, 'net_cents', 10000, 'tax_cents', 2000,
                           'tax_rate_percent', 20, 'recoverable_tax_cents', 2000, 'nonrecoverable_tax_cents', 0),
        jsonb_build_object('description', 'Ink', 'gross_cents', 6000, 'net_cents', 5000, 'tax_cents', 1000,
                           'tax_rate_percent', 20, 'recoverable_tax_cents', 500, 'nonrecoverable_tax_cents', 500)))::text))
  ->> 'purchase_id', true);
select pg_temp.call('00000000-0000-4000-8000-0000002365a1',
  format('select public.submit_purchase_v1(%L, %L, 1, %L)', '00000000-0000-4000-8000-0000002365b1', current_setting('t.bill'), gen_random_uuid()));
select pg_temp.call('00000000-0000-4000-8000-0000002365a3',
  format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)', '00000000-0000-4000-8000-0000002365b1',
    current_setting('t.bill'), (select revision from public.purchase_documents where id = current_setting('t.bill')::uuid), '', gen_random_uuid()));
select pg_temp.call('00000000-0000-4000-8000-0000002365a1',
  format('select public.record_supplier_payment_v1(%L, %L, 18000, %s, %L, %L, ''bank_transfer'', ''wire'')',
    '00000000-0000-4000-8000-0000002365b1',
    (select id from public.purchase_obligations where purchase_id = current_setting('t.bill')::uuid),
    (select revision from public.purchase_obligations where purchase_id = current_setting('t.bill')::uuid),
    gen_random_uuid(), '2026-04-02'));
select pg_temp.call('00000000-0000-4000-8000-0000002365a1',
  format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', '00000000-0000-4000-8000-0000002365b1',
    gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000002365f1',
      'original_reference', 'F-DRAFT', 'original_date', '2026-03-11', 'payer_kind', 'unpaid',
      'lines', jsonb_build_array(jsonb_build_object('description', 'x', 'gross_cents', 120, 'net_cents', 100,
        'tax_cents', 20, 'tax_rate_percent', 20)))::text));
select pg_temp.call('00000000-0000-4000-8000-0000002365a1',
  format('select public.record_member_reimbursement_v1(%L, %L, 6000, %s, %L, %L)',
    '00000000-0000-4000-8000-0000002365b1',
    (select id from public.purchase_obligations where creditor_member_id = '00000000-0000-4000-8000-0000002365c2'),
    (select revision from public.purchase_obligations where creditor_member_id = '00000000-0000-4000-8000-0000002365c2'),
    gen_random_uuid(), '2026-08-20'));
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002365a1","role":"authenticated"}',true);

select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-01-01', '2026-12-31')::text, true);

select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'postings'), 17, 'the year is seventeen entries');
select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'blockers'), 0, 'with the full chart nothing blocks');
select ok((select bool_and((select sum((l ->> 'debit_cents')::bigint) = sum((l ->> 'credit_cents')::bigint)
                              from jsonb_array_elements(p -> 'lines') l))
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p), 'every entry balances');
select is(pg_temp.lines('INV-1','invoice'), '411:D22550,706:C10000,44571:C2000,7061:C10000,445712:C550',
  'INV-1 per rate group; the reduced rate on its qualified accounts');
select is(pg_temp.lines('INV-1','receipt','2026-03-05'), '512:D4000,411:C4000', 'its netted payment is money in on the invoice day');
select is(pg_temp.lines('INV-1','expense'), null, 'its netted expense books nothing: its receipt did (0524)');
select is(pg_temp.lines('INV-1','receipt','2026-03-20'), '512:D15550,411:C15550', 'the receipt is dated on its match');
select is(pg_temp.lines('INV-3','write_off'), '654:D3334,44571:D666,411:C4000', 'INV-3 written off with 6.66 of output tax regularised');
select is(pg_temp.lines('CN-1','credit_note'), '411:C5000,706:D4167,44571:D833', 'CN-1 mirrors an invoice');
select is(pg_temp.lines('INV-4','invoice'), '411:D12000,706:C10000,44574:C2000',
  'INV-4 on receipts: its tax waits on the pending account');
select is(pg_temp.lines('INV-4','vat_release'), '44574:D1000,44571:C1000',
  'half of it is due when half is paid, on the day of the payment');
select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-07-01', '2026-07-31') -> 'postings'), 4,
  'July: INV-4, its receipt, the tax it released and its write-off');
select is(pg_temp.lines('INV-4','write_off'), '654:D5000,44574:D1000,411:C6000',
  'INV-4 written off: the open half''s tax leaves the pending account (0526)');

select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-04-01', '2026-04-30') -> 'postings'), 3,
  'April keeps only its own events: INV-2, its receipt and the supplier payment');
select is(pg_temp.lines('F-77','supplier_bill'), '625:D10000,44566:D2000,625:D5500,44566:D500,401:C18000',
  'the supplier bill: the cost with what cannot be recovered, the recoverable tax apart, the supplier owed the gross');
select is(pg_temp.lines('F-77','supplier_payment'), '401:D18000,512:C18000', 'the supplier is paid on the day it was paid');
select is(pg_temp.lines('F-DRAFT','supplier_bill'), null, 'a draft bill posts nothing');
select is(pg_temp.lines('','member_receipt'), '625:D5000,44566:D1000,411:C6000',
  'the member''s receipt: the cost and the recoverable tax, the member''s account credited');
select is(pg_temp.lines('','reimbursement','2026-08-20'), '411:D6000,512:C6000',
  'the money paid back to the member on the day it was paid');
select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d2', '2026-03-01', '2026-03-31') -> 'postings'), 1,
  'another issuer than the default one books no purchase');
select is((public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d2', '2026-01-01', '2026-12-31') -> 'blockers' -> 0 ->> 'block'), 'unmappedRole',
  'an issuer with no chart is blocked, the role named');
select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d2', '2026-01-01', '2026-12-31') -> 'postings' -> 0 -> 'lines'), 0,
  'and posts no guessed line');

select is((select sum((l ->> 'credit_cents')::bigint - (l ->> 'debit_cents')::bigint)
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
                  jsonb_array_elements(p -> 'lines') l
            where l ->> 'role' = 'vat_output' and p ->> 'kind' <> 'write_off') + 200,
          (select sum(vat_cents) from public.compute_vat_return('00000000-0000-4000-8000-0000002365b1',
             '2026-01-01', '2026-12-31') where direction = 'output'),
          'the year''s VAT return equals the books'' collected-VAT lines (write-off relief and the other issuer apart)');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002365a2","role":"authenticated"}',true);
select throws_ok($$select public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-01-01', '2026-12-31')$$, '42501', null, 'a plain member reads no books');

select * from finish();
rollback;
