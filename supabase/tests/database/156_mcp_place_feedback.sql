-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0375: favourites and ratings through an assistant.
begin;

-- 0340 — assistants act only for Google accounts: every test user this
-- file creates gets a Google identity (a trigger inside this transaction,
-- rolled back with it).
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
select plan(9);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')), 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.call(p_op text, p_args jsonb, p_req uuid default gen_random_uuid()) returns jsonb language sql as $$
  select public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.a')::uuid, p_op, p_args, p_req);
$$;

select set_config('t.i', public.installation_id()::text, true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000296a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'own-r@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000296a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mem-r@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;

select pg_temp.act_as('00000000-0000-4000-8000-0000000296a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP R', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as('00000000-0000-4000-8000-0000000296a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}',
  role_permissions = '{"member":["makeReservations"]}'::jsonb, booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000296a2', 'active');
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000000296a1');
select pg_temp.act_as('00000000-0000-4000-8000-0000000296a1');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000296a2', '00000000-0000-4000-8000-00000000e296', true);
select public.save_mcp_policy(current_setting('t.a')::uuid, 0, gen_random_uuid(), true,
  array['set_favorite','rate_place','list_my_favorites','get_place'], 'own');
reset role;
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000296a2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations)
select c.id, current_setting('t.a')::uuid,
       array['set_favorite','rate_place','list_my_favorites','get_place']
  from public.mcp_connections c where c.local_user_id = '00000000-0000-4000-8000-0000000296a2';
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);

select pg_temp.act_as('00000000-0000-4000-8000-0000000296a2', 'claude-test');
select set_config('t.f1', pg_temp.call('set_favorite', jsonb_build_object('kind', 'seat', 'resource_id', current_setting('t.seat')))::text, true);
select set_config('t.l1', pg_temp.call('list_my_favorites', '{}'::jsonb)::text, true);
select set_config('t.g1', pg_temp.call('get_place', jsonb_build_object('seat_id', current_setting('t.seat')))::text, true);
select set_config('t.r1', pg_temp.call('rate_place', jsonb_build_object('kind', 'seat', 'resource_id', current_setting('t.seat'), 'stars', 5))::text, true);
select set_config('t.r2', pg_temp.call('rate_place', jsonb_build_object('kind', 'seat', 'resource_id', current_setting('t.seat'), 'stars', 7))::text, true);
select set_config('t.r3', pg_temp.call('rate_place', jsonb_build_object('kind', 'seat', 'resource_id', current_setting('t.seat'), 'clear', true))::text, true);
select set_config('t.f2', pg_temp.call('set_favorite', jsonb_build_object('kind', 'seat', 'resource_id', current_setting('t.seat'), 'favorite', false))::text, true);
select set_config('t.l2', pg_temp.call('list_my_favorites', '{}'::jsonb)::text, true);
reset role;
update public.workspaces set feature_flags = feature_flags || '{"placeFeedback": false}' where id = current_setting('t.a')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000296a2', 'claude-test');
select set_config('t.off', pg_temp.call('set_favorite', jsonb_build_object('kind', 'seat', 'resource_id', current_setting('t.seat')))::text, true);
reset role;

select is(current_setting('t.f1')::jsonb->>'status', 'completed', 'an assistant marks a favourite as the person');
select is(current_setting('t.l1')::jsonb->'data'->'items'->0->>'resource_id', current_setting('t.seat'), 'and lists it with its id');
select ok(current_setting('t.l1')::jsonb->'data'->'items'->0->>'label' <> '', 'and its label');
select is(current_setting('t.g1')::jsonb->'data'->>'favorite', 'true', 'a favourite is described without the workspace ceiling, with its mark');
select is((current_setting('t.r1')::jsonb->'data'->>'mine')::int, 5, 'a rating is recorded');
select is(current_setting('t.r2')::jsonb->>'status', 'validation_error', 'seven stars is refused');
select is(current_setting('t.r3')::jsonb->'data'->>'mine', null, 'a rating is taken back');
select is(jsonb_array_length(current_setting('t.l2')::jsonb->'data'->'items'), 0, 'an unfavourited place leaves the list');
select is(current_setting('t.off')::jsonb->>'status', 'conflict', 'with the feature off the write is refused with its reason');

select * from finish();
rollback;
