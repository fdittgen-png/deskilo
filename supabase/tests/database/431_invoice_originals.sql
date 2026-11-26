-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3853 (0772) -- an issued invoice keeps one stored original. An issuer of
-- the invoice's business uploads its PDF once, at the path its digest names,
-- and records it once; the server keeps the record only when the PDF is
-- there and the XML names the invoice's number, currency and amount due.
-- Whoever reads the invoice reads its original; nobody changes it. An
-- invoice issued before keeps none; a voided invoice and a credit note keep
-- theirs. Rolled back.
begin;
select plan(39);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner uuid := '00000000-0000-4000-8000-000000003853';
  person_a uuid := '00000000-0000-4000-8000-000000003854';
  person_b uuid := '00000000-0000-4000-8000-000000003855';
  other_owner uuid := '00000000-0000-4000-8000-000000003856';
  ws uuid; other uuid; member_a uuid;
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
  values (ws, person_b, 100, '2026-01-01');
  -- member A's invoices; ORIG-0003 is made one issued before originals were
  -- kept, ORIG-0004 is voided and ORIG-CN-0001 a credit note, below
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, parties,
                               keeps_original)
  select ws, member_a, member_a, n, 'Desk', '[]'::jsonb, case when n like 'ORIG-CN%' then -12345 else 12345 end,
         'EUR', 'Ana Original', 'ORIGINALS', 'Owner', 'sig', '{}'::jsonb, false
    from unnest(array['ORIG-0001', 'ORIG-0002', 'ORIG-0003', 'ORIG-0004', 'ORIG-CN-0001']) n;
  perform set_config('deskilo.test.ws', ws::text, false);
  perform set_config('deskilo.test.other', other::text, false);
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
create or replace function pg_temp.sha(p text) returns text language sql as $$
  select encode(sha256(convert_to(p, 'UTF8')), 'hex')
$$;
-- the object path of [p_number]'s PDF whose digest is [p_sha], in [p_ws]
create or replace function pg_temp.path(p_number text, p_sha text, p_ws text default 'ws') returns text language sql as $$
  select current_setting('deskilo.test.' || p_ws) || '/' || current_setting('deskilo.test.inv_' || replace(lower(p_number), '-', '_'))
         || '/' || p_sha || '.pdf'
$$;
-- an upload as the caller, as the storage server writes it
create or replace function pg_temp.upload(p_name text) returns text language sql as $$
  insert into storage.objects (bucket_id, name, owner, metadata)
  values ('invoice-originals', p_name, auth.uid(), jsonb_build_object('size', 4321, 'mimetype', 'application/pdf'))
  returning name
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
create or replace function pg_temp.store(p_number text, p_sha text, p_xml text) returns text language sql as $$
  select format('select public.store_invoice_original(%L, %L, %L)',
                current_setting('deskilo.test.inv_' || replace(lower(p_number), '-', '_')), p_sha, p_xml)
$$;
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.test.' || p), 'role', 'authenticated')::text, true)
$$;
grant execute on all functions in schema pg_temp to authenticated;
-- the ids, read before any caller who does not see the invoices
select set_config('deskilo.test.inv_' || replace(lower(n), '-', '_'), pg_temp.inv(n)::text, false)
  from unnest(array['ORIG-0001', 'ORIG-0002', 'ORIG-0003', 'ORIG-0004', 'ORIG-CN-0001']) n;

select is((select keeps_original from public.invoices where number = 'ORIG-0001'), true,
  'an invoice issued now keeps an original, whatever its insert says');

-- test data, the guard lifted for these rows' change and armed again: an
-- invoice issued before originals were kept, and a voided one
alter table public.invoices disable trigger invoices_no_mutation;
update public.invoices set keeps_original = false where number = 'ORIG-0003';
update public.invoices set voided_at = now() where number = 'ORIG-0004';
alter table public.invoices enable trigger invoices_no_mutation;

-- ── the upload ──
select pg_temp.as_user('owner');
set local role authenticated;
select lives_ok(format('select pg_temp.upload(%L)', pg_temp.path('ORIG-0001', pg_temp.sha('one'))),
  'an issuer uploads the PDF at the path its digest names');
select throws_ok(format('select pg_temp.upload(%L)', pg_temp.path('ORIG-0002', pg_temp.sha('two'), 'other')),
  '42501', null, 'not in a folder of another business');
select throws_ok(format('select pg_temp.upload(%L)',
    current_setting('deskilo.test.ws') || '/' || current_setting('deskilo.test.inv_orig_0002') || '/original.pdf'),
  '42501', null, 'not at a path of any other shape');
select throws_ok(format('select pg_temp.upload(%L)', pg_temp.path('ORIG-0003', pg_temp.sha('three'))),
  '42501', null, 'not for an invoice issued before originals were kept');

