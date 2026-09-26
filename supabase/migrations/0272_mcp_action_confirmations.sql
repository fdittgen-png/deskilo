-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0272 (#1619, with the handlers of #1622/#1623/#1624) -- a high-impact
-- MCP action happens only after its human confirmed THAT action in the
-- Deskilo app.
--
-- An OAuth connection is delegated access, not proof that the person
-- wanted this refund, this status change, this vote. So invoice issue,
-- void and refund, member status and subscription changes, and a
-- validation response answer `requires_confirmation` with an opaque
-- confirmation id, and create nothing. The bound human opens it in the
-- native app (`mcp_get_action_confirmation`), sees the workspace, the
-- assistant, the action and its subject, and confirms or declines
-- (`mcp_confirm_action`) -- from a NATIVE session: a token carrying an
-- OAuth `client_id` is refused there. The assistant's retry with the
-- SAME request id then consumes the acknowledgement together with the
-- existing request RPC, after every gate is checked again.
--
-- A challenge is bound to installation, human, client, workspace,
-- eligibility grant, operation, request id, argument digest and the
-- target's revision; it expires after five minutes. A changed payload,
-- a changed target, a new grant or an expired challenge authorise
-- nothing. The acknowledgement is intent, not quorum: the request RPC
-- still goes through the workspace's validation rules and may answer
-- `pending_validation`.
--
-- Own-booking deletion needs no confirmation (#1619): it becomes a plain
-- dispatch branch here.

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none"},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_availability":{"rpc":null,"dispatch":false,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"list_my_reservations":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none"},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none"},"list_my_invoices":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none"},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none"},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageBilling","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"list_pending_validations":{"rpc":null,"dispatch":false,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_validation":{"rpc":null,"dispatch":false,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native"}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

create table if not exists public.mcp_action_confirmations (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.installation_identity (installation_id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null references public.mcp_clients (client_id),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  eligibility_grant_id uuid not null references public.mcp_eligibility_grants (id),
  operation text not null,
  request_id uuid not null,
  args_digest text not null,
  target_revision text not null default '',
  preview jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'acknowledged', 'consumed', 'declined', 'expired', 'revoked')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '5 minutes',
  acknowledged_at timestamptz,
  consumed_at timestamptz,
  unique (installation_id, local_user_id, client_id, request_id)
);
select public.ensure_system_columns('mcp_action_confirmations');
alter table public.mcp_action_confirmations enable row level security;
revoke all on table public.mcp_action_confirmations from anon, authenticated;

-- The target a high-impact action is about, and its current revision:
-- the confirmation holds the revision it showed, and a changed target
-- authorises nothing.
create or replace function public.mcp_target(p_workspace_id uuid, p_operation text, p_args jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_member public.members;
  v_event public.events;
  v_name text;
begin
  -- The revision is a digest of the WHOLE row: any change to the target,
  -- in any column, makes an earlier confirmation stale.
  if p_operation in ('request_invoice_void', 'request_refund') then
    select * into v_invoice from public.invoices
     where id = public.mcp_uuid_arg(p_args, 'invoice_id') and workspace_id = p_workspace_id;
    if v_invoice.id is null then return null; end if;
    return jsonb_build_object('kind', 'invoice', 'id', v_invoice.id, 'number', v_invoice.number,
      'total_cents', v_invoice.total_cents, 'currency', v_invoice.currency, 'period', v_invoice.period,
      'revision', md5(to_jsonb(v_invoice)::text));
  elsif p_operation in ('request_invoice_issue', 'request_member_status_change', 'request_subscription_change') then
    select * into v_member from public.members
     where id = public.mcp_uuid_arg(p_args, 'member_id') and workspace_id = p_workspace_id;
    if v_member.id is null then return null; end if;
    select coalesce(nullif(v_member.managed_name, ''), p.display_name, '') into v_name
      from (select 1) x left join public.profiles p on p.id = v_member.user_id;
    return jsonb_build_object('kind', 'member', 'id', v_member.id, 'name', v_name,
      'status', v_member.status, 'subscription_pct', v_member.subscription_pct,
      'revision', md5(to_jsonb(v_member)::text));
  elsif p_operation = 'respond_to_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null then return null; end if;
    return jsonb_build_object('kind', 'event', 'id', v_event.id, 'type', v_event.type,
      'status', v_event.status, 'revision', md5(to_jsonb(v_event)::text));
  end if;
  return null;
end;
$fn$;
revoke execute on function public.mcp_target(uuid, text, jsonb) from public, anon, authenticated;

-- What the native app shows before the human decides. Only the bound
-- human, only from a native session (no OAuth client in the token).
create or replace function public.mcp_get_action_confirmation(p_confirmation_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_c public.mcp_action_confirmations;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if auth.jwt() ? 'client_id' then raise exception 'confirmations are answered in the Deskilo app'; end if;
  select * into v_c from public.mcp_action_confirmations
   where id = p_confirmation_id and local_user_id = auth.uid();
  if v_c.id is null then return jsonb_build_object('status', 'not_found'); end if;
  return jsonb_build_object(
    'id', v_c.id,
    'status', case when v_c.status = 'pending' and v_c.expires_at <= now() then 'expired' else v_c.status end,
    'operation', v_c.operation,
    'workspace_id', v_c.workspace_id,
    'workspace_name', (select name from public.workspaces where id = v_c.workspace_id),
    'client_name', (select name from public.mcp_clients where client_id = v_c.client_id),
    'preview', v_c.preview,
    'expires_at', v_c.expires_at);
end;
$fn$;
revoke execute on function public.mcp_get_action_confirmation(uuid) from public, anon;
grant execute on function public.mcp_get_action_confirmation(uuid) to authenticated;

create or replace function public.mcp_confirm_action(p_confirmation_id uuid, p_accept boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_c public.mcp_action_confirmations;
  v_spec jsonb;
  v_target jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if auth.jwt() ? 'client_id' then raise exception 'confirmations are answered in the Deskilo app'; end if;
  select * into v_c from public.mcp_action_confirmations
   where id = p_confirmation_id and local_user_id = auth.uid() for update;
  if v_c.id is null then return jsonb_build_object('status', 'not_found'); end if;
  if v_c.status <> 'pending' then return jsonb_build_object('status', v_c.status); end if;
  if v_c.expires_at <= now() then
    update public.mcp_action_confirmations set status = 'expired' where id = v_c.id;
    return jsonb_build_object('status', 'expired');
  end if;
  if not p_accept then
    update public.mcp_action_confirmations set status = 'declined' where id = v_c.id;
    return jsonb_build_object('status', 'declined');
  end if;
  -- Everything the action will need is checked again now.
  if not exists (select 1 from public.mcp_eligibility_grants
                  where id = v_c.eligibility_grant_id and status = 'active' and expires_at > now()) then
    update public.mcp_action_confirmations set status = 'revoked' where id = v_c.id;
    return jsonb_build_object('status', 'revoked');
  end if;
  perform public.my_active_member(v_c.workspace_id);
  v_spec := public.mcp_operation_catalogue()->'operations'->v_c.operation;
  if v_spec->>'authority' = 'permission'
     and not public.has_permission(v_c.workspace_id, v_spec->>'permission') then
    update public.mcp_action_confirmations set status = 'revoked' where id = v_c.id;
    return jsonb_build_object('status', 'revoked');
  end if;
  v_target := public.mcp_target(v_c.workspace_id, v_c.operation, v_c.preview->'arguments');
  if coalesce(v_target->>'revision', '') <> v_c.target_revision then
    update public.mcp_action_confirmations set status = 'revoked' where id = v_c.id;
    return jsonb_build_object('status', 'target_changed');
  end if;
  update public.mcp_action_confirmations set status = 'acknowledged', acknowledged_at = now()
   where id = v_c.id;
  return jsonb_build_object('status', 'acknowledged');
end;
$fn$;
revoke execute on function public.mcp_confirm_action(uuid, boolean) from public, anon;
grant execute on function public.mcp_confirm_action(uuid, boolean) to authenticated;

-- Confirmations of an unlinked or revoked person stop with their grant.
create or replace function public.mcp_eligibility_revoked_cascade()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.status = 'active' and new.status <> 'active' then
    update public.mcp_action_confirmations set status = 'revoked'
     where eligibility_grant_id = new.id and status in ('pending', 'acknowledged');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.mcp_eligibility_revoked_cascade() from public, anon, authenticated;
drop trigger if exists mcp_eligibility_revoked_cascade on public.mcp_eligibility_grants;
create trigger mcp_eligibility_revoked_cascade
  after update of status on public.mcp_eligibility_grants
  for each row execute function public.mcp_eligibility_revoked_cascade();

-- The request RPCs answer {pending, event_id, ...}: pending is a real
-- event waiting for its validators, not a success of the act.
create or replace function public.mcp_request_outcome(p_result jsonb)
returns text language sql immutable set search_path = public as $fn$
  select case when coalesce((p_result->>'pending')::boolean, false) then 'pending_validation' else 'completed' end;
$fn$;
revoke execute on function public.mcp_request_outcome(jsonb) from public, anon, authenticated;

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
  v_confirmation public.mcp_action_confirmations;
  v_target jsonb;
  v_digest text;
  v_data jsonb;
  v_result jsonb;
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

  -- #1619 — a high-impact action waits for its human, in the app.
  if v_spec->>'confirmation' = 'native' then
    select * into v_confirmation from public.mcp_action_confirmations
     where installation_id = public.installation_id() and local_user_id = auth.uid()
       and client_id = v_client and request_id = p_request_id
     for update;
    begin
      v_target := public.mcp_target(p_workspace_id, p_operation, v_args);
    exception when invalid_parameter_value or invalid_text_representation then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error', null, 'invalid_arguments');
    end;
    if v_target is null then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'not_found', null, 'not_found');
    end if;
    if v_confirmation.id is null then
      insert into public.mcp_action_confirmations (installation_id, local_user_id, client_id,
        workspace_id, eligibility_grant_id, operation, request_id, args_digest, target_revision, preview)
      values (public.installation_id(), auth.uid(), v_client, p_workspace_id, v_grant.id,
              p_operation, p_request_id, v_digest, coalesce(v_target->>'revision', ''),
              jsonb_build_object('arguments', v_args - 'request_id', 'target', v_target - 'revision'))
      returning * into v_confirmation;
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'requires_confirmation',
        jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at));
    end if;
    if v_confirmation.workspace_id <> p_workspace_id or v_confirmation.operation <> p_operation
       or v_confirmation.args_digest <> v_digest then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'conflict', null, 'request_id_reused');
    end if;
    if v_confirmation.eligibility_grant_id <> v_grant.id
       or coalesce(v_target->>'revision', '') <> v_confirmation.target_revision then
      update public.mcp_action_confirmations set status = 'revoked'
       where id = v_confirmation.id and status in ('pending', 'acknowledged');
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'conflict', null, 'confirmation_stale');
    end if;
    if v_confirmation.status = 'pending' and v_confirmation.expires_at > now() then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'requires_confirmation',
        jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at));
    end if;
    if v_confirmation.status <> 'acknowledged' or v_confirmation.expires_at <= now() then
      return public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null,
        case when v_confirmation.status = 'declined' then 'confirmation_declined' else 'confirmation_expired' end);
    end if;
    update public.mcp_action_confirmations set status = 'consumed', consumed_at = now()
     where id = v_confirmation.id;
  end if;

  v_status := 'completed';
  begin
    if p_operation in ('update_reservation', 'check_in', 'check_out', 'request_reservation_deletion') then
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
      elsif p_operation = 'request_reservation_deletion' then
        v_id := public.request_reservation_deletion(v_reservation.id, left(coalesce(v_args->>'reason', ''), 500));
        v_data := jsonb_build_object('event_id', v_id);
        if (select status from public.events where id = v_id) = 'pending' then
          v_status := 'pending_validation';
        end if;
      elsif p_operation = 'request_invoice_issue' then
        v_result := public.request_invoice_issue(p_workspace_id, public.mcp_uuid_arg(v_args, 'member_id'),
          v_args->>'period', coalesce(v_args->>'kind', 'full'));
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id', 'invoice_id', v_result->'invoice_id'));
      elsif p_operation = 'request_invoice_void' then
        v_result := public.request_invoice_void(public.mcp_uuid_arg(v_args, 'invoice_id'),
          left(coalesce(v_args->>'reason', ''), 500));
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_refund' then
        v_result := public.request_refund(public.mcp_uuid_arg(v_args, 'invoice_id'),
          left(coalesce(v_args->>'note', ''), 500));
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_member_status_change' then
        v_result := public.request_member_status_change(public.mcp_uuid_arg(v_args, 'member_id'), v_args->>'status');
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_subscription_change' then
        v_result := public.request_subscription_change(public.mcp_uuid_arg(v_args, 'member_id'),
          (v_args->>'pct')::integer);
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'respond_to_validation' then
        -- The distinct-person quorum is respond_to_event's own (#1624).
        perform public.respond_to_event(public.mcp_uuid_arg(v_args, 'event_id'),
          (v_args->>'accept')::boolean);
        v_data := jsonb_build_object('event_id', public.mcp_uuid_arg(v_args, 'event_id'),
          'event_status', (select status from public.events where id = public.mcp_uuid_arg(v_args, 'event_id')));
      end if;
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      v_status := 'validation_error'; v_code := 'invalid_arguments'; v_data := null;
    when raise_exception or check_violation or exclusion_violation or unique_violation then
      v_status := 'conflict'; v_code := 'refused'; v_data := jsonb_build_object('reason', left(sqlerrm, 200));
  end;
  v_data := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, v_status, v_data, v_code);
  if v_status <> 'validation_error' then
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), v_client, p_request_id, p_workspace_id,
            p_operation, v_digest,
            case when v_status in ('completed', 'pending_validation') then 'applied' else 'refused' end, v_data);
  end if;
  return v_data;
end;
$fn$;
revoke execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(272);
