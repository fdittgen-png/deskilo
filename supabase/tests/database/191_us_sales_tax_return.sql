-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2362 (0439): the sales-tax summary of a period, from invoices a real
-- create_invoice froze. Two customers of one New York space buy the same
-- taxable service (USD 100.00) and a desk licence (USD 200.00); one holds a
-- nonprofit certificate. The summary states, per state and jurisdiction, the
-- taxed sales and the tax collected, the sales a certificate exempted and what
-- is outside the tax -- and nothing of another space, another period or a
-- voided invoice. Rolled back.
begin;
select plan(14);

alter table public.ledger_entries disable trigger ledger_entries_supply_class;
delete from public.tax_reference where domain = 'issuing_gate' and country = 'US';
insert into public.tax_reference(domain, country, key, valid_from, value, source, confirmed)
values ('issuing_gate', 'US', 'gate', '1900-01-01',
        '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"USD","tax_system":"sales_tax"}',
        'fixture of 191_us_sales_tax_return.sql', false),
       ('sales_tax', 'US', '10001', '2026-01-01',
        '{"state":"NY","components":[{"level":"state","label":"New York State","percent":4},{"level":"city","label":"New York City","percent":4.5},{"level":"district","label":"MCTD","percent":0.375}]}',
        'fixture of 191_us_sales_tax_return.sql', false),
       ('taxability', 'US', 'NY:service', '2026-01-01', '{"status":"taxable"}', 'fixture of 191_us_sales_tax_return.sql', false);

create or replace function pg_temp.space(tag text) returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  ws uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@us2362r.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,feature_flags,invoice_legal)
   values ('US 2362r ' || tag, 'US', 'USD', 'America/New_York', uo, '1 Broadway', 'New York', '10001',
           'not_subject', '{"invoicing":true,"salesTax":true}', '{}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  return ws;
end;
$seed$;

create or replace function pg_temp.customer(ws uuid, tag text) returns uuid language plpgsql as $seed$
declare
  um uuid := gen_random_uuid();
  mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@us2362r.test','',now(),now(),now());
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,0,'2026-01-01','business') returning id into mm;
  update public.profiles set first_name = 'Synthetic', last_name = 'Customer', company = 'Customer ' || tag,
         country_code='US', street = '200 Main St', city = 'Albany', postal_code='12207'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,supply_class)
   values (ws,mm,'charge','service',10000,'Printing','2026-09','general'),
          (ws,mm,'charge','adjustment',20000,'Desk licence','2026-09','property');
  return mm;
end;
$seed$;

create or replace function pg_temp.as_owner(ws uuid) returns void language plpgsql as $q$
begin
  perform set_config('request.jwt.claims', json_build_object('sub',
    (select user_id from public.members where workspace_id = ws and is_owner), 'role','authenticated')::text, true);
end;
$q$;

select set_config('us.ws', pg_temp.space('a')::text, true);
select set_config('us.a', pg_temp.customer(current_setting('us.ws')::uuid, 'plain')::text, true);
select set_config('us.b', pg_temp.customer(current_setting('us.ws')::uuid, 'nonprofit')::text, true);
select pg_temp.as_owner(current_setting('us.ws')::uuid);
select public.set_tax_exemption_certificate(current_setting('us.ws')::uuid, current_setting('us.b')::uuid,
                                            'nonprofit', 'NY', 'ST-119.1', '2026-01-01', null, '');
select public.create_invoice(current_setting('us.ws')::uuid, current_setting('us.a')::uuid, '2026-09');
select public.create_invoice(current_setting('us.ws')::uuid, current_setting('us.b')::uuid, '2026-09');

create or replace function pg_temp.line(st text, k text, nm text default '') returns text language sql as $q$
  select coalesce(r.base_cents::text || '/' || r.tax_cents::text || '/' || r.invoice_count::text, 'none')
    from (select 1) d
    left join public.sales_tax_return(current_setting('us.ws')::uuid, current_date - 1, current_date + 1) r
      on r.state = st and r.kind = k and r.name = nm;
$q$;

select is(pg_temp.line('NY', 'taxable'), '10000/888/1', 'taxed sales of 100.00 and 8.88 collected, from the one customer who pays');
select is(pg_temp.line('NY', 'tax', 'New York State'), '10000/400/1', 'the state tax on its base');
select is(pg_temp.line('NY', 'tax', 'New York City'), '10000/450/1', 'the city tax on its base');
select is(pg_temp.line('NY', 'tax', 'MCTD'), '10000/38/1', 'the district tax, rounded on the invoice');
select is(pg_temp.line('NY', 'exempt_certificate'), '10000/0/1', 'the sales a certificate exempted');
select is(pg_temp.line('NY', 'outside'), '40000/0/2', 'the licences to occupy space of both customers, outside the tax');
select is(pg_temp.line('NY', 'exempt_statute'), 'none', 'nothing exempted by the state: no row');
select is((select count(*)::int from public.sales_tax_return(current_setting('us.ws')::uuid, current_date + 1, current_date + 40)),
          0, 'a period without an invoice states nothing');
select is((select sum(tax_cents)::int from public.sales_tax_return(current_setting('us.ws')::uuid, current_date - 1, current_date + 1)
            where kind = 'tax'),
          (select sum((t ->> 'vat_cents')::int)::int from public.invoices i, jsonb_array_elements(i.vat_totals) t
            where i.workspace_id = current_setting('us.ws')::uuid),
          'the jurisdictions add up to the tax of the invoices');

-- a voided invoice leaves the summary
alter table public.invoices disable trigger invoices_no_mutation;
alter table public.invoices disable trigger invoice_legal_freeze;
update public.invoices set voided_at = now() where member_id = current_setting('us.a')::uuid;
alter table public.invoices enable trigger invoices_no_mutation;
alter table public.invoices enable trigger invoice_legal_freeze;
select is(pg_temp.line('NY', 'taxable'), 'none', 'a voided invoice is no longer in the summary');
select is(pg_temp.line('NY', 'outside'), '20000/0/1', 'nor its outside-the-tax sales');

-- who reads it
select set_config('us.other', pg_temp.space('b')::text, true);
select pg_temp.as_owner(current_setting('us.other')::uuid);
select throws_ok(format($t$select * from public.sales_tax_return(%L, current_date - 1, current_date + 1)$t$, current_setting('us.ws')),
                 'not allowed', 'the owner of another space cannot read it');
select set_config('request.jwt.claims', json_build_object('sub', (select user_id from public.members where id = current_setting('us.a')::uuid), 'role','authenticated')::text, true);
select throws_ok(format($t$select * from public.sales_tax_return(%L, current_date - 1, current_date + 1)$t$, current_setting('us.ws')),
                 'not allowed', 'nor a customer of the space');
select pg_temp.as_owner(current_setting('us.ws')::uuid);
select is((select count(*)::int from public.sales_tax_return(current_setting('us.ws')::uuid, current_date - 1, current_date + 1)) > 0,
          true, 'the owner reads it');
select * from finish();
rollback;
