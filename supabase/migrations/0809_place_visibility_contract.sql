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
  if v_me is not null and v_me = p_member then return true; end if;
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

do $patch$
declare
  v_def text := pg_get_functiondef('public.mcp_read_v1(uuid, members, text, jsonb)'::regprocedure);
  v_old constant text := $a$where e.workspace_id = p_workspace_id and e.status = 'pending'$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 2 then
    raise exception 'mcp_read_v1: expected anchor count 2' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$where e.workspace_id = p_workspace_id and e.status = 'pending'
           and public.booking_event_visible(e.workspace_id, e.reservation_id)$a$);
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.mcp_read_v1(uuid, members, text, jsonb)'::regprocedure);
  v_old constant text := $a$if v_event.id is null
$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'mcp_read_v1: expected anchor count 1' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$if v_event.id is null
       or not public.booking_event_visible(v_event.workspace_id, v_event.reservation_id)
$a$);
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure);
  v_old constant text := $a$if v_event.id is null
$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'mcp_target: expected anchor count 1' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$if v_event.id is null
       or not public.booking_event_visible(v_event.workspace_id, v_event.reservation_id)
$a$);
end;
$patch$;

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
    raise exception 'only the owner, or an admin with the adminSeatBlocking feature, may block seats';
  end if;
  select s.workspace_id into v_workspace_id from public.seats s
   where s.id = p_seat_id and s.workspace_id = any(v_workspaces)
     and public.desk_room_visible(s.desk_id);
  if v_workspace_id is null then raise exception 'unknown seat'; end if;
  if p_blocked_from is not null and p_blocked_to is not null and p_blocked_to <= p_blocked_from then
    raise exception 'blocked_to must be after blocked_from';
  end if;
  update public.seats set blocked_from = p_blocked_from, blocked_to = p_blocked_to
   where id = p_seat_id and workspace_id = v_workspace_id;
end;
$fn$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(809);
