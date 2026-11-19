-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (reservations gain removed_place_hidden; reservation_place_visible and
--  booking_event_visible restated whole; delete_plan_object, cancel_reservation,
--  calendar_items and respond_to_event patched at asserted anchors of their
--  live definitions; the bookings' and the levels' reading policies restated)
--
-- #4216 -- the place and booking visibility of 0809, with these rules:
--   1. A booking's own member always sees it, whatever place it names,
--      including a booking that names no place any more (its place was
--      removed from the plan and only its label is kept): its row, its
--      events, the member's own export and cancelling it. A paused member
--      too; a member who left the business does not.
--   2. A booking that names no place any more is read by its own member,
--      whoever holds the sites right, the owner and the administrators; by
--      everyone else of the business only when its place was not a hidden one
--      when it was removed. A booking removed before this record was kept is
--      read by everyone of the business only where the business has no
--      external level.
--   3. A business without an external level pays nothing for the booking
--      rule on events: it answers at once there, as the place readers do;
--      the events' policy reads the caller's businesses without an external
--      level once per query. Someone who does not belong to the business
--      sees none of its booking events.
--   4. Deciding a booking request needs the right to see the booking; a
--      request the caller may not see is answered as an unknown event.
--   5. Whoever holds the sites right adds an external level and reads back
--      the row they inserted, as for offices.

-- 2: whether the place a booking named was a hidden one when it was removed
-- (a room of an external level, or a rented room); null before this record.
alter table public.reservations add column if not exists removed_place_hidden boolean;
comment on column public.reservations.removed_place_hidden is
  'Whether the place this booking named was hidden (external level or rented room) when it was removed from the plan; null while it names a place, or when it was removed before this was recorded.';

do $patch$
declare
  v_def text := pg_get_functiondef('public.delete_plan_object(text, uuid)'::regprocedure);
  v_room constant text := $a$not (l.kind = 'own' and not exists (
             select 1 from public.room_rentals rr where rr.office_id = o.id))$a$;
  v_old text;
begin
  foreach v_old in array array['seat_id = null,', 'desk_id = null,', 'office_id = null,', 'level_id = null,'] loop
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception 'delete_plan_object: the anchor % is not there exactly once', v_old using errcode = 'P0001';
    end if;
    v_def := replace(v_def, v_old, v_old || $a$
         removed_place_hidden = $a$ || case when v_old = 'level_id = null,' then $a$l.kind <> 'own'$a$
                                             else v_room end || ',');
  end loop;
  execute v_def;
end;
$patch$;

-- 1, 2: the own-booking rule before the place rule. [p_removed_place_hidden]
-- is the booking's own record of 2 when it names no place.
create or replace function public.reservation_place_visible(
  p_workspace uuid, p_member uuid, p_seat uuid, p_desk uuid, p_office uuid, p_level uuid,
  p_removed_place_hidden boolean
) returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_caller public.members;
  v_desk uuid;
  v_office uuid;
  v_level uuid;
begin
  -- A booking names one place, or none (only its label is kept).
  if num_nonnulls(p_seat, p_desk, p_office, p_level) > 1 then return false; end if;
  -- A named place is a place of this business, or the answer is an unknown
  -- place's.
  if p_seat is not null and not exists (select 1 from public.seats s where s.id = p_seat and s.workspace_id = p_workspace)
     or p_desk is not null and not exists (select 1 from public.desks d where d.id = p_desk and d.workspace_id = p_workspace)
     or p_office is not null and not exists (select 1 from public.offices o where o.id = p_office and o.workspace_id = p_workspace)
     or p_level is not null and not exists (select 1 from public.levels l where l.id = p_level and l.workspace_id = p_workspace)
  then return false; end if;
  select m.* into v_caller from public.members m
   where m.workspace_id = p_workspace and m.user_id = auth.uid() and m.status in ('active', 'paused');
  if v_caller.id is null then return false; end if;
  -- 1: the member's own booking of exactly this place, or of no place.
  if v_caller.id = p_member and exists (
    select 1 from public.reservations r
     where r.workspace_id = p_workspace and r.member_id = v_caller.id
       and r.seat_id is not distinct from p_seat
       and r.desk_id is not distinct from p_desk
       and r.office_id is not distinct from p_office
       and r.level_id is not distinct from p_level
  ) then return true; end if;
  if v_caller.status <> 'active' then return false; end if;
  -- 2: a booking that names no place any more.
  if num_nonnulls(p_seat, p_desk, p_office, p_level) = 0 then
    return v_caller.is_owner or v_caller.is_admin
        or public.has_permission(p_workspace, 'manageSites')
        or p_removed_place_hidden is false
        or (p_removed_place_hidden is null and not exists (
              select 1 from public.levels l where l.workspace_id = p_workspace and l.kind = 'external'));
  end if;
  v_desk := coalesce(p_desk, (select s.desk_id from public.seats s where s.id = p_seat));
  v_office := coalesce(p_office, (select d.office_id from public.desks d where d.id = v_desk));
  v_level := coalesce(p_level, (select o.level_id from public.offices o where o.id = v_office));
  return public.place_visible_to(v_caller.id, v_office, case when v_office is null then v_level end);
