-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2356: DesKilo issues for a seller in every member state of the Union.
-- One real create_invoice per country proves the four things the gate
-- waited for: the country is accepted, the zero-rated line is Z (0407),
-- the VAT is stated in the national currency (art. 230), and the frozen
-- legal facts name the seller's country — which is what picks the
-- statutory mention and the payment clauses on the client (Dart
-- `defaultExemptionMention`, `LegalProfile.euBusiness`). Then the country
-- rules one at a time: outside the Union, a foreign currency, the German
-- tax number, the Spanish, Italian and French customer identifiers, and
-- an exempt seller's own small-business exemption. Rolled back.
begin;
select plan(40);

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
           'owner-' || lower(cc) || tag || '@eu2356.test','',now(),now(),now()),
          (um,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
           'member-' || lower(cc) || tag || '@eu2356.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by,street,city,postal_code,
                                vat_regime,vat_id,legal_id,feature_flags)
   values ('EU 2356 ' || cc || tag, cc, currency, 'Europe/Brussels', uo, '1 Synthetic Street', 'Capital', '1000',
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

-- Issue the month; '' when it went through with the four facts right.
create or replace function pg_temp.issue(cc text, currency text) returns text language plpgsql as $issue$
declare
  mm uuid;
  v_inv public.invoices;
  v_missing text[];
begin
  -- The customer states its identifier: Italy asks for it from everyone.
  mm := pg_temp.seller(cc, currency, 'vat_registered', cc || '123456789', 'REG-' || cc,
                       'consumer', 'CUST-' || cc);
  v_missing := pg_temp.missing(mm);
  if cardinality(v_missing) > 0 then return 'refused: ' || array_to_string(v_missing, ','); end if;
  perform public.create_invoice((select workspace_id from public.members where id = mm), mm, '2026-09');
  select * into v_inv from public.invoices where member_id = mm and period = '2026-09';
  if v_inv.id is null then return 'no invoice'; end if;
  if not exists (select 1 from jsonb_array_elements(v_inv.vat_totals) t where t ->> 'category' = 'Z') then
    return 'no Z in ' || v_inv.vat_totals::text;
  end if;
  if v_inv.currency <> currency then return 'currency ' || v_inv.currency; end if;
  if v_inv.legal_snapshot ->> 'seller_country' <> cc then
    return 'snapshot country ' || coalesce(v_inv.legal_snapshot ->> 'seller_country', 'null');
  end if;
  return '';
exception when others then
  return 'error: ' || sqlerrm;
end;
$issue$;

-- ── every member state ────────────────────────────────────────────────
select is(pg_temp.issue(c.cc, c.cur), '', c.cc || ': issued, Z line, ' || c.cur || ', seller country frozen')
  from (values ('AT','EUR'),('BE','EUR'),('BG','EUR'),('CY','EUR'),('CZ','CZK'),('DE','EUR'),
               ('DK','DKK'),('EE','EUR'),('ES','EUR'),('FI','EUR'),('FR','EUR'),('GR','EUR'),
               ('HR','EUR'),('HU','HUF'),('IE','EUR'),('IT','EUR'),('LT','EUR'),('LU','EUR'),
               ('LV','EUR'),('MT','EUR'),('NL','EUR'),('PL','PLN'),('PT','EUR'),('RO','RON'),
               ('SE','SEK'),('SI','EUR'),('SK','EUR')) as c(cc, cur)
 order by c.cc;

-- ── the country rules ─────────────────────────────────────────────────
select ok('seller_country_unsupported' = any(pg_temp.missing(
          pg_temp.seller('CH','CHF','vat_registered','CHE123456789','REG-CH'))),
          'outside the Union: still issued outside the app');
select ok('vat_national_currency' = any(pg_temp.missing(
          pg_temp.seller('PL','EUR','vat_registered','PL1234567890','REG-PL', tag => '-eur'))),
          'a Polish seller invoicing VAT in euros: refused, the VAT must be in złoty (art. 230)');
select ok(not ('vat_national_currency' = any(pg_temp.missing(
          pg_temp.seller('IE','USD','vat_registered','IE1234567T','REG-IE', tag => '-usd')))),
          'a euro-area seller may invoice in another currency');
select ok('seller_tax_number' = any(pg_temp.missing(
          pg_temp.seller('DE','EUR','exempt','','', tag => '-none'))),
          'a German Kleinunternehmer with neither USt-IdNr nor Steuernummer: refused (§ 14 Abs. 4 Nr. 2)');
select is(pg_temp.missing(pg_temp.seller('DE','EUR','exempt','','12/345/67890', tag => '-st')),
          '{}'::text[], 'with the Steuernummer, the small-business exemption issues: E, statutory mention');
select ok('buyer_tax_id' = any(pg_temp.missing(
          pg_temp.seller('ES','EUR','vat_registered','ESB12345678','B12345678', 'business', tag => '-b2b'))),
          'Spain: a business customer without its NIF is refused');
select is(pg_temp.missing(pg_temp.seller('ES','EUR','vat_registered','ESB12345678','B12345678', 'business',
          'B87654321', tag => '-nif')),
          '{}'::text[], 'Spain: with the customer''s NIF it issues');
select ok('buyer_tax_id' = any(pg_temp.missing(
          pg_temp.seller('IT','EUR','vat_registered','IT12345678901','RSSMRA80A01H501U', tag => '-cf'))),
          'Italy: a customer in Italy without codice fiscale is refused');
select ok('seller_vat_id' = any(pg_temp.missing(
          pg_temp.seller('IT','EUR','exempt','','RSSMRA80A01H501U', 'consumer', 'VRDLGI80A01H501U', tag => '-forf'))),
          'Italy: a forfettario states its partita IVA');
select ok('buyer_tax_id' = any(pg_temp.missing(
          pg_temp.seller('FR','EUR','vat_registered','FR12345678901','123456789', 'business', tag => '-siren'))),
          'France: a business customer in France without its SIREN is refused (art. 242 nonies A)');
select is(pg_temp.missing(pg_temp.seller('FR','EUR','vat_registered','FR12345678901','123456789', 'consumer',
          tag => '-conso')),
          '{}'::text[], 'France: a consumer has no SIREN to state');
select ok(not ('buyer_tax_id' = any(pg_temp.missing(
          pg_temp.seller('FR','EUR','not_subject','','W123456789', 'business', tag => '-asso')))),
          'France: an association outside the scope is not asked for its customer''s SIREN');
select is((select count(*)::int from public.invoices i join public.workspaces w on w.id = i.workspace_id
           where w.name = 'EU 2356 DE-st'), 0,
          'the readiness check issues nothing');

select * from finish();
rollback;
