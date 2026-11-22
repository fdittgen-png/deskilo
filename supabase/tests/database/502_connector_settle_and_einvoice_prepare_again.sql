-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0863. (1) With the accounting connectors in servicing, the manageable door answers `settle` for the
-- member and the right and still refuses `work`; a delivery that exists records its outcome, a new one
-- is refused where it is written; a plain member, another business and an assistant are refused.
-- (2) The HMRC connection is revoked by the owner with mtdSubmission and vatDeclarations off; its door
-- still refuses work then; a plain member never revokes. (3) A prepared or failed e-invoice transmission
-- whose document or receiver changed is prepared again under its row, once, and sent once; a sent,
-- uncertain, accepted or rejected one keeps the conflict; the first attempt's envelope stays and the new
-- attempt has its own. Rolled back.
begin;
select plan(32);

create or replace function pg_temp.v(p text) returns text language sql as $$ select current_setting('cs.' || p) $$;
create or replace function pg_temp.as_actor(p_who text, p_sql text, p_delegated boolean default false) returns text
language plpgsql as $$
declare v text;
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', pg_temp.v(p_who), 'role', 'authenticated')::jsonb
      || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return coalesce(v, 'ok');
exception when others then
  reset role;
  return sqlstate;
end;
$$;
create or replace function pg_temp.rec(p_doc text, p_status text) returns text language plpgsql as $d$
declare v jsonb;
begin
  v := public.record_accounting_delivery(pg_temp.v('c1')::uuid, 'invoice', p_doc::uuid, date '2026-03-02', 'F-2026-0007',
         date '2026-01-01', date '2026-12-31', repeat('a', 64), p_status, '{}', '');
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000086300c1';
  u_p uuid := '00000000-0000-4000-8000-0000086300c2';
  u_x uuid := '00000000-0000-4000-8000-0000086300c3';
  ws uuid; ws2 uuid; wg uuid; site uuid; sg uuid; c1 uuid; ch uuid; mo uuid; inv uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cs-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Settle books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'FR', 'EUR', 'Europe/Paris', u_x, '{"moneyTab": true, "invoicing": true}'::jsonb) returning id into ws2;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('UK books', 'GB', 'GBP', 'Europe/London', u_o,
          '{"moneyTab": true, "invoicing": true, "vatManagement": true, "vatDeclarations": true, "mtdSubmission": true, "accountingBook": true, "accountingConnectors": true}'::jsonb) returning id into wg;
  update public.workspaces set vat_regime = 'vat_registered', vat_id = 'GB 123 456 789' where id = wg;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_p, false, false), (ws2, u_x, true, true), (wg, u_o, true, true), (wg, u_p, false, false);
  select id into mo from public.members where workspace_id = ws and user_id = u_o;
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.sites (workspace_id, name) values (wg, 'Studio UK') returning id into sg;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, site, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now()) returning id into c1;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (wg, sg, 'hmrc_mtd', 'oauth2', '', 'HMRC', 'connected', now()) returning id into ch;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature)
  values (ws, mo, mo, 'E-1', 'September', '[]'::jsonb, 5000, 'EUR', 'M', 'W', 'M', 'sig') returning id into inv;
  perform set_config('cs.o', u_o::text, false);
  perform set_config('cs.p', u_p::text, false);
  perform set_config('cs.x', u_x::text, false);
  perform set_config('cs.ws', ws::text, false);
  perform set_config('cs.wg', wg::text, false);
  perform set_config('cs.c1', c1::text, false);
  perform set_config('cs.ch', ch::text, false);
  perform set_config('cs.inv', inv::text, false);
end
$seed$;

-- ── a delivery admitted while the connectors are active ──
select is(pg_temp.rec('00000000-0000-4000-8000-00000863d001', 'generated'), 'created', 'with the feature on, a delivery is admitted');

