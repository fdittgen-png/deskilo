-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2370 — the accounting interface. A billing manager connects an issuer
-- to Pennylane with a token that lands in Vault and in no answer, no table
-- and no grant a client holds; a reader sees the connection's state and
-- never the token; a plain member, an exporter and another space's owner
-- are refused what is not theirs; a space with the flag off is refused
-- (0A000). A mapping key of the wrong shape and a party of another space
-- are refused; once a mapping exists the remote company cannot change.
-- A delivery's identity and idempotency key are stored before any send; a
-- send with no answer stays a conflict when prepared again and is resolved
-- by one acknowledgement; a re-run of an acknowledged delivery is a no-op,
-- another digest is refused and another remote id is a conflict. A file of
-- the generic journal delivered twice yields one row per document, the same
-- digests and no remote id; a changed document is a new generation and the
-- earlier one keeps its file. A revoked and reconnected company finds its
-- documents again; a delegated token, a plain member and a stranger are
-- refused by calls under the authenticated role.
-- Revoking forgets the secret and keeps the mappings and deliveries. A
-- delivered connection takes a new token for its recorded company (#2370).
-- Positive cases beside every refusal.
begin;
select plan(60);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000023700c1';
  u_b uuid := '00000000-0000-4000-8000-0000023700c2';
  u_e uuid := '00000000-0000-4000-8000-0000023700c3';
  u_m uuid := '00000000-0000-4000-8000-0000023700c4';
  u_x uuid := '00000000-0000-4000-8000-0000023700c5';
  ws uuid; ws2 uuid; site uuid; site2 uuid; m_b uuid; m_e uuid; m_m uuid; m_x uuid; r_b uuid; r_e uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'acctconn-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_b, u_e, u_m, u_x]) u;
  -- The flag and every parent on (moneyTab > invoicing > accountingBook >
  -- accountingConnectors), custom roles for the two role holders.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Connected books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true, "customRoles": true}'::jsonb)
  returning id into ws;
  -- Another space whose books keep no connection: the flag off.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Paper books', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": false}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_b, false, false), (ws, u_e, false, false), (ws, u_m, false, false),
         (ws2, u_x, true, true);
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  select id into m_e from public.members where workspace_id = ws and user_id = u_e;
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  select id into m_x from public.members where workspace_id = ws2 and user_id = u_x;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'billing', array['manageBilling']) returning id into r_b;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'exporter', array['exportData', 'viewFinances']) returning id into r_e;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r_b, m_b), (ws, r_e, m_e);
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.sites (workspace_id, name) values (ws2, 'Elsewhere') returning id into site2;
  perform set_config('ac.ws', ws::text, false);
  perform set_config('ac.ws2', ws2::text, false);
  perform set_config('ac.site', site::text, false);
  perform set_config('ac.site2', site2::text, false);
  perform set_config('ac.member_m', m_m::text, false);
  perform set_config('ac.member_x', m_x::text, false);
  perform set_config('ac.owner', u_o::text, false);
  perform set_config('ac.billing', u_b::text, false);
  perform set_config('ac.exporter', u_e::text, false);
  perform set_config('ac.member', u_m::text, false);
  perform set_config('ac.stranger', u_x::text, false);
end
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('ac.' || p_who), 'role', 'authenticated')::text, true);
end
$act$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql's jsonb answer as p_who, or {"refused": sqlstate}.
create or replace function pg_temp.as_json(p_who text, p_sql text) returns jsonb
language plpgsql as $j$
declare v jsonb;
begin
  if p_who is not null then perform pg_temp.act_as(p_who); end if;
  execute p_sql into v;
  return v;
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql's jsonb answer as p_who with an assistant's delegated token.
create or replace function pg_temp.as_delegated(p_who text, p_sql text) returns jsonb
language plpgsql as $j$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('ac.' || p_who), 'role', 'authenticated',
                      'client_id', 'assistant')::text, true);
  execute p_sql into v;
  return v;
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql run as p_who under the authenticated role itself (grants, RLS):
-- its first value as text, or the SQLSTATE refused.
create or replace function pg_temp.as_role(p_who text, p_sql text) returns text
language plpgsql as $j$
declare v text;
begin
  perform pg_temp.act_as(p_who);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return sqlstate;
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.v(p_key text) returns text language sql as $v$
  select current_setting('ac.' || p_key)
