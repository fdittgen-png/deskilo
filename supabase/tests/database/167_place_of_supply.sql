-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2354: a desk is supplied where the building stands. A French seller
-- invoicing a German business keeps French VAT on the subscription
-- (category S, no reverse-charge mention); only a general-service line
-- (mail handling) follows the business customer, and that reverse charge
-- stays unreviewed. The rule's cases below are the Dart twin's too:
-- test/features/money/place_of_supply_test.dart parses every
-- `supply_vat_category(...)` line of this file and runs it through
-- supplyVatCategory, so the two cannot drift.
begin;
select plan(40);

-- ── the rule (the twin cases; one per line) ───────────────────────────
select is(public.supply_vat_category('auto','property','vat_registered','FR','DE','business',true), '', 'a desk for an EU business abroad: domestic');
select is(public.supply_vat_category('auto','property','vat_registered','FR','US','business',true), '', 'a desk for a business outside the EU: domestic');
select is(public.supply_vat_category('auto','property','vat_registered','FR','DE','consumer',true), '', 'a desk for a consumer abroad: domestic');
select is(public.supply_vat_category('auto','general','vat_registered','FR','DE','business',true), 'AE', 'a general service to an EU business abroad: AE');
select is(public.supply_vat_category('auto','general','vat_registered','FR','EL','business',true), 'AE', 'EL is Greece');
select is(public.supply_vat_category('auto','general','vat_registered','GR','EL','business',true), '', 'GR and EL are one country');
select is(public.supply_vat_category('auto','general','vat_registered','FR','fr','business',true), '', 'a general service at home: domestic');
select is(public.supply_vat_category('auto','general','vat_registered','FR','DE','consumer',true), '', 'a consumer pays the seller''s VAT (art. 45)');
select is(public.supply_vat_category('auto','general','vat_registered','FR','DE','unknown',true), '', 'a VAT number alone is not a business');
select is(public.supply_vat_category('auto','general','vat_registered','FR','US','business',true), 'G', 'a general service to a business outside the EU: G');
select is(public.supply_vat_category('auto','general','vat_registered','FR','US','consumer',true), '', 'a consumer outside the EU: domestic');
select is(public.supply_vat_category('auto','general','vat_registered','FR','DE','business',false), '', 'the workspace switched reverse charge off');
select is(public.supply_vat_category('auto','general','exempt','FR','DE','business',true), '', 'an exempt seller reverses nothing');
select is(public.supply_vat_category('auto','general','not_subject','FR','DE','business',true), '', 'a seller outside the scope reverses nothing');
select is(public.supply_vat_category('auto','general','vat_registered','CH','DE','business',true), '', 'a seller outside the EU');
select is(public.supply_vat_category('auto','general','vat_registered','FR','','business',true), '', 'no buyer country: the seller''s');
select is(public.supply_vat_category('domestic','general','vat_registered','FR','DE','business',true), '', 'domestic decides every line');
select is(public.supply_vat_category('reverse_charge','property','vat_registered','FR','FR','consumer',true), 'AE', 'reverse charge decides every line');
select is(public.supply_vat_category('export','property','vat_registered','FR','DE','business',true), 'G', 'export decides every line');
select is(public.supply_vat_category('exempt','property','vat_registered','FR','FR','business',true), 'E', 'exempt decides every line');

-- ── one EU set ────────────────────────────────────────────────────────
select is(public.eu_country_code(' el '), 'GR', 'the VAT prefix EL is normalised to GR');
select ok(public.is_eu_country('EL') and public.is_eu_country('gr'), 'Greece under both codes');
select ok(not public.is_eu_country('GB') and not public.is_eu_country('CH'), 'not in the Union');

