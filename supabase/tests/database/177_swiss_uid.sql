-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2360 (0420): the Swiss UID of a VAT-registered seller is CHE-123.456.789
-- plus MWST (TVA, IVA) with a valid modulus-11 check digit. The country
-- itself stays refused until the last slice of the issue lifts the gate,
-- so every case ignores that one code. Rolled back.
begin;
select plan(11);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002360a1','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a1@ch2360.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000002360b1','CH essentials','CH','CHF','Europe/Zurich','00000000-0000-4000-8000-0000002360a1','dev',
  '{"invoicing":true}', '{}');
insert into public.vat_rates(workspace_id,label,percent,is_default) values
 ('00000000-0000-4000-8000-0000002360b1','Normal',8.1,true);
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity) values
 ('00000000-0000-4000-8000-0000002360c1','00000000-0000-4000-8000-0000002360b1','00000000-0000-4000-8000-0000002360a1',true,true,'active','business');

create or replace function pg_temp.gaps(p_vat_id text) returns text[] language sql as $$
  select coalesce(array_agg(x order by x) filter (where x <> 'seller_country_unsupported'), '{}')
    from unnest(public.invoice_essentials_missing('00000000-0000-4000-8000-0000002360b1'::uuid,
      '00000000-0000-4000-8000-0000002360c1'::uuid,
      jsonb_build_object('seller', jsonb_build_object('street','s','city','c','vat_regime','vat_registered','vat_id',p_vat_id),
                         'buyer', '{"name":"B","street":"s","city":"c"}'::jsonb),
      jsonb_build_array(jsonb_build_object('category','S','percent',8.1,'gross_cents',10810,
                                           'net_cents',10000,'vat_cents',810)))) x;
$$;

select is(pg_temp.gaps('CHE-109.322.551 MWST'), '{}'::text[], 'the printed form is accepted');
select is(pg_temp.gaps('CHE109322551MWST'), '{}'::text[], 'without punctuation');
select is(pg_temp.gaps('CHE-109.322.551 TVA'), '{}'::text[], 'TVA in French');
select is(pg_temp.gaps('CHE-109.322.551 IVA'), '{}'::text[], 'IVA in Italian');
select is(pg_temp.gaps('CHE-109.322.551'), array['seller_uid_format'], 'the MWST suffix is required');
select is(pg_temp.gaps('CHE-109.322.552 MWST'), array['seller_uid_format'], 'a wrong check digit');
select is(pg_temp.gaps('CHE-109.322 MWST'), array['seller_uid_format'], 'too few digits');
select is(pg_temp.gaps('E109322551MWST'), array['seller_uid_format'], 'the old E prefix is not a UID');
select is(pg_temp.gaps(''), array['seller_vat_id'], 'a registered seller with no UID at all is missing it');
select ok(public.swiss_uid_valid('CHE-109.322.551', false), 'the suffix is optional for a buyer');
select ok(not public.swiss_uid_valid('CHE-000.000.030 MWST', true), 'check digit 10 never exists');

select * from finish();
rollback;
