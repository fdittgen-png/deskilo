-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3336 -- the evidence rows of the capability lifecycle that need no schema of
-- their own, exercised through the real entrypoints:
--   L10  a receipted invoice command replayed after the capability was
--        deactivated returns the original invoice, with its one envelope, and
--        issuing is not gated by the state;
--   L1   a populated baseline: an invoice from before the envelope reads
--        legacy_unknown; a v1 invoice, then a v2 registry and a deactivation,
--        leave every signed field, the legal snapshot, the signature and the
--        retained artifact bytes exactly as they were;
--   L4   two spaces using the same provider with the same local ids: deactivating
--        one refuses its new work and leaves the other usable, and nothing leaks
--        between their envelopes;
--   L5   a forged module, version or rule selector sent as "declared" never
--        selects anything: the server's registry and its own tax reference win;
--   L9   a closed period and a retention hold keep refusing, and reopening keeps
--        its own authority, whatever state the capability is in.
begin;
select plan(24);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('le.' || p)
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
create or replace function pg_temp.signed(p_id uuid) returns text language sql as $$
  select md5(row(number, signature, signature_algo, total_cents, currency, lines::text, legal_snapshot::text,
                 member_name, workspace_name, issuer_name, period, kind)::text)
    from public.invoices where id = p_id
$$;
create or replace function pg_temp.receipted(p_req text, p_period text) returns text language plpgsql as $$
begin
  return pg_temp.as_actor('uo', format($q$select public.create_invoice_receipted_v1(%L, %L, %L, %L)::text$q$,
    pg_temp.v('ws'), pg_temp.v('mm'), p_period, p_req));
end;
$$;
create or replace function pg_temp.rec(p_ws text, p_conn text, p_doc text, p_status text) returns text language plpgsql as $d$
declare v jsonb;
begin
  v := public.record_accounting_delivery(pg_temp.v(p_conn)::uuid, 'invoice', p_doc::uuid, date '2026-03-02', 'F-1',
         date '2026-01-01', date '2026-12-31', repeat('a', 64), p_status, '{}', '');
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  uo uuid := '00000000-0000-4000-8000-0000033600f1';
  um uuid := '00000000-0000-4000-8000-0000033600f2';
  ub uuid := '00000000-0000-4000-8000-0000033600f3';
  ws uuid; wb uuid; mo uuid; mm uuid; mb uuid; sa uuid; sb uuid; ca uuid; cb uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'life-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[uo, um, ub]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, street, city, postal_code, vat_regime, vat_id, feature_flags)
  values ('Lifecycle A', 'FR', 'EUR', 'Europe/Paris', uo, '1 rue du Pilote', 'Pézenas', '34120', 'vat_registered', 'FR12345678901',
          '{"moneyTab": true, "invoicing": true, "numberSequences": true, "accountingBook": true, "accountingPeriods": true, "accountingConnectors": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Lifecycle B', 'DE', 'EUR', 'Europe/Berlin', ub,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into wb;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values (ws, uo, true, true, '2026-01-01') returning id into mo;
  insert into public.members (workspace_id, user_id, subscription_pct, joined_at, customer_capacity) values (ws, um, 1, '2026-01-01', 'consumer') returning id into mm;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values (wb, ub, true, true, '2026-01-01') returning id into mb;
  insert into public.vat_rates (workspace_id, label, percent, is_default) values (ws, 'Standard', 20, true);
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents) values (ws, 0, 100, 3500, 1000);
  update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR', street = '2 rue du Test', city = 'Pézenas', postal_code = '34120' where id = um;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
  values (ws, mm, 'charge', 'adjustment', 1000, 'Supply', '2026-09', 20), (ws, mm, 'charge', 'adjustment', 700, 'Supply', '2026-10', 20),
         (ws, mm, 'charge', 'adjustment', 500, 'Supply', '2026-11', 20);
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into sa;
  insert into public.sites (workspace_id, name) values (wb, 'Studio') returning id into sb;  -- the same local name
  insert into public.accounting_connections (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, sa, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now()) returning id into ca;
  insert into public.accounting_connections (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (wb, sb, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now()) returning id into cb;
  perform set_config('le.uo', uo::text, false); perform set_config('le.um', um::text, false); perform set_config('le.ub', ub::text, false);
  perform set_config('le.ws', ws::text, false); perform set_config('le.wb', wb::text, false);
  perform set_config('le.mo', mo::text, false); perform set_config('le.mm', mm::text, false); perform set_config('le.mb', mb::text, false);
  perform set_config('le.ca', ca::text, false); perform set_config('le.cb', cb::text, false);
end
$seed$;

-- ── L10: a receipted command, replayed after the capability was deactivated ──
select set_config('le.i1', pg_temp.receipted('00000000-0000-4000-8000-0000033671a1', '2026-09'), false);
select ok(pg_temp.v('i1') ~ '^[0-9a-f-]{36}$', 'a receipted command issues an invoice');
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('i1')::uuid), 1,
  'with its one envelope');
