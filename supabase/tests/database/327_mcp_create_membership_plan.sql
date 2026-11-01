-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3132 (0638, decided in #3012): an assistant proposes a membership plan (a
-- subscription level, a percentage of the full subscription). The percentage
-- is shown in the app and waits for the person's confirmation; confirmed, the
-- same request_id runs create_subscription_level once, under the caller's own
-- identity. Whatever the command refuses is refused before anyone is asked
-- (a percentage outside the bounds or none, a plan already offered, the
-- money functionality off), a credential or an argument the operation does not
-- take is refused, a member without manageBilling and another workspace's
-- manager are refused, a proposal whose offer changed meanwhile is stale and a
-- declined one never runs.
begin;
select plan(32);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.call(p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003136c1',
                               'create_membership_plan', p_args, p_request);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.answer(p_answer text, p_accept boolean default true) returns jsonb language sql as $$
  select public.mcp_confirm_action((current_setting(p_answer)::jsonb->'data'->>'confirmation_id')::uuid, p_accept);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- status:code of an envelope, held in a setting.
create function pg_temp.got(p_answer text) returns text language sql as $$
  select (current_setting(p_answer)::jsonb->>'status') || ':' || coalesce(current_setting(p_answer)::jsonb->'error'->>'code', '');
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.target(p_request uuid) returns jsonb language sql as $$
  select preview->'target' from public.mcp_action_confirmations where request_id = p_request;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.asked(p_requests uuid[]) returns int language sql as $$
  select count(*)::int from public.mcp_action_confirmations where request_id = any (p_requests);
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.levels() returns jsonb language sql as $$
  select subscription_levels from public.workspaces where id = '00000000-0000-4000-8000-0000003136c1';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (d1), a plain member (d2) and the manager of another workspace
-- (d3), all with Google identities.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003136' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-membership-plan.test', '', now(), now(), now()
  from unnest(array['d1', 'd2', 'd3']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000003136d1', '00000000-0000-4000-8000-0000003136d2',
                    '00000000-0000-4000-8000-0000003136d3']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules,
                               feature_flags, role_permissions) values
 ('00000000-0000-4000-8000-0000003136c1', 'MCP plans', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003136d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
  '{"mcpAccess": true, "moneyTab": true}', '{"admin": ["manageBilling"]}'),
 ('00000000-0000-4000-8000-0000003136c2', 'MCP plans, elsewhere', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003136d3', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
  '{"mcpAccess": true, "moneyTab": true}', '{"admin": ["manageBilling"]}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003136c1', '00000000-0000-4000-8000-0000003136d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003136c1', '00000000-0000-4000-8000-0000003136d2', false, false, 'active'),
 ('00000000-0000-4000-8000-0000003136c2', '00000000-0000-4000-8000-0000003136d3', false, true, 'active');
update public.workspaces
   set subscription_levels = '{"enabled_presets": [50, 100], "extra_levels": [], "allow_custom": true}'
 where id = '00000000-0000-4000-8000-0000003136c1';

select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d2');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d3');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003136d1', '00000000-0000-4000-8000-0000003136d2',
                         '00000000-0000-4000-8000-0000003136d3') and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000003136c1', public.installation_id(), 1, true,
        array['create_membership_plan'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003136d1', '00000000-0000-4000-8000-0000003136d2',
                         '00000000-0000-4000-8000-0000003136d3') and status = 'active';
-- Every connection is consented to this workspace, so each refusal below
-- comes from the right or the membership and not from a missing consent.
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000003136c1', array['create_membership_plan'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000003136d1', '00000000-0000-4000-8000-0000003136d2',
                         '00000000-0000-4000-8000-0000003136d3');

