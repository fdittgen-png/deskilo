-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2145 / 0357 (S3 + S4 + self-service).
-- S3: the instance operator grants assistant access only while no other
-- database administrator exists, at aal2, on a Google session, for 1 to 30
-- days with a reason; the grant is audited with self_grant, the other
-- operators are notified, and the console marks it. Each refusal varies
-- one thing.
-- S4: Turn on refuses `endpoint_not_deployed` without a fresh probe that
-- saw 401 + resource_metadata and the PRM resource. pg_net answers are
-- simulated by writing its response rows (a rolled-back test sends no
-- request). A deployed probe publishes the PRM resource.
-- Self-service: whoever manages a workspace's integrations switches its
-- mcpAccess, and only that flag, against the value they read.
begin;
select plan(40);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  op uuid := '00000000-0000-4000-8000-000000214701';
  op2 uuid := '00000000-0000-4000-8000-000000214702';
  m1 uuid := '00000000-0000-4000-8000-000000214703';
  adm uuid := '00000000-0000-4000-8000-000000214704';
  nob uuid := '00000000-0000-4000-8000-000000214705';
  ia uuid := '00000000-0000-4000-8000-000000214706';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         n || '-2147@deskilo.test', '', now(), now(), now()
    from (values (op, 'op'), (op2, 'op2'), (m1, 'm1'), (adm, 'adm'), (nob, 'nob'), (ia, 'ia')) v(u, n);
  update public.profiles set display_name = 'Olga Operator' where id = op;
  update public.profiles set display_name = 'Mia Member' where id = m1;
  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  select gen_random_uuid(), 'google-2147-' || n, u, jsonb_build_object('sub', 'google-2147-' || n),
         'google', now(), now()
    from (values (op, 'op'), (m1, 'm1')) v(u, n);
  insert into public.platform_admins (user_id, added_at) values (op, '2000-01-01'), (op2, '2000-01-02');
  update public.database_administrators set status = 'revoked', revoked_at = now() where status = 'active';
  delete from public.identity_authority;
  insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
  perform set_config('request.jwt.claims', json_build_object('sub', op, 'role', 'authenticated')::text, true);
  ws := public.create_workspace('Self grant 2147', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null);
  perform public.finalize_identity_binding();
  perform set_config('request.jwt.claims', json_build_object('sub', m1, 'role', 'authenticated')::text, true);
  perform public.finalize_identity_binding();
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  perform public.finalize_identity_binding();
  perform set_config('request.jwt.claims', '', true);
  update public.workspaces set role_permissions = jsonb_build_object('admin', jsonb_build_array('manageIntegrations'))
   where id = ws;
  insert into public.members (workspace_id, user_id, status, is_admin)
  values (ws, m1, 'active', false), (ws, ia, 'active', true);
  perform set_config('deskilo.ws', ws::text, false);
  perform set_config('deskilo.op', op::text, false);
  perform set_config('deskilo.op2', op2::text, false);
  perform set_config('deskilo.m1', m1::text, false);
  perform set_config('deskilo.adm', adm::text, false);
  perform set_config('deskilo.nob', nob::text, false);
  perform set_config('deskilo.ia', ia::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as(p_user text, p_aal text, p_method text default 'oauth') returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('deskilo.' || p_user), 'role', 'authenticated', 'aal', p_aal,
    'amr', json_build_array(json_build_object('method', p_method)))::text, false);
$$;
create or replace function pg_temp.err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlerrm;
end;
$$;
create or replace function pg_temp.grant_to(p_user text, p_days int, p_reason text default 'only operator') returns text language sql as $$
  select pg_temp.err(format('select public.instance_grant_mcp_eligibility(%L, %L, %s)',
    current_setting('deskilo.' || p_user), p_reason, p_days));
$$;
-- pg_net's answer to one probe request, as it would store it.
create or replace function pg_temp.answer(p_which text, p_status int, p_headers jsonb, p_content text) returns void language plpgsql as $$
declare
  v_id bigint;
begin
  select case p_which when 'challenge' then challenge_request else metadata_request end into v_id
    from public.mcp_endpoint_probes order by id desc limit 1;
  insert into net._http_response (id, status_code, content_type, headers, content, timed_out, created)
  values (v_id, p_status, 'application/json', p_headers, p_content, false, now());
