-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 / 0641 -- the bank statement's value date and reference in the
-- accounting source snapshot, the input of the DATEV Buchungsstapel. The
-- fixture is 323's: four invoices paid on the same booking day, A by a
-- statement line with a reference, B by a line without one, C by a payment
-- no line explains (a stale line of another payment names C), D by two
-- instalment lines; and a second space that never imported a statement.
-- A's and B's match rows carry their line's value date (and A its
-- reference) and nothing else of the row changes; C's, D's and the other
-- space's rows are byte for byte the table rows, the control totals are
-- the rows' and the postings (0635's helper, now asking the same rule)
-- still carry the facts.
begin;
select plan(17);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000064100a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated',
        'a1@valuedate.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000064100b1','Value dates','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000064100a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"bankImport":true}', '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000064100c1','00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100a1',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000064100d1','00000000-0000-4000-8000-0000064100b1','Atelier','111','FR',true);

create function pg_temp.vt() returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('percent', 20, 'category', 'S', 'gross_cents', 12000, 'net_cents', 10000, 'vat_cents', 2000));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals)
select ('00000000-0000-4000-8000-0000064100e'||n)::uuid, '00000000-0000-4000-8000-0000064100b1',
       '00000000-0000-4000-8000-0000064100c1', '00000000-0000-4000-8000-0000064100c1', 'INV-' || chr(64 + n), 'T',
       jsonb_build_array(jsonb_build_object('kind','subscription','label','s','amount_cents',12000,'vat_percent',20)),
       12000, 'EUR', 'Ana', 'w', 'Flo', 'sig', '2026-03-05 10:00+00', '00000000-0000-4000-8000-0000064100d1', pg_temp.vt()
  from generate_series(1, 4) n;

-- Seven payments: one per invoice A and B, one for C, two instalments of D
-- (6000 each), and one stale payment no invoice consumed.
insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
select ('00000000-0000-4000-8000-0000064100f'||n)::uuid, '00000000-0000-4000-8000-0000064100b1',
       '00000000-0000-4000-8000-0000064100c1', 'credit', 'payment',
       case when n in (4, 5) then 6000 else 12000 end, 'p' || n, '2026-03', ('2026-03-1' || n)::date
  from generate_series(1, 6) n;
-- n=1 A, 2 B, 3 C, 4 and 5 D's instalments, 6 stale.
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at, payment_ledger_id)
select '00000000-0000-4000-8000-0000064100b1', ('00000000-0000-4000-8000-0000064100e'||n)::uuid, 12000, 'exact',
       '2026-03-20 10:00+00', ('00000000-0000-4000-8000-0000064100f'||
         case n when 4 then 4 else n end)::uuid
  from generate_series(1, 4) n;
insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution, matched_at)
values
 ('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100e1','00000000-0000-4000-8000-0000064100f1',12000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100e2','00000000-0000-4000-8000-0000064100f2',12000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100e3','00000000-0000-4000-8000-0000064100f3',12000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100e4','00000000-0000-4000-8000-0000064100f4',6000,'exact','2026-03-20 10:00+00'),
 ('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100e4','00000000-0000-4000-8000-0000064100f5',6000,'exact','2026-03-20 10:00+00');

insert into public.bank_statements (id, workspace_id, format, account, currency, source_sha256, period_from, period_to)
values ('00000000-0000-4000-8000-0000064100a9','00000000-0000-4000-8000-0000064100b1','camt053','FR7630006000011234567890189','EUR',
        repeat('a', 64), '2026-03-01', '2026-03-31');
insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date, amount_cents,
                                         currency, reference, line_hash, payment_ledger_id, invoice_id)
select '00000000-0000-4000-8000-0000064100a9', '00000000-0000-4000-8000-0000064100b1', 'FR7630006000011234567890189', n,
       d.booking, d.value, d.cents, 'EUR', d.ref, repeat(n::text, 64), ('00000000-0000-4000-8000-0000064100f'||n)::uuid, d.inv
  from (values
    (1, date '2026-03-18', date '2026-03-17', 12000, 'RF18539007547034', '00000000-0000-4000-8000-0000064100e1'::uuid),
    (2, date '2026-03-19', date '2026-03-18', 12000, '',                 '00000000-0000-4000-8000-0000064100e2'::uuid),
    (4, date '2026-03-11', date '2026-03-10', 6000,  'D1',               '00000000-0000-4000-8000-0000064100e4'::uuid),
    (5, date '2026-03-12', date '2026-03-11', 6000,  'D2',               '00000000-0000-4000-8000-0000064100e4'::uuid),
    -- stale: its payment (6) was consumed by no invoice, yet it names C
    (6, date '2026-03-16', date '2026-03-15', 12000, 'STALE',            '00000000-0000-4000-8000-0000064100e3'::uuid)
  ) d(n, booking, value, cents, ref, inv);

create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100d1',
    role, (public.save_book_account('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100d1',
      null, code, code, kind, true, 'manual', 0) ->> 'id')::uuid, '2020-01-01', 0);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;


-- A second space, no statement import: one invoice paid by one payment.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000064100a2','00000000-0000-0000-0000-000000000000','authenticated','authenticated',
        'a2@valuedate.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000064100b2','No statements','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000064100a2','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"bankImport":true}', '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000064100c2','00000000-0000-4000-8000-0000064100b2','00000000-0000-4000-8000-0000064100a2',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000064100d2','00000000-0000-4000-8000-0000064100b2','Studio','222','FR',true);
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals)
values ('00000000-0000-4000-8000-0000064100e9', '00000000-0000-4000-8000-0000064100b2',
        '00000000-0000-4000-8000-0000064100c2', '00000000-0000-4000-8000-0000064100c2', 'INV-Z', 'T',
        jsonb_build_array(jsonb_build_object('kind','subscription','label','s','amount_cents',12000,'vat_percent',20)),
        12000, 'EUR', 'Bo', 'w', 'Flo', 'sig', '2026-03-05 10:00+00', '00000000-0000-4000-8000-0000064100d2', pg_temp.vt());
insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
values ('00000000-0000-4000-8000-0000064100f9', '00000000-0000-4000-8000-0000064100b2',
        '00000000-0000-4000-8000-0000064100c2', 'credit', 'payment', 12000, 'pz', '2026-03', '2026-03-12');
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at, payment_ledger_id)
values ('00000000-0000-4000-8000-0000064100b2', '00000000-0000-4000-8000-0000064100e9', 12000, 'exact',
        '2026-03-20 10:00+00', '00000000-0000-4000-8000-0000064100f9');
insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution, matched_at)
values ('00000000-0000-4000-8000-0000064100b2','00000000-0000-4000-8000-0000064100e9','00000000-0000-4000-8000-0000064100f9',
        12000,'exact','2026-03-20 10:00+00');

-- The table row of [p_invoice] as to_jsonb renders it, and the snapshot's
-- delivered match row of it.
create function pg_temp.table_row(p_invoice uuid) returns jsonb language sql as $$
  select to_jsonb(m) from public.invoice_matches m where m.invoice_id = p_invoice
$$;
create function pg_temp.snap_row(p_setting text, p_invoice uuid) returns jsonb language sql as $$
  select r from jsonb_array_elements(current_setting(p_setting)::jsonb -> 'matches') r
   where r ->> 'invoice_id' = p_invoice::text
$$;
create function pg_temp.receipt(p_number text) returns jsonb language sql as $$
  select p from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
   where p ->> 'document_number' = p_number and p ->> 'kind' = 'receipt'
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064100a1","role":"authenticated"}',true);
set local role authenticated;
select set_config('t.s1', public.accounting_source_snapshot_v1('00000000-0000-4000-8000-0000064100b1',
  '2026-03-01','2026-03-31')::text, true);
select pg_temp.map('customers','411','asset');
select pg_temp.map('bank','512','asset');
select pg_temp.map('revenue','706','income');
select pg_temp.map('vat_output','44571','liability');
select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000064100b1','00000000-0000-4000-8000-0000064100d1',
  '2026-03-01','2026-03-31')::text, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064100a2","role":"authenticated"}',true);
select set_config('t.s2', public.accounting_source_snapshot_v1('00000000-0000-4000-8000-0000064100b2',
  '2026-03-01','2026-03-31')::text, true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064100a1","role":"authenticated"}',true);

select is(current_setting('t.s1')::jsonb ->> 'status', 'ok', 'the snapshot of the space with a statement is delivered');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e1') ->> 'value_date', '2026-03-17',
          'A: the match row carries its line''s value date');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e1') ->> 'bank_reference', 'RF18539007547034',
          'A: and its reference');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e1') - 'value_date' - 'bank_reference',
          pg_temp.table_row('00000000-0000-4000-8000-0000064100e1'),
          'A: every other key of the row is the table row''s');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e1') ->> 'matched_at',
          pg_temp.table_row('00000000-0000-4000-8000-0000064100e1') ->> 'matched_at',
          'A: the match''s own date is not the value date');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e2') ->> 'value_date', '2026-03-18',
          'B: the same amount and day keep their own value date');
select ok(not pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e2') ? 'bank_reference',
          'B: a line without a reference omits the key');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e3')::text,
          pg_temp.table_row('00000000-0000-4000-8000-0000064100e3')::text,
          'C: a payment no line explains, whatever a stale line says, leaves the row byte for byte');
select is(pg_temp.snap_row('t.s1', '00000000-0000-4000-8000-0000064100e4')::text,
          pg_temp.table_row('00000000-0000-4000-8000-0000064100e4')::text,
          'D: two instalment lines are ambiguous and leave the row byte for byte');
-- The table row of space 2 is read as space 2's owner: RLS hides it from a1.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064100a2","role":"authenticated"}',true);
select is(md5(pg_temp.snap_row('t.s2', '00000000-0000-4000-8000-0000064100e9')::text),
          md5(pg_temp.table_row('00000000-0000-4000-8000-0000064100e9')::text),
          'a space without a statement import: the row''s digest is the table row''s');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064100a1","role":"authenticated"}',true);
select is((select count(*)::int from jsonb_array_elements(current_setting('t.s2')::jsonb -> 'matches') r
            where r ?| array['value_date', 'bank_reference']), 0, 'and no row of that space carries a key');
select is(current_setting('t.s1')::jsonb #> '{totals,matches}', '{"count": 4, "paid_cents": 48000}'::jsonb,
          'the match totals are the rows''');
select is(current_setting('t.s1')::jsonb -> 'revisions' ->> 'calendar',
          current_setting('t.s2')::jsonb -> 'revisions' ->> 'calendar',
          'the revisions name the reference data, not the bank lines');
select is(pg_temp.receipt('INV-A') ->> 'value_date', '2026-03-17', 'the postings still carry A''s value date');
select ok(not (pg_temp.receipt('INV-D') ?| array['value_date', 'bank_reference']),
          'and D''s receipt still carries neither key');
select ok(has_function_privilege('authenticated', 'public.bank_line_facts(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.bank_line_facts(uuid, uuid)', 'execute'),
          'the rule is the reader''s (invoker), never anon''s');
select ok(not has_function_privilege('authenticated', 'public.posting_bank_entry(uuid, uuid, jsonb)', 'execute'),
          'a member still cannot call the posting helper');

select * from finish();
rollback;
