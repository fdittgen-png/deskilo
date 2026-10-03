-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2145 / 0354 (S1 + S5) — the consent page learns the real cause at load.
-- A dynamically registered assistant resolves to purpose `mcp` with the
-- operator's decision as its status (approved, waiting, blocked); nothing
-- is approved by it. The first arrival of a member of an mcpAccess
-- workspace with a waiting client is audited and notifies every instance
-- operator, once per client; an outsider raises no flag. A manually
-- registered unknown client still fails closed (0297). The consent options
-- name the client, its redirect host and who decides the first open step.
-- Installation notices belong to their recipient. The MCP endpoint is
-- answered to members of an mcpAccess workspace and to the operator, and
-- only the operator changes it, with a second factor, audited.
begin;
select plan(31);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  op uuid := '00000000-0000-4000-8000-000000214501';
  m1 uuid := '00000000-0000-4000-8000-000000214502';
  m2 uuid := '00000000-0000-4000-8000-000000214503';
  adm uuid := '00000000-0000-4000-8000-000000214504';
  ws uuid;
  ws2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         n || '-2145@deskilo.test', '', now(), now(), now()
    from (values (op, 'op'), (m1, 'm1'), (m2, 'm2'), (adm, 'adm')) v(u, n);
  update public.profiles set display_name = 'Olga Operator' where id = op;
  update public.profiles set display_name = 'Ada Admin' where id = adm;
  update public.profiles set display_name = 'Mia Member' where id = m1;
  -- The longest-standing owner is the one a member is told to ask.
  insert into public.platform_admins (user_id, added_at) values (op, '2000-01-01');
  delete from public.identity_authority;
  insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
  perform set_config('request.jwt.claims', json_build_object('sub', op, 'role', 'authenticated')::text, true);
  ws := public.create_workspace('Assistants 2145', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null);
  ws2 := public.create_workspace('No assistants 2145', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null);
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  perform public.finalize_identity_binding();
  perform set_config('request.jwt.claims', json_build_object('sub', m1, 'role', 'authenticated')::text, true);
  perform public.finalize_identity_binding();
  perform set_config('request.jwt.claims', '', true);
  update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
   where id = ws;
  update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": false}'
   where id = ws2;
  -- One installation, two workspaces: each decides for itself.
  insert into public.members (workspace_id, user_id, status) values (ws, m1, 'active'), (ws2, m1, 'active');
  insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
  values (ws, public.installation_id(), 1, true, array['get_capabilities'], 'own'),
         (ws2, public.installation_id(), 1, true, array['get_capabilities'], 'own');
  insert into auth.oauth_clients (id, client_name, registration_type, redirect_uris, grant_types, token_endpoint_auth_method)
  values ('00000000-0000-4000-8000-0000002145c1', 'Fresh assistant', 'dynamic',
          'https://assistant.example/callback', 'authorization_code', 'none'),
         ('00000000-0000-4000-8000-0000002145c2', 'Blocked assistant', 'dynamic',
          'https://blocked.example/callback', 'authorization_code', 'none'),
         ('00000000-0000-4000-8000-0000002145c3', 'Approved assistant', 'dynamic',
          'https://approved.example/callback', 'authorization_code', 'none'),
         ('00000000-0000-4000-8000-0000002145c4', 'Manual client', 'manual',
          'https://manual.example/callback', 'authorization_code', 'client_secret_basic'),
         ('00000000-0000-4000-8000-0000002145c5', 'Outsider assistant', 'dynamic',
          'https://outsider.example/callback', 'authorization_code', 'none');
  insert into public.mcp_clients (client_id, name, status) values
    ('00000000-0000-4000-8000-0000002145c2', 'Blocked assistant', 'revoked'),
    ('00000000-0000-4000-8000-0000002145c3', 'Approved assistant', 'active');
  insert into auth.oauth_authorizations (id, authorization_id, client_id, redirect_uri, scope,
                                         code_challenge, code_challenge_method)
  select gen_random_uuid(), repeat(l, 32), ('00000000-0000-4000-8000-0000002145' || c)::uuid,
         r, 'openid', repeat('a', 43), 's256'
    from (values ('a', 'c1', 'https://assistant.example/callback'),
                 ('b', 'c2', 'https://blocked.example/callback'),
                 ('c', 'c3', 'https://approved.example/callback'),
                 ('d', 'c4', 'https://manual.example/callback'),
                 ('e', 'c5', 'https://outsider.example/callback'),
                 ('f', 'c1', 'https://assistant.example/callback')) v(l, c, r);
  update auth.oauth_authorizations set user_id = m2 where authorization_id = repeat('f', 32);
  perform set_config('deskilo.op', op::text, false);
  perform set_config('deskilo.m1', m1::text, false);
  perform set_config('deskilo.m2', m2::text, false);
  perform set_config('deskilo.adm', adm::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as(p_user text, p_aal text default 'aal1') returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('deskilo.' || p_user), 'role', 'authenticated', 'aal', p_aal,
    'amr', json_build_array(json_build_object('method', 'oauth')))::text, false);
$$;
create or replace function pg_temp.notices(p_user text, p_kind text) returns int language sql as $$
  select count(*)::int from public.instance_notices
   where user_id = current_setting('deskilo.' || p_user)::uuid and kind = p_kind;
$$;

-- ── the context names the decision, approves nothing ─────────────────
select pg_temp.as('m1');
select is(public.oauth_authorization_context(repeat('c', 32))->>'client_status', 'approved',
  'an approved assistant resolves as approved');