$v$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- One connection delivery recorded by the service role (the edge function).
create or replace function pg_temp.deliver(p_doc text, p_sha text, p_status text,
                                           p_remote jsonb default '{}'::jsonb, p_error text default '')
returns jsonb language plpgsql as $d$
begin
  return public.record_accounting_delivery(current_setting('ac.conn')::uuid, 'invoice', p_doc::uuid,
    date '2026-03-02', 'F-2026-0007', date '2026-01-01', date '2026-12-31', repeat(p_sha, 64),
    p_status, p_remote, p_error);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$d$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The documents a generic journal file carried.
create or replace function pg_temp.docs(p_third text) returns jsonb language sql as $docs$
  select jsonb_build_array(
    jsonb_build_object('kind', 'invoice', 'id', '00000000-0000-4000-8000-00000237d001', 'number', 'F-1',
                       'date', '2026-02-01', 'sha256', repeat('a', 64)),
    jsonb_build_object('kind', 'receipt', 'id', '00000000-0000-4000-8000-00000237d001', 'number', 'F-1',
                       'date', '2026-02-20', 'sha256', repeat('b', 64)),
    jsonb_build_object('kind', 'credit_note', 'id', '00000000-0000-4000-8000-00000237d002', 'number', 'A-1',
                       'date', '2026-03-05', 'sha256', repeat(p_third, 64)))
$docs$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- ── no secret is ever within a client's reach ───────────────────────
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relrowsecurity
              and c.relname in ('accounting_connections', 'accounting_maps', 'accounting_deliveries')),
          3, 'the three tables have row level security');
select is((select count(*)::int from information_schema.role_table_grants
            where grantee in ('authenticated', 'anon') and table_schema = 'public'
              and table_name in ('accounting_connections', 'accounting_maps', 'accounting_deliveries')
              and privilege_type <> 'SELECT'),
          0, 'no client role may write the tables directly');
select is((select count(*)::int from information_schema.columns
            where table_schema = 'public'
              and table_name in ('accounting_connections', 'accounting_maps', 'accounting_deliveries')
              and (column_name ~ '(token|secret|password)' and column_name !~ '_expires_at$')),
          0, 'no column of the tables holds a token or a secret');
select is((select string_agg(f || ':' || has_function_privilege(r, 'public.' || f, 'execute')::text, ',' order by f, r)
             from unnest(array['accounting_credentials_resolved(uuid)', 'set_accounting_credentials(uuid,jsonb,jsonb)',
                               'record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int)']) f,
                  unnest(array['anon', 'authenticated']) r),
          'accounting_credentials_resolved(uuid):false,accounting_credentials_resolved(uuid):false,'
          'record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int):false,'
          'record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int):false,'
          'set_accounting_credentials(uuid,jsonb,jsonb):false,set_accounting_credentials(uuid,jsonb,jsonb):false',
          'the resolver and the service writers are no client''s to call');
select ok(has_function_privilege('service_role', 'public.accounting_credentials_resolved(uuid)', 'execute')
          and has_function_privilege('service_role', 'public.record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int)', 'execute'),
          'the service role resolves and records');
select ok(not has_table_privilege('authenticated', 'vault.decrypted_secrets', 'select'),
          'no client reads the decrypted secrets');

-- ── connections ────────────────────────────────────────────────────
select is(pg_temp.as_json('stranger', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', '')$q$,
            pg_temp.v('ws2'), pg_temp.v('site2'))) ->> 'refused',
          '0A000', 'a space with the flag off opens no connection');
select is(pg_temp.as_json('member', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', '')$q$,
            pg_temp.v('ws'), pg_temp.v('site'))) ->> 'refused',
          '42501', 'a plain member opens no connection');
