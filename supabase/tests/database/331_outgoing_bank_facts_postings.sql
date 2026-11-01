-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 / 0642 -- money out gets the bank statement's value date and
-- reference. Two approved supplier bills, decided by a second admin: F-1
-- paid in two halves (P1 on 2 April, P2 on 3 April), F-2 paid whole (P3 on
-- 6 April). The books are computed before any statement (r0) and after one
-- is imported (r1) whose line L1 became P1 (with a reference) and L3 P3
-- (without one); P2 has no line. P1's and P3's payment entries carry their
-- line's value date (P1 its reference), and nothing else of them changes;
-- P2's entry, the bills and every entry of r0 are byte for byte what they
-- were. A second line naming a payment is refused by the unique index, so
-- the "several lines" case cannot arise. The helper is an invoker function
-- (a stranger reads nothing through it) and not anon's.
begin;
select plan(16);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000064200'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@outgoing.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000064200b1','Money out','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000064200a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"purchases":true,"supplyExpenses":true,
    "scheduledExpenses":true,"inputVat":true,"vatManagement":true,"bankImport":true}',
  '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}'),
 -- a stranger's space: a2 owns it and is nobody in the first
 ('00000000-0000-4000-8000-0000064200b2','Elsewhere','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000064200a2','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"bankImport":true}',
  '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000064200c1','00000000-0000-4000-8000-0000064200b1','00000000-0000-4000-8000-0000064200a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000064200c3','00000000-0000-4000-8000-0000064200b1','00000000-0000-4000-8000-0000064200a3',false,true,'active'),
 ('00000000-0000-4000-8000-0000064200c2','00000000-0000-4000-8000-0000064200b2','00000000-0000-4000-8000-0000064200a2',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000064200d1','00000000-0000-4000-8000-0000064200b1','Atelier','111','FR',true),
 ('00000000-0000-4000-8000-0000064200d2','00000000-0000-4000-8000-0000064200b2','Studio','222','FR',true);
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 ('00000000-0000-4000-8000-0000064200f1','00000000-0000-4000-8000-0000064200b1','1','Fournitures SA','active');
insert into public.bank_statements (id, workspace_id, format, account, currency, source_sha256, period_from, period_to)
values ('00000000-0000-4000-8000-0000064200a9','00000000-0000-4000-8000-0000064200b1','camt053','FR7630006000011234567890189','EUR',
        repeat('b', 64), '2026-04-01', '2026-04-30');

create function pg_temp.acc(code text, kind text) returns text language sql as $$
  select public.save_book_account('00000000-0000-4000-8000-0000064200b1','00000000-0000-4000-8000-0000064200d1',
    null, code, code, kind, true, 'manual', 0) ->> 'id';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000064200b1','00000000-0000-4000-8000-0000064200d1',
    role, pg_temp.acc(code, kind)::uuid, '2020-01-01', 0);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.call(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- An approved bill of [p_gross] (20 %, fully recoverable): drafted and
-- submitted by a1, decided by a3; its purchase id.
create function pg_temp.bill(p_ref text, p_day date, p_gross int) returns text language plpgsql as $$
declare v_id text;
begin
  v_id := pg_temp.call('00000000-0000-4000-8000-0000064200a1',
    format('select public.save_purchase_draft_v1(%L, %L, 0, %L::jsonb)', '00000000-0000-4000-8000-0000064200b1',
      gen_random_uuid(), jsonb_build_object('kind', 'bill', 'supplier_id', '00000000-0000-4000-8000-0000064200f1',
        'original_reference', p_ref, 'original_date', p_day, 'due_on', '2026-05-31', 'payer_kind', 'unpaid',
        'lines', jsonb_build_array(jsonb_build_object('description', 'Paper', 'gross_cents', p_gross,
          'net_cents', p_gross * 5 / 6, 'tax_cents', p_gross / 6, 'tax_rate_percent', 20,
          'recoverable_tax_cents', p_gross / 6, 'nonrecoverable_tax_cents', 0)))::text)) ->> 'purchase_id';
  perform pg_temp.call('00000000-0000-4000-8000-0000064200a1',
    format('select public.submit_purchase_v1(%L, %L, 1, %L)', '00000000-0000-4000-8000-0000064200b1', v_id, gen_random_uuid()));
  perform pg_temp.call('00000000-0000-4000-8000-0000064200a3',
    format('select public.decide_purchase_v1(%L, %L, %s, true, %L, %L)', '00000000-0000-4000-8000-0000064200b1',
      v_id, (select revision from public.purchase_documents where id = v_id::uuid), '', gen_random_uuid()));
  return v_id;
end;
$$;
-- A payment of [p_cents] on [p_day] against [p_bill]'s payable, by a1; its
-- outgoing payment id.
create function pg_temp.pay(p_bill text, p_cents int, p_day date) returns text language plpgsql as $$
declare o public.purchase_obligations;
begin
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000064200a1","role":"authenticated"}', true);
  select * into o from public.purchase_obligations where purchase_id = p_bill::uuid;
  return pg_temp.call('00000000-0000-4000-8000-0000064200a1',
    format('select public.record_supplier_payment_v1(%L, %L, %s, %s, %L, %L, ''bank_transfer'', ''wire'')',
      '00000000-0000-4000-8000-0000064200b1', o.id, p_cents, o.revision, gen_random_uuid(), p_day)) ->> 'payment_id';
end;
$$;
-- The payment-out entry of [p_number] dated [p_day] in the books [p_setting].
create function pg_temp.entry(p_setting text, p_number text, p_day text) returns jsonb language sql as $$
  select p from jsonb_array_elements(current_setting(p_setting)::jsonb -> 'postings') p
   where p ->> 'document_number' = p_number and p ->> 'kind' = 'supplier_payment' and p ->> 'date' = p_day
$$;
-- The books [p_setting] without the payment entries of P1 and P3.
create function pg_temp.rest(p_setting text) returns text language sql as $$
  select jsonb_agg(p order by n)::text
    from jsonb_array_elements(current_setting(p_setting)::jsonb -> 'postings') with ordinality z(p, n)
   where not (p ->> 'kind' = 'supplier_payment' and p ->> 'date' in ('2026-04-02', '2026-04-06'))
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064200a1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.map('customers','411','asset');
select pg_temp.map('bank','512','asset');
select pg_temp.map('revenue','706','income');
select pg_temp.map('vat_output','44571','liability');
select pg_temp.map('expenses','625','expense');
select pg_temp.map('suppliers','401','liability');
select pg_temp.map('vat_input','44566','asset');
select pg_temp.map('vat_pending','44574','liability');

select set_config('t.f1', pg_temp.bill('F-1', '2026-03-10', 12000), true);
select set_config('t.f2', pg_temp.bill('F-2', '2026-03-12', 9000), true);
select set_config('t.p1', pg_temp.pay(current_setting('t.f1'), 6000, '2026-04-02'), true);
select set_config('t.p2', pg_temp.pay(current_setting('t.f1'), 6000, '2026-04-03'), true);
select set_config('t.p3', pg_temp.pay(current_setting('t.f2'), 9000, '2026-04-06'), true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064200a1","role":"authenticated"}',true);
select set_config('t.r0', public.compute_postings('00000000-0000-4000-8000-0000064200b1',
  '00000000-0000-4000-8000-0000064200d1', '2026-01-01', '2026-12-31')::text, true);

-- The statement arrives: L1 became P1 (with a reference), L3 P3 (none).
reset role;
insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date, amount_cents,
                                         currency, reference, line_hash, outgoing_payment_id)
values
 ('00000000-0000-4000-8000-0000064200a9','00000000-0000-4000-8000-0000064200b1','FR7630006000011234567890189', 1,
  '2026-04-02', '2026-04-01', -6000, 'EUR', 'RF71OUT0001', repeat('1', 64), current_setting('t.p1')::uuid),
 ('00000000-0000-4000-8000-0000064200a9','00000000-0000-4000-8000-0000064200b1','FR7630006000011234567890189', 3,
  '2026-04-06', '2026-04-07', -9000, 'EUR', '', repeat('3', 64), current_setting('t.p3')::uuid);
select throws_ok(
  format($$insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date,
           amount_cents, currency, reference, line_hash, outgoing_payment_id)
         values ('00000000-0000-4000-8000-0000064200a9','00000000-0000-4000-8000-0000064200b1','FR7630006000011234567890189', 9,
           '2026-04-02', '2026-04-02', -6000, 'EUR', 'TWICE', repeat('9', 64), %L)$$, current_setting('t.p1')),
  '23505', null, 'a second line naming a payment out is refused: one payment, at most one line');
