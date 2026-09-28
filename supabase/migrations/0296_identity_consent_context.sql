-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1648: resolve native consent purpose before Auth can auto-approve a request.
-- Identity clients must never also be business MCP clients, even when disabled.
do $$
begin
  if exists (select 1 from public.identity_federation_clients i
    join public.mcp_clients m on lower(m.client_id) = i.client_id::text) then
    raise exception 'oauth client purposes overlap';
  end if;
end;
$$;

create function public.guard_oauth_client_purpose()
returns trigger language plpgsql set search_path = '' as $$
declare v_client text := lower(new.client_id::text);
begin
  -- Serialize both registries: simultaneous operator registrations cannot
  -- each observe the other table empty and claim the same client.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('deskilo-oauth-purpose:' || v_client, 0));
  if (tg_table_name = 'mcp_clients' and exists (
      select 1 from public.identity_federation_clients where client_id::text = v_client))
    or (tg_table_name = 'identity_federation_clients' and exists (
      select 1 from public.mcp_clients where lower(client_id) = v_client)) then
    raise exception 'oauth client purpose is already reserved';
  end if;
  return new;
end;
$$;
revoke execute on function public.guard_oauth_client_purpose()
  from public, anon, authenticated, service_role;
create trigger guard_oauth_client_purpose before insert or update
  on public.identity_federation_clients for each row
  execute function public.guard_oauth_client_purpose();
create trigger guard_oauth_client_purpose before insert or update
  on public.mcp_clients for each row execute function public.guard_oauth_client_purpose();

create function public.oauth_authorization_context(p_authorization_id text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_auth record;
  v_identity public.identity_federation_clients;
  v_scopes text[];
begin
  perform public.mcp_require_native();
  if p_authorization_id is null or p_authorization_id !~ '^[A-Za-z0-9]{32}$' then
    raise exception 'oauth authorization unavailable';
  end if;
  if pg_catalog.to_regclass('auth.oauth_authorizations') is null then
    raise exception 'oauth authorization unsupported';
  end if;
  -- Dynamic lookup keeps installation on older Auth honest: unsupported at
  -- invocation, without inventing or modifying Auth-owned tables.
  execute 'select client_id, user_id, redirect_uri, scope, status::text,
      expires_at, resource, code_challenge, code_challenge_method::text
    from auth.oauth_authorizations where authorization_id = $1'
    into v_auth using p_authorization_id;
  if v_auth.client_id is null or v_auth.status <> 'pending'
    or v_auth.expires_at <= now()
    or (v_auth.user_id is not null and v_auth.user_id <> auth.uid()) then
    raise exception 'oauth authorization unavailable';
  end if;
  select * into v_identity from public.identity_federation_clients
    where client_id = v_auth.client_id;
  if found then
    v_scopes := regexp_split_to_array(btrim(v_auth.scope), '[[:space:]]+');
    if not v_identity.enabled or
      v_auth.redirect_uri <> v_identity.target_auth_url || '/callback' or
      not ('openid' = any(v_scopes)) or
      not (v_scopes <@ array['openid', 'profile']) or
      v_auth.resource is not null or
      nullif(v_auth.code_challenge, '') is null or
      v_auth.code_challenge_method is distinct from 's256' then
      raise exception 'identity authorization refused';
    end if;
    return jsonb_build_object('purpose', 'identity_federation',
      'client_id', v_identity.client_id, 'local_user_id', auth.uid(),
      'target_installation_id', v_identity.target_installation_id,
      'target_auth_url', v_identity.target_auth_url);
  end if;
  if exists (select 1 from public.mcp_clients
    where client_id = v_auth.client_id::text and status = 'active') then
    return jsonb_build_object('purpose', 'mcp',
      'client_id', v_auth.client_id, 'local_user_id', auth.uid());
  end if;
  raise exception 'oauth client purpose unavailable';
end;
$$;
revoke execute on function public.oauth_authorization_context(text)
  from public, anon, service_role;
grant execute on function public.oauth_authorization_context(text) to authenticated;

select public.set_deskilo_schema_version(0296);
