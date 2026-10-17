-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2567 / 0458 (C1a of #2464): ONE suppliers entity. Real roles throughout
-- (authenticated through the definer RPCs and the RLS policies); every
-- refusal is followed by a readback proving nothing changed.
--   A positive control: a verified tax identifier creates one supplier and links
--   B the same verified identifier under a new spelling links the SAME supplier
--   C two same-name documents without an identifier are NOT merged: review
--   D an unverified / multiple identifier and a VAT-group identifier: review
--   E the same tax identifier in another workspace is a separate supplier
--   F the backfill is idempotent and leaves the document snapshots untouched
--   G a person resolves a review candidate (and only once)
--   H who may read and write: a plain member, an admin without manageBilling,
--     the flag off; readbacks after every refusal
--   I bank details: revisions, outcomes, who changed them, no client write
--   J numbers and duplicates
begin;
select plan(67);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

-- The refusal text of running [p_sql] as [p_user]; '' when it worked.
create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;

-- An inbox document arriving as [p_user]; '' when stored.
create function pg_temp.ingest(p_user uuid, p_ws uuid, p_tag text, p_name text, p_vat text) returns text
language plpgsql as $$
begin
  return pg_temp.as_err(p_user, format(
    'select public.ingest_einvoice(%L, ''ubl'', %L, %L::jsonb)', p_ws, '<Invoice>' || p_tag || '</Invoice>',
    jsonb_build_object('number', p_tag, 'issue_date', '2026-09-01', 'currency', 'EUR',
      'supplier_name', p_name, 'supplier_vat_id', p_vat,
      'net_cents', 1000, 'tax_cents', 200, 'gross_cents', 1200)::text));
end;
$$;

create function pg_temp.supplier_of(p_ws uuid, p_tag text) returns uuid language sql as $$
  select supplier_id from public.einvoice_inbox where workspace_id = p_ws and invoice_number = p_tag;
$$;

create function pg_temp.review_of(p_ws uuid, p_tag text) returns public.supplier_review_candidates language sql as $$
  select c.* from public.supplier_review_candidates c
    join public.einvoice_inbox i on i.id = c.source_id
   where c.workspace_id = p_ws and i.invoice_number = p_tag;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-00002567' || lpad(i::text, 4, '0'))::uuid,
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@suppliers.test', '', now(), now(), now()
  from generate_series(1, 4) i;
-- 1 owner of A, 2 a plain member of A, 3 an admin of A, 4 owner of B.

select pg_temp.act_as('00000000-0000-4000-8000-000025670001');
select set_config('t.a', public.create_workspace('Suppliers A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-000025670004');
select set_config('t.b', public.create_workspace('Suppliers B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"services": true, "supplyExpenses": true, "invoicing": true, "einvoiceCustomerDelivery": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-000025670022', current_setting('t.a')::uuid, '00000000-0000-4000-8000-000025670002', false, false, 'active'),
 ('00000000-0000-4000-8000-000025670033', current_setting('t.a')::uuid, '00000000-0000-4000-8000-000025670003', false, true, 'active');

-- ── pure helpers ───────────────────────────────────────────────────────
select is(public.supplier_tax_identifier('fr 12.345.678-901') ->> 'value', 'FR12345678901',
  'only the presentation separators are dropped, the prefix is upper-cased');
select is(public.supplier_tax_identifier('DE123456789') ->> 'jurisdiction', 'DE', 'the jurisdiction is the prefix');
select ok(public.supplier_tax_identifier('123456789') is null, 'no prefix: not a verified identifier');
select ok(public.supplier_tax_identifier('XX123456789') is null, 'a prefix the reference store does not know is not verified');
select ok(public.supplier_tax_identifier('DE12345') is null, 'a body that breaks the jurisdiction''s pattern is not verified');
select ok(public.supplier_tax_identifier('FR12345678901, DE123456789') is null, 'two identifiers in one field are not one identifier');
select is(public.supplier_iban_check('FR76 3000 6000 0112 3456 7890 189'), 'valid', 'a valid IBAN passes the mod-97 check');
select is(public.supplier_iban_check('FR7630006000011234567890188'), 'checksum', 'a wrong check digit is named');

-- ── A / B: one verified identifier, one supplier ───────────────────────
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670001', current_setting('t.a')::uuid, 'F-1', 'ACME Sarl', 'FR 12 345 678 901'), '',
  'A: golden: the owner receives an invoice');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid), 1, 'A: one supplier was created');
