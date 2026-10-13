-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2359 (0418): land is exempt in the United Kingdom unless the owner opted
-- to tax it. A property line of a VAT-registered UK seller is E without the
-- option (and refused for want of the rate's reason when the seller has no
-- exempt rate), Z with it; a serviced package of facilities is taxed; an
-- option dated in the future is not yet in force; the choice is frozen in
-- the legal snapshot; every other country is untouched. The country itself
-- stays refused until the last slice, so the gaps ignore that one code.
-- Rolled back.
begin;
select plan(16);

-- A seller in [cc] with one customer and one September month: the
-- subscription at the standard rate and a supply priced at 0 %.
create or replace function pg_temp.seller(
  cc text, currency text, regime text, vat_id text, legal_id text,
  capacity text default 'consumer', buyer_legal text default '',
  buyer_country text default null, tag text default ''
) returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || lower(cc) || tag || '@uk2359b.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || lower(cc) || tag || '@uk2359b.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags)
   values ('UK 2359b ' || cc || tag, cc, currency, 'Europe/Brussels', uo, '1 Synthetic Street', 'Capital', '1000',
           regime, vat_id, legal_id, '{"invoicing":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,1,'2026-01-01',capacity) returning id into mm;
  if regime = 'vat_registered' then
    insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Synthetic standard',20,true);
    insert into public.vat_rates(workspace_id,label,percent,category,group_key) values (ws,'Synthetic zero',0,'Z','zero');
  end if;
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  update public.profiles set first_name='Synthetic',last_name='Customer',company='Customer Ltd',
         country_code=coalesce(buyer_country, cc),street='2 Synthetic Street',city='Capital',postal_code='1000',
         legal_id=buyer_legal
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',1000,'Zero-rated supply','2026-09',0);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return mm;
end;
$seed$;

create or replace function pg_temp.missing(mm uuid) returns text[] language sql as $q$
  select public.invoice_issue_readiness(m.workspace_id, m.id, '2026-09') from public.members m where m.id = mm;
$q$;


create or replace function pg_temp.gaps(mm uuid) returns text[] language sql as $q$
  select coalesce(array_agg(x order by x) filter (where x <> 'seller_country_unsupported'), '{}')
    from public.members m,
         unnest(public.invoice_issue_readiness(m.workspace_id, m.id, '2026-09')) x
   where m.id = mm;
$q$;

create or replace function pg_temp.legal(mm uuid, j jsonb) returns uuid language plpgsql as $q$
begin
  update public.workspaces set invoice_legal = j where id = (select workspace_id from public.members where id = mm);
  return mm;
end;
$q$;

create or replace function pg_temp.exempt_rate(mm uuid) returns uuid language plpgsql as $q$
begin
  insert into public.vat_rates(workspace_id,label,percent,category,group_key,exemption_reason)
   select workspace_id,'Exempt (land)',0,'E','exempt','VAT Act 1994, Schedule 9, Group 1 (land)'
     from public.members where id = mm;
  return mm;
end;
$q$;

-- the rule
select is(public.supply_vat_category_for(null,'2026-09-30','auto','property','vat_registered','GB','GB','business',true), 'E',
          'a UK desk with no option is exempt');
select is(public.supply_vat_category_for(null,'2026-09-30','auto','general','vat_registered','GB','GB','business',true), '',
          'a general service is standard-rated');
select is(public.supply_vat_category_for(null,'2026-09-30','auto','property','vat_registered','FR','FR','business',true), '',
          'the rule is the United Kingdom''s alone');
select is(public.supply_vat_category_for(null,'2026-09-30','auto','property','exempt','GB','GB','business',true), '',
          'an unregistered seller has no VAT to exempt from');
select is(public.supply_vat_category_for(null,'2026-09-30','export','property','vat_registered','GB','US','business',true), 'G',
          'the buyer''s treatment still decides first');

-- the choice
select is(pg_temp.gaps(pg_temp.legal(pg_temp.seller('GB','GBP','vat_registered','GB123456789','12345678', 'business', tag => '-none'), '{}')),
          array['exemption_reason','vat_treatment_unreviewed'],
          'no option and no exempt rate: the E line has no reason and is refused, never taxed');
select is(pg_temp.gaps(pg_temp.legal(pg_temp.exempt_rate(pg_temp.seller('GB','GBP','vat_registered','GB123456789','12345678', 'business', tag => '-rate')), '{}')),
          '{}'::text[], 'no option with the exempt land rate: exempt, its reason frozen');
select is(pg_temp.gaps(pg_temp.legal(pg_temp.seller('GB','GBP','vat_registered','GB123456789','12345678', 'business', tag => '-opt'),
            '{"option_to_tax":"true","option_to_tax_date":"2020-01-01","option_to_tax_reference":"HMRC/123"}')),
          '{}'::text[], 'opted to tax: the zero-priced line is Z, nothing to explain');
select is(pg_temp.gaps(pg_temp.legal(pg_temp.seller('GB','GBP','vat_registered','GB123456789','12345678', 'business', tag => '-future'),
            '{"option_to_tax":"true","option_to_tax_date":"2099-01-01"}')),
          array['exemption_reason','vat_treatment_unreviewed'], 'an option dated in the future is not yet in force');
select is(pg_temp.gaps(pg_temp.legal(pg_temp.seller('GB','GBP','vat_registered','GB123456789','12345678', 'business', tag => '-pkg'),
            '{"facilities_package":"true"}')),
          '{}'::text[], 'a serviced package of facilities is standard-rated');
select is(pg_temp.gaps(pg_temp.seller('FR','EUR','vat_registered','FR12345678901','123456789', 'consumer', tag => '-fr')),
          '{}'::text[], 'a French seller is untouched');
select ok(not public.workspace_taxes_land((select id from public.workspaces where name = 'UK 2359b GB-none'), '2026-09-30'),
          'the setting is read per workspace: default not taxed');
select ok(public.workspace_taxes_land((select id from public.workspaces where name = 'UK 2359b GB-opt'), '2026-09-30'),
          'an option in force taxes the land');
select ok(not public.workspace_taxes_land((select id from public.workspaces where name = 'UK 2359b GB-opt'), '2019-12-31'),
          'before the option''s date the land is exempt');

-- the snapshot freezes the choice
select is(public.invoice_legal_snapshot((select id from public.workspaces where name = 'UK 2359b GB-opt'),
            (select m.id from public.members m join public.workspaces w on w.id = m.workspace_id
              where w.name = 'UK 2359b GB-opt' and not m.is_owner), '{}'::jsonb) -> 'land_taxation',
          '{"option_to_tax": true, "option_to_tax_date": "2020-01-01", "option_to_tax_reference": "HMRC/123", "facilities_package": false}'::jsonb,
          'a UK invoice carries the option it was issued under');
select ok((public.invoice_legal_snapshot((select id from public.workspaces where name = 'UK 2359b FR-fr'),
            (select m.id from public.members m join public.workspaces w on w.id = m.workspace_id
              where w.name = 'UK 2359b FR-fr' and not m.is_owner), '{}'::jsonb) -> 'land_taxation') is null,
          'another country''s snapshot is unchanged');

select * from finish();
rollback;
