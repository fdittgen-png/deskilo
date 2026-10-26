-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2370 — the accounting interface: a connection per issuer and target, its
-- secrets in Vault, the mappings a delivery reads, and one delivery row per
-- document and target.
--
--   accounting_connections   an issuer's link to one API target (Pennylane,
--                            later QuickBooks, Xero, Sage, Business Central):
--                            the remote company, the state the screen shows
--                            (pending, connected, expired, revoked, error) and
--                            never a secret. The OAuth tokens or the pasted
--                            API token live in Vault under
--                            accounting:<connection>:<key>; only the service
--                            role resolves them.
--   accounting_maps          per connection, what a delivery needs named on
--                            the other side: a book role → a remote account,
--                            a tax component key → a remote tax code, a member
--                            or site → a remote customer, a revenue role → a
--                            remote item. A delivery with an unmapped key
--                            blocks with the key named; nothing is defaulted.
--   accounting_deliveries    one row per (connection or file target, issuer,
--                            document event): the payload sha256, the stable
--                            idempotency key, the remote id/number/version and
--                            the status generated|sent|acknowledged|conflict|
--                            failed. A file delivery points at the
--                            book_exports row of the file that carried it.
--
-- The stable identity of a delivery is the connection (or the file target and
-- the issuer), the document event kind, the document id and the event day.
-- No profile revision or mapping change makes a new identity: a changed
-- digest on an acknowledged delivery is refused, never created twice. A
-- connection's remote company cannot change once a delivery or a mapping
-- exists; switching company is a new connection.
--
--   accounting_connections_v1 / accounting_transfers_v1   readers
--   open_ / revoke_accounting_connection_v1, set_accounting_token_v1,
--   save_ / delete_accounting_map_v1                       manageBilling
--   record_file_deliveries_v1                              exportData
--   set_accounting_credentials, accounting_credentials_resolved,
--   record_accounting_delivery                             service role only
--
-- Every client entry point needs the accountingConnectors flag (child of
-- accountingBook). record_book_export_v1 is restated so the export log also
-- records while connectors are on, since a file delivery points at it.

-- ── the tables ────────────────────────────────────────────────────────────
create table public.accounting_connections (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  issuer_site_id uuid not null references public.sites(id) on delete restrict,
  target_id text not null check (target_id ~ '^[a-z0-9_]{1,60}$'),
  auth_kind text not null check (auth_kind in ('oauth2', 'token')),
  remote_tenant_id text not null default '' check (char_length(remote_tenant_id) <= 200),
  display_name text not null default '' check (char_length(display_name) <= 120),
  status text not null default 'pending'
    check (status in ('pending', 'connected', 'expired', 'revoked', 'error')),
  status_detail text not null default '' check (char_length(status_detail) <= 500),
  scopes text[] not null default '{}',
  connected_by_member_id uuid references public.members(id) on delete set null,
  connected_at timestamptz,
  token_expires_at timestamptz,
  refresh_expires_at timestamptz,
  revoked_at timestamptz,
  check ((status = 'revoked') = (revoked_at is not null))
);
select public.ensure_system_columns('accounting_connections');
-- One live connection per issuer and target; a revoked one stays beside it.
create unique index accounting_connections_live
  on public.accounting_connections (issuer_site_id, target_id) where revoked_at is null;
create index accounting_connections_workspace on public.accounting_connections (workspace_id);

create table public.accounting_maps (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  connection_id uuid not null references public.accounting_connections(id) on delete cascade,
  map_kind text not null check (map_kind in ('account', 'tax', 'party', 'item')),
  map_key text not null check (char_length(map_key) between 1 and 200),
  remote_id text not null default '' check (char_length(remote_id) <= 200),
  remote_code text not null default '' check (char_length(remote_code) <= 100),
  remote_name text not null default '' check (char_length(remote_name) <= 200),
  check (remote_id <> '' or remote_code <> ''),
  constraint accounting_maps_key unique (connection_id, map_kind, map_key)
);
select public.ensure_system_columns('accounting_maps');
create index accounting_maps_workspace on public.accounting_maps (workspace_id);

