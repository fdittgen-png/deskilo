-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0407 (#2392) -- the MCP facade restated as small functions with one job
-- each, after twelve anchored patches grew mcp_execute_v1 into one switch.
--
--   mcp_authorize      the gate chain, in its order, answering a refusal
--                      code in the context instead of returning early
--   mcp_idempotent     the request-id ledger's replay and reuse checks
--   mcp_confirm        the native-confirmation state machine
--   mcp_op_<id>        one handler per catalogued operation, found by name
--                      through to_regprocedure (no handler: unknown_operation)
--   mcp_outcome_of     the one mapping from an exception to a status
--   mcp_execute_v1     authorize -> read | (ledger -> confirmation ->
--                      handler -> ledger) -> usage note -> envelope; it
--                      names no operation
--
-- Every envelope is the one 0406 answered: the matrix (169) and the
-- conformance journey (97) run unchanged against this body. A new operation
-- is additive from here: a catalogue entry, one mcp_op_<id> in its own
-- migration, its pgTAP, its coverage row; anchored patches on mcp_*
-- functions are refused by test/lint/anchored_patch_test.dart.

create type public.mcp_call_context as (
  installation_id uuid,
  workspace_id uuid,
  operation text,
  request_id uuid,
  spec jsonb,
  client_id text,
  binding_id uuid,
  grant_id uuid,
  grant_expires_at timestamptz,
  connection_id uuid,
  policy_operations text[],
  scope_operations text[],
  member_id uuid,
  ceiling text,
  refusal text
);

-- A handler's answer: a status, its data and an error code.
create or replace function public.mcp_outcome(p_status text, p_data jsonb default null, p_code text default null)
returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_build_object('status', p_status, 'data', p_data, 'code', p_code);
$fn$;
revoke execute on function public.mcp_outcome(text, jsonb, text) from public, anon, authenticated;

-- The one mapping from an exception to an outcome. A target the caller may
-- not see in this workspace is not_found, never invalid arguments.
create or replace function public.mcp_outcome_of(p_sqlstate text, p_message text)
returns jsonb language sql immutable set search_path = public as $fn$
  select case
    when p_sqlstate = '22023' and p_message ilike '%not in this workspace%'
      then public.mcp_outcome('not_found', null, 'not_found')
    when p_sqlstate in ('22023', '22P02', '22007', '22008')
      then public.mcp_outcome('validation_error', null, 'invalid_arguments')
    else public.mcp_outcome('conflict',
           jsonb_build_object('reason', case when p_sqlstate = 'P0001' then left(p_message, 200) end), 'refused')
  end;
$fn$;
revoke execute on function public.mcp_outcome_of(text, text) from public, anon, authenticated;

-- The gate chain: installation, runtime, client, binding, Google identity,
-- grant, connection, policy/feature/allowed clients, consent, membership,
-- permission, ceiling. The first gate that refuses names the refusal.
create or replace function public.mcp_authorize(p_installation_id uuid, p_workspace_id uuid, p_operation text)
returns public.mcp_call_context
language plpgsql
security definer
set search_path = public
as $fn$
declare
  c public.mcp_call_context;
  v_grant public.mcp_eligibility_grants;
  v_connection public.mcp_connections;
  v_policy public.workspace_mcp_policies;
  v_scope public.mcp_connection_scopes;
  v_member public.members;
begin
  c.installation_id := p_installation_id;
  c.workspace_id := p_workspace_id;
  c.operation := p_operation;
  c.spec := public.mcp_operation_catalogue()->'operations'->p_operation;
  c.client_id := auth.jwt()->>'client_id';
  if c.spec is null or not (c.spec->>'dispatch')::boolean then
    c.refusal := 'unknown_operation'; return c;
  end if;
  if p_installation_id is distinct from public.installation_id() then
    c.refusal := 'wrong_installation'; return c;
  end if;
  if not (select enabled from public.mcp_runtime) then
    c.refusal := 'runtime_disabled'; return c;
  end if;
  if c.client_id is null then
    c.refusal := 'no_client'; return c;
  end if;
  c.binding_id := public.my_active_binding();
  if c.binding_id is null then
    c.refusal := 'no_identity'; return c;
  end if;
  if not public.mcp_has_google_identity() then
    c.refusal := 'no_google_identity'; return c;
  end if;
  select * into v_grant from public.mcp_eligibility_grants
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = c.binding_id and status = 'active' and expires_at > now()
   for share;
  if v_grant.id is null then
    c.refusal := 'not_eligible'; return c;
  end if;
  c.grant_id := v_grant.id;
  c.grant_expires_at := v_grant.expires_at;
  select * into v_connection from public.mcp_connections
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = c.binding_id and client_id = c.client_id and status = 'active';
  if v_connection.id is null or not exists (select 1 from public.mcp_clients
                                             where client_id = c.client_id and status = 'active') then
    c.refusal := 'no_connection'; return c;
  end if;
  c.connection_id := v_connection.id;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id for share;
  if v_policy.workspace_id is null or not v_policy.enabled
     or not public.feature_effective(p_workspace_id, 'mcpAccess')
     or not (p_operation = any (v_policy.operations))
     or (v_policy.allowed_clients is not null and not (c.client_id = any (v_policy.allowed_clients))) then
    c.refusal := 'not_exposed'; return c;
  end if;
  c.policy_operations := v_policy.operations;
  select * into v_scope from public.mcp_connection_scopes
   where connection_id = v_connection.id and workspace_id = p_workspace_id and revoked_at is null
   for share;
  if v_scope.connection_id is null or not (p_operation = any (v_scope.operations)) then
    c.refusal := 'no_consent'; return c;
  end if;
  c.scope_operations := v_scope.operations;
  begin
    v_member := public.my_active_member(p_workspace_id);
  exception when others then
    c.refusal := 'not_a_member'; return c;
  end;
  c.member_id := v_member.id;
  if c.spec->>'authority' = 'permission'
     and not public.has_permission(p_workspace_id, c.spec->>'permission') then
    c.refusal := 'forbidden'; return c;
  end if;
  c.ceiling := case when v_policy.target_ceiling = 'workspace' and v_scope.target_ceiling = 'workspace'
                    then 'workspace' else 'own' end;
  if c.spec->>'scope' = 'workspace' and p_operation <> 'get_capabilities' and c.ceiling <> 'workspace' then
    c.refusal := 'target_ceiling'; return c;
  end if;
  return c;
end;
$fn$;
revoke execute on function public.mcp_authorize(uuid, uuid, text) from public, anon, authenticated;

-- The request-id ledger: a replay answers the stored outcome through
-- today's allow-list and disclosure layers; a reused id with another
-- intent is a conflict; null lets the call proceed.
create or replace function public.mcp_idempotent(c public.mcp_call_context, p_request_id uuid, p_digest text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_prior public.mcp_idempotency;
begin
  perform pg_advisory_xact_lock(hashtextextended(
    public.installation_id()::text || auth.uid()::text || c.client_id || p_request_id::text, 1612));
  select * into v_prior from public.mcp_idempotency
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = c.client_id and request_id = p_request_id;
  if v_prior.id is null then
    return null;
  end if;
  if v_prior.workspace_id <> c.workspace_id or v_prior.operation <> c.operation
     or v_prior.args_digest <> p_digest then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'conflict', null, 'request_id_reused'));
  end if;
  -- #1644 — the stored answer, through TODAY's allow-list.
  return v_prior.outcome || jsonb_strip_nulls(jsonb_build_object('data',
    -- #1645 — and through the CURRENT disclosure layers.
    public.mcp_project_data(c.operation, v_prior.outcome->'data',
      public.mcp_disclosed_fields(c.operation, c.workspace_id))));