-- ── recording it ──
select is(public.store_invoice_original(pg_temp.inv('ORIG-0001'), pg_temp.sha('one'),
            pg_temp.cii('ORIG-0001', 'EUR', '123.45')) ->> 'path',
  pg_temp.path('ORIG-0001', pg_temp.sha('one')), 'an issuer records the original at the path its digest names');
select is((select pdf_bytes::int from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0001')), 4321,
  'with the size of the stored object');
select throws_ok(pg_temp.store('ORIG-0001', pg_temp.sha('one'), pg_temp.cii('ORIG-0001', 'EUR', '123.45')),
  '23505', 'this invoice already has its original', 'a second original is refused');
select throws_ok(format('select pg_temp.upload(%L)', pg_temp.path('ORIG-0001', pg_temp.sha('another'))),
  '42501', null, 'and so is a second upload for an invoice that has one');

-- ── refusals: nothing is recorded ──
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '22023', 'the original''s PDF is not stored', 'no record without the uploaded PDF');
select throws_ok(pg_temp.store('ORIG-0002', 'not-a-digest', pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '22023', 'the PDF''s digest is not a SHA-256', 'a digest that is not a SHA-256 is refused');
select pg_temp.upload(pg_temp.path('ORIG-0002', pg_temp.sha('two')));
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0001', 'EUR', '123.45')),
  '22023', 'the structured part does not name this invoice''s number', 'another invoice''s number is refused');
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0002', 'CHF', '123.45')),
  '22023', 'the structured part does not name this invoice''s currency', 'another currency is refused');
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0002', 'EUR', '123.40')),
  '22023', 'the structured part does not name this invoice''s amount due', 'another amount due is refused');
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'),
    replace(pg_temp.cii('ORIG-0002', 'EUR', '123.45'), '<ram:ID>ORIG-0002</ram:ID>',
            '<ram:ID>ORIG-0002</ram:ID><ram:ID>ORIG-0002</ram:ID>')),
  '22023', 'the structured part does not name this invoice''s number', 'a number named twice is no number');
select throws_ok(pg_temp.store('ORIG-0003', pg_temp.sha('three'), pg_temp.cii('ORIG-0003', 'EUR', '123.45')),
  '22023', 'this invoice was issued before its original was kept', 'an invoice issued before keeps none');
