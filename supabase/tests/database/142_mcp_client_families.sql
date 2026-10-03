-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2145 / 0356 (S2) — assistant clients are approved per family, by their
-- exact registered redirects, when a member of an mcpAccess workspace
-- arrives with them; the approval is audited with the family. Lookalike
-- hosts, longer paths, other schemes, mixed registrations and an
-- operator's block are never approved by a match. Loopback clients are
-- approved only while the operator's one audited switch is on, which
-- needs the operator and a second factor. Someone outside every mcpAccess
-- workspace approves nothing.
begin;
select plan(30);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  op uuid := '00000000-0000-4000-8000-000000214601';
  m1 uuid := '00000000-0000-4000-8000-000000214602';
  m2 uuid := '00000000-0000-4000-8000-000000214603';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         n || '-2146@deskilo.test', '', now(), now(), now()
    from (values (op, 'op'), (m1, 'm1'), (m2, 'm2')) v(u, n);
  insert into public.platform_admins (user_id, added_at) values (op, '2000-01-01');
  perform set_config('request.jwt.claims', json_build_object('sub', op, 'role', 'authenticated')::text, true);
  ws := public.create_workspace('Families 2146', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null);
  perform set_config('request.jwt.claims', '', true);
  update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
   where id = ws;
  insert into public.members (workspace_id, user_id, status) values (ws, m1, 'active');
  update public.mcp_installation_settings set allow_loopback_clients = false;
  insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types, token_endpoint_auth_method)
  select ('00000000-0000-4000-8000-0000002146' || k)::uuid, 'Assistant ' || k, 'dynamic', r,
         'authorization_code', 'none'
    from (values
      ('a1', 'https://claude.ai/api/mcp/auth_callback'),
      ('a2', 'https://claude.com/api/mcp/auth_callback'),
      ('a3', 'https://chatgpt.com/connector_platform_oauth_redirect'),
      ('a4', 'https://chatgpt.com/connector/oauth/cb_1234-abcd'),
      ('b1', 'https://claude.ai.evil.com/api/mcp/auth_callback'),
      ('b2', 'https://claude.ai/api/mcp/auth_callback/extra'),
      ('b3', 'https://claude.ai/api/mcp/auth_callback,https://evil.example/callback'),
      ('b4', 'http://claude.ai/api/mcp/auth_callback'),
      ('b5', 'https://chatgpt.com/connector/oauth/../../steal'),
      ('b6', 'HTTPS://CLAUDE.AI/api/mcp/auth_callback'),
      ('c1', 'http://127.0.0.1:33418/callback'),
      ('c2', 'http://localhost:53126/callback'),
      ('c3', 'http://127.0.0.1.evil.com/callback'),
      ('c4', 'https://localhost/callback'),
      ('c5', 'http://127.0.0.1:33418/callback,https://claude.ai/api/mcp/auth_callback'),
      ('d1', 'https://claude.ai/api/mcp/auth_callback'),
      ('d2', 'https://claude.ai/api/mcp/auth_callback')) v(k, r);
  insert into public.mcp_clients (client_id, name, status)
  values ('00000000-0000-4000-8000-0000002146d1', 'Blocked Claude', 'revoked');
  perform set_config('deskilo.op', op::text, false);
  perform set_config('deskilo.m1', m1::text, false);
  perform set_config('deskilo.m2', m2::text, false);
end;
$seed$;
select pg_temp.seed();

-- One arrival: a fresh pending authorization for that client, opened by
-- that person; answers the client's status.
create or replace function pg_temp.arrive(p_user text, p_client text) returns text language plpgsql as $$
declare
  v_id text := md5(p_user || p_client || clock_timestamp()::text);
begin
  insert into auth.oauth_authorizations (id, authorization_id, client_id, redirect_uri, scope,
                                         code_challenge, code_challenge_method)
  select gen_random_uuid(), v_id, c.id, split_part(c.redirect_uris, ',', 1), 'openid', repeat('a', 43), 's256'
    from auth.oauth_clients c where c.id = ('00000000-0000-4000-8000-0000002146' || p_client)::uuid;
  perform set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('deskilo.' || p_user), 'role', 'authenticated', 'aal', 'aal1')::text, true);
  return public.oauth_authorization_context(v_id)->>'client_status';
end;
$$;
create or replace function pg_temp.audited(p_client text) returns text language sql as $$
  select detail->>'family' from public.database_authority_audit
   where action = 'client_auto_approved'
     and detail->>'client_id' = '00000000-0000-4000-8000-0000002146' || p_client;
