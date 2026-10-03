-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0360 (#2145, S3 + S4) -- the single-operator dead end, a Turn on that
-- checks the deployed endpoint, and per-workspace self-service.
--
-- S3. An installation run by one person had no way through: the operator
-- may make themselves the first database administrator (0343), but nobody
-- decides their own eligibility (0270), so the request waited forever.
-- Owner decision (2026-10-03): `instance_grant_mcp_eligibility(subject,
-- reason, days)` lets the instance operator grant assistant access
--   * only while NO OTHER database administrator exists (when one does,
--     eligibility is theirs to decide, as before);
--   * at aal2 AND on a Google session (the sign-in assistants use);
--   * for at most 30 days, with a reason;
--   * audited (`eligibility_granted_by_operator`, `self_grant` = whether
--     the subject is the operator), and every OTHER owner and delegate
--     gets an installation notice.
-- The console overview lists the active grants, marking those an operator
-- made and the self-grants ("Self-approved by operator"). Eligibility is
-- never settled by signing in, and no step drops the second factor.
--
-- S4. The in-app Turn on (`instance_set_mcp_runtime(true)`) now refuses
-- with `endpoint_not_deployed` unless a probe of the deployed endpoint,
-- taken in the last 15 minutes, saw what an assistant sees: the endpoint
-- answers an anonymous call with 401 and a `resource_metadata` challenge,
-- and its protected-resource metadata names the resource. The probe runs
-- in the database through pg_net (`instance_probe_mcp_endpoint`, answers
-- read by `instance_mcp_endpoint_check`); pg_net is asynchronous, so the
-- app probes, then checks a moment later. The operator's CLI keeps judging
-- the endpoint itself (`operator_activate_mcp_runtime` is unchanged). A
-- deployed probe also makes the PRM `resource` the published endpoint
-- (`mcp_endpoint().source = 'published'`).
--
-- Self-service. `set_workspace_mcp_access(workspace, enabled, expected)`
-- lets the people who manage a workspace's integrations switch its
-- mcpAccess on or off themselves (until now it needed
-- manageConfiguration, so they could configure a policy they could not
-- turn on). It writes ONLY that flag, with set_feature_flags' semantics:
-- a merge under the row lock, refused with DK409 when the flag is no
-- longer what the caller read. mcpAccess has no prerequisite and no
-- dependant, so the write is exactly the toggle delta. Audited.

-- ── S3: the operator's grant ─────────────────────────────────────────

create or replace function public.instance_grant_mcp_eligibility(
  p_subject uuid, p_reason text, p_days integer)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_reason text := btrim(coalesce(p_reason, ''));
  v_binding uuid;
  v_request public.mcp_eligibility_requests;
  v_grant public.mcp_eligibility_grants;
  v_self boolean := p_subject = auth.uid();
begin
  perform public.instance_operator_require(true);
  if not public.mcp_google_session() then
    raise exception 'sign in with Google to grant assistant access';
  end if;
  if p_days is null or p_days < 1 or p_days > 30 then
    raise exception 'an operator grant lasts 1 to 30 days';
  end if;
  if v_reason = '' or length(v_reason) > 500 then
    raise exception 'name the reason for this grant (up to 500 characters)';
  end if;
  -- The same lock as provisioning an administrator: nobody becomes one
  -- between this check and the grant.
  perform pg_advisory_xact_lock(hashtextextended('database_administrators', 1608));
  if exists (select 1 from public.database_administrators
              where installation_id = public.installation_id() and status = 'active'
                and local_user_id is distinct from auth.uid()) then
    raise exception 'another database administrator decides assistant access here';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('mcp_eligibility|' || p_subject, 1611));
  select id into v_binding from public.identity_bindings
   where local_user_id = p_subject and status = 'active' and installation_id = public.installation_id();
  if v_binding is null then
    raise exception 'that person has no verified identity binding here';
  end if;
  select * into v_request from public.mcp_eligibility_requests
   where installation_id = public.installation_id() and local_user_id = p_subject and status = 'pending';
  update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
   where installation_id = public.installation_id() and local_user_id = p_subject and status = 'active';
  insert into public.mcp_eligibility_grants
    (installation_id, binding_id, local_user_id, decision_id, request_id, decision, status,
     decided_by, expires_at, reason)
  values (public.installation_id(), v_binding, p_subject, gen_random_uuid(), v_request.id,
          'approved', 'active', auth.uid(), now() + make_interval(days => p_days), v_reason)
  returning * into v_grant;
  if v_request.id is not null then
    update public.mcp_eligibility_requests set status = 'approved' where id = v_request.id;
  end if;
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
  values (public.installation_id(), 'eligibility_granted_by_operator', 'instance:' || auth.uid(), p_subject,
          jsonb_build_object('decision_id', v_grant.decision_id, 'grant_id', v_grant.id,
                             'valid_days', p_days, 'reason', v_reason, 'self_grant', v_self));
  perform public.instance_notify_operators(
    case when v_self then 'mcp_self_grant' else 'mcp_operator_grant' end, v_grant.id::text,
    jsonb_build_object('subject', public.mcp_person_name(p_subject),
                       'granted_by', public.mcp_person_name(auth.uid()),
                       'self_grant', v_self, 'valid_days', p_days,
                       'expires_at', v_grant.expires_at, 'reason', v_reason),
    auth.uid());
  return jsonb_build_object('status', 'granted', 'self_grant', v_self,
                            'expires_at', v_grant.expires_at);
