-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- Place visibility is shared by booking events and their readers. Commands
-- check authority and the target's visibility before validating its details.

CREATE OR REPLACE FUNCTION public.room_visible(p_office uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ws uuid;
  v_kind text;
  v_rental public.room_rentals;
  v_me uuid;
begin
  select o.workspace_id, l.kind into v_ws, v_kind
    from public.offices o join public.levels l on l.id = o.level_id where o.id = p_office;
  if v_ws is null then return false; end if;
  select * into v_rental from public.room_rentals where office_id = p_office;
  if v_kind = 'own' and v_rental.id is null then return true; end if;
  if public.has_permission(v_ws, 'manageSites') then return true; end if;
  if v_rental.id is null or v_rental.status <> 'active' then return false; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = v_ws and m.user_id = auth.uid() and m.status = 'active';
  return v_me is not null and public.room_audience_has(v_rental.id, v_me);
end;
$function$;

CREATE OR REPLACE FUNCTION public.level_visible(p_level uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_ws uuid; v_kind text;
begin
  select workspace_id, kind into v_ws, v_kind from public.levels where id = p_level;
  if v_ws is null then return false; end if;
  if v_kind = 'own' then return true; end if;
  return public.has_permission(v_ws, 'manageSites')
      or exists (select 1 from public.offices o where o.level_id = p_level and public.room_visible(o.id));
end;
$function$;

CREATE OR REPLACE FUNCTION public.desk_room_visible(p_desk uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select public.room_visible(d.office_id) from public.desks d where d.id = p_desk), false);
$function$;

CREATE OR REPLACE FUNCTION public.reservation_place_visible(p_workspace uuid, p_member uuid, p_seat uuid, p_desk uuid, p_office uuid, p_level uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid;
  v_desk uuid;
  v_office uuid;
  v_level uuid;
begin
  -- Resolve an actual place of this business before the own-booking rule.
  if num_nonnulls(p_seat, p_desk, p_office, p_level) <> 1 then return false; end if;
  if p_seat is not null and not exists (select 1 from public.seats s where s.id = p_seat and s.workspace_id = p_workspace)
     or p_desk is not null and not exists (select 1 from public.desks d where d.id = p_desk and d.workspace_id = p_workspace)
     or p_office is not null and not exists (select 1 from public.offices o where o.id = p_office and o.workspace_id = p_workspace)
     or p_level is not null and not exists (select 1 from public.levels l where l.id = p_level and l.workspace_id = p_workspace)
  then return false; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace and m.user_id = auth.uid() and m.status = 'active';
  if v_me is not null and v_me = p_member and exists (
    select 1 from public.reservations r
     where r.workspace_id = p_workspace and r.member_id = v_me
       and r.seat_id is not distinct from p_seat
       and r.desk_id is not distinct from p_desk
       and r.office_id is not distinct from p_office
       and r.level_id is not distinct from p_level
  ) then return true; end if;
  v_desk := coalesce(p_desk, (select s.desk_id from public.seats s where s.id = p_seat));
  v_office := coalesce(p_office, (select d.office_id from public.desks d where d.id = v_desk));
  v_level := coalesce(p_level, (select o.level_id from public.offices o where o.id = v_office));
  if v_me is null then return false; end if;
  return public.place_visible_to(v_me, v_office, case when v_office is null then v_level end);
end;
$function$;

create or replace function public.booking_event_visible(p_workspace uuid, p_reservation uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_reservation is null or exists (
    select 1 from public.reservations r
     where r.id = p_reservation and r.workspace_id = p_workspace
       and public.reservation_place_visible(r.workspace_id, r.member_id, r.seat_id,
                                            r.desk_id, r.office_id, r.level_id));
$fn$;
revoke execute on function public.booking_event_visible(uuid, uuid) from public, anon;
grant execute on function public.booking_event_visible(uuid, uuid) to authenticated;

create policy events_booking_visibility on public.events as restrictive for select to authenticated
  using (public.booking_event_visible(workspace_id, reservation_id));

do $patch$
declare
  v_def text := pg_get_functiondef('public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure);
  v_old constant text := $a$and public.event_readable(e.workspace_id, e.type, e.actor_member_id, e.subject_member_id);$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 2 then
    raise exception 'calendar_items: expected anchor count 2' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$and public.event_readable(e.workspace_id, e.type, e.actor_member_id, e.subject_member_id)
       and public.booking_event_visible(e.workspace_id, e.reservation_id);$a$);
end;
$patch$;

CREATE OR REPLACE FUNCTION public.mcp_read_v1(p_workspace_id uuid, p_member members, p_operation text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_readable text[];
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
  v_level uuid;
  v_office uuid;
  v_kind text;
  v_page jsonb;
  v_more boolean;
  -- #2391 — beyond her own rows only when her consent reaches the
  -- workspace (the facade always says which; a direct definer call is the
  -- service role's).
  v_wide boolean := coalesce(p_args->>'_ceiling', 'workspace') = 'workspace';
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > make_interval(days => (public.setting_value(null, 'mcp.read_range_days') #>> '{}')::int) then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id, x.desk_id, x.office_id, x.level_id),
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
    -- #2145 — optionally one level or one office; #2391 — every kind the app
    -- books (seats, and desks, offices and levels booked as a whole),
    -- optionally one kind. A page is the next place ids in order; it is
    -- shown by label, and the cursor follows the ids it paged by. "free" is
    -- the booking engine's own verdict (0345), asked only for this page.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    v_kind := nullif(p_args->>'kind', '');
    if v_kind is not null and v_kind not in ('seat', 'desk', 'office', 'level', 'room', 'parking') then
      raise exception using errcode = '22023', message = 'kind';
    end if;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.id), '[]'::jsonb) into v_page
      from (select p.*
              from (select s.resource_kind as kind, s.id, s.id as seat_id, d.id as desk_id, o.id as office_id,
                           o.level_id, s.name
                      from public.seats s
                      join public.desks d on d.id = s.desk_id
                      join public.offices o on o.id = d.office_id
                     where s.workspace_id = p_workspace_id
                       and public.resource_kind_enabled(p_workspace_id, s.resource_kind)
                    union all
                    select 'desk', d.id, null, d.id, o.id, o.level_id, d.name
                      from public.desks d
                      join public.offices o on o.id = d.office_id
                     where d.workspace_id = p_workspace_id and d.bookable_as_whole
                    union all
                    select 'office', o.id, null, null, o.id, o.level_id, o.name
                      from public.offices o
                     where o.workspace_id = p_workspace_id and o.bookable_as_whole
                    union all
                    select 'level', l.id, null, null, null, l.id, l.name
                      from public.levels l
                     where l.workspace_id = p_workspace_id and l.bookable_as_whole) p
             where public.place_visible_to(p_member.id, p.office_id, case when p.kind = 'level' then p.level_id end)
               and (v_kind is null or p.kind = v_kind)
               and (v_level is null or p.level_id = v_level)
               and (v_office is null or p.office_id = v_office)
               and (v_after_id is null or p.id > v_after_id)
             order by p.id
             limit v_limit + 1) q;
    v_more := jsonb_array_length(v_page) > v_limit;
    if v_more then
      v_page := v_page - v_limit;
    end if;
    select coalesce(jsonb_agg(r order by r->>'label', r->>'kind', coalesce(r->>'seat_id', r->>'desk_id',
                                 r->>'office_id', r->>'level_id')), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('kind', x.kind, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end),
                 'name', x.name,
                 'free', public.mcp_place_bookable(p_workspace_id, x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end, v_from, v_to) is null) as r
          from jsonb_to_recordset(v_page) as x(kind text, id uuid, seat_id uuid, desk_id uuid,
                                               office_id uuid, level_id uuid, name text)) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(),
          (v_page->(jsonb_array_length(v_page) - 1)->>'id')::uuid) end,
      'not_checked', jsonb_build_array('price', 'approval'));
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
    -- #4143 -- of the types waiting in this business, those the caller may
    -- read (event_readable), asked once per type, not per row.
    v_readable := array(select x.t from (select distinct e.type as t from public.events e
                                          where e.workspace_id = p_workspace_id and e.status = 'pending'
           and public.booking_event_visible(e.workspace_id, e.reservation_id)) x
                         where public.event_readable(p_workspace_id, x.t, null, null));
    -- Pending events the caller authored or is the subject of; under a
    -- workspace ceiling also the ones she may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and public.booking_event_visible(e.workspace_id, e.reservation_id)
           and (((e.actor_member_id = p_member.id or e.subject_member_id = p_member.id)
                 and public.event_type_restriction_holds(e.workspace_id, e.type))
                or (v_wide and e.type = any(v_readable)))
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
       or not public.booking_event_visible(v_event.workspace_id, v_event.reservation_id)
       or not (((v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id)
                and public.event_type_restriction_holds(v_event.workspace_id, v_event.type))
               or (v_wide and public.event_readable(v_event.workspace_id, v_event.type,
                                                    v_event.actor_member_id, v_event.subject_member_id))) then
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
        when raise_exception
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36'
      -- #3811: an invoicing refusal carries its code (0742).
      or sqlstate 'DKI01' or sqlstate 'DKI03' or sqlstate 'DKI04' or sqlstate 'DKI05' or sqlstate 'DKI06' or sqlstate 'DKI07' or sqlstate 'DKD01'
      -- #3821: a permission refusal carries its code (0745).
      or sqlstate 'DKN01' then
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

  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$function$;
revoke execute on function public.mcp_read_v1 (uuid, members, text, jsonb) from public, anon, authenticated;



CREATE OR REPLACE FUNCTION public.mcp_target(p_workspace_id uuid, p_operation text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.invoices;
  v_member public.members;
  v_event public.events;
  v_name text;
begin
  -- #1623 — nor a percentage or a status the workflow would refuse.
  if p_operation = 'request_subscription_change'
     and (coalesce(p_args->>'pct', '') !~ '^\d{1,3}$'
          or (p_args->>'pct')::integer not between 0 and 100) then
    raise exception using errcode = '22023', message = 'pct';
  end if;
  if p_operation = 'request_member_status_change'
     and coalesce(p_args->>'status', '') not in ('active', 'paused', 'exited') then
    raise exception using errcode = '22023', message = 'status';
  end if;
  -- #1624 — a decision is yes or no, never something to guess at.
  if p_operation = 'respond_to_validation'
     and coalesce(p_args->>'accept', '') not in ('true', 'false') then
    raise exception using errcode = '22023', message = 'accept';
  end if;
  -- #1622 — a request a person could never approve is not put to them.
  if p_operation = 'request_invoice_issue'
     and coalesce(p_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception using errcode = '22023', message = 'period';
  end if;
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
    -- #4146 -- an event the caller may not read is answered as one not found.
    if v_event.id is null
       or not public.booking_event_visible(v_event.workspace_id, v_event.reservation_id)
       or public.event_readable(v_event.workspace_id, v_event.type,
                                v_event.actor_member_id, v_event.subject_member_id) is not true then
      return null;
    end if;
    return jsonb_build_object('kind', 'event', 'id', v_event.id, 'type', v_event.type,
      'status', v_event.status, 'revision', md5(to_jsonb(v_event)::text));
  end if;
  return null;
end;
$function$;
revoke execute on function public.mcp_target(uuid, text, jsonb) from public, anon, authenticated;

do $patch$
declare
  v_def text := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_old constant text := $a$and public.event_type_restriction_holds(e.workspace_id, e.type)),$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'export_my_data: expected anchor count 1' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$and public.event_type_restriction_holds(e.workspace_id, e.type)
                  and public.booking_event_visible(e.workspace_id, e.reservation_id)),$a$);
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.cancel_reservation(uuid)'::regprocedure);
  v_old constant text := $a$if v_res.id is null then raise exception 'not your reservation' using errcode = 'DKK29'; end if;$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'cancel_reservation: expected anchor count 1' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$if v_res.id is null or not public.reservation_place_visible(
       v_res.workspace_id, v_res.member_id, v_res.seat_id, v_res.desk_id, v_res.office_id, v_res.level_id) then
    raise exception 'not your reservation' using errcode = 'DKK29';
  end if;$a$);