select is(pg_temp.as_delegated('billing', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', '')$q$,
            pg_temp.v('ws'), pg_temp.v('site'))) ->> 'refused',
          '42501', 'an assistant''s delegated token connects nothing, whoever it acts for');
select is(pg_temp.as_json('billing', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', 'Pennylane')$q$,
            pg_temp.v('ws'), pg_temp.v('site2'))) ->> 'refused',
          'DKA03', 'an issuer of another space is refused');
select set_config('ac.conn', pg_temp.as_json('billing',
  format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', 'Pennylane')$q$,
         pg_temp.v('ws'), pg_temp.v('site'))) ->> 'id', false);
select is((select status from public.accounting_connections where id = pg_temp.v('conn')::uuid),
          'pending', 'a billing manager opens a pending connection');
select is(pg_temp.as_json('billing', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', '')$q$,
            pg_temp.v('ws'), pg_temp.v('site'))) ->> 'refused',
          'DKA01', 'one live connection per issuer and target');
select is(pg_temp.as_json('billing', format($q$select public.set_accounting_token_v1(%L, 'short', '')$q$, pg_temp.v('conn'))) ->> 'refused',
          'DKA03', 'a token too short is refused');
select is(pg_temp.as_json('billing', format($q$select public.set_accounting_token_v1(%L, 'tok-secret-2370-abcdef', '812345678')$q$,
            pg_temp.v('conn'))) - 'id' - 'connected_at' - 'issuer_site_id',
          jsonb_build_object('target_id', 'pennylane_api', 'auth_kind', 'token', 'remote_tenant_id', '812345678',
            'display_name', 'Pennylane', 'status', 'connected', 'status_detail', '', 'scopes', '[]'::jsonb,
            'token_expires_at', null, 'refresh_expires_at', null, 'revoked_at', null,
            'remote_revocation', null, 'remote_revocation_at', null,
            'secrets_set', '["access_token"]'::jsonb, 'delivered', false, 'maps', '[]'::jsonb),
          'the token connects, and the answer names the secret, never its value');
select is((select decrypted_secret from vault.decrypted_secrets
            where name = 'accounting:' || pg_temp.v('conn') || ':access_token'),
          'tok-secret-2370-abcdef', 'the token is in Vault');
select is(public.accounting_credentials_resolved(pg_temp.v('conn')::uuid) #>> '{secrets,access_token}',
          'tok-secret-2370-abcdef', 'the service role resolves it');
select ok((pg_temp.as_json('exporter', format('select public.accounting_connections_v1(%L)', pg_temp.v('ws'))))::text
            !~ 'tok-secret' and
          jsonb_array_length(pg_temp.as_json('exporter', format('select public.accounting_connections_v1(%L)', pg_temp.v('ws')))) = 1,
          'a reader sees the connection and not the token');
select is(pg_temp.as_json('stranger', format('select public.accounting_connections_v1(%L)', pg_temp.v('ws'))) ->> 'refused',
          '42501', 'another space''s owner reads nothing of this space');
select is(pg_temp.as_role('member', format('select public.accounting_credentials_resolved(%L)', pg_temp.v('conn'))),
          '42501', 'a member may not call the resolver');
select is(pg_temp.as_role('member', format('select public.accounting_connections_v1(%L)', pg_temp.v('ws'))),
          '42501', 'a plain member reads no connection');
select is(pg_temp.as_role('member', format($q$select public.accounting_transfers_v1(%L, '2026-01-01', '2026-12-31')$q$, pg_temp.v('ws'))),
          '42501', 'a plain member reads no transfer');
select is(pg_temp.as_role('member', format('select public.revoke_accounting_connection_v1(%L)', pg_temp.v('conn'))),
          '42501', 'a plain member revokes nothing');
select is(pg_temp.as_role('stranger', format('select public.revoke_accounting_connection_v1(%L)', pg_temp.v('conn'))),
          '42501', 'another space''s owner revokes nothing');