end;
$$;

-- ── S3: who may grant ────────────────────────────────────────────────
select pg_temp.as('m1', 'aal2');
select alike(pg_temp.grant_to('m1', 30), '%only the instance operator%', 'a member who is not the operator is refused');
select pg_temp.as('op', 'aal1');
select alike(pg_temp.grant_to('op', 30), '%second factor%', 'the operator without a second factor is refused');
select pg_temp.as('op', 'aal2', 'password');
select alike(pg_temp.grant_to('op', 30), '%sign in with Google%', 'the operator not signed in with Google is refused');
select pg_temp.as('op', 'aal2');
select alike(pg_temp.grant_to('op', 31), '%1 to 30 days%', 'more than 30 days is refused');
select alike(pg_temp.grant_to('op', 0), '%1 to 30 days%', 'zero days is refused');
select alike(pg_temp.grant_to('op', 30, '  '), '%name the reason%', 'a grant without a reason is refused');
select alike(pg_temp.grant_to('nob', 30), '%no verified identity binding%', 'a subject without an identity is refused');
select public.operator_grant_database_admin(current_setting('deskilo.adm')::uuid, true);
select alike(pg_temp.grant_to('op', 30), '%another database administrator%', 'while another administrator exists it is theirs');
select is((select count(*)::int from public.mcp_eligibility_grants
            where local_user_id = current_setting('deskilo.op')::uuid and status = 'active'), 0,
  'no refusal left a grant behind');
update public.database_administrators set status = 'revoked', revoked_at = now()
 where local_user_id = current_setting('deskilo.adm')::uuid and status = 'active';
select public.operator_grant_database_admin(current_setting('deskilo.op')::uuid, true);

-- ── S3: the self-grant ───────────────────────────────────────────────
select is(pg_temp.grant_to('op', 30, 'single-operator installation'), 'ok',
  'the operator who is the only administrator grants themselves');
select is(public.my_database_capabilities()->>'mcp_eligibility', 'eligible', 'and is eligible');
select ok((public.my_database_capabilities()->>'eligible_until')::timestamptz <= now() + interval '30 days',
  'for at most 30 days');
select is((select detail->>'self_grant' from public.database_authority_audit
            where action = 'eligibility_granted_by_operator'
              and target_user_id = current_setting('deskilo.op')::uuid), 'true',
  'audited as a self-grant');
select is((select actor from public.database_authority_audit
            where action = 'eligibility_granted_by_operator'
              and target_user_id = current_setting('deskilo.op')::uuid), 'instance:' || current_setting('deskilo.op'),
  'naming the operator');
select is((select count(*)::int from public.instance_notices
            where user_id = current_setting('deskilo.op2')::uuid and kind = 'mcp_self_grant'), 1,
  'the other owner is notified');
select is((select count(*)::int from public.instance_notices
            where user_id = current_setting('deskilo.op')::uuid and kind = 'mcp_self_grant'), 0,
  'the operator is not notified of their own grant');
select is((select u->>'granted_by' || '/' || (u->>'self_grant')
             from jsonb_array_elements(public.instance_mcp_overview()->'eligible_users') u
            where u->>'user_id' = current_setting('deskilo.op')), 'operator/true',
  'the console marks it self-approved by the operator');
select is(pg_temp.grant_to('m1', 7, 'pilot member'), 'ok', 'the operator grants a member too');
select is((select count(*)::int from public.instance_notices
            where user_id = current_setting('deskilo.op2')::uuid and kind = 'mcp_operator_grant'), 1,
  'which notifies the other owner as an operator grant');
select is(public.instance_mcp_overview()->>'operator_grant_available', 'true',
  'the console offers the grant while no other administrator exists');

-- ── S4: Turn on needs the deployed endpoint ──────────────────────────
select public.instance_set_mcp_endpoint('https://mcp.deskilo.test/deskilo-mcp');
select alike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%endpoint_not_deployed%',
  'without a probe, Turn on refuses endpoint_not_deployed');
select pg_temp.as('m1', 'aal2');
select alike(pg_temp.err('select public.instance_probe_mcp_endpoint()'), '%only the instance operator%',
  'only the operator probes');
