-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2867 (0539) and #2869 (0545): each step the server verifies from a
-- table of its own is open until that table holds its evidence, and ready
-- once it does — a positive and a negative case per step. A configurer
-- sets an optional step aside and takes it back; a manual step is marked
-- done; a required verified step, a ready one and an unknown one cannot be
-- set aside; someone who does not configure the space cannot either.
begin;
select plan(31);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002868'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@step-evidence.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules,feature_flags)
values('00000000-0000-4000-8000-0000002868b1','Step evidence','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002868a1','dev','{"open_weekdays":[1,2,3,4,5]}',
       '{"moneyTab":true,"services":true,"kioskMode":true,"purchases":true,"workspaceBranding":true,"publicListings":true,"invoicing":true,"vatManagement":true,"numberSequences":true,"invoicePdfTemplate":true,"accountingBook":true,"dunning":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002868c1','00000000-0000-4000-8000-0000002868b1','00000000-0000-4000-8000-0000002868a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002868c2','00000000-0000-4000-8000-0000002868b1','00000000-0000-4000-8000-0000002868a2',false,false,'active');

create function pg_temp.state(p_step text) returns text language sql as $$
  select s->>'state' from jsonb_array_elements(public.workspace_setup_status('00000000-0000-4000-8000-0000002868b1')->'steps') s
   where s->>'step' = p_step
$$;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002868a1","role":"authenticated"}',true);

-- Before: nothing the steps verify exists.
select is(pg_temp.state('services'), 'needs_configuration', 'services: none active yet');
select is(pg_temp.state('kiosk'), 'needs_configuration', 'kiosk: no kiosk member yet');
select is(pg_temp.state('purchases'), 'needs_configuration', 'purchases: no supplier yet');
select is(pg_temp.state('look'), 'needs_configuration', 'look: no branding yet');
select is(pg_temp.state('public_page'), 'needs_configuration', 'public page: none yet');
select is(pg_temp.state('vat'), 'blocked', 'vat: no rate yet, and it waits for the legal identity');
select is(pg_temp.state('numbering'), 'blocked', 'numbering: no sequence yet');
select is(pg_temp.state('documents'), 'blocked', 'documents: no design yet');
select is(pg_temp.state('accounting'), 'blocked', 'accounting: no book profile yet, and it waits for VAT');
select is(pg_temp.state('reminders'), 'needs_configuration', 'reminders: no dunning rules yet');

-- The evidence, row by row.
insert into public.services(workspace_id,name) values ('00000000-0000-4000-8000-0000002868b1','Coffee');
insert into public.members(workspace_id,user_id,is_owner,is_admin,status,is_kiosk) values
 ('00000000-0000-4000-8000-0000002868b1','00000000-0000-4000-8000-0000002868a3',false,false,'active',true);
insert into public.suppliers(workspace_id,supplier_number,name) values ('00000000-0000-4000-8000-0000002868b1','S1','Landlord');
update public.workspaces set branding = '{"seed_color":"#3366CC"}', invoice_pdf_template = '{"header":[]}',
       dunning_rules = '{"levels":[]}'
 where id = '00000000-0000-4000-8000-0000002868b1';
insert into public.workspace_public_pages(workspace_id) values ('00000000-0000-4000-8000-0000002868b1');
insert into public.vat_rates(workspace_id,label,percent) values ('00000000-0000-4000-8000-0000002868b1','Normal',20);
insert into public.number_sequences(workspace_id,journal) values ('00000000-0000-4000-8000-0000002868b1','invoice');
insert into public.sites(id,workspace_id,name) values ('00000000-0000-4000-8000-0000002868e1','00000000-0000-4000-8000-0000002868b1','Main')
  on conflict do nothing;
insert into public.book_profiles(workspace_id,issuer_site_id,functional_currency,fiscal_year_start_month,
       fiscal_year_start_day,accounting_basis,effective_from)
select '00000000-0000-4000-8000-0000002868b1', id, 'EUR', 1, 1, 'accrual', '2026-01-01'
  from public.sites where workspace_id = '00000000-0000-4000-8000-0000002868b1' limit 1;

select is(pg_temp.state('services'), 'ready', 'services: ready with an active service');
select is(pg_temp.state('kiosk'), 'ready', 'kiosk: ready with an active kiosk member');
select is(pg_temp.state('purchases'), 'ready', 'purchases: ready with a supplier');
select is(pg_temp.state('look'), 'ready', 'look: ready with a branding');
select is(pg_temp.state('public_page'), 'ready', 'public page: ready once it exists');
select is(pg_temp.state('vat'), 'ready', 'vat: ready with a rate');
select is(pg_temp.state('numbering'), 'ready', 'numbering: ready with a sequence');
select is(pg_temp.state('documents'), 'ready', 'documents: ready with a design');
select is(pg_temp.state('accounting'), 'ready', 'accounting: ready with a book profile');
select is(pg_temp.state('reminders'), 'ready', 'reminders: ready with dunning rules');

-- 0545: the guide's own actions.
select is(pg_temp.state('recovery'), 'needs_configuration', 'recovery starts open');
select lives_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002868b1','recovery')$$,
  'an optional open step can be set aside');
select is(pg_temp.state('recovery'), 'deferred', 'and then reads deferred, never ready');
select throws_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002868b1','recovery')$$,
  '22023', null, 'a deferred step has nothing left to set aside');
select ok(public.clear_setup_step_acknowledgement('00000000-0000-4000-8000-0000002868b1','recovery'),
  'taking it back removes the acknowledgement');
select is(pg_temp.state('recovery'), 'needs_configuration', 'and the step is open again');
select lives_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002868b1','new_members')$$,
  'a manual step can be marked done');
select is(pg_temp.state('new_members'), 'ready', 'and then reads ready');
select throws_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002868b1','places')$$,
  '22023', null, 'a required step the server verifies cannot be set aside');
select throws_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002868b1','nope')$$,
  '22023', null, 'an unknown step is refused');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002868a2","role":"authenticated"}',true);
select throws_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002868b1','recovery')$$,
  '42501', null, 'someone who does not configure the space cannot set a step aside');

select * from finish();
rollback;