set local role authenticated;
select set_config('t.r1', public.compute_postings('00000000-0000-4000-8000-0000064200b1',
  '00000000-0000-4000-8000-0000064200d1', '2026-01-01', '2026-12-31')::text, true);

select is(jsonb_array_length(current_setting('t.r1')::jsonb -> 'blockers'), 0, 'with the full chart nothing blocks');
select is(pg_temp.entry('t.r1', 'F-1', '2026-04-02') ->> 'value_date', '2026-04-01',
          'P1: the payment entry carries its line''s value date');
select is(pg_temp.entry('t.r1', 'F-1', '2026-04-02') ->> 'bank_reference', 'RF71OUT0001',
          'P1: and its reference');
select is((pg_temp.entry('t.r1', 'F-1', '2026-04-02') - 'value_date' - 'bank_reference')::text,
          pg_temp.entry('t.r0', 'F-1', '2026-04-02')::text,
          'P1: every other key of the entry, its date and lines included, is what it was');
select is(pg_temp.entry('t.r1', 'F-2', '2026-04-06') ->> 'value_date', '2026-04-07',
          'P3: the value date may follow the payment day');
select ok(not pg_temp.entry('t.r1', 'F-2', '2026-04-06') ? 'bank_reference',
          'P3: a line without a reference omits the key');