select is((select concat_ws('/', supplier_number, tax_identifier, name) from public.suppliers where workspace_id = current_setting('t.a')::uuid),
  '1/FR12345678901/ACME Sarl', 'A: it carries the next number, the canonical identifier and the name');
select isnt(pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'), null::uuid, 'A: the document is linked');
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670001', current_setting('t.a')::uuid, 'F-2', 'ACME S.A.R.L. (Paris)', 'fr12.345.678.901'), '',
  'B: the same identifier arrives under another spelling of the name');
select is(pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-2'), pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'),
  'B: it links to the SAME supplier');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid), 1, 'B: still one supplier');
select is((select supplier_name from public.einvoice_inbox where workspace_id = current_setting('t.a')::uuid and invoice_number = 'F-2'),
  'ACME S.A.R.L. (Paris)', 'B: the document keeps the raw name it arrived with');

-- ── C: names alone never merge ─────────────────────────────────────────
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670001', current_setting('t.a')::uuid, 'F-3', 'Bob Plumbing', ''), '', 'C: a document without an identifier');
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670001', current_setting('t.a')::uuid, 'F-4', 'Bob Plumbing', ''), '', 'C: another one with the same name');
select ok(pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-3') is null and pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-4') is null,
  'C: neither is linked');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid), 1, 'C: no supplier was invented from a name');
select is((pg_temp.review_of(current_setting('t.a')::uuid, 'F-3')).reason, 'missing_identifier', 'C: each waits as an explicit review candidate');
select is((select count(*)::int from public.supplier_review_candidates where workspace_id = current_setting('t.a')::uuid and status = 'open'), 2,
  'C: two candidates, the records stay separate');

-- ── D: unverified and group identifiers ────────────────────────────────
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670001', current_setting('t.a')::uuid, 'F-5', 'Broken Ltd', 'FR1234'), '', 'D: an identifier that does not verify');
select is((pg_temp.review_of(current_setting('t.a')::uuid, 'F-5')).reason, 'unverified_identifier', 'D: it is a review, not a supplier');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001',
  format('select public.save_supplier(%L, null, ''Group HQ GmbH'', ''DE 123 456 789'', ''vat_group'', '''', '''', '''', '''', '''', '''')', current_setting('t.a'))), '',
  'D: the owner records a supplier whose identifier is a VAT-group identifier');
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670001', current_setting('t.a')::uuid, 'F-6', 'Subsidiary GmbH', 'DE123456789'), '',
  'D: a document with that group identifier arrives');
