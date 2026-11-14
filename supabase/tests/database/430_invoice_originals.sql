-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3853 (0771) -- an issued invoice keeps one stored original. An issuer
-- stores it once; the server keeps it only when it is a PDF and its XML
-- names the invoice's number, currency and amount due. Whoever reads the
-- invoice reads its original; nobody changes it. An invoice issued before
-- keeps none. Rolled back.
begin;
select plan(20);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner uuid := '00000000-0000-4000-8000-000000003853';
  person_a uuid := '00000000-0000-4000-8000-000000003854';
  person_b uuid := '00000000-0000-4000-8000-000000003855';
  other_owner uuid := '00000000-0000-4000-8000-000000003856';
  ws uuid; other uuid; member_a uuid; member_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'originals-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner, person_a, person_b, other_owner]) u;
  insert into public.profiles (id, display_name) values (person_a, 'Ana Original'), (person_b, 'Ben Original')
  on conflict (id) do update set display_name = excluded.display_name;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 street, city, postal_code, vat_regime, feature_flags)
  values ('ORIGINALS', 'FR', 'EUR', 'Europe/Paris', owner, '1 rue A', 'Pézenas', '34120',
          'not_subject', '{"invoicing": true}') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (ws, owner, true, true, '2026-01-01');
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 street, city, postal_code, vat_regime, feature_flags)
  values ('ORIGINALS-OTHER', 'FR', 'EUR', 'Europe/Paris', other_owner, '2 rue B', 'Sète', '34200',
          'not_subject', '{"invoicing": true}') returning id into other;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (other, other_owner, true, true, '2026-01-01');
  insert into public.members (workspace_id, user_id, subscription_pct, joined_at)
  values (ws, person_a, 100, '2026-01-01') returning id into member_a;
  insert into public.members (workspace_id, user_id, subscription_pct, joined_at)
  values (ws, person_b, 100, '2026-01-01') returning id into member_b;
  -- two invoices of member A, the second one issued before originals were
  -- kept is made below
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, parties,
                               keeps_original)
  select ws, member_a, member_a, n, 'Desk', '[]'::jsonb, 12345, 'EUR', 'Ana Original', 'ORIGINALS',
         'Owner', 'sig', '{}'::jsonb, false
    from unnest(array['ORIG-0001', 'ORIG-0002', 'ORIG-0003']) n;
  perform set_config('deskilo.test.owner', owner::text, false);
  perform set_config('deskilo.test.person_a', person_a::text, false);
  perform set_config('deskilo.test.person_b', person_b::text, false);
  perform set_config('deskilo.test.other_owner', other_owner::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.inv(p_number text) returns uuid language sql as $$
  select id from public.invoices where number = p_number
$$;
create or replace function pg_temp.pdf() returns text language sql as $$
  select encode(convert_to('%PDF-1.7 an invoice', 'UTF8'), 'base64')
$$;
create or replace function pg_temp.cii(p_number text, p_currency text, p_due text) returns text language sql as $$
  select format($x$<?xml version="1.0" encoding="UTF-8"?>
<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100">
  <rsm:ExchangedDocument><ram:ID>%s</ram:ID></rsm:ExchangedDocument>
  <rsm:SupplyChainTradeTransaction>
    <ram:ApplicableHeaderTradeSettlement>
      <ram:InvoiceCurrencyCode>%s</ram:InvoiceCurrencyCode>
      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
        <ram:DuePayableAmount>%s</ram:DuePayableAmount>
      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
    </ram:ApplicableHeaderTradeSettlement>
  </rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>$x$, p_number, p_currency, p_due)
$$;
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.test.' || p), 'role', 'authenticated')::text, true)
$$;
grant execute on all functions in schema pg_temp to authenticated;

select is((select keeps_original from public.invoices where number = 'ORIG-0001'), true,
  'an invoice issued now keeps an original, whatever its insert says');

-- an invoice issued before originals were kept (test data: the guard is
-- lifted for this row's change and armed again)
alter table public.invoices disable trigger invoices_no_mutation;
update public.invoices set keeps_original = false where number = 'ORIG-0003';
alter table public.invoices enable trigger invoices_no_mutation;

-- ── the issuer stores it once ──
select pg_temp.as_user('owner');
set local role authenticated;
select is(public.store_invoice_original(pg_temp.inv('ORIG-0001'), pg_temp.pdf(),
            pg_temp.cii('ORIG-0001', 'EUR', '123.45')) ->> 'sha256',
  encode(sha256(convert_to('%PDF-1.7 an invoice', 'UTF8')), 'hex'),
  'an issuer stores the original and the server returns its digest');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0001'), pg_temp.pdf(), pg_temp.cii('ORIG-0001', 'EUR', '123.45')),
  '23505', 'this invoice already has its original', 'a second original is refused');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), pg_temp.pdf(), pg_temp.cii('ORIG-0001', 'EUR', '123.45')),
  '22023', 'the structured part does not name this invoice''s number', 'another invoice''s number is refused');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), pg_temp.pdf(), pg_temp.cii('ORIG-0002', 'CHF', '123.45')),
  '22023', 'the structured part does not name this invoice''s currency', 'another currency is refused');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), pg_temp.pdf(), pg_temp.cii('ORIG-0002', 'EUR', '123.40')),
  '22023', 'the structured part does not name this invoice''s amount due', 'another amount due is refused');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), encode(convert_to('not a pdf', 'UTF8'), 'base64'),
    pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '22023', 'the original is not a PDF', 'bytes that are not a PDF are refused');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0003'), pg_temp.pdf(), pg_temp.cii('ORIG-0003', 'EUR', '123.45')),
  '22023', 'this invoice was issued before its original was kept', 'an invoice issued before keeps none');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), encode(convert_to('%PDF-' || repeat('x', public.invoice_original_max_bytes()), 'UTF8'), 'base64'),
    pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '22023', format('the original is larger than %s bytes', public.invoice_original_max_bytes()),
  'an original larger than the bound is refused');
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), pg_temp.pdf(),
    replace(pg_temp.cii('ORIG-0002', 'EUR', '123.45'), '<ram:ID>ORIG-0002</ram:ID>',
            '<ram:ID>ORIG-0002</ram:ID><ram:ID>ORIG-0002</ram:ID>')),
  '22023', 'the structured part does not name this invoice''s number', 'a number named twice is no number');