select is(public.oauth_authorization_context(repeat('a', 32)) - 'local_user_id',
  jsonb_build_object('purpose', 'mcp', 'client_id', '00000000-0000-4000-8000-0000002145c1',
                     'client_status', 'waiting'),
  'a freshly registered assistant resolves to the MCP consent, waiting');
select is((select count(*)::int from public.mcp_clients
            where client_id = '00000000-0000-4000-8000-0000002145c1'), 0,
  'resolving it approved nothing');
select is((select count(*)::int from public.database_authority_audit
            where action = 'client_waiting' and detail->>'client_id' = '00000000-0000-4000-8000-0000002145c1'), 1,
  'the waiting arrival is audited');
select is(pg_temp.notices('op', 'mcp_client_waiting'), 1, 'the operator is notified');
select is((select payload->>'redirect_host' from public.instance_notices
            where user_id = current_setting('deskilo.op')::uuid and kind = 'mcp_client_waiting'),
  'assistant.example', 'the notice names the redirect host');
select is((select payload->>'requested_by' from public.instance_notices
            where user_id = current_setting('deskilo.op')::uuid and kind = 'mcp_client_waiting'),
  'Mia Member', 'and who arrived with it');
select lives_ok($$ select public.oauth_authorization_context(repeat('a', 32)) $$, 'a second arrival');
select is(pg_temp.notices('op', 'mcp_client_waiting')
          + (select count(*)::int from public.database_authority_audit
              where action = 'client_waiting' and detail->>'client_id' = '00000000-0000-4000-8000-0000002145c1'),
  2, 'notifies and audits nothing more: once per client');
select is(public.oauth_authorization_context(repeat('b', 32))->>'client_status', 'blocked',
  'a revoked assistant resolves as blocked');
select is(pg_temp.notices('op', 'mcp_client_waiting'), 1, 'a blocked assistant notifies nobody');
select throws_ok($$ select public.oauth_authorization_context(repeat('d', 32)) $$,
  'P0001', 'oauth client purpose unavailable', 'an unknown manual client still fails closed');
select pg_temp.as('m2');
select is(public.oauth_authorization_context(repeat('e', 32))->>'client_status', 'waiting',
  'someone outside any mcpAccess workspace sees the status too');
select is((select count(*)::int from public.instance_notices
            where subject = '00000000-0000-4000-8000-0000002145c5'), 0,
  'but raises no flag');

-- ── consent options: the client and who decides ──────────────────────
select pg_temp.as('m1');
select is((public.mcp_consent_options(repeat('a', 32))->'client') - 'family',
  jsonb_build_object('client_id', '00000000-0000-4000-8000-0000002145c1', 'name', 'Fresh assistant',
                     'status', 'waiting', 'redirect_host', 'assistant.example'),
  'the options name the client, its status and redirect host');
select is(public.mcp_consent_options(repeat('a', 32))->'decider',
  '{"kind": "operator", "display_name": "Olga Operator", "me": false}'::jsonb,
  'a waiting client is the operator''s decision, by name');
select is(public.mcp_consent_options(repeat('c', 32))->'decider'->>'kind', 'operator',
  'eligibility with no other database administrator falls to the operator');
select public.operator_grant_database_admin(current_setting('deskilo.adm')::uuid, true);
select is(public.mcp_consent_options(repeat('c', 32))->'decider',
  '{"kind": "admin", "display_name": "Ada Admin", "me": false}'::jsonb,
  'with an administrator, eligibility is theirs');
select is(public.mcp_consent_options()->'client', 'null'::jsonb,
  'without an authorization the options carry no client');
select is((select jsonb_agg(w->>'name') from jsonb_array_elements(public.mcp_consent_options()->'workspaces') w),
  '["Assistants 2145"]'::jsonb,
  'of two workspaces on one installation, only the one with mcpAccess on is offered');
select throws_ok($$ select public.mcp_consent_options(repeat('f', 32)) $$,
  'P0001', 'oauth authorization unavailable', 'another person''s authorization is refused');
select pg_temp.as('op');
select is(public.mcp_consent_options(repeat('b', 32))->'decider'->>'me', 'true',
  'the operator is told the decision is theirs');

-- ── notices belong to their recipient ────────────────────────────────
select pg_temp.as('m1');
select is((public.my_instance_notices()->>'unread')::int, 0, 'a member reads none of the operator''s notices');
select is(public.mark_instance_notice_read()->>'count', '0', 'nor marks them');
select pg_temp.as('op');
select is((public.my_instance_notices()->>'unread')::int >= 1, true, 'the operator reads theirs');
select is(public.mark_instance_notice_read()->>'status', 'read', 'and marks them read');
select is((public.my_instance_notices()->>'unread')::int, 0, 'nothing is left unread');

-- ── the endpoint ─────────────────────────────────────────────────────
select pg_temp.as('m2');
select throws_like($$ select public.mcp_endpoint() $$, '%not offered to you%',
  'someone outside every mcpAccess workspace is not given the endpoint');
select pg_temp.as('op');
select throws_like($$ select public.instance_set_mcp_endpoint('https://mcp.deskilo.test/mcp') $$,
  '%second factor%', 'changing it needs the second factor');
select pg_temp.as('op', 'aal2');
select is(public.instance_set_mcp_endpoint('https://mcp.deskilo.test/mcp/') - 'metadata_url',
  '{"resource": "https://mcp.deskilo.test/mcp", "source": "configured"}'::jsonb,
  'the operator configures the published endpoint, audited');
select pg_temp.as('m1');
select is(public.mcp_endpoint()->>'metadata_url',
  'https://mcp.deskilo.test/mcp/.well-known/oauth-protected-resource',
  'a member of an mcpAccess workspace reads it, with its metadata URL');

select * from finish();
rollback;
