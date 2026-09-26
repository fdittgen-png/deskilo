-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1610/#1612: per-workspace MCP exposure and the one dispatch door.
-- One person, three workspaces: A exposes booking, B only capabilities,
-- C is off. Every call runs as `authenticated` with the OAuth client in
-- the token; effects are read back as postgres.
begin;
select plan(18);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000161a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'own-o@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000161a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mem-u@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant');
update public.mcp_runtime set enabled = true;

select pg_temp.act_as('00000000-0000-4000-8000-0000000161a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.b', public.create_workspace('MCP B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.c', public.create_workspace('MCP C', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as('00000000-0000-4000-8000-0000000161a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, status)
select w, '00000000-0000-4000-8000-0000000161a2', 'active'
  from unnest(array[current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.c')::uuid]) w;
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000000161a1');

select pg_temp.act_as('00000000-0000-4000-8000-0000000161a1');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000161a2', '00000000-0000-4000-8000-00000000e001', true);
select throws_ok(format($$select public.save_mcp_policy(%L, 0, gen_random_uuid(), true, array['list_workspaces'], 'own')$$,
  current_setting('t.a')), 'P0001', 'unknown or unimplemented operation list_workspaces', 'no unimplemented operation');
select is(public.save_mcp_policy(current_setting('t.a')::uuid, 0, '00000000-0000-4000-8000-00000000f001', true,
  array['get_capabilities','create_reservation','request_reservation_deletion'], 'own')->>'status', 'saved', 'the owner exposes A');
select is(public.save_mcp_policy(current_setting('t.a')::uuid, 0, '00000000-0000-4000-8000-00000000f001', true,
  array['get_capabilities','create_reservation','request_reservation_deletion'], 'own')->>'status', 'replayed', 'the same save replays');
select is(public.save_mcp_policy(current_setting('t.a')::uuid, 0, '00000000-0000-4000-8000-00000000f001', false,
  array[]::text[], 'own')->>'reason', 'mutation_id_reused', 'another payload under the same id conflicts');
select is(public.save_mcp_policy(current_setting('t.a')::uuid, 0, gen_random_uuid(), true,
  array['get_capabilities'], 'own')->>'reason', 'stale_revision', 'a stale revision conflicts');
select is(public.save_mcp_policy(current_setting('t.b')::uuid, 0, gen_random_uuid(), true,
  array['get_capabilities'], 'own')->>'status', 'saved', 'B exposes less');
select throws_ok(format($$select public.save_mcp_policy(%L, 0, gen_random_uuid(), true, array['get_capabilities'], 'own')$$,
  current_setting('t.c')), 'P0001', 'the MCP feature is off for this workspace', 'C cannot be enabled with the feature off');
reset role;
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000161a2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations)
select c.id, w, array['get_capabilities','create_reservation','request_reservation_deletion']
  from public.mcp_connections c,
       unnest(array[current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.c')::uuid]) w;

select pg_temp.act_as('00000000-0000-4000-8000-0000000161a2');
select throws_ok(format($$select public.save_mcp_policy(%L, 1, gen_random_uuid(), false, array[]::text[], 'own')$$,
  current_setting('t.a')), 'P0001', 'only the owner configures MCP exposure', 'a member cannot configure');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'get_capabilities', '{}', null)->'error'->>'code',
  'no_client', 'a native session is not an MCP client');
select pg_temp.act_as('00000000-0000-4000-8000-0000000161a2', 'claude-test');
select is(public.mcp_execute_v1(gen_random_uuid(), current_setting('t.a')::uuid, 'get_capabilities', '{}', null)->'error'->>'code',
  'wrong_installation', 'another installation is refused');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'get_capabilities', '{}', null)->'data'->'operations',
  '["create_reservation", "get_capabilities", "request_reservation_deletion"]'::jsonb, 'A: the intersection');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.b')::uuid, 'get_capabilities', '{}', null)->'data'->'operations',
  '["get_capabilities"]'::jsonb, 'B: less, for the same person');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.c')::uuid, 'get_capabilities', '{}', null)->'error'->>'code',
  'not_exposed', 'C: nothing');
select set_config('t.args', json_build_object(
  'seat_id', (select id from public.seats where workspace_id = current_setting('t.a')::uuid order by id limit 1),
  'starts_at', to_char(((now() at time zone 'Europe/Paris')::date + 7 + time '08:00') at time zone 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'ends_at', to_char(((now() at time zone 'Europe/Paris')::date + 7 + time '12:00') at time zone 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))::text, true);
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'create_reservation',
  current_setting('t.args')::jsonb, '00000000-0000-4000-8000-00000000a001')->>'status', 'completed', 'A books');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'create_reservation',
  current_setting('t.args')::jsonb, '00000000-0000-4000-8000-00000000a001')->>'status', 'completed', 'the replay answers the same');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'create_reservation',
  current_setting('t.args')::jsonb || '{"desk_id":null}', '00000000-0000-4000-8000-00000000a001')->'error'->>'code',
  'request_id_reused', 'the same id with other arguments conflicts');
select is(public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, 'request_reservation_deletion',
  '{"reservation_id":"00000000-0000-4000-8000-0000000000aa"}', gen_random_uuid())->>'status',
  'not_found', 'an unknown reservation is not found: a deletion request names a real one (0272)');
reset role;
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.a')::uuid), 1,
  'one booking, however often it was asked');

select * from finish();
rollback;