end;
$fn$;
revoke execute on function public.mcp_idempotent(public.mcp_call_context, uuid, text) from public, anon, authenticated;

-- The native confirmation (#1619): the first call records what would
-- change and stops; only the app's acknowledgement, for the same intent on
-- an unchanged target, lets the call proceed (null), once.
create or replace function public.mcp_confirm(c public.mcp_call_context, p_request_id uuid, p_digest text, p_args jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_confirmation public.mcp_action_confirmations;
  v_target jsonb;
begin
  select * into v_confirmation from public.mcp_action_confirmations
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = c.client_id and request_id = p_request_id
   for update;
  begin
    v_target := public.mcp_target(c.workspace_id, c.operation, p_args);
  exception when invalid_parameter_value or invalid_text_representation then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'validation_error', null, 'invalid_arguments'));
  end;
  if v_target is null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'not_found', null, 'not_found'));
  end if;
  if v_confirmation.id is null then
    insert into public.mcp_action_confirmations (installation_id, local_user_id, client_id,
      workspace_id, eligibility_grant_id, operation, request_id, args_digest, target_revision, preview)
    values (public.installation_id(), auth.uid(), c.client_id, c.workspace_id, c.grant_id,
            c.operation, p_request_id, p_digest, coalesce(v_target->>'revision', ''),
            jsonb_build_object('arguments', p_args - 'request_id', 'target', v_target - 'revision'))
    returning * into v_confirmation;
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'requires_confirmation',
      jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at)));
  end if;
  if v_confirmation.workspace_id <> c.workspace_id or v_confirmation.operation <> c.operation
     or v_confirmation.args_digest <> p_digest then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'conflict', null, 'request_id_reused'));
  end if;
  if v_confirmation.eligibility_grant_id <> c.grant_id
     or coalesce(v_target->>'revision', '') <> v_confirmation.target_revision then
    update public.mcp_action_confirmations set status = 'revoked'
     where id = v_confirmation.id and status in ('pending', 'acknowledged');
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'conflict', null, 'confirmation_stale'));
  end if;
  if v_confirmation.status = 'pending' and v_confirmation.expires_at > now() then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'requires_confirmation',
      jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at)));
  end if;
  if v_confirmation.status <> 'acknowledged' or v_confirmation.expires_at <= now() then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'denied', null,
      case when v_confirmation.status = 'declined' then 'confirmation_declined' else 'confirmation_expired' end));
  end if;
  update public.mcp_action_confirmations set status = 'consumed', consumed_at = now()
   where id = v_confirmation.id;
  return null;
