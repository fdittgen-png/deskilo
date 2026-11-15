-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3649 (0787) -- an address knows its region, and the region travels with
-- its address block. A buyer's region is their own block's (the person's
-- profile, or the managed identity the business keeps); the issuer's earlier
-- region is used only when that block has none; street and region come
-- from the same block; the e-invoicing endpoint is unchanged. A region is a
-- code; a managed identity keeps it; erasure clears it; a claimed profile
-- carries it; a site's region travels in a configuration. Rolled back.
begin;
select plan(14);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000036491';
  up uuid := '00000000-0000-4000-8000-000000036492';
  uq uuid := '00000000-0000-4000-8000-000000036493';
  uc uuid := '00000000-0000-4000-8000-000000036494';
  ws uuid; mp uuid; mq uuid; m1 uuid; m2 uuid; mc uuid; other uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  select u,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','region-'||right(u::text,4)||'@deskilo.test','',now(),now(),now()
    from unnest(array[uo, up, uq, uc]) u;
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,vat_regime,feature_flags)
   values ('Region 3649','FR','EUR','Europe/Paris',uo,'1 rue de la Région','Pézenas','34120','not_subject','{"invoicing":true}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  update public.profiles set street = 'Via Roma 2', postal_code = '20121', city = 'Milano', country_code = 'IT', subdivision = 'MI'
   where id = up;
  update public.profiles set street = 'Via Garibaldi 3', postal_code = '10121', city = 'Torino', country_code = 'IT', subdivision = ''
   where id = uq;
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,billing_subdivision,einvoice_endpoint_id,einvoice_endpoint_scheme)
   values (ws,up,1,'2026-01-01','RM','IT01234567890','0211') returning id into mp;
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,billing_subdivision)
   values (ws,uq,1,'2026-01-01','TO') returning id into mq;
  -- two managed members, the business keeping their identity
  insert into public.members(workspace_id,user_id,joined_at,billing_subdivision,managed_name)
   values (ws,null,'2026-01-01','FI','Bianchi') returning id into m1;
  insert into public.members(workspace_id,user_id,joined_at,billing_subdivision,managed_name)
   values (ws,null,'2026-01-01','NA','Verdi') returning id into m2;
  insert into public.managed_identities(workspace_id, member_id, identity)
  values (ws, m1, public.managed_identity_clean('{"street": "Via Po 4", "city": "Bologna", "subdivision": " bo "}')),
         (ws, m2, public.managed_identity_clean('{"street": "Via Toledo 5", "city": "Napoli"}'));
  -- a managed profile to be claimed, with its region
  insert into public.members(workspace_id,user_id,joined_at,managed_name)
   values (ws,null,'2026-01-01','Neri') returning id into mc;
  insert into public.managed_identities(workspace_id, member_id, identity)
  values (ws, mc, public.managed_identity_clean('{"street": "Via Dante 6", "city": "Firenze", "subdivision": "FI"}'));
  insert into public.invitations(workspace_id, code, is_admin, created_by, expires_at, member_id)
  values (ws, 'REGION3649', false, uo, now() + interval '1 day', mc);
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands(workspace_id,from_pct,to_pct,fee_cents,overage_fee_cents) values (ws,0,100,3500,1000);
  insert into public.sites(workspace_id, name, street, city, country_code, subdivision)
  values (ws, 'Annex', 'Via Brera 7', 'Milano', 'IT', 'MI');
  -- a second business, in another country, the configuration is applied to
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by)
   values ('Region 3649 Lugano','CH','CHF','Europe/Zurich',uo) returning id into other;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (other,uo,true,true,'2026-01-01');
  perform set_config('deskilo.r.other', other::text, false);
  perform set_config('deskilo.r.ws', ws::text, false);
  perform set_config('deskilo.r.mp', mp::text, false);
  perform set_config('deskilo.r.mq', mq::text, false);
  perform set_config('deskilo.r.m1', m1::text, false);
  perform set_config('deskilo.r.m2', m2::text, false);
  perform set_config('deskilo.r.mc', mc::text, false);
  perform set_config('deskilo.r.up', up::text, false);
  perform set_config('deskilo.r.uc', uc::text, false);
  perform set_config('deskilo.r.uo', uo::text, false);
end;
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select pg_temp.seed();

create or replace function pg_temp.region(p text) returns text language sql as $$
  select public.member_einvoice_address(current_setting('deskilo.r.' || p)::uuid) ->> 'subdivision'
$$;

