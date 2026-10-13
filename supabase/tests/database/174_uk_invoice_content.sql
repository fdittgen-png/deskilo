-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2359 (0417): what a UK invoice states (VAT Notice 700 §16). The VAT
-- registration number has HMRC's shape; the VAT is in pounds sterling; up
-- to GBP 250 including VAT no customer name or address is needed. The
-- country itself stays refused until the last slice of the issue lifts
-- the gate, so every case ignores that one code. Rolled back.
begin;
select plan(10);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002359'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@uk2359.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000002359b1','UK essentials','GB','GBP','Europe/London','00000000-0000-4000-8000-0000002359a1','dev',
  '{"invoicing":true}', '{}'),
 ('00000000-0000-4000-8000-0000002359b2','UK in euros','GB','EUR','Europe/London','00000000-0000-4000-8000-0000002359a1','dev',
  '{"invoicing":true}', '{}');
insert into public.vat_rates(workspace_id,label,percent,is_default) values
 ('00000000-0000-4000-8000-0000002359b1','Standard',20,true),
 ('00000000-0000-4000-8000-0000002359b2','Standard',20,true);
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity) values
 ('00000000-0000-4000-8000-0000002359c1','00000000-0000-4000-8000-0000002359b1','00000000-0000-4000-8000-0000002359a1',true,true,'active',null),
 ('00000000-0000-4000-8000-0000002359c2','00000000-0000-4000-8000-0000002359b1','00000000-0000-4000-8000-0000002359a2',false,false,'active','business'),
 ('00000000-0000-4000-8000-0000002359c3','00000000-0000-4000-8000-0000002359b2','00000000-0000-4000-8000-0000002359a2',false,false,'active','business');

-- The gaps of an invoice, without the code the last slice lifts.
create or replace function pg_temp.gaps(p_vat_id text, p_buyer jsonb, p_gross int default 12000,
  p_ws text default '00000000-0000-4000-8000-0000002359b1', p_member text default '00000000-0000-4000-8000-0000002359c2',
  p_regime text default 'vat_registered') returns text[] language sql as $$
  select coalesce(array_agg(x order by x) filter (where x <> 'seller_country_unsupported'), '{}')
    from unnest(public.invoice_essentials_missing(p_ws::uuid, p_member::uuid,
      jsonb_build_object('seller', jsonb_build_object('street','s','city','c','vat_regime',p_regime,'vat_id',p_vat_id),
                         'buyer', p_buyer),
      jsonb_build_array(jsonb_build_object('category','S','percent',20,'gross_cents',p_gross,
                                           'net_cents',p_gross * 5 / 6,'vat_cents',p_gross / 6)))) x;
$$;

select is(pg_temp.gaps('GB123456789', '{"name":"B","street":"s","city":"c"}'), '{}'::text[],
          'GB: a nine-digit VRN, sterling, a full customer: nothing else missing');
select is(pg_temp.gaps('XI123456789012', '{"name":"B","street":"s","city":"c"}'), '{}'::text[],
          'XI: a Northern Ireland VRN with twelve digits has the shape');
select is(pg_temp.gaps('GB 123 4567 89', '{"name":"B","street":"s","city":"c"}'), '{}'::text[],
          'spaces in the VRN are ignored');
select is(pg_temp.gaps('GB12345', '{"name":"B","street":"s","city":"c"}'), array['seller_vat_id_format'],
          'a VRN of the wrong shape is refused');
select is(pg_temp.gaps('123456789', '{"name":"B","street":"s","city":"c"}'), array['seller_vat_id_format'],
          'a VRN without GB or XI is refused');
select is(pg_temp.gaps('', '{"name":"B","street":"s","city":"c"}'), array['seller_vat_id'],
          'a registered seller with no VRN at all is missing it, not malformed');
select is(pg_temp.gaps('GB123456789', '{"name":"B","street":"s","city":"c"}', 12000,
          '00000000-0000-4000-8000-0000002359b2', '00000000-0000-4000-8000-0000002359c3'),
          array['vat_national_currency'], 'VAT is stated in sterling: euros are refused');
select is(pg_temp.gaps('GB123456789', '{"name":"","company":"","street":"","city":""}', 25000), '{}'::text[],
          'up to GBP 250 including VAT a less detailed invoice needs no customer name or address');
select is(pg_temp.gaps('GB123456789', '{"name":"","company":"","street":"","city":""}', 25001),
          array['buyer_address','buyer_name'], 'above GBP 250 the customer is named and addressed');
select ok(not public.is_eu_country('GB'),
          'the United Kingdom is not in the Union: no EN 16931 mandate, no reverse charge');

select * from finish();
rollback;
