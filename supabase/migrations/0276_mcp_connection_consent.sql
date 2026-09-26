-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0276 (#1615) -- a person connects an assistant, explicitly, workspace by
-- workspace, from the Deskilo app.
--
-- Supabase Auth's OAuth 2.1 server sends the person's browser to the app
-- with an authorization id. The app shows the assistant and what it asks,
-- and offers ONLY the workspaces whose owner exposed MCP, with ONLY the
-- operations this person may use there (mcp_consent_options). The person
-- picks a subset; the app records it (mcp_prepare_connection), approves
-- the authorization with Auth, and then finalises (mcp_finalize_connection),
-- which is when the connection and its workspace scopes become usable. An
-- approval that failed or was abandoned leaves a preparation that expires
-- and authorises nothing.
--
-- Every function here answers the NATIVE session only: a token carrying
-- an OAuth `client_id` is refused, so an assistant can never widen its own
-- consent. Database eligibility (#1611) is required to prepare; it is not
-- implied by consent. A workspace joined later, or an operation exposed
-- later, is never added silently: consent names them one by one.
--
-- Removing one workspace revokes that scope only; disconnecting the
-- assistant revokes the connection and all its scopes here (the app also
-- revokes the provider grant, which is Auth's, not this database's).

create table if not exists public.mcp_connection_preparations (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.installation_identity (installation_id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null references public.mcp_clients (client_id),
  authorization_id text not null unique check (authorization_id ~ '^[A-Za-z0-9._-]{8,128}$'),
  scopes jsonb not null,
  status text not null default 'prepared' check (status in ('prepared', 'finalized', 'abandoned')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes'
);
select public.ensure_system_columns('mcp_connection_preparations');
alter table public.mcp_connection_preparations enable row level security;
revoke all on table public.mcp_connection_preparations from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.mcp_connection_preparations;
create policy mcp_delegated_deny on public.mcp_connection_preparations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.mcp_require_native()
returns void language plpgsql stable set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.mcp_is_delegated() then raise exception 'connections are managed in the Deskilo app'; end if;
end;
$fn$;
revoke execute on function public.mcp_require_native() from public, anon, authenticated;

-- What this person could consent to, per workspace: the owner's exposed
-- operations that their membership and permissions allow.
create or replace function public.mcp_consent_options()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_row record;
  v_ops text[];
  v_out jsonb := '[]'::jsonb;
begin
  perform public.mcp_require_native();
  for v_row in
    select w.id, w.name, p.operations
      from public.members m
      join public.workspaces w on w.id = m.workspace_id
      join public.workspace_mcp_policies p on p.workspace_id = w.id and p.enabled
     where m.user_id = auth.uid() and m.status = 'active'
       and public.feature_effective(w.id, 'mcpAccess')
     order by w.name, w.id
  loop
    select coalesce(array_agg(o order by o), '{}') into v_ops
      from unnest(v_row.operations) o
     where public.mcp_operation_catalogue()->'operations'->o->>'authority' <> 'permission'
        or public.has_permission(v_row.id, public.mcp_operation_catalogue()->'operations'->o->>'permission');
    if cardinality(v_ops) > 0 then
      v_out := v_out || jsonb_build_object('workspace_id', v_row.id, 'name', v_row.name, 'operations', to_jsonb(v_ops));
    end if;
  end loop;
  return jsonb_build_object('eligibility', public.my_database_capabilities()->>'mcp_eligibility',
                            'workspaces', v_out);
end;
$fn$;
revoke execute on function public.mcp_consent_options() from public, anon;
grant execute on function public.mcp_consent_options() to authenticated;

-- The subset the person chose, checked against what they may choose now.
create or replace function public.mcp_prepare_connection(
  p_client_id text, p_authorization_id text, p_scopes jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_options jsonb;
  v_scope jsonb;
  v_allowed jsonb;
  v_op text;
  v_clean jsonb := '[]'::jsonb;
begin
  perform public.mcp_require_native();
  if public.my_database_capabilities()->>'mcp_eligibility' <> 'eligible' then
    raise exception 'this database has not approved MCP for you yet';
  end if;
  if not exists (select 1 from public.mcp_clients where client_id = p_client_id and status = 'active') then
    raise exception 'this assistant is not approved on this instance';
  end if;
  if jsonb_typeof(p_scopes) <> 'array' or jsonb_array_length(p_scopes) = 0 then
    raise exception 'choose at least one workspace';
  end if;
  v_options := public.mcp_consent_options()->'workspaces';
  for v_scope in select * from jsonb_array_elements(p_scopes) loop
    select o->'operations' into v_allowed from jsonb_array_elements(v_options) o
     where o->>'workspace_id' = v_scope->>'workspace_id';
    if v_allowed is null then
      raise exception 'workspace % cannot be offered', v_scope->>'workspace_id';
    end if;
    for v_op in select * from jsonb_array_elements_text(coalesce(v_scope->'operations', '[]'::jsonb)) loop
      if not v_allowed ? v_op then raise exception 'operation % is not available there', v_op; end if;
    end loop;
    v_clean := v_clean || jsonb_build_object('workspace_id', v_scope->>'workspace_id',
      'operations', (select coalesce(jsonb_agg(distinct x order by x), '[]'::jsonb)
                       from jsonb_array_elements_text(coalesce(v_scope->'operations', '[]'::jsonb)) x));
  end loop;
  insert into public.mcp_connection_preparations (installation_id, local_user_id, client_id, authorization_id, scopes)
  values (public.installation_id(), auth.uid(), p_client_id, p_authorization_id, v_clean)
  on conflict (authorization_id) do nothing;
  if not exists (select 1 from public.mcp_connection_preparations
                  where authorization_id = p_authorization_id and local_user_id = auth.uid()
                    and client_id = p_client_id and status = 'prepared' and scopes = v_clean) then
    raise exception 'this authorization was prepared differently';
  end if;
  return jsonb_build_object('status', 'prepared', 'scopes', v_clean);
end;
$fn$;
revoke execute on function public.mcp_prepare_connection(text, text, jsonb) from public, anon;
grant execute on function public.mcp_prepare_connection(text, text, jsonb) to authenticated;

-- After Auth approved: the connection and exactly the chosen scopes.
create or replace function public.mcp_finalize_connection(p_authorization_id text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_prep public.mcp_connection_preparations;
  v_binding uuid := public.my_active_binding();
  v_connection uuid;
  v_scope jsonb;
begin
  perform public.mcp_require_native();
  select * into v_prep from public.mcp_connection_preparations
   where authorization_id = p_authorization_id and local_user_id = auth.uid() for update;
  if v_prep.id is null then raise exception 'unknown authorization'; end if;
  if v_prep.status = 'finalized' then return jsonb_build_object('status', 'finalized'); end if;
  if v_prep.status <> 'prepared' or v_prep.expires_at <= now() then
    update public.mcp_connection_preparations set status = 'abandoned' where id = v_prep.id;
    return jsonb_build_object('status', 'expired');
  end if;
  if v_binding is null or public.my_database_capabilities()->>'mcp_eligibility' <> 'eligible' then
    raise exception 'this database has not approved MCP for you';
  end if;
  select id into v_connection from public.mcp_connections
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = v_prep.client_id and status = 'active';
  if v_connection is null then
    insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
    values (public.installation_id(), auth.uid(), v_binding, v_prep.client_id)
    returning id into v_connection;
  end if;
  for v_scope in select * from jsonb_array_elements(v_prep.scopes) loop
    -- A chosen workspace-wide operation (issue an invoice, answer a
    -- validation) is consent to act beyond the person's own records; the
    -- owner's policy ceiling still caps it in the dispatcher.
    insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling, consented_at, revoked_at)
    values (v_connection, (v_scope->>'workspace_id')::uuid,
            array(select jsonb_array_elements_text(v_scope->'operations')),
            case when exists (select 1 from jsonb_array_elements_text(v_scope->'operations') o
                               where o <> 'get_capabilities'
                                 and public.mcp_operation_catalogue()->'operations'->o->>'scope' = 'workspace')
                 then 'workspace' else 'own' end,
            now(), null)
    on conflict (connection_id, workspace_id) do update
      set operations = excluded.operations, target_ceiling = excluded.target_ceiling,
          consented_at = now(), revoked_at = null;
  end loop;
  update public.mcp_connection_preparations set status = 'finalized' where id = v_prep.id;
  return jsonb_build_object('status', 'finalized');
end;
$fn$;
revoke execute on function public.mcp_finalize_connection(text) from public, anon;
grant execute on function public.mcp_finalize_connection(text) to authenticated;

create or replace function public.my_mcp_connections()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'client_id', c.client_id,
             'client_name', (select name from public.mcp_clients k where k.client_id = c.client_id),
             'connected_at', c.created_at,
             'workspaces', (select coalesce(jsonb_agg(jsonb_build_object('workspace_id', s.workspace_id,
                              'name', (select name from public.workspaces w where w.id = s.workspace_id),
                              'operations', to_jsonb(s.operations)) order by s.workspace_id), '[]'::jsonb)
                              from public.mcp_connection_scopes s
                             where s.connection_id = c.id and s.revoked_at is null))
           order by c.created_at)
      from public.mcp_connections c
     where c.installation_id = public.installation_id() and c.local_user_id = auth.uid()
       and c.status = 'active'), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_mcp_connections() from public, anon;
grant execute on function public.my_mcp_connections() to authenticated;

create or replace function public.revoke_mcp_workspace_scope(p_client_id text, p_workspace_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count int;
begin
  perform public.mcp_require_native();
  update public.mcp_connection_scopes s set revoked_at = now()
    from public.mcp_connections c
   where s.connection_id = c.id and c.local_user_id = auth.uid() and c.client_id = p_client_id
     and s.workspace_id = p_workspace_id and s.revoked_at is null;
  get diagnostics v_count = row_count;
  return jsonb_build_object('status', case when v_count > 0 then 'revoked' else 'unchanged' end);
end;
$fn$;
revoke execute on function public.revoke_mcp_workspace_scope(text, uuid) from public, anon;
grant execute on function public.revoke_mcp_workspace_scope(text, uuid) to authenticated;

create or replace function public.revoke_mcp_connection(p_client_id text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count int;
begin
  perform public.mcp_require_native();
  update public.mcp_connection_scopes s set revoked_at = now()
    from public.mcp_connections c
   where s.connection_id = c.id and c.local_user_id = auth.uid() and c.client_id = p_client_id
     and s.revoked_at is null;
  update public.mcp_connections set status = 'revoked', revoked_at = now()
   where local_user_id = auth.uid() and client_id = p_client_id and status = 'active';
  get diagnostics v_count = row_count;
  return jsonb_build_object('status', case when v_count > 0 then 'revoked' else 'unchanged' end);
end;
$fn$;
revoke execute on function public.revoke_mcp_connection(text) from public, anon;
grant execute on function public.revoke_mcp_connection(text) to authenticated;

-- The operator approves an assistant for this instance (its OAuth client
-- is registered in Auth separately).
create or replace function public.operator_approve_mcp_client(p_client_id text, p_name text, p_active boolean default true)
returns jsonb language sql volatile security definer set search_path = public as $fn$
  insert into public.mcp_clients (client_id, name, status)
  values (p_client_id, p_name, case when p_active then 'active' else 'revoked' end)
  on conflict (client_id) do update set name = excluded.name, status = excluded.status
  returning jsonb_build_object('client_id', client_id, 'status', status);
$fn$;
revoke execute on function public.operator_approve_mcp_client(text, text, boolean) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(276);