select is((pg_temp.review_of(current_setting('t.a')::uuid, 'F-6')).reason, 'group_identifier', 'D: a group identifier is never proof of the same payee: review');
select ok(pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-6') is null, 'D: the document is not linked');
select is(cardinality((pg_temp.review_of(current_setting('t.a')::uuid, 'F-6')).candidate_supplier_ids), 1, 'D: the group supplier is offered as a candidate');

-- ── E: another workspace never merges ──────────────────────────────────
select is(pg_temp.ingest('00000000-0000-4000-8000-000025670004', current_setting('t.b')::uuid, 'F-1', 'ACME Sarl', 'FR12345678901'), '',
  'E: the same tax identifier arrives in workspace B');
select isnt(pg_temp.supplier_of(current_setting('t.b')::uuid, 'F-1'), pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'),
  'E: it is a different supplier');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.b')::uuid), 1, 'E: one supplier in B');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid), 2, 'E: A is unchanged (ACME and the group supplier)');

-- ── F: the backfill ────────────────────────────────────────────────────
insert into public.einvoice_inbox (workspace_id, syntax, document_hash, source_xml, invoice_number, issue_date, currency,
  supplier_name, supplier_vat_id, net_cents, tax_cents, gross_cents)
values (current_setting('t.a')::uuid, 'ubl', repeat('a', 64), '<Invoice>old</Invoice>', 'OLD-1', '2026-01-01', 'EUR',
  'Vecchia Srl', 'IT 12345678901', 100, 22, 122);
create temp table before_snapshot as
  select invoice_number, supplier_name, supplier_vat_id, document_hash, source_xml from public.einvoice_inbox
   where workspace_id = current_setting('t.a')::uuid;
select is(public.supplier_backfill(current_setting('t.a')::uuid), 1, 'F: the backfill processes only the document no one had looked at');
select isnt(pg_temp.supplier_of(current_setting('t.a')::uuid, 'OLD-1'), null::uuid, 'F: the older document is now linked');
select is((select supplier_number from public.suppliers where tax_identifier = 'IT12345678901'), '3', 'F: with the next free number');
select is(public.supplier_backfill(null), 0, 'F: a second run does nothing (idempotent)');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid), 3, 'F: no supplier was added twice');
select is((select count(*)::int from before_snapshot b join public.einvoice_inbox i
            on i.workspace_id = current_setting('t.a')::uuid and i.invoice_number = b.invoice_number
           where i.supplier_name = b.supplier_name and i.supplier_vat_id = b.supplier_vat_id
             and i.document_hash = b.document_hash and i.source_xml = b.source_xml), 7,
  'F: the raw name, identifier, hash and bytes of every document are unchanged');

-- ── G: a person resolves ───────────────────────────────────────────────
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001',
  format('select public.resolve_supplier_review(%L, null)', (pg_temp.review_of(current_setting('t.a')::uuid, 'F-3')).id)), '',
  'G: the owner resolves a candidate by making a new supplier');
select is((select name from public.suppliers where id = pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-3')), 'Bob Plumbing',
  'G: the new supplier is made from the document''s own name');
select ok(pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-4') is null, 'G: the other same-name document is still unlinked');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001',
  format('select public.resolve_supplier_review(%L, %L)', (pg_temp.review_of(current_setting('t.a')::uuid, 'F-4')).id, pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-3'))), '',
  'G: and links the second one to it by choice');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001',
  format('select public.resolve_supplier_review(%L, null)', (pg_temp.review_of(current_setting('t.a')::uuid, 'F-4')).id)),
  'this candidate was already resolved', 'G: a candidate is resolved once');

-- ── H: who may read and write ──────────────────────────────────────────
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670002',
  format('select public.save_supplier(%L, null, ''Intruder'', '''', ''vat'', '''', '''', '''', '''', '''', '''')', current_setting('t.a'))),
  'not allowed to manage suppliers', 'H: a plain member cannot save a supplier');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670003',
  format('select public.save_supplier(%L, null, ''Intruder'', '''', ''vat'', '''', '''', '''', '''', '''', '''')', current_setting('t.a'))),
  'not allowed to manage suppliers', 'H: an admin without manageBilling cannot either');
select ok(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'insert into public.suppliers (workspace_id, supplier_number, name) values (%L, ''99'', ''Direct'')', current_setting('t.a'))) <> '',
  'H: no client, not even the owner, inserts a supplier row directly');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid and name in ('Intruder', 'Direct')), 0,
  'H: readback: neither write left a row');