select pg_temp.as('op', 'aal2');
select is(public.instance_probe_mcp_endpoint()->>'state', 'pending', 'a probe is queued');
select ok((select challenge_request is not null and metadata_request is not null
             from public.mcp_endpoint_probes order by id desc limit 1),
  'with one anonymous call and one metadata read');
select is(public.instance_mcp_endpoint_check()->>'state', 'pending', 'until pg_net answers');
select pg_temp.answer('challenge', 404, '{}', '{"error":"not found"}');
select pg_temp.answer('metadata', 404, '{}', '{"error":"not found"}');
select is(public.instance_mcp_endpoint_check()->>'reason', 'challenge_404', 'a missing function is not deployed');
select alike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%endpoint_not_deployed (challenge_404)%',
  'and Turn on says so');
select public.instance_probe_mcp_endpoint();
select pg_temp.answer('challenge', 503, '{}', '{"error":"not_configured"}');
select pg_temp.answer('metadata', 200, '{}', '{"resource":"https://mcp.deskilo.test/deskilo-mcp"}');
select is(public.instance_mcp_endpoint_check()->>'state', 'endpoint_not_deployed',
  'metadata alone is not enough: the endpoint must challenge');
select public.instance_probe_mcp_endpoint();
select pg_temp.answer('challenge', 401,
  '{"www-authenticate": "Bearer resource_metadata=\"https://mcp.deskilo.test/deskilo-mcp/.well-known/oauth-protected-resource\""}',
  '{"error":"unauthorized"}');
select pg_temp.answer('metadata', 200, '{}',
  '{"resource":"https://mcp.deskilo.test/deskilo-mcp","authorization_servers":["https://auth.deskilo.test/auth/v1"]}');
select is(public.instance_mcp_endpoint_check()->>'state', 'deployed', '401 + resource_metadata + PRM: deployed');
select is(public.mcp_endpoint()->>'source', 'published', 'the PRM resource is now the published endpoint');
select unalike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%endpoint_not_deployed%',
  'a fresh deployed probe passes the endpoint gate');
update public.mcp_endpoint_probes set requested_at = now() - interval '16 minutes'
 where id = (select max(id) from public.mcp_endpoint_probes);
select alike(pg_temp.err('select public.instance_set_mcp_runtime(true)'), '%older than 15 minutes%',
  'a stale probe does not');
select public.instance_probe_mcp_endpoint();
select pg_temp.answer('challenge', 401, '{"www-authenticate": "Bearer resource_metadata=\"x\""}', '{}');
select pg_temp.answer('metadata', 200, '{}', '{"resource":"https://elsewhere.deskilo.test/mcp"}');
select is(public.instance_mcp_endpoint_check()->>'state', 'resource_mismatch', 'metadata naming another resource is a mismatch');
select is(public.mcp_endpoint()->>'resource', 'https://elsewhere.deskilo.test/mcp', 'and the app shows what is published');
select public.instance_probe_mcp_endpoint();
update public.mcp_endpoint_probes set requested_at = now() - interval '1 minute'
 where id = (select max(id) from public.mcp_endpoint_probes);
select is(public.instance_mcp_endpoint_check()->>'reason', 'no_answer', 'no answer within 30 seconds is not deployed');

-- ── per-workspace self-service ───────────────────────────────────────
select pg_temp.as('m1', 'aal1');
select alike(pg_temp.err(format('select public.set_workspace_mcp_access(%L, true)', current_setting('deskilo.ws'))),
  '%manage integrations%', 'a member without manageIntegrations cannot switch it');
select pg_temp.as('ia', 'aal1');
select is((public.set_workspace_mcp_access(current_setting('deskilo.ws')::uuid, true, false))->>'mcp_access', 'true',
  'an administrator who manages integrations switches assistants on');
select ok(public.feature_effective(current_setting('deskilo.ws')::uuid, 'mcpAccess'), 'mcpAccess is on');
select alike(pg_temp.err(format('select public.set_workspace_mcp_access(%L, false, false)', current_setting('deskilo.ws'))),
  '%changed since they were read%', 'a decision on a stale read is refused');
select is((select count(*)::int from public.database_authority_audit
            where action = 'workspace_mcp_access_on' and detail->>'workspace_id' = current_setting('deskilo.ws')), 1,
  'the switch is audited');

select * from finish();
rollback;