select is(pg_temp.entry('t.r1', 'F-1', '2026-04-03')::text, pg_temp.entry('t.r0', 'F-1', '2026-04-03')::text,
          'P2: a payment no line explains keeps its entry byte for byte');
select ok(pg_temp.entry('t.r0', 'F-1', '2026-04-03') is not null, 'and that entry exists');
select is(pg_temp.rest('t.r1'), pg_temp.rest('t.r0'),
          'every other entry, the bills included, is byte for byte what it was');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r0')::jsonb -> 'postings') p
            where p ?| array['value_date', 'bank_reference']), 0, 'before the statement no entry carries a key');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r1')::jsonb -> 'postings') p
            where p ?| array['value_date', 'bank_reference']), 2, 'after it, exactly the two explained payments do');
select is(public.bank_line_out_facts('00000000-0000-4000-8000-0000064200b1', current_setting('t.p1')::uuid),
          '{"value_date": "2026-04-01", "bank_reference": "RF71OUT0001"}'::jsonb,
          'the finance reader asks the rule directly and gets the facts');
-- A stranger (a2 owns another space) reads the rule under its own policies.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064200a2","role":"authenticated"}',true);
select is(public.bank_line_out_facts('00000000-0000-4000-8000-0000064200b1', current_setting('t.p1')::uuid),
          '{}'::jsonb, 'a stranger reads no line through it: the rule is the reader''s (invoker)');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000064200a1","role":"authenticated"}',true);
select ok((select not p.prosecdef from pg_proc p where p.oid = 'public.bank_line_out_facts(uuid, uuid)'::regprocedure)
          and has_function_privilege('authenticated', 'public.bank_line_out_facts(uuid, uuid)', 'execute')
          and not has_function_privilege('anon', 'public.bank_line_out_facts(uuid, uuid)', 'execute'),
          'the helper is an invoker function, a member''s, never anon''s');
select ok(exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'bank_statement_lines_payment'
                  and indexdef like 'CREATE UNIQUE INDEX % (payment_ledger_id) WHERE (payment_ledger_id IS NOT NULL)')
          and exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'bank_statement_lines_outgoing'
                  and indexdef like 'CREATE UNIQUE INDEX % (outgoing_payment_id) WHERE (outgoing_payment_id IS NOT NULL)'),
          'both payment lookups are served by a unique partial index');

select * from finish();
rollback;
