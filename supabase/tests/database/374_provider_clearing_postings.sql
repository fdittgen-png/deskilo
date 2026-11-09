-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 / 0698 -- a payment provider's money through its clearing account.
-- Three Stripe payments of 120.00 (fee 3.78 each) matched to INV-1..3 and
-- carried by one payout of 348.66: receipts debit clearing:stripe, one fee
-- entry per payment (Dr fees, Dr/Cr the reverse-charge VAT of the fee at the
-- French standard rate, Cr clearing), one payout entry (Dr bank, Cr clearing),
-- and the clearing balance of those three is zero. Beside them, every branch
-- the patch touches: INV-4 paid half online and half otherwise (clearing for
-- the online half, bank for the rest), INV-5 paid with no online payment (its
-- receipt is the bank leg it always was), a fee whose payout is not yet paid,
-- a payout without a fee, and the reverse charge absent where the country has
-- no standard rate. Rolled back.
begin;
select plan(17);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000069800a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a1@clearing.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000069800b1','Clearing','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000069800a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}', '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values ('00000000-0000-4000-8000-0000069800c1','00000000-0000-4000-8000-0000069800b1','00000000-0000-4000-8000-0000069800a1',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values ('00000000-0000-4000-8000-0000069800d1','00000000-0000-4000-8000-0000069800b1','Atelier','111','FR',true);

create function pg_temp.vt() returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('percent', 20, 'category', 'S', 'gross_cents', 12000, 'net_cents', 10000, 'vat_cents', 2000));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals)
select ('00000000-0000-4000-8000-0000069800e'||n)::uuid, '00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800c1', '00000000-0000-4000-8000-0000069800c1', 'INV-' || n, 'T',
       jsonb_build_array(jsonb_build_object('kind','subscription','label','s','amount_cents',12000,'vat_percent',20)),
       12000, 'EUR', 'Ana', 'w', 'Flo', 'sig', '2026-03-05 10:00+00', '00000000-0000-4000-8000-0000069800d1', pg_temp.vt()
  from generate_series(1, 5) n;

-- Payments: f1..f3 online (12000), f4 online (6000), f5 plain (6000), f6 plain (12000).
insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
select ('00000000-0000-4000-8000-0000069800f'||n)::uuid, '00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800c1', 'credit', 'payment', case when n in (4, 5) then 6000 else 12000 end,
       case when n <= 4 then 'stripe online payment' else 'bank transfer' end, '2026-03', '2026-03-10'
  from generate_series(1, 6) n;
insert into public.payment_intents (workspace_id, member_id, provider, order_id, period, amount_cents, currency,
                                    status, ledger_entry_id, capture_id)
select '00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800c1', 'stripe', 'cs_' || n, '2026-03', case when n = 4 then 6000 else 12000 end, 'EUR', 'captured',
       ('00000000-0000-4000-8000-0000069800f'||n)::uuid, 'pi_' || n
  from generate_series(1, 4) n;
select public.record_provider_fee_v1('stripe', 'cs_' || n, case when n = 4 then 192 else 378 end,
                                     case when n = 4 then 5808 else 11622 end, 'EUR', 'txn_' || n)
  from generate_series(1, 4) n;
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at, payment_ledger_id)
values ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e1', 12000, 'exact', '2026-03-12 10:00+00', '00000000-0000-4000-8000-0000069800f1'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e2', 12000, 'exact', '2026-03-12 10:00+00', '00000000-0000-4000-8000-0000069800f2'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e3', 12000, 'exact', '2026-03-12 10:00+00', '00000000-0000-4000-8000-0000069800f3'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e4', 12000, 'exact', '2026-03-12 10:00+00', '00000000-0000-4000-8000-0000069800f4'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e5', 12000, 'exact', '2026-03-12 10:00+00', '00000000-0000-4000-8000-0000069800f6');
insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution, matched_at)
values ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e1', '00000000-0000-4000-8000-0000069800f1', 12000, 'exact', '2026-03-12 10:00+00'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e2', '00000000-0000-4000-8000-0000069800f2', 12000, 'exact', '2026-03-12 10:00+00'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e3', '00000000-0000-4000-8000-0000069800f3', 12000, 'exact', '2026-03-12 10:00+00'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e4', '00000000-0000-4000-8000-0000069800f4', 6000, 'exact', '2026-03-12 10:00+00'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e4', '00000000-0000-4000-8000-0000069800f5', 6000, 'exact', '2026-03-12 10:00+00'),
       ('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800e5', '00000000-0000-4000-8000-0000069800f6', 12000, 'exact', '2026-03-12 10:00+00');
-- The payout of the first three, and one with no payment behind it.
insert into public.provider_payouts (workspace_id, provider, payout_id, amount_cents, currency, arrival_date, status)
values ('00000000-0000-4000-8000-0000069800b1', 'stripe', 'po_1', 34866, 'EUR', '2026-03-15', 'paid'),
       ('00000000-0000-4000-8000-0000069800b1', 'mollie', 'po_m', 5000, 'EUR', '2026-03-16', 'paid'),
       ('00000000-0000-4000-8000-0000069800b1', 'stripe', 'po_late', 777, 'EUR', '2026-04-02', 'paid');

create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000069800b1','00000000-0000-4000-8000-0000069800d1', role, (public.save_book_account('00000000-0000-4000-8000-0000069800b1','00000000-0000-4000-8000-0000069800d1',
      null, code, code, kind, true, 'manual', 0) ->> 'id')::uuid, '2020-01-01', 0);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000069800a1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.map('customers','411','asset');
