-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2361 (0423): the tax of a Canadian invoice as components. The catalogue
-- as data (GST, HST, GST + QST, the legacy GST + PST), the split of a total
-- to the cent (CAD 1 000.00 -> GST 50.00 + QST 99.75, the QST on the price
-- without the GST), the components adding up to the tax whatever the cents,
-- nothing for any other country, and a real create_invoice of a German
-- seller whose vat_totals carry no `components` key. The Canadian issue
-- itself waits for the gate that the last slice of the issue lifts. Rolled
-- back.
begin;
select plan(17);

select is(public.vat_percent_components('CA', 5) -> 0 ->> 'scheme', 'GST', 'AB BC MB NT NU SK YT: GST alone');
select is(jsonb_array_length(public.vat_percent_components('CA', 5)), 1, 'one component');
select is(public.vat_percent_components('CA', 13) -> 0 ->> 'scheme', 'HST', 'Ontario: HST 13');
select is(public.vat_percent_components('CA', 14) -> 0 ->> 'scheme', 'HST', 'Nova Scotia: HST 14');
select is(public.vat_percent_components('ca', 15) -> 0 ->> 'scheme', 'HST', 'NB NL PE: HST 15, the country in any case');
select is((select string_agg(c ->> 'scheme', '+' order by o) from jsonb_array_elements(
             public.vat_percent_components('CA', 14.975)) with ordinality t(c, o)), 'GST+QST', 'Quebec: GST then QST');
select is((select string_agg(c ->> 'scheme', '+' order by o) from jsonb_array_elements(
             public.vat_percent_components('CA', 12)) with ordinality t(c, o)), 'GST+PST', 'a legacy GST+PST row splits into its two taxes');
select ok(public.vat_percent_components('CA', 7.5) is null, 'a rate the catalogue does not know is not split');
select ok(public.vat_percent_components('DE', 14.975) is null, 'no other country is split');

-- The acceptance: CAD 1 000.00 -> GST 50.00, QST 99.75, 1 149.75.
select is((select string_agg((c ->> 'tax_cents') || '/' || (c ->> 'base_cents'), ' ' order by o)
             from jsonb_array_elements(public.vat_components_entry('CA', 14.975, 100000, 14975) -> 'components')
                  with ordinality t(c, o)),
          '5000/100000 9975/100000', 'Quebec: 50.00 + 99.75, both on 1 000.00');
select is((select string_agg((c ->> 'tax_cents'), ' ' order by o)
             from jsonb_array_elements(public.vat_components_entry('CA', 14.975, 2899, 434) -> 'components')
                  with ordinality t(c, o)),
          '145 289', 'an odd net: 1.45 + 2.89 = the 4.34 of the invoice');
select is((select sum((c ->> 'tax_cents')::int)::int from jsonb_array_elements(
             public.vat_components_entry('CA', 12, 92412, 11089) -> 'components') c),
          11089, 'the last component takes the rounding remainder');
select is(public.vat_components_entry('FR', 14.975, 100000, 14975), '{}'::jsonb, 'nothing for a French seller');
select is(public.vat_components_entry('CA', 7.5, 96280, 7221), '{}'::jsonb, 'nothing for an unknown rate');
select is(public.vat_components_entry('CA', 0, 103501, 0), '{}'::jsonb, 'nothing for a zero rate');

-- A real issue: a German seller is unchanged, no components key.
create or replace function pg_temp.de_seller() returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@ca2361.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@ca2361.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags,invoice_legal)
   values ('DE 2361', 'DE', 'EUR', 'Europe/Berlin', uo, 'Hauptstr. 1', 'Berlin', '10115',
           'vat_registered', 'DE123456789', '', '{"invoicing":true}', '{}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,0,'2026-01-01','business') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Standard 19 %',19,true);
  update public.profiles set first_name = 'Synthetic', last_name = 'Customer', company = 'Customer GmbH',
         country_code='DE', street = 'Marktstr. 2', city = 'Hamburg', postal_code='20095' where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',11900,'Desk licence','2026-09',19);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return mm;
end;
$seed$;
select set_config('ca.de', pg_temp.de_seller()::text, true);
select lives_ok($q$select public.create_invoice((select workspace_id from public.members where id = current_setting('ca.de')::uuid),
                                                 current_setting('ca.de')::uuid, '2026-09')$q$,
                'a German seller still issues');
select is((select (i.vat_totals -> 0) ? 'components' from public.invoices i
            where i.member_id = current_setting('ca.de')::uuid and i.period = '2026-09'),
          false, 'and its total carries no components key');
select * from finish();
rollback;
