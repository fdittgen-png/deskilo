-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0372 -- an assistant books by the workspace's own periods.
--
-- A workspace books in named periods (morning, afternoon, the full working
-- day) whose exact times are its own configuration (work_start,
-- half_boundary, work_end, in its time zone). An assistant that had to
-- compute those times itself guessed them and was refused. Now:
--   * get_capabilities answers `booking_periods`: each period with its
--     exact local from/to;
--   * create_reservation and update_reservation accept `date` +
--     `period` instead of starts_at/ends_at, and the SERVER turns them
--     into the workspace's exact times (never the caller);
--   * giving both a period and explicit times is ambiguous and refused.
-- The booking engine is untouched: it still validates the result exactly
-- as for a person in the app.


-- the workspace's periods as minutes of the local day
create or replace function public.mcp_booking_period_minutes(p_workspace_id uuid)
returns table (work_start integer, half_boundary integer, work_end integer, tz text)
language sql stable security definer set search_path = public as $fn$
  select coalesce((w.booking_rules->>'work_start_minutes')::int, 480),
         coalesce((w.booking_rules->>'half_boundary_minutes')::int, 720),
         coalesce((w.booking_rules->>'work_end_minutes')::int, 1020),
         w.timezone
    from public.workspaces w where w.id = p_workspace_id;
$fn$;
revoke execute on function public.mcp_booking_period_minutes(uuid) from public, anon, authenticated;

create or replace function public.mcp_booking_periods(p_workspace_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'morning', jsonb_build_object(
      'from', to_char(make_interval(mins => m.work_start), 'HH24:MI'),
      'to', to_char(make_interval(mins => m.half_boundary), 'HH24:MI')),
    'afternoon', jsonb_build_object(
      'from', to_char(make_interval(mins => m.half_boundary), 'HH24:MI'),
      'to', to_char(make_interval(mins => m.work_end), 'HH24:MI')),
    'full_day', jsonb_build_object(
      'from', to_char(make_interval(mins => m.work_start), 'HH24:MI'),
      'to', to_char(make_interval(mins => m.work_end), 'HH24:MI')))
  from public.mcp_booking_period_minutes(p_workspace_id) m;
$fn$;
revoke execute on function public.mcp_booking_periods(uuid) from public, anon, authenticated;

-- date + period -> starts_at/ends_at, in the workspace's time zone
create or replace function public.mcp_apply_period(p_workspace_id uuid, p_args jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  m record;
  v_from integer;
  v_to integer;
  v_day date;
begin
  if not (p_args ? 'period' or p_args ? 'date') then
    return p_args;
  end if;
  if p_args ? 'starts_at' or p_args ? 'ends_at' then
    raise exception using errcode = '22023', message = 'period';
  end if;
  if coalesce(p_args->>'date', '') !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception using errcode = '22023', message = 'date';
  end if;
  v_day := (p_args->>'date')::date;
  select * into m from public.mcp_booking_period_minutes(p_workspace_id);
  case p_args->>'period'
    when 'morning' then v_from := m.work_start; v_to := m.half_boundary;
    when 'afternoon' then v_from := m.half_boundary; v_to := m.work_end;
    when 'full_day' then v_from := m.work_start; v_to := m.work_end;
    else raise exception using errcode = '22023', message = 'period';
  end case;
  return (p_args - 'date' - 'period') || jsonb_build_object(
    'starts_at', to_jsonb(((v_day::timestamp + make_interval(mins => v_from)) at time zone m.tz)) #>> '{}',
    'ends_at', to_jsonb(((v_day::timestamp + make_interval(mins => v_to)) at time zone m.tz)) #>> '{}');
end;
$fn$;
revoke execute on function public.mcp_apply_period(uuid, jsonb) from public, anon, authenticated;

-- get_capabilities: the periods beside the opening hours
create or replace function public.mcp_workspace_context(p_workspace_id uuid)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object(
    'time_zone', w.timezone,
    'currency', w.currency_code,
    'opening_hours', jsonb_strip_nulls(jsonb_build_object(
      'open_weekdays', coalesce(w.booking_rules->'open_weekdays', '[1,2,3,4,5]'::jsonb),
      'work_start', to_char(make_interval(mins => coalesce((w.booking_rules->>'work_start_minutes')::int, 480)), 'HH24:MI'),
      'half_boundary', to_char(make_interval(mins => coalesce((w.booking_rules->>'half_boundary_minutes')::int, 720)), 'HH24:MI'),
      'work_end', to_char(make_interval(mins => coalesce((w.booking_rules->>'work_end_minutes')::int, 1020)), 'HH24:MI'),
      'granularity', w.booking_rules->>'granularity')),
    'booking_periods', public.mcp_booking_periods(w.id))
    from public.workspaces w where w.id = p_workspace_id;
$fn$;

revoke execute on function public.mcp_workspace_context(uuid) from public, anon;

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
  if position('mcp_apply_period' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$    if v_status = 'completed' then
      if p_operation = 'create_reservation' then$a$,
      $a$    if v_status = 'completed' then
      if p_operation in ('create_reservation', 'update_reservation') then
        v_args := public.mcp_apply_period(p_workspace_id, v_args);
      end if;
      if p_operation = 'create_reservation' then$a$);
    if v_next is null then raise exception '0372: the facade anchor did not match'; end if;
    execute v_next;
  end if;
end
$migration$;

notify pgrst, 'reload schema';

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","expires_at","operations","reason","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["afternoon","booking_periods","confirmation_id","currency","eligible_until","expires_at","from","full_day","granularity","half_boundary","morning","open_weekdays","opening_hours","operations","reason","target_ceiling","time_zone","to","unchanged","work_end","work_start"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","free","items","label","level_id","next_cursor","not_checked","observed_at","office_id","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","label","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_place":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["amenities","bookable_as_whole","confirmation_id","desk_id","expires_at","image_available","image_requested","kind","label","level_id","office_id","reason","render","reservation_id","seat_id","seats","unchanged"],"optional":["name"]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"cancel_reservation":{"rpc":"cancel_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;

revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

select public.set_deskilo_schema_version(372);