end;
$fn$;
revoke execute on function public.reservation_place_visible(uuid, uuid, uuid, uuid, uuid, uuid, boolean) from public, anon;
grant execute on function public.reservation_place_visible(uuid, uuid, uuid, uuid, uuid, uuid, boolean) to authenticated;

-- The six-argument form, for a place without the booking's own record: it
-- only asks the guarded seven-argument one.
create or replace function public.reservation_place_visible(
  p_workspace uuid, p_member uuid, p_seat uuid, p_desk uuid, p_office uuid, p_level uuid
) returns boolean language sql stable security invoker set search_path = public as $fn$
  select public.reservation_place_visible(p_workspace, p_member, p_seat, p_desk, p_office, p_level, null);
$fn$;
revoke execute on function public.reservation_place_visible(uuid, uuid, uuid, uuid, uuid, uuid) from public, anon;

-- The bookings' reading policy reads the booking's own record of 2.
drop policy reservations_hidden_rooms on public.reservations;
create policy reservations_hidden_rooms on public.reservations as restrictive for select to authenticated
  using ((not public.workspace_has_external_level(workspace_id))
         or public.reservation_place_visible(workspace_id, member_id, seat_id, desk_id, office_id, level_id,
                                             removed_place_hidden));

-- 3: someone who does not belong to the business sees none of its booking
-- events; a business without an external level answers at once.
create or replace function public.booking_event_visible(p_workspace uuid, p_reservation uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_reservation is null
      or (exists (select 1 from public.members m
                   where m.workspace_id = p_workspace and m.user_id = auth.uid()
                     and m.status in ('active', 'paused'))
          and (not exists (select 1 from public.levels l
                            where l.workspace_id = p_workspace and l.kind = 'external')
               or exists (
            select 1 from public.reservations r
             where r.id = p_reservation and r.workspace_id = p_workspace
               and public.reservation_place_visible(r.workspace_id, r.member_id, r.seat_id,
                                                    r.desk_id, r.office_id, r.level_id,
                                                    r.removed_place_hidden))));
$fn$;
revoke execute on function public.booking_event_visible(uuid, uuid) from public, anon;

-- 3 (the events' policy): the caller's businesses without an external level,
-- read once per query as a hashed list rather than once per row.
create or replace function public.member_workspaces_without_external_level()
returns setof uuid language sql stable security definer set search_path = public as $fn$
  select m.workspace_id from public.members m
   where m.user_id = auth.uid() and m.status = 'active'
     and not exists (select 1 from public.levels l
                      where l.workspace_id = m.workspace_id and l.kind = 'external');
$fn$;
revoke execute on function public.member_workspaces_without_external_level() from public, anon;
grant execute on function public.member_workspaces_without_external_level() to authenticated;

drop policy events_booking_visibility on public.events;
create policy events_booking_visibility on public.events as restrictive for select to authenticated
  using (reservation_id is null
         or workspace_id in (select public.member_workspaces_without_external_level())
         or public.booking_event_visible(workspace_id, reservation_id));

-- 1, 2: cancelling and the calendar read the booking's own record of 2.
do $patch$
declare
  v_def text := pg_get_functiondef('public.cancel_reservation(uuid)'::regprocedure);
  v_old constant text := $a$v_res.desk_id, v_res.office_id, v_res.level_id) then$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'cancel_reservation: the anchor of its place rule is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$v_res.desk_id, v_res.office_id, v_res.level_id, v_res.removed_place_hidden) then$a$);
end;
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure);
  v_old constant text := $a$r.desk_id, r.office_id, r.level_id))$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 4 then
    raise exception 'calendar_items: the four anchors of its place rule are not there' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$r.desk_id, r.office_id, r.level_id, r.removed_place_hidden))$a$);
end;
$patch$;

-- 4: a booking request the caller may not see is an unknown event, before
-- anything else about it is said.
do $patch$
declare
  v_def text := pg_get_functiondef('public.respond_to_event(uuid, boolean)'::regprocedure);
  v_old constant text := $a$select e.* into v_event from public.events e where e.id = p_event_id for update;$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'respond_to_event: the anchor of its event read is not there exactly once'
      using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$select e.* into v_event from public.events e where e.id = p_event_id for update;
  -- #4216 -- a booking request the caller may not see is an unknown event.
  if v_event.id is not null
     and not public.booking_event_visible(v_event.workspace_id, v_event.reservation_id) then
    v_event := null;
  end if;$a$);
end;
$patch$;

-- 5: the sites right first, as for offices: a new row is not yet visible to
-- the rule's own lookup within the inserting statement.
drop policy levels_external_hidden on public.levels;
create policy levels_external_hidden on public.levels as restrictive for select to authenticated
  using (public.has_permission(workspace_id, 'manageSites') or kind = 'own' or public.level_visible(id));

select public.set_deskilo_schema_version(813);
