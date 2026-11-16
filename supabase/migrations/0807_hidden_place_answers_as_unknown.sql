-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (create_reservation, create_series, admin_create_reservation_for and
--  kiosk_act are patched at asserted anchors of their live definitions;
--  booking_place_hidden is new)
--
-- #4148 -- a booking needs its place to be visible to the member it is
-- booked for (GHSA-f33x-v5jc-fvp4). A place the member may not see -- a room
-- of an external level or a rented room outside its audience
-- (place_visible_to) -- is answered exactly as a place that does not exist,
-- whether it is free or taken: the same message and code, for a seat, a
-- desk, an office or a level, before any other check of that place -- its own
-- booking slot included. A series tells nothing about such a place's days.

-- Whether [the place] exists but is hidden for a booking for member
-- [p_member]: it is a room of an external level or a rented room, the member
-- is outside the rental's audience, and the CALLER does not hold the sites
-- right (place_visible_to takes the audience from the member and the sites
-- right from the caller: in admin_create_reservation_for and at the kiosk,
-- the caller's right counts). An unknown place is not hidden: its own lookup
-- answers.
create or replace function public.booking_place_hidden(
  p_member uuid, p_seat uuid, p_desk uuid, p_office uuid, p_level uuid)
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_desk uuid;
  v_office uuid;
  v_level uuid;
begin
  v_desk := coalesce(p_desk, (select s.desk_id from public.seats s where s.id = p_seat));
  v_office := coalesce(p_office, (select d.office_id from public.desks d where d.id = v_desk));
  v_level := coalesce(p_level, (select o.level_id from public.offices o where o.id = v_office));
  if v_office is null and v_level is null then return false; end if;
  return not public.place_visible_to(p_member, v_office, case when v_office is null then v_level end);
end;
$fn$;
revoke execute on function public.booking_place_hidden(uuid, uuid, uuid, uuid, uuid) from public, anon, authenticated;

do $patch$
declare
  v_def text := pg_get_functiondef('public.create_reservation(uuid, uuid, uuid, timestamptz, timestamptz, boolean, uuid, uuid)'::regprocedure);
begin
  if (length(v_def) - length(replace(v_def, $a$        select * into v_seat from public.seats
          where id = p_seat_id and workspace_id = p_workspace_id;$a$, ''))) / length($a$        select * into v_seat from public.seats
          where id = p_seat_id and workspace_id = p_workspace_id;$a$) <> 1 then
    raise exception 'create_reservation: anchor 1 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$        select * into v_seat from public.seats
          where id = p_seat_id and workspace_id = p_workspace_id;$a$, $a$        select * into v_seat from public.seats
          where id = p_seat_id and workspace_id = p_workspace_id;
        -- #4148 -- a place the member may not see is an unknown place
        if v_seat.id is not null and public.booking_place_hidden(v_member.id, v_seat.id, null, null, null) then
          v_seat := null;
        end if;$a$);
  if (length(v_def) - length(replace(v_def, $a$          where d.id = p_desk_id and d.workspace_id = p_workspace_id
            and d.bookable_as_whole$a$, ''))) / length($a$          where d.id = p_desk_id and d.workspace_id = p_workspace_id
            and d.bookable_as_whole$a$) <> 1 then
    raise exception 'create_reservation: anchor 2 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$          where d.id = p_desk_id and d.workspace_id = p_workspace_id
            and d.bookable_as_whole$a$, $a$          where d.id = p_desk_id and d.workspace_id = p_workspace_id
            and d.bookable_as_whole
            and not public.booking_place_hidden(v_member.id, null, d.id, null, null)$a$);
  if (length(v_def) - length(replace(v_def, $a$          where o.id = p_office_id and o.workspace_id = p_workspace_id
            and o.bookable_as_whole$a$, ''))) / length($a$          where o.id = p_office_id and o.workspace_id = p_workspace_id
            and o.bookable_as_whole$a$) <> 1 then
    raise exception 'create_reservation: anchor 3 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$          where o.id = p_office_id and o.workspace_id = p_workspace_id
            and o.bookable_as_whole$a$, $a$          where o.id = p_office_id and o.workspace_id = p_workspace_id
            and o.bookable_as_whole
            and not public.booking_place_hidden(v_member.id, null, null, o.id, null)$a$);
  if (length(v_def) - length(replace(v_def, $a$          where l.id = p_level_id and l.workspace_id = p_workspace_id
            and l.bookable_as_whole$a$, ''))) / length($a$          where l.id = p_level_id and l.workspace_id = p_workspace_id
            and l.bookable_as_whole$a$) <> 1 then
    raise exception 'create_reservation: anchor 4 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$          where l.id = p_level_id and l.workspace_id = p_workspace_id
            and l.bookable_as_whole$a$, $a$          where l.id = p_level_id and l.workspace_id = p_workspace_id
            and l.bookable_as_whole
            and not public.booking_place_hidden(v_member.id, null, null, null, l.id)$a$);
  if (length(v_def) - length(replace(v_def, $a$      perform public.enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in, p_seat_id);$a$, ''))) / length($a$      perform public.enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in, p_seat_id);$a$) <> 1 then
    raise exception 'create_reservation: the anchor of its booking rules is not there exactly once' using errcode = 'P0001';
  end if;
  -- a hidden seat's own booking slot is not read: the business's rules apply, as for an unknown seat
  v_def := replace(v_def, $a$      perform public.enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in, p_seat_id);$a$, $a$      perform public.enforce_booking_rules(p_workspace_id, v_starts, v_ends, p_check_in, 
        case when public.booking_place_hidden(v_member.id, p_seat_id, null, null, null) then null else p_seat_id end);$a$);
  execute v_def;
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.create_series(uuid, uuid, timestamptz, timestamptz, text, timestamptz, uuid, uuid, uuid)'::regprocedure);
begin
  if (length(v_def) - length(replace(v_def, $a$        where d.id = p_desk_id and d.workspace_id = p_workspace_id
          and d.bookable_as_whole$a$, ''))) / length($a$        where d.id = p_desk_id and d.workspace_id = p_workspace_id
          and d.bookable_as_whole$a$) <> 1 then
    raise exception 'create_series: anchor 1 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$        where d.id = p_desk_id and d.workspace_id = p_workspace_id
          and d.bookable_as_whole$a$, $a$        where d.id = p_desk_id and d.workspace_id = p_workspace_id
          and d.bookable_as_whole
          and not public.booking_place_hidden(v_member.id, null, d.id, null, null)$a$);
  if (length(v_def) - length(replace(v_def, $a$        where o.id = p_office_id and o.workspace_id = p_workspace_id
          and o.bookable_as_whole$a$, ''))) / length($a$        where o.id = p_office_id and o.workspace_id = p_workspace_id
          and o.bookable_as_whole$a$) <> 1 then
    raise exception 'create_series: anchor 2 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$        where o.id = p_office_id and o.workspace_id = p_workspace_id
          and o.bookable_as_whole$a$, $a$        where o.id = p_office_id and o.workspace_id = p_workspace_id
          and o.bookable_as_whole
          and not public.booking_place_hidden(v_member.id, null, null, o.id, null)$a$);
  if (length(v_def) - length(replace(v_def, $a$        where l.id = p_level_id and l.workspace_id = p_workspace_id
          and l.bookable_as_whole$a$, ''))) / length($a$        where l.id = p_level_id and l.workspace_id = p_workspace_id
          and l.bookable_as_whole$a$) <> 1 then
    raise exception 'create_series: anchor 3 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$        where l.id = p_level_id and l.workspace_id = p_workspace_id
          and l.bookable_as_whole$a$, $a$        where l.id = p_level_id and l.workspace_id = p_workspace_id
          and l.bookable_as_whole
          and not public.booking_place_hidden(v_member.id, null, null, null, l.id)$a$);
  if (length(v_def) - length(replace(v_def, $a$  perform public.enforce_booking_rules(p_workspace_id, p_first_start, p_first_end, false, p_seat_id);$a$, ''))) / length($a$  perform public.enforce_booking_rules(p_workspace_id, p_first_start, p_first_end, false, p_seat_id);$a$) <> 1 then
    raise exception 'create_series: the anchor of its booking rules is not there exactly once' using errcode = 'P0001';
  end if;
  -- a hidden seat's own booking slot is not read: the business's rules apply, as for an unknown seat
  v_def := replace(v_def, $a$  perform public.enforce_booking_rules(p_workspace_id, p_first_start, p_first_end, false, p_seat_id);$a$, $a$  perform public.enforce_booking_rules(p_workspace_id, p_first_start, p_first_end, false, 
        case when public.booking_place_hidden(v_member.id, p_seat_id, null, null, null) then null else p_seat_id end);$a$);
  execute v_def;
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.admin_create_reservation_for(uuid, uuid, uuid, timestamptz, timestamptz, uuid)'::regprocedure);
begin
  if (length(v_def) - length(replace(v_def, $a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole$a$, ''))) / length($a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole$a$) <> 1 then
    raise exception 'admin_create_reservation_for: anchor 1 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole$a$, $a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole
        and not public.booking_place_hidden(p_subject_member_id, null, null, null, l.id)$a$);
  if (length(v_def) - length(replace(v_def, $a$    perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);$a$, ''))) / length($a$    perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);$a$) <> 1 then
    raise exception 'admin_create_reservation_for: anchor 2 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$    perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);$a$, $a$    -- #4148 -- a seat the member may not see is an unknown seat
    if public.booking_place_hidden(p_subject_member_id, p_seat_id, null, null, null) then
      raise exception 'unknown seat' using errcode = 'P0001';
    end if;
    perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);$a$);
  if (length(v_def) - length(replace(v_def, $a$  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, false, p_seat_id);$a$, ''))) / length($a$  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, false, p_seat_id);$a$) <> 1 then
    raise exception 'admin_create_reservation_for: the anchor of its booking rules is not there exactly once' using errcode = 'P0001';
  end if;
  -- a hidden seat's own booking slot is not read: the business's rules apply, as for an unknown seat
  v_def := replace(v_def, $a$  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, false, p_seat_id);$a$, $a$  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, false, 
        case when public.booking_place_hidden(p_subject_member_id, p_seat_id, null, null, null) then null else p_seat_id end);$a$);
  execute v_def;
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.kiosk_act(uuid, text, text, uuid, timestamptz, timestamptz, uuid)'::regprocedure);
begin
  if (length(v_def) - length(replace(v_def, $a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole$a$, ''))) / length($a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole$a$) <> 1 then
    raise exception 'kiosk_act: anchor 1 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole$a$, $a$      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole
        and not public.booking_place_hidden(v_subject.id, null, null, null, l.id)$a$);
  if (length(v_def) - length(replace(v_def, $a$  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;$a$, ''))) / length($a$  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;$a$) <> 1 then
    raise exception 'kiosk_act: anchor 2 is not there exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;$a$, $a$  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;
  -- #4148 -- a place the member may not see is an unknown place
  if v_seat.id is not null and public.booking_place_hidden(v_subject.id, v_seat.id, null, null, null) then
    v_seat := null;
  end if;$a$);
  execute v_def;
end;
$patch$;
notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(807);
