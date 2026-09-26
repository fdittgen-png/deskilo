-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1616: the MCP server's tools/list is the caller's own — the union over
-- their workspaces of what policy, consent, membership and permission
-- all allow — and a missing gate answers an empty list, not an error.
begin;
select plan(6);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000165a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o1616@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000165a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1616@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant');
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000165a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('List A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.b', public.create_workspace('List B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000165a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, status)
select w, '00000000-0000-4000-8000-0000000165a2', 'active'
  from unnest(array[current_setting('t.a')::uuid, current_setting('t.b')::uuid]) w;
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations) values
 (current_setting('t.a')::uuid, public.installation_id(), 1, true, array['get_capabilities','create_reservation']),
 (current_setting('t.b')::uuid, public.installation_id(), 1, true, array['get_capabilities','check_in']);

select pg_temp.act_as('00000000-0000-4000-8000-0000000165a2', 'claude-test');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations', '[]'::jsonb,
  'without eligibility: nothing');
reset role;
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000000165a2' and status = 'active';
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000165a2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations)
select id, current_setting('t.a')::uuid, array['get_capabilities','create_reservation','check_in'] from public.mcp_connections;

select pg_temp.act_as('00000000-0000-4000-8000-0000000165a2', 'claude-test');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations',
  '["create_reservation", "get_capabilities"]'::jsonb, 'A consented: its policy ∩ consent');
select is(jsonb_array_length(public.mcp_my_operations(current_setting('t.i')::uuid)->'workspaces'), 1,
  'B is not listed: exposed, but never consented');
select is(public.mcp_my_operations(gen_random_uuid())->'operations', '[]'::jsonb,
  'another installation: nothing');
select pg_temp.act_as('00000000-0000-4000-8000-0000000165a2');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations', '[]'::jsonb,
  'a native session is not an MCP client');
reset role;
update public.workspace_mcp_policies set enabled = false where workspace_id = current_setting('t.a')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000165a2', 'claude-test');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations', '[]'::jsonb,
  'A switched off: nothing listed any more');

select * from finish();
rollback;
