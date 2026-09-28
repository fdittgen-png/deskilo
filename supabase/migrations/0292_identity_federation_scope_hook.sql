-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1648: canonical identity clients are distinct from business MCP clients.
-- A provider's default scopes are overridable by the authorization request.
-- This supported Custom Access Token Hook enforces the restriction at issuance,
-- before Auth creates the ID token. It MUST be installed/read back before a
-- participating provider is activated. Existing token containment still applies.

create table public.identity_federation_clients (
  client_id uuid primary key,
  target_installation_id uuid not null,
  target_auth_url text not null check (target_auth_url ~
    '^(https://[^/@?#[:space:]]+|http://(127[.]0[.]0[.]1|localhost)(:[0-9]+)?)(/[A-Za-z0-9._~-]+)*$'),
  purpose text not null default 'identity_federation'
    check (purpose = 'identity_federation'),
  enabled boolean not null default false
);
select public.ensure_system_columns('identity_federation_clients');
alter table public.identity_federation_clients enable row level security;
revoke all on public.identity_federation_clients from public, anon, authenticated, service_role;
create policy mcp_delegated_deny on public.identity_federation_clients
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create function public.protect_identity_federation_client()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'identity clients are disabled, never forgotten';
  end if;
  if new.client_id <> old.client_id or
     new.target_installation_id <> old.target_installation_id or
     new.target_auth_url <> old.target_auth_url or new.purpose <> old.purpose then
    raise exception 'identity client target is immutable';
  end if;
  return new;
end;
$$;
revoke execute on function public.protect_identity_federation_client() from public, anon, authenticated;
create trigger protect_identity_federation_client
  before update or delete on public.identity_federation_clients
  for each row execute function public.protect_identity_federation_client();

-- These are infrastructure-operator functions, never application-admin RPCs.
create function public.operator_register_identity_federation_client(
  p_client_id uuid, p_target_installation_id uuid, p_target_auth_url text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_existing public.identity_federation_clients;
begin
  insert into public.identity_federation_clients
    (client_id, target_installation_id, target_auth_url)
  values (p_client_id, p_target_installation_id, p_target_auth_url)
  on conflict (client_id) do nothing;
  select * into strict v_existing from public.identity_federation_clients
    where client_id = p_client_id;
  if v_existing.target_installation_id <> p_target_installation_id or
     v_existing.target_auth_url <> p_target_auth_url then
    raise exception 'identity client target is immutable';
  end if;
end;
$$;
revoke execute on function public.operator_register_identity_federation_client(uuid, uuid, text)
  from public, anon, authenticated, service_role;

create function public.operator_set_identity_federation_client(p_client_id uuid, p_enabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.identity_federation_clients set enabled = p_enabled
    where client_id = p_client_id;
  if not found then raise exception 'identity client not registered'; end if;
end;
$$;
revoke execute on function public.operator_set_identity_federation_client(uuid, boolean)
  from public, anon, authenticated, service_role;

-- Only the Auth service invokes this. It reads operator-owned configuration;
-- no decision comes from user_metadata. The claims (including client_id and
-- role) are preserved so the existing raw API guards cannot be stripped away.
create function public.identity_federation_token_hook(event jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_claims jsonb := event->'claims';
  v_client text := v_claims->>'client_id';
  v_enabled boolean;
  v_scopes text[];
begin
  if jsonb_typeof(v_claims) is distinct from 'object' then
    raise sqlstate '28000' using message = 'invalid_identity_token_event';
  end if;
  if v_client is null then return jsonb_build_object('claims', v_claims); end if;
  select enabled into v_enabled from public.identity_federation_clients
    where client_id = v_client::uuid;
  if not found then return jsonb_build_object('claims', v_claims); end if;
  if not v_enabled then
    raise sqlstate '28000' using message = 'identity_client_disabled';
  end if;
  if jsonb_typeof(v_claims->'scope') is distinct from 'string' then
    raise sqlstate '28000' using message = 'identity_client_scope_refused';
  end if;
  v_scopes := regexp_split_to_array(btrim(v_claims->>'scope'), '[[:space:]]+');
  if not ('openid' = any(v_scopes)) or not (v_scopes <@ array['openid', 'profile']) then
    raise sqlstate '28000' using message = 'identity_client_scope_refused';
  end if;
  return jsonb_build_object('claims', v_claims);
end;
$$;
revoke execute on function public.identity_federation_token_hook(jsonb)
  from public, anon, authenticated, service_role;
grant usage on schema public to supabase_auth_admin;
grant execute on function public.identity_federation_token_hook(jsonb) to supabase_auth_admin;

select public.set_deskilo_schema_version(0292);
