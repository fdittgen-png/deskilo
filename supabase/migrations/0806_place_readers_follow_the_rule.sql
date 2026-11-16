-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (calendar_items, kpi_seat_capacity and my_favorites are patched at
--  asserted anchors of their live definitions)
--
-- #4144 -- the server functions that read reservations and places follow
-- their reading rules: a place in an external level or a rented room is
-- shown to those who manage the sites or to the rental's audience, and its
-- bookings to their own member or to whoever sees the place
-- (room_visible, level_visible, desk_room_visible,
-- reservation_place_visible: the tables' own restrictive rules).
--   * the calendar shows a member's bookings as the bookings table shows
--     them to the caller;
--   * the capacity figures of a level the caller may not see are answered
--     as those of an unknown level, in content and in the error;
--   * a member's favourites show the places they may see.

-- ── the calendar's bookings ──────────────────────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure);
  v_old constant text := $a$where r.workspace_id = p_workspace_id and r.member_id = v_subject$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 4 then
    raise exception 'calendar_items: the anchor of its bookings is not there four times' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, v_old || $a$
         and (not public.workspace_has_external_level(r.workspace_id)
              or public.reservation_place_visible(r.workspace_id, r.member_id, r.seat_id,
                                                  r.desk_id, r.office_id, r.level_id))$a$);
end;
$patch$;

-- ── the capacity of a level ──────────────────────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.kpi_seat_capacity(uuid, timestamptz, timestamptz, uuid)'::regprocedure);
  v_old constant text := $a$  if p_level_id is not null and not exists (
       select 1 from public.levels l
        where l.id = p_level_id and l.workspace_id = p_workspace_id)
     and not exists (
       select 1 from public.seat_history h
        where h.level_id = p_level_id and h.workspace_id = p_workspace_id) then$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'kpi_seat_capacity: the anchor of its level is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$  if p_level_id is not null and ((not exists (
       select 1 from public.levels l
        where l.id = p_level_id and l.workspace_id = p_workspace_id)
     and not exists (
       select 1 from public.seat_history h
        where h.level_id = p_level_id and h.workspace_id = p_workspace_id))
     -- #4144 -- a level the caller may not see is an unknown level
     or not public.level_visible(p_level_id)) then$a$);
end;
$patch$;

-- ── a member's favourites ────────────────────────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.my_favorites(uuid)'::regprocedure);
  v_old constant text := $a$              when 'seat' then exists (select 1 from public.seats x where x.id = f.resource_id)
              when 'desk' then exists (select 1 from public.desks x where x.id = f.resource_id)
              when 'office' then exists (select 1 from public.offices x where x.id = f.resource_id)
              else exists (select 1 from public.levels x where x.id = f.resource_id) end)$a$;
begin
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'my_favorites: the anchor of its places is not there exactly once' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, $a$              when 'seat' then exists (select 1 from public.seats x where x.id = f.resource_id
                                         and public.desk_room_visible(x.desk_id))
              when 'desk' then exists (select 1 from public.desks x where x.id = f.resource_id
                                         and public.room_visible(x.office_id))
              when 'office' then exists (select 1 from public.offices x where x.id = f.resource_id
                                           and public.room_visible(x.id))
              else exists (select 1 from public.levels x where x.id = f.resource_id
                             and (x.kind = 'own' or public.level_visible(x.id))) end)$a$);
end;
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(806);