select throws_ok(format($$insert into public.invoice_originals (invoice_id, workspace_id, pdf, xml, sha256, xml_sha256)
    select id, workspace_id, '\x00', '\x00', '', '' from public.invoices where number = 'ORIG-0002'$$),
  '42501', null, 'nobody writes an original by hand');
select is((select count(*)::int from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0002')), 0,
  'a refused original is not kept');
reset role;

select is((select created_by_user from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0001')),
  current_setting('deskilo.test.owner')::uuid, 'it records who stored it');

select is((select artifacts ->> 'pdf_sha256' from public.provenance_envelopes
            where result_kind = 'invoice_original' and result_id = pg_temp.inv('ORIG-0001')),
  encode(sha256(convert_to('%PDF-1.7 an invoice', 'UTF8')), 'hex'),
  'the stored original leaves a provenance entry with its digest');
select is((select issuer ->> 'number' from public.provenance_envelopes
            where result_kind = 'invoice_original' and result_id = pg_temp.inv('ORIG-0001')),
  'ORIG-0001', 'and the invoice''s number, never the bytes');

-- ── an issuer of another business ──
-- the invoice's id is read first: that issuer does not see the invoice
select set_config('deskilo.test.orig2', pg_temp.inv('ORIG-0002')::text, false);
select pg_temp.as_user('other_owner');
set local role authenticated;
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    current_setting('deskilo.test.orig2'), pg_temp.pdf(), pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '42501', 'not allowed to issue invoices', 'an issuer of another business stores none');
reset role;

-- ── a member who may not issue ──
select pg_temp.as_user('person_a');
set local role authenticated;
select throws_ok(format($$select public.store_invoice_original(%L, %L, %L)$$,
    pg_temp.inv('ORIG-0002'), pg_temp.pdf(), pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '42501', 'not allowed to issue invoices', 'a member who may not issue invoices stores none');
-- ── whoever reads the invoice reads its original ──
select is((select encode(pdf, 'base64') from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0001')),
  pg_temp.pdf(), 'the member reads the original of their own invoice, byte for byte');
reset role;
select pg_temp.as_user('person_b');
set local role authenticated;
select is((select count(*)::int from public.invoice_originals), 0, 'another member reads none');
reset role;

select throws_ok($$update public.invoice_originals set sha256 = 'x'$$,
  '42501', 'an invoice''s original is never changed', 'nobody changes a stored original');

select * from finish();
rollback;
