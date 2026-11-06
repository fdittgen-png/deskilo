-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3336 / 0693 -- the provenance envelope. Every new durable result carries one
-- row written with it, by the server, once: an invoice (after the legal
-- snapshot and the frozen QRR), a book export (with the client's declared
-- renderer kept apart), a file delivery (referring to its export), an
-- accounting delivery (pinned at its first preparation). A result with no
-- envelope reads legacy_unknown. Stamping never changes which results can
-- exist: with no tax reference in force the rule revision is 'unknown'. The
-- envelope is insert-only; a forged field is not promoted; another space reads
-- nothing; the registry covers every kind the table accepts.
begin;
select plan(31);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('pv.' || p)
$$;
create or replace function pg_temp.as_actor(p_who text, p_sql text) returns text
language plpgsql as $$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.v(p_who), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return coalesce(v, 'ok');
exception when others then
  reset role;
  return sqlstate;
end;
$$;
create or replace function pg_temp.invoice(p_number text, p_total int, p_period text) returns uuid language plpgsql as $$
declare v uuid;
begin
  -- the invoice hooks read the issuing member's settings
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.v('o'), 'role', 'authenticated')::text, true);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, kind)
  values (pg_temp.v('ws')::uuid, pg_temp.v('m')::uuid, pg_temp.v('m')::uuid, p_number, p_period, p_period, '[]', p_total,
          'EUR', 'M', 'W', 'O', repeat('s', 64), 'full')
  returning id into v;
  return v;
end;
$$;
create or replace function pg_temp.env(p_kind text, p_id uuid) returns public.provenance_envelopes language sql as $$
  select * from public.provenance_envelopes where result_kind = p_kind and result_id = p_id
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033600e1';
  u_p uuid := '00000000-0000-4000-8000-0000033600e2';
  u_x uuid := '00000000-0000-4000-8000-0000033600e3';
  ws uuid; ws2 uuid; m uuid; site uuid; c1 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'prov-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Provenance books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingPeriods": true, "accountingConnectors": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_p, false, false), (ws2, u_x, true, true);
  select id into m from public.members where workspace_id = ws and user_id = u_o;
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, site, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now())
  returning id into c1;
  perform set_config('pv.o', u_o::text, false);
  perform set_config('pv.p', u_p::text, false);
  perform set_config('pv.x', u_x::text, false);
  perform set_config('pv.ws', ws::text, false);
  perform set_config('pv.ws2', ws2::text, false);
  perform set_config('pv.m', m::text, false);
  perform set_config('pv.site', site::text, false);
  perform set_config('pv.c1', c1::text, false);
end
$seed$;

-- 1-4. an invoice: the envelope is written with it, after the snapshot and the QRR
select set_config('pv.inv1', pg_temp.invoice('PV-1', 5000, '2026-05')::text, false);
select ok(exists (select 1 from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('inv1')::uuid),
  'a new invoice carries an envelope');
select is((select module_id || '/' || module_version || '/' || input_schema from pg_temp.env('invoice', pg_temp.v('inv1')::uuid)),
  'invoice.issue/1/invoice-legal-snapshot/1', 'it names the server''s module, version and input schema');
select is((select issuer ->> 'issuer_member_id' from pg_temp.env('invoice', pg_temp.v('inv1')::uuid)), pg_temp.v('m'),
  'the issuer is the server-derived member');
select is((select artifacts ->> 'legal_snapshot_sha256' from pg_temp.env('invoice', pg_temp.v('inv1')::uuid)),
  (select encode(sha256(convert_to(legal_snapshot::text, 'utf8')), 'hex') from public.invoices where id = pg_temp.v('inv1')::uuid),
  'the snapshot digest is of the FINAL snapshot, after the QRR was frozen into it');
select ok((select (artifacts ->> 'qrr_frozen')::boolean from pg_temp.env('invoice', pg_temp.v('inv1')::uuid)),
  'a positive invoice records that its QRR was frozen first');