select is(pg_temp.as_role('stranger', 'select (select count(*) from public.accounting_connections)
            + (select count(*) from public.accounting_maps) + (select count(*) from public.accounting_deliveries)'),
          '0', 'another space''s owner sees no row of the three tables');

-- ── mappings ──────────────────────────────────────────────────────
select is(pg_temp.as_json('billing', format($q$select public.save_accounting_map_v1(%L, 'tax', 'VAT|FR|5.5', '', 'FR_55', '')$q$,
            pg_temp.v('conn'))) ->> 'refused',
          'DKA03', 'a tax key of the wrong shape is refused');
select is(pg_temp.as_json('billing', format($q$select public.save_accounting_map_v1(%L, 'tax', 'VAT|FR|taxed|20|2014', '', 'FR_200', '')$q$,
            pg_temp.v('conn'))) -> 'maps' -> 0 ->> 'remote_code',
          'FR_200', 'a tax component key maps to a remote code');
select is(pg_temp.as_json('billing', format($q$select public.save_accounting_map_v1(%L, 'party', %L, '', 'C-1', '')$q$,
            pg_temp.v('conn'), 'member:' || pg_temp.v('member_x'))) ->> 'refused',
          'DKA03', 'a member of another space is no party here');
select is(pg_temp.as_json('exporter', format($q$select public.save_accounting_map_v1(%L, 'account', 'revenue:standard', '', '706000', '')$q$,
            pg_temp.v('conn'))) ->> 'refused',
          '42501', 'an exporter maps nothing');
select is(pg_temp.as_json(null, format($q$select public.set_accounting_credentials(%L, '{}'::jsonb, '{"remote_tenant_id": "999"}'::jsonb)$q$,
            pg_temp.v('conn'))) ->> 'refused',
          '23514', 'a mapped connection keeps its remote company');

-- ── connection deliveries ─────────────────────────────────────────
select ok(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'generated') ->> 'idempotency_key' ~ '^[0-9a-f]{64}$',
          'the idempotency key is stored before any send');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'sent') ->> 'status', 'sent', 'the send is recorded');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'conflict', '{}'::jsonb, 'no answer after send: timeout') ->> 'status',
          'conflict', 'a send with no answer is a conflict');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'generated') - 'id' - 'idempotency_key' - 'recorded_at'
            - 'sent_at' - 'acknowledged_at' - 'issuer_site_id' - 'connection_id' - 'document_id' - 'recorded_by_member_id'
            - 'book_export_id' - 'period_from' - 'period_to' - 'event_date' - 'payload_sha256' - 'target_id' - 'document_kind'
            - 'document_number' - 'remote_number' - 'remote_version' - 'remote_state' - 'generation',
          '{"status": "conflict", "outcome": "existing", "remote_id": "", "attempts": 1, "error": "no answer after send: timeout"}'::jsonb,
          'preparing it again leaves the conflict for a readback');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'acknowledged', '{"id": "R-1", "number": "F-2026-0007", "state": "posted"}') ->> 'status',
          'acknowledged', 'the readback acknowledges the one remote document');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'generated') ->> 'outcome',
          'unchanged', 'a re-run of the acknowledged delivery is a no-op');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'd', 'generated') ->> 'refused',
          '23514', 'another content for an acknowledged document needs a correction');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e001', 'c', 'acknowledged', '{"id": "R-2"}') ->> 'outcome',
          'conflict', 'another remote id for the same delivery is a conflict');
select is((select string_agg(status || ':' || remote_id || ':' || attempts, ',') from public.accounting_deliveries
            where connection_id = pg_temp.v('conn')::uuid),
          'conflict:R-1:1', 'one row for the document, the first remote id kept');

select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e002', 'a', 'acknowledged', '{"id": "R-7", "number": "F-2026-0008"}') ->> 'status',
          'acknowledged', 'a second invoice is received');
