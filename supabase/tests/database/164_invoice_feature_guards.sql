-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1917: feature-off issuing and requests refuse under the authenticated
-- role; readiness explains it, while whole-month charges and history survive.
begin;
select plan(14);
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
insert into public.validation_policies(workspace_id,event_type,required_count)
 values (current_setting('deskilo.pilot.ws')::uuid,'invoice_issue',1);
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-08')$$,'positive control: whole-month invoice issues');
select set_config('deskilo.pilot.before',(select md5(to_jsonb(i)::text) from public.invoices i
 where member_id=current_setting('deskilo.pilot.m')::uuid),true);
select public.set_feature_flags(current_setting('deskilo.pilot.ws')::uuid,
 '{"subscriptionInvoices":false,"usageInvoices":false}');
select is(public.invoice_issue_readiness(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-11','subscription'),array['invoice_feature_disabled'],
 'disabled advance invoices have a readable refusal before submission');
select throws_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-11',null,false,'subscription')$$,
 'DKI01','invoice_essentials_missing','disabled subscription cannot issue directly');
select throws_ok($$select public.request_invoice_issue(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-12','subscription')$$,
 'DKI01','invoice_essentials_missing','disabled subscription cannot request approval either');
select throws_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-09',null,false,'usage')$$,
 'DKI01','invoice_essentials_missing','twin: disabled usage invoice cannot issue');
select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-09')$$,'whole-month invoice remains available with split invoices off');
select public.set_feature_flags(current_setting('deskilo.pilot.ws')::uuid,'{"invoicing":false}');
select throws_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-10')$$,
 'DKI01','invoice_essentials_missing','twin: disabled parent also refuses whole-month issuing');
select is((select md5(to_jsonb(i)::text) from public.invoices i
 where member_id=current_setting('deskilo.pilot.m')::uuid and period='2026-08'),
 current_setting('deskilo.pilot.before'),'historical invoice content remains identical');
select is((select count(*)::int from public.events where workspace_id=current_setting('deskilo.pilot.ws')::uuid
 and type='invoice_issue'),0,'refusal leaves no misleading approval request');
select is((public.member_statement(current_setting('deskilo.pilot.m')::uuid,'2026-09')->>'fee_cents')::int,
 3500,'ordinary statements remain readable');
select public.set_feature_flags(current_setting('deskilo.pilot.ws')::uuid,
 '{"invoicing":true,"subscriptionInvoices":true}');
select lives_ok($$select public.create_invoice(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-11',null,false,'subscription')$$,
 'positive control: explicitly enabled subscription issuing remains supported');
select is((public.request_invoice_issue(current_setting('deskilo.pilot.ws')::uuid,
 current_setting('deskilo.pilot.m')::uuid,'2026-12','subscription')->>'pending')::boolean,true,
 'positive control: enabled invoice can enter the configured approval flow');
select is((select count(*)::int from public.events where workspace_id=current_setting('deskilo.pilot.ws')::uuid
 and type='invoice_issue' and status='pending'),1,'exactly the permitted approval request persists');
select is((select count(*)::int from public.invoices where member_id=current_setting('deskilo.pilot.m')::uuid),3,
 'only the three permitted invoices persist');
reset role;
select * from finish();
rollback;
