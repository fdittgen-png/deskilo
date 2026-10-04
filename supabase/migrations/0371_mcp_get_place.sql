-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0371 -- an assistant can describe a place, and show it when asked to.
--
-- `get_place` (a read, authority member, scope own) describes one place --
-- a seat, a desk, an office or a level, or the place of one of the
-- person's OWN reservations -- as what it is, where it sits (the label
-- the other tools already use), how many seats it has, what a seat offers
-- and whether it can be booked as a whole.
--
-- A picture is NEVER part of the answer by default. Only `include_image =
-- true` -- which the tool's description tells the assistant to set only
-- when the person explicitly asks for an image, picture, plan or map --
-- adds `render`: the geometry of the place's level and the place to
-- highlight, as one compact string the Edge function draws as a floor-plan
-- picture. The geometry is what the app's own plan shows (grid rectangles
-- and seat points); no photograph, name or person is in it, and the
-- storage bucket (which a delegated token cannot read) is not involved.
--
-- Ids of places other than the person's own reservation reveal the
-- workspace's structure, exactly like get_availability, so they need the
-- workspace target ceiling; an own reservation needs none. The ceiling is
-- handed to the reader by mcp_execute_v1 (never taken from the caller's
-- arguments).


create or replace function public.mcp_place_v1(
  p_workspace_id uuid, p_member public.members, p_args jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_res uuid := public.mcp_uuid_arg(p_args, 'reservation_id', false);
  v_seat uuid := public.mcp_uuid_arg(p_args, 'seat_id', false);
  v_desk uuid := public.mcp_uuid_arg(p_args, 'desk_id', false);
  v_office uuid := public.mcp_uuid_arg(p_args, 'office_id', false);
  v_level uuid := public.mcp_uuid_arg(p_args, 'level_id', false);
  v_image boolean := coalesce(p_args->>'include_image', 'false') = 'true';
  v_given integer;
  v_reservation public.reservations;
  v_seat_row public.seats;
  v_desk_row public.desks;
  v_office_row public.offices;
  v_level_row public.levels;
  v_kind text;
  v_name text;
  v_seats integer;
  v_amenities jsonb;
  v_whole boolean;
  v_render jsonb;
begin
  v_given := (v_res is not null)::int + (v_seat is not null)::int + (v_desk is not null)::int
           + (v_office is not null)::int + (v_level is not null)::int;
  if v_given <> 1 then
    return jsonb_build_object('refused', 'validation_error', 'code', 'invalid_arguments');
  end if;
  -- A place by its id shows the workspace's structure: that is the
  -- workspace ceiling's, as for get_availability. One's own booking is not.
  if v_res is null and coalesce(p_args->>'_ceiling', 'own') <> 'workspace' then
    return jsonb_build_object('refused', 'denied', 'code', 'target_ceiling');
  end if;
  if v_res is not null then
    select * into v_reservation from public.reservations
     where id = v_res and workspace_id = p_workspace_id and member_id = p_member.id;
    if v_reservation.id is null then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_seat := v_reservation.seat_id; v_desk := v_reservation.desk_id;
    v_office := v_reservation.office_id; v_level := v_reservation.level_id;
  end if;

  if v_seat is not null then
    select * into v_seat_row from public.seats where id = v_seat and workspace_id = p_workspace_id;
    if v_seat_row.id is null then return jsonb_build_object('refused', 'not_found', 'code', 'not_found'); end if;
    v_desk := v_seat_row.desk_id;
  end if;
  if v_desk is not null then
    select * into v_desk_row from public.desks where id = v_desk and workspace_id = p_workspace_id;
    if v_desk_row.id is null then return jsonb_build_object('refused', 'not_found', 'code', 'not_found'); end if;
    v_office := v_desk_row.office_id;
  end if;
  if v_office is not null then
    select * into v_office_row from public.offices where id = v_office and workspace_id = p_workspace_id;
    if v_office_row.id is null then return jsonb_build_object('refused', 'not_found', 'code', 'not_found'); end if;
    v_level := v_office_row.level_id;
  end if;
  select * into v_level_row from public.levels where id = v_level and workspace_id = p_workspace_id;
  if v_level_row.id is null then return jsonb_build_object('refused', 'not_found', 'code', 'not_found'); end if;

  v_kind := case when v_seat_row.id is not null then 'seat'
                 when v_desk_row.id is not null then 'desk'
                 when v_office_row.id is not null then 'office' else 'level' end;
  v_name := case v_kind when 'seat' then v_seat_row.name when 'desk' then v_desk_row.name
                        when 'office' then v_office_row.name else v_level_row.name end;
  v_whole := case v_kind when 'desk' then v_desk_row.bookable_as_whole
                         when 'office' then v_office_row.bookable_as_whole
                         when 'level' then v_level_row.bookable_as_whole end;
  select count(*)::int into v_seats
    from public.seats s
    join public.desks d on d.id = s.desk_id
    join public.offices o on o.id = d.office_id
   where s.workspace_id = p_workspace_id
     and case v_kind when 'seat' then s.id = v_seat_row.id
                     when 'desk' then d.id = v_desk_row.id
                     when 'office' then o.id = v_office_row.id
                     else o.level_id = v_level_row.id end;
  select coalesce(jsonb_agg(a order by a), '[]'::jsonb) into v_amenities
    from (select distinct unnest(s.amenities) a
            from public.seats s
            join public.desks d on d.id = s.desk_id
            join public.offices o on o.id = d.office_id
           where s.workspace_id = p_workspace_id
             and case v_kind when 'seat' then s.id = v_seat_row.id
                             when 'desk' then d.id = v_desk_row.id
                             when 'office' then o.id = v_office_row.id
                             else o.level_id = v_level_row.id end
           limit 20) q;

  if v_image then
    -- The level's plan as the app draws it, bounded: a level too large to
    -- draw legibly is not drawn, and the answer says the image is
    -- unavailable rather than sending a partial one.
    select jsonb_build_object(
      'highlight', jsonb_build_object('kind', v_kind, 'id',
        case v_kind when 'seat' then v_seat_row.id when 'desk' then v_desk_row.id
                    when 'office' then v_office_row.id else v_level_row.id end),
      'offices', coalesce((select jsonb_agg(jsonb_build_array(o.id, o.x, o.y, o.w, o.h, o.color) order by o.id)
                             from public.offices o where o.level_id = v_level_row.id), '[]'::jsonb),
      'desks', coalesce((select jsonb_agg(jsonb_build_array(d.id, d.office_id, d.x, d.y, d.w, d.h) order by d.id)
                           from public.desks d join public.offices o on o.id = d.office_id
                          where o.level_id = v_level_row.id), '[]'::jsonb),
      'seats', coalesce((select jsonb_agg(jsonb_build_array(s.id, s.desk_id, s.x, s.y, s.orientation::text) order by s.id)
                           from public.seats s join public.desks d on d.id = s.desk_id
                           join public.offices o on o.id = d.office_id
                          where o.level_id = v_level_row.id), '[]'::jsonb))
      into v_render;
    if jsonb_array_length(v_render->'offices') > 200
       or jsonb_array_length(v_render->'desks') > 800
       or jsonb_array_length(v_render->'seats') > 2000
       or jsonb_array_length(v_render->'offices') = 0 then
      v_render := null;
    end if;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'kind', v_kind,
    'level_id', v_level_row.id, 'office_id', v_office_row.id,
    'desk_id', v_desk_row.id, 'seat_id', v_seat_row.id,
    'reservation_id', v_reservation.id,
    'label', public.mcp_place_label(v_seat_row.id, v_desk_row.id, v_office_row.id, v_level_row.id),
    'name', v_name,
    'seats', v_seats,
    'amenities', v_amenities,
    'bookable_as_whole', v_whole,
    'image_requested', v_image,
    'image_available', case when v_image then v_render is not null else true end,
    'render', case when v_render is null then null else (v_render::text) end));