select set_config('pv.cn', pg_temp.invoice('PV-CN', 0, '2026-06')::text, false);
select ok(not (select (artifacts ->> 'qrr_frozen')::boolean from pg_temp.env('invoice', pg_temp.v('cn')::uuid)),
  'a credit or zero document has an envelope and no QRR');
select is((select rule_revision ->> 'status' from pg_temp.env('invoice', pg_temp.v('inv1')::uuid)), 'known',
  'the tax reference in force is recorded as a count and a digest');

-- 8. issuance never depends on the stamp: no tax reference in force
create temp table tax_saved as select * from public.tax_reference;
delete from public.tax_reference;
select set_config('pv.inv2', pg_temp.invoice('PV-2', 4000, '2026-07')::text, false);
select is((select rule_revision ->> 'status' from pg_temp.env('invoice', pg_temp.v('inv2')::uuid)), 'unknown',
  'with no tax reference the invoice is still issued and the rule revision reads unknown');
insert into public.tax_reference select * from tax_saved;

-- 9-11. insert-only, never forged, never twice
select throws_ok($$ update public.provenance_envelopes set module_version = '9' where result_id = pg_temp.v('inv1')::uuid $$,
  '23514', 'provenance is written once and never changed', 'an envelope is never updated');
select throws_ok($$ delete from public.provenance_envelopes where result_id = pg_temp.v('inv1')::uuid $$,
  '23514', 'provenance is written once and never changed', 'nor deleted');
select public.record_provenance(pg_temp.v('ws')::uuid, 'invoice', pg_temp.v('inv1')::uuid, '{"issuer_member_id": "forged"}', '{}', '{}');
select is((select issuer ->> 'issuer_member_id' from pg_temp.env('invoice', pg_temp.v('inv1')::uuid)), pg_temp.v('m'),
  'a second write is a no-op: the first envelope is the truth');
select throws_ok($$ select public.record_provenance(pg_temp.v('ws')::uuid, 'no_such_kind', gen_random_uuid(), '{}', '{}', '{}') $$,
  '22023', 'unknown provenance kind no_such_kind', 'an unknown kind is a programming error');
select ok(not exists (
    select 1 from (select (regexp_matches(pg_get_constraintdef(oid), '''([a-z_]+)''', 'g'))[1] k
                     from pg_constraint where conname = 'provenance_envelopes_result_kind_check') x
     where not (public.provenance_modules() ? k)),
  'every result kind the table accepts has a registry entry');

-- 14-17. the reader
select is(pg_temp.as_actor('o', format($q$select (public.provenance_envelope_v1(%L, 'invoice', %L) ->> 'status')$q$, pg_temp.v('ws'), pg_temp.v('inv1'))),
  'recorded', 'the accounting reader reads an envelope');
select is(pg_temp.as_actor('o', format($q$select (public.provenance_envelope_v1(%L, 'invoice', gen_random_uuid()) ->> 'status')$q$, pg_temp.v('ws'))),
  'legacy_unknown', 'a result with no envelope reads legacy_unknown');
select is(pg_temp.as_actor('p', format($q$select (public.provenance_envelope_v1(%L, 'invoice', %L) ->> 'status')$q$, pg_temp.v('ws'), pg_temp.v('inv1'))),
  '42501', 'a plain member reads nothing');
select is(pg_temp.as_actor('x', format($q$select (public.provenance_envelope_v1(%L, 'invoice', %L) ->> 'status')$q$, pg_temp.v('ws2'), pg_temp.v('inv1'))),
  'legacy_unknown', 'another space''s reader sees nothing of this space''s results');

-- 18. an invoice issued before the hook reads legacy_unknown
alter table public.invoices disable trigger invoice_provenance_stamp;
select set_config('pv.old', pg_temp.invoice('PV-OLD', 3000, '2026-08')::text, false);
alter table public.invoices enable trigger invoice_provenance_stamp;
select is(pg_temp.as_actor('o', format($q$select (public.provenance_envelope_v1(%L, 'invoice', %L) ->> 'status')$q$, pg_temp.v('ws'), pg_temp.v('old'))),
  'legacy_unknown', 'an invoice from before the hook reads legacy_unknown; nothing is backfilled');

