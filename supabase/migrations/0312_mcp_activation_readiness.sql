-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0312 (#1633) -- controlled MCP activation: inspect, enable exactly one
-- installation on current evidence, disable with a reason.
--
-- operator_set_mcp_runtime (0273, 0310) already refuses to turn MCP on
-- without the delegated-token guard or an administrator. It takes one
-- boolean, so nothing ties the switch to what the operator inspected: a
-- command aimed at the wrong project, or run an hour after a client was
-- revoked, still switches. This file adds the database half of the
-- activation sequence that `dart run tool/instance.dart mcp-*` drives:
--
--   operator_mcp_readiness()      read-only. What this database knows about
--                                 the six readiness areas, the blockers it
--                                 can name itself, and a fingerprint of
--                                 the facts activation depends on. Counts
--                                 and codes only: no user or administrator
--                                 id, no e-mail, no secret.
--   operator_activate_mcp_runtime(installation, epoch, fingerprint)
--                                 switches ON only when the caller names
--                                 THIS installation and epoch, the
--                                 fingerprint is the current one (stale
--                                 evidence is refused, never trusted), and
--                                 no blocker remains. Idempotent.
--   operator_disable_mcp_runtime(installation, reason)
--                                 switches OFF with a named reason (a
--                                 failed pilot, a rollback, an incident).
--                                 Guards, containment and the audit stay.
--
-- None of them accepts a caller's verdict: there is no "checks passed"
-- parameter, and the fingerprint is recomputed here, not stored. What only
-- the operator's tooling can see (Auth, the deployed endpoint and its
-- secrets) is judged there; the database never claims it.

create or replace function public.operator_mcp_readiness()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_runtime public.mcp_runtime;
  v_guard jsonb := public.mcp_facade_guard_status();
  v_authority public.identity_authority;
  v_catalogue jsonb := public.mcp_operation_catalogue();
  v_limits public.mcp_limits;
  v_admins int;
  v_admins_unbound int;
  v_admin_digest text;
  v_clients jsonb;
  v_unclassified jsonb;
  v_ceiling text[] := public.mcp_disclosure_ceiling();
  v_ceiling_unknown jsonb;
  v_basis jsonb;
  v_blockers text[] := '{}';
begin
  select * into v_runtime from public.mcp_runtime;
  select * into v_authority from public.identity_authority;
  select * into v_limits from public.mcp_limits;
  select count(*)::int,
         (count(*) filter (where not exists (
            select 1 from public.identity_bindings b
             where b.id = a.binding_id and b.status = 'active')))::int,
         md5(coalesce(string_agg(a.id::text || ':' || a.can_provision::text, ',' order by a.id), ''))
    into v_admins, v_admins_unbound, v_admin_digest
    from public.database_administrators a
   where a.installation_id = public.installation_id() and a.status = 'active';
  select coalesce(jsonb_agg(client_id order by client_id), '[]'::jsonb) into v_clients
    from public.mcp_clients where status = 'active';
  -- An implemented operation whose answer is not classified would be
  -- projected to nothing today and to whatever a later patch adds.
  select coalesce(jsonb_agg(k order by k), '[]'::jsonb) into v_unclassified
    from jsonb_each(v_catalogue->'operations') e(k, v)
   where coalesce((v->>'dispatch')::boolean, false)
     and (jsonb_typeof(v->'output') is distinct from 'array'
          or jsonb_array_length(v->'output') = 0);
  select coalesce(jsonb_agg(f order by f), '[]'::jsonb) into v_ceiling_unknown
    from unnest(v_ceiling) f
   where not f = any (public.mcp_optional_field_names());

  if not coalesce((v_guard->>'pre_request_installed')::boolean, false)
     or jsonb_array_length(v_guard->'tables_without_denial') > 0 then
    v_blockers := array_append(v_blockers, 'facade_guard_incomplete');
  end if;
  if v_authority is null then
    v_blockers := array_append(v_blockers, 'no_identity_authority');
  end if;
  if v_admins = 0 then
    v_blockers := array_append(v_blockers, 'no_database_administrator');
  end if;
  if v_admins_unbound > 0 then
    v_blockers := array_append(v_blockers, 'administrator_without_identity');
  end if;
  if jsonb_array_length(v_clients) = 0 then
    v_blockers := array_append(v_blockers, 'no_active_mcp_client');
  end if;
  if jsonb_array_length(v_unclassified) > 0 then
    v_blockers := array_append(v_blockers, 'unclassified_operation_output');
  end if;
  if jsonb_array_length(v_ceiling_unknown) > 0 then
    v_blockers := array_append(v_blockers, 'disclosure_ceiling_unknown_field');
  end if;
  if v_limits is null then
    v_blockers := array_append(v_blockers, 'limits_missing');
  end if;

  -- What activation depends on. Anything that changes one of these after
  -- the operator inspected makes the evidence stale.
  v_basis := jsonb_build_object(
    'installation_id', public.installation_id(),
    'epoch', v_runtime.epoch,
    'schema_version', public.deskilo_schema_version(),
    'catalogue', md5(v_catalogue::text),
    'guard', v_guard,
    'authority', case when v_authority is null then null else jsonb_build_object(
      'kind', v_authority.kind, 'issuer', v_authority.issuer,
      'oidc_provider', v_authority.oidc_provider) end,
    'administrators', v_admin_digest,
    'clients', v_clients,
    'limits', case when v_limits is null then null else jsonb_build_object(
      'calls_per_minute', v_limits.calls_per_minute,
      'mutations_per_minute', v_limits.mutations_per_minute,
      'workspace_calls_per_day', v_limits.workspace_calls_per_day) end,
    'disclosure_ceiling', to_jsonb(v_ceiling));

  return jsonb_build_object(
    'installation_id', public.installation_id(),
    'epoch', v_runtime.epoch,
    'enabled', v_runtime.enabled,
    'schema_version', public.deskilo_schema_version(),
    'catalogue_version', v_catalogue->>'version',
    'catalogue_digest', md5(v_catalogue::text),
    'guard', v_guard,
    'areas', jsonb_build_object(
      'canonical_federation', jsonb_build_object(
        'authority_kind', v_authority.kind,
        'issuer', v_authority.issuer,
        'oidc_provider', v_authority.oidc_provider,
        'active_bindings', (select count(*) from public.identity_bindings
                             where installation_id = public.installation_id() and status = 'active'),
        'federation_clients', (select count(*) from public.identity_federation_clients),
        'federation_clients_enabled', (select count(*) from public.identity_federation_clients
                                        where enabled)),
      'database_eligibility', jsonb_build_object(
        'administrators', v_admins,
        'administrators_without_identity', v_admins_unbound,
        'eligible_users', (select count(*) from public.mcp_eligibility_grants
                            where installation_id = public.installation_id()
                              and status = 'active' and expires_at > now()),
        'pending_requests', (select count(*) from public.mcp_eligibility_requests
                              where installation_id = public.installation_id()
                                and status = 'pending')),
      'workspace_exposure', jsonb_build_object(
        'workspaces_with_policy', (select count(*) from public.workspace_mcp_policies
                                    where installation_id = public.installation_id()),
        'workspaces_exposed', (select count(*) from public.workspace_mcp_policies p
                                where p.installation_id = public.installation_id() and p.enabled
                                  and cardinality(p.operations) > 0
                                  and public.feature_effective(p.workspace_id, 'mcpAccess'))),
      'user_consent', jsonb_build_object(
        'active_connections', (select count(*) from public.mcp_connections
                                where installation_id = public.installation_id()
                                  and status = 'active')),
      'mcp_runtime', jsonb_build_object(
        'enabled', v_runtime.enabled,
        'epoch', v_runtime.epoch,
        'active_clients', v_clients,
        'limits', v_basis->'limits',
        'disclosure_ceiling_fields', cardinality(v_ceiling),
        'unclassified_operations', v_unclassified,
        'unknown_ceiling_fields', v_ceiling_unknown)),
    'blockers', to_jsonb(v_blockers),
    'fingerprint', md5(v_basis::text));