end;
$fn$;
revoke execute on function public.instance_grant_mcp_eligibility(uuid, text, integer) from public, anon;
grant execute on function public.instance_grant_mcp_eligibility(uuid, text, integer) to authenticated;

-- ── S4: probing the deployed endpoint ────────────────────────────────

create table if not exists public.mcp_endpoint_probes (
  id bigint generated always as identity primary key,
  requested_by uuid references auth.users (id) on delete set null,
  endpoint_url text not null,
  challenge_request bigint,
  metadata_request bigint,
  requested_at timestamptz not null default now(),
  verdict text check (verdict in ('deployed', 'endpoint_not_deployed', 'resource_mismatch', 'unavailable')),
  reason text,
  published_resource text,
  settled_at timestamptz,
  check ((verdict is null) = (settled_at is null))
);
select public.ensure_system_columns('mcp_endpoint_probes');
alter table public.mcp_endpoint_probes enable row level security;
revoke all on table public.mcp_endpoint_probes from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.mcp_endpoint_probes;
create policy mcp_delegated_deny on public.mcp_endpoint_probes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The URL the operator configured, or the one derived from this
-- database's functions URL (0358's rule): what a probe calls.
create or replace function public.mcp_endpoint_configured()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_url text;
  v_source text;
  v_functions text;
begin
  select endpoint_url into v_url from public.mcp_installation_settings;
  if v_url is not null then
    v_source := 'configured';
  else
    select functions_url into v_functions from public.push_config where id;
    if v_functions ~ '^https://[^/?#@[:space:]]+/' then
      v_url := rtrim(v_functions, '/') || '/deskilo-mcp';
      v_source := 'derived';
    end if;
  end if;
  return jsonb_build_object('resource', v_url, 'source', v_source);
end;
$fn$;
revoke execute on function public.mcp_endpoint_configured() from public, anon, authenticated;

-- 0358, restated: a deployed probe's PRM resource is the published one.
create or replace function public.mcp_endpoint_resolved()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_base jsonb := public.mcp_endpoint_configured();
  v_url text := v_base->>'resource';
  v_source text := v_base->>'source';
  v_published text;
begin
  select published_resource into v_published from public.mcp_endpoint_probes
   where verdict in ('deployed', 'resource_mismatch') and published_resource is not null
   order by id desc limit 1;
  if v_published is not null then
    v_url := v_published;
    v_source := 'published';
  end if;
  return jsonb_build_object(
    'resource', v_url,
    'metadata_url', case when v_url is not null
                         then v_url || '/.well-known/oauth-protected-resource' end,
    'source', v_source);
end;
$fn$;
revoke execute on function public.mcp_endpoint_resolved() from public, anon, authenticated;

-- Reads pg_net's answers for the latest probe and records the verdict
-- once both arrived (or 30 seconds passed). Answers the latest probe.
create or replace function public.mcp_endpoint_probe_settle()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_probe public.mcp_endpoint_probes;
  v_challenge record;
  v_metadata record;
  v_resource text;
  v_verdict text;
  v_reason text;