select pg_temp.map('bank','512','asset');
select pg_temp.map('revenue','706','income');
select pg_temp.map('vat_output','44571','liability');
select pg_temp.map('vat_input','445660','asset');
select pg_temp.map('clearing','5171','asset');
select pg_temp.map('fees','6278','expense');

select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000069800b1','00000000-0000-4000-8000-0000069800d1','2026-03-01','2026-03-31')::text, true);
select set_config('t.early', public.compute_postings('00000000-0000-4000-8000-0000069800b1','00000000-0000-4000-8000-0000069800d1','2026-03-01','2026-03-14')::text, true);
create function pg_temp.entries(p_set text, p_number text, p_kind text) returns jsonb language sql as $$
  select coalesce(jsonb_agg(p), '[]'::jsonb) from jsonb_array_elements(current_setting(p_set)::jsonb -> 'postings') p
   where p ->> 'document_number' = p_number and p ->> 'kind' = p_kind
$$;
-- 'role:debit/credit' of every line of the entry set, in order.
create function pg_temp.lines(p_entries jsonb) returns text language sql as $$
  select string_agg((l ->> 'role') || coalesce(':' || (l ->> 'qualifier'), '') || ' ' || (l ->> 'debit_cents') || '/' || (l ->> 'credit_cents'), ', ' order by e.n, z.n)
    from jsonb_array_elements(p_entries) with ordinality e(p, n),
         jsonb_array_elements(e.p -> 'lines') with ordinality z(l, n)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'blockers'), 0, 'the month posts without a blocker');
select is(pg_temp.lines(pg_temp.entries('t.r', 'INV-1', 'receipt')), 'clearing:stripe 12000/0, customers 0/12000',
          'a receipt matched to an online payment debits the provider''s clearing account, not the bank');
select is(pg_temp.lines(pg_temp.entries('t.r', 'INV-4', 'receipt')),
          'bank 6000/0, clearing:stripe 6000/0, customers 0/12000',
          'half online, half otherwise: clearing for the online half, the bank for the rest');
select is(pg_temp.lines(pg_temp.entries('t.r', 'INV-5', 'receipt')), 'bank 12000/0, customers 0/12000',
          'no online payment: the receipt is the bank leg it always was');
select is(pg_temp.lines(pg_temp.entries('t.r', 'cs_1', 'expense')),
          'fees:stripe 378/0, vat_input:standard 76/0, vat_output:standard 0/76, clearing:stripe 0/378',
          'the fee: Dr fees, the reverse charge at the standard rate (3.78 x 20 % = 0.76), Cr clearing');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
            where p ->> 'kind' = 'expense' and p ->> 'journal' = 'purchases'), 4, 'one fee entry per paid-for payment');
select is(pg_temp.lines(pg_temp.entries('t.r', 'po_1', 'receipt')), 'bank 34866/0, clearing:stripe 0/34866',
          'the payout: Dr bank, Cr clearing');
-- The done-when: gross receipts less fees equal the payout, to the cent.
select is((select sum((l ->> 'debit_cents')::bigint - (l ->> 'credit_cents')::bigint)::int
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
                  jsonb_array_elements(p -> 'lines') l
            where l ->> 'role' = 'clearing' and l ->> 'qualifier' = 'stripe'
              and p ->> 'document_number' in ('INV-1', 'INV-2', 'INV-3', 'cs_1', 'cs_2', 'cs_3', 'po_1')), 0,
          'the clearing balance of the three payments is zero after the payout');
select is((select sum((l ->> 'debit_cents')::bigint - (l ->> 'credit_cents')::bigint)::int
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
                  jsonb_array_elements(p -> 'lines') l
            where l ->> 'role' = 'clearing' and l ->> 'qualifier' = 'stripe'), 5808,
          'what stays in clearing is the net of the payment no payout carried yet (6000 - 1.92)');
select is(pg_temp.lines(pg_temp.entries('t.r', 'po_m', 'receipt')), 'bank 5000/0, clearing:mollie 0/5000',
          'a payout with no payment behind it still moves clearing to the bank');
select is(jsonb_array_length(pg_temp.entries('t.early', 'po_1', 'receipt')), 0, 'a fee before its payout: no payout entry yet');
select is(jsonb_array_length(pg_temp.entries('t.early', 'cs_1', 'expense')), 1, 'and the fee is booked on its capture day');
select is(jsonb_array_length(pg_temp.entries('t.r', 'po_late', 'receipt')), 0, 'a payout arriving after the period is not in it');
-- Reverse charge absent: a country with no standard rate row (the helper is
-- not callable by a member, so this statement runs as the owner).
reset role;
select is(pg_temp.lines(jsonb_build_array(public.provider_settlement_postings('00000000-0000-4000-8000-0000069800b1', '00000000-0000-4000-8000-0000069800d1', '2026-03-01', '2026-03-31', 'ZZ', 'UTC', 'EUR')
            -> 0)), 'fees:stripe 378/0, clearing:stripe 0/378',
          'no standard rate in the country: no reverse-charge pair');
set local role authenticated;
select ok(not has_function_privilege('authenticated', 'public.provider_settlement_postings(uuid, uuid, date, date, text, text, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.provider_clearing_lines(uuid, date, bigint, jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.provider_receipt_split(uuid, uuid, bigint)', 'execute'),
          'a member cannot call the helpers');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
            where p ->> 'kind' = 'receipt' and p ->> 'document_number' like 'INV-%'), 5,
          'one receipt per invoice, none added or dropped');

select * from finish();
rollback;
