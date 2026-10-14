-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2479 (C3 of #2476, 0431): the issuing gate, the tax point policy and the
-- shapes of the four new domains are ROWS. One real create_invoice per scene
-- against a Canadian seller (the same fixture as 183): turning the country's
-- `issuing_gate.supported` off refuses with seller_country_unsupported and
-- on lets it issue; a national channel refuses whatever `supported` says; a
-- country with no row is refused. The tax point policy follows its rows, and
-- the value shapes refuse what is not one. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.seller(
  tag text, currency text, vat_id text, legal_id text, pct numeric, amount int,
  regime text default 'vat_registered'
) returns uuid language plpgsql as $seed$
declare
  uo uuid := gen_random_uuid();
  um uuid := gen_random_uuid();
  ws uuid; mm uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'owner-' || tag || '@gate2479.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || tag || '@gate2479.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags,invoice_legal)
   values ('Gate 2479 ' || tag, 'CA', currency, 'America/Toronto', uo, '100 Main St', 'Montreal', 'H2X 1Y4',
           regime, vat_id, legal_id, '{"invoicing":true}', '{}')
   returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin,joined_at) values (ws,uo,true,true,'2026-01-01');
  insert into public.members(workspace_id,user_id,subscription_pct,joined_at,customer_capacity)
   values (ws,um,0,'2026-01-01','business') returning id into mm;
  insert into public.vat_rates(workspace_id,label,percent,is_default) values (ws,'Rate',pct,true);
  update public.profiles set first_name = 'Synthetic', last_name = 'Customer', company = 'Customer Ltd',
         country_code='CA', street = '200 King St', city = 'Toronto', postal_code='M5H 1J9'
   where id = um;
  insert into public.ledger_entries(workspace_id,member_id,kind,category,amount_cents,description,period,vat_percent)
   values (ws,mm,'charge','adjustment',amount,'Desk licence','2026-09',pct);
  perform set_config('request.jwt.claims', json_build_object('sub',uo,'role','authenticated')::text, true);
  return mm;
end;
$seed$;

create or replace function pg_temp.issue(mm uuid) returns text language plpgsql as $q$
begin
  perform public.create_invoice((select workspace_id from public.members where id = mm), mm, '2026-09');
  return '';
exception when others then
  return coalesce(sqlerrm, '') || ' ' || coalesce(
    (select '[' || string_agg(x, ',') || ']' from unnest(public.invoice_issue_readiness(
       (select workspace_id from public.members where id = mm), mm, '2026-09')) x), '');
end;
$q$;

create or replace function pg_temp.invoice_of(mm uuid) returns public.invoices language sql as $q$
  select i.* from public.invoices i where i.member_id = mm and i.period = '2026-09';
$q$;


-- ── the gate follows its row ──────────────────────────────────────────
select set_config('gate.ca', pg_temp.seller('on', 'CAD', '123456789 RT0001', '', 13, 11300)::text, true);
select is(pg_temp.issue(current_setting('gate.ca')::uuid), '', 'a Canadian seller issues while its row says supported');

update public.tax_reference set value = jsonb_set(value, '{supported}', 'false')
 where domain = 'issuing_gate' and country = 'CA' and key = 'gate';
select ok(pg_temp.issue(pg_temp.seller('off', 'CAD', '123456789 RT0001', '', 13, 11300)) like '%seller_country_unsupported%',
          'supported = false refuses with seller_country_unsupported');

update public.tax_reference set value = jsonb_set(jsonb_set(value, '{supported}', 'true'), '{national_channel_required}', 'true')
 where domain = 'issuing_gate' and country = 'CA' and key = 'gate';
select ok(pg_temp.issue(pg_temp.seller('chan', 'CAD', '123456789 RT0001', '', 13, 11300)) like '%seller_country_unsupported%',
          'a national channel refuses whatever supported says');

update public.tax_reference set value = jsonb_set(value, '{national_channel_required}', 'false')
 where domain = 'issuing_gate' and country = 'CA' and key = 'gate';
select is(pg_temp.issue(pg_temp.seller('back', 'CAD', '123456789 RT0001', '', 13, 11300)), '',
          'supported again, no channel: it issues');

update public.tax_reference set valid_to = current_date, valid_from = current_date - 1
 where domain = 'issuing_gate' and country = 'CA' and key = 'gate';
select ok(pg_temp.issue(pg_temp.seller('none', 'CAD', '123456789 RT0001', '', 13, 11300)) like '%seller_country_unsupported%',
          'a country whose row ended has no row: refused');

select ok(not exists (select 1 from public.tax_reference where domain = 'issuing_gate' and country = 'US'),
          'the United States have no row');
select is(public.issuing_gate_of('el') ->> 'supported', 'true', 'EL reads the Greek row');
select is(public.issuing_gate_of('IT') ->> 'national_channel_required', 'true', 'Italy is behind a national channel');
select is(public.issuing_gate_of('ES') ->> 'requires_tax_number', 'true', 'Spain asks for a tax number');
select is(public.issuing_gate_of('CH') ->> 'currency', 'CHF', 'Switzerland states the VAT in francs');

-- ── the tax point policy follows its rows ─────────────────────────────
select is((select p.standard || '/' || p.invoice_option || '/' || p.cash_option || '/' || p.cash_backstop
             from public.vat_tax_point_policy('fr') p), 'receipt/true/false/none', 'France: receipts, the debits option, no cash option');
select is((select p.standard || '/' || p.cash_backstop from public.vat_tax_point_policy('ES') p),
          'service_period/end_of_following_year', 'Spain: the service period, a backstop');
select is((select p.standard from public.vat_tax_point_policy('NO') p), 'invoice', 'a country with no row falls to the shared row');
update public.tax_reference set value = jsonb_set(value, '{standard}', '"receipt"')
 where domain = 'tax_point' and country = '*' and key = 'policy';
select is((select p.standard from public.vat_tax_point_policy('NO') p), 'receipt', 'and follows it when it changes');

-- ── the shapes ────────────────────────────────────────────────────────
select ok(public.tax_reference_valid('threshold', '{"cents":100,"effect":"immediate","currency":"EUR"}'::jsonb)
          and not public.tax_reference_valid('threshold', '{"cents":0,"effect":"immediate","currency":"EUR"}'::jsonb)
          and not public.tax_reference_valid('threshold', '{"cents":100,"effect":"sometime","currency":"EUR"}'::jsonb)
          and not public.tax_reference_valid('tax_point', '{"standard":"never","invoice_option":false,"cash_option":true,"cash_backstop":"none"}'::jsonb)
          and not public.tax_reference_valid('mandate', '{"duty":"issue_all","from":"2026-02-30"}'::jsonb)
          and public.tax_reference_valid('mandate', '{"duty":"issue_all","from":"2026-02-28"}'::jsonb)
          and not public.tax_reference_valid('issuing_gate', '{"supported":true}'::jsonb)
          and public.tax_reference_valid('issuing_gate', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"EUR"}'::jsonb),
          'each of the four domains refuses what is not its shape');

select * from finish();
rollback;