-- ── a French space, a German business ────────────────────────────────
create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000235401';
  um uuid := '00000000-0000-4000-8000-000000235402';
  ws uuid; mm uuid; om uuid; sv uuid; ev uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@supply2354.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@supply2354.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,feature_flags)
   values ('Supply 2354','FR','EUR','Europe/Paris',uo,'1 rue du Pilote','Pézenas','34120',
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
         vat_id='DE123456789',street='1 Teststraße',city='Berlin',postal_code='10115'
   where id = um;
  -- Mail handling is a general service; the charge freezes its class.
  insert into public.services(workspace_id,name,price_cents,supply_class)
   values (ws,'Mail handling',1500,'general') returning id into sv;
  insert into public.events(workspace_id,type,action,actor_member_id,subject_member_id,payload,status)
   values (ws,'service_charge','submitted',om,mm,
           jsonb_build_object('service_id',sv,'name','Mail handling','quantity',1,'amount_cents',1500,
                              'vat_percent',20,'period','2026-10'),'confirmed')
   returning id into ev;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,event_id,vat_percent)
   values (ws,mm,'charge','service',1500,'Mail handling x1','2026-10',ev,20);
  -- A client cannot declare a line general: anything else is property.
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent,supply_class)
   values (ws,mm,'charge','adjustment',500,'Key deposit','2026-10',20,'general');
  perform set_config('deskilo.s.ws', ws::text, false);
  perform set_config('deskilo.s.m', mm::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

select is((select supply_class from public.ledger_entries
            where member_id = current_setting('deskilo.s.m')::uuid and category = 'service'),
          'general', 'a service charge freezes its catalogue service''s class');
select is((select supply_class from public.ledger_entries
            where member_id = current_setting('deskilo.s.m')::uuid and category = 'adjustment'),
          'property', 'a client value is ignored: an adjustment is property-connected');
select is((select l->>'supply' from jsonb_array_elements(
             public.invoice_lines_for(current_setting('deskilo.s.m')::uuid, '2026-10')) l
            where l->>'kind' = 'service'),
          'general', 'the invoice line carries the class');
select ok((public.export_workspace_configuration(current_setting('deskilo.s.ws')::uuid)::text)
            like '%"supply_class": "general"%', 'the configuration transfer carries the class');

-- The subscription month: French VAT, category S, no AE anywhere.
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-09'), '{}'::text[],
          'a desk for a German business is not refused as cross-border');
select lives_ok($$select public.create_invoice(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-09')$$, 'the subscription invoice is issued');
reset role;
select is((select array_agg(distinct t->>'category') from public.invoices i,
             jsonb_array_elements(i.vat_totals) t
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-09'),
          array['S'], 'a French seller, a German business, a subscription: category S');
select is((select (t->>'percent')::numeric from public.invoices i, jsonb_array_elements(i.vat_totals) t
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-09'),
          20::numeric, 'at the French rate');
select ok((select bool_and(l->>'supply' = 'property' and l->>'vat_category' = 'S')
             from public.invoices i, jsonb_array_elements(i.lines) l
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-09'),
          'every line says it is property-connected and taxed');

-- Mail handling to the same business: AE, which stays unreviewed here.
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-10'), array['vat_treatment_unreviewed'],
          'a general service to an EU business is reverse-charged, and not issued here yet');
select throws_ok($$select public.create_invoice(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-10')$$, 'DKI01', 'invoice_essentials_missing',
          'the reverse-charged month is refused before numbering');

-- Nobody stated the capacity: refuse rather than guess.
reset role;
update public.members set customer_capacity = null where id = current_setting('deskilo.s.m')::uuid;
set local role authenticated;
select is(public.invoice_issue_readiness(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-10'), array['buyer_capacity_unknown'],
          'a general service abroad needs the customer''s capacity');

-- A consumer pays the seller's VAT on every line.
reset role;
update public.members set customer_capacity = 'consumer' where id = current_setting('deskilo.s.m')::uuid;
set local role authenticated;
select lives_ok($$select public.create_invoice(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-10')$$, 'the consumer''s month is issued');
reset role;
select is((select array_agg(distinct t->>'category') from public.invoices i,
             jsonb_array_elements(i.vat_totals) t
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-10'),
          array['S'], 'a consumer abroad: French VAT on the general service too');
select is((select l->>'vat_category' from public.invoices i, jsonb_array_elements(i.lines) l
            where i.member_id = current_setting('deskilo.s.m')::uuid and i.period = '2026-10'
              and l->>'kind' = 'service'),
          'S', 'the general-service line is taxed at home');

-- A business outside the EU: G on the general service only, unreviewed.
update public.members set customer_capacity = 'business' where id = current_setting('deskilo.s.m')::uuid;
update public.profiles set country_code = 'US', vat_id = ''
 where id = '00000000-0000-4000-8000-000000235402';
insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,event_id,vat_percent)
select workspace_id, member_id, 'charge', 'service', 1500, 'Mail handling x1', '2026-11', event_id, 20
  from public.ledger_entries where member_id = current_setting('deskilo.s.m')::uuid and category = 'service';
set local role authenticated;
select ok('vat_treatment_unreviewed' = any(public.invoice_issue_readiness(current_setting('deskilo.s.ws')::uuid,
          current_setting('deskilo.s.m')::uuid, '2026-11')),
          'a general service to a business outside the EU is G, and not issued here yet');
reset role;
select is((select array_agg(c order by c) from (
             select distinct public.supply_vat_category('auto', l->>'supply', 'vat_registered', 'FR', 'US', 'business', true) c
               from jsonb_array_elements(public.invoice_lines_for(current_setting('deskilo.s.m')::uuid, '2026-11')) l
              where (l->>'amount_cents')::int > 0) x),
          array['', 'G'], 'the desk stays domestic beside the G line');

select * from finish();
rollback;
