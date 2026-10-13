-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2361 (0424): the legal identity of a Canadian seller. A VAT-registered
-- seller states its business number with the RT account (123456789 RT0001);
-- an invoice that charges the QST (a QST component in vat_totals, 0423) also
-- carries Revenu Québec's number (1234567890 TQ0001) in the legal id. A small
-- supplier (not registered) is asked for neither. The country itself stays
-- refused until the last slice of the issue lifts the gate, so every case
-- ignores that one code. Rolled back.
begin;
select plan(13);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002361a1','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a1@ca2361.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000002361b1','CA essentials','CA','CAD','America/Toronto','00000000-0000-4000-8000-0000002361a1','dev',
  '{"invoicing":true}', '{}');
insert into public.vat_rates(workspace_id,label,percent,is_default) values
 ('00000000-0000-4000-8000-0000002361b1','GST+QST',14.975,true);
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity) values
 ('00000000-0000-4000-8000-0000002361c1','00000000-0000-4000-8000-0000002361b1','00000000-0000-4000-8000-0000002361a1',true,true,'active','business');

create or replace function pg_temp.gaps(p_regime text, p_vat_id text, p_legal_id text, p_totals jsonb) returns text[]
language sql as $$
  select coalesce(array_agg(x order by x) filter (where x <> 'seller_country_unsupported'), '{}')
    from unnest(public.invoice_essentials_missing('00000000-0000-4000-8000-0000002361b1'::uuid,
      '00000000-0000-4000-8000-0000002361c1'::uuid,
      jsonb_build_object('seller', jsonb_build_object('street','s','city','c','vat_regime',p_regime,
                                                      'vat_id',p_vat_id,'legal_id',p_legal_id),
                         'buyer', '{"name":"B","street":"s","city":"c"}'::jsonb),
      p_totals)) x;
$$;

create or replace function pg_temp.gst(p_percent numeric) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object('category','S','percent',p_percent,'gross_cents',10500,
    'net_cents',10000,'vat_cents',500,
    'components', jsonb_build_array(jsonb_build_object('scheme','GST','authority','CA','percent',5,'base_cents',10000,'tax_cents',500))));
$$;
create or replace function pg_temp.gst_qst() returns jsonb language sql as $$
  select public.vat_components_entry('CA', 14.975, 100000, 14975)
         || jsonb_build_object('category','S','percent',14.975,'gross_cents',114975,'net_cents',100000,'vat_cents',14975);
$$;
create or replace function pg_temp.qst_totals() returns jsonb language sql as $$
  select jsonb_build_array(pg_temp.gst_qst());
$$;

select is(pg_temp.gaps('vat_registered', '123456789 RT0001', '', pg_temp.gst(5)), '{}'::text[], 'a GST-only invoice: the BN with its RT account is enough');
select is(pg_temp.gaps('vat_registered', '123456789RT0001', '', pg_temp.gst(5)), '{}'::text[], 'without the space');
select is(pg_temp.gaps('vat_registered', '123456789 rt0002', '', pg_temp.gst(5)), '{}'::text[], 'a second account, in any case');
select is(pg_temp.gaps('vat_registered', '123456789', '', pg_temp.gst(5)), array['seller_bn_format'], 'the RT account is required');
select is(pg_temp.gaps('vat_registered', '12345678 RT0001', '', pg_temp.gst(5)), array['seller_bn_format'], 'eight digits is not a BN');
select is(pg_temp.gaps('vat_registered', '123456789 RC0001', '', pg_temp.gst(5)), array['seller_bn_format'], 'RC is the corporate-income-tax account');
select is(pg_temp.gaps('vat_registered', '', '', pg_temp.gst(5)), array['seller_vat_id'], 'no number at all is missing it');
select is(pg_temp.gaps('vat_registered', '123456789 RT0001', '', pg_temp.qst_totals()), array['seller_qst_number'], 'a Quebec invoice also needs the QST number');
select is(pg_temp.gaps('vat_registered', '123456789 RT0001', '1234567890 TQ0001', pg_temp.qst_totals()), '{}'::text[], 'with both numbers it is complete');
select is(pg_temp.gaps('vat_registered', '123456789 RT0001', '1234567890TQ0001', pg_temp.qst_totals()), '{}'::text[], 'without the space');
select is(pg_temp.gaps('vat_registered', '123456789 RT0001', '1234567890 TQ', pg_temp.qst_totals()), array['seller_qst_number'], 'a QST number of the wrong shape');
select is(pg_temp.gaps('vat_registered', '123456789 RT0001', '', pg_temp.gst(13)), '{}'::text[], 'no QST charged, no QST number asked');
select is(pg_temp.gaps('exempt', '', '', '[]'::jsonb), '{}'::text[], 'a small supplier states no number and charges none');
select * from finish();
rollback;