begin
  select * into v_probe from public.mcp_endpoint_probes order by id desc limit 1 for update;
  if v_probe.id is null then
    return jsonb_build_object('state', 'missing');
  end if;
  if v_probe.verdict is null then
    if to_regclass('net._http_response') is null then
      v_verdict := 'unavailable';
      v_reason := 'no_pg_net';
    else
      execute 'select status_code, headers, content, timed_out from net._http_response where id = $1'
        into v_challenge using v_probe.challenge_request;
      execute 'select status_code, headers, content, timed_out from net._http_response where id = $1'
        into v_metadata using v_probe.metadata_request;
      if v_challenge.status_code is null and coalesce(v_challenge.timed_out, false) = false
         or v_metadata.status_code is null and coalesce(v_metadata.timed_out, false) = false then
        if v_probe.requested_at > now() - interval '30 seconds' then
          return jsonb_build_object('state', 'pending', 'endpoint_url', v_probe.endpoint_url,
                                    'requested_at', v_probe.requested_at);
        end if;
        v_verdict := 'endpoint_not_deployed';
        v_reason := 'no_answer';
      elsif v_challenge.status_code is distinct from 401
         or coalesce(v_challenge.headers->>'www-authenticate', '') not like '%resource_metadata="%' then
        v_verdict := 'endpoint_not_deployed';
        v_reason := 'challenge_' || coalesce(v_challenge.status_code::text, 'timeout');
      else
        begin
          v_resource := case when v_metadata.status_code = 200
                             then (v_metadata.content::jsonb)->>'resource' end;
        exception when others then
          v_resource := null;
        end;
        if v_resource is null or v_resource !~ '^https://' then
          v_verdict := 'endpoint_not_deployed';
          v_reason := 'metadata_' || coalesce(v_metadata.status_code::text, 'timeout');
        elsif v_resource <> v_probe.endpoint_url then
          v_verdict := 'resource_mismatch';
          v_reason := 'metadata_names_another_resource';
        else
          v_verdict := 'deployed';
        end if;
      end if;
    end if;
    update public.mcp_endpoint_probes
       set verdict = v_verdict, reason = v_reason, settled_at = now(),
           published_resource = case when v_verdict in ('deployed', 'resource_mismatch') then v_resource end
     where id = v_probe.id
    returning * into v_probe;
  end if;
  return jsonb_build_object('state', v_probe.verdict, 'reason', v_probe.reason,
                            'endpoint_url', v_probe.endpoint_url,
                            'published_resource', v_probe.published_resource,
                            'requested_at', v_probe.requested_at);
end;
$fn$;
revoke execute on function public.mcp_endpoint_probe_settle() from public, anon, authenticated;

-- The operator asks the deployed endpoint what an assistant would get.
create or replace function public.instance_probe_mcp_endpoint()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_url text := public.mcp_endpoint_configured()->>'resource';
  v_challenge bigint;
  v_metadata bigint;
begin
  perform public.instance_operator_require(false);
  if v_url is null then
    raise exception 'no endpoint is known here: configure it first';
  end if;
  perform public.mcp_endpoint_probe_settle();
  if to_regprocedure('net.http_post(text, jsonb, jsonb, jsonb, integer)') is null then
    insert into public.mcp_endpoint_probes (requested_by, endpoint_url, verdict, reason, settled_at)
    values (auth.uid(), v_url, 'unavailable', 'no_pg_net', now());
    return public.mcp_endpoint_probe_settle();
  end if;
  -- Anonymous, as an assistant's first call: no token, no secret.
  execute 'select net.http_post(url := $1, body := ''{}''::jsonb,
             headers := ''{"Content-Type": "application/json"}''::jsonb, timeout_milliseconds := 5000)'
    into v_challenge using v_url;
  execute 'select net.http_get(url := $1, timeout_milliseconds := 5000)'
    into v_metadata using v_url || '/.well-known/oauth-protected-resource';
  insert into public.mcp_endpoint_probes (requested_by, endpoint_url, challenge_request, metadata_request)
  values (auth.uid(), v_url, v_challenge, v_metadata);
  return jsonb_build_object('state', 'pending', 'endpoint_url', v_url, 'requested_at', now());
end;
$fn$;
revoke execute on function public.instance_probe_mcp_endpoint() from public, anon;
grant execute on function public.instance_probe_mcp_endpoint() to authenticated;