insert into public.capability_states (workspace_id, capability_key, state, reason, changed_by_member_id)
values (pg_temp.v('ws')::uuid, 'accountingConnectors', 'servicing', '', pg_temp.v('mo')::uuid);
select is(pg_temp.receipted('00000000-0000-4000-8000-0000033671a1', '2026-09'), pg_temp.v('i1'),
  'replayed after deactivation, the same command returns the original invoice');
select is((select count(*)::int from public.invoices where workspace_id = pg_temp.v('ws')::uuid), 1, 'no second invoice');
select is((select count(*)::int from public.provenance_envelopes where result_kind = 'invoice'
            and workspace_id = pg_temp.v('ws')::uuid), 1, 'and no second envelope');
select set_config('le.i2', pg_temp.receipted('00000000-0000-4000-8000-0000033671a2', '2026-10'), false);
select ok((select count(*) = 1 from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('i2')::uuid),
  'issuing is not gated by the accounting state: a new invoice still gets its envelope');
delete from public.capability_states where workspace_id = pg_temp.v('ws')::uuid;

-- ── L1: the populated baseline, v1, then v2 and a deactivation ───────────
alter table public.invoices disable trigger invoice_provenance_stamp;
-- a row as the baseline held it: no hook ran
select set_config('le.old', pg_temp.receipted('00000000-0000-4000-8000-0000033671a3', '2026-11'), false);
alter table public.invoices enable trigger invoice_provenance_stamp;
select is(pg_temp.as_actor('uo', format($q$select (public.provenance_envelope_v1(%L, 'invoice', %L) ->> 'status')$q$, pg_temp.v('ws'), pg_temp.v('old'))),
  'legacy_unknown', 'an invoice from before the envelope reads legacy_unknown');
select set_config('le.sig_old', pg_temp.signed(pg_temp.v('old')::uuid), false);
select set_config('le.sig_v1', pg_temp.signed(pg_temp.v('i1')::uuid), false);
-- a transmission prepared under v1 keeps its retained bytes
select set_config('le.t1', public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, pg_temp.v('i1')::uuid, 'generic', 'government', 'prod',
  pg_temp.v('uo')::uuid, 'T', 'facturX', 'h1', 'f.pdf', 'application/pdf', '', '', '\xdeadbeef'::bytea) ->> 'id', false);
select set_config('le.bytes_v1', (select md5(bytes) from public.invoice_transmission_artifacts where transmission_id = pg_temp.v('t1')::uuid), false);
-- v2 of the invoice module is deployed and the capability is deactivated
create or replace function public.provenance_modules() returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_build_object(
    'invoice',             jsonb_build_object('module_id', 'invoice.issue',         'module_version', '2', 'input_schema', 'invoice-legal-snapshot/2'),
    'book_export',         jsonb_build_object('module_id', 'book.export',           'module_version', '1', 'input_schema', 'book-export/1'),
    'file_delivery',       jsonb_build_object('module_id', 'book.file-delivery',    'module_version', '1', 'input_schema', 'file-delivery/1'),
    'accounting_delivery', jsonb_build_object('module_id', 'accounting.delivery',   'module_version', '1', 'input_schema', 'accounting-delivery/1'),
    'transmission',        jsonb_build_object('module_id', 'einvoice.transmission', 'module_version', '1', 'input_schema', 'einvoice-transmission/1'))
$fn$;
insert into public.capability_states (workspace_id, capability_key, state, reason, changed_by_member_id)
values (pg_temp.v('ws')::uuid, 'accountingConnectors', 'servicing', '', pg_temp.v('mo')::uuid);
select set_config('le.i3', pg_temp.receipted('00000000-0000-4000-8000-0000033671a4', '2026-12'), false);
select is((select module_version from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('i3')::uuid), '2',
  'an invoice issued after v2 is deployed carries v2');
select is((select module_version from public.provenance_envelopes where result_kind = 'invoice' and result_id = pg_temp.v('i1')::uuid), '1',
  'the v1 invoice keeps v1: a later deployment and a deactivation rewrite nothing');
select is(pg_temp.signed(pg_temp.v('i1')::uuid), pg_temp.v('sig_v1'), 'its signed fields, snapshot and signature are unchanged');
select is(pg_temp.signed(pg_temp.v('old')::uuid), pg_temp.v('sig_old'), 'so are the legacy invoice''s');
select is(pg_temp.as_actor('uo', format($q$select (public.provenance_envelope_v1(%L, 'invoice', %L) ->> 'status')$q$, pg_temp.v('ws'), pg_temp.v('old'))),
  'legacy_unknown', 'and it still reads legacy_unknown: nothing was backfilled');
