-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0501 (#2568) -- the bookings of a room a member may not book are not theirs
-- to read.
--
-- 0496 hid a rented room, its desks and seats from everyone outside its
-- audience; the reservations made on it still named it by id. A restrictive
-- select policy now hides a reservation whose place is hidden from the reader,
-- except the reader's own bookings (a person always sees what they booked,
-- even after the audience changed). Workspaces without an external level or a
-- rental pay one indexed lookup per row; nothing else changes.

create or replace function public.reservation_place_visible(
  p_workspace uuid, p_member uuid, p_seat uuid, p_desk uuid, p_office uuid, p_level uuid
) returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_desk uuid;
  v_office uuid;
  v_level uuid;
begin
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace and m.user_id = auth.uid() and m.status = 'active';
  if v_me is not null and v_me = p_member then return true; end if;
  v_desk := coalesce(p_desk, (select s.desk_id from public.seats s where s.id = p_seat));
  v_office := coalesce(p_office, (select d.office_id from public.desks d where d.id = v_desk));
  v_level := coalesce(p_level, (select o.level_id from public.offices o where o.id = v_office));
  if v_me is null then return false; end if;
  return public.place_visible_to(v_me, v_office, case when v_office is null then v_level end);
end;
$fn$;
revoke execute on function public.reservation_place_visible(uuid, uuid, uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.reservation_place_visible(uuid, uuid, uuid, uuid, uuid, uuid) to authenticated;

-- Read past the policies that hide a rented floor: the reader cannot see the
-- external level, and "no external level I can see" must not read as "none".
create or replace function public.workspace_has_external_level(p_workspace uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.is_member_of(p_workspace)
     and exists (select 1 from public.levels l where l.workspace_id = p_workspace and l.kind = 'external');
$fn$;
revoke execute on function public.workspace_has_external_level(uuid) from public, anon;
grant execute on function public.workspace_has_external_level(uuid) to authenticated;

create policy reservations_hidden_rooms on public.reservations as restrictive for select to authenticated
  using (
    not public.workspace_has_external_level(workspace_id)
    or public.reservation_place_visible(workspace_id, member_id, seat_id, desk_id, office_id, level_id)
  );

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(501);