end;
$fn$;
revoke execute on function public.operator_mcp_readiness() from public, anon, authenticated;

-- ON for exactly the installation, epoch and evidence the operator
-- inspected. Every refusal leaves MCP off and says why.
create or replace function public.operator_activate_mcp_runtime(
  p_installation_id uuid, p_epoch integer, p_fingerprint text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_ready jsonb;
  v_result jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('mcp_runtime_activation', 1633));
  v_ready := public.operator_mcp_readiness();
  if p_installation_id is distinct from (v_ready->>'installation_id')::uuid then
    raise exception 'MCP stays off: this database is installation %, not %',
      v_ready->>'installation_id', p_installation_id;
  end if;
  if p_epoch is distinct from (v_ready->>'epoch')::integer then
    raise exception 'MCP stays off: the inspected epoch % is not this database''s epoch %',
      p_epoch, v_ready->>'epoch';
  end if;
  if p_fingerprint is distinct from v_ready->>'fingerprint' then
    raise exception 'MCP stays off: the readiness evidence is stale; inspect again';
  end if;
  if jsonb_array_length(v_ready->'blockers') > 0 then
    raise exception 'MCP stays off: not ready (%)', v_ready->'blockers';
  end if;
  if (v_ready->>'enabled')::boolean then
    return jsonb_build_object('enabled', true, 'unchanged', true,
                              'epoch', (v_ready->>'epoch')::integer,
                              'fingerprint', p_fingerprint);
  end if;
  v_result := public.operator_set_mcp_runtime(true);
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'runtime_activation_checked', 'operator',
          jsonb_build_object('fingerprint', p_fingerprint, 'epoch', p_epoch,
                             'schema_version', v_ready->'schema_version'));
  return v_result || jsonb_build_object('unchanged', false, 'fingerprint', p_fingerprint);
end;
$fn$;
revoke execute on function public.operator_activate_mcp_runtime(uuid, integer, text) from public, anon, authenticated;

-- OFF, always allowed on this installation, with the reason in the audit.
-- The guard, the denial policies, consent records and the audit are
-- untouched: off with native access intact is the safe state.
create or replace function public.operator_disable_mcp_runtime(p_installation_id uuid, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_result jsonb;
begin
  if p_installation_id is distinct from public.installation_id() then
    raise exception 'this database is installation %, not %', public.installation_id(), p_installation_id;
  end if;
  if p_reason is null or p_reason not in ('pilot_failed', 'rollback', 'incident', 'operator_request') then
    raise exception 'a disable names its reason: pilot_failed, rollback, incident or operator_request';
  end if;
  v_result := public.operator_set_mcp_runtime(false);
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'runtime_disable_reason', 'operator',
          jsonb_build_object('reason', p_reason));
  return v_result || jsonb_build_object('reason', p_reason);
end;
$fn$;
revoke execute on function public.operator_disable_mcp_runtime(uuid, text) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(312);
