-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1623 / 0290: membership and subscription requests refuse impossible
-- values before a human is asked, write nothing when nothing changes, and
-- read the member back.
begin;
select plan(7);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid) returns jsonb language sql as $$
  select public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, p_op, p_args, p_request);
$$;
create function pg_temp.confirm_and_run(p_op text, p_args jsonb, p_request uuid) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := pg_temp.call(p_op, p_args, p_request);
  perform pg_temp.act_as('00000000-0000-4000-8000-0000000290a1');
  perform public.mcp_confirm_action((v->'data'->>'confirmation_id')::uuid, true);
  perform pg_temp.act_as('00000000-0000-4000-8000-0000000290a1', 'claude-test');
  return pg_temp.call(p_op, p_args, p_request);
end;
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000290a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o1623@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000290a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1623@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000290a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP M', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status, subscription_pct)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000290a2', 'active', 100);
select set_config('t.m', (select id::text from public.members where workspace_id = current_setting('t.a')::uuid
  and user_id = '00000000-0000-4000-8000-0000000290a2'), true);
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000000290a1' and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.a')::uuid, public.installation_id(), 1, true,
  array['request_member_status_change','request_subscription_change'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000290a1' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, current_setting('t.a')::uuid, array['request_member_status_change','request_subscription_change'], 'workspace'
  from public.mcp_connections where local_user_id = '00000000-0000-4000-8000-0000000290a1';

select pg_temp.act_as('00000000-0000-4000-8000-0000000290a1', 'claude-test');
select set_config('t.p150', pg_temp.call('request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.m'), 'pct', 150), gen_random_uuid())::text, true);
select set_config('t.st', pg_temp.call('request_member_status_change',
  jsonb_build_object('member_id', current_setting('t.m'), 'status', 'banana'), gen_random_uuid())::text, true);
select set_config('t.same', pg_temp.confirm_and_run('request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.m'), 'pct', 100), gen_random_uuid())::text, true);
select set_config('t.half', pg_temp.confirm_and_run('request_subscription_change',
  jsonb_build_object('member_id', current_setting('t.m'), 'pct', 50), gen_random_uuid())::text, true);
reset role;

select is(current_setting('t.p150')::jsonb->>'status', 'validation_error', '150 % is refused before anyone is asked');
select is(current_setting('t.st')::jsonb->>'status', 'validation_error', 'an unknown status too');
select is(current_setting('t.same')::jsonb->'data'->>'unchanged', 'true', 'the value it already has changes nothing');
select is((select count(*)::int from public.events where workspace_id = current_setting('t.a')::uuid
            and type = 'subscription_change' and (payload->>'after')::int = 100), 0, 'and records no event');
select is(current_setting('t.half')::jsonb->>'status', 'completed', 'a real change runs');
select is(current_setting('t.half')::jsonb->'data'->>'subscription_pct', '50', 'and reads the member back');
select is((select subscription_pct from public.members where id = current_setting('t.m')::uuid), 50, 'one effect');

select * from finish();
rollback;