-- ── servicing ──
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": false}'::jsonb where id = pg_temp.v('ws')::uuid;
select is(pg_temp.as_actor('o', format($q$select (public.accounting_connection_manageable_v1(%L, 'work'))::text is not null$q$, pg_temp.v('c1'))), '0A000',
  'servicing: the door still refuses work');
select is(pg_temp.as_actor('o', format($q$select (public.accounting_connection_manageable_v1(%L, 'settle') ->> 'workspace_id')$q$, pg_temp.v('c1'))), pg_temp.v('ws'),
  'servicing: it answers a delivery under way to be settled');
select is(pg_temp.as_actor('o', format($q$select (public.accounting_connection_manageable_v1(%L, 'revoke') ->> 'workspace_id')$q$, pg_temp.v('c1'))), pg_temp.v('ws'),
  'and the revocation as before');
select is(pg_temp.as_actor('p', format($q$select public.accounting_connection_manageable_v1(%L, 'settle')::text$q$, pg_temp.v('c1'))), '42501',
  'a plain member is refused');
select is(pg_temp.as_actor('x', format($q$select public.accounting_connection_manageable_v1(%L, 'settle')::text$q$, pg_temp.v('c1'))), '42501',
  'another business''s owner is refused');
select is(pg_temp.as_actor('o', format($q$select public.accounting_connection_manageable_v1(%L, 'settle')::text$q$, pg_temp.v('c1')), true), '42501',
  'an assistant''s delegated token is refused');
select is(pg_temp.rec('00000000-0000-4000-8000-00000863d001', 'sent'), 'updated', 'servicing: the outcome of the delivery under way is recorded');
select is(pg_temp.rec('00000000-0000-4000-8000-00000863d002', 'generated'), '0A000', 'servicing: a new delivery is still refused');

-- ── HMRC: the owner revokes with the features off ──
select is(pg_temp.as_actor('o', format($q$select (public.hmrc_connection_manageable_v1(%L) ->> 'workspace_id')$q$, pg_temp.v('ch'))), pg_temp.v('wg'),
  'MTD on: the door answers work as before');
update public.workspaces set feature_flags = feature_flags || '{"mtdSubmission": false, "vatDeclarations": false}'::jsonb where id = pg_temp.v('wg')::uuid;
select is(pg_temp.as_actor('o', format($q$select public.hmrc_connection_manageable_v1(%L)::text is not null$q$, pg_temp.v('ch'))), '55000',
  'MTD off: the door still refuses work');
select is(pg_temp.as_actor('o', format($q$select (public.hmrc_connection_manageable_v1(%L, 'revoke') ->> 'workspace_id')$q$, pg_temp.v('ch'))), pg_temp.v('wg'),
  'MTD off: it answers the revocation');
select is(pg_temp.as_actor('p', format($q$select public.hmrc_connection_manageable_v1(%L, 'revoke')::text$q$, pg_temp.v('ch'))), '42501',
  'a plain member does not revoke');
select is(pg_temp.as_actor('o', format($q$select (public.revoke_hmrc_connection_v1(%L) ->> 'status')$q$, pg_temp.v('ch'))), 'revoked',
  'MTD off: the owner revokes the connection');
select is((select status from public.accounting_connections where id = pg_temp.v('ch')::uuid), 'revoked', 'and it is revoked');

-- ── e-invoice: prepared again ──
create or replace function pg_temp.prep(p_dest text, p_hash text, p_scheme text) returns jsonb language sql as $$
  select public.prepare_einvoice_v1(pg_temp.v('ws')::uuid, pg_temp.v('inv')::uuid, 'generic', p_dest, 'prod', pg_temp.v('o')::uuid,
    'T', 'facturX', p_hash, 'f.pdf', 'application/pdf', p_scheme, '', '\x01'::bytea) $$;
create or replace function pg_temp.own() returns text language sql as $$ select pg_temp.v('o') $$;

