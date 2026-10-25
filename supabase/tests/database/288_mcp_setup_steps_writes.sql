-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2873 (9999): an assistant explains the setup steps and sets up the hours,
-- the closure days and a number series through the step pages' own
-- commands. Someone who configures the space reads every step with its
-- state, what it waits for and what it unlocks; a member is refused, and
-- so is an operation the workspace does not expose. Each write waits for
-- the person's confirmation in the app, which is shown every change from
-- -> to, then runs once under the same request_id; a proposal whose values
-- moved meanwhile is stale and applies nothing. What the command would
-- refuse (an impossible working day, a restart more often than the printed
-- date, days already closed) and any credential are refused before anyone
-- is asked.
begin;
select plan(31);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000002873c1', p_op, p_args, p_request);
$$;
create function pg_temp.confirm(p_answer text) returns jsonb language sql as $$
  select public.mcp_confirm_action((current_setting(p_answer)::jsonb->'data'->>'confirmation_id')::uuid, true);
$$;
create function pg_temp.rules() returns jsonb language sql as $$
  select booking_rules from public.workspaces where id = '00000000-0000-4000-8000-0000002873c1';
$$;
create function pg_temp.target(p_request uuid) returns jsonb language sql as $$
  select preview->'target' from public.mcp_action_confirmations where request_id = p_request;
$$;