-- ── the region of the buyer's own block ──
select is(pg_temp.region('mp'), 'MI', 'a person''s own region, even when the issuer''s earlier one differs');
select is(pg_temp.region('mq'), 'TO', 'a person without one: the issuer''s earlier region');
select is(pg_temp.region('m1'), 'BO', 'a managed member''s region comes from the identity the business keeps');
select is(pg_temp.region('m2'), 'NA', 'a managed member without one: the issuer''s earlier region');
select is((select (a->>'endpoint_id', a->>'endpoint_scheme')::text
             from (select public.member_einvoice_address(current_setting('deskilo.r.mp')::uuid) a) x),
  '(IT01234567890,0211)', 'the e-invoicing endpoint is unchanged');

-- ── street and region from one block, on an issued invoice ──
select set_config('request.jwt.claims', json_build_object('sub', current_setting('deskilo.r.uo'), 'role', 'authenticated')::text, false);
set local role authenticated;
select set_config('deskilo.r.inv', public.create_invoice(current_setting('deskilo.r.ws')::uuid,
  current_setting('deskilo.r.mp')::uuid, '2026-09')::text, false);
reset role;
select is((select (parties->'buyer'->>'street', parties->'buyer'->>'subdivision')::text
             from public.invoices where id = current_setting('deskilo.r.inv')::uuid),
  '("Via Roma 2",MI)', 'the buyer''s street and region come from the same block');
update public.profiles set subdivision = 'MB' where id = current_setting('deskilo.r.up')::uuid;
select is((select parties->'buyer'->>'subdivision' from public.invoices where id = current_setting('deskilo.r.inv')::uuid),
  'MI', 'an issued invoice keeps the parties it stored');

-- ── a region is a code ──
select throws_ok(format('update public.profiles set subdivision = %L where id = %L', 'Lombardia region', current_setting('deskilo.r.up')),
  '23514', null, 'a region is a code, not free text');
select is((select identity->>'subdivision' from public.managed_identities where member_id = current_setting('deskilo.r.m1')::uuid),
  'BO', 'a managed identity keeps its region as a code');

-- ── a claimed profile carries it; erasure clears it ──
select set_config('request.jwt.claims', json_build_object('sub', current_setting('deskilo.r.uc'), 'role', 'authenticated')::text, false);
set local role authenticated;
select public.join_workspace('REGION3649');
reset role;
select is((select subdivision from public.profiles where id = current_setting('deskilo.r.uc')::uuid), 'FI',
  'a managed profile claimed by its person brings its region into their address');
select set_config('request.jwt.claims', json_build_object('sub', current_setting('deskilo.r.up'), 'role', 'authenticated')::text, false);
set local role authenticated;
select public.erase_my_membership(current_setting('deskilo.r.ws')::uuid);
reset role;
select is((select subdivision from public.profiles where id = current_setting('deskilo.r.up')::uuid), '',
  'erasing the address erases its region');

-- ── a site's region travels in a configuration ──
select set_config('request.jwt.claims', json_build_object('sub', current_setting('deskilo.r.uo'), 'role', 'authenticated')::text, false);
set local role authenticated;
select set_config('deskilo.r.cfg', public.export_workspace_configuration(current_setting('deskilo.r.ws')::uuid)::text, false);
reset role;
select is((select s->>'subdivision' from jsonb_array_elements(current_setting('deskilo.r.cfg')::jsonb->'tables'->'sites') s
            where s->>'name' = 'Annex'), 'MI', 'a site''s region is in the configuration');
update public.sites set subdivision = '' where workspace_id = current_setting('deskilo.r.ws')::uuid;
set local role authenticated;
select public.import_workspace_configuration(current_setting('deskilo.r.ws')::uuid,
  current_setting('deskilo.r.cfg')::jsonb, 'merge');
reset role;
select is((select subdivision from public.sites where workspace_id = current_setting('deskilo.r.ws')::uuid and name = 'Annex'), 'MI',
  'and comes back with it');
-- into a business of another country and currency the fence (0779) keeps
-- sites: a site travels whole, its region with its street
set local role authenticated;
select public.import_workspace_configuration(current_setting('deskilo.r.other')::uuid,
  current_setting('deskilo.r.cfg')::jsonb, 'merge');
reset role;
select is((select (street, country_code, subdivision)::text from public.sites
            where workspace_id = current_setting('deskilo.r.other')::uuid and name = 'Annex'),
  '("Via Brera 7",IT,MI)', 'into another country a site arrives whole, its region with its address');

select * from finish();
rollback;
