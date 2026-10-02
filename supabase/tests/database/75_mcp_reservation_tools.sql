-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1620 / 0288: the owned-reservation MCP tools read back what happened,
-- refuse a stale expected state, and pass the caller's check_in through.
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
 ('00000000-0000-4000-8000-0000000288a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'own-r@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000288a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mem-r@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;

select pg_temp.act_as('00000000-0000-4000-8000-0000000288a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('MCP R', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as('00000000-0000-4000-8000-0000000288a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status)
values (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000288a2', 'active');
select public.operator_grant_database_admin('00000000-0000-4000-8000-0000000288a1');
select pg_temp.act_as('00000000-0000-4000-8000-0000000288a1');
select public.decide_mcp_eligibility('00000000-0000-4000-8000-0000000288a2', '00000000-0000-4000-8000-00000000e288', true);
select public.save_mcp_policy(current_setting('t.a')::uuid, 0, gen_random_uuid(), true,
  array['create_reservation','update_reservation','check_in','check_out','request_reservation_deletion'], 'own');
reset role;
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id = '00000000-0000-4000-8000-0000000288a2' and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations)
select c.id, current_setting('t.a')::uuid,
       array['create_reservation','update_reservation','check_in','check_out','request_reservation_deletion']
  from public.mcp_connections c where c.local_user_id = '00000000-0000-4000-8000-0000000288a2';
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);
select set_config('t.day', ((now() at time zone 'Europe/Paris')::date + 2)::text, true);
select set_config('t.am_s', to_jsonb((current_setting('t.day') || ' 08:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.am_e', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.pm_s', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.pm_e', to_jsonb((current_setting('t.day') || ' 18:00')::timestamp at time zone 'Europe/Paris')->>0, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000000288a2', 'claude-test');
select set_config('t.c', pg_temp.call('create_reservation', jsonb_build_object('seat_id', current_setting('t.seat'),
  'starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.am_e')))::text, true);
select set_config('t.r', current_setting('t.c')::jsonb->'data'->>'reservation_id', true);
select set_config('t.stale', pg_temp.call('update_reservation', jsonb_build_object('reservation_id', current_setting('t.r'),
  'starts_at', current_setting('t.pm_s'), 'ends_at', current_setting('t.pm_e'), 'expected_state', 'not-what-you-saw'))::text, true);
select set_config('t.u', pg_temp.call('update_reservation', jsonb_build_object('reservation_id', current_setting('t.r'),
  'starts_at', current_setting('t.pm_s'), 'ends_at', current_setting('t.pm_e'),
  'expected_state', current_setting('t.c')::jsonb->'data'->>'state_digest'))::text, true);
select set_config('t.d', pg_temp.call('request_reservation_deletion', jsonb_build_object('reservation_id', current_setting('t.r'),
  'reason', 'plans changed'))::text, true);
select set_config('t.ci', pg_temp.call('create_reservation', jsonb_build_object('seat_id', current_setting('t.seat'),
  'starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.am_e'), 'check_in', true))::text, true);
reset role;

select is(current_setting('t.c')::jsonb->>'status', 'completed', 'create completes');
select is(current_setting('t.c')::jsonb->'data'->>'status',
  (select status from public.reservations where id = current_setting('t.r')::uuid), 'and reads the real status back');
select ok(length(current_setting('t.c')::jsonb->'data'->>'state_digest') = 32, 'with a state digest to act on');
select is(current_setting('t.stale')::jsonb->'error'->>'code', 'stale', 'a stale expected state is refused');
select is((select starts_at from public.reservations where id = current_setting('t.r')::uuid),
  (current_setting('t.pm_s'))::timestamptz, 'the matching expected state retimes it');
select is(current_setting('t.u')::jsonb->'data'->>'starts_at',
  to_jsonb((current_setting('t.pm_s'))::timestamptz)->>0, 'and the answer reads the new start back');
-- A booking that has not started is cancelled directly; the deletion
-- request path refuses it with the business rule's own words.
select is(current_setting('t.d')::jsonb->>'status', 'conflict', 'a deletion request follows the native rule');
select ok(current_setting('t.d')::jsonb->'data'->>'reason' like 'cancel directly%',
  'and says why, leaving the booking untouched');
select isnt(current_setting('t.ci')::jsonb->>'status', 'completed',
  'check_in reaches the business rule: a booking two days ahead cannot be checked in');

select * from finish();
rollback;
