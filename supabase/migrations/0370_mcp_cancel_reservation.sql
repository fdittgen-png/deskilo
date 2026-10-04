-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0370 -- an assistant can cancel a booking that has not started.
--
-- request_reservation_deletion is the path for a booking that already
-- STARTED (the workspace's validation rules decide); for one that has not,
-- the app cancels directly (cancel_reservation) and the deletion request
-- is refused with "cancel directly -- this booking has not started". The
-- MCP contract had only the first, so an assistant asked to cancel next
-- week's booking could not.
--
-- `cancel_reservation` is a new operation of the contract (authority self,
-- scope own, request-id idempotent, destructive): the person's own booking,
-- through the native cancel_reservation, which owns every rule (who may
-- cancel, the event, the notification). It rides the same guards as the
-- other owned-reservation operations in mcp_execute_v1: the target is the
-- caller's own booking in this workspace, an expected_state that no longer
-- matches is a stale conflict carrying the current state, the answer reads
-- the reservation back, and a replay of the same request_id returns the
-- stored answer.

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","expires_at","operations","reason","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","currency","eligible_until","expires_at","opening_hours","operations","reason","target_ceiling","time_zone","unchanged"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","free","items","label","level_id","next_cursor","not_checked","observed_at","office_id","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","label","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"cancel_reservation":{"rpc":"cancel_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;

revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('cancel_reservation' in v_def) = 0 then
    -- the owned-reservation guard (own booking, stale expected state)
    v_next := pg_temp.anchor_replace(v_def,
      $a$if p_operation in ('update_reservation', 'check_in', 'check_out', 'request_reservation_deletion') then$a$,
      $a$if p_operation in ('update_reservation', 'check_in', 'check_out', 'cancel_reservation',
                         'request_reservation_deletion') then$a$);
    if v_next is null then raise exception '0370: the guard anchor did not match'; end if;
    v_def := v_next;
    -- the branch
    v_next := pg_temp.anchor_replace(v_def,
      $a$      elsif p_operation = 'request_reservation_deletion' then$a$,
      $a$      elsif p_operation = 'cancel_reservation' then
        perform public.cancel_reservation(v_reservation.id);
      elsif p_operation = 'request_reservation_deletion' then$a$);
    if v_next is null then raise exception '0370: the branch anchor did not match'; end if;
    v_def := v_next;
    -- the read-back
    v_next := pg_temp.anchor_replace(v_def,
      $a$      if p_operation in ('create_reservation', 'update_reservation', 'check_in', 'check_out',
                         'request_reservation_deletion') then$a$,
      $a$      if p_operation in ('create_reservation', 'update_reservation', 'check_in', 'check_out',
                         'cancel_reservation', 'request_reservation_deletion') then$a$);
    if v_next is null then raise exception '0370: the read-back anchor did not match'; end if;
    execute v_next;
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(370);
