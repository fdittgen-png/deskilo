-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2370 / 0636: record_accounting_delivery answers `in_flight` to a prepare of a
-- `generated` or `sent` delivery last touched within the window the caller names (the
-- delivery function's wall-clock budget), so a second run that is truly concurrent
-- stops instead of reading back nothing and creating. A row older than the window, a
-- window of 0, a call without a window, a conflict, a failure and an acknowledged
-- digest behave as before. A reconnected connection taking over a young sent row of
-- the same company stops too. The eleven-argument signature is gone; only the service
-- role may call the new one.
begin;
select plan(25);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000023600c1';
  ws uuid; site uuid; c1 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_o, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'acctflight-' || u_o || '@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('In flight books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u_o, true, true);
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, site, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now())
  returning id into c1;
  perform set_config('ac.ws', ws::text, false);
  perform set_config('ac.site', site::text, false);
  perform set_config('ac.c1', c1::text, false);
end
$seed$;

-- The same company, reconnected: the first connection is revoked, a new one
-- takes its place.
create or replace function pg_temp.reconnect() returns text language plpgsql as $r$
declare c2 uuid;
begin
  update public.accounting_connections set status = 'revoked', revoked_at = now()
   where id = current_setting('ac.c1')::uuid;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (current_setting('ac.ws')::uuid, current_setting('ac.site')::uuid, 'pennylane_api', 'token',
          '812345678', 'Pennylane', 'connected', now())
  returning id into c2;
  perform set_config('ac.c2', c2::text, false);
  return 'reconnected';
end
$r$;

-- A delivery's last activity, p_seconds ago.
create or replace function pg_temp.age(p_doc text, p_seconds int) returns text language plpgsql as $a$
begin
  -- The system-columns trigger keeps created_datetime immutable; the fixture
  -- ages the row as the passing of time would.
  set local session_replication_role = replica;
  update public.accounting_deliveries
     set created_datetime = now() - make_interval(secs => p_seconds),
         sent_at = case when sent_at is null then null else now() - make_interval(secs => p_seconds) end
   where document_id = p_doc::uuid;
  set local session_replication_role = origin;
  return 'aged';
end
$a$;

-- One prepare or record of a document; a null window is the call without it.
-- The outcome, or the SQLSTATE it was refused with.
create or replace function pg_temp.rec(p_conn uuid, p_doc text, p_status text, p_window int,
                                       p_remote jsonb, p_sha text) returns text language plpgsql as $d$
declare v jsonb;
begin
  if p_window is null then
    v := public.record_accounting_delivery(p_conn, 'invoice', p_doc::uuid, date '2026-03-02', 'F-2026-0007',
           date '2026-01-01', date '2026-12-31', repeat(p_sha, 64), p_status, p_remote, '');
  else
    v := public.record_accounting_delivery(p_conn, 'invoice', p_doc::uuid, date '2026-03-02', 'F-2026-0007',
           date '2026-01-01', date '2026-12-31', repeat(p_sha, 64), p_status, p_remote, '', p_window);
  end if;
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;

select pg_temp.seed();

select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', 400, '{}', 'a'), 'created', 'the first prepare creates the row');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', 400, '{}', 'a'), 'in_flight', 'a prepare within the window of a generated row stops');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', 0, '{}', 'a'), 'existing', 'a window of 0 never stops it');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', null, '{}', 'a'), 'existing', 'a caller without a window (the old call) never stops it');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'sent', 400, '{}', 'a'), 'updated', 'the send is recorded');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', 400, '{}', 'a'), 'in_flight', 'a prepare within the window of a sent row stops');
select is(pg_temp.age('00000000-0000-4000-8000-00000236d001', 500) || ':' || pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', 400, '{}', 'a'), 'aged:existing', 'a row older than the window is read back');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d001', 'generated', 600, '{}', 'a'), 'in_flight', 'the same row with a longer window is in flight again');
select is((select status || ':' || attempts from public.accounting_deliveries where document_id = '00000000-0000-4000-8000-00000236d001'), 'sent:1', 'an in-flight answer changes nothing in the row');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d002', 'generated', 400, '{}', 'a'), 'created', 'a second document is created');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d002', 'conflict', 400, '{}', 'a'), 'updated', 'a conflict is recorded');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d002', 'generated', 400, '{}', 'a'), 'existing', 'a conflict is left for a readback, never in flight');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d003', 'generated', 400, '{}', 'a'), 'created', 'a third document is created');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d003', 'failed', 400, '{}', 'a'), 'updated', 'a failure is recorded');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d003', 'generated', 400, '{}', 'a'), 'existing', 'a failed delivery is prepared again, never in flight');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d004', 'generated', 400, '{}', 'a'), 'created', 'a fourth document is created');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d004', 'acknowledged', 400, '{"id": "R-1"}', 'a'), 'updated', 'it is acknowledged');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d004', 'generated', 400, '{}', 'a'), 'unchanged', 'an acknowledged digest asked again ends as unchanged, not in flight');
select is(pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d005', 'generated', 400, '{}', 'a') || ':' || pg_temp.rec(current_setting('ac.c1')::uuid, '00000000-0000-4000-8000-00000236d005', 'sent', 400, '{}', 'a'), 'created:updated', 'a fifth document is created and sent');
select is(pg_temp.reconnect(), 'reconnected', 'the connection is revoked and reconnected to the same company');
select is(pg_temp.rec(current_setting('ac.c2')::uuid, '00000000-0000-4000-8000-00000236d005', 'generated', 400, '{}', 'a'), 'in_flight', 'the reconnected one taking over a young sent row stops');
select is((select (connection_id = current_setting('ac.c2')::uuid)::text from public.accounting_deliveries where document_id = '00000000-0000-4000-8000-00000236d005'), 'true', 'the row is taken over by the reconnected connection all the same');
select is(pg_temp.rec(current_setting('ac.c2')::uuid, '00000000-0000-4000-8000-00000236d005', 'generated', 0, '{}', 'a'), 'existing', 'the same prepare without a window reads it back');
select is(coalesce(to_regprocedure('public.record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text)')::text, 'gone'), 'gone', 'the old signature is gone');
select is(has_function_privilege('anon', 'public.record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int)', 'execute')::text || ',' || has_function_privilege('authenticated', 'public.record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int)', 'execute')::text || ',' || has_function_privilege('service_role', 'public.record_accounting_delivery(uuid,text,uuid,date,text,date,date,text,text,jsonb,text,int)', 'execute')::text, 'false,false,true', 'anon, authenticated and service_role');

select * from finish();
rollback;