select is(pg_temp.as_json('billing', format($q$select public.set_accounting_token_v1(%L, 'tok-other-company-2370', '')$q$,
            pg_temp.v('conn'))) ->> 'refused',
          'DKA02', 'a connection that delivered keeps its token without the company it recorded');
-- #2370 — a routine rotation: a new token for the recorded company keeps
-- the connection, its maps and its deliveries; another company is refused.
select is(pg_temp.as_json('billing', format($q$select public.set_accounting_token_v1(%L, 'tok-other-company-2370', '999999999')$q$,
            pg_temp.v('conn'))) ->> 'refused',
          'DKA02', 'a token for another company is a new connection');
select is((pg_temp.as_json('billing', format($q$select public.set_accounting_token_v1(%L, 'tok-rotated-2370-abcdef', '812345678')$q$,
            pg_temp.v('conn'))) ->> 'id')
          || ':' || (select count(*) from public.accounting_maps where connection_id = pg_temp.v('conn')::uuid)
          || ':' || (select count(*) from public.accounting_deliveries where connection_id = pg_temp.v('conn')::uuid),
          pg_temp.v('conn') || ':1:2', 'a new token for the recorded company keeps the connection, its map and its deliveries');

-- ── the generic journal file, delivered twice ─────────────────────
select set_config('ac.export1', pg_temp.as_json('exporter', format(
  $q$select public.record_book_export_v1(%L, 'generic_journal_csv', '2026-01-01', '2026-12-31', %L, 100, 7, 3)$q$,
  pg_temp.v('ws'), repeat('e', 64))) ->> 'id', false);
select isnt(nullif(pg_temp.v('export1'), ''), null, 'with the connectors on the export log records the file');
select is(pg_temp.as_json('exporter', format($q$select public.record_file_deliveries_v1(%L, 'generic_journal_csv', %L, %L, %L::jsonb)$q$,
            pg_temp.v('ws'), pg_temp.v('site'), pg_temp.v('export1'), pg_temp.docs('c'))),
          '{"created": 3, "unchanged": 0, "changed": 0}'::jsonb, 'each document of the file is one delivery');
select set_config('ac.export2', pg_temp.as_json('exporter', format(
  $q$select public.record_book_export_v1(%L, 'generic_journal_csv', '2026-01-01', '2026-12-31', %L, 100, 7, 3)$q$,
  pg_temp.v('ws'), repeat('e', 64))) ->> 'id', false);
select is(pg_temp.as_json('exporter', format($q$select public.record_file_deliveries_v1(%L, 'generic_journal_csv', %L, %L, %L::jsonb)$q$,
            pg_temp.v('ws'), pg_temp.v('site'), pg_temp.v('export2'), pg_temp.docs('c'))),
          '{"created": 0, "unchanged": 3, "changed": 0}'::jsonb, 'delivering the same books again changes nothing');
select is((select string_agg(document_kind || ':' || left(payload_sha256, 1) || ':' || remote_id || ':' || (book_export_id = pg_temp.v('export1')::uuid)::text,
                             ',' order by document_kind)
             from public.accounting_deliveries where target_id = 'generic_journal_csv' and workspace_id = pg_temp.v('ws')::uuid),
          'credit_note:c::true,invoice:a::true,receipt:b::true',
          'one row per document, the same digests, no remote id');
select is(pg_temp.as_json('exporter', format($q$select public.record_file_deliveries_v1(%L, 'generic_journal_csv', %L, %L, %L::jsonb)$q$,
            pg_temp.v('ws'), pg_temp.v('site'), pg_temp.v('export2'), pg_temp.docs('f'))),
          '{"created": 0, "unchanged": 2, "changed": 1}'::jsonb, 'a changed document is delivered again');
select is((select string_agg(generation || ':' || left(payload_sha256, 1) || ':' || (book_export_id = pg_temp.v('export1')::uuid)::text, ','
                             order by generation)
             from public.accounting_deliveries where document_kind = 'credit_note' and workspace_id = pg_temp.v('ws')::uuid),
          '1:c:true,2:f:false', 'a changed document gets a new generation, the old one keeps its file');
