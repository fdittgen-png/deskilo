-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2365 / 9999: a refunded credit note is money OUT in the books. INV-R
-- (60.00 at 20 %) is paid 60.00; CN-R credits it in full and is refunded
-- through `settle_credit_invoice`'s match (resolution `refunded`, the 60.00
-- paid back, positive, 0436). The refund posts Dr customers / Cr bank, kind
-- `refund`, on its day; nothing is written off; the member's account nets to
-- zero over the four entries, and the bank holds nothing of the pair.
begin;
select plan(7);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000009999a1','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a1@refund-postings.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000009999b1','Refund postings','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000009999a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}', '{"vat_tax_point":"invoice","vat_exigibility":"invoice"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000009999c1','00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999a1',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id,country_code,is_default) values
 ('00000000-0000-4000-8000-0000009999d1','00000000-0000-4000-8000-0000009999b1','Atelier','111','FR',true);

insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, issued_at, site_id, vat_totals) values
 ('00000000-0000-4000-8000-0000009999e1','00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999c1',
  '00000000-0000-4000-8000-0000009999c1','INV-R','T',
  jsonb_build_array(jsonb_build_object('kind','subscription','label','Desk','amount_cents',6000,'vat_percent',20)),
  6000,'EUR','Ana','w','Flo','sig','2026-05-05 10:00+00','00000000-0000-4000-8000-0000009999d1',
  jsonb_build_array(jsonb_build_object('percent',20,'category','S','gross_cents',6000,'net_cents',5000,'vat_cents',1000))),
 ('00000000-0000-4000-8000-0000009999e2','00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999c1',
  '00000000-0000-4000-8000-0000009999c1','CN-R','T',
  jsonb_build_array(jsonb_build_object('kind','adjustment','label','Desk','amount_cents',-6000,'vat_percent',20)),
  -6000,'EUR','Ana','w','Flo','sig','2026-06-05 10:00+00','00000000-0000-4000-8000-0000009999d1',
  jsonb_build_array(jsonb_build_object('percent',20,'category','S','gross_cents',-6000,'net_cents',-5000,'vat_cents',-1000)));
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at) values
 ('00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999e1',6000,'exact','2026-05-20 10:00+00'),
 ('00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999e2',6000,'refunded','2026-06-10 10:00+00');

create function pg_temp.acc(code text, kind text) returns text language sql as $$
  select public.save_book_account('00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999d1',
    null, code, code, kind, true, 'manual', 0) ->> 'id';
$$;
create function pg_temp.map(role text, code text, kind text) returns jsonb language sql as $$
  select public.save_book_mapping('00000000-0000-4000-8000-0000009999b1','00000000-0000-4000-8000-0000009999d1',
    role, pg_temp.acc(code, kind)::uuid, '2020-01-01', 0);
$$;
create function pg_temp.lines(p_number text, p_kind text) returns text language sql as $$
  select string_agg((l ->> 'account_code') || ':' ||
           case when (l ->> 'debit_cents')::bigint > 0 then 'D' || (l ->> 'debit_cents') else 'C' || (l ->> 'credit_cents') end,
           ',' order by (l ->> 'account_code') collate "C", n)
    from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
         jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
   where p ->> 'document_number' = p_number and p ->> 'kind' = p_kind;
$$;
create function pg_temp.net(p_code text) returns bigint language sql as $$
  select coalesce(sum((l ->> 'debit_cents')::bigint - (l ->> 'credit_cents')::bigint), 0)
    from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p,
         jsonb_array_elements(p -> 'lines') l
   where l ->> 'account_code' = p_code;
$$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000009999a1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.map('customers','411','asset');
select pg_temp.map('bank','512','asset');
select pg_temp.map('revenue','706','income');
select pg_temp.map('vat_output','44571','liability');
select pg_temp.map('write_off','654','expense');

select set_config('t.r', public.compute_postings('00000000-0000-4000-8000-0000009999b1',
  '00000000-0000-4000-8000-0000009999d1', '2026-01-01', '2026-12-31')::text, true);

select is(pg_temp.lines('CN-R','refund'), '411:D6000,512:C6000',
  'the refunded credit note pays the member back: customers debited, bank credited');
select is(pg_temp.lines('CN-R','receipt'), null, 'and is no receipt');
select is(pg_temp.lines('INV-R','receipt'), '411:C6000,512:D6000', 'the invoice''s payment stays a receipt');
select is(pg_temp.lines('CN-R','write_off'), null, 'the refund leaves nothing open to write off');
select ok((select bool_and((select sum((l ->> 'debit_cents')::bigint) = sum((l ->> 'credit_cents')::bigint)
                              from jsonb_array_elements(p -> 'lines') l))
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'postings') p), 'every entry balances');
select is(pg_temp.net('411'), 0::bigint, 'the member''s account nets to zero over the year');
select is(pg_temp.net('512'), 0::bigint, 'the bank holds nothing of the pair: 60.00 in, 60.00 out');

select * from finish();
rollback;
