-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0273 (#1613, #1614) -- a delegated MCP token reaches the MCP facade and
-- nothing else.
--
-- Supabase OAuth access tokens keep the user's database role. Hiding a
-- tool does not stop the same token being used against `/rest/v1`,
-- `/graphql/v1`, Storage or Realtime directly. So a token is DELEGATED
-- when its signed claims carry `client_id` (every OAuth client, known or
-- not), and then:
--
--   * PostgREST: `mcp_pre_request` runs before every request and refuses
--     every route but `POST /rpc/mcp_execute_v1` and the caller's own
--     `POST /rpc/my_database_capabilities`. Method and path come from
--     PostgREST's own request settings. Nested business functions inside
--     the facade run in the same request and are not re-checked, and their
--     `auth.uid()` is untouched.
--   * Tables, Storage objects and Realtime messages: a RESTRICTIVE policy
--     `mcp_delegated_deny` on every RLS-enabled table denies a delegated
--     token directly -- restrictive, so it ANDs with every existing allow
--     policy instead of ORing into nothing. Definer functions (the facade,
--     every business RPC) run as the table owner and are unaffected; a
--     native session (no `client_id`) is unaffected.
--
-- The MCP runtime cannot be switched on unless the pre-request guard is
-- installed on the API role (`mcp_facade_guard_status`); an operator
-- enables it through `operator_set_mcp_runtime`, which refuses otherwise.

create or replace function public.mcp_is_delegated()
returns boolean language sql stable set search_path = public as $fn$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ? 'client_id';
$fn$;
revoke execute on function public.mcp_is_delegated() from public, anon;
grant execute on function public.mcp_is_delegated() to authenticated;

-- The routes a delegated token may reach: exact, versioned, POST only.
create or replace function public.mcp_pre_request()
returns void language plpgsql stable set search_path = public as $fn$
declare
  v_path text := coalesce(current_setting('request.path', true), '');
  v_method text := upper(coalesce(current_setting('request.method', true), ''));
begin
  if not public.mcp_is_delegated() then
    return;
  end if;
  if v_method = 'POST' and v_path in ('/rpc/mcp_execute_v1', '/rpc/my_database_capabilities') then
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

alter role authenticator set pgrst.db_pre_request to 'public.mcp_pre_request';
notify pgrst, 'reload config';

-- Restrictive denial on every RLS-enabled business table, on Storage
-- objects and on Realtime messages.
do $deny$
declare
  v_table record;
begin
  for v_table in
    select n.nspname as schema_name, c.relname as table_name
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where c.relkind = 'r' and c.relrowsecurity
       and (n.nspname = 'public'
            or (n.nspname = 'storage' and c.relname = 'objects')
            or (n.nspname = 'realtime' and c.relname = 'messages'))
  loop
    execute format('drop policy if exists mcp_delegated_deny on %I.%I',
                   v_table.schema_name, v_table.table_name);
    execute format(
      'create policy mcp_delegated_deny on %I.%I as restrictive for all to authenticated '
      'using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated())',
      v_table.schema_name, v_table.table_name);
  end loop;
end
$deny$;

-- Is the guard installed where PostgREST reads it? Operators and the
-- doctor ask this; it answers configured or not, never a guess.
create or replace function public.mcp_facade_guard_status()
returns jsonb language sql stable security definer set search_path = public, pg_catalog as $fn$
  select jsonb_build_object(
    'pre_request_installed', exists (
      select 1 from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
       where r.rolname = 'authenticator'
         and 'pgrst.db_pre_request=public.mcp_pre_request' = any (s.setconfig)),
    'tables_without_denial', (
      select coalesce(jsonb_agg(c.relname order by c.relname), '[]'::jsonb)
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
         and not exists (select 1 from pg_policy p
                          where p.polrelid = c.oid and p.polname = 'mcp_delegated_deny')));
$fn$;
revoke execute on function public.mcp_facade_guard_status() from public, anon, authenticated;

-- The only way the runtime goes on: the guard must be there, and every
-- RLS table must carry its denial. Off is always allowed.
create or replace function public.operator_set_mcp_runtime(p_enabled boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_status jsonb := public.mcp_facade_guard_status();
begin
  if p_enabled and (not (v_status->>'pre_request_installed')::boolean
                    or jsonb_array_length(v_status->'tables_without_denial') > 0) then
    raise exception 'MCP stays off: the delegated-token guard is not complete (%)', v_status;
  end if;
  update public.mcp_runtime set enabled = p_enabled;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), case when p_enabled then 'runtime_enabled' else 'runtime_disabled' end,
          'operator', v_status);
  return jsonb_build_object('enabled', p_enabled, 'guard', v_status);
end;
$fn$;
revoke execute on function public.operator_set_mcp_runtime(boolean) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(273);