select pg_temp.act_as('00000000-0000-4000-8000-000025670002');
select is((select count(*)::int from public.suppliers), 0, 'H: a plain member sees no supplier');
select pg_temp.act_as('00000000-0000-4000-8000-000025670003');
select is((select count(*)::int from public.suppliers), 4, 'H: an admin (viewFinances) reads the workspace''s suppliers, and only its own');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"supplyExpenses": false}' where id = current_setting('t.a')::uuid;
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001',
  format('select public.save_supplier(%L, null, ''Off'', '''', ''vat'', '''', '''', '''', '''', '''', '''')', current_setting('t.a'))),
  'supplier management is switched off in this space', 'H: with the flag off even the owner is refused');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid and name = 'Off'), 0, 'H: readback: nothing was saved');
update public.workspaces set feature_flags = feature_flags || '{"supplyExpenses": true}' where id = current_setting('t.a')::uuid;

-- ── I: bank details ────────────────────────────────────────────────────
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'select public.set_supplier_bank(%L, ''ACME Sarl'', ''FR76 3000 6000 0112 3456 7890 189'', ''AGRIFRPP'')', pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'))), '',
  'I: the owner records bank details');
select is((select concat_ws('/', revision, validation, iban) from public.supplier_bank_revisions where supplier_id = pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1') and revision = 1),
  '1/valid/FR7630006000011234567890189', 'I: revision 1 is valid');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'select public.set_supplier_bank(%L, ''ACME Sarl'', ''FR7630006000011234567890189'', ''AGRIFRPP'')', pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'))), '',
  'I: the same details again');
select is((select bank_revision from public.suppliers where id = pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1')), 1, 'I: an unchanged value adds no revision');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'select public.set_supplier_bank(%L, ''ACME Sarl'', ''FR7630006000011234567890188'', ''AGRIFRPP'')', pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'))), '',
  'I: a changed IBAN with a wrong check digit is recorded');
select is((select concat_ws('/', revision, validation, validation_detail) from public.supplier_bank_revisions where supplier_id = pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1') and revision = 2),
  '2/invalid/iban_checksum', 'I: revision 2 is invalid, and says why');
select is((select count(*)::int from public.supplier_bank_revisions r join public.members m on m.id = r.changed_by
            where m.user_id = '00000000-0000-4000-8000-000025670001' and r.supplier_id = pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1')), 2,
  'I: both revisions name the owner''s member as the author');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670003', format(
  'select public.set_supplier_bank(%L, ''x'', ''FR7630006000011234567890189'', '''')', pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'))),
  'not allowed to manage suppliers', 'I: an admin without manageBilling cannot change bank details');
select pg_temp.act_as('00000000-0000-4000-8000-000025670003');
select is((select count(*)::int from public.supplier_bank_revisions), 0, 'I: and cannot read them either (not in a picker)');
reset role;
select ok(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'update public.supplier_bank_revisions set iban = ''XX'' where supplier_id = %L', pg_temp.supplier_of(current_setting('t.a')::uuid, 'F-1'))) <> '',
  'I: not even the owner can rewrite a revision');
select is((select count(*)::int from public.supplier_bank_revisions where iban = 'XX'), 0, 'I: readback: history is unchanged');

-- ── J: numbers and duplicates ──────────────────────────────────────────
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'select public.save_supplier(%L, null, ''Numbered'', '''', ''vat'', '''', '''', '''', '''', '''', ''K-100'')', current_setting('t.a'))), '',
  'J: the owner sets a supplier number');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'select public.save_supplier(%L, null, ''Numbered again'', '''', ''vat'', '''', '''', '''', '''', '''', ''K-100'')', current_setting('t.a'))),
  'this supplier number is already used', 'J: a number is unique per workspace');
select is(pg_temp.as_err('00000000-0000-4000-8000-000025670001', format(
  'select public.save_supplier(%L, null, ''Twin ACME'', ''FR 12 345 678 901'', ''vat'', '''', '''', '''', '''', '''', '''')', current_setting('t.a'))),
  'another supplier already has this tax identifier', 'J: so is a verified tax identifier');
select is((select count(*)::int from public.suppliers where workspace_id = current_setting('t.a')::uuid and name in ('Numbered again', 'Twin ACME')), 0,
  'J: readback: neither duplicate was stored');

select * from finish();
rollback;
