-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3132 (0623, decided in #3012): an assistant proposes to invite a member.
-- The invitee is shown in the app and waits for the person's confirmation;
-- confirmed, the same request_id runs the invite step's own command once; the
-- answer names the invitation and its status and NEVER the join code; an
-- invitation naming nobody, one already open for the same person, and any
-- credential are refused before anyone is asked; a member is refused.
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
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003133c1', p_op, p_args, p_request);
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

create function pg_temp.invites() returns jsonb language sql as $$
  select coalesce(jsonb_agg(jsonb_build_object('first', invited_first_name, 'last', invited_last_name, 'admin', is_admin) order by invited_first_name), '[]'::jsonb)
    from public.invitations where workspace_id = '00000000-0000-4000-8000-0000003133c1';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (d1) and a member (d2), both with Google identities.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003133' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-invitations.test', '', now(), now(), now()
  from unnest(array['d1', 'd2']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000003133d1', '00000000-0000-4000-8000-0000003133d2']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values ('00000000-0000-4000-8000-0000003133c1', 'MCP invitations', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-0000003133d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
        '{"mcpAccess": true, "setupGuide": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003133c1', '00000000-0000-4000-8000-0000003133d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003133c1', '00000000-0000-4000-8000-0000003133d2', false, false, 'active');

select pg_temp.act_as('00000000-0000-4000-8000-0000003133d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003133d2');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003133d1', '00000000-0000-4000-8000-0000003133d2') and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000003133c1', public.installation_id(), 1, true,
        array['create_invitations'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003133d1', '00000000-0000-4000-8000-0000003133d2') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000003133c1',
       array['create_invitations'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000003133d1', '00000000-0000-4000-8000-0000003133d2');



-- ── the owner, through the assistant ───────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003133d1', 'claude-test');
select set_config('t.i1', pg_temp.call('create_invitations', '{"first_name": "Camille", "last_name": "Martin"}',
  '00000000-0000-4000-8000-0000003133e1')::text, true);
select set_config('t.before', pg_temp.invites()::text, true);
select set_config('t.i2', pg_temp.call('create_invitations', '{}',
  '00000000-0000-4000-8000-0000003133e2')::text, true);
select set_config('t.i3', pg_temp.call('create_invitations', '{"first_name": "Zoé", "api_key": "sk_live_x"}',
  '00000000-0000-4000-8000-0000003133e3')::text, true);

-- ── the owner, in the app ──────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003133d1');
select set_config('t.c1', pg_temp.confirm('t.i1')::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000003133d1', 'claude-test');
select set_config('t.i4', pg_temp.call('create_invitations', '{"first_name": "Camille", "last_name": "Martin"}',
  '00000000-0000-4000-8000-0000003133e1')::text, true);
select set_config('t.i5', pg_temp.call('create_invitations', '{"first_name": "camille", "last_name": "MARTIN"}',
  '00000000-0000-4000-8000-0000003133e5')::text, true);

-- ── a member, through the assistant ────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003133d2', 'claude-test');
select set_config('t.m1', pg_temp.call('create_invitations', '{"first_name": "Nina"}',
  '00000000-0000-4000-8000-0000003133ec')::text, true);
select set_config('request.jwt.claims', '', true);

select is(current_setting('t.i1')::jsonb->>'status', 'requires_confirmation', 'the invitation waits for the person');
select is(current_setting('t.before')::jsonb, '[]'::jsonb, 'and nothing is written before it');
select is(pg_temp.target('00000000-0000-4000-8000-0000003133e1')->'changes',
  '[{"field": "invitee", "from": null, "to": "Camille Martin"}]'::jsonb,
  'the app is shown who is invited');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(current_setting('t.i4')::jsonb->>'status', 'completed', 'the same request_id then runs it');
select is(pg_temp.invites(), '[{"first": "Camille", "last": "Martin", "admin": false}]'::jsonb,
  'one member invitation exists, never an admin');
select ok(current_setting('t.i4')::jsonb->'data' ? 'invitation_id'
          and current_setting('t.i4')::jsonb->'data'->>'status' = 'open'
          and position((select code from public.invitations where workspace_id = '00000000-0000-4000-8000-0000003133c1' limit 1)
                       in current_setting('t.i4')) = 0,
  'the answer names the invitation and its status and does not carry the join code');
select is(current_setting('t.i2')::jsonb->>'status', 'validation_error', 'an invitation that names nobody is refused');
select is(current_setting('t.i3')::jsonb->'error'->>'code', 'secret_in_app_only', 'a credential is refused');
select is(current_setting('t.i5')::jsonb->>'status', 'validation_error', 'the same person again, in other letters, is already invited');
select is((select count(*)::int from public.mcp_action_confirmations where request_id in
            ('00000000-0000-4000-8000-0000003133e2', '00000000-0000-4000-8000-0000003133e3',
             '00000000-0000-4000-8000-0000003133e5')), 0,
  'and no one is asked to confirm what would be refused');
select is(current_setting('t.m1')::jsonb->'error'->>'code', 'forbidden', 'a member is refused');
select is((select count(*)::int from public.mcp_action_confirmations where request_id = '00000000-0000-4000-8000-0000003133ec'), 0,
  'and is never asked to confirm');

select * from finish();
rollback;
