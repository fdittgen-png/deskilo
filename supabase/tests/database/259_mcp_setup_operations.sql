-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2873 (9999): an assistant runs the setup guide through the facade. Someone
-- who configures the space reads the status and previews levels; a member is
-- refused, and so is an operation the workspace does not expose. A change of
-- levels and a step marked done wait for the person's confirmation in the
-- app, then run once under the same request_id; a proposal whose features
-- moved is stale and never applied. A credential is refused before anyone
-- is asked, under any operation, and a step that takes one is never acted on
-- for an assistant; a step the server verifies cannot be marked done. The
-- step command itself still refuses a delegated token: only the confirmed
-- operation acknowledges for an assistant.
begin;
select plan(34);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000002873b1', p_op, p_args, p_request);
$$;
create function pg_temp.raw(p_key text) returns boolean language sql as $$
  select public.feature_raw(feature_flags, p_key) from public.workspaces
   where id = '00000000-0000-4000-8000-0000002873b1';
$$;

-- Two people with Google identities: the owner (a1) and a member (a2).
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000002873' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-setup.test', '', now(), now(), now()
  from unnest(array['a1', 'a2']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000002873a1', '00000000-0000-4000-8000-0000002873a2']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values ('00000000-0000-4000-8000-0000002873b1', 'MCP setup', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-0000002873a1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
        '{"mcpAccess": true, "setupGuide": true, "publicListings": false, "spaceInquiries": false}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000002873b1', '00000000-0000-4000-8000-0000002873a1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000002873b1', '00000000-0000-4000-8000-0000002873a2', false, false, 'active');

select pg_temp.act_as('00000000-0000-4000-8000-0000002873a1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000002873a2');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000002873a1', '00000000-0000-4000-8000-0000002873a2') and status = 'active';
-- list_setup_levels is not exposed by this workspace; the consent names all five.
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000002873b1', public.installation_id(), 1, true,
        array['get_setup_status', 'preview_setup_levels', 'apply_setup_levels', 'mark_setup_step'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000002873a1', '00000000-0000-4000-8000-0000002873a2') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000002873b1',
       array['get_setup_status', 'list_setup_levels', 'preview_setup_levels', 'apply_setup_levels', 'mark_setup_step'],
       'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000002873a1', '00000000-0000-4000-8000-0000002873a2');

-- ── the owner, through the assistant ───────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002873a1', 'claude-test');
select set_config('t.s1', pg_temp.call('get_setup_status', '{}')::text, true);
select set_config('t.l1', pg_temp.call('list_setup_levels', '{}')::text, true);
update public.workspace_mcp_policies set operations = operations || array['list_setup_levels']
 where workspace_id = '00000000-0000-4000-8000-0000002873b1';
select set_config('t.l2', pg_temp.call('list_setup_levels', '{}')::text, true);
select set_config('t.p1', pg_temp.call('preview_setup_levels', '{"presentation": "public"}')::text, true);
select set_config('t.p2', pg_temp.call('preview_setup_levels', '{"money": "none", "tax": "vat"}')::text, true);
select set_config('t.p3', pg_temp.call('preview_setup_levels', '{"presentation": "public", "api_key": "sk_live_x"}')::text, true);
select set_config('t.a1', pg_temp.call('apply_setup_levels', '{"presentation": "public"}',
  '00000000-0000-4000-8000-0000002873f1')::text, true);
select set_config('t.raw_before', pg_temp.raw('publicListings')::text, true);
select set_config('t.k1', pg_temp.call('mark_setup_step', '{"step": "online_payments"}',
  '00000000-0000-4000-8000-0000002873f3')::text, true);
select set_config('t.k2', pg_temp.call('mark_setup_step', '{"step": "places"}',
  '00000000-0000-4000-8000-0000002873f4')::text, true);
select set_config('t.k3', pg_temp.call('mark_setup_step', '{"step": "new_members"}',
  '00000000-0000-4000-8000-0000002873f5')::text, true);
select set_config('t.k5', pg_temp.call('apply_setup_levels', '{"presentation": "public", "password": "x"}',
  '00000000-0000-4000-8000-0000002873f6')::text, true);
select throws_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002873b1', 'new_members')$$,
  '42501', null, 'the step command refuses a delegated token: only the confirmed operation acts for an assistant');
select throws_ok($$select public.mcp_confirm_action(
    (current_setting('t.a1')::jsonb->'data'->>'confirmation_id')::uuid, true)$$,
  'P0001', 'confirmations are answered in the Deskilo app', 'an assistant cannot confirm its own proposal');

-- ── the owner, in the app ──────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002873a1');
select set_config('t.c1', public.mcp_confirm_action(
  (current_setting('t.a1')::jsonb->'data'->>'confirmation_id')::uuid, true)::text, true);
