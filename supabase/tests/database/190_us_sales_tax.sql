-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2362 (0434): a seller in the United States issues in sales-tax mode. One real
-- create_invoice per scene against a seller whose country's gate says
-- `sales_tax` (the fixture sets the row itself): the tax is ADDED to a net
-- price, per jurisdiction of the site's postal code and rounded per invoice
-- (taxable service USD 100.00 at 4 + 4.5 + 0.375 % -> 4.00 + 4.50 + 0.38 =
-- 8.88), a licence to occupy space stays outside the tax, a customer's
-- certificate takes the taxable line out and is cited on the invoice, and
-- the refusals (no rate for the ZIP code, a kind of line nobody classified,
-- the feature off, another currency). Then the shapes of the new rows and who
-- may write a certificate and who reads it. Every rate here is a fixture of
-- this file: none ships. Rolled back.
begin;
select plan(29);

-- The supply class of a ledger line is stamped from the service of its event;
-- the fixtures state it themselves.
alter table public.ledger_entries disable trigger ledger_entries_supply_class;

-- The gate row the last slice seeds: written here so the file proves the mode
-- with or without it.
delete from public.tax_reference where domain = 'issuing_gate' and country = 'US';
insert into public.tax_reference(domain, country, key, valid_from, value, source, confirmed)
values ('issuing_gate', 'US', 'gate', '1900-01-01',
        '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"USD","tax_system":"sales_tax"}',
        'fixture of 190_us_sales_tax.sql', false);
-- A ZIP code with three jurisdictions, one with a single state tax, one with none entered.
insert into public.tax_reference(domain, country, key, valid_from, value, source, confirmed)
values ('sales_tax', 'US', '10001', '2026-01-01',
        '{"state":"NY","components":[{"level":"state","label":"New York State","percent":4},{"level":"city","label":"New York City","percent":4.5},{"level":"district","label":"MCTD","percent":0.375}]}',
        'fixture of 190_us_sales_tax.sql', false),
       ('sales_tax', 'US', '94105', '2026-01-01',
        '{"state":"CA","components":[{"level":"state","label":"California","percent":7.25}]}',
        'fixture of 190_us_sales_tax.sql', false),
       ('taxability', 'US', 'NY:service', '2026-01-01', '{"status":"taxable"}', 'fixture of 190_us_sales_tax.sql', false),
       ('taxability', 'US', 'NY:package', '2026-01-01', '{"status":"exempt"}', 'fixture of 190_us_sales_tax.sql', false);

create or replace function pg_temp.seller(
  tag text, postal text, currency text default 'USD', flags text default '{"invoicing":true,"salesTax":true}'
) returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@us2362.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@us2362.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,feature_flags,invoice_legal)
   values ('US 2362 ' || tag, 'US', currency, 'America/New_York', uo, '1 Broadway', 'New York', postal,
           'not_subject', flags::jsonb, '{}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,0,'2026-01-01','business') returning id into mm;
  update public.profiles set first_name = 'Synthetic', last_name = 'Customer', company = 'Customer LLC',
         country_code='US', street = '200 Main St', city = 'Albany', postal_code='12207'
   where id = um;
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return mm;
end;
$seed$;

create or replace function pg_temp.charge(mm uuid, category text, cents int, supply text, descr text)
returns void language sql as $q$
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,supply_class)
  select workspace_id, id, 'charge', category, cents, descr, '2026-09', supply
    from public.members where id = mm;
$q$;

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

-- ── the shapes ────────────────────────────────────────────────────────
select ok(public.tax_reference_valid('sales_tax', '{"state":"NY","components":[{"level":"state","label":"NY","percent":4}]}'),
          'a sales tax row: a state and its components');
select ok(not public.tax_reference_valid('sales_tax', '{"state":"NY","components":[]}'),
          'a sales tax row without a component is refused');
select ok(not public.tax_reference_valid('sales_tax', '{"state":"NY","components":[{"level":"planet","label":"NY","percent":4}]}'),
          'a component of an unknown level is refused');
select ok(not public.tax_reference_valid('sales_tax', '{"state":"NY","components":[{"level":"state","label":"NY","percent":"4"}]}'),
          'a percent that is a string is refused, not cast');
select ok(public.tax_reference_valid('taxability', '{"status":"exempt"}')
          and not public.tax_reference_valid('taxability', '{"status":"maybe"}'),
          'a taxability row: three answers, no fourth');
select ok(not public.tax_reference_valid('issuing_gate',
          '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"tax_system":"gst"}'),
          'a gate names its tax system as vat or sales_tax only');

-- ── a taxable service, a licence to occupy space ──────────────────────
select set_config('us.ny', pg_temp.seller('ny', '10001')::text, true);
select pg_temp.charge(current_setting('us.ny')::uuid, 'service', 10000, 'general', 'Printing');
select pg_temp.charge(current_setting('us.ny')::uuid, 'adjustment', 20000, 'property', 'Desk licence');
select is(pg_temp.issue(current_setting('us.ny')::uuid), '', 'a New York seller issues');
select is((pg_temp.invoice_of(current_setting('us.ny')::uuid)).total_cents, 30888,
          'the total is the net 300.00 plus 8.88 of tax');
select is((select string_agg(c ->> 'name' || ':' || (c ->> 'tax_cents'), ' ' order by o)
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.ny')::uuid)).vat_totals -> 0 -> 'components')
                  with ordinality t(c, o)),
          'New York State:400 New York City:450 MCTD:38', 'the tax is stated apart per jurisdiction, rounded on the net');
select is((pg_temp.invoice_of(current_setting('us.ny')::uuid)).vat_totals -> 0 ->> 'net_cents', '10000',
          'on a net price of 100.00');
