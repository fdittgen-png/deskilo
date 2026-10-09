-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1916: an invoice is not issued while its essentials are unknown. The
-- checks run on the parties the invoice is about to freeze; create_invoice
-- refuses (SQLSTATE DKI01, the missing keys in DETAIL) BEFORE a number is
-- taken, so a refused invoice leaves no row and no gap. A consumer is not
-- asked for a postal address; a stated business capacity is.
begin;
select plan(21);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001917'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@essentials.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal) values
 ('00000000-0000-4000-8000-0000001917b1','Essentials','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001917a1','dev',
  '{"invoicing":true}', '{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status,customer_capacity) values
 ('00000000-0000-4000-8000-0000001917c1','00000000-0000-4000-8000-0000001917b1','00000000-0000-4000-8000-0000001917a1',true,true,'active',null),
 ('00000000-0000-4000-8000-0000001917c2','00000000-0000-4000-8000-0000001917b1','00000000-0000-4000-8000-0000001917a2',false,false,'active',null);

create or replace function pg_temp.missing(p_parties jsonb, p_totals jsonb default '[]') returns text[] language sql as $$
  select public.invoice_essentials_missing('00000000-0000-4000-8000-0000001917b1',
    '00000000-0000-4000-8000-0000001917c2', p_parties, p_totals);
$$;

select is(pg_temp.missing('{"seller":{"street":"","city":""},"buyer":{"name":"B"}}'),
  array['seller_address'], 'no street and no city: the seller address is missing');
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"vat_registered","vat_id":""},"buyer":{"name":"B"}}'),
  array['seller_vat_id','vat_rate_unresolved'],
  'a VAT-registered seller needs its identifier — and, with no default rate, a rate (#1917)');
select is(pg_temp.missing('{"seller":{"city":"c","vat_regime":"exempt","tax_exemption_reason":""},"buyer":{"name":"B"}}',
  '[{"category":"E"}]'), array['exemption_reason','vat_treatment_unreviewed'], 'an exempt line needs its basis and reviewed classification');
select is(pg_temp.missing('{"seller":{"city":"c","vat_regime":"exempt","tax_exemption_reason":"art. 261"},"buyer":{"name":"B"}}',
  '[{"category":"E"}]'), array['vat_treatment_unreviewed'], 'a free-text basis alone cannot qualify the exemption');
select is(pg_temp.missing('{"seller":{"city":"c"},"buyer":{"name":"B","vat_id":""}}', '[{"category":"AE"}]'),
  array['buyer_vat_id','vat_treatment_unreviewed'], 'reverse charge needs more than the buyer''s VAT identifier');
select is(pg_temp.missing('{"seller":{"city":"c"},"buyer":{"name":"","company":""}}'),
  array['buyer_name'], 'a document needs someone to address it to');
select is(pg_temp.missing('{"seller":{"city":"c"},"buyer":{"name":"B","street":"","city":""}}'),
  array[]::text[], 'a customer whose capacity is not stated is not asked for an address');

update public.members set customer_capacity = 'business' where id = '00000000-0000-4000-8000-0000001917c2';
select is(pg_temp.missing('{"seller":{"city":"c"},"buyer":{"name":"B","street":"","city":""}}'),
  array['buyer_address'], 'a stated business customer needs a postal address');
update public.members set customer_capacity = 'consumer' where id = '00000000-0000-4000-8000-0000001917c2';
select is(pg_temp.missing('{"seller":{"city":"c"},"buyer":{"name":"B","street":"","city":""}}'),
  array[]::text[], 'a consumer does not');

-- #1917: a default rate in force resolves; an unsupported seller country refuses.
insert into public.vat_rates(workspace_id,label,percent,is_default)
  values ('00000000-0000-4000-8000-0000001917b1','Standard',20,true);
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"vat_registered","vat_id":"FR1"},"buyer":{"name":"B"}}'),
  array[]::text[], 'a resolvable default rate is not missing');
update public.vat_rates set active = false where workspace_id = '00000000-0000-4000-8000-0000001917b1';
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"vat_registered","vat_id":"FR1"},"buyer":{"name":"B"}}'),
  array['vat_rate_unresolved'], 'an inactive default rate never falls back to 0 %');
update public.workspaces set country_code = 'US' where id = '00000000-0000-4000-8000-0000001917b1';
select is(pg_temp.missing('{"seller":{"city":"c"},"buyer":{"name":"B"}}'),
  array['seller_country_unsupported'], 'a country the clauses were not reviewed for refuses issuing');
select is(pg_temp.missing('{"seller":{"city":"c","country":"DE"},"buyer":{"name":"B"}}'),
  array[]::text[], 'the seller country stated on the party (DE) is reviewed');
update public.workspaces set country_code = 'FR' where id = '00000000-0000-4000-8000-0000001917b1';

-- #1917 (0393): an expired default no longer resolves with its own percent;
-- a 0 % charge with nothing explaining it, and VAT billed by a seller that
-- does not charge VAT, both refuse issuing. A 0 % credit does not.
update public.vat_rates set active = true, valid_from = '2000-01-01', valid_to = '2001-01-01'
 where workspace_id = '00000000-0000-4000-8000-0000001917b1';
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"vat_registered","vat_id":"FR1"},"buyer":{"name":"B"}}'),
  array['vat_rate_unresolved'], 'an expired default rate is not in force');
update public.vat_rates set valid_to = null where workspace_id = '00000000-0000-4000-8000-0000001917b1';
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"vat_registered","vat_id":"FR1"},"buyer":{"name":"B"}}',
  '[{"percent":0,"category":"O","gross_cents":1000}]'),
  array['vat_line_zero_unexplained'], 'a charge at 0 % with nothing explaining it refuses issuing');
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"vat_registered","vat_id":"FR1"},"buyer":{"name":"B"}}',
  '[{"percent":0,"category":"O","gross_cents":-500}]'),
  array[]::text[], 'a credit at 0 % is money returned, not a supply');
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"not_subject"},"buyer":{"name":"B"}}',
  '[{"percent":20,"category":"S","gross_cents":1200}]'),
  array['vat_charged_not_registered'], 'a seller that does not charge VAT never issues VAT');
select is(pg_temp.missing('{"seller":{"street":"s","vat_regime":"not_subject"},"buyer":{"name":"B"}}',
  '[{"percent":0,"category":"O","gross_cents":1000}]'),
  array[]::text[], 'and its 0 % lines are what they should be');
update public.workspaces set subscription_vat_rate_id =
  (select id from public.vat_rates where workspace_id = '00000000-0000-4000-8000-0000001917b1' limit 1)
 where id = '00000000-0000-4000-8000-0000001917b1';
select is(public.workspace_tariff_vat_percent('00000000-0000-4000-8000-0000001917b1', current_date),
  0::numeric, 'a subscription rate does not apply where the workspace does not charge VAT');

-- The gate itself: the workspace has no postal address. The owner issues.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001917a1","role":"authenticated"}',true);
select throws_ok($$select public.create_invoice('00000000-0000-4000-8000-0000001917b1',
    '00000000-0000-4000-8000-0000001917c2', '2020-01', null, false, 'full', true)$$,
  'DKI01', 'invoice_essentials_missing', 'create_invoice refuses before taking a number');
select is((select count(*)::int from public.invoices where workspace_id = '00000000-0000-4000-8000-0000001917b1'),
  0, 'and leaves no invoice behind');

select * from finish();
rollback;
