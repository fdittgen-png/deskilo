-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3336 / 0692 -- the operational state of a capability, per workspace. Absent
-- a row the state is derived from the feature (on = active, off = servicing).
-- The manager (the connector authority) moves active <-> servicing; only the
-- owner, with a reason, retires or reopens; retiring is refused while a
-- delivery is unresolved; anything else is refused. servicing and retired
-- refuse new work with the unchanged 0A000 and still allow reading, revoking
-- and the outcome of admitted work; the feature choice stays authoritative; a
-- plain member, another space's owner and an assistant's token move nothing.
begin;
select plan(33);

create or replace function pg_temp.v(p text) returns text language sql as $$
  select current_setting('cs.' || p)
$$;
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
  return case when sqlerrm like '%unresolved%' then sqlstate || ':unresolved' else sqlstate end;
end;
$$;
create or replace function pg_temp.set_state(p_who text, p_to text, p_reason text default 'because', p_key text default 'accountingConnectors')
returns text language sql as $$
  select pg_temp.as_actor(p_who, format($q$select (r ->> 'state') || ':' || (r ->> 'changed') from (select public.set_capability_state_v1(%L, %L, %L, %L) as r) x$q$,
    pg_temp.v('ws'), p_key, p_to, p_reason))
$$;
create or replace function pg_temp.rec(p_doc text, p_status text, p_remote jsonb default '{}', p_conn text default null) returns text language plpgsql as $d$
declare v jsonb;
begin
  v := public.record_accounting_delivery(coalesce(p_conn, pg_temp.v('c1'))::uuid, 'invoice', p_doc::uuid, date '2026-03-02', 'F-2026-0007',
         date '2026-01-01', date '2026-12-31', repeat('a', 64), p_status, p_remote, '');
  return v ->> 'outcome';
exception when others then
  return sqlstate;
end
$d$;
create or replace function pg_temp.state_now(p_who text) returns text language sql as $$
  select pg_temp.as_actor(p_who, format($q$select (public.capability_states_v1(%L) -> 0 ->> 'state') || ':' || (public.capability_states_v1(%L) -> 0 ->> 'derived')$q$,
    pg_temp.v('ws'), pg_temp.v('ws')))
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

do $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000033600d1';
  u_a uuid := '00000000-0000-4000-8000-0000033600d2';
  u_p uuid := '00000000-0000-4000-8000-0000033600d3';
  u_x uuid := '00000000-0000-4000-8000-0000033600d4';
  ws uuid; ws2 uuid; site uuid; c1 uuid; r_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'capstate-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Capability books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true, "customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Another space', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, false), (ws, u_p, false, false), (ws2, u_x, true, true);
  -- the manager: not the owner, holds the connector right through a role
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'billing', array['manageBilling']) returning id into r_b;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  select ws, r_b, id from public.members where workspace_id = ws and user_id = u_a;
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, site, 'pennylane_api', 'token', '812345678', 'Pennylane', 'connected', now())
  returning id into c1;
  perform set_config('cs.o', u_o::text, false);
  perform set_config('cs.a', u_a::text, false);
  perform set_config('cs.p', u_p::text, false);
  perform set_config('cs.x', u_x::text, false);
  perform set_config('cs.ws', ws::text, false);
  perform set_config('cs.ws2', ws2::text, false);
  perform set_config('cs.site', site::text, false);
  perform set_config('cs.c1', c1::text, false);
end
$seed$;

-- Terminal work that must not block retirement: a failed delivery on the live
-- connection, and a stale prepared one and a failed one on a revoked connection.
do $old$
declare
  ws uuid := current_setting('cs.ws')::uuid; s2 uuid; co uuid;
begin
  insert into public.sites (workspace_id, name) values (ws, 'Annex') returning id into s2;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, status, connected_at)
  values (ws, s2, 'pennylane_api', 'token', '999', 'Old', 'connected', now()) returning id into co;
  perform set_config('cs.co', co::text, false);
end
$old$;
select pg_temp.rec('00000000-0000-4000-8000-00000336e005', 'generated');
select pg_temp.rec('00000000-0000-4000-8000-00000336e005', 'failed');
select pg_temp.rec('00000000-0000-4000-8000-00000336e006', 'generated', '{}', pg_temp.v('co'));
select pg_temp.rec('00000000-0000-4000-8000-00000336e007', 'generated', '{}', pg_temp.v('co'));
select pg_temp.rec('00000000-0000-4000-8000-00000336e007', 'failed', '{}', pg_temp.v('co'));
update public.accounting_connections set status = 'revoked', revoked_at = now() where id = pg_temp.v('co')::uuid;

-- 1. no row: derived from the feature
select is(pg_temp.state_now('o'), 'active:true', 'no row: the state is derived (feature on = active)');
select is(pg_temp.state_now('p'), '42501', 'a plain member does not read the state');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336e001', 'generated'), 'created', 'active admits a new delivery');

