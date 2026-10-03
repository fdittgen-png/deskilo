-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0359 (#2145, S2) -- assistant clients are approved per family, by their
-- exact redirect.
--
-- Supabase Auth registers a new OAuth client for every fresh assistant
-- connection (RFC 7591; no client-ID metadata documents yet), so approving
-- each registration by hand left every new connection waiting for the
-- operator. Owner decision (2026-10-03):
--   * a registration whose redirect URIs are ALL exactly an approved
--     family's callback is approved when a member of an mcpAccess
--     workspace arrives with it, and the approval is audited with the
--     family (`client_auto_approved`):
--       claude   https://claude.ai/api/mcp/auth_callback
--                https://claude.com/api/mcp/auth_callback (announced move)
--       chatgpt  https://chatgpt.com/connector_platform_oauth_redirect
--                https://chatgpt.com/connector/oauth/<callback id> (the
--                per-connector form ChatGPT uses when the authorization
--                server does not return `iss`)
--   * a registration whose redirects are ALL loopback
--     (http://127.0.0.1[:port][/path] or http://localhost[:port][/path]:
--     Claude Code, Cursor, VS Code) is approved the same way only while the
--     operator's ONE switch "Allow desktop and command-line assistants" is
--     on (`instance_set_mcp_loopback_clients`, default off, aal2, audited);
--   * everything else stays a per-client manual approval, and an operator's
--     block is never undone by a family match.
-- Matching is exact string comparison (or one anchored pattern), never a
-- prefix or a host test: https://claude.ai.evil.com/… and
-- http://127.0.0.1.evil.com/… are other clients. `mcp_clients` keeps its
-- meaning (a row = the operator's decision, active or revoked).
--
-- The console overview and the consent options also say which family a
-- client was recognised as, and the overview shows the loopback switch and
-- the endpoint.

alter table public.mcp_installation_settings
  add column if not exists allow_loopback_clients boolean not null default false;

-- The family every registered redirect belongs to, or null when they are
-- not all one family's.
create or replace function public.mcp_client_family(p_redirect_uris text)
returns text language plpgsql immutable set search_path = public as $fn$
declare
  v_uri text;
  v_family text;
  v_one text;
  v_seen integer := 0;
begin
  foreach v_uri in array regexp_split_to_array(coalesce(p_redirect_uris, ''), '\s*,\s*') loop
    v_uri := btrim(v_uri);
    if v_uri = '' then continue; end if;
    v_one := case
      when v_uri in ('https://claude.ai/api/mcp/auth_callback',
                     'https://claude.com/api/mcp/auth_callback') then 'claude'
      when v_uri = 'https://chatgpt.com/connector_platform_oauth_redirect'
        or v_uri ~ '^https://chatgpt\.com/connector/oauth/[A-Za-z0-9_-]{1,128}$' then 'chatgpt'
      when v_uri ~ '^http://(127\.0\.0\.1|localhost)(:[0-9]{1,5})?(/[^?#[:space:]]*)?$' then 'loopback'
    end;
    if v_one is null or (v_family is not null and v_one <> v_family) then
      return null;
    end if;
    v_family := v_one;
    v_seen := v_seen + 1;
  end loop;
  return case when v_seen > 0 then v_family end;
end;
$fn$;
revoke execute on function public.mcp_client_family(text) from public, anon, authenticated;

-- The registered redirects of a client, from Auth (null on older Auth).
create or replace function public.mcp_registered_redirects(p_client_id text)
returns text language plpgsql stable security definer set search_path = public as $fn$
declare
  v_uris text;
begin
  if to_regclass('auth.oauth_clients') is null or p_client_id !~ '^[0-9a-fA-F-]{36}$' then
    return null;
  end if;
  execute 'select redirect_uris::text from auth.oauth_clients
            where id = $1::uuid and deleted_at is null and registration_type::text = ''dynamic'''
    into v_uris using p_client_id;
  return v_uris;
end;
$fn$;
revoke execute on function public.mcp_registered_redirects(text) from public, anon, authenticated;

-- 0358, restated: a waiting client of an approved family is approved on
-- arrival, audited with its family; any other waiting client is audited
-- and the operators are told, once.
create or replace function public.mcp_client_arrival(p_client_id text, p_name text, p_redirect_uri text)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_status text := public.mcp_client_status(p_client_id);
  v_uris text;
  v_family text;
  v_name text := left(coalesce(nullif(btrim(p_name), ''), p_client_id), 120);
begin
  if v_status <> 'waiting' then return v_status; end if;
  -- Only someone an assistant could ever serve here raises the flag.
  if not exists (select 1 from public.members m
                  where m.user_id = auth.uid() and m.status = 'active'
                    and public.feature_effective(m.workspace_id, 'mcpAccess')) then
    return v_status;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('mcp_client_arrival|' || p_client_id, 2145));
  v_status := public.mcp_client_status(p_client_id);
  if v_status <> 'waiting' then return v_status; end if;
  v_uris := public.mcp_registered_redirects(p_client_id);
  v_family := public.mcp_client_family(v_uris);
  if v_family in ('claude', 'chatgpt')
     or (v_family = 'loopback'
         and coalesce((select allow_loopback_clients from public.mcp_installation_settings), false)) then
    insert into public.mcp_clients (client_id, name, status) values (p_client_id, v_name, 'active')
    on conflict (client_id) do nothing;
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
    values (public.installation_id(), 'client_auto_approved', 'family:' || v_family, auth.uid(),
            jsonb_build_object('client_id', p_client_id, 'name', v_name, 'family', v_family,
                               'redirect_uris', v_uris));
    return public.mcp_client_status(p_client_id);
  end if;
  if not exists (select 1 from public.database_authority_audit
                  where action = 'client_waiting' and detail->>'client_id' = p_client_id) then
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
    values (public.installation_id(), 'client_waiting', 'member:' || auth.uid(), auth.uid(),
            jsonb_build_object('client_id', p_client_id, 'name', v_name, 'family', v_family,
                               'redirect_host', public.mcp_redirect_host(p_redirect_uri)));
    perform public.instance_notify_operators('mcp_client_waiting', p_client_id,
      jsonb_build_object('client_id', p_client_id, 'client_name', v_name, 'family', v_family,
                         'redirect_host', public.mcp_redirect_host(p_redirect_uri),
                         'requested_by', public.mcp_person_name(auth.uid())),
      null);
  end if;
  return v_status;
end;
$fn$;
revoke execute on function public.mcp_client_arrival(text, text, text) from public, anon, authenticated;

-- The operator's one switch for desktop and command-line assistants.
create or replace function public.instance_set_mcp_loopback_clients(p_enabled boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_before boolean;
begin
  perform public.instance_operator_require(true);
  if p_enabled is null then raise exception 'say on or off'; end if;
  select allow_loopback_clients into v_before from public.mcp_installation_settings for update;
  if v_before is distinct from p_enabled then
    update public.mcp_installation_settings set allow_loopback_clients = p_enabled where singleton;
    insert into public.database_authority_audit (installation_id, action, actor, detail)
    values (public.installation_id(),
            case when p_enabled then 'loopback_clients_allowed' else 'loopback_clients_disallowed' end,
            'instance:' || auth.uid(), '{}'::jsonb);
  end if;
  return jsonb_build_object('allow_loopback_clients', p_enabled,
                            'unchanged', v_before is not distinct from p_enabled);
end;
$fn$;
revoke execute on function public.instance_set_mcp_loopback_clients(boolean) from public, anon;
grant execute on function public.instance_set_mcp_loopback_clients(boolean) to authenticated;

-- 0343, restated: plus the loopback switch, the endpoint, and each
-- client's family and redirect hosts.
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
    'allow_loopback_clients', coalesce((select allow_loopback_clients
                                          from public.mcp_installation_settings), false),
    'endpoint', public.mcp_endpoint_resolved(),
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

-- 0358, restated: the client also names its family.
create or replace function public.mcp_consent_options(p_authorization_id text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_row record;
  v_ops text[];
  v_out jsonb := '[]'::jsonb;
  v_auth record;
  v_client record;
  v_status text;
  v_client_json jsonb;
  v_eligibility text;
  v_admin uuid;
  v_decider jsonb;
begin
  perform public.mcp_require_native();
  for v_row in
    select w.id, w.name, p.operations, p.optional_fields
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
      v_out := v_out || jsonb_build_object('workspace_id', v_row.id, 'name', v_row.name, 'operations', to_jsonb(v_ops),
        'optional_fields', (select coalesce(jsonb_agg(f order by f), '[]'::jsonb) from unnest(v_row.optional_fields) f
                             where f = any (public.mcp_disclosure_ceiling())));
    end if;
  end loop;
  v_eligibility := public.my_database_capabilities()->>'mcp_eligibility';

  if p_authorization_id is not null then
    if p_authorization_id !~ '^[A-Za-z0-9]{32}$'
       or to_regclass('auth.oauth_authorizations') is null then
      raise exception 'oauth authorization unavailable';
    end if;
    execute 'select client_id, user_id, redirect_uri, status::text as status, expires_at
      from auth.oauth_authorizations where authorization_id = $1'
      into v_auth using p_authorization_id;
    if v_auth.client_id is null or v_auth.status <> 'pending' or v_auth.expires_at <= now()
       or (v_auth.user_id is not null and v_auth.user_id <> auth.uid()) then
      raise exception 'oauth authorization unavailable';
    end if;
    execute 'select client_name, redirect_uris::text as redirect_uris from auth.oauth_clients where id = $1'
      into v_client using v_auth.client_id;
    v_status := public.mcp_client_status(v_auth.client_id::text);
    v_client_json := jsonb_build_object(
      'client_id', v_auth.client_id::text,
      'name', coalesce((select name from public.mcp_clients where client_id = v_auth.client_id::text),
                       nullif(btrim(v_client.client_name), ''), v_auth.client_id::text),
      'status', v_status,
      'redirect_host', public.mcp_redirect_host(v_auth.redirect_uri),
      'family', public.mcp_client_family(v_client.redirect_uris));
  end if;

  -- The first open step that someone else decides.
  if v_status in ('waiting', 'blocked') then
    v_decider := public.mcp_operator_decider();
  elsif v_eligibility in ('not_requested', 'requested', 'expired') then
    select a.local_user_id into v_admin from public.database_administrators a
     where a.installation_id = public.installation_id() and a.status = 'active'
       and a.local_user_id <> auth.uid()
     order by a.granted_at, a.id limit 1;
    v_decider := case when v_admin is null then public.mcp_operator_decider()
                      else jsonb_build_object('kind', 'admin',
                             'display_name', public.mcp_person_name(v_admin), 'me', false) end;
  end if;

  return jsonb_build_object('eligibility', v_eligibility,
                            'workspaces', v_out,
                            'client', v_client_json,
                            'decider', v_decider);
end;
$fn$;
revoke execute on function public.mcp_consent_options(text) from public, anon;
grant execute on function public.mcp_consent_options(text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(356);
