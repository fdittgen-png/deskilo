-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1624 / 0291: a validation decision through MCP counts one person once,
-- says it was recorded, and never claims the effect while others still
-- have to decide.
begin;
select plan(8);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.respond(p_args jsonb, p_request uuid) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-0000000291b2', 'claude-test');
  v := public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'respond_to_validation', p_args, p_request);
  if v->>'status' <> 'requires_confirmation' then return v; end if;
  perform pg_temp.act_as('00000000-0000-4000-8000-0000000291b2');
  perform public.mcp_confirm_action((v->'data'->>'confirmation_id')::uuid, true);
  perform pg_temp.act_as('00000000-0000-4000-8000-0000000291b2', 'claude-test');
  return public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'respond_to_validation', p_args, p_request);
end;
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000000291' || s)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated',
       'authenticated', s || '@v1624.deskilo.test', '', now(), now(), now()
  from unnest(array['a1', 'b2', 'c3', 'd4']) s;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000291a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP V', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000291b2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000291b2', 'active', true, 100),
       (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000291c3', 'active', true, 100),
       (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000291d4', 'active', false, 100);
select set_config('t.d', (select id::text from public.members where workspace_id = current_setting('t.a')::uuid
  and user_id = '00000000-0000-4000-8000-0000000291d4'), true);
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (current_setting('t.a')::uuid, 'subscription_change', 2, true, 'admins');
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000000291b2' and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.a')::uuid, public.installation_id(), 1, true, array['respond_to_validation'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000291b2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, current_setting('t.a')::uuid, array['respond_to_validation'], 'workspace'
  from public.mcp_connections where local_user_id = '00000000-0000-4000-8000-0000000291b2';

-- The owner asks, in the app: two admins must agree.
select pg_temp.act_as('00000000-0000-4000-8000-0000000291a1');
select set_config('t.e', (public.request_subscription_change(current_setting('t.d')::uuid, 50)->>'event_id'), true);
reset role;

select set_config('t.bad', pg_temp.respond(jsonb_build_object('event_id', current_setting('t.e'), 'accept', 'maybe'), gen_random_uuid())::text, true);
select set_config('t.b1', pg_temp.respond(jsonb_build_object('event_id', current_setting('t.e'), 'accept', true), gen_random_uuid())::text, true);
select set_config('t.b2', pg_temp.respond(jsonb_build_object('event_id', current_setting('t.e'), 'accept', true), gen_random_uuid())::text, true);
reset role;

select is(current_setting('t.bad')::jsonb->>'status', 'validation_error', 'maybe is not a decision');
select is(current_setting('t.b1')::jsonb->>'status', 'pending_validation', 'one of two approvals: still pending');
select is(current_setting('t.b1')::jsonb->'data'->>'decision_recorded', 'true', 'and says the decision was recorded');
select is(current_setting('t.b1')::jsonb->'data'->>'effect_applied', 'false', 'not that the change happened');
select is(current_setting('t.b2')::jsonb->>'status', 'conflict', 'the same person again, under another request, is refused');
select is((select count(*)::int from public.event_decisions where event_id = current_setting('t.e')::uuid), 1,
  'one person counts once');

-- The second admin decides in the app: the change applies, once.
select pg_temp.act_as('00000000-0000-4000-8000-0000000291c3');
select public.respond_to_event(current_setting('t.e')::uuid, true);
reset role;
select ok((select status from public.events where id = current_setting('t.e')::uuid) in ('applied', 'confirmed'),
  'the second person completes the quorum');
select is((select subscription_pct from public.members where id = current_setting('t.d')::uuid), 50, 'the effect, once');

select * from finish();
rollback;
