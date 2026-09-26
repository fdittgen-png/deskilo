-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1619: a high-impact MCP action waits for its human, in the app. Calls
-- run as `authenticated`; the MCP calls carry the OAuth client in the
-- token, the confirmations do not; effects are read back as postgres.
begin;
select plan(13);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.call(p_request uuid, p_pct integer) returns jsonb language sql as $$
  select public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid,
    'request_subscription_change', json_build_object('member_id', current_setting('t.m'), 'pct', p_pct)::jsonb, p_request);
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000162a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o1619@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000162a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1619@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant');
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP C1', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000162a2', 'active');
select set_config('t.m', (select id::text from public.members where workspace_id = current_setting('t.a')::uuid
  and user_id = '00000000-0000-4000-8000-0000000162a2'), true);
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000000162a1' and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.a')::uuid, public.installation_id(), 1, true, array['request_subscription_change'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000162a1' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, current_setting('t.a')::uuid, array['request_subscription_change'], 'workspace' from public.mcp_connections;

select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1', 'claude-test');
select set_config('t.r1', pg_temp.call('00000000-0000-4000-8000-00000000c001', 50)::text, true);
select is(current_setting('t.r1')::jsonb->>'status', 'requires_confirmation', 'a high-impact action asks first');
select is(pg_temp.call('00000000-0000-4000-8000-00000000c001', 50)->'data'->>'confirmation_id',
  current_setting('t.r1')::jsonb->'data'->>'confirmation_id', 'asking again reuses the challenge');
select is(pg_temp.call('00000000-0000-4000-8000-00000000c001', 10)->'error'->>'code', 'request_id_reused',
  'a changed payload cannot reuse it');
select throws_ok(format($$select public.mcp_confirm_action(%L, true)$$,
  current_setting('t.r1')::jsonb->'data'->>'confirmation_id'), 'P0001',
  'confirmations are answered in the Deskilo app', 'an OAuth token cannot confirm');
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a2');
select is(public.mcp_confirm_action((current_setting('t.r1')::jsonb->'data'->>'confirmation_id')::uuid, true)->>'status',
  'not_found', 'another person cannot confirm');
reset role;
select is((select subscription_pct from public.members where id = current_setting('t.m')::uuid), 100,
  'nothing happened before the confirmation');

select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1');
select is(public.mcp_get_action_confirmation((current_setting('t.r1')::jsonb->'data'->>'confirmation_id')::uuid)->'preview'->'target'->>'kind',
  'member', 'the bound person sees what it is about');
select is(public.mcp_confirm_action((current_setting('t.r1')::jsonb->'data'->>'confirmation_id')::uuid, true)->>'status',
  'acknowledged', 'the bound person confirms in the app');
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1', 'claude-test');
select is(pg_temp.call('00000000-0000-4000-8000-00000000c001', 50)->>'status', 'completed', 'the retry runs the action once');
select is(pg_temp.call('00000000-0000-4000-8000-00000000c001', 50)->>'status', 'completed', 'and replays after that');
reset role;
select is((select subscription_pct from public.members where id = current_setting('t.m')::uuid), 50, 'one effect');

select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1', 'claude-test');
select set_config('t.r2', pg_temp.call('00000000-0000-4000-8000-00000000c002', 20)::text, true);
reset role;
update public.members set managed_name = 'changed meanwhile' where id = current_setting('t.m')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1');
select is(public.mcp_confirm_action((current_setting('t.r2')::jsonb->'data'->>'confirmation_id')::uuid, true)->>'status',
  'target_changed', 'a changed target authorises nothing');
reset role;
update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
 where local_user_id = '00000000-0000-4000-8000-0000000162a1';
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1', 'claude-test');
select is(pg_temp.call('00000000-0000-4000-8000-00000000c003', 30)->'error'->>'code', 'not_eligible',
  'a revoked person asks nothing');

select * from finish();
rollback;