-- 19-23. a book export: the old call, and the call with a declared renderer
select is(pg_temp.as_actor('o', format($q$select public.record_book_export_v1(%L, 'pennylane_api', date '2026-01-01', date '2026-03-31', %L, 100, 3, 2) ->> 'logged'$q$,
  pg_temp.v('ws'), repeat('a', 64))), 'true', 'the old eight-argument call still works and is logged');
select is(pg_temp.as_actor('o', format($q$select public.record_book_export_v1(%L, 'pennylane_api', date '2026-04-01', date '2026-04-30', %L, 200, 4, 2, %L::jsonb) ->> 'logged'$q$,
  pg_temp.v('ws'), repeat('b', 64), '{"renderer": "ui/1", "exported_by_member_id": "forged"}')), 'true', 'a new export is logged');
select is((select declared ->> 'renderer' from public.provenance_envelopes
            where result_kind = 'book_export' and artifacts ->> 'sha256' = repeat('b', 64)), 'ui/1',
  'the client''s renderer is kept as declared');
select is((select issuer ->> 'exported_by_member_id' from public.provenance_envelopes
            where result_kind = 'book_export' and artifacts ->> 'sha256' = repeat('b', 64)), pg_temp.v('m'),
  'and a forged field in it never becomes the server-established one');
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'book_export'), 2,
  'each logged export has exactly one envelope');

-- 24-27. file deliveries refer to their export; an unchanged digest writes nothing
select set_config('pv.exp', (select result_id::text from public.provenance_envelopes
                              where result_kind = 'book_export' and artifacts ->> 'sha256' = repeat('b', 64)), false);
select set_config('pv.doc', gen_random_uuid()::text, false);
create or replace function pg_temp.files(p_sha text) returns text language plpgsql as $$
begin
  return pg_temp.as_actor('o', format($q$select public.record_file_deliveries_v1(%L, 'pennylane_api', %L, %L, %L::jsonb)::text$q$,
    pg_temp.v('ws'), pg_temp.v('site'), pg_temp.v('exp'),
    json_build_array(json_build_object('kind', 'invoice', 'id', pg_temp.v('doc'), 'date', '2026-04-10', 'number', 'F-1', 'sha256', p_sha))::text));
end;
$$;
select is(pg_temp.files(repeat('c', 64)) like '%"created": 1%', true, 'a file delivery is created');
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'file_delivery'), 1, 'it has its envelope');
select is((select issuer ->> 'book_export_id' from public.provenance_envelopes where result_kind = 'file_delivery'), pg_temp.v('exp'),
  'which refers to the export it was written from');
select pg_temp.files(repeat('c', 64));
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'file_delivery'), 1,
  'the same digest again is a no-op: no second envelope');
select pg_temp.files(repeat('d', 64));
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'file_delivery'), 2,
  'a changed file is a new generation with its own envelope');

-- 28-30. an accounting delivery pins its context at the first preparation
create or replace function pg_temp.rec(p_status text, p_sha text) returns text language plpgsql as $d$
declare v jsonb;
begin
  v := public.record_accounting_delivery(pg_temp.v('c1')::uuid, 'invoice', '00000000-0000-4000-8000-00000336f001'::uuid, date '2026-03-02', 'F-2026-0007',
         date '2026-01-01', date '2026-12-31', repeat(p_sha, 64), p_status, '{}', '');
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;
select is(pg_temp.rec('generated', 'a'), 'created', 'a delivery is prepared');
select pg_temp.rec('sent', 'a');
select pg_temp.rec('generated', 'a');
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'accounting_delivery'), 1,
  'its envelope is written once, at the first preparation, and kept through the outcomes and a replay');
select is((select artifacts ->> 'payload_sha256' from public.provenance_envelopes where result_kind = 'accounting_delivery'),
  repeat('a', 64), 'it holds the digest that was prepared');

select * from finish();
rollback;
