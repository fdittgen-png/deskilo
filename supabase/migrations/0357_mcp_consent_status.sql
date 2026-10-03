-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0361 (#2145, S1 + S5) -- the consent page names the real cause at load,
-- and the app shows the endpoint the installation publishes.
--
-- S1. Until now `oauth_authorization_context` refused every assistant
-- client the operator had not approved ("oauth client purpose
-- unavailable"), so a member arriving from a freshly registered assistant
-- saw a generic error and nobody learned that a client was waiting.
--   * A DYNAMICALLY registered client (how assistants register, RFC 7591)
--     now resolves to purpose `mcp` with `client_status` approved,
--     waiting (no decision yet) or blocked (the operator revoked it).
--     Nothing is approved here: `mcp_prepare_connection` and the facade
--     still refuse every client that is not active. A manually registered
--     client the registries do not know still fails closed, as in 0297.
--   * The first time a member of an mcpAccess workspace arrives with a
--     waiting client, the arrival is audited (`client_waiting`) and every
--     instance operator (owner and active delegates) gets an
--     installation notice. Once per client: DCR churn cannot flood them.
--   * `mcp_consent_options(p_authorization_id)` adds, for that pending
--     authorization, the client (name, status, redirect host) and the
--     DECIDER of the first open step: the operator for a client that is
--     not approved, a database administrator for eligibility (the
--     operator when no other administrator exists).
--
-- Installation notices are a new, minimal inbox for people who answer for
-- the installation rather than one workspace: `instance_notices`, read
-- through `my_instance_notices()` and `mark_instance_notice_read(id)`.
-- No client may write the table. Read notices are kept 90 days.
--
-- S5. `mcp_endpoint()` answers the canonical MCP resource (the URL an
-- assistant is given) to the instance operator and to active members of a
-- workspace where mcpAccess is on: the operator-configured URL when set
-- (`instance_set_mcp_endpoint`, `operator_set_mcp_endpoint`), else the
-- one derived from this database's functions URL, and says which.

-- ── installation notices ─────────────────────────────────────────────

create table if not exists public.instance_notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind ~ '^[a-z][a-z_]{2,63}$'),
  subject text not null check (length(subject) between 1 and 200),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique (user_id, kind, subject)
);
select public.ensure_system_columns('instance_notices');
create index if not exists instance_notices_recipient
  on public.instance_notices (user_id, created_at desc);
alter table public.instance_notices enable row level security;
revoke all on table public.instance_notices from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.instance_notices;
create policy mcp_delegated_deny on public.instance_notices as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- One notice per operator (owner and active delegates), once per subject.
create or replace function public.instance_notify_operators(
  p_kind text, p_subject text, p_payload jsonb, p_except uuid default null)
returns integer language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count integer;
begin
  delete from public.instance_notices
   where read_at is not null and read_at < now() - interval '90 days';
  insert into public.instance_notices (user_id, kind, subject, payload)
  select r.user_id, p_kind, p_subject, coalesce(p_payload, '{}'::jsonb)
    from (select user_id from public.platform_admins
          union
          select user_id from public.instance_delegates where status = 'active') r
   where p_except is null or r.user_id <> p_except
  on conflict (user_id, kind, subject) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;
revoke execute on function public.instance_notify_operators(text, text, jsonb, uuid) from public, anon, authenticated;

create or replace function public.my_instance_notices()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  return jsonb_build_object(
    'unread', (select count(*) from public.instance_notices
                where user_id = auth.uid() and read_at is null),
    'notices', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', n.id, 'kind', n.kind, 'subject', n.subject, 'payload', n.payload,
               'created_at', n.created_at, 'read_at', n.read_at)
             order by n.created_at desc, n.id)
        from (select * from public.instance_notices
               where user_id = auth.uid()
               order by created_at desc, id limit 50) n), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.my_instance_notices() from public, anon;
grant execute on function public.my_instance_notices() to authenticated;