create table public.accounting_deliveries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  issuer_site_id uuid not null references public.sites(id) on delete restrict,
  connection_id uuid references public.accounting_connections(id) on delete restrict,
  target_id text not null check (target_id ~ '^[a-z0-9_]{1,60}$'),
  book_export_id uuid references public.book_exports(id) on delete restrict,
  identity_key text not null check (char_length(identity_key) between 1 and 400),
  idempotency_key text not null check (idempotency_key ~ '^[0-9a-f]{64}$'),
  period_from date not null,
  period_to date not null,
  document_kind text not null check (document_kind ~ '^[a-z_]{1,40}$'),
  document_id uuid not null,
  document_number text not null default '' check (char_length(document_number) <= 100),
  event_date date not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  remote_id text not null default '' check (char_length(remote_id) <= 200),
  remote_number text not null default '' check (char_length(remote_number) <= 100),
  remote_version text not null default '' check (char_length(remote_version) <= 200),
  remote_state text not null default '' check (remote_state in ('', 'draft', 'posted')),
  status text not null check (status in ('generated', 'sent', 'acknowledged', 'conflict', 'failed')),
  error text not null default '' check (char_length(error) <= 1000),
  attempts int not null default 1 check (attempts >= 1),
  sent_at timestamptz,
  acknowledged_at timestamptz,
  recorded_by_member_id uuid references public.members(id) on delete set null,
  check (period_to >= period_from),
  -- a connection delivery or a file delivery, never both, never neither
  check ((connection_id is null) <> (book_export_id is null)),
  check (status <> 'acknowledged' or (remote_id <> '' and acknowledged_at is not null)),
  constraint accounting_deliveries_identity unique (workspace_id, identity_key)
);
select public.ensure_system_columns('accounting_deliveries');
create index accounting_deliveries_period on public.accounting_deliveries (workspace_id, event_date);
create index accounting_deliveries_export on public.accounting_deliveries (book_export_id);
create index accounting_deliveries_connection on public.accounting_deliveries (connection_id);

