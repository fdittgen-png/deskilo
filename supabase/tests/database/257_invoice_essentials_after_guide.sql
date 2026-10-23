-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2875: after the setup guide's Grow steps, a test invoice raises no
-- invoice_essentials_missing reason. A French space starts as the wizard
-- leaves it (no address, no VAT regime) and is refused, naming the seller
-- address. Then each step writes what its page writes: the legal identity
-- (regime, numbers, address and the printed lines, one row update as the
-- legal identity command sends it), the country's usual rates through
-- set_vat_rates and the invoice series through set_number_sequence, both
-- as the owner. Between the identity and the rates the refusal names the
-- missing rate; after the rates, the server's own dry run
-- (invoice_issue_readiness) finds nothing missing, and create_invoice
-- issues the member's month under the series' number at French VAT.
begin;
select plan(9);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002875'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@grow-guide.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags)
values('00000000-0000-4000-8000-0000002875b1','Grow guide','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002875a1','dev',
       '{"moneyTab":true,"invoicing":true,"vatManagement":true,"numberSequences":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,joined_at) values
 ('00000000-0000-4000-8000-0000002875c1','00000000-0000-4000-8000-0000002875b1','00000000-0000-4000-8000-0000002875a1',true,true,'active','2026-01-01');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,subscription_pct,joined_at) values
 ('00000000-0000-4000-8000-0000002875c2','00000000-0000-4000-8000-0000002875b1','00000000-0000-4000-8000-0000002875a2',false,false,'active',1,'2026-01-01');
delete from public.fee_bands where workspace_id = '00000000-0000-4000-8000-0000002875b1';
insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents)
values ('00000000-0000-4000-8000-0000002875b1',0,100,3500,1000);
update public.profiles set first_name = 'Synthetic', last_name = 'Member'
 where id = '00000000-0000-4000-8000-0000002875a2';

create function pg_temp.readiness() returns text[] language sql as $$
  select public.invoice_issue_readiness('00000000-0000-4000-8000-0000002875b1',
    '00000000-0000-4000-8000-0000002875c2', '2026-09')
$$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002875a1","role":"authenticated"}',true);

-- Before the guide: the server refuses, and says why.
select ok('seller_address' = any(pg_temp.readiness()),
  'before the guide a test invoice is refused, naming the seller address');

-- Legal identity: what the step's Save writes, in one row update.
update public.workspaces
   set vat_regime = 'vat_registered', vat_id = 'FR12345678901', legal_id = '123 456 789 00012',
       street = '1 rue du Guide', city = 'Pézenas', postal_code = '34120',
       invoice_legal = coalesce(invoice_legal, '{}'::jsonb)
         || '{"legal_form":"SAS au capital de 1 000 €","registration":"RCS Béziers 123 456 789"}'::jsonb
 where id = '00000000-0000-4000-8000-0000002875b1';
select ok(not ('seller_address' = any(pg_temp.readiness())),
  'the legal identity answers the seller address');
select ok('vat_rate_unresolved' = any(pg_temp.readiness()),
  'a VAT-registered seller without rates is still refused, naming the rate');

-- VAT: the country's usual rates, as the step offers them (the reference
-- catalogue for FR, the standard rate the default).
select lives_ok($$select public.set_vat_rates('00000000-0000-4000-8000-0000002875b1',
  '[{"label":"Standard 20 %","percent":20,"category":"S","is_default":true,"group_key":"standard"},
    {"label":"Intermédiaire 10 %","percent":10,"category":"S","is_default":false,"group_key":"intermediate"},
    {"label":"Réduit 5,5 %","percent":5.5,"category":"S","is_default":false,"group_key":"reduced"},
    {"label":"Particulier 2,1 %","percent":2.1,"category":"S","is_default":false,"group_key":"super_reduced"}]'::jsonb)$$,
  'the owner stores the usual rates through the VAT step''s write');

-- Numbering: the invoice series, as the step's card saves it.
select lives_ok($$select public.set_number_sequence('00000000-0000-4000-8000-0000002875b1',
  'invoice', 'FA-', '', 'year', 4, 'yearly')$$,
  'the owner stores the invoice series through the numbering step''s write');

-- After the guide: nothing is missing.
select is(pg_temp.readiness(), '{}'::text[],
  'after the guide a test invoice raises no invoice_essentials_missing reason');
select lives_ok($$select public.create_invoice('00000000-0000-4000-8000-0000002875b1',
  '00000000-0000-4000-8000-0000002875c2', '2026-09')$$,
  'and the invoice is issued');
select ok((select number like 'FA-%' from public.invoices
            where member_id = '00000000-0000-4000-8000-0000002875c2'),
  'under the series the numbering step saved');
select is((select string_agg((t->>'category') || ':' || round((t->>'percent')::numeric)::text, ',')
             from public.invoices i, jsonb_array_elements(i.vat_totals) t
            where i.member_id = '00000000-0000-4000-8000-0000002875c2'),
  'S:20', 'at the default rate the VAT step stored');

select * from finish();
rollback;