-- failed → changed receiver → prepared again → sent once
select set_config('cs.t1', (pg_temp.prep('government', 'h1', '') ->> 'id'), false);
select public.claim_einvoice_dispatch_v1(pg_temp.v('t1')::uuid, pg_temp.v('o')::uuid, 150);
select public.record_einvoice_outcome_v1(pg_temp.v('t1')::uuid, 1, pg_temp.v('o')::uuid, 'failed', '', 'no address', '{}');
select is((select phase from public.invoice_transmissions where id = pg_temp.v('t1')::uuid), 'failed', 'a connector refusal before dispatch leaves the row failed');
select is((pg_temp.prep('government', 'h1', 'iso') ->> 'outcome') || '/' || (pg_temp.prep('government', 'h1', 'iso') ->> 'phase'), 'prepared/prepared',
  'failed, then a changed receiver: prepared again');
select is((select count(*)::int from public.invoice_transmissions where invoice_id = pg_temp.v('inv')::uuid and destination = 'government'), 1, 'under the same row');
select is((select receiver_scheme from public.invoice_transmission_artifacts where transmission_id = pg_temp.v('t1')::uuid), 'iso', 'the artifact holds the new receiver');
select is((select phase || '|' || detail from public.invoice_transmissions where id = pg_temp.v('t1')::uuid), 'prepared|In progress or unresolved - do not resend',
  'the row reads as prepared, its refusal cleared');
select is((public.claim_einvoice_dispatch_v1(pg_temp.v('t1')::uuid, pg_temp.v('o')::uuid, 150) ->> 'claimed'), 'true', 'it is claimed once');
select is((public.claim_einvoice_dispatch_v1(pg_temp.v('t1')::uuid, pg_temp.v('o')::uuid, 150) ->> 'claimed'), 'false', 'and never twice');
select is((select count(*)::int from public.provenance_envelopes where result_id = pg_temp.v('t1')::uuid
             or issuer ->> 'transmission_id' = pg_temp.v('t1')), 2, 'the first attempt''s envelope stays and the new attempt has its own');

-- prepared and abandoned → changed document → prepared again
select set_config('cs.t2', (pg_temp.prep('customer', 'h1', '') ->> 'id'), false);
select is((pg_temp.prep('customer', 'h2', '') ->> 'outcome'), 'prepared', 'prepared and abandoned, then a changed document: prepared again');
select is((select sha256 from public.invoice_transmission_artifacts where transmission_id = pg_temp.v('t2')::uuid), 'h2', 'the artifact holds the new document');

select is((public.claim_einvoice_dispatch_v1(pg_temp.v('t2')::uuid, pg_temp.v('o')::uuid, 150, 'h1') ->> 'detail'), 'binding_changed',
  'a claim of the document that was replaced is refused: nothing old is sent');
select is((public.claim_einvoice_dispatch_v1(pg_temp.v('t2')::uuid, pg_temp.v('o')::uuid, 150, 'h2') ->> 'claimed'), 'true',
  'the claim of the current document wins');

-- every other phase keeps the conflict
select is((pg_temp.prep('government', 'h3', 'iso') ->> 'outcome'), 'conflict', 'sent, then a changed document: conflict');
select public.record_einvoice_outcome_v1(pg_temp.v('t1')::uuid, 2, pg_temp.v('o')::uuid, 'uncertain', '', '', '{}');
select is((pg_temp.prep('government', 'h3', 'iso') ->> 'outcome'), 'conflict', 'uncertain: conflict');
update public.invoice_transmissions set phase = 'accepted' where id = pg_temp.v('t1')::uuid;
select is((pg_temp.prep('government', 'h3', 'iso') ->> 'outcome'), 'conflict', 'accepted: conflict');
update public.invoice_transmissions set phase = 'rejected' where id = pg_temp.v('t1')::uuid;
select is((pg_temp.prep('government', 'h3', 'iso') ->> 'outcome'), 'conflict', 'rejected: conflict');
select is((pg_temp.prep('government', 'h3', 'iso') ->> 'phase'), 'rejected', 'and it names the phase');

select * from finish();
rollback;