select is((select md5(bytes) from public.invoice_transmission_artifacts where transmission_id = pg_temp.v('t1')::uuid), pg_temp.v('bytes_v1'),
  'the retained artifact bytes are unchanged');
delete from public.capability_states where workspace_id = pg_temp.v('ws')::uuid;

-- ── L4: two spaces, one provider, the same local ids ─────────────────────
select is(pg_temp.rec('ws', 'ca', '00000000-0000-4000-8000-00000336f101', 'generated'), 'created', 'space A admits a delivery');
select is(pg_temp.rec('wb', 'cb', '00000000-0000-4000-8000-00000336f101', 'generated'), 'created',
  'space B admits the same document id through the same provider: separate rows');
select is((select count(distinct workspace_id)::int from public.accounting_deliveries where document_id = '00000000-0000-4000-8000-00000336f101'), 2,
  'two deliveries, one per space');
insert into public.capability_states (workspace_id, capability_key, state, reason, changed_by_member_id)
values (pg_temp.v('ws')::uuid, 'accountingConnectors', 'servicing', '', pg_temp.v('mo')::uuid);
select is(pg_temp.rec('ws', 'ca', '00000000-0000-4000-8000-00000336f102', 'generated'), '0A000', 'A is deactivated: its new work refuses');
select is(pg_temp.rec('wb', 'cb', '00000000-0000-4000-8000-00000336f102', 'generated'), 'created', 'B, on the shared provider, is untouched');
select is(pg_temp.as_actor('ub', format($q$select (public.provenance_envelope_v1(%L, 'accounting_delivery', %L) ->> 'status')$q$, pg_temp.v('wb'),
  (select id::text from public.accounting_deliveries where workspace_id = pg_temp.v('ws')::uuid limit 1))),
  'legacy_unknown', 'and B''s reader sees nothing of A''s envelopes');
delete from public.capability_states where workspace_id = pg_temp.v('ws')::uuid;

-- ── L5: a forged selector sent as "declared" selects nothing ─────────────
select pg_temp.as_actor('uo', format($q$select public.record_book_export_v1(%L, 'pennylane_api', date '2026-01-01', date '2026-03-31', %L, 10, 1, 1,
  %L::jsonb)::text$q$, pg_temp.v('ws'), repeat('f', 64),
  '{"module_id": "evil", "module_version": "0", "input_schema": "x", "rule_revision": {"status": "known"}, "renderer": "ui/1"}'));
select is((select module_id || '/' || module_version || '/' || (rule_revision ->> 'status') from public.provenance_envelopes
            where result_kind = 'book_export' and artifacts ->> 'sha256' = repeat('f', 64)), 'book.export/1/unknown',
  'a forged module, version or rule is ignored: the server''s registry and tax reference decide');
select is((select declared from public.provenance_envelopes where result_kind = 'book_export' and artifacts ->> 'sha256' = repeat('f', 64)),
  '{"renderer": "ui/1"}'::jsonb, 'only the allowed declaration survives, as declared');

-- ── L9: a closed period and a retention hold, whatever the state ─────────
insert into public.book_periods (workspace_id, period_from, period_to, reason, closed_by_member_id)
values (pg_temp.v('ws')::uuid, '2026-02-01', '2026-02-28', 'owner', pg_temp.v('mo')::uuid);
insert into public.capability_states (workspace_id, capability_key, state, reason, changed_by_member_id)
values (pg_temp.v('ws')::uuid, 'accountingConnectors', 'retired', 'closing', pg_temp.v('mo')::uuid);
select is(pg_temp.as_actor('um', format($q$select (public.reopen_book_period_v1(%L, (select id from public.book_periods where workspace_id = %L), 'please'))::text$q$,
  pg_temp.v('ws'), pg_temp.v('ws'))), 'P0001', 'retired: reopening a closed period keeps its own authority');
select ok(public.book_period_closed(pg_temp.v('ws')::uuid, date '2026-02-10'), 'and the period stays closed');
select pg_temp.as_actor('uo', format($q$select (public.place_retention_hold(%L, null, null, 'audit'))::text$q$, pg_temp.v('ws')));
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, created_at)
values (pg_temp.v('ws')::uuid, pg_temp.v('mm')::uuid, 'charge', 'subscription', 1000, 'old', '2019-06', '2019-06-01 12:00+02');
select is(pg_temp.as_actor('uo', format($q$select public.reset_workspace(%L)::text$q$, pg_temp.v('ws'))), 'DKE01',
  'retired: the destructive reset still refuses what a retention hold keeps');

select * from finish();
rollback;