-- One notice, or every unread one when p_id is null.
create or replace function public.mark_instance_notice_read(p_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count integer;
begin
  perform public.mcp_require_native();
  update public.instance_notices set read_at = now()
   where user_id = auth.uid() and read_at is null and (p_id is null or id = p_id);
  get diagnostics v_count = row_count;
  delete from public.instance_notices
   where user_id = auth.uid() and read_at is not null and read_at < now() - interval '90 days';
  return jsonb_build_object('status', case when v_count > 0 then 'read' else 'unchanged' end,
                            'count', v_count);
end;
$fn$;
revoke execute on function public.mark_instance_notice_read(uuid) from public, anon;
grant execute on function public.mark_instance_notice_read(uuid) to authenticated;

-- ── who decides, by name ─────────────────────────────────────────────

create or replace function public.mcp_person_name(p_user uuid)
returns text language sql stable security definer set search_path = public, auth as $fn$
  -- The person, never the company their profile invoices as.
  select coalesce(nullif(public.profile_person_name(p), ''), nullif(btrim(p.display_name), ''),
                  split_part(u.email, '@', 1))
    from auth.users u left join public.profiles p on p.id = u.id
   where u.id = p_user;
$fn$;
revoke execute on function public.mcp_person_name(uuid) from public, anon, authenticated;

-- The operator a member is told to ask: the first owner, else the first
-- active delegate. Null on an installation nobody answers for yet.
create or replace function public.mcp_operator_decider()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_user uuid;
begin
  select user_id into v_user from public.platform_admins order by added_at, user_id limit 1;
  if v_user is null then
    select user_id into v_user from public.instance_delegates
     where status = 'active' order by granted_at, user_id limit 1;
  end if;
  return jsonb_build_object('kind', 'operator',
                            'display_name', public.mcp_person_name(v_user),
                            'me', v_user is not null and v_user = auth.uid());
end;
$fn$;
revoke execute on function public.mcp_operator_decider() from public, anon, authenticated;

-- ── the client an authorization names ────────────────────────────────

-- host[:port] of an absolute URI, lower-cased, without user info.
create or replace function public.mcp_redirect_host(p_uri text)
returns text language sql immutable set search_path = public as $fn$
  select nullif(lower(regexp_replace(substring(p_uri from '^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]*)'),
                                     '^.*@', '')), '');
$fn$;
revoke execute on function public.mcp_redirect_host(text) from public, anon, authenticated;

-- approved | waiting | blocked: the operator's decision, or none yet.
create or replace function public.mcp_client_status(p_client_id text)
returns text language sql stable security definer set search_path = public as $fn$
  select coalesce((select case status when 'active' then 'approved' else 'blocked' end
                     from public.mcp_clients where client_id = p_client_id), 'waiting');
$fn$;
revoke execute on function public.mcp_client_status(text) from public, anon, authenticated;

-- A member arrived from this client. A waiting client is audited and the
-- operators are told, once. Answers the client's status.
create or replace function public.mcp_client_arrival(p_client_id text, p_name text, p_redirect_uri text)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_status text := public.mcp_client_status(p_client_id);
begin
  if v_status <> 'waiting' then return v_status; end if;
  -- Only someone an assistant could ever serve here raises the flag.
  if not exists (select 1 from public.members m
                  where m.user_id = auth.uid() and m.status = 'active'
                    and public.feature_effective(m.workspace_id, 'mcpAccess')) then
    return v_status;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('mcp_client_arrival|' || p_client_id, 2145));
  if not exists (select 1 from public.database_authority_audit
                  where action = 'client_waiting' and detail->>'client_id' = p_client_id) then
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
    values (public.installation_id(), 'client_waiting', 'member:' || auth.uid(), auth.uid(),
            jsonb_build_object('client_id', p_client_id, 'name', p_name,
                               'redirect_host', public.mcp_redirect_host(p_redirect_uri)));
    perform public.instance_notify_operators('mcp_client_waiting', p_client_id,
      jsonb_build_object('client_id', p_client_id, 'client_name', p_name,
                         'redirect_host', public.mcp_redirect_host(p_redirect_uri),
                         'requested_by', public.mcp_person_name(auth.uid())),
      null);
  end if;
  return v_status;
end;
$fn$;
revoke execute on function public.mcp_client_arrival(text, text, text) from public, anon, authenticated;