select is((select string_agg(t ->> 'category' || ':' || (t ->> 'net_cents'), ' ' order by o)
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.ny')::uuid)).vat_totals) with ordinality x(t, o)),
          'S:10000 O:20000', 'the licence to occupy space is outside the tax');
select is((select string_agg((l ->> 'net_cents') || '/' || (l ->> 'amount_cents'), ',' order by l ->> 'kind')
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.ny')::uuid)).lines) l),
          '20000/20000,10000/10888', 'a line quotes its net price and carries it with its tax');
select is((select sum((l ->> 'amount_cents')::int)::int
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.ny')::uuid)).lines) l),
          (pg_temp.invoice_of(current_setting('us.ny')::uuid)).total_cents,
          'and the lines add up to the total, as on every other invoice');
select is((pg_temp.invoice_of(current_setting('us.ny')::uuid)).parties -> 'seller' ->> 'vat_id', '',
          'no VAT number is asked or stated');

-- ── a certificate takes the taxable line out of the tax ───────────────
select set_config('us.cert', pg_temp.seller('cert', '10001')::text, true);
select pg_temp.charge(current_setting('us.cert')::uuid, 'service', 10000, 'general', 'Printing');
select pg_temp.charge(current_setting('us.cert')::uuid, 'adjustment', 20000, 'property', 'Desk licence');
select ok(public.set_tax_exemption_certificate(
            (select workspace_id from public.members where id = current_setting('us.cert')::uuid),
            current_setting('us.cert')::uuid, 'nonprofit', 'NY', 'ST-119.1', '2026-01-01', null, '') is not null,
          'the owner records a nonprofit certificate for New York');
select is(pg_temp.issue(current_setting('us.cert')::uuid), '', 'an exempt customer is invoiced');
select is((pg_temp.invoice_of(current_setting('us.cert')::uuid)).total_cents, 30000, 'without any tax');
select is((select string_agg(t ->> 'category' || ':' || coalesce(t ->> 'exemption_basis', ''), ' ' order by o)
             from jsonb_array_elements((pg_temp.invoice_of(current_setting('us.cert')::uuid)).vat_totals) with ordinality x(t, o)),
          'E:certificate O:', 'the taxable line is exempt by certificate');
select is((pg_temp.invoice_of(current_setting('us.cert')::uuid)).parties -> 'buyer' -> 'exemption_certificate' ->> 'number',
          'ST-119.1', 'the invoice cites the certificate');

-- ── a state law exemption ─────────────────────────────────────────────
select set_config('us.pkg', pg_temp.seller('pkg', '10001')::text, true);
select pg_temp.charge(current_setting('us.pkg')::uuid, 'package', 5000, 'property', 'Pack of days');
select is(pg_temp.issue(current_setting('us.pkg')::uuid), '', 'a kind the state exempts is issued');
select is((pg_temp.invoice_of(current_setting('us.pkg')::uuid)).vat_totals -> 0 ->> 'exemption_basis', 'statute',
          'exempt by the state, not by a certificate');

-- ── the refusals ──────────────────────────────────────────────────────
select ok(pg_temp.issue(pg_temp.seller('norate', '99999')) like '%sales_tax_rate_unset%',
          'a ZIP code nobody entered a rate for is refused');
select set_config('us.unset', pg_temp.seller('unset', '94105')::text, true);
select pg_temp.charge(current_setting('us.unset')::uuid, 'service', 10000, 'general', 'Printing');
select ok(pg_temp.issue(current_setting('us.unset')::uuid) like '%sales_tax_taxability_unset%',
          'a kind of line nobody classified in the state is refused, never guessed');
select set_config('us.off', pg_temp.seller('off', '10001', 'USD', '{"invoicing":true,"salesTax":false}')::text, true);
select pg_temp.charge(current_setting('us.off')::uuid, 'service', 10000, 'general', 'Printing');
select ok(pg_temp.issue(current_setting('us.off')::uuid) like '%seller_country_unsupported%',
          'with the feature off the seller is refused as before');
select set_config('us.eur', pg_temp.seller('eur', '10001', 'EUR')::text, true);
select pg_temp.charge(current_setting('us.eur')::uuid, 'service', 10000, 'general', 'Printing');
select ok(pg_temp.issue(current_setting('us.eur')::uuid) like '%vat_national_currency%',
          'tax in a currency the return is not in is refused');

-- ── who writes a certificate, who reads it ────────────────────────────
select set_config('us.member_user', (select user_id::text from public.members where id = current_setting('us.cert')::uuid), true);
select set_config('us.owner_user', (select user_id::text from public.members
                                     where workspace_id = (select workspace_id from public.members where id = current_setting('us.cert')::uuid)
                                       and is_owner), true);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', current_setting('us.member_user'), 'role','authenticated')::text, true);
select throws_ok(format($t$select public.set_tax_exemption_certificate(%L, %L, 'resale', 'NY', 'X', null, null, '')$t$,
                        (select workspace_id from public.members where id = current_setting('us.cert')::uuid),
                        current_setting('us.cert')),
                 'not allowed', 'a customer cannot write their own certificate');
select is((select count(*)::int from public.tax_exemption_certificates), 1, 'but reads their own');
select set_config('request.jwt.claims', json_build_object('sub', current_setting('us.owner_user'), 'role','authenticated')::text, true);
select is((select count(*)::int from public.tax_exemption_certificates), 1, 'the owner reads the workspace certificates');
select set_config('request.jwt.claims', json_build_object('sub', (select created_by from public.workspaces where name = 'US 2362 ny'), 'role','authenticated')::text, true);
select is((select count(*)::int from public.tax_exemption_certificates), 0, 'an owner of another workspace reads none');
reset role;
select * from finish();
rollback;
