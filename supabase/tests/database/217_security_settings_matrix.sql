-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2485 / 0451 + 0472 (S2 of #2483): what 197 left open -- the alternate
-- workspace attack, who may write a security limit, the platform value as a
-- ceiling for a workspace value, a limit changed between attempts, an expired
-- confirmation that is replayed, and the probe freshness at a changed value.
-- Expected values are written by hand; every refusal is followed by a readback.
--   A the alternate workspace   B the platform value is a ceiling
--   C who may write   D counts survive a change of the limit
--   E the confirmation expiry and its replay   F the probe freshness
begin;
select plan(32);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2',
    'amr', case when p_client is null then null else jsonb_build_array(jsonb_build_object('method', 'oauth')) end,
    'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002486' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.days_of(p_code text) returns numeric language sql as $$
  select round(extract(epoch from (i.expires_at - now())) / 86400)::numeric
    from public.invitations i where i.code = p_code;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@securitymatrix.test', '', now(), now(), now()
  from generate_series(1, 8) i;
-- 1 owner of A, 2 platform owner, 3 owner of B, 4 plain member of A,
-- 5 group sender, 6 group member, 7 confirmation holder, 8 the operator.
insert into public.platform_admins (user_id) values (pg_temp.u(2));

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Matrix A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(3));
select set_config('t.b', public.create_workspace('Matrix B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at)
values (current_setting('t.a')::uuid, pg_temp.u(4), false, false, 'active', 100, '2026-01-01');

-- ── A: the alternate workspace ─────────────────────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select is(public.set_setting(current_setting('t.a')::uuid, 'security.invitation_expiry_days', '7', 'tighten')->>'status', 'saved',
  'A: the owner of A tightens A to 7 days');
select ok(pg_temp.err(format('select public.set_setting(%L, ''security.invitation_expiry_days'', ''3'', ''x'')', current_setting('t.b'))) like '%not allowed%',
  'A: and cannot touch the value of B');
select ok(pg_temp.err(format('select public.setting_value(%L, ''security.invitation_expiry_days'')', current_setting('t.b'))) like '%not a member%',
  'A: nor read it');
select ok(pg_temp.err(format('select public.create_invitation(%L, false, ''Eve'', ''Mallory'')', current_setting('t.b'))) <> '',
  'A: nor invite into B');
select set_config('t.ia', public.create_invitation(current_setting('t.a')::uuid, false, 'Ada', 'Lovelace'), true);
select pg_temp.act_as(pg_temp.u(3));
select set_config('t.ib', public.create_invitation(current_setting('t.b')::uuid, false, 'Grace', 'Hopper'), true);
reset role;
select is(pg_temp.days_of(current_setting('t.ia')), 7::numeric, 'A: an invitation of A lasts the 7 days of A');
select is(pg_temp.days_of(current_setting('t.ib')), 14::numeric, 'A: an invitation of B still lasts 14: the tightening did not travel');
select is((select count(*)::int from public.invitations where workspace_id = current_setting('t.b')::uuid), 1,
  'A: readback: B holds only its own invitation');

-- ── B: the platform value is a ceiling ─────────────────────────────────
select pg_temp.act_as(pg_temp.u(2));
select is(public.set_setting(null, 'security.invitation_expiry_days', '5', 'platform tightens')->>'status', 'saved',
  'B: the platform owner tightens the lifetime to 5 days');
reset role;
select is(public.setting_value(current_setting('t.a')::uuid, 'security.invitation_expiry_days')::text, '7',
  'B: the resolver still reads A''s own 7 (the ceiling is applied where the invitation is issued)');
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.ic', public.create_invitation(current_setting('t.a')::uuid, false, 'Alan', 'Turing'), true);
reset role;
select is(pg_temp.days_of(current_setting('t.ic')), 5::numeric, 'B: A stored 7 but the platform says 5: the invitation lasts 5');
select is(pg_temp.days_of(current_setting('t.ia')), 7::numeric, 'B: an invitation created before keeps its own 7');
select public.store_setting(current_setting('t.a')::uuid, 'security.invitation_expiry_days', '2'::jsonb, 'test', null);
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.id', public.create_invitation(current_setting('t.a')::uuid, false, 'Emmy', 'Noether'), true);
reset role;
select is(pg_temp.days_of(current_setting('t.id')), 2::numeric, 'B: a workspace tighter than the platform keeps its 2 days');
select public.store_setting(null, 'security.invitation_expiry_days', '14'::jsonb, 'test', null);
select public.store_setting(current_setting('t.a')::uuid, 'security.invitation_expiry_days', '14'::jsonb, 'test', null);

-- ── C: who may write ───────────────────────────────────────────────────
select ok(pg_temp.err('select public.set_setting(null, ''security.badge_lockout_failures'', ''4'', ''x'')') <> '',
  'C: anonymous cannot write a limit');
select pg_temp.act_as(pg_temp.u(2), 'claude-test');
select ok(pg_temp.err('select public.set_setting(null, ''security.badge_lockout_failures'', ''4'', ''x'')') like '%not allowed%',
  'C: an assistant acting for the platform owner cannot write it either');
select pg_temp.act_as(pg_temp.u(4));
select ok(pg_temp.err(format('select public.set_setting(%L, ''security.invitation_expiry_days'', ''3'', ''x'')', current_setting('t.a'))) like '%not allowed to change%',
  'C: a plain member cannot write the workspace value');
select pg_temp.act_as(pg_temp.u(1));
select ok(pg_temp.err('select public.set_setting(null, ''security.badge_lockout_failures'', ''4'', ''x'')') like '%platform owners only%',
  'C: the owner of a workspace cannot write a platform value');
reset role;
select is(public.setting_value(null, 'security.badge_lockout_failures')::text, '5', 'C: readback: no refusal changed the limit');
select pg_temp.act_as(pg_temp.u(2));
select is(public.set_setting(null, 'security.badge_lockout_failures', '4', 'native platform owner')->>'status', 'saved',
  'C: positive control: the platform owner on a native session writes it');
select public.set_setting(null, 'security.badge_lockout_failures', '5', 'restore');
reset role;

-- ── D: counts survive a change of the limit ────────────────────────────
select pg_temp.act_as(pg_temp.u(6));
select public.set_visibility('reachability', 'signed_in');
select pg_temp.act_as(pg_temp.u(5));
select public.create_account_group('G1', array[pg_temp.u(6)], pg_temp.u(5));
select public.create_account_group('G2', array[pg_temp.u(6)], pg_temp.u(5));
reset role;
select public.store_setting(null, 'messaging.group_creation_per_hour', '2'::jsonb, 'test', null);
select pg_temp.act_as(pg_temp.u(5));
select ok(pg_temp.err(format('select public.create_account_group(''G3'', array[%L::uuid], %L::uuid)', pg_temp.u(6), pg_temp.u(5))) like '%group limit reached%',
  'D: two groups made under the old ceiling count against the tightened one: the count was not reset');
reset role;
select public.store_setting(null, 'messaging.group_creation_per_hour', '10'::jsonb, 'test', null);
select pg_temp.act_as(pg_temp.u(5));
select lives_ok(format('select public.create_account_group(''G3'', array[%L::uuid], %L::uuid)', pg_temp.u(6), pg_temp.u(5)),
  'D: and restoring the ceiling reopens exactly the room that was left');
reset role;

-- ── E: the confirmation expiry and its replay ──────────────────────────
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
values (gen_random_uuid(), 'google-matrix-7', pg_temp.u(7), jsonb_build_object('sub', 'google-matrix-7'), 'google', now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
select pg_temp.act_as(pg_temp.u(7));
select public.finalize_identity_binding();
reset role;
insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
  from public.identity_bindings where local_user_id = pg_temp.u(7) and status = 'active';
insert into public.mcp_action_confirmations
  (id, installation_id, local_user_id, client_id, workspace_id, eligibility_grant_id, operation, request_id, args_digest, preview, company_id)
select '00000000-0000-4000-8000-0000248600e1', public.installation_id(), pg_temp.u(7), 'claude-test', w.id,
       (select g.id from public.mcp_eligibility_grants g where g.local_user_id = pg_temp.u(7)), 'request_subscription_change', gen_random_uuid(), 'd1', '{}'::jsonb, w.company_id
  from public.workspaces w where w.id = current_setting('t.a')::uuid;
select public.store_setting(null, 'mcp.confirmation_expiry_minutes', '2'::jsonb, 'test', null);
insert into public.mcp_action_confirmations
  (id, installation_id, local_user_id, client_id, workspace_id, eligibility_grant_id, operation, request_id, args_digest, preview, company_id)
select '00000000-0000-4000-8000-0000248600e2', public.installation_id(), pg_temp.u(7), 'claude-test', w.id,
       (select g.id from public.mcp_eligibility_grants g where g.local_user_id = pg_temp.u(7)), 'request_subscription_change', gen_random_uuid(), 'd2', '{}'::jsonb, w.company_id
  from public.workspaces w where w.id = current_setting('t.a')::uuid;
select is((select round(extract(epoch from (expires_at - created_at)) / 60)::int from public.mcp_action_confirmations
            where id = '00000000-0000-4000-8000-0000248600e1'), 5, 'E: a confirmation made at the default waits 5 minutes');
select is((select round(extract(epoch from (expires_at - created_at)) / 60)::int from public.mcp_action_confirmations
            where id = '00000000-0000-4000-8000-0000248600e2'), 2, 'E: one made after the tightening waits 2');
select public.store_setting(null, 'mcp.confirmation_expiry_minutes', '5'::jsonb, 'test', null);
select is((select round(extract(epoch from (expires_at - created_at)) / 60)::int from public.mcp_action_confirmations
            where id = '00000000-0000-4000-8000-0000248600e2'), 2, 'E: and restoring the setting does not stretch the one already made');
update public.mcp_action_confirmations set expires_at = now() - interval '1 second'
 where id = '00000000-0000-4000-8000-0000248600e2';
select pg_temp.act_as(pg_temp.u(7));
select is(public.mcp_confirm_action('00000000-0000-4000-8000-0000248600e2', true) ->> 'status', 'expired', 'E: past its tightened expiry it cannot be given');
select is(public.mcp_confirm_action('00000000-0000-4000-8000-0000248600e2', true) ->> 'status', 'expired', 'E: and the replay is expired too');
select pg_temp.act_as(pg_temp.u(7), 'claude-test');
select ok(pg_temp.err('select public.mcp_confirm_action(''00000000-0000-4000-8000-0000248600e1'', true)') like '%answered in the Deskilo app%',
  'E: an assistant cannot answer a confirmation, whatever its expiry');
reset role;
select ok(pg_temp.err('select public.mcp_confirm_action(''00000000-0000-4000-8000-0000248600e1'', true)') <> '',
  'E: nor an anonymous caller');
select is((select status from public.mcp_action_confirmations where id = '00000000-0000-4000-8000-0000248600e1'), 'pending',
  'E: readback: the unexpired confirmation was not touched by either refusal');

-- ── F: the probe freshness at a changed value ──────────────────────────
create function pg_temp.as_operator() returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(8), 'role', 'authenticated', 'aal', 'aal2',
    'amr', json_build_array(json_build_object('method', 'oauth')))::text, true);
$$;
create function pg_temp.answer(p_which text, p_status int, p_headers jsonb, p_content text) returns void language plpgsql as $$
declare v_id bigint;
begin
  select case p_which when 'challenge' then challenge_request else metadata_request end into v_id
    from public.mcp_endpoint_probes order by id desc limit 1;
  insert into net._http_response (id, status_code, content_type, headers, content, timed_out, created)
  values (v_id, p_status, 'application/json', p_headers, p_content, false, now());
end;
$$;
insert into public.platform_admins (user_id) values (pg_temp.u(8));
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
values (gen_random_uuid(), 'google-matrix-8', pg_temp.u(8), jsonb_build_object('sub', 'google-matrix-8'), 'google', now(), now());
select pg_temp.as_operator();
select public.instance_set_mcp_endpoint('https://mcp.deskilo.test/deskilo-mcp');
select public.instance_probe_mcp_endpoint();
select pg_temp.answer('challenge', 401,
  '{"www-authenticate": "Bearer resource_metadata=\"https://mcp.deskilo.test/deskilo-mcp/.well-known/oauth-protected-resource\""}',
  '{"error":"unauthorized"}');
select pg_temp.answer('metadata', 200, '{}',
  '{"resource":"https://mcp.deskilo.test/deskilo-mcp","authorization_servers":["https://auth.deskilo.test/auth/v1"]}');
update public.mcp_endpoint_probes set requested_at = now() - interval '10 minutes'
 where id = (select max(id) from public.mcp_endpoint_probes);
select unalike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%older than%',
  'F: golden: a 10-minute-old deployed probe is fresh at the default 15');
select public.store_setting(null, 'mcp.probe_freshness_minutes', '5'::jsonb, 'test', null);
select alike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%older than 5 minutes%',
  'F: tightened to 5 the same probe is stale, at once, and the message names the value in force');
select public.store_setting(null, 'mcp.probe_freshness_minutes', '30'::jsonb, 'test', null);
select unalike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%older than%',
  'F: a stored value looser than the bound is held at 15: the probe is fresh again, not fresher');
update public.mcp_endpoint_probes set requested_at = now() - interval '16 minutes'
 where id = (select max(id) from public.mcp_endpoint_probes);
select alike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%older than 15 minutes%',
  'F: and 16 minutes is stale whatever was stored');

select * from finish();
rollback;
