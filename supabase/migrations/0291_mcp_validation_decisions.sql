-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0291 (#1624) -- a validation decision through MCP says what it did: the
-- decision recorded, the event's status, and whether the business effect
-- was applied, never "completed" while others still have to decide.
--
-- respond_to_validation already runs through mcp_execute_v1 with the
-- workspace-scoped event target, the #1619 single-use native confirmation
-- bound to that event's exact revision, request-id idempotency, and the
-- existing respond_to_event, which owns the distinct-person quorum (one
-- decision per member per event, whatever client or request id), the
-- validator pool, owner/sequential rules and the application. Gaps:
--   * an accept that is not a boolean was put to a person to confirm; it
--     is now refused as invalid_arguments first;
--   * the answer was only the event id and status, reported as
--     completed even when the event still waits for other validators; it
--     now carries decision_recorded, event_status and effect_applied, and
--     answers pending_validation while the event is pending.
--   * the tool demanded manageValidation, the right to CONFIGURE
--     validation, which the policy's own validators (admins by default)
--     do not hold: an eligible validator could decide in the app but not
--     through MCP. Its authority is now 'member'; respond_to_event alone
--     decides who may decide (scope, pool, owner and sequential rules).

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none"},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none"},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none"},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none"},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none"},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none"},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageBilling","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native"},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none"},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native"}}}$json$::jsonb
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
  v_def := pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure);
  if position('#1624' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  -- #1622 — a request a person could never approve is not put to them.$a$,
      $a$  -- #1624 — a decision is yes or no, never something to guess at.
  if p_operation = 'respond_to_validation'
     and coalesce(p_args->>'accept', '') not in ('true', 'false') then
    raise exception using errcode = '22023', message = 'accept';
  end if;
  -- #1622 — a request a person could never approve is not put to them.$a$);
    if v_next is null then raise exception '0291: mcp_target anchor not found (needs 0289)'; end if;
    execute v_next;
  end if;

  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('decision_recorded' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$        v_data := jsonb_build_object('event_id', public.mcp_uuid_arg(v_args, 'event_id'),
          'event_status', (select status from public.events where id = public.mcp_uuid_arg(v_args, 'event_id')));$a$,
      $a$        v_data := jsonb_build_object('event_id', public.mcp_uuid_arg(v_args, 'event_id'),
          'event_status', (select status from public.events where id = public.mcp_uuid_arg(v_args, 'event_id')),
          'decision_recorded', exists (select 1 from public.event_decisions d
                                        where d.event_id = public.mcp_uuid_arg(v_args, 'event_id')
                                          and d.member_id = v_member.id),
          'effect_applied', (select status from public.events where id = public.mcp_uuid_arg(v_args, 'event_id'))
                            in ('applied', 'confirmed'));
        if v_data->>'event_status' = 'pending' then
          v_status := 'pending_validation';
        end if;$a$);
    if v_next is null then raise exception '0291: respond_to_validation branch not found'; end if;
    execute v_next;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(291);
