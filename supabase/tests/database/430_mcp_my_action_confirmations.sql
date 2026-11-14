-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3978: the assistants page lists the person's own requests: every one
-- still waiting, and the ones answered since the moment the app names. A
-- waiting request past its time reads as expired; another person's and an
-- older answer are not listed; an assistant's token is refused.
begin;

-- The fixture of 60_mcp_action_confirmations.sql: two people, a workspace
-- with assistants on, the first person eligible and connected.
create function public.test_google_identity() returns trigger language plpgsql as $g$
begin
  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (gen_random_uuid(), 'google-' || new.id, new.id,
          jsonb_build_object('sub', 'google-' || new.id), 'google', now(), now());
  return new;
end
$g$;
create trigger zz_test_google_identity after insert on auth.users
  for each row execute function public.test_google_identity();

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')), 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000162a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o3978@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000162a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3978@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant');
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP L1', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
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
select plan(9);

-- The requests, as the server stores them.
create function pg_temp.request(p_id uuid, p_user uuid, p_status text, p_asked interval, p_lasts interval)
returns void language sql as $$
  insert into public.mcp_action_confirmations (id, installation_id, local_user_id, client_id, workspace_id,
    eligibility_grant_id, operation, request_id, args_digest, preview, status, created_at, expires_at)
  select p_id, public.installation_id(), p_user, 'claude-test', current_setting('t.a')::uuid,
    (select id from public.mcp_eligibility_grants limit 1), 'request_subscription_change', gen_random_uuid(), 'digest',
    '{"arguments": {}, "target": {"kind": "member"}}'::jsonb, p_status, now() - p_asked, now() - p_asked + p_lasts;
$$;
select pg_temp.request('00000000-0000-4000-8000-0000000397a1', '00000000-0000-4000-8000-0000000162a1', 'pending', interval '1 minute', interval '5 minutes');
select pg_temp.request('00000000-0000-4000-8000-0000000397a2', '00000000-0000-4000-8000-0000000162a1', 'pending', interval '2 days', interval '5 minutes');
select pg_temp.request('00000000-0000-4000-8000-0000000397a3', '00000000-0000-4000-8000-0000000162a1', 'declined', interval '1 day', interval '5 minutes');
select pg_temp.request('00000000-0000-4000-8000-0000000397a4', '00000000-0000-4000-8000-0000000162a1', 'acknowledged', interval '30 days', interval '5 minutes');
select pg_temp.request('00000000-0000-4000-8000-0000000397a5', '00000000-0000-4000-8000-0000000162a2', 'pending', interval '1 minute', interval '5 minutes');

select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1');
select set_config('t.l', public.mcp_my_action_confirmations(now() - interval '7 days')::text, true);
select is((select array_agg(e->>'id' order by ord) from jsonb_array_elements(current_setting('t.l')::jsonb) with ordinality x(e, ord)),
  array['00000000-0000-4000-8000-0000000397a1', '00000000-0000-4000-8000-0000000397a3', '00000000-0000-4000-8000-0000000397a2'],
  'the waiting one and the answered ones since the moment named, newest first');
select is((select e->>'status' from jsonb_array_elements(current_setting('t.l')::jsonb) e where e->>'id' = '00000000-0000-4000-8000-0000000397a1'),
  'pending', 'a request still in its time waits');
select is((select e->>'status' from jsonb_array_elements(current_setting('t.l')::jsonb) e where e->>'id' = '00000000-0000-4000-8000-0000000397a2'),
  'expired', 'a waiting request past its time reads as expired');
select is((select e->>'status' from jsonb_array_elements(current_setting('t.l')::jsonb) e where e->>'id' = '00000000-0000-4000-8000-0000000397a3'),
  'declined', 'an answered request carries its answer');
select is((select e->>'client_name' || ' / ' || (e->>'created_at' is not null)::text
    from jsonb_array_elements(current_setting('t.l')::jsonb) e where e->>'id' = '00000000-0000-4000-8000-0000000397a1'),
  'Test assistant / true', 'each names the assistant that asked and when');
select is(jsonb_array_length(public.mcp_my_action_confirmations(now())), 1,
  'a waiting request is listed whatever moment the app names');

select pg_temp.act_as('00000000-0000-4000-8000-0000000162a2');
select is((select array_agg(e->>'id') from jsonb_array_elements(public.mcp_my_action_confirmations(now() - interval '7 days')) e),
  array['00000000-0000-4000-8000-0000000397a5'], 'another person reads only their own');

select pg_temp.act_as('00000000-0000-4000-8000-0000000162a1', 'claude-test');
select throws_ok($$select public.mcp_my_action_confirmations(now() - interval '7 days')$$, 'DKN01',
  'confirmations are answered in the Deskilo app', 'an assistant''s token reads none');
reset role;
select ok(not has_function_privilege('anon', 'public.mcp_my_action_confirmations(timestamptz)', 'execute'),
  'nobody signed out can ask');

select * from finish();
rollback;
