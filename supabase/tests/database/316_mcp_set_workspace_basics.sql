-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3132 (0619, decided in #3012): an assistant proposes the workspace's time
-- zone, default language and address. The change waits for the person's
-- confirmation in the app, which is shown every change from -> to, then runs
-- once under the same request_id through save_workspace_settings; a value
-- that is not an IANA zone or one of the five languages and any credential
-- are refused before anyone is asked; a member is refused; country and
-- currency are not offered at all.
begin;
select plan(14);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'client_id', p_client))::text, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.call(p_op text, p_args jsonb, p_request uuid default null) returns jsonb language sql as $$
  select public.mcp_execute_v1(public.installation_id(), '00000000-0000-4000-8000-0000003132c1', p_op, p_args, p_request);
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

create function pg_temp.ws() returns jsonb language sql as $$
  select jsonb_build_object('timezone', timezone, 'default_locale', default_locale, 'address', address)
    from public.workspaces where id = '00000000-0000-4000-8000-0000003132c1';
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (d1) and a member (d2), both with Google identities.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003132' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@mcp-workspace-basics.test', '', now(), now(), now()
  from unnest(array['d1', 'd2']) s;
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u, u, jsonb_build_object('sub', 'google-' || u), 'google', now(), now()
  from unnest(array['00000000-0000-4000-8000-0000003132d1', '00000000-0000-4000-8000-0000003132d2']::uuid[]) u;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;

insert into public.workspaces (id, name, country_code, currency_code, timezone, default_locale, address, created_by, environment, booking_rules, feature_flags)
values ('00000000-0000-4000-8000-0000003132c1', 'MCP workspace basics', 'FR', 'EUR', 'Europe/Paris', 'fr', 'Old street',
        '00000000-0000-4000-8000-0000003132d1', 'dev', '{"open_weekdays":[1,2,3,4,5]}',
        '{"mcpAccess": true, "setupGuide": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003132c1', '00000000-0000-4000-8000-0000003132d1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003132c1', '00000000-0000-4000-8000-0000003132d2', false, false, 'active');

select pg_temp.act_as('00000000-0000-4000-8000-0000003132d1');
select public.finalize_identity_binding();
select pg_temp.act_as('00000000-0000-4000-8000-0000003132d2');
select public.finalize_identity_binding();
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003132d1', '00000000-0000-4000-8000-0000003132d2') and status = 'active';
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values ('00000000-0000-4000-8000-0000003132c1', public.installation_id(), 1, true,
        array['set_workspace_basics'], 'workspace');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
 where local_user_id in ('00000000-0000-4000-8000-0000003132d1', '00000000-0000-4000-8000-0000003132d2') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, '00000000-0000-4000-8000-0000003132c1',
       array['set_workspace_basics'], 'workspace'
  from public.mcp_connections
 where local_user_id in ('00000000-0000-4000-8000-0000003132d1', '00000000-0000-4000-8000-0000003132d2');


-- ── the owner, through the assistant ───────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003132d1', 'claude-test');
select set_config('t.b1', pg_temp.call('set_workspace_basics', '{"timezone": "Europe/Berlin", "default_locale": "de"}',
  '00000000-0000-4000-8000-0000003132e1')::text, true);
select set_config('t.before', pg_temp.ws()::text, true);
select set_config('t.b2', pg_temp.call('set_workspace_basics', '{"timezone": "Mars/Olympus"}',
  '00000000-0000-4000-8000-0000003132e2')::text, true);
select set_config('t.b3', pg_temp.call('set_workspace_basics', '{"default_locale": "xx"}',
  '00000000-0000-4000-8000-0000003132e3')::text, true);
select set_config('t.b4', pg_temp.call('set_workspace_basics', '{"address": "1 rue X", "api_key": "sk_live_x"}',
  '00000000-0000-4000-8000-0000003132e4')::text, true);
select set_config('t.b5', pg_temp.call('set_workspace_basics', '{"currency_code": "USD"}',
  '00000000-0000-4000-8000-0000003132e5')::text, true);
select set_config('t.b6', pg_temp.call('set_workspace_basics', '{"timezone": "Europe/Paris"}',
  '00000000-0000-4000-8000-0000003132e6')::text, true);

-- ── the owner, in the app ──────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003132d1');
select set_config('t.c1', pg_temp.confirm('t.b1')::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-0000003132d1', 'claude-test');
select set_config('t.b7', pg_temp.call('set_workspace_basics', '{"timezone": "Europe/Berlin", "default_locale": "de"}',
  '00000000-0000-4000-8000-0000003132e1')::text, true);

-- ── a member, through the assistant ────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003132d2', 'claude-test');
select set_config('t.m1', pg_temp.call('set_workspace_basics', '{"timezone": "Europe/Berlin"}',
  '00000000-0000-4000-8000-0000003132ec')::text, true);
select set_config('request.jwt.claims', '', true);

select is(current_setting('t.b1')::jsonb->>'status', 'requires_confirmation', 'the change waits for the person');
select is(current_setting('t.before')::jsonb, '{"timezone": "Europe/Paris", "default_locale": "fr", "address": "Old street"}'::jsonb,
  'and nothing is written before it');
select is(pg_temp.target('00000000-0000-4000-8000-0000003132e1')->'changes',
  '[{"field": "timezone", "from": "Europe/Paris", "to": "Europe/Berlin"}, {"field": "default_locale", "from": "fr", "to": "de"}]'::jsonb,
  'the app is shown every change, from and to');
select is(current_setting('t.c1')::jsonb->>'status', 'acknowledged', 'the person confirms it in the app');
select is(current_setting('t.b7')::jsonb->>'status', 'completed', 'the same request_id then runs it');
select is(pg_temp.ws(), '{"timezone": "Europe/Berlin", "default_locale": "de", "address": "Old street"}'::jsonb,
  'the zone and the language changed, the address did not');
select is(current_setting('t.b2')::jsonb->>'status', 'validation_error', 'a zone that does not exist is refused');
select is(current_setting('t.b3')::jsonb->>'status', 'validation_error', 'and a language the app does not speak');
select is(current_setting('t.b4')::jsonb->'error'->>'code', 'secret_in_app_only', 'a credential is refused');
select is(current_setting('t.b5')::jsonb->>'status', 'validation_error', 'the currency is not an argument of this operation');
select is(current_setting('t.b6')::jsonb->>'status', 'validation_error', 'a change that changes nothing is refused');
select is((select count(*)::int from public.mcp_action_confirmations where request_id in
            ('00000000-0000-4000-8000-0000003132e2', '00000000-0000-4000-8000-0000003132e3',
             '00000000-0000-4000-8000-0000003132e4', '00000000-0000-4000-8000-0000003132e5',
             '00000000-0000-4000-8000-0000003132e6')), 0,
  'and no one is asked to confirm what would be refused');
select is(current_setting('t.m1')::jsonb->'error'->>'code', 'forbidden', 'a member is refused');
select is((select count(*)::int from public.mcp_action_confirmations where request_id = '00000000-0000-4000-8000-0000003132ec'), 0,
  'and is never asked to confirm');

select * from finish();
rollback;