select set_config('t.c3', public.mcp_confirm_action(
  (current_setting('t.k3')::jsonb->'data'->>'confirmation_id')::uuid, true)::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000002873a1', 'claude-test');
select set_config('t.a2', pg_temp.call('apply_setup_levels', '{"presentation": "public"}',
  '00000000-0000-4000-8000-0000002873f1')::text, true);
select set_config('t.a3', pg_temp.call('apply_setup_levels', '{"presentation": "public"}',
  '00000000-0000-4000-8000-0000002873f1')::text, true);
select set_config('t.k4', pg_temp.call('mark_setup_step', '{"step": "new_members"}',
  '00000000-0000-4000-8000-0000002873f5')::text, true);
select set_config('t.st1', pg_temp.call('apply_setup_levels', '{"presentation": "basic"}',
  '00000000-0000-4000-8000-0000002873f2')::text, true);

-- The features move after the proposal: confirming it finds it changed,
-- and the assistant's retry is stale, never applied.
update public.workspaces set feature_flags = feature_flags || '{"dunning": true}'
 where id = '00000000-0000-4000-8000-0000002873b1';
select pg_temp.act_as('00000000-0000-4000-8000-0000002873a1');
select set_config('t.c2', public.mcp_confirm_action(
  (current_setting('t.st1')::jsonb->'data'->>'confirmation_id')::uuid, true)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000002873a1', 'claude-test');
select set_config('t.st2', pg_temp.call('apply_setup_levels', '{"presentation": "basic"}',
  '00000000-0000-4000-8000-0000002873f2')::text, true);

-- ── a member, through the assistant ────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002873a2', 'claude-test');
select set_config('t.m1', pg_temp.call('get_setup_status', '{}')::text, true);
select set_config('t.m2', pg_temp.call('apply_setup_levels', '{"presentation": "basic"}',
  '00000000-0000-4000-8000-0000002873f7')::text, true);
select set_config('request.jwt.claims', '', true);

-- Reads.
select is(current_setting('t.s1')::jsonb->>'status', 'completed', 'get_setup_status: a configurer reads the status');
select is((select s->>'assistant' from jsonb_array_elements(current_setting('t.s1')::jsonb->'data'->'steps') s
            where s->>'step' = 'einvoicing'), 'in_app_only',
  'a step that takes credentials is the person''s, in the app');
select is((select s->>'assistant' from jsonb_array_elements(current_setting('t.s1')::jsonb->'data'->'steps') s
            where s->>'step' = 'new_members'), 'mark_done', 'a step only the person can tell is done can be marked done');
select ok(current_setting('t.s1')::jsonb->'data' ? 'next_milestone'
          and current_setting('t.s1')::jsonb->'data' ? 'next_step',
  'with the next milestone and the next step');
select is(jsonb_array_length(current_setting('t.s1')::jsonb->'data'->'levels'),
  jsonb_array_length(public.setup_level_catalogue()->'processes'), 'and the level of every process');
select is(current_setting('t.l1')::jsonb->'error'->>'code', 'not_exposed',
  'list_setup_levels: an operation the workspace does not expose is refused');
select is(current_setting('t.l2')::jsonb->>'status', 'completed', 'and answers once the workspace exposes it');
select is(jsonb_array_length(current_setting('t.l2')::jsonb->'data'->'presets'), 3,
  'with the three quick starts and the current levels');
select ok(current_setting('t.p1')::jsonb->'data'->'switch_on' ? 'publicListings',
  'preview_setup_levels: a higher presentation switches the public page on');
select is(current_setting('t.p1')::jsonb->'data'->>'ready_to_apply', 'true', 'and can be applied');
select is(current_setting('t.p2')::jsonb->'data'->'gaps'->0->'needs'->>'level', 'invoices',
  'a level that needs a higher level of another process names the gap');
select is(current_setting('t.p2')::jsonb->'data'->>'ready_to_apply', 'false', 'and cannot be applied');
select is(current_setting('t.p3')::jsonb->'error'->>'code', 'secret_in_app_only',
  'a credential is refused even by a preview');

-- The confirmation round trip.
select is(current_setting('t.a1')::jsonb->>'status', 'requires_confirmation',
  'apply_setup_levels: the change waits for the person');
select is(current_setting('t.raw_before'), 'false', 'and nothing is written before the confirmation');
select ok((select preview->'target'->'switch_on' ? 'publicListings' from public.mcp_action_confirmations
            where request_id = '00000000-0000-4000-8000-0000002873f1'),
  'the app is shown every feature the change switches on');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(current_setting('t.a2')::jsonb->>'status', 'completed', 'the same request_id then runs it');
select is(pg_temp.raw('publicListings'), true, 'the public page is on');
select is(current_setting('t.a3')::jsonb->>'status', 'completed', 'a retry answers the same outcome');
select is((select count(*)::int from public.mcp_idempotency where request_id = '00000000-0000-4000-8000-0000002873f1'), 1,
  'and acts once');
select is(current_setting('t.c2')::jsonb->>'status', 'target_changed', 'a proposal whose features moved is not confirmed');
select is(current_setting('t.st2')::jsonb->'error'->>'code', 'confirmation_stale', 'and the retry is stale');
select is(pg_temp.raw('publicListings'), true, 'nothing of the stale proposal was applied');

-- Steps.
select is(current_setting('t.k1')::jsonb->'error'->>'code', 'secret_in_app_only',
  'mark_setup_step: a step that takes credentials is never acted on for an assistant');
select is((select count(*)::int from public.mcp_action_confirmations
            where request_id in ('00000000-0000-4000-8000-0000002873f3', '00000000-0000-4000-8000-0000002873f6')), 0,
  'and no one is asked to confirm a credential');
select is(current_setting('t.k5')::jsonb->'error'->>'code', 'secret_in_app_only', 'nor a write that carries one');
select is(current_setting('t.k2')::jsonb->>'status', 'validation_error', 'a step the server verifies cannot be marked done');
select is(current_setting('t.k4')::jsonb->'data'->>'marked', 'done', 'a confirmed manual step is marked done');
select is(current_setting('t.k4')::jsonb->'data'->>'state', 'ready', 'and reads ready');

-- A member.
select is(current_setting('t.m1')::jsonb->'error'->>'code', 'forbidden', 'a member does not read the setup status');
select is(current_setting('t.m2')::jsonb->'error'->>'code', 'forbidden', 'nor changes the levels');

select * from finish();
rollback;