end;
$patch$;

create or replace function public.set_seat_block(
  p_seat_id uuid, p_blocked_from timestamptz, p_blocked_to timestamptz
) returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_workspaces uuid[];
  v_workspace_id uuid;
begin
  -- The right is established without reading a seat or its dates.
  select array_agg(m.workspace_id) into v_workspaces from public.members m
   where m.user_id = auth.uid() and m.status = 'active'
     and (public.is_owner_of(m.workspace_id)
       or (public.has_permission(m.workspace_id, 'manageReservations')
           and public.feature_operation_allowed(m.workspace_id, 'adminSeatBlocking',
             case when p_blocked_from is null and p_blocked_to is null
                  then 'service_existing' else 'accept_new' end)));
  if v_workspaces is null then
    raise exception 'only the owner, or an admin with the adminSeatBlocking feature, may block seats' using errcode = 'P0001';
  end if;
  select s.workspace_id into v_workspace_id from public.seats s
   where s.id = p_seat_id and s.workspace_id = any(v_workspaces)
     and public.desk_room_visible(s.desk_id);
  if v_workspace_id is null then raise exception 'unknown seat' using errcode = 'P0001'; end if;
  if p_blocked_from is not null and p_blocked_to is not null and p_blocked_to <= p_blocked_from then
    raise exception 'blocked_to must be after blocked_from' using errcode = 'P0001';
  end if;
  update public.seats set blocked_from = p_blocked_from, blocked_to = p_blocked_to
   where id = p_seat_id and workspace_id = v_workspace_id;
