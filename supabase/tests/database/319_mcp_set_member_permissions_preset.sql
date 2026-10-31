-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3132 (0625, decided in #3012): an assistant proposes the members' everyday
-- rights as a request. The list of permissions is shown in the app and waits
-- for the person's confirmation; confirmed, the same request_id runs the
-- member-rights step's own command once; when the workspace requires
-- validation of role changes the answer is pending_validation, the requests
-- wait for the validators and nothing is granted; an unknown preset, a
-- preset the members role already holds and any credential are refused
-- before anyone is asked; a member is refused.
begin;
select plan(13);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003134c1', p_op, p_args, p_request);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.confirm(p_answer text) returns jsonb language sql as $$
  select public.mcp_confirm_action((current_setting(p_answer)::jsonb->'data'->>'confirmation_id')::uuid, true);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.target(p_request uuid) returns jsonb language sql as $$
  select preview->'target' from public.mcp_action_confirmations where request_id = p_request;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.holds() returns jsonb language sql as $$
  select jsonb_object_agg(p, public.role_holds('00000000-0000-4000-8000-0000003134c1', 'member', p))
    from unnest(array['makeReservations', 'viewCalendar', 'useMessages', 'viewMyMoney']) p;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (d1) and a member (d2), both with Google identities.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003134' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-member-rights.test', '', now(), now(), now()
  from unnest(array['d1', 'd2']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000003134d1', '00000000-0000-4000-8000-0000003134d2']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values ('00000000-0000-4000-8000-0000003134c1', 'MCP member rights', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-0000003134d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
        '{"mcpAccess": true, "setupGuide": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003134c1', '00000000-0000-4000-8000-0000003134d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003134c1', '00000000-0000-4000-8000-0000003134d2', false, false, 'active');

select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d2');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003134d1', '00000000-0000-4000-8000-0000003134d2') and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000003134c1', public.installation_id(), 1, true,
        array['set_member_permissions_preset'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003134d1', '00000000-0000-4000-8000-0000003134d2') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000003134c1',
       array['set_member_permissions_preset'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000003134d1', '00000000-0000-4000-8000-0000003134d2');




-- ── the owner, through the assistant ───────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1', 'claude-test');
select set_config('t.r1', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book"}',
  '00000000-0000-4000-8000-0000003134e1')::text, true);
select set_config('t.before', pg_temp.holds()::text, true);
select set_config('t.r2', pg_temp.call('set_member_permissions_preset', '{"preset": "everything"}',
  '00000000-0000-4000-8000-0000003134e2')::text, true);
select set_config('t.r3', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book", "api_key": "sk_live_x"}',
  '00000000-0000-4000-8000-0000003134e3')::text, true);

-- ── the owner, in the app ──────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1');
select set_config('t.c1', pg_temp.confirm('t.r1')::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1', 'claude-test');
select set_config('t.r4', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book"}',
  '00000000-0000-4000-8000-0000003134e1')::text, true);
select set_config('t.after', pg_temp.holds()::text, true);
select set_config('t.r5', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book"}',
  '00000000-0000-4000-8000-0000003134e5')::text, true);

-- ── the same, in a workspace that validates role changes ───────────────
reset role;
update public.workspaces set role_permissions = '{}'::jsonb where id = '00000000-0000-4000-8000-0000003134c1';
insert into public.validation_policies (workspace_id, event_type, min_amount_cents)
values ('00000000-0000-4000-8000-0000003134c1', 'matrix_change', 0);
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1', 'claude-test');
select set_config('t.p1', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book"}',
  '00000000-0000-4000-8000-0000003134e6')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1');
select set_config('t.pc', pg_temp.confirm('t.p1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d1', 'claude-test');
select set_config('t.p2', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book"}',
  '00000000-0000-4000-8000-0000003134e6')::text, true);
select set_config('t.pending_holds', pg_temp.holds()::text, true);

-- ── a member, through the assistant ────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003134d2', 'claude-test');
select set_config('t.m1', pg_temp.call('set_member_permissions_preset', '{"preset": "members_can_book"}',
  '00000000-0000-4000-8000-0000003134ec')::text, true);
select set_config('request.jwt.claims', '', true);

select is(current_setting('t.r1')::jsonb->>'status', 'requires_confirmation', 'the preset waits for the person');
select is(current_setting('t.before')::jsonb,
  '{"makeReservations": false, "viewCalendar": false, "useMessages": false, "viewMyMoney": false}'::jsonb,
  'and nothing is granted before it');
select is(pg_temp.target('00000000-0000-4000-8000-0000003134e1')->'changes',
  '[{"field": "makeReservations", "from": false, "to": true}, {"field": "viewCalendar", "from": false, "to": true},
    {"field": "useMessages", "from": false, "to": true}, {"field": "viewMyMoney", "from": false, "to": true}]'::jsonb,
  'the app is shown each permission, from no to yes');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(current_setting('t.r4')::jsonb->>'status', 'completed', 'the same request_id then runs it');
select is(current_setting('t.after')::jsonb,
  '{"makeReservations": true, "viewCalendar": true, "useMessages": true, "viewMyMoney": true}'::jsonb,
  'the members role holds the everyday set');
select is(current_setting('t.r2')::jsonb->>'status', 'validation_error', 'an unknown preset is refused');
select is(current_setting('t.r3')::jsonb->'error'->>'code', 'secret_in_app_only', 'a credential is refused');
select is(current_setting('t.r5')::jsonb->>'status', 'validation_error', 'a preset the members role already holds is refused');
select is(current_setting('t.p2')::jsonb->>'status', 'pending_validation',
  'where role changes are validated the answer is pending_validation');
select is(current_setting('t.pending_holds')::jsonb,
  '{"makeReservations": false, "viewCalendar": false, "useMessages": false, "viewMyMoney": false}'::jsonb,
  'and nothing was granted: the requests wait for the validators');
select is((select count(*)::int from public.events where workspace_id = '00000000-0000-4000-8000-0000003134c1'
            and type = 'matrix_change' and status = 'pending'), 4, 'four requests wait, never approved by the assistant');
select is(current_setting('t.m1')::jsonb->'error'->>'code', 'forbidden', 'a member is refused');

select * from finish();
rollback;
