-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2370 (0644) -- two server checks of the accounting connections.
-- open_accounting_connection_v1 refuses a target the app does not define, a
-- file target and a way a target is not connected by (22023), and opens a
-- known target by a way it takes. The revoke RPC is unchanged: called
-- without any outcome it revokes as before and records none. What the target
-- answered is written by the service role alone (record_accounting_revocation):
-- authenticated and anon may not call it nor write the columns; it refuses a
-- live connection and an unknown outcome (22023); a recorded outcome is
-- answered to the readers, and a live row cannot carry one (23514).
begin;
select plan(18);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000023706a1';
  u_b uuid := '00000000-0000-4000-8000-0000023706a2';
  ws uuid; site uuid; m_b uuid; r_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'acctcheck-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_b]) u;
  -- The flag and every parent on (moneyTab > invoicing > accountingBook >
  -- accountingConnectors), custom roles for the billing manager.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Checked books', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "accountingBook": true, "accountingConnectors": true, "customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_b, false, false);
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'billing', array['manageBilling']) returning id into r_b;
  insert into public.workspace_role_members (workspace_id, role_id, member_id) values (ws, r_b, m_b);
  insert into public.sites (workspace_id, name) values (ws, 'Studio') returning id into site;
  perform set_config('ck.ws', ws::text, false);
  perform set_config('ck.site', site::text, false);
  perform set_config('ck.billing', u_b::text, false);
end
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.v(p_key text) returns text language sql as $v$
  select current_setting('ck.' || p_key)
$v$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql's jsonb answer as the billing manager, or {"refused": sqlstate}.
create or replace function pg_temp.as_billing(p_sql text) returns jsonb
language plpgsql as $j$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.v('billing'), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return v;
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql run under p_role itself (grants, RLS): its first value as text,
-- or the SQLSTATE refused.
create or replace function pg_temp.as_role(p_role text, p_sql text) returns text
language plpgsql as $j$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', pg_temp.v('billing'), 'role', p_role)::text, true);
  execute format('set local role %I', p_role);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return sqlstate;
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The service writer's answer, or {"refused": sqlstate}.
create or replace function pg_temp.record(p_conn text, p_outcome text) returns jsonb
language plpgsql as $r$
begin
  return public.record_accounting_revocation(p_conn::uuid, p_outcome);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$r$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.open(p_target text, p_kind text) returns jsonb language sql as $o$
  select pg_temp.as_billing(format($q$select public.open_accounting_connection_v1(%L, %L, %L, %L, '')$q$,
                                   pg_temp.v('ws'), pg_temp.v('site'), p_target, p_kind))
$o$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- ── the targets a connection is opened for ─────────────────────────
select is(pg_temp.open('nosuch_api', 'token') ->> 'refused', '22023',
          'a target the app does not define is refused');
select is(pg_temp.open('fec', 'token') ->> 'refused', '22023',
          'a file target is no connection');
select is(pg_temp.open('xero_gb', 'token') ->> 'refused', '22023',
          'a way of connecting the target does not take is refused');
select is((select count(*)::int from public.accounting_connections
            where workspace_id = pg_temp.v('ws')::uuid), 0, 'a refused target stores nothing');
select set_config('ck.conn', pg_temp.open('pennylane_api', 'token') ->> 'id', false);
select is((select status from public.accounting_connections where id = pg_temp.v('conn')::uuid),
          'pending', 'a known target by a way it takes is opened');
select set_config('ck.live', pg_temp.open(' xero_gb ', 'oauth2') ->> 'id', false);
select is((select target_id from public.accounting_connections where id = pg_temp.v('live')::uuid),
          'xero_gb', 'the id is read trimmed, as it is stored');

-- ── the revoke RPC without an outcome behaves as before ───────────
select is(pg_temp.as_billing(format('select public.revoke_accounting_connection_v1(%L)', pg_temp.v('conn')))
            - 'id' - 'issuer_site_id' - 'revoked_at' - 'maps' - 'secrets_set' - 'delivered' - 'connected_at'
            - 'scopes' - 'token_expires_at' - 'refresh_expires_at' - 'display_name' - 'remote_tenant_id',
          jsonb_build_object('target_id', 'pennylane_api', 'auth_kind', 'token', 'status', 'revoked',
                             'status_detail', '', 'remote_revocation', null, 'remote_revocation_at', null),
          'revoking revokes, and records no outcome of its own');

-- ── only the service role writes the outcome ──────────────────────
select ok(not has_function_privilege('authenticated', 'public.record_accounting_revocation(uuid,text)', 'execute')
          and not has_function_privilege('anon', 'public.record_accounting_revocation(uuid,text)', 'execute')
          and not has_function_privilege('public', 'public.record_accounting_revocation(uuid,text)', 'execute'),
          'no client role may record an outcome');
select ok(has_function_privilege('service_role', 'public.record_accounting_revocation(uuid,text)', 'execute'),
          'the service role records it');
select is(pg_temp.as_role('authenticated',
            format($q$select public.record_accounting_revocation(%L, 'revoked')::text$q$, pg_temp.v('conn'))),
          '42501', 'the billing manager cannot call the writer');
select is(pg_temp.as_role('anon',
            format($q$select public.record_accounting_revocation(%L, 'revoked')::text$q$, pg_temp.v('conn'))),
          '42501', 'anyone signed out cannot call the writer');
select is(pg_temp.as_role('authenticated',
            format($q$update public.accounting_connections set remote_revocation = 'revoked', remote_revocation_at = now()
                      where id = %L returning 'written'$q$, pg_temp.v('conn'))),
          '42501', 'nor write the outcome on the row');
select is(pg_temp.record(pg_temp.v('live'), 'revoked') ->> 'refused', '22023',
          'a live connection takes no outcome: it is revoked here first');
select is(pg_temp.record(pg_temp.v('conn'), 'maybe') ->> 'refused', '22023',
          'an outcome is revoked, failed or not_supported');
select is(pg_temp.record(pg_temp.v('conn'), 'failed') ->> 'remote_revocation', 'failed',
          'the service role records what the target answered');
select ok((select remote_revocation_at is not null from public.accounting_connections where id = pg_temp.v('conn')::uuid),
          'and when');
select is((select x ->> 'remote_revocation'
             from jsonb_array_elements(pg_temp.as_billing(format('select public.accounting_connections_v1(%L)', pg_temp.v('ws')))) x
            where x ->> 'id' = pg_temp.v('conn')),
          'failed', 'the readers are answered the outcome');
select throws_ok(format($q$update public.accounting_connections set remote_revocation = 'failed', remote_revocation_at = now()
                          where id = %L$q$, pg_temp.v('live')),
                 '23514', null, 'a live row cannot carry an outcome');

select * from finish();
rollback;
