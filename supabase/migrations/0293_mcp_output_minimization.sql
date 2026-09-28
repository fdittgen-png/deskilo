-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0293 (#1644) -- what an MCP answer may carry is decided by the contract,
-- in the database, for every answer and every replay. (0292 is Codex's
-- #1648 identity hook; this follows it.)
--
-- contracts/mcp/operations.json now classifies every output field
-- (output_fields: operational / display) and every operation declares
-- the fields it emits; the catalogue below carries, per operation, the
-- operational fields it may return by default. mcp_envelope projects
-- `data` through that allow-list, recursively (nested objects and item
-- lists): an unclassified or display field -- a seat's label that can
-- name a person, any key a handler adds later without classifying it --
-- never leaves the database, so the same OAuth token calling the SQL
-- facade directly gets the same minimized answer the MCP server returns.
-- There is no switch to widen it (#1645 owns named disclosure).
--
-- A replay re-projects the stored outcome through the CURRENT allow-list
-- instead of returning it as saved, so an answer stored wider than today's
-- policy is narrowed, never re-run. And a refusal keeps its reason only
-- when it is a business rule's own sentence (SQLSTATE P0001); a
-- constraint or driver message, which can name tables and values, leaves
-- only the code.

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","environment","expires_at","reason","role","unchanged","workspace_id"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","eligible_until","expires_at","operations","reason","target_ceiling","unchanged"]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","ends_at","expires_at","free","items","next_cursor","not_checked","observed_at","reason","seat_id","starts_at","unchanged","window"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageBilling","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"]}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

create or replace function public.mcp_project_data(p_operation text, p_value jsonb)
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  v_allowed jsonb := coalesce(public.mcp_operation_catalogue()->'operations'->p_operation->'output', '[]'::jsonb);
  v_out jsonb;
  v_key text;
  v_inner jsonb;
begin
  if p_value is null then
    return null;
  elsif jsonb_typeof(p_value) = 'array' then
    select coalesce(jsonb_agg(public.mcp_project_data(p_operation, e) order by o), '[]'::jsonb)
      into v_out from jsonb_array_elements(p_value) with ordinality x(e, o);
    return v_out;
  elsif jsonb_typeof(p_value) <> 'object' then
    return p_value;
  end if;
  v_out := '{}'::jsonb;
  for v_key, v_inner in select key, value from jsonb_each(p_value) loop
    if v_allowed ? v_key then
      v_out := v_out || jsonb_build_object(v_key, public.mcp_project_data(p_operation, v_inner));
    end if;
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.mcp_project_data(text, jsonb) from public, anon, authenticated;

create or replace function public.mcp_envelope(
  p_request_id uuid, p_operation text, p_workspace_id uuid, p_status text,
  p_data jsonb default null, p_code text default null, p_fields jsonb default null)
returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_strip_nulls(jsonb_build_object(
    'schema_version', 1, 'request_id', p_request_id, 'operation', p_operation,
    'workspace_id', p_workspace_id, 'status', p_status,
    'data', public.mcp_project_data(p_operation, p_data),
    'error', case when p_code is null then null
                  else jsonb_strip_nulls(jsonb_build_object('code', p_code, 'fields', p_fields)) end));
$fn$;
revoke execute on function public.mcp_envelope(uuid, text, uuid, text, jsonb, text, jsonb) from public, anon, authenticated;

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
  v_def text := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  v_next text;
begin
  if position('#1644' in v_def) > 0 then
    return;
  end if;
  v_next := pg_temp.anchor_replace(v_def,
    $a$    return v_prior.outcome;$a$,
    $a$    -- #1644 — the stored answer, through TODAY's allow-list.
    return v_prior.outcome || jsonb_strip_nulls(jsonb_build_object('data',
      public.mcp_project_data(p_operation, v_prior.outcome->'data')));$a$);
  if v_next is null then raise exception '0293: replay anchor not found'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def,
    $a$v_data := jsonb_build_object('reason', left(sqlerrm, 200));$a$,
    $a$v_data := jsonb_build_object('reason', case when sqlstate = 'P0001' then left(sqlerrm, 200) end);$a$);
  if v_next is null then raise exception '0293: refusal anchor not found'; end if;
  execute v_next;
end
$migration$;

select public.set_deskilo_schema_version(293);
