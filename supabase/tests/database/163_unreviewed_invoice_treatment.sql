-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1917: unreviewed reverse-charge, export and exemption classifications
-- refuse actual authenticated issuance before numbering. Domestic ordinary
-- charges remain usable; existing invoice snapshots persist.
-- #2354: a buyer abroad is no longer refused as such — a desk is supplied
-- where the building stands, so it carries the seller's VAT (166).
begin;
select plan(11);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000191701';
  um uuid := '00000000-0000-4000-8000-000000191702';
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@pilot1917.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@pilot1917.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,vat_regime,feature_flags)
   values ('Pilot 1917','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120','not_subject','{"invoicing":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  -- 1 % of September's 22 open days × 2 = one included half-day.
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at) values (ws,um,1,'2026-01-01')
   returning id into mm;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  -- Three half-days used: one included, two billed at 10.00.
  insert into public.reservations(workspace_id,member_id,starts_at,ends_at,status,space_label) values
   (ws,mm,'2026-09-07 08:00+02','2026-09-07 12:00+02','completed','desk'),
   (ws,mm,'2026-09-08 08:00+02','2026-09-08 12:00+02','completed','desk'),
   (ws,mm,'2026-09-09 13:00+02','2026-09-09 17:00+02','completed','desk');
  perform set_config('deskilo.pilot.ws', ws::text, false);
  perform set_config('deskilo.pilot.m', mm::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, false);

end;
$seed$;

select pg_temp.seed();

update public.workspaces set vat_regime='vat_registered',vat_id='FR12345678901'
 where id=current_setting('deskilo.pilot.ws')::uuid;
insert into public.vat_rates(workspace_id,label,percent,is_default)
 values (current_setting('deskilo.pilot.ws')::uuid,'Synthetic standard',20,true);
update public.profiles set first_name='Synthetic',last_name='Buyer',country_code='FR',vat_id='FR12345678901',
 street='1 Test Street',city='Berlin',postal_code='10115'
 where id='00000000-0000-4000-8000-000000191702';
update public.members set customer_capacity='business'
 where id=current_setting('deskilo.pilot.m')::uuid;
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-08')$$,'ordinary domestic invoice remains available');
select set_config('deskilo.pilot.invoice_before',(select md5(to_jsonb(i)::text) from public.invoices i
 where member_id=current_setting('deskilo.pilot.m')::uuid),true);
reset role;
update public.profiles set country_code='DE',vat_id='DE123456789'
 where id='00000000-0000-4000-8000-000000191702';
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-09'),'{}'::text[],
 'a foreign VAT ID establishes nothing: the desk keeps the seller''s VAT (#2354)');
select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-09')$$,
 'the cross-border desk invoice is issued with domestic VAT');
select is((select count(*)::int from public.invoices i, jsonb_array_elements(i.vat_totals) t
 where i.member_id=current_setting('deskilo.pilot.m')::uuid and i.period='2026-09'
   and t->>'category'='AE'),0,
 'no reverse charge is inferred from a foreign VAT ID');
reset role;
update public.members set vat_treatment='domestic' where id=current_setting('deskilo.pilot.m')::uuid;
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-10')$$,
 'a domestic override issues a cross-border desk invoice too');
reset role;
update public.members set vat_treatment='export',vat_exemption_reason='Synthetic unreviewed reason'
 where id=current_setting('deskilo.pilot.m')::uuid;
set local role authenticated;
select throws_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-11')$$,'DKI01','invoice_essentials_missing',
 'an unreviewed export selection must not establish export eligibility');
select is((select count(*)::int from public.invoices where member_id=current_setting('deskilo.pilot.m')::uuid),3,
 'export refusal creates no additional invoice');

reset role;
update public.profiles set country_code='FR' where id='00000000-0000-4000-8000-000000191702';
update public.members set vat_treatment='reverse_charge' where id=current_setting('deskilo.pilot.m')::uuid;
set local role authenticated;
select throws_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-11')$$,'DKI01','invoice_essentials_missing',
 'a domestic reverse-charge override cannot bypass the review requirement');
reset role;
update public.members set vat_treatment='exempt' where id=current_setting('deskilo.pilot.m')::uuid;
set local role authenticated;
select throws_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-12')$$,'DKI01','invoice_essentials_missing',
 'a free-text reason is not a reviewed exemption');
select is((select md5(to_jsonb(i)::text) from public.invoices i
 where member_id=current_setting('deskilo.pilot.m')::uuid and period='2026-08'),
 current_setting('deskilo.pilot.invoice_before'),'classification changes never rewrite the earlier invoice');
select is((public.member_statement(current_setting('deskilo.pilot.m')::uuid,'2026-09')->>'fee_cents')::int,3500,
 'the member statement remains usable while issuing is refused');
reset role;
select * from finish();
rollback;