reset role;
-- the bound made small for this test only, so a large file is not built
create or replace function public.invoice_original_xml_max_bytes()
returns integer language sql immutable as $$ select 64 $$;
select pg_temp.as_user('owner');
set local role authenticated;
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '22023', 'the structured part is larger than 64 bytes', 'an XML larger than its bound is refused');
select is((select count(*)::int from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0002')), 0,
  'a refused original is not recorded');
select throws_ok($$insert into public.invoice_originals (invoice_id, workspace_id, path, pdf_bytes, pdf_sha256, xml, xml_sha256)
    select id, workspace_id, 'x', 1, repeat('0', 64), '', '' from public.invoices where number = 'ORIG-0002'$$,
  '42501', null, 'nobody records an original by hand');
reset role;
create or replace function public.invoice_original_xml_max_bytes()
returns integer language sql immutable as $$ select 512 * 1024 $$;

select is((select created_by_user from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0001')),
  current_setting('deskilo.test.owner')::uuid, 'it records who stored it');
select is((select artifacts ->> 'pdf_sha256' from public.provenance_envelopes
            where result_kind = 'invoice_original' and result_id = pg_temp.inv('ORIG-0001')),
  pg_temp.sha('one'), 'the recorded original leaves a provenance entry with its digest');
select is((select issuer ->> 'number' from public.provenance_envelopes
            where result_kind = 'invoice_original' and result_id = pg_temp.inv('ORIG-0001')),
  'ORIG-0001', 'and the invoice''s number, never the bytes');

-- ── who else ──
select pg_temp.as_user('other_owner');
set local role authenticated;
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '42501', 'not allowed to issue invoices', 'an issuer of another business records none');
select is((select count(*)::int from storage.objects where bucket_id = 'invoice-originals'), 0,
  'and sees no PDF of this business, recorded or not');
reset role;
select pg_temp.as_user('person_a');
set local role authenticated;
select throws_ok(pg_temp.store('ORIG-0002', pg_temp.sha('two'), pg_temp.cii('ORIG-0002', 'EUR', '123.45')),
  '42501', 'not allowed to issue invoices', 'a member who may not issue invoices records none');
select is((select count(*)::int from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0001')), 1,
  'the member reads the original of their own invoice');
select is((select count(*)::int from storage.objects where bucket_id = 'invoice-originals'
            and name = pg_temp.path('ORIG-0001', pg_temp.sha('one'))), 1,
  'and its PDF');
reset role;
select pg_temp.as_user('person_b');
set local role authenticated;
select is((select count(*)::int from public.invoice_originals), 0, 'another member reads no original');
select is((select count(*)::int from storage.objects where bucket_id = 'invoice-originals'), 0,
  'and no PDF');
reset role;

-- ── nobody changes it ──
select pg_temp.as_user('owner');
set local role authenticated;
update storage.objects set metadata = '{"size": 1}'::jsonb
 where bucket_id = 'invoice-originals' and name = pg_temp.path('ORIG-0001', pg_temp.sha('one'));
reset role;
select is((select (metadata ->> 'size')::int from storage.objects
            where bucket_id = 'invoice-originals' and name = pg_temp.path('ORIG-0001', pg_temp.sha('one'))), 4321,
  'an issuer does not change a stored PDF');
select is((select count(*)::int from pg_policies where schemaname = 'storage' and tablename = 'objects'
            and policyname like 'invoice_originals%' and cmd in ('UPDATE', 'DELETE', 'ALL')), 0,
  'no policy updates or deletes a stored PDF');
select throws_ok($$update public.invoice_originals set pdf_sha256 = repeat('1', 64)$$,
  '42501', 'an invoice''s original is never changed', 'nobody changes a recorded original');
-- #4492: nor removes one, the server's own role included
create or replace function pg_temp.server(p_sql text) returns text language plpgsql as $f$
begin
  set local role service_role;
  begin
    execute p_sql;
  exception when others then
    reset role;
    return 'ERR ' || sqlstate;
  end;
  reset role;
  return 'done';
end
$f$;
select is(pg_temp.server(format('delete from public.invoice_originals where invoice_id = %L', pg_temp.inv('ORIG-0001'))),
  'ERR DKL03', 'nobody deletes a recorded original');
select is((select count(*)::int from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0001')), 1,
  'and the original is still recorded');

-- ── the folder is part of the rule ──
select pg_temp.as_user('owner');
set local role authenticated;
select throws_ok(format('select public.store_invoice_original(%L, %L, %L)', gen_random_uuid(), pg_temp.sha('x'),
    pg_temp.cii('ORIG-9999', 'EUR', '1.00')),
  '42501', 'not allowed to issue invoices', 'an invoice that does not exist answers as one the caller may not issue');
reset role;
-- test data written as the server: a record whose file sits in another
-- business's folder, and a file of a malformed name
insert into storage.objects (bucket_id, name, metadata)
values ('invoice-originals', pg_temp.path('ORIG-0002', pg_temp.sha('elsewhere'), 'other'), '{"size": 9}'::jsonb),
       ('invoice-originals', 'not-a-business/not-an-invoice.pdf', '{"size": 9}'::jsonb);
insert into public.invoice_originals (invoice_id, workspace_id, path, pdf_bytes, pdf_sha256, xml, xml_sha256)
values (pg_temp.inv('ORIG-0002'), current_setting('deskilo.test.ws')::uuid,
        pg_temp.path('ORIG-0002', pg_temp.sha('elsewhere'), 'other'), 9, pg_temp.sha('elsewhere'), '', '');
select pg_temp.as_user('person_a');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'invoice-originals'
            and name = pg_temp.path('ORIG-0002', pg_temp.sha('elsewhere'), 'other')), 0,
  'a recorded file in a folder not of its record''s business is read by nobody');
reset role;
select pg_temp.as_user('owner');
set local role authenticated;
select is((select count(*)::int from storage.objects where bucket_id = 'invoice-originals'
            and name = 'not-a-business/not-an-invoice.pdf'), 0,
  'a file of a malformed name answers no row, without an error');
reset role;
-- test data leaves as it came: the guards are lifted for it and armed again
alter table public.invoice_originals disable trigger user;
delete from public.invoice_originals where invoice_id = pg_temp.inv('ORIG-0002');
alter table public.invoice_originals enable trigger user;

-- ── a voided invoice and a credit note keep theirs ──
select pg_temp.as_user('owner');
set local role authenticated;
select lives_ok(format('select pg_temp.upload(%L); %s', pg_temp.path('ORIG-0004', pg_temp.sha('four')),
    pg_temp.store('ORIG-0004', pg_temp.sha('four'), pg_temp.cii('ORIG-0004', 'EUR', '123.45'))),
  'a voided invoice keeps the original that was sent');
select lives_ok(format('select pg_temp.upload(%L); %s', pg_temp.path('ORIG-CN-0001', pg_temp.sha('cn')),
    pg_temp.store('ORIG-CN-0001', pg_temp.sha('cn'), pg_temp.cii('ORIG-CN-0001', 'EUR', '-123.45'))),
  'and so does a credit note');
reset role;

select * from finish();
rollback;
