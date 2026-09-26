-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0275 (#1617, absorbing #1618) -- the bounded MCP reads: availability,
-- my reservations, my invoices, pending validations and one validation.
--
-- Each runs inside mcp_execute_v1, after every gate, for the caller's own
-- member in the explicit workspace. Windows are at most 31 days, pages 25
-- by default and 100 at most, ordered by a stable (time, id) key; the
-- cursor carries its operation and workspace, so a cursor from elsewhere
-- is refused. Fields are allow-listed: no bank details, no other member's
-- identity, no attachment, no signed URL. Nothing here writes: no sweep,
-- no notification, no decision.
--
-- Whether the caller may answer a pending validation is asked of
-- respond_to_event ITSELF, inside a subtransaction that always rolls
-- back: the native rules, exactly, and nothing persists. A preview is not
-- authority; the answer is decided again when it is given.

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none"},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none"},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none"},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none"},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none"},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageBilling","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"permission","permission":"manageValidation","features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native"}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

create or replace function public.mcp_cursor(p_operation text, p_workspace_id uuid, p_at timestamptz, p_id uuid)
returns text language sql immutable set search_path = public as $fn$
  select translate(encode(convert_to(jsonb_build_object('o', p_operation, 'w', p_workspace_id,
    'a', p_at, 'i', p_id)::text, 'UTF8'), 'base64'), E'\n', '');
$fn$;
revoke execute on function public.mcp_cursor(text, uuid, timestamptz, uuid) from public, anon, authenticated;

-- The (time, id) a cursor points after, when it belongs to this operation
-- and workspace; raises 22023 otherwise.
create or replace function public.mcp_cursor_position(p_cursor text, p_operation text, p_workspace_id uuid)
returns table (at timestamptz, id uuid) language plpgsql immutable set search_path = public as $fn$
declare
  v jsonb;
begin
  if p_cursor is null then return; end if;
  begin
    v := convert_from(decode(p_cursor, 'base64'), 'UTF8')::jsonb;
  exception when others then
    raise exception using errcode = '22023', message = 'cursor';
  end;
  if v->>'o' is distinct from p_operation or (v->>'w')::uuid is distinct from p_workspace_id then
    raise exception using errcode = '22023', message = 'cursor';
  end if;
  return query select (v->>'a')::timestamptz, (v->>'i')::uuid;
end;
$fn$;
revoke execute on function public.mcp_cursor_position(text, text, uuid) from public, anon, authenticated;

create or replace function public.mcp_read_v1(
  p_workspace_id uuid, p_member public.members, p_operation text, p_args jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_limit integer := least(greatest(coalesce((p_args->>'limit')::integer, 25), 1), 100);
  v_from timestamptz;
  v_to timestamptz;
  v_after_at timestamptz;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_event public.events;
  v_can boolean;
  v_reason text;
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > interval '31 days' then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'starts_at', x.starts_at, 'ends_at', x.ends_at, 'status', x.status) as r
          from public.reservations x
         where x.workspace_id = p_workspace_id and x.member_id = p_member.id
           and x.starts_at < v_to and x.ends_at > v_from
           and (v_after_at is null or (x.starts_at, x.id) > (v_after_at, v_after_id))
         order by x.starts_at, x.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'starts_at')::timestamptz, (v_last->>'reservation_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_availability' then
    -- Seats and whether a live reservation overlaps the window. What is
    -- NOT checked here -- opening hours, quota, price, approval -- is said.
    select coalesce(jsonb_agg(r order by r->>'name', r->>'seat_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('seat_id', s.id, 'name', s.name,
                 'free', not exists (select 1 from public.reservations x
                                      where x.seat_id = s.id and x.status in ('reserved', 'checked_in')
                                        and x.starts_at < v_to and x.ends_at > v_from)
                         and not (s.blocked_from is not null and s.blocked_from < v_to
                                  and coalesce(s.blocked_to, 'infinity') > v_from)) as r
          from public.seats s
         where s.workspace_id = p_workspace_id
           and (v_after_id is null or s.id > v_after_id)
         order by s.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', case when v_count > v_limit then v_rows - v_limit else v_rows end,
      'next_cursor', case when v_count > v_limit then
        public.mcp_cursor(p_operation, p_workspace_id, now(), ((v_rows - v_limit)->(v_limit - 1)->>'seat_id')::uuid) end,
      'not_checked', jsonb_build_array('opening_hours', 'quota', 'price', 'approval'));
  end if;

  if p_operation = 'list_my_invoices' then
    select coalesce(jsonb_agg(r order by (r->>'issued_at')::timestamptz desc, r->>'invoice_id' desc), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('invoice_id', i.id, 'number', i.number, 'period', i.period,
                 'kind', i.kind, 'total_cents', i.total_cents, 'currency', i.currency,
                 'issued_at', i.issued_at, 'voided', i.voided_at is not null) as r
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = p_member.id
           and (v_after_at is null or (i.issued_at, i.id) < (v_after_at, v_after_id))
         order by i.issued_at desc, i.id desc
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'issued_at')::timestamptz, (v_last->>'invoice_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'list_pending_validations' then
    -- Pending events the caller authored, is the subject of, or may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (e.actor_member_id = p_member.id or e.subject_member_id = p_member.id
                or p_member.is_owner or p_member.is_admin
                or public.may_validate_event_type(p_workspace_id, e.type))
           and (v_after_at is null or (e.created_at, e.id) > (v_after_at, v_after_id))
         order by e.created_at, e.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'requested_at')::timestamptz, (v_last->>'event_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null
       or not (v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id
               or p_member.is_owner or p_member.is_admin
               or public.may_validate_event_type(p_workspace_id, v_event.type)) then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_can := false;
    if v_event.status = 'pending' then
      begin
        perform public.respond_to_event(v_event.id, true);
        raise exception using errcode = 'P0002', message = 'mcp preview';
      exception
        when no_data_found then
          v_can := sqlerrm = 'mcp preview';
        when raise_exception then
          v_reason := left(sqlerrm, 120);
        when others then
          v_reason := 'unavailable';
      end;
    end if;
    return jsonb_build_object(
      'event_id', v_event.id, 'type', v_event.type, 'status', v_event.status,
      'requested_at', v_event.created_at,
      'decisions', (select count(*) from public.event_decisions d where d.event_id = v_event.id),
      'can_respond', v_can, 'reason', v_reason);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$fn$;
revoke execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) from public, anon, authenticated;

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
      else
        -- #1617 — the bounded reads; a refusal comes back as {status, code}.
        v_data := public.mcp_read_v1(p_workspace_id, v_member, p_operation, v_args);
        if v_data ? 'refused' then
          return public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
            v_data->>'refused', null, v_data->>'code');
        end if;
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

select public.set_deskilo_schema_version(275);