-- 2. who may move it, and what is a state
select is(pg_temp.set_state('p', 'servicing'), '42501', 'a plain member moves nothing');
select is(pg_temp.set_state('x', 'servicing'), '42501', 'another space''s owner moves nothing');
select is(pg_temp.as_actor('o', format($q$select public.set_capability_state_v1(%L, 'accountingConnectors', 'servicing', '')::text$q$, pg_temp.v('ws')), true),
  '42501', 'an assistant''s delegated token moves nothing');
select is(pg_temp.set_state('o', 'servicing', 'x', 'noSuchCapability'), '22023', 'an unknown capability is refused');
select is(pg_temp.set_state('o', 'paused'), '22023', 'an unknown state is refused');

-- 3. the manager (a role holder, not the owner) moves active <-> servicing
select is(pg_temp.set_state('a', 'servicing', ''), 'servicing:true', 'a manager moves active to servicing');
select is(pg_temp.state_now('o'), 'servicing:false', 'the state is now stored, not derived');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336e002', 'generated'), '0A000', 'servicing refuses a new delivery with the unchanged 0A000');
select is(pg_temp.as_actor('o', format($q$select public.open_accounting_connection_v1(%L, %L, 'pennylane_api', 'token', '')::text$q$,
          pg_temp.v('ws'), pg_temp.v('site'))), '0A000', 'servicing refuses opening a connection');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336e001', 'sent'), 'updated', 'servicing records the outcome of an admitted delivery');
select is(pg_temp.set_state('a', 'servicing', ''), 'servicing:false', 'repeating the state changes nothing');
select is((select count(*)::int from public.capability_states where workspace_id = pg_temp.v('ws')::uuid), 1, 'one row per capability');
select is(pg_temp.set_state('a', 'active', ''), 'active:true', 'a manager reopens servicing to active');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336e002', 'generated'), 'created', 'active admits again');

-- 4. retiring: servicing first, the owner, a reason, no unresolved delivery
select is(pg_temp.set_state('o', 'retired', 'closing'), '22023', 'active goes to retired only through servicing');
select is(pg_temp.set_state('a', 'servicing', ''), 'servicing:true', 'back to servicing');
select is(pg_temp.set_state('a', 'retired', 'closing'), '42501', 'a manager who is not the owner does not retire');
select is(pg_temp.set_state('o', 'retired', ''), '22023', 'retiring needs a reason');
select is(pg_temp.set_state('o', 'retired', 'closing'), '22023:unresolved', 'retiring is refused while a delivery is unresolved');
select is((select count(*)::int from public.accounting_deliveries
            where workspace_id = pg_temp.v('ws')::uuid and status = 'failed'), 2,
  'a failed delivery on a live connection and one on a revoked connection exist');
select is((select count(*)::int from public.accounting_deliveries d
             join public.accounting_connections k on k.id = d.connection_id
            where d.workspace_id = pg_temp.v('ws')::uuid and d.status = 'generated' and k.revoked_at is not null), 1,
  'and a stale prepared delivery on a revoked connection');

-- 5. resolve them, retire, and see what retired allows
select pg_temp.rec('00000000-0000-4000-8000-00000336e001', 'acknowledged', '{"id": "R-1"}');
select pg_temp.rec('00000000-0000-4000-8000-00000336e002', 'acknowledged', '{"id": "R-2"}');
select is(pg_temp.set_state('o', 'retired', 'closing'), 'retired:true',
  'the owner retires once nothing can still complete: failed work and work on a revoked connection do not block it');
select is(pg_temp.rec('00000000-0000-4000-8000-00000336e003', 'generated'), '0A000', 'retired refuses new work');
select is(pg_temp.as_actor('o', format($q$select jsonb_array_length(public.accounting_connections_v1(%L))::text$q$, pg_temp.v('ws'))), '2',
  'retired: the history is still read');
select is(pg_temp.set_state('o', 'active', 'again'), '22023', 'retired goes back through servicing, not to active');
select is(pg_temp.set_state('a', 'servicing', 'reopen'), '42501', 'a manager who is not the owner does not reopen');
select is(pg_temp.set_state('o', 'servicing', 'reopening'), 'servicing:true', 'the owner reopens a retired capability for servicing');

-- 6. the feature choice stays authoritative
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": false}'::jsonb
 where id = pg_temp.v('ws')::uuid;
select is(pg_temp.set_state('a', 'active', ''), '0A000', 'servicing does not go back to active while the feature is off');
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": true}'::jsonb
 where id = pg_temp.v('ws')::uuid;
select pg_temp.set_state('a', 'active', '');
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": false}'::jsonb
 where id = pg_temp.v('ws')::uuid;
select is(pg_temp.rec('00000000-0000-4000-8000-00000336e004', 'generated'), '0A000',
  'an active row admits nothing while the feature is off');
update public.workspaces set feature_flags = feature_flags || '{"accountingConnectors": true}'::jsonb
 where id = pg_temp.v('ws')::uuid;

-- 7. another space is its own
select is(pg_temp.as_actor('x', format($q$select (public.capability_states_v1(%L) -> 0 ->> 'state') || ':' || (public.capability_states_v1(%L) -> 0 ->> 'derived')$q$,
    pg_temp.v('ws2'), pg_temp.v('ws2'))), 'active:true', 'another space keeps its own, untouched state');

select * from finish();
rollback;
