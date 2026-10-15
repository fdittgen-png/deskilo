-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2362 (0434, 0435, 0439, 0440): the journey of a US seller on the gate the migrations
-- seed -- no fixture row opens it. A New York space with the sales tax of its
-- ZIP code and the taxability of its kinds (fixtures of this file: no rate ships)
-- invoices three customers for September: one pays a taxable amenity (USD
-- 100.00) and a desk licence (USD 200.00); one holds a nonprofit certificate;
-- one is a consumer. The invoices show net prices, the tax per jurisdiction
-- under its own name, no VAT field, the certificate of the exempt one; the
-- summary of the period states them. A space in a state nobody classified is
-- refused by name, and a space that is not in this mode is untouched. Rolled
-- back.
begin;
select plan(18);

alter table public.ledger_entries disable trigger ledger_entries_supply_class;
insert into public.tax_reference(domain, country, key, valid_from, value, source, confirmed)
values ('sales_tax', 'US', '10001', '2026-01-01',
        '{"state":"NY","components":[{"level":"state","label":"New York State","percent":4},{"level":"city","label":"New York City","percent":4.5},{"level":"district","label":"MCTD","percent":0.375}]}',
        'fixture of 192_us_issuing.sql', false),
       ('taxability', 'US', 'NY:service', '2026-01-01', '{"status":"taxable"}', 'fixture of 192_us_issuing.sql', false);

select is(public.issuing_gate_of('US') ->> 'supported', 'true', 'the gate of the United States is a seeded row, supported');
select is(public.issuing_gate_of('US') ->> 'tax_system', 'sales_tax', 'in sales-tax mode');
select is(public.issuing_gate_of('US') ->> 'requires_tax_number', 'false', 'with no tax number to state');

create or replace function pg_temp.space(tag text, postal text default '10001') returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  ws uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@us2362j.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,feature_flags,invoice_legal)
   values ('US 2362j ' || tag, 'US', 'USD', 'America/New_York', uo, '1 Broadway', 'New York', postal,
           'not_subject', '{"invoicing":true,"salesTax":true}', '{}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return ws;
end;
$seed$;

create or replace function pg_temp.customer(ws uuid, tag text, capacity text default 'business') returns uuid language plpgsql as $seed$
declare
  um uuid := gen_random_uuid();
  mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@us2362j.test','',now(),now(),now());
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,0,'2026-01-01',capacity) returning id into mm;
  update public.profiles set first_name = 'Synthetic', last_name = 'Customer', company = 'Customer ' || tag,
         country_code='US', street = '200 Main St', city = 'Albany', postal_code='12207'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,supply_class)
   values (ws,mm,'charge','service',10000,'Printing','2026-09','general'),
          (ws,mm,'charge','adjustment',20000,'Desk licence','2026-09','property');
  return mm;
end;
$seed$;

create or replace function pg_temp.issue(mm uuid) returns text language plpgsql as $q$
begin
  perform public.create_invoice((select workspace_id from public.members where id = mm), mm, '2026-09');
  return '';
exception when others then
  return coalesce(sqlerrm, '') || ' ' || coalesce(
    (select '[' || string_agg(x, ',') || ']' from unnest(public.invoice_issue_readiness(
       (select workspace_id from public.members where id = mm), mm, '2026-09')) x), '');
end;
$q$;

create or replace function pg_temp.invoice_of(mm uuid) returns public.invoices language sql as $q$
  select i.* from public.invoices i where i.member_id = mm and i.period = '2026-09';
$q$;

select set_config('us.ws', pg_temp.space('ny')::text, true);
select set_config('us.pay', pg_temp.customer(current_setting('us.ws')::uuid, 'pays')::text, true);
select set_config('us.np', pg_temp.customer(current_setting('us.ws')::uuid, 'nonprofit')::text, true);
select set_config('us.consumer', pg_temp.customer(current_setting('us.ws')::uuid, 'consumer', 'consumer')::text, true);
select public.set_tax_exemption_certificate(current_setting('us.ws')::uuid, current_setting('us.np')::uuid,
                                            'nonprofit', 'NY', 'ST-119.1', '2026-01-01', null, '');

-- ── the invoices ──────────────────────────────────────────────────────
select is(pg_temp.issue(current_setting('us.pay')::uuid), '', 'a New York space issues: the gate is open');
select is((pg_temp.invoice_of(current_setting('us.pay')::uuid)).total_cents, 30888, 'net 300.00 and 8.88 of tax');
select is((select string_agg(c ->> 'name' || ' ' || (c ->> 'percent') || '%: ' || (c ->> 'tax_cents'), '; ' order by o)
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.pay')::uuid)).vat_totals -> 0 -> 'components')
                  with ordinality t(c, o)),
          'New York State 4%: 400; New York City 4.5%: 450; MCTD 0.375%: 38', 'one line per jurisdiction under its own name');
select is((select count(*)::int from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.pay')::uuid)).vat_totals) t
            where t ->> 'category' = 'O' and (t ->> 'net_cents')::int = 20000),
          1, 'the desk licence stays outside the tax');
select is((pg_temp.invoice_of(current_setting('us.pay')::uuid)).parties -> 'seller' ->> 'vat_id', '', 'no VAT number is stated');
select is((pg_temp.invoice_of(current_setting('us.pay')::uuid)).parties -> 'seller' ->> 'vat_regime', 'not_subject', 'under no VAT regime');
select is(pg_temp.issue(current_setting('us.consumer')::uuid), '', 'a consumer is invoiced the same way');
select is((pg_temp.invoice_of(current_setting('us.consumer')::uuid)).total_cents, 30888, 'and pays the same tax');
select is(pg_temp.issue(current_setting('us.np')::uuid), '', 'the nonprofit is invoiced');
select is((pg_temp.invoice_of(current_setting('us.np')::uuid)).total_cents, 30000, 'without any tax');
select is((pg_temp.invoice_of(current_setting('us.np')::uuid)).parties -> 'buyer' -> 'exemption_certificate' ->> 'number',
          'ST-119.1', 'and cites its certificate');

-- ── the summary of the period ─────────────────────────────────────────
select set_config('us.start', (current_date - 1)::text, true);
select is((select base_cents::text || '/' || tax_cents::text || '/' || invoice_count::text
             from public.sales_tax_return(current_setting('us.ws')::uuid, current_date - 1, current_date + 1)
            where kind = 'taxable' and state = 'NY'),
          '20000/1776/2', 'taxed sales and tax collected: two customers pay');
select is((select base_cents::text from public.sales_tax_return(current_setting('us.ws')::uuid, current_date - 1, current_date + 1)
            where kind = 'exempt_certificate' and state = 'NY'),
          '10000', 'the sales the certificate exempted');

-- ── the refusals ──────────────────────────────────────────────────────
select set_config('us.cal', pg_temp.space('cal', '90210')::text, true);
select set_config('us.calc', pg_temp.customer(current_setting('us.cal')::uuid, 'cal')::text, true);
select ok(pg_temp.issue(current_setting('us.calc')::uuid) like '%sales_tax_rate_unset%',
          'a ZIP code with no entered rate is refused by name, never given a national rate');

-- the United States is not the only country: a French seller is untouched
select ok(public.issuing_gate_of('FR') ->> 'tax_system' is null, 'a VAT country gate names no tax system: unchanged');
select * from finish();
rollback;