create or replace function public.instance_mcp_endpoint_check()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.instance_operator_require(false);
  return public.mcp_endpoint_probe_settle();
end;
$fn$;
revoke execute on function public.instance_mcp_endpoint_check() from public, anon;
grant execute on function public.instance_mcp_endpoint_check() to authenticated;

-- 0343, restated: Turn on needs a fresh probe that saw the endpoint
-- deployed. Turning off never does.
create or replace function public.instance_set_mcp_runtime(p_enabled boolean, p_reason text default 'operator_request')
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_ready jsonb;
  v_probe jsonb;
  v_result jsonb;
begin
  perform public.instance_operator_require(true);
  if p_enabled then
    v_probe := public.mcp_endpoint_probe_settle();
    if v_probe->>'state' is distinct from 'deployed'
       or (v_probe->>'requested_at')::timestamptz < now() - interval '15 minutes' then
      raise exception 'MCP stays off: endpoint_not_deployed (%)',
        case when v_probe->>'state' = 'deployed' then 'probe older than 15 minutes'
             else coalesce(v_probe->>'reason', v_probe->>'state') end
        using hint = 'probe the endpoint again (instance_probe_mcp_endpoint), then turn on';
    end if;
    -- The same evidence the CLI inspects: a fingerprint read now, so the
    -- activation judges the state the operator was shown.
    v_ready := public.operator_mcp_readiness();
    v_result := public.operator_activate_mcp_runtime(public.installation_id(),
      (v_ready->>'epoch')::integer, v_ready->>'fingerprint');
  else
    v_result := public.operator_disable_mcp_runtime(public.installation_id(),
      coalesce(p_reason, 'operator_request'));
  end if;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), case when p_enabled then 'runtime_enabled_in_app' else 'runtime_disabled_in_app' end,
          'instance:' || auth.uid(),
          jsonb_build_object('reason', p_reason, 'endpoint', v_probe->'published_resource'));
  return v_result;
end;
$fn$;
revoke execute on function public.instance_set_mcp_runtime(boolean, text) from public, anon;
grant execute on function public.instance_set_mcp_runtime(boolean, text) to authenticated;

-- 0359, restated: plus the grants (marking operator and self grants),
-- whether the operator may grant, and the latest endpoint probe.
create or replace function public.instance_mcp_overview()
returns jsonb language plpgsql stable security definer set search_path = public, auth as $fn$
declare
  v_ready jsonb;
  v_probe public.mcp_endpoint_probes;
