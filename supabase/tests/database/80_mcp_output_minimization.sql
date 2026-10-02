-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1644 / 0293: the database decides what an MCP answer may carry: a
-- person's name or address planted in a seat label never leaves it, the
-- operational fields do, and a stored answer wider than today's policy is
-- narrowed on replay, not re-run.
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
select plan(7);

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
 ('00000000-0000-4000-8000-0000000293a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'own-m@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000293a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mem-m@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
select pg_temp.act_as('00000000-0000-4000-8000-0000000293a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP P', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as('00000000-0000-4000-8000-0000000293a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000293a2', 'active');
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);
update public.seats set name = 'Desk of Alice Canary <alice.canary@example.org>' where id = current_setting('t.seat')::uuid;
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000000293a1');
select pg_temp.act_as('00000000-0000-4000-8000-0000000293a1');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000293a2', '00000000-0000-4000-8000-00000000e293', true);
select public.save_mcp_policy(current_setting('t.a')::uuid, 0, gen_random_uuid(), true,
  array['get_availability','create_reservation'], 'workspace');
reset role;
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000293a2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select c.id, current_setting('t.a')::uuid, array['get_availability','create_reservation'], 'workspace'
  from public.mcp_connections c where c.local_user_id = '00000000-0000-4000-8000-0000000293a2';
select set_config('t.day', ((now() at time zone 'Europe/Paris')::date + 2)::text, true);
select set_config('t.s', to_jsonb((current_setting('t.day') || ' 08:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.e', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000000293a2', 'claude-test');
select set_config('t.av', pg_temp.call('get_availability',
  jsonb_build_object('starts_at', current_setting('t.s'), 'ends_at', current_setting('t.e')))::text, true);
select set_config('t.c1', pg_temp.call('create_reservation', jsonb_build_object('seat_id', current_setting('t.seat'),
  'starts_at', current_setting('t.s'), 'ends_at', current_setting('t.e')), '00000000-0000-4000-8000-00000000f293')::text, true);
reset role;
-- An answer stored wider than the policy allows (as an older release could).
update public.mcp_idempotency set outcome = jsonb_set(outcome, '{data,private_note}', '"CANARY-NOTE for Alice"')
 where request_id = '00000000-0000-4000-8000-00000000f293';
select pg_temp.act_as('00000000-0000-4000-8000-0000000293a2', 'claude-test');
select set_config('t.c2', pg_temp.call('create_reservation', jsonb_build_object('seat_id', current_setting('t.seat'),
  'starts_at', current_setting('t.s'), 'ends_at', current_setting('t.e')), '00000000-0000-4000-8000-00000000f293')::text, true);
reset role;

select is(current_setting('t.av')::jsonb->>'status', 'completed', 'availability answers');
select ok(position('Canary' in current_setting('t.av')) = 0 and position('example.org' in current_setting('t.av')) = 0,
  'a name and an address in a seat label never leave the database');
select ok(exists (select 1 from jsonb_array_elements(current_setting('t.av')::jsonb->'data'->'items') r
                   where r->>'seat_id' = current_setting('t.seat') and r ? 'free'),
  'the seat is still there, by reference, with whether it is free');
select is(current_setting('t.c1')::jsonb->>'status', 'completed', 'booking by that reference works');
select ok(position('CANARY' in current_setting('t.c2')) = 0, 'a stored answer wider than today''s policy is narrowed on replay');
select is(current_setting('t.c2')::jsonb->'data'->>'reservation_id', current_setting('t.c1')::jsonb->'data'->>'reservation_id',
  'and still answers the same booking');
select is((select count(*)::int from public.reservations where seat_id = current_setting('t.seat')::uuid), 1,
  'replaying never books twice');

select * from finish();
rollback;
