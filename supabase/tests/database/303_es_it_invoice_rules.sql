-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2363 (0600): the Spanish and Italian invoice rules as tax reference rows.
-- The store takes the new threshold effects (with the stamp duty's charge)
-- and the gate's outside-VAT postal codes, and refuses a malformed one; the
-- rows are seeded; a Spanish seller at a Canary Islands, Ceuta or Melilla
-- site is refused by name and one on the mainland is not; up to the
-- simplified-invoice line of its country (ES 400 EUR, GB 250 GBP as before)
-- no customer name or address is needed, above it they are. Spain itself
-- stays refused until Verifactu, so the cases ignore that one code.
-- Rolled back.
begin;
select plan(17);

-- the shapes
select ok(public.tax_reference_valid('threshold',
            '{"cents":7747,"effect":"stamp_duty","currency":"EUR","charge_cents":200}'),
          'a stamp-duty threshold with its charge is a valid shape');
select ok(public.tax_reference_valid('threshold',
            '{"cents":300506,"effect":"annual_operations","currency":"EUR"}'),
          'the modelo 347 line is a valid shape');
select ok(not public.tax_reference_valid('threshold',
            '{"cents":100,"effect":"whenever","currency":"EUR"}'),
          'an unknown effect is refused');
select ok(not public.tax_reference_valid('threshold',
            '{"cents":7747,"effect":"stamp_duty","currency":"EUR","charge_cents":"2"}'),
          'a charge that is not a whole number of minor units is refused');
select ok(public.tax_reference_valid('threshold',
            '{"cents":2500000,"effect":"next_year","currency":"EUR"}'),
          'a small-business threshold keeps its shape');
select ok(public.tax_reference_valid('issuing_gate',
            '{"supported":true,"requires_tax_number":true,"national_channel_required":true,"outside_vat_postal_codes":["35","38"]}'),
          'a gate with outside-VAT postal codes is a valid shape');
select ok(not public.tax_reference_valid('issuing_gate',
            '{"supported":true,"requires_tax_number":true,"national_channel_required":true,"outside_vat_postal_codes":[35]}'),
          'a postal-code prefix that is not a string is refused');

-- the rows
select is((select (value ->> 'cents')::int from public.tax_reference
            where domain = 'threshold' and country = 'ES' and key = 'modelo347'),
          300506, 'the modelo 347 line is 3,005.06 EUR');
select is((select value - 'effect' from public.tax_reference
            where domain = 'threshold' and country = 'IT' and key = 'stamp_duty'),
          '{"cents":7747,"currency":"EUR","charge_cents":200}'::jsonb,
          'the stamp duty: 2.00 EUR above 77.47 EUR');
select ok(exists (select 1 from public.tax_reference
                   where domain = 'exemption_text' and country = 'IT' and key = 'stamp_duty'),
          'the stamp duty has its statutory line');
select is(public.issuing_gate_of('ES') -> 'outside_vat_postal_codes',
          '["35","38","51","52"]'::jsonb,
          'the Spanish gate in force names the Canary Islands, Ceuta and Melilla');
select is(public.tax_threshold_cents('ES', 'simplified_invoice'), 40000::bigint,
          'the Spanish simplified invoice goes up to 400 EUR');

-- the essentials
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002363'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@es2363.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000002363b1','ES essentials','ES','EUR','Europe/Madrid','00000000-0000-4000-8000-0000002363a1','dev',
  '{"invoicing":true}', '{}');
insert into public.vat_rates(workspace_id,label,percent,is_default) values
 ('00000000-0000-4000-8000-0000002363b1','General',21,true);
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity) values
 ('00000000-0000-4000-8000-0000002363c1','00000000-0000-4000-8000-0000002363b1','00000000-0000-4000-8000-0000002363a1',true,true,'active',null),
 ('00000000-0000-4000-8000-0000002363c2','00000000-0000-4000-8000-0000002363b1','00000000-0000-4000-8000-0000002363a2',false,false,'active','business');

-- The gaps of a Spanish invoice at [p_postal], without the code Verifactu lifts.
create or replace function pg_temp.gaps(p_postal text, p_buyer jsonb, p_gross int default 12100)
returns text[] language sql as $$
  select coalesce(array_agg(x order by x) filter (where x <> 'seller_country_unsupported'), '{}')
    from unnest(public.invoice_essentials_missing(
      '00000000-0000-4000-8000-0000002363b1'::uuid, '00000000-0000-4000-8000-0000002363c2'::uuid,
      jsonb_build_object('seller', jsonb_build_object('street','s','city','c','postal_code',p_postal,
                                                      'country','ES','vat_regime','vat_registered',
                                                      'vat_id','ESB12345678'),
                         'buyer', p_buyer),
      jsonb_build_array(jsonb_build_object('category','S','percent',21,'gross_cents',p_gross,
                                           'net_cents',p_gross * 100 / 121,
                                           'vat_cents',p_gross - p_gross * 100 / 121)))) x;
$$;

select is(pg_temp.gaps('28001', '{"name":"B","street":"s","city":"c","vat_id":"ESA12345674"}'),
          '{}'::text[], 'Madrid: nothing else missing');
select is(pg_temp.gaps('35001', '{"name":"B","street":"s","city":"c","vat_id":"ESA12345674"}'),
          array['territory_outside_vat'], 'Las Palmas: outside the VAT, refused by name');
select is(pg_temp.gaps('52001', '{"name":"B","street":"s","city":"c","vat_id":"ESA12345674"}'),
          array['territory_outside_vat'], 'Melilla: outside the VAT, refused by name');
select is(pg_temp.gaps('28001', '{"name":"","company":"","street":"","city":"","vat_id":"ESA12345674"}', 40000),
          '{}'::text[], 'up to 400 EUR a simplified invoice names no customer');
select is(pg_temp.gaps('28001', '{"name":"","company":"","street":"","city":"","vat_id":"ESA12345674"}', 40001),
          array['buyer_address','buyer_name'], 'above 400 EUR the customer is named and addressed');

select * from finish();
rollback;
