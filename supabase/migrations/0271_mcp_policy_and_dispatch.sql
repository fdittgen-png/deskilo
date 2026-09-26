-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0271 (#1610, #1612) -- what a workspace exposes to MCP, and the one
-- door every MCP call goes through.
--
-- A workspace owner decides WHETHER and WHICH implemented operations the
-- workspace exposes (revisioned, idempotent by mutation id, off by
-- default, no wildcard). That is organisational configuration: it creates
-- no user eligibility (#1611), no membership and no consent.
--
-- `mcp_execute_v1` is the door. A call is allowed only as the
-- INTERSECTION of: this installation, the runtime switched on, the
-- caller's OAuth client (from the token, `client_id`), an active identity
-- binding, current database eligibility, an active connection for that
-- client, the workspace policy (feature on, operation listed, client
-- allowed), the connection's explicit consent for THIS workspace and
-- operation, active membership, and the operation's existing business
-- permission. Nothing unions across memberships. The existing business
-- RPC then runs as the caller, inside a subtransaction; a business
-- refusal rolls back its effects and answers in the envelope.
--
-- A mutation is idempotent by (installation, human, client, request id):
-- the same id replays the stored outcome after re-authorising, and the
-- same id with another workspace, operation or arguments is a conflict,
-- never a second effect. An operation needing native confirmation
-- answers `requires_confirmation` and does nothing until #1619.
--
-- Connections and consent scopes are written by the OAuth flow (#1615)
-- through privileged setup; this file adds no public writer.
--
-- Lock order, always: eligibility grant, workspace policy, consent scope,
-- idempotency record.

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none"},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_availability":{"rpc":null,"dispatch":false,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"list_my_reservations":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none"},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none"},"list_my_invoices":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none"},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"native"},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":false,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":false,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_refund":{"rpc":"request_refund","dispatch":false,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":false,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":false,"authority":"permission","permission":"manageBilling","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"list_pending_validations":{"rpc":null,"dispatch":false,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_validation":{"rpc":null,"dispatch":false,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"respond_to_validation":{"rpc":"respond_to_event","dispatch":false,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native"}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

-- ── the exposure policy (#1610) ──────────────────────────────────────

create table if not exists public.workspace_mcp_policies (
  workspace_id uuid primary key references public.workspaces (id) on delete cascade,
  installation_id uuid not null references public.installation_identity (installation_id),
  revision integer not null default 0 check (revision >= 0),
  enabled boolean not null default false,
  operations text[] not null default '{}',
  target_ceiling text not null default 'own' check (target_ceiling in ('own', 'workspace')),
  -- Null: any client the instance approved; otherwise exactly these.
  allowed_clients text[]
);
select public.ensure_system_columns('workspace_mcp_policies');
alter table public.workspace_mcp_policies enable row level security;
revoke all on table public.workspace_mcp_policies from anon, authenticated;

create table if not exists public.workspace_mcp_policy_revisions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  revision integer not null check (revision >= 1),
  mutation_id uuid not null,
  payload jsonb not null,
  saved_by uuid not null references auth.users (id),
  saved_at timestamptz not null default now(),
  unique (workspace_id, revision),
  unique (workspace_id, mutation_id)
);
select public.ensure_system_columns('workspace_mcp_policy_revisions');
alter table public.workspace_mcp_policy_revisions enable row level security;
revoke all on table public.workspace_mcp_policy_revisions from anon, authenticated;

create or replace function public.workspace_mcp_policy_revisions_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  raise exception 'a policy revision is history: it is never rewritten';
end;
$fn$;
revoke execute on function public.workspace_mcp_policy_revisions_immutable() from public, anon, authenticated;
drop trigger if exists workspace_mcp_policy_revisions_immutable on public.workspace_mcp_policy_revisions;
create trigger workspace_mcp_policy_revisions_immutable
  before update on public.workspace_mcp_policy_revisions
  for each row execute function public.workspace_mcp_policy_revisions_immutable();

-- The AI clients this instance approved (#1615 registers them).
create table if not exists public.mcp_clients (
  client_id text primary key check (client_id ~ '^[A-Za-z0-9._:-]{1,128}$'),
  name text not null check (length(name) between 1 and 120),
  status text not null default 'active' check (status in ('active', 'revoked'))
);
select public.ensure_system_columns('mcp_clients');
alter table public.mcp_clients enable row level security;
revoke all on table public.mcp_clients from anon, authenticated;

create or replace function public.mcp_policy_status(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_policy public.workspace_mcp_policies;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner configures MCP exposure';
  end if;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id;
  return jsonb_build_object(
    'workspace_id', p_workspace_id,
    'revision', coalesce(v_policy.revision, 0),
    'enabled', coalesce(v_policy.enabled, false),
    'operations', to_jsonb(coalesce(v_policy.operations, '{}'::text[])),
    'target_ceiling', coalesce(v_policy.target_ceiling, 'own'),
    'allowed_clients', to_jsonb(v_policy.allowed_clients),
    'feature_enabled', public.feature_effective(p_workspace_id, 'mcpAccess'),
    'available_operations', (
      select coalesce(jsonb_agg(k order by k), '[]'::jsonb)
        from jsonb_each(public.mcp_operation_catalogue()->'operations') e(k, v)
       where (v->>'dispatch')::boolean));
end;
$fn$;
revoke execute on function public.mcp_policy_status(uuid) from public, anon;
grant execute on function public.mcp_policy_status(uuid) to authenticated;

create or replace function public.save_mcp_policy(
  p_workspace_id uuid, p_expected_revision integer, p_mutation_id uuid,
  p_enabled boolean, p_operations text[], p_target_ceiling text,
  p_allowed_clients text[] default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_policy public.workspace_mcp_policies;
  v_prior public.workspace_mcp_policy_revisions;
  v_ops text[];
  v_payload jsonb;
  v_op text;
  v_client text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_mutation_id is null then raise exception 'a policy save needs its mutation id'; end if;
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner configures MCP exposure';
  end if;
  if p_target_ceiling not in ('own', 'workspace') then
    raise exception 'unknown target ceiling %', p_target_ceiling;
  end if;
  select coalesce(array_agg(distinct o order by o), '{}') into v_ops from unnest(coalesce(p_operations, '{}')) o;
  foreach v_op in array v_ops loop
    if not coalesce((public.mcp_operation_catalogue()->'operations'->v_op->>'dispatch')::boolean, false) then
      raise exception 'unknown or unimplemented operation %', v_op;
    end if;
  end loop;
  if p_allowed_clients is not null then
    foreach v_client in array p_allowed_clients loop
      if not exists (select 1 from public.mcp_clients where client_id = v_client and status = 'active') then
        raise exception 'client % is not approved on this instance', v_client;
      end if;
    end loop;
  end if;
  if p_enabled and not public.feature_effective(p_workspace_id, 'mcpAccess') then
    raise exception 'the MCP feature is off for this workspace';
  end if;
  v_payload := jsonb_build_object('enabled', p_enabled, 'operations', to_jsonb(v_ops),
    'target_ceiling', p_target_ceiling,
    'allowed_clients', to_jsonb((select array_agg(distinct c order by c) from unnest(p_allowed_clients) c)));

  insert into public.workspace_mcp_policies (workspace_id, installation_id)
  values (p_workspace_id, public.installation_id()) on conflict (workspace_id) do nothing;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id for update;

  select * into v_prior from public.workspace_mcp_policy_revisions
   where workspace_id = p_workspace_id and mutation_id = p_mutation_id;
  if v_prior.id is not null then
    if v_prior.payload = v_payload then
      return jsonb_build_object('status', 'replayed', 'revision', v_prior.revision);
    end if;
    return jsonb_build_object('status', 'conflict', 'reason', 'mutation_id_reused');
  end if;
  if v_policy.revision <> coalesce(p_expected_revision, -1) then
    return jsonb_build_object('status', 'conflict', 'reason', 'stale_revision',
                              'revision', v_policy.revision);
  end if;

  insert into public.workspace_mcp_policy_revisions (workspace_id, revision, mutation_id, payload, saved_by)
  values (p_workspace_id, v_policy.revision + 1, p_mutation_id, v_payload, auth.uid());
  update public.workspace_mcp_policies
     set revision = v_policy.revision + 1, enabled = p_enabled, operations = v_ops,
         target_ceiling = p_target_ceiling,
         allowed_clients = (select array_agg(distinct c order by c) from unnest(p_allowed_clients) c)
   where workspace_id = p_workspace_id;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'workspace_policy_saved', 'owner:' || auth.uid(),
          jsonb_build_object('workspace_id', p_workspace_id, 'revision', v_policy.revision + 1));
  return jsonb_build_object('status', 'saved', 'revision', v_policy.revision + 1);
end;
$fn$;
revoke execute on function public.save_mcp_policy(uuid, integer, uuid, boolean, text[], text, text[]) from public, anon;
grant execute on function public.save_mcp_policy(uuid, integer, uuid, boolean, text[], text, text[]) to authenticated;

-- ── connections and consent (#1612 seam; #1615 writes them) ───────────

create table if not exists public.mcp_connections (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.installation_identity (installation_id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  binding_id uuid not null references public.identity_bindings (id),
  client_id text not null references public.mcp_clients (client_id),
  status text not null default 'active' check (status in ('active', 'revoked')),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  check ((status = 'revoked') = (revoked_at is not null))
);
select public.ensure_system_columns('mcp_connections');
create unique index if not exists mcp_connections_one_active
  on public.mcp_connections (installation_id, local_user_id, client_id) where status = 'active';
alter table public.mcp_connections enable row level security;
revoke all on table public.mcp_connections from anon, authenticated;

create table if not exists public.mcp_connection_scopes (
  connection_id uuid not null references public.mcp_connections (id) on delete cascade,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  operations text[] not null default '{}',
  target_ceiling text not null default 'own' check (target_ceiling in ('own', 'workspace')),
  consented_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (connection_id, workspace_id)
);
select public.ensure_system_columns('mcp_connection_scopes');
alter table public.mcp_connection_scopes enable row level security;
revoke all on table public.mcp_connection_scopes from anon, authenticated;

create table if not exists public.mcp_idempotency (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null,
  local_user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  request_id uuid not null,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  operation text not null,
  args_digest text not null,
  status text not null check (status in ('applied', 'refused', 'requires_confirmation')),
  outcome jsonb not null,
  created_at timestamptz not null default now(),
  unique (installation_id, local_user_id, client_id, request_id)
);
select public.ensure_system_columns('mcp_idempotency');
alter table public.mcp_idempotency enable row level security;
revoke all on table public.mcp_idempotency from anon, authenticated;

-- ── the door ──────────────────────────────────────────────────────────

create or replace function public.mcp_envelope(
  p_request_id uuid, p_operation text, p_workspace_id uuid, p_status text,
  p_data jsonb default null, p_code text default null, p_fields jsonb default null)
returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_strip_nulls(jsonb_build_object(
    'schema_version', 1, 'request_id', p_request_id, 'operation', p_operation,
    'workspace_id', p_workspace_id, 'status', p_status, 'data', p_data,
    'error', case when p_code is null then null
                  else jsonb_strip_nulls(jsonb_build_object('code', p_code, 'fields', p_fields)) end));
$fn$;
revoke execute on function public.mcp_envelope(uuid, text, uuid, text, jsonb, text, jsonb) from public, anon, authenticated;

create or replace function public.mcp_uuid_arg(p_args jsonb, p_key text, p_required boolean default true)
returns uuid language plpgsql immutable set search_path = public as $fn$
begin
  if p_args ? p_key and jsonb_typeof(p_args->p_key) = 'string' then
    return (p_args->>p_key)::uuid;
  end if;
  if p_required then raise exception using errcode = '22023', message = p_key; end if;
  return null;
end;
$fn$;
revoke execute on function public.mcp_uuid_arg(jsonb, text, boolean) from public, anon, authenticated;

create or replace function public.mcp_time_arg(p_args jsonb, p_key text)
returns timestamptz language plpgsql immutable set search_path = public as $fn$
declare
  v text := p_args->>p_key;
begin
  if v is null or v !~ '(Z|[+-]\d{2}:\d{2})$' then
    raise exception using errcode = '22023', message = p_key;
  end if;
  return v::timestamptz;
end;
$fn$;
revoke execute on function public.mcp_time_arg(jsonb, text) from public, anon, authenticated;

create or replace function public.mcp_execute_v1(
  p_installation_id uuid, p_workspace_id uuid, p_operation text,
  p_arguments jsonb, p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_spec jsonb := public.mcp_operation_catalogue()->'operations'->p_operation;
  v_args jsonb := coalesce(p_arguments, '{}'::jsonb);
  v_client text := auth.jwt()->>'client_id';
  v_binding uuid;
  v_grant public.mcp_eligibility_grants;
  v_connection public.mcp_connections;
  v_policy public.workspace_mcp_policies;
  v_scope public.mcp_connection_scopes;
  v_member public.members;
  v_ceiling text;
  v_prior public.mcp_idempotency;
  v_digest text;
  v_data jsonb;
  v_reservation public.reservations;
  v_id uuid;
  v_status text;
  v_code text;
  v_ops jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if v_spec is null or not (v_spec->>'dispatch')::boolean then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error', null, 'unknown_operation');
  end if;
  if p_installation_id is distinct from public.installation_id() then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'wrong_installation');
  end if;
  if not (select enabled from public.mcp_runtime) then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'runtime_disabled');
  end if;
  if v_client is null then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_client');
  end if;
  v_binding := public.my_active_binding();
  if v_binding is null then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_identity');
  end if;
  select * into v_grant from public.mcp_eligibility_grants
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = v_binding and status = 'active' and expires_at > now()
   for share;
  if v_grant.id is null then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'not_eligible');
  end if;
  select * into v_connection from public.mcp_connections
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = v_binding and client_id = v_client and status = 'active';
  if v_connection.id is null or not exists (select 1 from public.mcp_clients
                                             where client_id = v_client and status = 'active') then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_connection');
  end if;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id for share;
  if v_policy.workspace_id is null or not v_policy.enabled
     or not public.feature_effective(p_workspace_id, 'mcpAccess')
     or not (p_operation = any (v_policy.operations))
     or (v_policy.allowed_clients is not null and not (v_client = any (v_policy.allowed_clients))) then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'not_exposed');
  end if;
  select * into v_scope from public.mcp_connection_scopes
   where connection_id = v_connection.id and workspace_id = p_workspace_id and revoked_at is null
   for share;
  if v_scope.connection_id is null or not (p_operation = any (v_scope.operations)) then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_consent');
  end if;
  begin
    v_member := public.my_active_member(p_workspace_id);
  exception when others then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'not_a_member');
  end;
  if v_spec->>'authority' = 'permission'
     and not public.has_permission(p_workspace_id, v_spec->>'permission') then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'forbidden');
  end if;
  v_ceiling := case when v_policy.target_ceiling = 'workspace' and v_scope.target_ceiling = 'workspace'
                    then 'workspace' else 'own' end;
  if v_spec->>'scope' = 'workspace' and p_operation <> 'get_capabilities' and v_ceiling <> 'workspace' then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'target_ceiling');
  end if;

  -- Reads: bounded, never stored.
  if v_spec->>'mutation' = 'read' then
    begin
      if p_operation = 'get_capabilities' then
        select coalesce(jsonb_agg(o order by o), '[]'::jsonb) into v_ops
          from unnest(v_policy.operations) o
         where o = any (v_scope.operations)
           and (public.mcp_operation_catalogue()->'operations'->o->>'authority' <> 'permission'
                or public.has_permission(p_workspace_id,
                     public.mcp_operation_catalogue()->'operations'->o->>'permission'));
        v_data := jsonb_build_object('operations', v_ops, 'target_ceiling', v_ceiling,
                                     'eligible_until', v_grant.expires_at);
      elsif p_operation = 'get_my_statement' then
        if public.mcp_uuid_arg(v_args, 'member_id') <> v_member.id then
          return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'not_found', null, 'not_found');
        end if;
        if coalesce(v_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
          return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error',
                                     null, 'invalid_arguments', jsonb_build_object('period', 'invalid_month'));
        end if;
        v_data := public.member_statement(v_member.id, v_args->>'period');
      end if;
    exception when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error',
                                 null, 'invalid_arguments');
    end;
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'completed', v_data);
  end if;

  -- Mutations: one request id, one outcome.
  if p_request_id is null then
    return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error',
                               null, 'invalid_arguments', jsonb_build_object('request_id', 'required'));
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_operation || '|' || (v_args - 'request_id')::text);
  perform pg_advisory_xact_lock(hashtextextended(
    public.installation_id()::text || auth.uid()::text || v_client || p_request_id::text, 1612));
  select * into v_prior from public.mcp_idempotency
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = v_client and request_id = p_request_id;
  if v_prior.id is not null then
    if v_prior.workspace_id <> p_workspace_id or v_prior.operation <> p_operation
       or v_prior.args_digest <> v_digest then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'conflict', null, 'request_id_reused');
    end if;
    return v_prior.outcome;
  end if;

  if v_spec->>'confirmation' = 'native' then
    v_data := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'requires_confirmation');
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), v_client, p_request_id, p_workspace_id,
            p_operation, v_digest, 'requires_confirmation', v_data);
    return v_data;
  end if;

  v_status := 'completed';
  begin
    if p_operation in ('update_reservation', 'check_in', 'check_out') then
      select * into v_reservation from public.reservations
       where id = public.mcp_uuid_arg(v_args, 'reservation_id')
         and workspace_id = p_workspace_id and member_id = v_member.id;
      if v_reservation.id is null then
        v_status := 'not_found'; v_code := 'not_found';
      end if;
    end if;
    if v_status = 'completed' then
      if p_operation = 'create_reservation' then
        v_id := public.create_reservation_once(p_request_id, p_workspace_id,
          public.mcp_uuid_arg(v_args, 'seat_id', false), public.mcp_uuid_arg(v_args, 'desk_id', false),
          public.mcp_uuid_arg(v_args, 'office_id', false), public.mcp_uuid_arg(v_args, 'level_id', false),
          public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'), false);
        v_data := jsonb_build_object('reservation_id', v_id);
      elsif p_operation = 'update_reservation' then
        perform public.update_reservation(v_reservation.id,
          public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'));
      elsif p_operation = 'check_in' then
        perform public.check_in_reservation(v_reservation.id);
      elsif p_operation = 'check_out' then
        perform public.check_out_reservation(v_reservation.id);
      end if;
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      v_status := 'validation_error'; v_code := 'invalid_arguments'; v_data := null;
    when raise_exception or check_violation or exclusion_violation or unique_violation then
      -- The business RPC refused: its effects are rolled back with this block.
      v_status := 'conflict'; v_code := 'refused'; v_data := jsonb_build_object('reason', left(sqlerrm, 200));
  end;
  v_data := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, v_status, v_data, v_code);
  if v_status <> 'validation_error' then
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), v_client, p_request_id, p_workspace_id,
            p_operation, v_digest, case when v_status = 'completed' then 'applied' else 'refused' end, v_data);
  end if;
  return v_data;
end;
$fn$;
revoke execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(271);