end;
$fn$;
revoke execute on function public.mcp_confirm(public.mcp_call_context, uuid, text, jsonb) from public, anon, authenticated;

-- ── reads ─────────────────────────────────────────────────────────────
-- A bounded read of mcp_read_v1 (the shared read engine, also driven
-- directly by pgTAP 63 and 144), its {refused, code} turned into an outcome.
create or replace function public.mcp_read_outcome(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_data jsonb;
begin
  v_data := public.mcp_read_v1(c.workspace_id, (select m from public.members m where m.id = c.member_id),
    c.operation, (p_args - '_ceiling') || jsonb_build_object('_ceiling', c.ceiling));
  if v_data ? 'refused' then
    return public.mcp_outcome(v_data->>'refused', null, v_data->>'code');
  end if;
  return public.mcp_outcome('completed', v_data);
end;
$fn$;
revoke execute on function public.mcp_read_outcome(public.mcp_call_context, jsonb) from public, anon, authenticated;

-- One member's statement for a month, as the app's member_statement.
create or replace function public.mcp_statement_outcome(c public.mcp_call_context, p_member_id uuid, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select case
    when coalesce(p_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$'
      then public.mcp_outcome('validation_error', null, 'invalid_arguments')
           || jsonb_build_object('fields', jsonb_build_object('period', 'invalid_month'))
    else public.mcp_outcome('completed', public.member_statement(p_member_id, p_args->>'period')
           || jsonb_build_object('currency', (select w.currency_code from public.workspaces w where w.id = c.workspace_id))
           || case when c.operation = 'get_member_statement' then jsonb_build_object('member_id', p_member_id)
                   else '{}'::jsonb end)
  end;
$fn$;
revoke execute on function public.mcp_statement_outcome(public.mcp_call_context, uuid, jsonb) from public, anon, authenticated;

create or replace function public.mcp_op_get_capabilities(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_ops jsonb;
  v_refused jsonb;
begin
  -- #2391 — what it may do here, and for everything else why not.
  select coalesce(jsonb_agg(o order by o), '[]'::jsonb) into v_ops
    from unnest(c.policy_operations) o
   where public.mcp_capability_refusal(c.workspace_id, o, c.policy_operations, c.scope_operations, c.ceiling) is null;
  select coalesce(jsonb_agg(jsonb_build_object('operation', k, 'reason', r) order by k), '[]'::jsonb) into v_refused
    from (select k, public.mcp_capability_refusal(c.workspace_id, k, c.policy_operations, c.scope_operations, c.ceiling) r
            from jsonb_each(public.mcp_operation_catalogue()->'operations') e(k, s)
           where (s->>'dispatch')::boolean) q
   where r is not null;
  return public.mcp_outcome('completed',
    jsonb_build_object('operations', v_ops, 'refused', v_refused, 'target_ceiling', c.ceiling,
                       'eligible_until', c.grant_expires_at)
    || public.mcp_workspace_context(c.workspace_id));
end;
$fn$;

create or replace function public.mcp_op_get_my_statement(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  -- #2145 — always the caller's own: another member's id does not exist.
  if p_args ? 'member_id' and public.mcp_uuid_arg(p_args, 'member_id') <> c.member_id then
    return public.mcp_outcome('not_found', null, 'not_found');
  end if;
  return public.mcp_statement_outcome(c, c.member_id, p_args);
end;
$fn$;

create or replace function public.mcp_op_get_member_statement(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
begin
  -- #2391 — viewFinances (the gate) reads a member of THIS workspace.
  select m.id into v_id from public.members m
   where m.id = public.mcp_uuid_arg(p_args, 'member_id') and m.workspace_id = c.workspace_id;
  if v_id is null then
    return public.mcp_outcome('not_found', null, 'not_found');
  end if;
  return public.mcp_statement_outcome(c, v_id, p_args);
end;
$fn$;

create or replace function public.mcp_op_get_availability(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;
create or replace function public.mcp_op_list_my_reservations(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;
create or replace function public.mcp_op_get_place(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;
create or replace function public.mcp_op_list_my_favorites(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;
create or replace function public.mcp_op_list_my_invoices(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;
create or replace function public.mcp_op_list_pending_validations(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;
create or replace function public.mcp_op_get_validation(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_read_outcome(c, p_args);
$fn$;

-- ── writes on the caller's own booking ───────────────────────────────
-- The caller's reservation named by reservation_id, locked; not_found or
-- a stale expected_state answer instead of a reservation.
create or replace function public.mcp_own_reservation(c public.mcp_call_context, p_args jsonb,
  out reservation_id uuid, out refusal jsonb)
language plpgsql security definer set search_path = public as $fn$
begin
  select r.id into reservation_id from public.reservations r
   where r.id = public.mcp_uuid_arg(p_args, 'reservation_id')
     and r.workspace_id = c.workspace_id and r.member_id = c.member_id
     for update;
  if reservation_id is null then
    refusal := public.mcp_outcome('not_found', null, 'not_found');
  elsif p_args ? 'expected_state'
        and p_args->>'expected_state' is distinct from public.mcp_reservation_digest(reservation_id) then
    refusal := public.mcp_outcome('conflict', public.mcp_reservation_view(reservation_id), 'stale');
  end if;
end;
$fn$;
revoke execute on function public.mcp_own_reservation(public.mcp_call_context, jsonb) from public, anon, authenticated;

-- A reservation write's answer: its data and the reservation as it is now.
create or replace function public.mcp_reservation_outcome(p_status text, p_reservation_id uuid, p_data jsonb default null)
returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  if public.mcp_reservation_view(p_reservation_id) is null then
    raise exception 'the reservation could not be read back';
  end if;
  return public.mcp_outcome(p_status,
    coalesce(p_data, '{}'::jsonb) || public.mcp_reservation_view(p_reservation_id));
end;
$fn$;
revoke execute on function public.mcp_reservation_outcome(text, uuid, jsonb) from public, anon, authenticated;

create or replace function public.mcp_op_create_reservation(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_args jsonb := public.mcp_apply_period(c.workspace_id, p_args);
  v_id uuid;
begin
  v_id := public.create_reservation_once(c.request_id, c.workspace_id,
    public.mcp_uuid_arg(v_args, 'seat_id', false), public.mcp_uuid_arg(v_args, 'desk_id', false),
    public.mcp_uuid_arg(v_args, 'office_id', false), public.mcp_uuid_arg(v_args, 'level_id', false),
    public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'),
    coalesce((v_args->>'check_in')::boolean, false));
  perform public.mcp_record_reservation_origin(v_id, c.workspace_id, c.member_id, c.client_id, c.request_id);
  return public.mcp_reservation_outcome('completed', v_id, jsonb_build_object('reservation_id', v_id));
end;
$fn$;

create or replace function public.mcp_op_update_reservation(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v uuid;
  v_refusal jsonb;
  v_args jsonb;
begin
  select o.reservation_id, o.refusal into v, v_refusal from public.mcp_own_reservation(c, p_args) o;
  if v_refusal is not null then return v_refusal; end if;
  v_args := public.mcp_apply_period(c.workspace_id, p_args);
  perform public.update_reservation(v, public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'));
  return public.mcp_reservation_outcome('completed', v);
end;
$fn$;

create or replace function public.mcp_op_check_in(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v uuid;
  v_refusal jsonb;
begin
  select o.reservation_id, o.refusal into v, v_refusal from public.mcp_own_reservation(c, p_args) o;
  if v_refusal is not null then return v_refusal; end if;
  perform public.check_in_reservation(v);
  return public.mcp_reservation_outcome('completed', v);
end;
$fn$;

create or replace function public.mcp_op_check_out(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v uuid;
  v_refusal jsonb;
begin
  select o.reservation_id, o.refusal into v, v_refusal from public.mcp_own_reservation(c, p_args) o;
  if v_refusal is not null then return v_refusal; end if;
  perform public.check_out_reservation(v);
  return public.mcp_reservation_outcome('completed', v);
end;
$fn$;

create or replace function public.mcp_op_cancel_reservation(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v uuid;
  v_refusal jsonb;
begin
  select o.reservation_id, o.refusal into v, v_refusal from public.mcp_own_reservation(c, p_args) o;
  if v_refusal is not null then return v_refusal; end if;
  perform public.cancel_reservation(v);
  return public.mcp_reservation_outcome('completed', v);
end;
$fn$;

create or replace function public.mcp_op_request_reservation_deletion(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v uuid;
  v_refusal jsonb;
  v_event uuid;
begin
  select o.reservation_id, o.refusal into v, v_refusal from public.mcp_own_reservation(c, p_args) o;
  if v_refusal is not null then return v_refusal; end if;
  v_event := public.request_reservation_deletion(v, left(coalesce(p_args->>'reason', ''), 500));
  return public.mcp_reservation_outcome(
    case when (select status from public.events where id = v_event) = 'pending' then 'pending_validation'
         else 'completed' end,
    v, jsonb_build_object('event_id', v_event));
end;
$fn$;

create or replace function public.mcp_op_set_favorite(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_outcome('completed', public.mcp_place_feedback_write(c.workspace_id, c.operation, p_args));
$fn$;
create or replace function public.mcp_op_rate_place(c public.mcp_call_context, p_args jsonb)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_outcome('completed', public.mcp_place_feedback_write(c.workspace_id, c.operation, p_args));
$fn$;

-- ── requests that go through the workspace's validation ─────────────
-- An invoice request's answer: the request outcome and the invoice now.
create or replace function public.mcp_invoice_outcome(p_result jsonb, p_data jsonb, p_invoice_id uuid,
  p_must_read_back boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_status text := public.mcp_request_outcome(p_result);
  v_invoice uuid := coalesce((p_data->>'invoice_id')::uuid, p_invoice_id);
begin
  if p_must_read_back and v_status = 'completed' and public.mcp_invoice_view(v_invoice) is null then
    raise exception 'the invoice could not be read back';
  end if;
  return public.mcp_outcome(v_status, p_data || coalesce(public.mcp_invoice_view(v_invoice), '{}'::jsonb));
end;
$fn$;
revoke execute on function public.mcp_invoice_outcome(jsonb, jsonb, uuid, boolean) from public, anon, authenticated;

create or replace function public.mcp_op_request_invoice_issue(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_result jsonb := public.request_invoice_issue(c.workspace_id, public.mcp_uuid_arg(p_args, 'member_id'),
    p_args->>'period', coalesce(p_args->>'kind', 'full'));
begin
  return public.mcp_invoice_outcome(v_result,
    jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id', 'invoice_id', v_result->'invoice_id')),
    null, true);
end;
$fn$;

create or replace function public.mcp_op_request_invoice_void(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_result jsonb := public.request_invoice_void(public.mcp_uuid_arg(p_args, 'invoice_id'),
    left(coalesce(p_args->>'reason', ''), 500));
begin
  return public.mcp_invoice_outcome(v_result, jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id')),
    public.mcp_uuid_arg(p_args, 'invoice_id', false), false);
end;
$fn$;

create or replace function public.mcp_op_request_refund(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_result jsonb := public.request_refund(public.mcp_uuid_arg(p_args, 'invoice_id'),
    left(coalesce(p_args->>'note', ''), 500));
begin
  return public.mcp_invoice_outcome(v_result, jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id')),
    public.mcp_uuid_arg(p_args, 'invoice_id', false), false);
end;
$fn$;

-- A member request's answer: the request outcome and the member now.
create or replace function public.mcp_member_outcome(p_status text, p_data jsonb, p_member_id uuid)
returns jsonb language sql security definer set search_path = public as $fn$
  select public.mcp_outcome(p_status, coalesce(p_data, '{}'::jsonb)
    || coalesce(public.mcp_member_view(p_member_id), '{}'::jsonb));
$fn$;
revoke execute on function public.mcp_member_outcome(text, jsonb, uuid) from public, anon, authenticated;

create or replace function public.mcp_op_request_member_status_change(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_member uuid := public.mcp_uuid_arg(p_args, 'member_id');
  v_result jsonb;
begin
  if (select status from public.members where id = v_member) = p_args->>'status' then
    return public.mcp_member_outcome('completed', jsonb_build_object('unchanged', true), v_member);
  end if;
  v_result := public.request_member_status_change(v_member, p_args->>'status');
  return public.mcp_member_outcome(public.mcp_request_outcome(v_result),
    jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id')), v_member);
end;
$fn$;

create or replace function public.mcp_op_request_subscription_change(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_member uuid := public.mcp_uuid_arg(p_args, 'member_id');
  v_result jsonb;
begin
  if (select subscription_pct from public.members where id = v_member) = (p_args->>'pct')::integer then
    return public.mcp_member_outcome('completed', jsonb_build_object('unchanged', true), v_member);
  end if;
  v_result := public.request_subscription_change(v_member, (p_args->>'pct')::integer);
  return public.mcp_member_outcome(public.mcp_request_outcome(v_result),
    jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id')), v_member);
end;
$fn$;

create or replace function public.mcp_op_respond_to_validation(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_event uuid := public.mcp_uuid_arg(p_args, 'event_id');
  v_status text;
begin
  perform public.respond_to_event(v_event, (p_args->>'accept')::boolean);
  v_status := (select status from public.events where id = v_event);
  return public.mcp_outcome(case when v_status = 'pending' then 'pending_validation' else 'completed' end,
    jsonb_build_object('event_id', v_event, 'event_status', v_status,
      'decision_recorded', exists (select 1 from public.event_decisions d
                                    where d.event_id = v_event and d.member_id = c.member_id),
      'effect_applied', v_status in ('applied', 'confirmed')));
end;
$fn$;

-- Every handler is reached only through mcp_execute_v1.
revoke execute on function public.mcp_op_get_capabilities(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_get_my_statement(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_get_member_statement(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_get_availability(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_list_my_reservations(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_get_place(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_list_my_favorites(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_list_my_invoices(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_list_pending_validations(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_get_validation(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_create_reservation(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_update_reservation(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_check_in(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_check_out(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_cancel_reservation(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_request_reservation_deletion(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_set_favorite(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_rate_place(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_request_invoice_issue(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_request_invoice_void(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_request_refund(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_request_member_status_change(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_request_subscription_change(public.mcp_call_context, jsonb) from public, anon, authenticated;
revoke execute on function public.mcp_op_respond_to_validation(public.mcp_call_context, jsonb) from public, anon, authenticated;

-- The facade: authorize, then the operation's handler; no operation name.
create or replace function public.mcp_execute_v1(p_installation_id uuid, p_workspace_id uuid, p_operation text,
                                                 p_arguments jsonb, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  c public.mcp_call_context;
  v_args jsonb := coalesce(p_arguments, '{}'::jsonb);
  v_read boolean;
  v_digest text;
  v_stop jsonb;
  v_retry integer;
  v_out jsonb;
  v_envelope jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  c := public.mcp_authorize(p_installation_id, p_workspace_id, p_operation);
  c.request_id := p_request_id;
  if c.refusal is null and to_regprocedure(
       format('public.%I(public.mcp_call_context, jsonb)', 'mcp_op_' || p_operation)) is null then
    c.refusal := 'unknown_operation';
  end if;
  if c.refusal is not null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
      case when c.refusal = 'unknown_operation' then 'validation_error' else 'denied' end, null, c.refusal));
  end if;
  v_read := c.spec->>'mutation' = 'read';
  if not v_read then
    if p_request_id is null then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
        'validation_error', null, 'invalid_arguments', jsonb_build_object('request_id', 'required')));
    end if;
    v_digest := md5(p_workspace_id::text || '|' || p_operation || '|' || (v_args - 'request_id')::text);
    v_stop := public.mcp_idempotent(c, p_request_id, v_digest);
    if v_stop is not null then return v_stop; end if;
  end if;
  -- #1630 — limited once authorised (a replay is not a new call), before work.
  v_retry := public.mcp_limit_retry_after(p_workspace_id, c.client_id, not v_read);
  if v_retry is not null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
      'rate_limited', null, 'rate_limited') || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry)));
  end if;
  if not v_read and c.spec->>'confirmation' = 'native' then
    v_stop := public.mcp_confirm(c, p_request_id, v_digest, v_args);
    if v_stop is not null then return v_stop; end if;
  end if;
  begin
    execute format('select public.%I($1, $2)', 'mcp_op_' || p_operation) into v_out using c, v_args;
  exception
    when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      v_out := public.mcp_outcome_of(sqlstate, sqlerrm);
    when raise_exception or check_violation or exclusion_violation or unique_violation then
      if v_read then raise; end if;
      v_out := public.mcp_outcome_of(sqlstate, sqlerrm);
  end;
  v_envelope := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, v_out->>'status',
    case when v_out->>'status' = 'validation_error' then null else v_out->'data' end, v_out->>'code', v_out->'fields');
  if not v_read and v_out->>'status' <> 'validation_error' then
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), c.client_id, p_request_id, p_workspace_id, p_operation, v_digest,
            case when v_out->>'status' in ('completed', 'pending_validation') then 'applied' else 'refused' end,
            v_envelope);
  end if;
  return public.mcp_usage_note(c.spec, v_envelope);
end;
$fn$;
revoke execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(407);