select is(pg_temp.as_json('exporter', format($q$select public.record_file_deliveries_v1(%L, 'fec', %L, %L, %L::jsonb)$q$,
            pg_temp.v('ws'), pg_temp.v('site'), pg_temp.v('export2'), pg_temp.docs('c'))) ->> 'refused',
          'DKA03', 'a file is delivered for the target it was written for');
select is(pg_temp.as_json('member', format($q$select public.record_file_deliveries_v1(%L, 'generic_journal_csv', %L, %L, %L::jsonb)$q$,
            pg_temp.v('ws'), pg_temp.v('site'), pg_temp.v('export2'), pg_temp.docs('c'))) ->> 'refused',
          '42501', 'a plain member logs no delivery');
select is((select jsonb_build_array(jsonb_array_length(t -> 'files'),
                                    (select array_agg(jsonb_array_length(f -> 'deliveries') order by jsonb_array_length(f -> 'deliveries'))
                                       from jsonb_array_elements(t -> 'files') f),
                                    jsonb_array_length(t -> 'deliveries'))
             from (select pg_temp.as_json('exporter', format($q$select public.accounting_transfers_v1(%L, '2026-01-01', '2026-12-31')$q$,
                                          pg_temp.v('ws'))) as t) x),
          '[2, [1, 3], 2]'::jsonb, 'the transfers list the two files with their documents and the connection deliveries');

-- ── revoking, the flag off, the registries ────────────────────────
select is(pg_temp.as_json('billing', format('select public.revoke_accounting_connection_v1(%L)', pg_temp.v('conn'))) ->> 'status',
          'revoked', 'a billing manager revokes');
select is((select count(*) from vault.secrets where name like 'accounting:' || pg_temp.v('conn') || ':%')::text
          || (select count(*) from public.accounting_maps where connection_id = pg_temp.v('conn')::uuid)::text
          || (select count(*) from public.accounting_deliveries where connection_id = pg_temp.v('conn')::uuid)::text,
          '012', 'revoking forgets the token and keeps the mapping and the deliveries');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e003', 'a', 'generated') ->> 'refused',
          '23514', 'a revoked connection delivers nothing new');
select set_config('ac.conn_old', pg_temp.v('conn'), false);
select set_config('ac.conn', pg_temp.as_json('billing',
  format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', 'Pennylane')$q$,
         pg_temp.v('ws'), pg_temp.v('site'))) ->> 'id', false);
select is(pg_temp.as_json('billing', format($q$select public.set_accounting_token_v1(%L, 'tok-secret-2370-again', '812345678')$q$,
            pg_temp.v('conn'))) ->> 'status',
          'connected', 'after a revocation the issuer connects again, to the same company');
select is(pg_temp.deliver('00000000-0000-4000-8000-00000237e002', 'a', 'generated') ->> 'outcome',
          'unchanged', 'after revoke and reconnect, the acknowledged invoice is not created again');
select is((select string_agg((connection_id = pg_temp.v('conn')::uuid)::text || ':' || remote_id, ',')
             from public.accounting_deliveries where document_id = '00000000-0000-4000-8000-00000237e002'),
          'true:R-7', 'its one row follows the reconnected connection with its remote id');
select is(pg_temp.as_json('stranger', format(
            $q$select public.record_book_export_v1(%L, 'fec', '2026-01-01', '2026-12-31', %L, 1, 1, 1)$q$,
            pg_temp.v('ws2'), repeat('e', 64))) ->> 'logged',
          'false', 'with neither periods nor connectors on, nothing is logged');
select is(public.feature_registry() -> 'accountingConnectors',
          '{"parent": "accountingBook", "default": false, "core": false}'::jsonb,
          'the server knows the flag, under the books');
select ok(exists (select 1 from jsonb_array_elements(public.template_field_registry()) r
                   where r ->> 'id' = 'workspace.feature_flags.accountingConnectors'),
          'the template field registry knows the flag');

select * from finish();
rollback;