$$;
create or replace function pg_temp.as(p_user text, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('deskilo.' || p_user), 'role', 'authenticated', 'aal', p_aal)::text, false);
$$;

-- ── an outsider approves nothing ─────────────────────────────────────
select is(pg_temp.arrive('m2', 'd2'), 'waiting', 'someone outside every mcpAccess workspace approves nothing');

-- ── the hosted families, exactly ─────────────────────────────────────
select is(pg_temp.arrive('m1', 'a1'), 'approved', 'the claude.ai callback is approved on arrival');
select is(pg_temp.audited('a1'), 'claude', 'audited with its family');
select is((select status from public.mcp_clients where client_id = '00000000-0000-4000-8000-0000002146a1'),
  'active', 'as an ordinary approval row');
select is(pg_temp.arrive('m1', 'a2'), 'approved', 'the announced claude.com callback too');
select is(pg_temp.arrive('m1', 'a3'), 'approved', 'the ChatGPT stable callback');
select is(pg_temp.audited('a3'), 'chatgpt', 'audited as chatgpt');
select is(pg_temp.arrive('m1', 'a4'), 'approved', 'the ChatGPT per-connector callback');

-- ── lookalikes are other clients ─────────────────────────────────────
select is(pg_temp.arrive('m1', 'b1'), 'waiting', 'a lookalike host (claude.ai.evil.com) waits');
select is(pg_temp.arrive('m1', 'b2'), 'waiting', 'a longer path waits');
select is(pg_temp.arrive('m1', 'b3'), 'waiting', 'a family callback mixed with another redirect waits');
select is(pg_temp.arrive('m1', 'b4'), 'waiting', 'plain http to the family host waits');
select is(pg_temp.arrive('m1', 'b5'), 'waiting', 'a callback id that is a path waits');
select is(pg_temp.arrive('m1', 'b6'), 'waiting', 'another spelling is not the exact callback');
select is((select count(*)::int from public.database_authority_audit
            where action = 'client_auto_approved' and detail->>'client_id' like '%2146b_'), 0,
  'and none of them is audited as approved');
select is((select count(*)::int from public.database_authority_audit
            where action = 'client_waiting' and detail->>'client_id' like '%2146b_'), 6,
  'each waits on the operator, audited');

-- ── an operator's block wins ─────────────────────────────────────────
select is(pg_temp.arrive('m1', 'd1'), 'blocked', 'a blocked Claude client stays blocked');

-- ── loopback behind the operator's switch ────────────────────────────
select is(pg_temp.arrive('m1', 'c1'), 'waiting', 'a loopback client waits while the switch is off');
select pg_temp.as('m1', 'aal2');
select throws_like($$ select public.instance_set_mcp_loopback_clients(true) $$,
  '%only the instance operator%', 'a member cannot turn the switch on');
select pg_temp.as('op', 'aal1');
select throws_like($$ select public.instance_set_mcp_loopback_clients(true) $$,
  '%second factor%', 'the operator needs the second factor');
select pg_temp.as('op', 'aal2');
select is(public.instance_set_mcp_loopback_clients(true)->>'allow_loopback_clients', 'true',
  'the operator turns it on');
select is((select count(*)::int from public.database_authority_audit
            where action = 'loopback_clients_allowed' and actor = 'instance:' || current_setting('deskilo.op')), 1,
  'audited, naming the operator');
select is(public.instance_mcp_overview()->>'allow_loopback_clients', 'true', 'the console shows the switch');
select is((select c->>'family' from jsonb_array_elements(public.instance_mcp_overview()->'clients') c
            where c->>'client_id' = '00000000-0000-4000-8000-0000002146c1'), 'loopback',
  'and each client''s family');
select is(pg_temp.arrive('m1', 'c1'), 'approved', 'the waiting loopback client is approved on its next arrival');
select is(pg_temp.arrive('m1', 'c2'), 'approved', 'localhost with a port too');
select is(pg_temp.audited('c2'), 'loopback', 'audited as loopback');
select is(pg_temp.arrive('m1', 'c3'), 'waiting', '127.0.0.1.evil.com is not loopback');
select is(pg_temp.arrive('m1', 'c4'), 'waiting', 'https on localhost is not the loopback family');
select is(pg_temp.arrive('m1', 'c5'), 'waiting', 'a loopback redirect mixed with a hosted one waits');

select * from finish();
rollback;
