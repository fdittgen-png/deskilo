-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0622 (#3152) — the acquisition tax in the books, the same hand-worked
-- entries as acquisition_postings_test.dart. A Swiss space buys two
-- services of CHF 1 000.00 abroad at 8.1 % (tax owed 81.00, Ziffer 383),
-- one fully and one 60 % deductible:
--   aaaaaaaa: Dr 1170 81.00 / Cr 2200 81.00
--   bbbbbbbb: Dr 1170 48.60, Dr 6500 32.40 / Cr 2200 81.00
-- on the expense's tax point (12 March), in the purchases journal.
begin;
select plan(6);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000003152a1','00000000-0000-0000-0000-000000000000',
        'authenticated','authenticated','acq@postings.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000003152b1','Bezug','CH','CHF','Europe/Zurich','00000000-0000-4000-8000-0000003152a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true,"purchases":true,"supplyExpenses":true,
    "inputVat":true,"vatManagement":true,"vatDeclarations":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000003152c1','00000000-0000-4000-8000-0000003152b1','00000000-0000-4000-8000-0000003152a1',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000003152d1','00000000-0000-4000-8000-0000003152b1','Zürich','CHE-123.456.789','CH',true);

-- Two services bought abroad, confirmed on 12 March.
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status,
                           decided_at, created_at) values
 ('aaaaaaaa-0000-4000-8000-000000003152','00000000-0000-4000-8000-0000003152b1','expense','submitted',
  '00000000-0000-4000-8000-0000003152c1','00000000-0000-4000-8000-0000003152c1',
  '{"amount_cents": 100000, "category": "software", "note": "Licence", "vat": {"percent": 8.1, "deductible_pct": 100, "acquisition": true}}',
  'confirmed', '2026-03-12 10:00+00', '2026-03-11 10:00+00'),
 ('bbbbbbbb-0000-4000-8000-000000003152','00000000-0000-4000-8000-0000003152b1','expense','submitted',
  '00000000-0000-4000-8000-0000003152c1','00000000-0000-4000-8000-0000003152c1',
  '{"amount_cents": 100000, "category": "software", "note": "Hosting", "vat": {"percent": 8.1, "deductible_pct": 60, "acquisition": true}}',
  'confirmed', '2026-03-12 11:00+00', '2026-03-11 11:00+00');

create function pg_temp.acc(code text, kind text) returns text language sql as $$
  select public.save_book_account('00000000-0000-4000-8000-0000003152b1','00000000-0000-4000-8000-0000003152d1',
    null, code, code, kind, true, 'manual', 0) ->> 'id';
$$;
create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000003152b1','00000000-0000-4000-8000-0000003152d1',
    role, pg_temp.acc(code, kind)::uuid, '2020-01-01', 0);
$$;
create function pg_temp.lines(p_number text) returns text language sql as $$
  select string_agg((l ->> 'account_code') || ':' ||
           case when (l ->> 'debit_cents')::bigint > 0 then 'D' || (l ->> 'debit_cents') else 'C' || (l ->> 'credit_cents') end,
           ',' order by n)
    from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
         jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
   where p ->> 'document_number' = p_number and p ->> 'kind' = 'acquisition_tax';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- What the return files as acquisition tax, read before the role switch.
select set_config('t.owed', (select sum(a.gross_cents - a.net_cents)::text
  from public.vat_input_amounts('00000000-0000-4000-8000-0000003152b1', '2026-01-01', '2026-12-31') a
 where a.category = 'acquisition'), true);

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003152a1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.map('customers','1100','asset');
select pg_temp.map('vat_input','1170','asset');
select pg_temp.map('vat_output','2200','liability');
select pg_temp.map('expenses','6500','expense');

select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000003152b1',
  '00000000-0000-4000-8000-0000003152d1', '2026-01-01', '2026-12-31')::text, true);

select is(pg_temp.lines('aaaaaaaa'), '1170:D8100,2200:C8100',
  'fully deductible: input against output');
select is(pg_temp.lines('bbbbbbbb'), '1170:D4860,6500:D3240,2200:C8100',
  '60 % deductible: the rest is a cost');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
            where p ->> 'kind' = 'acquisition_tax' and p ->> 'journal' = 'purchases' and p ->> 'date' = '2026-03-12'), 2,
  'both on the tax point, in the purchases journal');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p
            where p ->> 'kind' = 'acquisition_tax'
              and (select sum((l ->> 'debit_cents')::bigint) from jsonb_array_elements(p -> 'lines') l)
               <> (select sum((l ->> 'credit_cents')::bigint) from jsonb_array_elements(p -> 'lines') l)), 0,
  'every acquisition entry balances');
select is((select sum((l ->> 'credit_cents')::bigint)::int
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
                  jsonb_array_elements(p -> 'lines') l
            where p ->> 'kind' = 'acquisition_tax' and l ->> 'account_code' = '2200'),
  current_setting('t.owed')::int,
  'the output credited equals the acquisition tax the return files');
select is(jsonb_array_length(public.compute_postings('00000000-0000-4000-8000-0000003152b1',
  '00000000-0000-4000-8000-0000003152d1', '2026-04-01', '2026-04-30') -> 'postings'), 0,
  'a period without the tax point books none');
reset role;

select * from finish();
rollback;