-- 0297, restated: a dynamically registered client resolves to purpose
-- `mcp` whatever the operator decided, with that decision as
-- `client_status`. VOLATILE now: an arrival may be recorded.
create or replace function public.oauth_authorization_context(p_authorization_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_auth record;
  v_client record;
  v_identity public.identity_federation_clients;
  v_scopes text[];
  v_status text;
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
      'client_id', v_auth.client_id, 'local_user_id', auth.uid(),
      'client_status', 'approved');
  end if;
  execute 'select registration_type::text as registration_type, client_name
    from auth.oauth_clients where id = $1 and deleted_at is null'
    into v_client using v_auth.client_id;
  if v_client.registration_type is distinct from 'dynamic' then
    raise exception 'oauth client purpose unavailable';
  end if;
  v_status := public.mcp_client_arrival(v_auth.client_id::text,
    coalesce(nullif(btrim(v_client.client_name), ''), v_auth.client_id::text),
    v_auth.redirect_uri);
  return jsonb_build_object('purpose', 'mcp',
    'client_id', v_auth.client_id, 'local_user_id', auth.uid(),
    'client_status', v_status);
end;
$$;
revoke execute on function public.oauth_authorization_context(text)
  from public, anon, service_role;
grant execute on function public.oauth_authorization_context(text) to authenticated;

-- ── consent options, with the client and who decides ─────────────────

drop function if exists public.mcp_consent_options();

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
    execute 'select client_name from auth.oauth_clients where id = $1'
      into v_client using v_auth.client_id;
    v_status := public.mcp_client_status(v_auth.client_id::text);
    v_client_json := jsonb_build_object(
      'client_id', v_auth.client_id::text,
      'name', coalesce((select name from public.mcp_clients where client_id = v_auth.client_id::text),
                       nullif(btrim(v_client.client_name), ''), v_auth.client_id::text),
      'status', v_status,
      'redirect_host', public.mcp_redirect_host(v_auth.redirect_uri));
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

-- ── S5: the endpoint the installation publishes ──────────────────────

create table if not exists public.mcp_installation_settings (
  singleton boolean primary key default true check (singleton),
  endpoint_url text check (endpoint_url ~ '^https://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$')
);
select public.ensure_system_columns('mcp_installation_settings');
insert into public.mcp_installation_settings (singleton) values (true) on conflict do nothing;
alter table public.mcp_installation_settings enable row level security;
revoke all on table public.mcp_installation_settings from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.mcp_installation_settings;
create policy mcp_delegated_deny on public.mcp_installation_settings as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.mcp_endpoint_resolved()
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
  return jsonb_build_object(
    'resource', v_url,
    'metadata_url', case when v_url is not null
                         then v_url || '/.well-known/oauth-protected-resource' end,
    'source', v_source);
end;
$fn$;
revoke execute on function public.mcp_endpoint_resolved() from public, anon, authenticated;

-- What an assistant is given, for whoever may connect one here.
create or replace function public.mcp_endpoint()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  if not public.is_instance_operator()
     and not exists (select 1 from public.members m
                      where m.user_id = auth.uid() and m.status = 'active'
                        and public.feature_effective(m.workspace_id, 'mcpAccess')) then
    raise exception 'assistants are not offered to you on this installation';
  end if;
  return public.mcp_endpoint_resolved();
end;
$fn$;
revoke execute on function public.mcp_endpoint() from public, anon;
grant execute on function public.mcp_endpoint() to authenticated;

create or replace function public.mcp_set_endpoint_internal(p_url text, p_actor text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_url text := nullif(rtrim(btrim(coalesce(p_url, '')), '/'), '');
begin
  if v_url is not null and v_url !~ '^https://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$' then
    raise exception 'the endpoint is an https URL without query or fragment';
  end if;
  update public.mcp_installation_settings set endpoint_url = v_url where singleton;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'endpoint_configured', p_actor,
          jsonb_build_object('endpoint_url', v_url));
  return public.mcp_endpoint_resolved();
end;
$fn$;
revoke execute on function public.mcp_set_endpoint_internal(text, text) from public, anon, authenticated;

-- The operator, in the app (aal2, audited); null returns to the derived URL.
create or replace function public.instance_set_mcp_endpoint(p_url text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.instance_operator_require(true);
  return public.mcp_set_endpoint_internal(p_url, 'instance:' || auth.uid());
end;
$fn$;
revoke execute on function public.instance_set_mcp_endpoint(text) from public, anon;
grant execute on function public.instance_set_mcp_endpoint(text) to authenticated;

-- The operator's tooling (service role / SQL owner).
create or replace function public.operator_set_mcp_endpoint(p_url text)
returns jsonb language sql volatile security definer set search_path = public as $fn$
  select public.mcp_set_endpoint_internal(p_url, 'operator');
$fn$;
revoke execute on function public.operator_set_mcp_endpoint(text) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(357);
