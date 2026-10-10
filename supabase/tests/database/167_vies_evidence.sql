-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2354: a reverse charge needs evidence. A French seller, a German
-- business: the desk keeps French VAT, mail handling is reverse-charged
-- (AE) only once the buyer's number was found valid in VIES, and the
-- consultation number is frozen in the invoice's legal snapshot. VIES
-- down refuses with DKI01 naming vies_unverified; nobody but the
-- service role writes the evidence.
begin;
select plan(13);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000235411';
  um uuid := '00000000-0000-4000-8000-000000235412';
  ws uuid; mm uuid; om uuid; sv uuid; ev uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@vies2354.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@vies2354.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Vies 2354','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
           'vat_registered','FR12345678901','{"invoicing":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01')
   returning id into om;
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01','business') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Synthetic standard',20,true);
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name='Synthetic',last_name='Kunde',company='Kunde GmbH',country_code='DE',
         vat_id='DE 123 456 789',street='1 Teststraße',city='Berlin',postal_code='10115'
   where id = um;
  insert into public.services(workspace_id,name,price_cents,supply_class)
   values (ws,'Mail handling',1500,'general') returning id into sv;
  insert into public.events(workspace_id,type,action,actor_member_id,subject_member_id,payload,status)
   values (ws,'service_charge','submitted',om,mm,
           jsonb_build_object('service_id',sv,'name','Mail handling','quantity',1,'amount_cents',1500,
                              'vat_percent',20,'period','2026-09'),'confirmed')
   returning id into ev;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,event_id,vat_percent)
   values (ws,mm,'charge','service',1500,'Mail handling x1','2026-09',ev,20);
  perform set_config('deskilo.v.ws', ws::text, false);
  perform set_config('deskilo.v.m', mm::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

-- What the edge function asks VIES, for the issuer.
set local role authenticated;
select is(public.vies_check_subject(current_setting('deskilo.v.ws')::uuid, current_setting('deskilo.v.m')::uuid)
            - 'vat_id',
          '{"country_code":"DE","number":"123456789","requester_country":"FR","requester_number":"12345678901"}'::jsonb,
          'the buyer''s number split for VIES, the seller''s number as the requester');
select throws_ok($$select public.record_vies_check(current_setting('deskilo.v.m')::uuid,
          'DE123456789','valid','FORGED','')$$, '42501', null,
          'a client cannot record a VIES answer');
-- An issuer cannot write the evidence through the member row either.
do $$ begin
  update public.members set vies_status = 'valid', vies_vat_id = 'DE123456789',
         vies_checked_at = now(), vies_consultation = 'FORGED'
   where id = current_setting('deskilo.v.m')::uuid;
exception when others then null; -- refused outright is as good as ignored
end $$;
reset role;
select is((select vies_status from public.members where id = current_setting('deskilo.v.m')::uuid),
          null, 'a direct write of the evidence is ignored');

-- Never checked: the reverse-charged month waits for VIES.
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid, '2026-09'), array['vies_unverified'],
          'a reverse charge without a VIES check is refused, naming the check');

-- VIES down: recorded as an outage, and still refused.
reset role;
select lives_ok($$select public.record_vies_check(current_setting('deskilo.v.m')::uuid,
          'DE123456789','unavailable','','MS_UNAVAILABLE')$$, 'the service role records an outage');
set local role authenticated;
select throws_ok($$select public.create_invoice(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid, '2026-09')$$, 'DKI01', 'invoice_essentials_missing',
          'VIES down refuses the reverse charge, it never falls back to domestic VAT');
select is(public.invoice_issue_readiness(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid, '2026-09'), array['vies_unverified'],
          'and the refusal names vies_unverified');

-- A valid check of another number is not evidence for this one.
reset role;
select public.record_vies_check(current_setting('deskilo.v.m')::uuid, 'DE999999999', 'valid', 'WAPIOTHER', '');
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid, '2026-09'), array['vies_unverified'],
          'a check of another number proves nothing');

-- Valid: mail handling is AE, the desk keeps French VAT, the number is frozen.
reset role;
select public.record_vies_check(current_setting('deskilo.v.m')::uuid, 'DE123456789', 'valid', 'WAPIAAAAZ1', '');
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid, '2026-09')$$, 'a verified reverse charge is issued');
reset role;
select is((select string_agg((t->>'category') || ':' || round((t->>'percent')::numeric)::text, ',' order by t->>'category')
             from public.invoices i, jsonb_array_elements(i.vat_totals) t
            where i.member_id = current_setting('deskilo.v.m')::uuid),
          'AE:0,S:20', 'mail handling is reverse-charged, the subscription is French VAT');
select is((select legal_snapshot #>> '{vies,consultation}' from public.invoices
            where member_id = current_setting('deskilo.v.m')::uuid),
          'WAPIAAAAZ1', 'the consultation number is frozen on the invoice');

-- Without the feature, the reverse charge stays outside the app.
update public.workspaces set feature_flags = feature_flags || '{"viesVerification":false}'::jsonb
 where id = current_setting('deskilo.v.ws')::uuid;
insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,event_id,vat_percent)
select workspace_id, member_id, 'charge', 'service', 1500, 'Mail handling x1', '2026-10', event_id, 20
  from public.ledger_entries where member_id = current_setting('deskilo.v.m')::uuid and category = 'service'
 limit 1;
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid, '2026-10'), array['vat_treatment_unreviewed'],
          'feature off: a reverse charge is not issued here');
select throws_ok($$select public.vies_check_subject(current_setting('deskilo.v.ws')::uuid,
          current_setting('deskilo.v.m')::uuid)$$, 'P0001', 'vies verification is off in this workspace',
          'and nobody asks VIES');
reset role;

select * from finish();
rollback;