begin
  perform public.instance_operator_require(false);
  v_ready := public.operator_mcp_readiness();
  select * into v_probe from public.mcp_endpoint_probes order by id desc limit 1;
  return jsonb_build_object(
    'installation_id', v_ready->'installation_id',
    'enabled', v_ready->'enabled',
    'epoch', v_ready->'epoch',
    'blockers', v_ready->'blockers',
    'second_factor', coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2',
    'google_session', public.mcp_google_session(),
    'allow_loopback_clients', coalesce((select allow_loopback_clients
                                          from public.mcp_installation_settings), false),
    'endpoint', public.mcp_endpoint_resolved(),
    'endpoint_probe', case when v_probe.id is null then jsonb_build_object('state', 'missing')
      else jsonb_build_object('state', coalesce(v_probe.verdict, 'pending'), 'reason', v_probe.reason,
                              'endpoint_url', v_probe.endpoint_url,
                              'published_resource', v_probe.published_resource,
                              'requested_at', v_probe.requested_at,
                              'fresh', v_probe.requested_at >= now() - interval '15 minutes') end,
    'operator_grant_available', not exists (
      select 1 from public.database_administrators a
       where a.installation_id = public.installation_id() and a.status = 'active'
         and a.local_user_id is distinct from auth.uid()),
    'administrators', coalesce((
      select jsonb_agg(jsonb_build_object(
               'user_id', a.local_user_id,
               'name', coalesce(nullif(p.display_name, ''), u.email, a.local_user_id::text),
               'can_provision', a.can_provision,
               'me', a.local_user_id = auth.uid())
             order by coalesce(nullif(p.display_name, ''), u.email))
        from public.database_administrators a
        left join public.profiles p on p.id = a.local_user_id
        left join auth.users u on u.id = a.local_user_id
       where a.installation_id = public.installation_id() and a.status = 'active'), '[]'::jsonb),
    'candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
               'user_id', b.local_user_id,
               'name', coalesce(nullif(p.display_name, ''), u.email, b.local_user_id::text),
               'me', b.local_user_id = auth.uid())
             order by coalesce(nullif(p.display_name, ''), u.email))
        from public.identity_bindings b
        left join public.profiles p on p.id = b.local_user_id
        left join auth.users u on u.id = b.local_user_id
       where b.installation_id = public.installation_id() and b.status = 'active'
         and not exists (select 1 from public.database_administrators a
                          where a.installation_id = b.installation_id
                            and a.local_user_id = b.local_user_id and a.status = 'active')), '[]'::jsonb),
    'eligible_users', coalesce((
      select jsonb_agg(jsonb_build_object(
               'user_id', g.local_user_id,
               'name', public.mcp_person_name(g.local_user_id),
               'expires_at', g.expires_at,
               'granted_by', case when x.id is not null then 'operator' else 'admin' end,
               'self_grant', coalesce((x.detail->>'self_grant')::boolean, false),
               'me', g.local_user_id = auth.uid())
             order by g.expires_at, g.local_user_id)
        from public.mcp_eligibility_grants g
        left join lateral (
          select d.id, d.detail from public.database_authority_audit d
           where d.action = 'eligibility_granted_by_operator'
             and d.detail->>'decision_id' = g.decision_id::text
           limit 1) x on true
       where g.installation_id = public.installation_id() and g.status = 'active'
         and g.expires_at > now()), '[]'::jsonb),
    'clients', coalesce((
      select jsonb_agg(jsonb_build_object(
               'client_id', c.id::text,
               'name', coalesce(nullif(c.client_name, ''), c.id::text),
               'registered_at', c.created_at,
               'status', coalesce(m.status, 'waiting'),
               'family', public.mcp_client_family(c.redirect_uris::text),
               'redirect_hosts', (select coalesce(jsonb_agg(distinct public.mcp_redirect_host(btrim(r))), '[]'::jsonb)
                                    from unnest(regexp_split_to_array(coalesce(c.redirect_uris::text, ''), ',')) r
                                   where public.mcp_redirect_host(btrim(r)) is not null))
             order by c.created_at desc)
        from auth.oauth_clients c
        left join public.mcp_clients m on m.client_id = c.id::text
       where c.deleted_at is null), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.instance_mcp_overview() from public, anon;
grant execute on function public.instance_mcp_overview() to authenticated;

-- ── per-workspace self-service ───────────────────────────────────────

create or replace function public.set_workspace_mcp_access(
  p_workspace_id uuid, p_enabled boolean, p_expected boolean default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_current jsonb;
  v_before boolean;
begin
  perform public.mcp_require_native();
  if p_enabled is null then raise exception 'say on or off'; end if;
  if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'only those who manage integrations switch assistants on or off here';
  end if;
  select coalesce(feature_flags, '{}'::jsonb) into v_current
    from public.workspaces where id = p_workspace_id for update;
  if not found then raise exception 'unknown workspace'; end if;
  v_before := public.feature_raw(v_current, 'mcpAccess');
  if p_expected is not null and v_before is distinct from p_expected then
    raise exception using errcode = 'DK409',
      message = 'the features changed since they were read: mcpAccess';
  end if;
  if v_before is distinct from p_enabled then
    update public.workspaces set feature_flags = v_current || jsonb_build_object('mcpAccess', p_enabled)
     where id = p_workspace_id;
    insert into public.database_authority_audit (installation_id, action, actor, detail)
    values (public.installation_id(),
            case when p_enabled then 'workspace_mcp_access_on' else 'workspace_mcp_access_off' end,
            'member:' || auth.uid(), jsonb_build_object('workspace_id', p_workspace_id));
  end if;
  return jsonb_build_object('workspace_id', p_workspace_id, 'mcp_access', p_enabled,
                            'unchanged', v_before is not distinct from p_enabled);
end;
$fn$;
revoke execute on function public.set_workspace_mcp_access(uuid, boolean, boolean) from public, anon;
grant execute on function public.set_workspace_mcp_access(uuid, boolean, boolean) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(360);