-- ── the owner, through the assistant ───────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1', 'claude-test');
select set_config('t.r1', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136e1')::text, true);
select set_config('t.before', pg_temp.levels()::text, true);
select set_config('t.r2', pg_temp.call('{"percent": 0}', '00000000-0000-4000-8000-0000003136e2')::text, true);
select set_config('t.r3', pg_temp.call('{"percent": 101}', '00000000-0000-4000-8000-0000003136e3')::text, true);
select set_config('t.r4', pg_temp.call('{}', '00000000-0000-4000-8000-0000003136e4')::text, true);
select set_config('t.r5', pg_temp.call('{"percent": 50}', '00000000-0000-4000-8000-0000003136e5')::text, true);
select set_config('t.r6', pg_temp.call('{"percent": "abc"}', '00000000-0000-4000-8000-0000003136e6')::text, true);
select set_config('t.r7', pg_temp.call('{"percent": 30, "label": "gold"}', '00000000-0000-4000-8000-0000003136e7')::text, true);
select set_config('t.r8', pg_temp.call('{"percent": 30, "api_key": "sk_live_x"}', '00000000-0000-4000-8000-0000003136e8')::text, true);

-- The money functionality off: the command refuses, so nobody is asked.
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"moneyTab": false}'::jsonb
 where id = '00000000-0000-4000-8000-0000003136c1';
select set_config('t.r9', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136e9')::text, true);
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"moneyTab": true}'::jsonb
 where id = '00000000-0000-4000-8000-0000003136c1';

-- ── a member, and another workspace's manager ──────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d2', 'claude-test');
select set_config('t.ra', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136ea')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d3', 'claude-test');
select set_config('t.rb', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136eb')::text, true);
select set_config('request.jwt.claims', '', true);

-- ── the owner confirms in the app, the assistant repeats the call ──────
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1');
select set_config('t.c1', pg_temp.answer('t.r1')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1', 'claude-test');
select set_config('t.r10', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136e1')::text, true);
select set_config('t.after', pg_temp.levels()::text, true);
select set_config('t.r11', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136e1')::text, true);
select set_config('t.stored', pg_temp.levels()::text, true);
select set_config('t.rc', pg_temp.call('{"percent": 30}', '00000000-0000-4000-8000-0000003136ec')::text, true);

-- A proposal whose offer changed meanwhile is stale.
select set_config('t.rd', pg_temp.call('{"percent": 40}', '00000000-0000-4000-8000-0000003136ed')::text, true);
update public.workspaces set subscription_levels = subscription_levels || '{"extra_levels": [30, 60]}'::jsonb
 where id = '00000000-0000-4000-8000-0000003136c1';
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1');
select set_config('t.cd', pg_temp.answer('t.rd')::text, true);

-- A declined proposal never runs.
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1', 'claude-test');
select set_config('t.re', pg_temp.call('{"percent": 45}', '00000000-0000-4000-8000-0000003136ee')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1');
select set_config('t.ce', pg_temp.answer('t.re', false)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000003136d1', 'claude-test');
select set_config('t.re2', pg_temp.call('{"percent": 45}', '00000000-0000-4000-8000-0000003136ee')::text, true);
select set_config('request.jwt.claims', '', true);

select is(jsonb_build_object('permission', c->'permission', 'features', c->'features', 'mutation', c->>'mutation',
                             'confirmation', c->>'confirmation'),
  '{"permission": "manageBilling", "features": ["mcpAccess", "moneyTab"], "mutation": "write", "confirmation": "native"}'::jsonb,
  'the catalogue asks manageBilling and the money functionality, writes, and confirms in the app')
  from (select public.mcp_operation_catalogue()->'operations'->'create_membership_plan' c) q;
select is(pg_temp.got('t.r1'), 'requires_confirmation:', 'the plan waits for the person');
select is(current_setting('t.before')::jsonb, '{"enabled_presets": [50, 100], "extra_levels": [], "allow_custom": true}'::jsonb,
  'and nothing is written before it');
select is(pg_temp.target('00000000-0000-4000-8000-0000003136e1'),
  '{"kind": "membership_plan", "percent": 30, "changes": [{"field": "subscription_level", "from": null, "to": 30}]}'::jsonb,
  'the app is shown the percentage (and, beside it, the workspace)');
select is(pg_temp.got('t.r2'), 'validation_error:invalid_arguments', 'zero is below the bounds');
select is(pg_temp.got('t.r3'), 'validation_error:invalid_arguments', '101 is above the bounds');
select is(pg_temp.got('t.r4'), 'validation_error:invalid_arguments', 'no percentage is refused');
select is(pg_temp.got('t.r5'), 'validation_error:invalid_arguments', 'a plan already offered is refused');
select is(pg_temp.got('t.r6'), 'validation_error:invalid_arguments', 'a percentage that is not a number is refused');
select is(pg_temp.got('t.r7'), 'validation_error:invalid_arguments', 'an argument the operation does not take is refused');
select is(pg_temp.got('t.r8'), 'denied:secret_in_app_only', 'a credential is refused');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003136e2', '00000000-0000-4000-8000-0000003136e3',
  '00000000-0000-4000-8000-0000003136e4', '00000000-0000-4000-8000-0000003136e5', '00000000-0000-4000-8000-0000003136e6',
  '00000000-0000-4000-8000-0000003136e7', '00000000-0000-4000-8000-0000003136e8']::uuid[]), 0,
  'and no one is asked to confirm what the command would refuse');
select is(pg_temp.got('t.r9'), 'denied:not_exposed', 'a space with the money functionality off is refused');
select is(pg_temp.got('t.ra'), 'denied:forbidden', 'a member without manageBilling is refused');
select is(pg_temp.got('t.rb'), 'denied:not_a_member', 'another workspace''s manager is refused');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003136e9', '00000000-0000-4000-8000-0000003136ea',
  '00000000-0000-4000-8000-0000003136eb']::uuid[]), 0, 'and none of them is asked to confirm');
