-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2365 / 0518: the posting engine over the seeded year of the Dart rules
-- (test/features/money/posting_rules_test.dart), same entries to the cent:
-- INV-1 at 20 % and 5.5 % with a netted payment (40.00) and a netted
-- expense (30.00), paid 155.50; INV-2 part-paid; INV-3 paid 60.00 and the
-- rest written off; CN-1 a credit note. Every entry balances; the reduced
-- rate books to its qualified accounts; a period keeps only its own events;
-- an issuer with no chart is blocked with the role named; a plain member
-- reads nothing.
begin;
select plan(13);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002365'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@postings.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000002365b1','Postings','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002365a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002365c1','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002365c2','00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a2',false,false,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code) values
 ('00000000-0000-4000-8000-0000002365d1','00000000-0000-4000-8000-0000002365b1','Atelier','111','FR'),
 ('00000000-0000-4000-8000-0000002365d2','00000000-0000-4000-8000-0000002365b1','Annexe','222','FR');

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
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at, writeoff_at) values
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e1',15550,'exact','2026-03-20 10:00+00',null),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e2',12000,'under_accepted','2026-04-20 10:00+00',null),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365e3',6000,'under_accepted','2026-05-20 10:00+00','2026-05-25 10:00+00');

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

select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-01-01', '2026-12-31')::text, true);

select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'postings'), 10, 'the year is ten entries');
select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'blockers'), 0, 'with the full chart nothing blocks');
select ok((select bool_and((select sum((l ->> 'debit_cents')::bigint) = sum((l ->> 'credit_cents')::bigint)
                              from jsonb_array_elements(p -> 'lines') l))
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p), 'every entry balances');
select is(pg_temp.lines('INV-1','invoice'), '411:D22550,706:C10000,44571:C2000,7061:C10000,445712:C550',
  'INV-1 per rate group; the reduced rate on its qualified accounts');
select is(pg_temp.lines('INV-1','receipt','2026-03-05'), '512:D4000,411:C4000', 'its netted payment is money in on the invoice day');
select is(pg_temp.lines('INV-1','expense'), '625:D3000,411:C3000', 'its netted expense is one purchase entry, never the bank');
select is(pg_temp.lines('INV-1','receipt','2026-03-20'), '512:D15550,411:C15550', 'the receipt is dated on its match');
select is(pg_temp.lines('INV-3','write_off'), '654:D3334,44571:D666,411:C4000', 'INV-3 written off with 6.66 of output tax regularised');
select is(pg_temp.lines('CN-1','credit_note'), '411:C5000,706:D4167,44571:D833', 'CN-1 mirrors an invoice');

select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-04-01', '2026-04-30') -> 'postings'), 2,
  'April keeps only its own events: INV-2 and its receipt');
select is((public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d2', '2026-01-01', '2026-12-31') -> 'blockers' -> 0 ->> 'block'), 'unmappedRole',
  'an issuer with no chart is blocked, the role named');
select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d2', '2026-01-01', '2026-12-31') -> 'postings' -> 0 -> 'lines'), 0,
  'and posts no guessed line');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002365a2","role":"authenticated"}',true);
select throws_ok($$select public.compute_postings('00000000-0000-4000-8000-0000002365b1',
  '00000000-0000-4000-8000-0000002365d1', '2026-01-01', '2026-12-31')$$, '42501', null, 'a plain member reads no books');

select * from finish();
rollback;