-- ── who reads them ────────────────────────────────────────────────────────
-- The finances' readers, the exporters and the billing managers: the same
-- audience as the export log (0504), plus who connects.
create or replace function public.accounting_reader(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.is_owner_of(p_workspace_id)
      or p_workspace_id in (select public.workspaces_permitting(array['viewFinances', 'exportData', 'manageBilling']));
$fn$;
revoke execute on function public.accounting_reader(uuid) from public, anon;
grant execute on function public.accounting_reader(uuid) to authenticated;

alter table public.accounting_connections enable row level security;
alter table public.accounting_maps enable row level security;
alter table public.accounting_deliveries enable row level security;
revoke all on public.accounting_connections, public.accounting_maps, public.accounting_deliveries
  from public, anon, authenticated;
grant select on public.accounting_connections, public.accounting_maps, public.accounting_deliveries
  to authenticated;
create policy accounting_connections_select on public.accounting_connections for select to authenticated
  using (public.accounting_reader(workspace_id));
create policy accounting_maps_select on public.accounting_maps for select to authenticated
  using (public.accounting_reader(workspace_id));
create policy accounting_deliveries_select on public.accounting_deliveries for select to authenticated
  using (public.accounting_reader(workspace_id));
create policy mcp_delegated_deny on public.accounting_connections as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.accounting_maps as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.accounting_deliveries as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the remote company holds still ────────────────────────────────────────
-- Once a delivery or a mapping names the remote company, relabelling the
-- connection would move acknowledged records to another company: refused.
create or replace function public.accounting_connection_tenant_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.remote_tenant_id <> '' and new.remote_tenant_id is distinct from old.remote_tenant_id
     and (exists (select 1 from public.accounting_deliveries d where d.connection_id = old.id)
          or exists (select 1 from public.accounting_maps m where m.connection_id = old.id)) then
    raise exception 'this connection already delivered or mapped for its company: connect the other company as a new connection'
      using errcode = '23514';
  end if;
  if new.issuer_site_id is distinct from old.issuer_site_id or new.target_id is distinct from old.target_id
     or new.workspace_id is distinct from old.workspace_id then
    raise exception 'a connection keeps its issuer and its target' using errcode = '23514';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.accounting_connection_tenant_guard() from public, anon, authenticated;
create trigger accounting_connection_tenant_guard before update on public.accounting_connections
  for each row execute function public.accounting_connection_tenant_guard();

-- ── the secrets, in Vault ─────────────────────────────────────────────────
create or replace function public.accounting_secret_name(p_connection_id uuid, p_key text)
returns text language sql immutable as $fn$
  select 'accounting:' || p_connection_id::text || ':' || p_key;
$fn$;
revoke execute on function public.accounting_secret_name(uuid, text) from public, anon, authenticated;

-- Stores, replaces or (an empty value) deletes one secret of a connection.
create or replace function public.accounting_store_secret(p_connection_id uuid, p_key text, p_value text)
returns void language plpgsql security definer set search_path = public, vault as $fn$
declare
  v_name text := public.accounting_secret_name(p_connection_id, p_key);
  v_id uuid;
begin
  if p_key !~ '^[a-z_]{1,40}$' then
    raise exception 'unknown credential key' using errcode = '22023';
  end if;
  select id into v_id from vault.secrets where name = v_name;
  if coalesce(p_value, '') = '' then
    delete from vault.secrets where id = v_id;
  elsif v_id is null then
    perform vault.create_secret(p_value, v_name, 'DesKilo accounting connection credential');
  else
    perform vault.update_secret(v_id, p_value);
  end if;
end;
$fn$;
revoke execute on function public.accounting_store_secret(uuid, text, text) from public, anon, authenticated;

create or replace function public.clear_accounting_credentials(p_connection_id uuid)
returns void language plpgsql security definer set search_path = public, vault as $fn$
begin
  delete from vault.secrets where name like public.accounting_secret_name(p_connection_id, '') || '%';
end;
$fn$;
revoke execute on function public.clear_accounting_credentials(uuid) from public, anon, authenticated;

-- The names of the secrets a connection holds, never their values.
create or replace function public.accounting_secret_keys(p_connection_id uuid)
returns jsonb language sql stable security definer set search_path = public, vault as $fn$
  select coalesce(jsonb_agg(substr(s.name, char_length(public.accounting_secret_name(p_connection_id, '')) + 1)
                            order by s.name), '[]'::jsonb)
    from vault.secrets s
   where s.name like public.accounting_secret_name(p_connection_id, '') || '%';
$fn$;
revoke execute on function public.accounting_secret_keys(uuid) from public, anon, authenticated;

-- The one writer of the edge function (service role): secrets (an empty
-- value removes one) and the connection's state after an OAuth exchange, a
-- refresh or a refused refresh. A revoked connection takes nothing.
create or replace function public.set_accounting_credentials(
  p_connection_id uuid, p_secrets jsonb, p_patch jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_entry record;
  v_status text;
begin
  select * into c from public.accounting_connections where id = p_connection_id for update;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  if c.revoked_at is not null then raise exception 'this connection was revoked' using errcode = '23514'; end if;
  for v_entry in select key, value from jsonb_each(coalesce(p_secrets, '{}'::jsonb)) loop
    perform public.accounting_store_secret(p_connection_id, v_entry.key, v_entry.value #>> '{}');
  end loop;
  v_status := coalesce(p_patch ->> 'status', c.status);
  if v_status = 'revoked' then
    raise exception 'a connection is revoked by its manager' using errcode = '22023';
  end if;
  update public.accounting_connections set
    status = v_status,
    status_detail = coalesce(p_patch ->> 'status_detail', case when v_status = c.status then c.status_detail else '' end),
    remote_tenant_id = coalesce(p_patch ->> 'remote_tenant_id', c.remote_tenant_id),
    scopes = coalesce((select array_agg(x) from jsonb_array_elements_text(p_patch -> 'scopes') x), c.scopes),
    token_expires_at = case when p_patch ? 'token_expires_at'
                            then (p_patch ->> 'token_expires_at')::timestamptz else c.token_expires_at end,
    refresh_expires_at = case when p_patch ? 'refresh_expires_at'
                              then (p_patch ->> 'refresh_expires_at')::timestamptz else c.refresh_expires_at end,
    connected_at = case when v_status = 'connected' and c.status <> 'connected' then now() else c.connected_at end
  where id = p_connection_id
  returning * into c;
  return jsonb_build_object('id', c.id, 'status', c.status);
end;
$fn$;
revoke execute on function public.set_accounting_credentials(uuid, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.set_accounting_credentials(uuid, jsonb, jsonb) to service_role;

-- The connection with every secret decrypted: the only place a token is
-- plain text, for the service role alone.
create or replace function public.accounting_credentials_resolved(p_connection_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, vault as $fn$
declare
  c public.accounting_connections;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null then return null; end if;
  return jsonb_build_object(
    'id', c.id, 'workspace_id', c.workspace_id, 'issuer_site_id', c.issuer_site_id,
    'target_id', c.target_id, 'auth_kind', c.auth_kind, 'status', c.status,
    'remote_tenant_id', c.remote_tenant_id, 'revoked', c.revoked_at is not null,
    'token_expires_at', c.token_expires_at, 'refresh_expires_at', c.refresh_expires_at,
    'secrets', coalesce((
      select jsonb_object_agg(substr(s.name, char_length(public.accounting_secret_name(c.id, '')) + 1),
                              s.decrypted_secret)
        from vault.decrypted_secrets s
       where s.name like public.accounting_secret_name(c.id, '') || '%'), '{}'::jsonb));
end;
$fn$;
revoke execute on function public.accounting_credentials_resolved(uuid) from public, anon, authenticated;
grant execute on function public.accounting_credentials_resolved(uuid) to service_role;

-- ── the client's doors ────────────────────────────────────────────────────
-- The active member acting in [p_workspace_id] once the flag is on and the
-- right is held; raises otherwise.
create or replace function public.accounting_connector_actor(p_workspace_id uuid, p_permission text)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member' using errcode = '42501'; end if;
  if not public.feature_effective(p_workspace_id, 'accountingConnectors') then
    raise exception 'accounting connections are switched off in this space' using errcode = '0A000';
  end if;
  if p_permission = 'read' then
    if not public.accounting_reader(p_workspace_id) then
      raise exception 'you may not read the accounting transfers' using errcode = '42501';
    end if;
  elsif not public.has_permission(p_workspace_id, p_permission) then
    raise exception 'you may not do this for the books' using errcode = '42501';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.accounting_connector_actor(uuid, text) from public, anon, authenticated;

create or replace function public.accounting_connection_json(c public.accounting_connections)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', c.id, 'issuer_site_id', c.issuer_site_id, 'target_id', c.target_id,
    'auth_kind', c.auth_kind, 'remote_tenant_id', c.remote_tenant_id,
    'display_name', c.display_name, 'status', c.status, 'status_detail', c.status_detail,
    'scopes', to_jsonb(c.scopes), 'connected_at', c.connected_at,
    'token_expires_at', c.token_expires_at, 'refresh_expires_at', c.refresh_expires_at,
    'revoked_at', c.revoked_at,
    'secrets_set', public.accounting_secret_keys(c.id),
    'maps', coalesce((select jsonb_agg(jsonb_build_object(
                         'id', m.id, 'kind', m.map_kind, 'key', m.map_key, 'remote_id', m.remote_id,
                         'remote_code', m.remote_code, 'remote_name', m.remote_name)
                       order by m.map_kind, m.map_key)
                       from public.accounting_maps m where m.connection_id = c.id), '[]'::jsonb));
$fn$;
revoke execute on function public.accounting_connection_json(public.accounting_connections) from public, anon, authenticated;

create or replace function public.accounting_connections_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.accounting_connector_actor(p_workspace_id, 'read');
  return coalesce((select jsonb_agg(public.accounting_connection_json(c)
                                    order by c.revoked_at nulls first, c.created_datetime desc)
                     from public.accounting_connections c where c.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.accounting_connections_v1(uuid) from public, anon;
grant execute on function public.accounting_connections_v1(uuid) to authenticated;

-- The edge function asks, with the caller's own token, whether the caller
-- may connect this connection; the answer names what it needs.
create or replace function public.accounting_connection_manageable_v1(p_connection_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');
  if c.revoked_at is not null then raise exception 'this connection was revoked' using errcode = '23514'; end if;
  return jsonb_build_object('id', c.id, 'workspace_id', c.workspace_id, 'target_id', c.target_id,
                            'auth_kind', c.auth_kind, 'status', c.status);
end;
$fn$;
revoke execute on function public.accounting_connection_manageable_v1(uuid) from public, anon;
grant execute on function public.accounting_connection_manageable_v1(uuid) to authenticated;

create or replace function public.open_accounting_connection_v1(
  p_workspace_id uuid, p_issuer_site_id uuid, p_target_id text, p_auth_kind text, p_display_name text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.accounting_connector_actor(p_workspace_id, 'manageBilling');
  c public.accounting_connections;
begin
  if not exists (select 1 from public.sites s where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this space' using errcode = '22023';
  end if;
  if exists (select 1 from public.accounting_connections x
              where x.issuer_site_id = p_issuer_site_id and x.target_id = btrim(p_target_id)
                and x.revoked_at is null) then
    raise exception 'this issuer is already connected to this target: revoke it first' using errcode = '23505';
  end if;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, display_name, connected_by_member_id)
  values (p_workspace_id, p_issuer_site_id, btrim(p_target_id), p_auth_kind,
          btrim(coalesce(p_display_name, '')), v_me)
  returning * into c;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.open_accounting_connection_v1(uuid, uuid, text, text, text) from public, anon;
grant execute on function public.open_accounting_connection_v1(uuid, uuid, text, text, text) to authenticated;

-- A target reached with an API token the person creates in the target
-- (Pennylane's company token): stored in Vault, never echoed back.
create or replace function public.set_accounting_token_v1(
  p_connection_id uuid, p_token text, p_remote_tenant_id text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_me uuid;
begin
  select * into c from public.accounting_connections where id = p_connection_id for update;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  v_me := public.accounting_connector_actor(c.workspace_id, 'manageBilling');
  if c.revoked_at is not null then raise exception 'this connection was revoked' using errcode = '23514'; end if;
  if c.auth_kind <> 'token' then
    raise exception 'this target is connected by signing in to it, not by a token' using errcode = '22023';
  end if;
  if char_length(btrim(coalesce(p_token, ''))) not between 8 and 4000 then
    raise exception 'paste the whole token' using errcode = '22023';
  end if;
  perform public.accounting_store_secret(c.id, 'access_token', btrim(p_token));
  update public.accounting_connections
     set status = 'connected', status_detail = '', connected_at = now(), connected_by_member_id = v_me,
         remote_tenant_id = coalesce(nullif(btrim(coalesce(p_remote_tenant_id, '')), ''), c.remote_tenant_id)
   where id = c.id
  returning * into c;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.set_accounting_token_v1(uuid, text, text) from public, anon;
grant execute on function public.set_accounting_token_v1(uuid, text, text) to authenticated;

-- Revoking forgets the secrets and keeps the deliveries and the mappings.
create or replace function public.revoke_accounting_connection_v1(p_connection_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
begin
  select * into c from public.accounting_connections where id = p_connection_id for update;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');
  if c.revoked_at is not null then return public.accounting_connection_json(c); end if;
  perform public.clear_accounting_credentials(c.id);
  update public.accounting_connections
     set status = 'revoked', status_detail = '', revoked_at = now()
   where id = c.id
  returning * into c;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.revoke_accounting_connection_v1(uuid) from public, anon;
grant execute on function public.revoke_accounting_connection_v1(uuid) to authenticated;

-- The shape of a mapping key, per kind: a book role with its qualifier, a
-- tax component key `scheme|authority|treatment|rate|version`, a member,
-- site or supplier by id, a revenue role.
create or replace function public.accounting_map_key_valid(p_kind text, p_key text)
returns boolean language sql immutable as $fn$
  select case p_kind
    when 'account' then p_key ~ '^[a-z_]{1,40}(:[A-Za-z0-9_.-]{1,60})?$'
    when 'item' then p_key ~ '^[a-z_]{1,40}(:[A-Za-z0-9_.-]{1,60})?$'
    when 'tax' then p_key ~ '^[A-Z][A-Z0-9_]{0,15}\|[A-Z]{2}(-[A-Z0-9]{1,3})?\|(taxed|zeroRated|exempt|outOfScope|reverseCharge)\|[0-9]{1,3}(\.[0-9]{1,4})?\|[A-Za-z0-9_.:-]{0,60}$'
    when 'party' then p_key ~ '^(member|site|supplier):[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    else false end;
$fn$;
revoke execute on function public.accounting_map_key_valid(text, text) from public, anon, authenticated;

create or replace function public.save_accounting_map_v1(
  p_connection_id uuid, p_kind text, p_key text, p_remote_id text, p_remote_code text, p_remote_name text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_key text := btrim(coalesce(p_key, ''));
  v_party uuid;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');
  if c.revoked_at is not null then raise exception 'this connection was revoked' using errcode = '23514'; end if;
  if not public.accounting_map_key_valid(p_kind, v_key) then
    raise exception 'not a % key: %', p_kind, v_key using errcode = '22023';
  end if;
  if p_kind = 'party' then
    v_party := split_part(v_key, ':', 2)::uuid;
    if not (exists (select 1 from public.members m where m.id = v_party and m.workspace_id = c.workspace_id)
            or exists (select 1 from public.sites s where s.id = v_party and s.workspace_id = c.workspace_id)
            or exists (select 1 from public.suppliers s where s.id = v_party and s.workspace_id = c.workspace_id)) then
      raise exception 'this party is not of this space' using errcode = '22023';
    end if;
  end if;
  if btrim(coalesce(p_remote_id, '')) = '' and btrim(coalesce(p_remote_code, '')) = '' then
    raise exception 'name the remote account, code or id' using errcode = '22023';
  end if;
  insert into public.accounting_maps
    (workspace_id, connection_id, map_kind, map_key, remote_id, remote_code, remote_name)
  values (c.workspace_id, c.id, p_kind, v_key, btrim(coalesce(p_remote_id, '')),
          btrim(coalesce(p_remote_code, '')), btrim(coalesce(p_remote_name, '')))
  on conflict (connection_id, map_kind, map_key) do update
    set remote_id = excluded.remote_id, remote_code = excluded.remote_code, remote_name = excluded.remote_name;
  select * into c from public.accounting_connections where id = c.id;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.save_accounting_map_v1(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.save_accounting_map_v1(uuid, text, text, text, text, text) to authenticated;

create or replace function public.delete_accounting_map_v1(p_map_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  m public.accounting_maps;
  c public.accounting_connections;
begin
  select * into m from public.accounting_maps where id = p_map_id;
  if m.id is null then raise exception 'unknown mapping' using errcode = 'P0002'; end if;
  perform public.accounting_connector_actor(m.workspace_id, 'manageBilling');
  delete from public.accounting_maps where id = m.id;
  select * into c from public.accounting_connections where id = m.connection_id;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.delete_accounting_map_v1(uuid) from public, anon;
grant execute on function public.delete_accounting_map_v1(uuid) to authenticated;

-- ── deliveries ────────────────────────────────────────────────────────────
create or replace function public.accounting_idempotency_key(p_identity text)
returns text language sql immutable as $fn$
  select encode(sha256(convert_to(p_identity, 'UTF8')), 'hex');
$fn$;
revoke execute on function public.accounting_idempotency_key(text) from public, anon, authenticated;

create or replace function public.accounting_delivery_json(d public.accounting_deliveries)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', d.id, 'issuer_site_id', d.issuer_site_id, 'connection_id', d.connection_id,
    'target_id', d.target_id, 'book_export_id', d.book_export_id,
    'idempotency_key', d.idempotency_key, 'period_from', d.period_from, 'period_to', d.period_to,
    'document_kind', d.document_kind, 'document_id', d.document_id,
    'document_number', d.document_number, 'event_date', d.event_date,
    'payload_sha256', d.payload_sha256, 'remote_id', d.remote_id, 'remote_number', d.remote_number,
    'remote_version', d.remote_version, 'remote_state', d.remote_state, 'status', d.status,
    'error', d.error, 'attempts', d.attempts, 'sent_at', d.sent_at,
    'acknowledged_at', d.acknowledged_at, 'recorded_by_member_id', d.recorded_by_member_id,
    'recorded_at', d.created_datetime);
$fn$;
revoke execute on function public.accounting_delivery_json(public.accounting_deliveries) from public, anon, authenticated;

-- The documents a file carried, one delivery each. The same document in a
-- later file with the same digest changes nothing; with another digest the
-- row follows the newer file. Answers what each document became.
create or replace function public.record_file_deliveries_v1(
  p_workspace_id uuid, p_target_id text, p_issuer_site_id uuid, p_book_export_id uuid,
  p_documents jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.accounting_connector_actor(p_workspace_id, 'exportData');
  x public.book_exports;
  v_doc jsonb;
  v_identity text;
  d public.accounting_deliveries;
  v_sha text;
  v_created int := 0;
  v_unchanged int := 0;
  v_changed int := 0;
begin
  select * into x from public.book_exports e where e.id = p_book_export_id and e.workspace_id = p_workspace_id;
  if x.id is null then raise exception 'unknown export of this space' using errcode = '22023'; end if;
  if x.format_id <> btrim(p_target_id) then
    raise exception 'the export was written for another target' using errcode = '22023';
  end if;
  if not exists (select 1 from public.sites s where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this space' using errcode = '22023';
  end if;
  if jsonb_typeof(p_documents) is distinct from 'array' then
    raise exception 'the documents are a list' using errcode = '22023';
  end if;
  for v_doc in select value from jsonb_array_elements(p_documents) loop
    v_sha := lower(v_doc ->> 'sha256');
    v_identity := 'f:' || x.format_id || ':' || p_issuer_site_id || ':' || (v_doc ->> 'kind') || ':'
                  || (v_doc ->> 'id') || ':' || (v_doc ->> 'date');
    select * into d from public.accounting_deliveries
     where workspace_id = p_workspace_id and identity_key = v_identity for update;
    if d.id is null then
      insert into public.accounting_deliveries
        (workspace_id, issuer_site_id, target_id, book_export_id, identity_key, idempotency_key,
         period_from, period_to, document_kind, document_id, document_number, event_date,
         payload_sha256, status, recorded_by_member_id)
      values (p_workspace_id, p_issuer_site_id, x.format_id, x.id, v_identity,
              public.accounting_idempotency_key(v_identity), x.period_from, x.period_to,
              v_doc ->> 'kind', (v_doc ->> 'id')::uuid, coalesce(v_doc ->> 'number', ''),
              (v_doc ->> 'date')::date, v_sha, 'generated', v_me);
      v_created := v_created + 1;
    elsif d.payload_sha256 = v_sha then
      v_unchanged := v_unchanged + 1;
    else
      update public.accounting_deliveries
         set payload_sha256 = v_sha, book_export_id = x.id, period_from = x.period_from,
             period_to = x.period_to, document_number = coalesce(v_doc ->> 'number', document_number),
             attempts = attempts + 1, recorded_by_member_id = v_me
       where id = d.id;
      v_changed := v_changed + 1;
    end if;
  end loop;
  return jsonb_build_object('created', v_created, 'unchanged', v_unchanged, 'changed', v_changed);
end;
$fn$;
revoke execute on function public.record_file_deliveries_v1(uuid, text, uuid, uuid, jsonb) from public, anon;
grant execute on function public.record_file_deliveries_v1(uuid, text, uuid, uuid, jsonb) to authenticated;

-- What an API adapter (an edge function, service role) records of one
-- document's delivery to a connection. The identity is stable; the first
-- call stores the idempotency key before anything is sent. An acknowledged
-- delivery asked again with its digest is a no-op ('unchanged'), with
-- another digest it is refused (a correction, never a second create). A
-- remote id that disagrees with the one held turns the row into a conflict.
create or replace function public.record_accounting_delivery(
  p_connection_id uuid, p_document_kind text, p_document_id uuid, p_event_date date,
  p_document_number text, p_period_from date, p_period_to date, p_payload_sha256 text,
  p_status text, p_remote jsonb, p_error text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  d public.accounting_deliveries;
  v_identity text;
  v_remote_id text := coalesce(p_remote ->> 'id', '');
  v_status text := p_status;
  v_error text := left(coalesce(p_error, ''), 1000);
  v_outcome text;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  if p_status not in ('generated', 'sent', 'acknowledged', 'conflict', 'failed') then
    raise exception 'unknown delivery status %', p_status using errcode = '22023';
  end if;
  v_identity := 'c:' || c.id || ':' || p_document_kind || ':' || p_document_id || ':' || p_event_date;
  select * into d from public.accounting_deliveries
   where workspace_id = c.workspace_id and identity_key = v_identity for update;
  if d.id is null then
    if c.revoked_at is not null or c.status <> 'connected' then
      raise exception 'this connection cannot deliver: %', c.status using errcode = '23514';
    end if;
    insert into public.accounting_deliveries
      (workspace_id, issuer_site_id, connection_id, target_id, identity_key, idempotency_key,
       period_from, period_to, document_kind, document_id, document_number, event_date,
       payload_sha256, status, error, sent_at)
    values (c.workspace_id, c.issuer_site_id, c.id, c.target_id, v_identity,
            public.accounting_idempotency_key(v_identity), p_period_from, p_period_to,
            p_document_kind, p_document_id, coalesce(p_document_number, ''), p_event_date,
            lower(p_payload_sha256), case when p_status = 'acknowledged' then 'sent' else p_status end,
            v_error, case when p_status in ('sent', 'acknowledged') then now() end)
    returning * into d;
    if p_status <> 'acknowledged' then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'created');
    end if;
  end if;
  if d.status = 'acknowledged' then
    if d.payload_sha256 = lower(p_payload_sha256) and (v_remote_id = '' or v_remote_id = d.remote_id) then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'unchanged');
    end if;
    if d.payload_sha256 <> lower(p_payload_sha256) then
      raise exception 'this document was acknowledged with another content: it needs a correction, not a second delivery'
        using errcode = '23514';
    end if;
  end if;
  -- Preparing a delivery that already exists changes nothing: a send whose
  -- outcome is unknown stays so until a readback resolves it.
  if p_status = 'generated' then
    return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');
  end if;
  if v_remote_id <> '' and d.remote_id <> '' and v_remote_id <> d.remote_id then
    v_status := 'conflict';
    v_error := left('the remote holds ' || d.remote_id || ' and answered ' || v_remote_id, 1000);
  elsif v_status = 'acknowledged' and v_remote_id = '' and d.remote_id = '' then
    raise exception 'an acknowledged delivery names its remote id' using errcode = '22023';
  end if;
  update public.accounting_deliveries set
    status = v_status,
    error = case when v_status in ('conflict', 'failed') then v_error else '' end,
    payload_sha256 = lower(p_payload_sha256),
    document_number = coalesce(nullif(p_document_number, ''), document_number),
    remote_id = case when v_status = 'conflict' then remote_id else coalesce(nullif(v_remote_id, ''), remote_id) end,
    remote_number = coalesce(nullif(p_remote ->> 'number', ''), remote_number),
    remote_version = coalesce(nullif(p_remote ->> 'version', ''), remote_version),
    remote_state = coalesce(nullif(p_remote ->> 'state', ''), remote_state),
    attempts = attempts + case when v_status = 'sent' and d.status <> 'generated' then 1 else 0 end,
    sent_at = case when v_status = 'sent' then now() else sent_at end,
    acknowledged_at = case when v_status = 'acknowledged' then now() else acknowledged_at end
  where id = d.id
  returning * into d;
  v_outcome := case when v_status = 'conflict' and p_status <> 'conflict' then 'conflict' else 'updated' end;
  return public.accounting_delivery_json(d) || jsonb_build_object('outcome', v_outcome);
end;
$fn$;
revoke execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text)
  to service_role;

-- ── the transfers of a period ─────────────────────────────────────────────
-- The files handed out whose period overlaps [p_from, p_to], each with the
-- documents it carried, and the connection deliveries of documents dated in
-- it: what moved, how, with which digest, by whom and when.
create or replace function public.accounting_transfers_v1(p_workspace_id uuid, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.accounting_connector_actor(p_workspace_id, 'read');
  if p_to < p_from then raise exception 'the period ends before it starts' using errcode = '22023'; end if;
  return jsonb_build_object(
    'files', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'format_id', e.format_id, 'period_from', e.period_from, 'period_to', e.period_to,
        'sha256', e.sha256, 'byte_count', e.byte_count, 'row_count', e.row_count,
        'document_count', e.document_count, 'closed_period', e.closed_period,
        'exported_at', e.exported_at, 'exported_by_member_id', e.exported_by_member_id,
        'deliveries', coalesce((select jsonb_agg(public.accounting_delivery_json(d)
                                                 order by d.event_date, d.document_number, d.document_kind)
                                  from public.accounting_deliveries d where d.book_export_id = e.id), '[]'::jsonb))
        order by e.exported_at desc)
      from public.book_exports e
     where e.workspace_id = p_workspace_id and e.period_from <= p_to and e.period_to >= p_from), '[]'::jsonb),
    'deliveries', coalesce((select jsonb_agg(public.accounting_delivery_json(d)
                                             order by d.event_date desc, d.document_number)
      from public.accounting_deliveries d
     where d.workspace_id = p_workspace_id and d.connection_id is not null
       and d.event_date between p_from and p_to), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.accounting_transfers_v1(uuid, date, date) from public, anon;
grant execute on function public.accounting_transfers_v1(uuid, date, date) to authenticated;

-- ── the export log also records for the connectors ────────────────────────
create or replace function public.record_book_export_v1(
  p_workspace_id uuid, p_format_id text, p_from date, p_to date,
  p_sha256 text, p_bytes bigint, p_rows int, p_documents int
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  e public.book_exports;
  v_closed boolean;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  -- The client logs every accounting export it makes; a space that keeps
  -- neither accounting periods nor accounting transfers logs nothing.
  if not (public.feature_effective(p_workspace_id, 'accountingPeriods')
          or public.feature_effective(p_workspace_id, 'accountingConnectors')) then
    return jsonb_build_object('logged', false);
  end if;
  if not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'you may not export the books';
  end if;
  if p_to < p_from then raise exception 'the period ends before it starts'; end if;
  -- closed when every day of the export lies inside closed periods
  select not exists (
      select 1 from generate_series(p_from, p_to, interval '1 day') d
       where not public.book_period_closed(p_workspace_id, d::date)) into v_closed;
  insert into public.book_exports
    (workspace_id, format_id, period_from, period_to, sha256, byte_count, row_count, document_count,
     closed_period, exported_by_member_id)
  values (p_workspace_id, btrim(p_format_id), p_from, p_to, lower(p_sha256), p_bytes, p_rows, p_documents,
          v_closed, v_me)
  returning * into e;
  return jsonb_build_object('logged', true, 'id', e.id, 'closed_period', e.closed_period, 'exported_at', e.exported_at);
end;
$fn$;
revoke execute on function public.record_book_export_v1(uuid, text, date, date, text, bigint, int, int) from public, anon;
grant execute on function public.record_book_export_v1(uuid, text, date, date, text, bigint, int, int) to authenticated;

-- ── the feature registry knows accountingConnectors (child of accountingBook, off) ──
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": "calendarTab", "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": null, "default": false, "core": false},
    "parking": {"parent": null, "default": false, "core": false},
    "webMcp": {"parent": "mcpAccess", "default": false, "core": false},
    "purchases": {"parent": "moneyTab", "default": false, "core": false},
    "premisesLease": {"parent": "scheduledExpenses", "default": false, "core": false},
    "assetRegister": {"parent": "purchases", "default": false, "core": false},
    "externalRooms": {"parent": "levelBooking", "default": false, "core": false},
    "accountingPeriods": {"parent": "accountingBook", "default": false, "core": false},
    "biReportDesigner": {"parent": null, "default": false, "core": false},
    "purchaseAnalytics": {"parent": "purchases", "default": false, "core": false},
    "workspaceOverview": {"parent": null, "default": false, "core": false},
    "setupGuide": {"parent": null, "default": true, "core": true},
    "dataReport": {"parent": "dataExport", "default": true, "core": true},
    "personalShell": {"parent": null, "default": false, "core": false},
    "foreignCurrencyPurchases": {"parent": "purchases", "default": false, "core": false},
    "accountingConnectors": {"parent": "accountingBook", "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
