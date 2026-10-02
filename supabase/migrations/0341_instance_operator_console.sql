-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0341 (#1827 B) -- the installation's assistant switches, in the app.
--
-- Until now three installation-wide steps were SQL-only, through the
-- operator_* functions (service role): making someone a database
-- administrator, approving an assistant's OAuth client, and turning the
-- MCP runtime on or off. The instance operator (is_instance_operator():
-- a platform admin or an active instance delegate, never through an
-- assistant token) now takes them in the app. Same rules, same internal
-- functions; what is added is the caller check:
--
--   * reading the overview needs the operator;
--   * every CHANGE needs the operator AND a second factor on this session
--     (aal2): these are installation-wide powers;
--   * each change is written to database_authority_audit naming the
--     operator who made it.
--
-- The operator may make themselves the first administrator (someone has
-- to be first); they still cannot approve their own MCP eligibility --
-- that remains another administrator's decision (decide_mcp_eligibility).

create or replace function public.instance_operator_require(p_change boolean)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_instance_operator() then
    raise exception 'only the instance operator manages the installation''s assistants';
  end if;
  if p_change and coalesce(auth.jwt()->>'aal', 'aal1') <> 'aal2' then
    raise exception 'confirm with your second factor first';
  end if;
end;
$fn$;
revoke execute on function public.instance_operator_require(boolean) from public, anon, authenticated;

create or replace function public.instance_mcp_overview()
returns jsonb language plpgsql stable security definer set search_path = public, auth as $fn$
declare
  v_ready jsonb;
begin
  perform public.instance_operator_require(false);
  v_ready := public.operator_mcp_readiness();
  return jsonb_build_object(
    'installation_id', v_ready->'installation_id',
    'enabled', v_ready->'enabled',
    'epoch', v_ready->'epoch',
    'blockers', v_ready->'blockers',
    'second_factor', coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2',
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
    'clients', coalesce((
      select jsonb_agg(jsonb_build_object(
               'client_id', c.id::text,
               'name', coalesce(nullif(c.client_name, ''), c.id::text),
               'registered_at', c.created_at,
               'status', coalesce(m.status, 'waiting'))
             order by c.created_at desc)
        from auth.oauth_clients c
        left join public.mcp_clients m on m.client_id = c.id::text
       where c.deleted_at is null), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.instance_mcp_overview() from public, anon;
grant execute on function public.instance_mcp_overview() to authenticated;

create or replace function public.instance_grant_database_admin(p_target uuid, p_can_provision boolean default true)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.instance_operator_require(true);
  return public.grant_database_admin_internal(p_target, p_can_provision, 'instance:' || auth.uid());
end;
$fn$;
revoke execute on function public.instance_grant_database_admin(uuid, boolean) from public, anon;
grant execute on function public.instance_grant_database_admin(uuid, boolean) to authenticated;

create or replace function public.instance_revoke_database_admin(p_target uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.instance_operator_require(true);
  return public.revoke_database_admin_internal(p_target, 'instance:' || auth.uid());
end;
$fn$;
revoke execute on function public.instance_revoke_database_admin(uuid) from public, anon;
grant execute on function public.instance_revoke_database_admin(uuid) to authenticated;

create or replace function public.instance_set_mcp_client(p_client_id text, p_active boolean)
returns jsonb language plpgsql volatile security definer set search_path = public, auth as $fn$
declare
  v_name text;
  v_result jsonb;
begin
  perform public.instance_operator_require(true);
  select coalesce(nullif(c.client_name, ''), c.id::text) into v_name
    from auth.oauth_clients c where c.id::text = p_client_id and c.deleted_at is null;
  if v_name is null then raise exception 'unknown assistant client'; end if;
  v_result := public.operator_approve_mcp_client(p_client_id, v_name, p_active);
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), case when p_active then 'client_approved' else 'client_blocked' end,
          'instance:' || auth.uid(), jsonb_build_object('client_id', p_client_id, 'name', v_name));
  return v_result;
end;
$fn$;
revoke execute on function public.instance_set_mcp_client(text, boolean) from public, anon;
grant execute on function public.instance_set_mcp_client(text, boolean) to authenticated;

create or replace function public.instance_set_mcp_runtime(p_enabled boolean, p_reason text default 'operator_request')
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_ready jsonb;
  v_result jsonb;
begin
  perform public.instance_operator_require(true);
  if p_enabled then
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
          'instance:' || auth.uid(), jsonb_build_object('reason', p_reason));
  return v_result;
end;
$fn$;
revoke execute on function public.instance_set_mcp_runtime(boolean, text) from public, anon;
grant execute on function public.instance_set_mcp_runtime(boolean, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(341);