-- The owner (d1) and a member (d2), both with Google identities.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000002873' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-setup-writes.test', '', now(), now(), now()
  from unnest(array['d1', 'd2']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000002873d1', '00000000-0000-4000-8000-0000002873d2']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags)
values ('00000000-0000-4000-8000-0000002873c1', 'MCP setup writes', 'FR', 'EUR', 'Europe/Paris',
        '00000000-0000-4000-8000-0000002873d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
        '{"mcpAccess": true, "setupGuide": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000002873c1', '00000000-0000-4000-8000-0000002873d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000002873c1', '00000000-0000-4000-8000-0000002873d2', false, false, 'active');

select pg_temp.act_as('00000000-0000-4000-8000-0000002873d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000002873d2');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000002873d1', '00000000-0000-4000-8000-0000002873d2') and status = 'active';
-- set_number_sequence is not exposed yet; the consent names all four.
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000002873c1', public.installation_id(), 1, true,
        array['explain_setup_step', 'set_opening_hours', 'add_closure_days'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000002873d1', '00000000-0000-4000-8000-0000002873d2') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000002873c1',
       array['explain_setup_step', 'set_opening_hours', 'add_closure_days', 'set_number_sequence'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000002873d1', '00000000-0000-4000-8000-0000002873d2');

-- ── the owner, through the assistant ───────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002873d1', 'claude-test');
select set_config('t.x1', pg_temp.call('explain_setup_step', '{}')::text, true);
select set_config('t.x2', pg_temp.call('explain_setup_step', '{"step": "hours"}')::text, true);
select set_config('t.x3', pg_temp.call('explain_setup_step', '{"step": "nope"}')::text, true);
select set_config('t.n0', pg_temp.call('set_number_sequence', '{"journal": "invoice", "prefix": "F-"}',
  '00000000-0000-4000-8000-0000002873e9')::text, true);
select set_config('t.h1', pg_temp.call('set_opening_hours', '{"open_weekdays": "1,2,3,4,5,6", "work_start_minutes": 540}',
  '00000000-0000-4000-8000-0000002873e1')::text, true);
select set_config('t.rules_before', pg_temp.rules()::text, true);
select set_config('t.h2', pg_temp.call('set_opening_hours', '{"work_start_minutes": 800}',
  '00000000-0000-4000-8000-0000002873e2')::text, true);
select set_config('t.h3', pg_temp.call('set_opening_hours', '{"open_weekdays": "0,8"}',
  '00000000-0000-4000-8000-0000002873e3')::text, true);
select set_config('t.h4', pg_temp.call('set_opening_hours', '{"open_weekdays": "1", "api_key": "sk_live_x"}',
  '00000000-0000-4000-8000-0000002873e4')::text, true);
select set_config('t.d1', pg_temp.call('add_closure_days', '{"days": "2026-12-24,2026-12-31", "reason": "Christmas"}',
  '00000000-0000-4000-8000-0000002873e5')::text, true);
select set_config('t.d2', pg_temp.call('add_closure_days', '{"days": "2026-13-01"}',
  '00000000-0000-4000-8000-0000002873e6')::text, true);

-- ── the owner, in the app ──────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002873d1');
select set_config('t.c1', pg_temp.confirm('t.h1')::text, true);
-- Someone closes the 31st in the app before the proposal is confirmed.
insert into public.closure_days (workspace_id, day, reason)
values ('00000000-0000-4000-8000-0000002873c1', '2026-12-31', 'Inventory');
select set_config('t.c2', pg_temp.confirm('t.d1')::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000002873d1', 'claude-test');
select set_config('t.h5', pg_temp.call('set_opening_hours', '{"open_weekdays": "1,2,3,4,5,6", "work_start_minutes": 540}',
  '00000000-0000-4000-8000-0000002873e1')::text, true);
select set_config('t.h6', pg_temp.call('set_opening_hours', '{"open_weekdays": "1,2,3,4,5,6", "work_start_minutes": 540}',
  '00000000-0000-4000-8000-0000002873e1')::text, true);
select set_config('t.d3', pg_temp.call('add_closure_days', '{"days": "2026-12-24,2026-12-31", "reason": "Christmas"}',
  '00000000-0000-4000-8000-0000002873e5')::text, true);
select set_config('t.d4', pg_temp.call('add_closure_days', '{"days": "2026-12-24,2026-12-31", "reason": "Christmas"}',
  '00000000-0000-4000-8000-0000002873e7')::text, true);
select set_config('t.d5', pg_temp.call('add_closure_days', '{"days": "2026-12-31"}',
  '00000000-0000-4000-8000-0000002873e8')::text, true);
update public.workspace_mcp_policies set operations = operations || array['set_number_sequence']
 where workspace_id = '00000000-0000-4000-8000-0000002873c1';
select set_config('t.n1', pg_temp.call('set_number_sequence', '{"journal": "invoice", "prefix": "F-"}',
  '00000000-0000-4000-8000-0000002873ea')::text, true);
select set_config('t.n2', pg_temp.call('set_number_sequence', '{"journal": "member", "reset": "yearly"}',
  '00000000-0000-4000-8000-0000002873eb')::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000002873d1');
select set_config('t.c3', pg_temp.confirm('t.d4')::text, true);
select set_config('t.c4', pg_temp.confirm('t.n1')::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000002873d1', 'claude-test');
select set_config('t.d6', pg_temp.call('add_closure_days', '{"days": "2026-12-24,2026-12-31", "reason": "Christmas"}',
  '00000000-0000-4000-8000-0000002873e7')::text, true);
select set_config('t.n3', pg_temp.call('set_number_sequence', '{"journal": "invoice", "prefix": "F-"}',
  '00000000-0000-4000-8000-0000002873ea')::text, true);

-- ── a member, through the assistant ────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002873d2', 'claude-test');
select set_config('t.m1', pg_temp.call('explain_setup_step', '{}')::text, true);
select set_config('t.m2', pg_temp.call('set_opening_hours', '{"work_start_minutes": 600}',
  '00000000-0000-4000-8000-0000002873ec')::text, true);
select set_config('request.jwt.claims', '', true);

-- explain_setup_step.
select is(jsonb_array_length(current_setting('t.x1')::jsonb->'data'->'steps'),
  jsonb_array_length(public.setup_step_catalogue()), 'explain_setup_step: every step of the guide, in its order');
select is((select s->>'takes_credentials' from jsonb_array_elements(current_setting('t.x1')::jsonb->'data'->'steps') s
            where s->>'step' = 'online_payments'), 'true', 'a step that takes credentials says so');
select is((select s->>'assistant' from jsonb_array_elements(current_setting('t.x1')::jsonb->'data'->'steps') s
            where s->>'step' = 'online_payments'), 'in_app_only', 'with the same verdict as the setup status');
select is(current_setting('t.x2')::jsonb->'data'->'steps'->0->>'step', 'hours', 'one step when asked for one');
select is(current_setting('t.x2')::jsonb->'data'->'steps'->0->'depends_on', '["basics"]'::jsonb, 'with what it waits for');
select ok(current_setting('t.x2')::jsonb->'data'->'steps'->0 ? 'unlocks'
          and current_setting('t.x2')::jsonb->'data'->'steps'->0->>'route' = '/setup/step/hours',
  'what it unlocks and the screen that sets it up');
select is(current_setting('t.x3')::jsonb->>'status', 'validation_error', 'an unknown step is invalid');

-- set_opening_hours.
select is(current_setting('t.h1')::jsonb->>'status', 'requires_confirmation', 'set_opening_hours: the change waits for the person');
select is(current_setting('t.rules_before')::jsonb->'open_weekdays', '[1,2,3,4,5]'::jsonb, 'and nothing is written before it');
select is(pg_temp.target('00000000-0000-4000-8000-0000002873e1')->'changes',
  '[{"field": "open_weekdays", "from": [1,2,3,4,5], "to": [1,2,3,4,5,6]}, {"field": "work_start_minutes", "from": 480, "to": 540}]'::jsonb,
  'the app is shown every change, from and to');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(current_setting('t.h5')::jsonb->>'status', 'completed', 'the same request_id then runs it');
select is(pg_temp.rules()->'open_weekdays', '[1,2,3,4,5,6]'::jsonb, 'Saturday is open');
select is(pg_temp.rules()->>'work_start_minutes', '540', 'and the day starts at nine');
select is((select count(*)::int from public.mcp_idempotency where request_id = '00000000-0000-4000-8000-0000002873e1'), 1,
  'a retry answers the same outcome and acts once');
select is(current_setting('t.h2')::jsonb->>'status', 'validation_error', 'a day that starts after its half-day boundary is refused');
select is(current_setting('t.h3')::jsonb->>'status', 'validation_error', 'and a weekday that does not exist');
select is(current_setting('t.h4')::jsonb->'error'->>'code', 'secret_in_app_only', 'a credential is refused');
select is((select count(*)::int from public.mcp_action_confirmations where request_id in
            ('00000000-0000-4000-8000-0000002873e2', '00000000-0000-4000-8000-0000002873e3',
             '00000000-0000-4000-8000-0000002873e4', '00000000-0000-4000-8000-0000002873e6')), 0,
  'and no one is asked to confirm what would be refused');

-- add_closure_days.
select is(current_setting('t.c2')::jsonb->>'status', 'target_changed', 'add_closure_days: a proposal whose days moved is not confirmed');
select is(current_setting('t.d3')::jsonb->'error'->>'code', 'confirmation_stale', 'and the retry is stale');
select is(pg_temp.target('00000000-0000-4000-8000-0000002873e7')->'days', '["2026-12-24"]'::jsonb,
  'a new proposal names only the day not closed yet');
select is(current_setting('t.d6')::jsonb->>'status', 'completed', 'and runs once confirmed');
select is((select string_agg(day::text || ' ' || reason, ', ' order by day) from public.closure_days
            where workspace_id = '00000000-0000-4000-8000-0000002873c1'), '2026-12-24 Christmas, 2026-12-31 Inventory',
  'the 24th is closed for Christmas; the 31st keeps its own reason');
select is(current_setting('t.d5')::jsonb->>'status', 'validation_error', 'days already closed change nothing');
select is(current_setting('t.d2')::jsonb->>'status', 'validation_error', 'and a date that does not exist is refused');

-- set_number_sequence.
select is(current_setting('t.n0')::jsonb->'error'->>'code', 'not_exposed', 'set_number_sequence: refused until the workspace exposes it');
select is(pg_temp.target('00000000-0000-4000-8000-0000002873ea')->'changes',
  '[{"field": "prefix", "from": "INV-", "to": "F-"}]'::jsonb, 'the app is shown the new prefix');
select ok(current_setting('t.c4')::jsonb->>'status' = 'acknowledged' and current_setting('t.n3')::jsonb->>'status' = 'completed'
          and (select prefix from public.number_sequences
                where workspace_id = '00000000-0000-4000-8000-0000002873c1' and journal = 'invoice') = 'F-'
          and current_setting('t.n3')::jsonb->'data'->>'preview' like 'F-%',
  'once confirmed the series prints F- through the editor''s own command');
select is(current_setting('t.n2')::jsonb->>'status', 'validation_error',
  'a series that restarts more often than it prints its date is refused before anyone is asked');

-- A member.
select ok(current_setting('t.m1')::jsonb->'error'->>'code' = 'forbidden'
          and current_setting('t.m2')::jsonb->'error'->>'code' = 'forbidden',
  'a member neither reads the steps nor changes the hours');

select * from finish();
rollback;
