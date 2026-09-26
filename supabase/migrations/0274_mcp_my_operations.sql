-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0274 (#1616) -- what THIS caller may call, for the MCP server's
-- tools/list and its deskilo_list_workspaces tool.
--
-- The same gates as mcp_execute_v1, evaluated per workspace and unioned
-- over the caller's workspaces: installation, runtime, token client,
-- binding, eligibility, connection, then per workspace the policy, the
-- consent scope, membership and each operation's permission. A tool
-- listed here is still re-checked on every call; the list authorises
-- nothing. Anything missing answers an empty list, never an error that
-- tells a stranger why.

create or replace function public.mcp_my_operations(p_installation_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_client text := auth.jwt()->>'client_id';
  v_binding uuid := public.my_active_binding();
  v_connection public.mcp_connections;
  v_workspaces jsonb := '[]'::jsonb;
  v_operations text[] := '{}';
  v_row record;
  v_ops text[];
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_installation_id is distinct from public.installation_id()
     or not (select enabled from public.mcp_runtime)
     or v_client is null or v_binding is null
     or not exists (select 1 from public.mcp_eligibility_grants
                     where installation_id = public.installation_id() and local_user_id = auth.uid()
                       and binding_id = v_binding and status = 'active' and expires_at > now()) then
    return jsonb_build_object('workspaces', '[]'::jsonb, 'operations', '[]'::jsonb);
  end if;
  select * into v_connection from public.mcp_connections
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = v_binding and client_id = v_client and status = 'active';
  if v_connection.id is null then
    return jsonb_build_object('workspaces', '[]'::jsonb, 'operations', '[]'::jsonb);
  end if;
  for v_row in
    select w.id, w.name, p.operations as policy_ops, s.operations as scope_ops,
           p.target_ceiling as policy_ceiling, s.target_ceiling as scope_ceiling
      from public.members m
      join public.workspaces w on w.id = m.workspace_id
      join public.workspace_mcp_policies p on p.workspace_id = w.id and p.enabled
      join public.mcp_connection_scopes s on s.workspace_id = w.id
                                          and s.connection_id = v_connection.id and s.revoked_at is null
     where m.user_id = auth.uid() and m.status = 'active'
       and public.feature_effective(w.id, 'mcpAccess')
       and (p.allowed_clients is null or v_client = any (p.allowed_clients))
     order by w.name, w.id
  loop
    select coalesce(array_agg(o order by o), '{}') into v_ops
      from unnest(v_row.policy_ops) o
     where o = any (v_row.scope_ops)
       and (public.mcp_operation_catalogue()->'operations'->o->>'authority' <> 'permission'
            or public.has_permission(v_row.id,
                 public.mcp_operation_catalogue()->'operations'->o->>'permission'))
       and (public.mcp_operation_catalogue()->'operations'->o->>'scope' <> 'workspace'
            or o = 'get_capabilities'
            or (v_row.policy_ceiling = 'workspace' and v_row.scope_ceiling = 'workspace'));
    if cardinality(v_ops) > 0 then
      v_workspaces := v_workspaces || jsonb_build_object('workspace_id', v_row.id, 'name', v_row.name,
                                                         'operations', to_jsonb(v_ops));
      v_operations := array(select distinct x from unnest(v_operations || v_ops) x order by 1);
    end if;
  end loop;
  return jsonb_build_object('workspaces', v_workspaces, 'operations', to_jsonb(v_operations));
end;
$fn$;
revoke execute on function public.mcp_my_operations(uuid) from public, anon;
grant execute on function public.mcp_my_operations(uuid) to authenticated;

-- The delegated token may reach this discovery RPC too.
create or replace function public.mcp_pre_request()
returns void language plpgsql stable set search_path = public as $fn$
declare
  v_path text := coalesce(current_setting('request.path', true), '');
  v_method text := upper(coalesce(current_setting('request.method', true), ''));
begin
  if not public.mcp_is_delegated() then
    return;
  end if;
  if v_method = 'POST' and v_path in ('/rpc/mcp_execute_v1', '/rpc/mcp_my_operations',
                                      '/rpc/my_database_capabilities') then
    return;
  end if;
  raise sqlstate 'PGRST' using
    message = json_build_object('code', 'MCP403',
      'message', 'a delegated token may only call the MCP facade')::text,
    detail = json_build_object('status', 403, 'headers', json_build_object())::text;
end;
$fn$;
revoke execute on function public.mcp_pre_request() from public;
grant execute on function public.mcp_pre_request() to anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(274);