end;
$fn$;
revoke execute on function public.mcp_place_v1(uuid, public.members, jsonb) from public, anon, authenticated;

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
  -- the reader: one more branch
  v_def := pg_get_functiondef('public.mcp_read_v1(uuid, public.members, text, jsonb)'::regprocedure);
  if position('mcp_place_v1' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');$a$,
      $a$  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');$a$);
    if v_next is null then raise exception '0371: the reader anchor did not match'; end if;
    execute v_next;
  end if;
  -- the facade: the reader is told the ceiling, never asked for it
  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('_ceiling' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$v_data := public.mcp_read_v1(p_workspace_id, v_member, p_operation, v_args);$a$,
      $a$v_data := public.mcp_read_v1(p_workspace_id, v_member, p_operation,
          (v_args - '_ceiling') || jsonb_build_object('_ceiling', v_ceiling));$a$);
    if v_next is null then raise exception '0371: the facade anchor did not match'; end if;
    execute v_next;
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(371);

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","expires_at","operations","reason","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","currency","eligible_until","expires_at","opening_hours","operations","reason","target_ceiling","time_zone","unchanged"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","free","items","label","level_id","next_cursor","not_checked","observed_at","office_id","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","label","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_place":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["amenities","bookable_as_whole","confirmation_id","desk_id","expires_at","image_available","image_requested","kind","label","level_id","office_id","reason","render","reservation_id","seat_id","seats","unchanged"],"optional":["name"]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"cancel_reservation":{"rpc":"cancel_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;

revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

select public.set_deskilo_schema_version(371);