select throws_ok($$select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003136c1',
  'create_membership_plan', '{"percent": 30}', '00000000-0000-4000-8000-0000003136ef')$$,
  'P0001', null, 'nobody signed in is refused');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(pg_temp.got('t.r10'), 'completed:', 'the same request_id then runs it');
select is(current_setting('t.r10')::jsonb->'data', '{"created": true, "percent": 30}'::jsonb,
  'the answer says the plan was created, at which percentage, and nothing else');
select is(current_setting('t.after')::jsonb, '{"enabled_presets": [50, 100], "extra_levels": [30], "allow_custom": true}'::jsonb,
  'the level joined the extras, through the command');
select is(pg_temp.got('t.r11'), 'completed:', 'a repeated call answers the same outcome');
select is(current_setting('t.stored')::jsonb, current_setting('t.after')::jsonb, 'and never adds the plan twice');
select is(pg_temp.got('t.rc'), 'validation_error:invalid_arguments', 'the plan now offered is refused for a new request');
select is(pg_temp.asked(array['00000000-0000-4000-8000-0000003136ec']::uuid[]), 0, 'and nobody is asked about it');
select is(pg_temp.got('t.rd'), 'requires_confirmation:', 'another plan is proposed');
select is(current_setting('t.cd')::jsonb->>'status', 'target_changed', 'and is stale once the offer changed meanwhile');
select is(pg_temp.got('t.re'), 'requires_confirmation:', 'a further plan is proposed');
select is(current_setting('t.ce')::jsonb->>'status', 'declined', 'the person declines it in the app');
select is(pg_temp.got('t.re2'), 'denied:confirmation_declined', 'and the repeated call is refused as declined');
select is(pg_temp.levels(), '{"enabled_presets": [50, 100], "extra_levels": [30, 60], "allow_custom": true}'::jsonb,
  'neither the stale nor the declined plan was written');
select ok(not has_function_privilege('authenticated', 'public.mcp_op_create_membership_plan(public.mcp_call_context,jsonb)', 'execute')
          and not has_function_privilege('authenticated', 'public.mcp_target_create_membership_plan(uuid,jsonb)', 'execute'),
  'the handler and the target are reachable only through the dispatcher');

select * from finish();
rollback;
