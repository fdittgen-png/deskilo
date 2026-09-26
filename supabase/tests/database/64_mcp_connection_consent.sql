-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1615: a person connects an assistant from the app, workspace by
-- workspace: only exposed workspaces and permitted operations are offered,
-- eligibility is required, an assistant's own token can never manage
-- consent, finalising makes exactly the chosen subset usable, and removing
-- one workspace leaves the other.
begin;
select plan(17);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000167a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o1615@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000167a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1615@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-consent', 'Consent assistant')
  on conflict (client_id) do update set status = 'active';
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000167a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('Consent A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.b', public.create_workspace('Consent B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.c', public.create_workspace('Consent C', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, status)
select w, '00000000-0000-4000-8000-0000000167a2', 'active'
  from unnest(array[current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.c')::uuid]) w;
-- C is exposed by policy but its mcpAccess flag is off: never offered.
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, target_ceiling, operations) values
 (current_setting('t.a')::uuid, public.installation_id(), 1, true, 'workspace',
  array['get_capabilities','get_availability','create_reservation','request_invoice_issue']),
 (current_setting('t.b')::uuid, public.installation_id(), 1, true, 'workspace', array['get_capabilities','check_in']),
 (current_setting('t.c')::uuid, public.installation_id(), 1, true, 'workspace', array['get_capabilities']);

select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2', 'claude-consent');
select throws_ok($$select public.mcp_consent_options()$$, 'P0001', 'connections are managed in the Deskilo app',
  'an assistant token cannot read the consent options');
select throws_ok($$select public.mcp_prepare_connection('claude-consent', 'authz-self-00001', '[]')$$, 'P0001', null,
  'nor prepare its own consent');

select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2');
select isnt(public.mcp_consent_options()->>'eligibility', 'eligible', 'not yet eligible');
select throws_ok(format($$select public.mcp_prepare_connection('claude-consent', 'authz-early-0001', '[{"workspace_id": "%s", "operations": ["check_in"]}]')$$,
  current_setting('t.b')), 'P0001', 'this database has not approved MCP for you yet', 'preparing needs eligibility');

reset role;
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = '00000000-0000-4000-8000-0000000167a2' and status = 'active';

select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2');
select set_config('t.opt', public.mcp_consent_options()::text, true);
select is(current_setting('t.opt')::jsonb->>'eligibility', 'eligible', 'eligible now');
select is((select jsonb_agg(w->>'name' order by w->>'name') from jsonb_array_elements(current_setting('t.opt')::jsonb->'workspaces') w),
  '["Consent A", "Consent B"]'::jsonb, 'only the workspaces with mcpAccess on are offered');
select is((select w->'operations' from jsonb_array_elements(current_setting('t.opt')::jsonb->'workspaces') w where w->>'name' = 'Consent A'),
  '["create_reservation", "get_availability", "get_capabilities"]'::jsonb,
  'an operation the person has no permission for is not offered');
select throws_ok(format($$select public.mcp_prepare_connection('claude-consent', 'authz-bad-00001', '[{"workspace_id": "%s", "operations": ["get_capabilities"]}]')$$,
  current_setting('t.c')), 'P0001', null, 'an unoffered workspace cannot be chosen');
select throws_ok(format($$select public.mcp_prepare_connection('claude-consent', 'authz-bad-00002', '[{"workspace_id": "%s", "operations": ["request_invoice_issue"]}]')$$,
  current_setting('t.a')), 'P0001', null, 'an unoffered operation cannot be chosen');

select lives_ok(format($$select public.mcp_prepare_connection('claude-consent', 'authz-good-0001',
  '[{"workspace_id": "%s", "operations": ["get_capabilities", "get_availability"]}, {"workspace_id": "%s", "operations": ["check_in"]}]')$$,
  current_setting('t.a'), current_setting('t.b')), 'the chosen subset is recorded');
select throws_ok(format($$select public.mcp_prepare_connection('claude-consent', 'authz-good-0001', '[{"workspace_id": "%s", "operations": ["check_in"]}]')$$,
  current_setting('t.b')), 'P0001', 'this authorization was prepared differently', 'one authorization, one subset');

select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2', 'claude-consent');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations', '[]'::jsonb,
  'prepared is not usable: nothing before finalising');
select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2');
select is(public.mcp_finalize_connection('authz-good-0001')->>'status', 'finalized', 'finalised');
select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2', 'claude-consent');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations',
  '["check_in", "get_availability", "get_capabilities"]'::jsonb, 'exactly the chosen subset is usable');

select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2');
select is(jsonb_array_length((public.my_mcp_connections()->0)->'workspaces'), 2, 'the connection lists both workspaces');
select is(public.revoke_mcp_workspace_scope('claude-consent', current_setting('t.a')::uuid)->>'status', 'revoked',
  'A is removed');
select pg_temp.act_as('00000000-0000-4000-8000-0000000167a2', 'claude-consent');
select is(public.mcp_my_operations(current_setting('t.i')::uuid)->'operations', '["check_in"]'::jsonb,
  'B still works without A');

select * from finish();
rollback;
