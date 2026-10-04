-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0375 (#2185) -- favourites and ratings through an assistant.
--
--   * list_my_favorites: the person's favourite places, labelled and rated;
--     the ids go straight into create_reservation.
--   * set_favorite and rate_place: the two writes, as the person, through
--     the facade (request-id idempotency like every write). They refuse
--     with the reason when the feature is off or the permission to use
--     reservations is not held, exactly as in the app.
--   * get_place carries the favourite mark and the rating, and describes a
--     place the person favourited without the workspace ceiling: it is
--     theirs.

create or replace function public.mcp_place_feedback_write(
  p_workspace uuid, p_operation text, p_args jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_kind text := p_args->>'kind';
  v_id uuid := public.mcp_uuid_arg(p_args, 'resource_id');
  v_member public.members;
  v_stars integer;
begin
  if v_kind is null or v_kind not in ('seat', 'desk', 'office', 'level') then
    raise exception using errcode = '22023', message = 'kind';
  end if;
  v_member := public.place_feedback_member(p_workspace, v_kind, v_id);
  if p_operation = 'set_favorite' then
    if coalesce((p_args->>'favorite')::boolean, true) then
      insert into public.resource_favorites (workspace_id, member_id, kind, resource_id)
      values (p_workspace, v_member.id, v_kind, v_id)
      on conflict (member_id, kind, resource_id) do nothing;
    else
      delete from public.resource_favorites
       where member_id = v_member.id and kind = v_kind and resource_id = v_id;
    end if;
  else
    if coalesce((p_args->>'clear')::boolean, false) then
      delete from public.resource_ratings
       where member_id = v_member.id and kind = v_kind and resource_id = v_id;
    else
      if p_args->>'stars' is null then
        raise exception using errcode = '22023', message = 'stars';
      end if;
      v_stars := (p_args->>'stars')::integer;
      if v_stars not between 0 and 5 then
        raise exception using errcode = '22023', message = 'stars';
      end if;
      insert into public.resource_ratings (workspace_id, member_id, kind, resource_id, stars)
      values (p_workspace, v_member.id, v_kind, v_id, v_stars)
      on conflict (member_id, kind, resource_id) do update set stars = excluded.stars;
    end if;
  end if;
  return public.place_rating_summary(p_workspace, v_kind, v_id, v_member.id);
end;
$fn$;
revoke execute on function public.mcp_place_feedback_write(uuid, text, jsonb) from public, anon, authenticated;

create or replace function public.mcp_favorites_v1(p_workspace uuid)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('items', public.my_favorites(p_workspace));
$fn$;
revoke execute on function public.mcp_favorites_v1(uuid) from public, anon, authenticated;

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
  -- the facade: the two writes
  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('mcp_place_feedback_write' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$      elsif p_operation = 'request_reservation_deletion' then
        v_id := public.request_reservation_deletion($a$,
      $a$      elsif p_operation in ('set_favorite', 'rate_place') then
        v_data := public.mcp_place_feedback_write(p_workspace_id, p_operation, v_args);
      elsif p_operation = 'request_reservation_deletion' then
        v_id := public.request_reservation_deletion($a$);
    if v_next is null then raise exception '0375: the facade anchor did not match'; end if;
    execute v_next;
  end if;

  -- the reader: the list
  v_def := pg_get_functiondef('public.mcp_read_v1(uuid, public.members, text, jsonb)'::regprocedure);
  if position('mcp_favorites_v1' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  if p_operation = 'get_place' then$a$,
      $a$  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then$a$);
    if v_next is null then raise exception '0375: the reader anchor did not match'; end if;
    execute v_next;
  end if;

  -- get_place: the mark and the rating, and a favourite is the person's own
  v_def := pg_get_functiondef('public.mcp_place_v1(uuid, public.members, jsonb)'::regprocedure);
  if position('place_rating_summary' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  if v_res is null and coalesce(p_args->>'_ceiling', 'own') <> 'workspace' then$a$,
      $a$  if v_res is null and coalesce(p_args->>'_ceiling', 'own') <> 'workspace'
     and not exists (select 1 from public.resource_favorites f
                      where f.member_id = p_member.id
                        and f.resource_id = coalesce(v_seat, v_desk, v_office, v_level)) then$a$);
    if v_next is null then raise exception '0375: the ceiling anchor did not match'; end if;
    v_next := pg_temp.anchor_replace(v_next,
      $a$    'image_requested', v_image,$a$,
      $a$    'favorite', case when public.feature_effective(p_workspace_id, 'placeFeedback')
                     then (public.place_rating_summary(p_workspace_id, v_kind,
                       case v_kind when 'seat' then v_seat_row.id when 'desk' then v_desk_row.id
                                   when 'office' then v_office_row.id else v_level_row.id end,
                       p_member.id))->'favorite' end,
    'rating', case when public.feature_effective(p_workspace_id, 'placeFeedback')
                   then (public.place_rating_summary(p_workspace_id, v_kind,
                     case v_kind when 'seat' then v_seat_row.id when 'desk' then v_desk_row.id
                                 when 'office' then v_office_row.id else v_level_row.id end,
                     p_member.id)) - 'favorite' end,
    'image_requested', v_image,$a$);
    if v_next is null then raise exception '0375: the result anchor did not match'; end if;
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
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","expires_at","operations","reason","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["afternoon","booking_periods","confirmation_id","currency","eligible_until","expires_at","from","full_day","granularity","half_boundary","morning","open_weekdays","opening_hours","operations","reason","target_ceiling","time_zone","to","unchanged","work_end","work_start"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","free","items","label","level_id","next_cursor","not_checked","observed_at","office_id","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","label","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_place":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["amenities","average","bookable_as_whole","confirmation_id","count","desk_id","expires_at","favorite","image_available","image_requested","kind","label","level_id","mine","office_id","rating","reason","render","reservation_id","seat_id","seats","unchanged"],"optional":["name"]},"list_my_favorites":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","placeFeedback"],"scope":"own","mutation":"read","confirmation":"none","output":["average","confirmation_id","count","expires_at","favorite","items","kind","label","mine","rating","reason","resource_id","unchanged"],"optional":[]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"cancel_reservation":{"rpc":"cancel_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"set_favorite":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","placeFeedback"],"scope":"own","mutation":"write","confirmation":"none","output":["average","confirmation_id","count","expires_at","favorite","mine","reason","unchanged"],"optional":[]},"rate_place":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","placeFeedback"],"scope":"own","mutation":"write","confirmation":"none","output":["average","confirmation_id","count","expires_at","favorite","mine","reason","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;

revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

select public.set_deskilo_schema_version(375);
