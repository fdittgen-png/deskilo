-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 / 0635 -- the bank statement's value date and reference in the
-- books. Four invoices of the same amount are paid on the same booking day
-- (20 March): A by a statement line with a reference (value date 17 March),
-- B by a line without one (18 March), C by a payment no line explains (a
-- stale line of another payment names C), D by two instalments, each a
-- statement line. The receipts of A and B carry their own line's value date
-- (and A its reference) beside the unchanged booking date; C's and D's
-- receipts carry neither key and the lines of every entry are what they
-- were; no invoice entry carries a key; the helper is not callable by a
-- member.
begin;
select plan(13);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000063500a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated',
        'a1@valuedate.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000063500b1','Value dates','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000063500a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"bankImport":true}', '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000063500c1','00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500a1',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000063500d1','00000000-0000-4000-8000-0000063500b1','Atelier','111','FR',true);

create function pg_temp.vt() returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('percent', 20, 'category', 'S', 'gross_cents', 12000, 'net_cents', 10000, 'vat_cents', 2000));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals)
select ('00000000-0000-4000-8000-0000063500e'||n)::uuid, '00000000-0000-4000-8000-0000063500b1',
       '00000000-0000-4000-8000-0000063500c1', '00000000-0000-4000-8000-0000063500c1', 'INV-' || chr(64 + n), 'T',
       jsonb_build_array(jsonb_build_object('kind','subscription','label','s','amount_cents',12000,'vat_percent',20)),
       12000, 'EUR', 'Ana', 'w', 'Flo', 'sig', '2026-03-05 10:00+00', '00000000-0000-4000-8000-0000063500d1', pg_temp.vt()
  from generate_series(1, 4) n;

-- Seven payments: one per invoice A and B, one for C, two instalments of D
-- (6000 each), and one stale payment no invoice consumed.
insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
select ('00000000-0000-4000-8000-0000063500f'||n)::uuid, '00000000-0000-4000-8000-0000063500b1',
       '00000000-0000-4000-8000-0000063500c1', 'credit', 'payment',
       case when n in (4, 5) then 6000 else 12000 end, 'p' || n, '2026-03', ('2026-03-1' || n)::date
  from generate_series(1, 6) n;
-- n=1 A, 2 B, 3 C, 4 and 5 D's instalments, 6 stale.
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at, payment_ledger_id)
select '00000000-0000-4000-8000-0000063500b1', ('00000000-0000-4000-8000-0000063500e'||n)::uuid, 12000, 'exact',
       '2026-03-20 10:00+00', ('00000000-0000-4000-8000-0000063500f'||
         case n when 4 then 4 else n end)::uuid
  from generate_series(1, 4) n;
insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution, matched_at)
values
 ('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500e1','00000000-0000-4000-8000-0000063500f1',12000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500e2','00000000-0000-4000-8000-0000063500f2',12000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500e3','00000000-0000-4000-8000-0000063500f3',12000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500e4','00000000-0000-4000-8000-0000063500f4',6000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500e4','00000000-0000-4000-8000-0000063500f5',6000,'exact','2026-03-20 10:00+00');

insert into public.bank_statements (id, workspace_id, format, account, currency, source_sha256, period_from, period_to)
values ('00000000-0000-4000-8000-0000063500a9','00000000-0000-4000-8000-0000063500b1','camt053','FR7630006000011234567890189','EUR',
        repeat('a', 64), '2026-03-01', '2026-03-31');
insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date, amount_cents,
                                         currency, reference, line_hash, payment_ledger_id, invoice_id)
select '00000000-0000-4000-8000-0000063500a9', '00000000-0000-4000-8000-0000063500b1', 'FR7630006000011234567890189', n,
       d.booking, d.value, d.cents, 'EUR', d.ref, repeat(n::text, 64), ('00000000-0000-4000-8000-0000063500f'||n)::uuid, d.inv
  from (values
    (1, date '2026-03-18', date '2026-03-17', 12000, 'RF18539007547034', '00000000-0000-4000-8000-0000063500e1'::uuid),
    (2, date '2026-03-19', date '2026-03-18', 12000, '',                 '00000000-0000-4000-8000-0000063500e2'::uuid),
    (4, date '2026-03-11', date '2026-03-10', 6000,  'D1',               '00000000-0000-4000-8000-0000063500e4'::uuid),
    (5, date '2026-03-12', date '2026-03-11', 6000,  'D2',               '00000000-0000-4000-8000-0000063500e4'::uuid),
    -- stale: its payment (6) was consumed by no invoice, yet it names C
    (6, date '2026-03-16', date '2026-03-15', 12000, 'STALE',            '00000000-0000-4000-8000-0000063500e3'::uuid)
  ) d(n, booking, value, cents, ref, inv);

create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500d1',
    role, (public.save_book_account('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500d1',
      null, code, code, kind, true, 'manual', 0) ->> 'id')::uuid, '2020-01-01', 0);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000063500a1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.map('customers','411','asset');
select pg_temp.map('bank','512','asset');
select pg_temp.map('revenue','706','income');
select pg_temp.map('vat_output','44571','liability');

select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000063500b1','00000000-0000-4000-8000-0000063500d1',
  '2026-03-01','2026-03-31')::text, true);
create function pg_temp.receipt(p_number text) returns jsonb language sql as $$
  select p from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
   where p ->> 'document_number' = p_number and p ->> 'kind' = 'receipt'
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'blockers'), 0, 'the month posts without a blocker');
select is(pg_temp.receipt('INV-A') ->> 'value_date', '2026-03-17', 'A: the receipt carries its line''s value date');
select is(pg_temp.receipt('INV-A') ->> 'bank_reference', 'RF18539007547034', 'A: and its reference');
select is(pg_temp.receipt('INV-B') ->> 'value_date', '2026-03-18', 'B: the same amount and booking day keep their own value date');
select ok(not pg_temp.receipt('INV-B') ? 'bank_reference', 'B: a line without a reference omits the key');
select is(pg_temp.receipt('INV-A') ->> 'date', pg_temp.receipt('INV-B') ->> 'date', 'the booking day is the match day for both');
select is(pg_temp.receipt('INV-A') ->> 'date', '2026-03-20', 'and it is not the value date');
select ok(not (pg_temp.receipt('INV-C') ?| array['value_date', 'bank_reference']),
          'C: a payment no line explains, whatever a stale line says, carries neither key');
select ok(not (pg_temp.receipt('INV-D') ?| array['value_date', 'bank_reference']),
          'D: two instalment lines are ambiguous and carry neither key');
select is((select string_agg((l ->> 'role') || ':' || (l ->> 'debit_cents') || '/' || (l ->> 'credit_cents'), ',' order by n)
             from jsonb_array_elements(pg_temp.receipt('INV-A') -> 'lines') with ordinality z(l, n)),
          'bank:12000/0,customers:0/12000', 'A: the lines of the entry are what they were');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
            where p ? 'value_date' and p ->> 'kind' <> 'receipt'), 0, 'no other entry carries a value date');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
            where p ->> 'kind' = 'receipt'), 4, 'one receipt per invoice, none added or dropped');
select ok(not has_function_privilege('authenticated', 'public.posting_bank_entry(uuid, uuid, jsonb)', 'execute'),
          'a member cannot call the helper');

select * from finish();
rollback;