end;
$fn$;

revoke execute on function public.room_visible(uuid) from public, anon;
revoke execute on function public.level_visible(uuid) from public, anon;
revoke execute on function public.desk_room_visible(uuid) from public, anon;
revoke execute on function public.reservation_place_visible(uuid, uuid, uuid, uuid, uuid, uuid) from public, anon;
revoke execute on function public.set_seat_block(uuid, timestamptz, timestamptz) from public, anon;

-- Sites holders may read the room they are creating with INSERT RETURNING;
-- a stable id lookup cannot yet see that new row in the statement snapshot.
drop policy offices_external_hidden on public.offices;
create policy offices_external_hidden on public.offices as restrictive for select to authenticated
  using (public.has_permission(workspace_id, 'manageSites') or public.room_visible(id));

-- Historical capacity has its own workspace-qualified snapshots. Apply the
-- live place rule when the floor still exists; a historical-only floor is
-- authorised by the capacity reader's existing rights and history lookup.
CREATE OR REPLACE FUNCTION public.kpi_seat_capacity(p_workspace_id uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_level_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tz text; v_since timestamptz; v_covered tstzmultirange; v_open tstzmultirange;
  v_seats int; v_physical numeric; v_offered numeric; v_reserved numeric;
  v_outside numeric; v_overlap numeric; v_unattributed int;
  v_rooms int; v_room_offered numeric; v_room_reserved numeric;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > make_interval(days => (public.setting_value(null, 'kpi.capacity_range_days') #>> '{}')::int) then
    raise exception 'the KPI period must be [from, to) with from < to, at most % days', (public.setting_value(null, 'kpi.capacity_range_days') #>> '{}')::int
      using errcode = '22023';
  end if;
  if not public.kpi_readable(p_workspace_id, 'capacity.seat_utilisation') then
    raise exception 'not allowed to read the capacity figures of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'capacityKpi') then
    raise exception 'the capacity KPI is not enabled for this workspace'
      using errcode = '42501';
  end if;
  if p_level_id is not null and ((not exists (
       select 1 from public.levels l
        where l.id = p_level_id and l.workspace_id = p_workspace_id)
     and not exists (
       select 1 from public.seat_history h
        where h.level_id = p_level_id and h.workspace_id = p_workspace_id))
     -- #4144 -- a level the caller may not see is an unknown level
     or (exists (select 1 from public.levels l
                    where l.id = p_level_id and l.workspace_id = p_workspace_id)
         and not public.level_visible(p_level_id))) then
    raise exception 'unknown level for this workspace' using errcode = '22023';
  end if;
  select w.timezone into v_tz from public.workspaces w where w.id = p_workspace_id;
  select a.since into v_since from public.analytics_history a
   where a.workspace_id = p_workspace_id;
  v_since := coalesce(v_since, now());
  v_covered := case when greatest(p_from, v_since) < p_to
                    then tstzmultirange(tstzrange(greatest(p_from, v_since), p_to, '[)'))
                    else '{}'::tstzmultirange end;
  select coalesce(range_agg(tstzrange(
           (g.d + make_interval(mins => h.work_start_minutes)) at time zone v_tz,
           (g.d + make_interval(mins => h.work_end_minutes)) at time zone v_tz, '[)')
           * h.valid), '{}'::tstzmultirange) * v_covered
    into v_open
    from generate_series((p_from at time zone v_tz)::date::timestamp,
                         (p_to at time zone v_tz)::date::timestamp,
                         interval '1 day') g(d)
    join public.opening_hours_history h
      on h.workspace_id = p_workspace_id
     and h.valid && tstzrange(p_from, p_to, '[)')
   where h.work_end_minutes > h.work_start_minutes
     and extract(isodow from g.d)::int = any (h.open_weekdays)
     and not exists (select 1 from public.closure_days c
                      where c.workspace_id = p_workspace_id
                        and c.day = g.d::date);
  with scope as (
    select h.seat_id, h.desk_id, h.office_id, h.level_id,
           tstzmultirange(h.valid) * v_covered as held,
           case when h.blocked_from is null then '{}'::tstzmultirange
                else tstzmultirange(tstzrange(h.blocked_from, h.blocked_to, '[)'))
           end as blocked
      from public.seat_history h
     where h.workspace_id = p_workspace_id
       and h.valid && tstzrange(p_from, p_to, '[)')
       and (p_level_id is null or h.level_id = p_level_id)
  ), targets as (
    select r.starts_at, r.ends_at,
           case when t.reservation_id is null then r.seat_id else t.seat_id end as seat_id,
           case when t.reservation_id is null then r.desk_id else t.desk_id end as desk_id,
           case when t.reservation_id is null then r.office_id else t.office_id end as office_id,
           case when t.reservation_id is null then r.level_id else t.level_id end as level_id
      from public.reservations r
      left join lateral (
        select x.reservation_id, x.seat_id, x.desk_id, x.office_id, x.level_id
          from public.reservation_target_history x
         where x.reservation_id = r.id
         order by x.recorded_at desc, x.id desc limit 1) t on true
     where r.workspace_id = p_workspace_id
       and r.status in ('reserved', 'checked_in', 'completed')
       and r.starts_at < p_to and r.ends_at > p_from
  ), bound as (
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held as rng
      from targets tg
      join scope sc on tg.seat_id = sc.seat_id
    union all
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held
      from targets tg
      join scope sc on tg.desk_id = sc.desk_id
     where not coalesce(tg.seat_id = sc.seat_id, false)
    union all
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held
      from targets tg
      join scope sc on tg.office_id = sc.office_id
     where not coalesce(tg.seat_id = sc.seat_id, false)
       and not coalesce(tg.desk_id = sc.desk_id, false)
    union all
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held
      from targets tg
      join scope sc on tg.level_id = sc.level_id
     where not coalesce(tg.seat_id = sc.seat_id, false)
       and not coalesce(tg.desk_id = sc.desk_id, false)
       and not coalesce(tg.office_id = sc.office_id, false)
  ), per_seat as (
    select sc.seat_id,
           range_agg(v_open * sc.held) as open_time,
           range_agg((v_open * sc.held) - sc.blocked) as offered
      from scope sc
     group by sc.seat_id
  ), bound_seat as (
    select b.seat_id, range_agg(b.rng) as reserved,
           sum(public.kpi_multirange_hours(b.rng)) as raw_hours
      from bound b
     group by b.seat_id
  ), measured as (
    select p.seat_id, p.open_time, p.offered,
           coalesce(bs.reserved, '{}'::tstzmultirange) as reserved,
           coalesce(bs.raw_hours, 0) as raw_hours
      from per_seat p
      left join bound_seat bs on bs.seat_id = p.seat_id
  )
  select count(*)::int,
         coalesce(sum(public.kpi_multirange_hours(m.open_time)), 0),
         coalesce(sum(public.kpi_multirange_hours(m.offered)), 0),
         coalesce(sum(public.kpi_multirange_hours(m.reserved * m.offered)), 0),
         coalesce(sum(public.kpi_multirange_hours(m.reserved - m.offered)), 0),
         coalesce(sum(m.raw_hours - public.kpi_multirange_hours(m.reserved)), 0)
    into v_seats, v_physical, v_offered, v_reserved, v_outside, v_overlap
    from measured m;
  with rooms as (
    select o.id, o.level_id
      from public.offices o
     where o.workspace_id = p_workspace_id
       and (p_level_id is null or o.level_id = p_level_id)
       and not exists (select 1 from public.desks d
                         join public.seats s on s.desk_id = d.id
                        where d.office_id = o.id)
  )
  select count(*)::int,
         count(*) * public.kpi_multirange_hours(v_open),
         coalesce(sum(public.kpi_multirange_hours(
           coalesce((select range_agg(tstzrange(r.starts_at, r.ends_at, '[)'))
                       from public.reservations r
                      where r.workspace_id = p_workspace_id
                        and (r.office_id = rm.id or r.level_id = rm.level_id)
                        and r.status in ('reserved', 'checked_in', 'completed')),
                    '{}'::tstzmultirange) * v_open)), 0)
    into v_rooms, v_room_offered, v_room_reserved
    from rooms rm;
  select count(*)::int into v_unattributed
    from public.reservations r
   where r.workspace_id = p_workspace_id and p_level_id is null
     and r.status in ('reserved', 'checked_in', 'completed')
     and r.starts_at < p_to and r.ends_at > p_from
     and num_nonnulls(r.seat_id, r.desk_id, r.office_id, r.level_id) = 0
     and not exists (select 1 from public.reservation_target_history x
                      where x.reservation_id = r.id);
  if v_covered = '{}'::tstzmultirange then
    v_quality := v_quality || 'not_recorded'::text;
    v_reasons := v_reasons || 'history_not_recorded_before'::text;
  elsif v_offered = 0 then
    v_quality := v_quality || 'not_applicable'::text;
    v_reasons := v_reasons || 'no_offered_capacity'::text;
  elsif v_reserved = 0 then
    v_quality := v_quality || 'known_zero'::text;
  end if;
  if p_from < v_since and v_covered <> '{}'::tstzmultirange then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'history_not_recorded_before'::text;
  end if;
  if v_unattributed > 0 then
    if not ('partial' = any (v_quality)) then
      v_quality := v_quality || 'partial'::text;
    end if;
    v_reasons := v_reasons || 'unattributed_reservations'::text;
  end if;
  if v_outside > 0 then
    v_reasons := v_reasons || 'reserved_outside_offered_hours'::text;
  end if;
  if v_overlap > 0 then
    v_reasons := v_reasons || 'overlapping_reservations'::text;
  end if;
  if v_rooms > 0 and p_from < now() then
    v_reasons := v_reasons || 'rooms_current_structure'::text;
  end if;
  return jsonb_build_object(
    'kpi', 'capacity.seat_utilisation', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz, 'level_id', p_level_id,
    'history_since', v_since,
    'seats', v_seats,
    'physical_seat_hours', round(v_physical, 2),
    'offered_seat_hours', round(v_offered, 2),
    'reserved_seat_hours', round(v_reserved, 2),
    'reserved_outside_offered_seat_hours', round(v_outside, 2),
    'overlapping_seat_hours', round(v_overlap, 2),
    'rooms_without_seats', v_rooms,
    'offered_room_hours', round(v_room_offered, 2),
    'reserved_room_hours', round(v_room_reserved, 2),
    'unattributed_reservations', v_unattributed,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now())
    || public.kpi_resource_counts(p_workspace_id, p_from, p_to, p_level_id);
end
$function$;
revoke execute on function public.kpi_seat_capacity(uuid,timestamptz,timestamptz,uuid) from public, anon;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(809);
