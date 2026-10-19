-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0497 (#2568) -- the rentals screen needs what to rent and where.
--
-- `room_rentals_v1` (0496) answers the rentals. The owner screen also needs
-- the levels with their kind (to mark one external) and the rooms of the
-- external levels, with whether each already has a rental, so a rental can be
-- started from a room. Same rights as before: plan managers and finance
-- readers; nothing here is shown to a member.

create or replace function public.room_rentals_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active') then
    raise exception 'not an active member';
  end if;
  if not public.feature_effective(p_workspace_id, 'externalRooms') then
    raise exception 'rented rooms are switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'manageSites') or public.has_permission(p_workspace_id, 'viewFinances')) then
    raise exception 'you may not read the rentals';
  end if;
  return jsonb_build_object(
    'rentals', coalesce((
      select jsonb_agg(public.room_rental_json(r) order by r.available_from, r.id)
        from public.room_rentals r where r.workspace_id = p_workspace_id), '[]'::jsonb),
    'levels', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'kind', l.kind) order by l.sort_order, l.name)
        from public.levels l where l.workspace_id = p_workspace_id), '[]'::jsonb),
    'rooms', coalesce((
      select jsonb_agg(jsonb_build_object('office_id', o.id, 'name', o.name, 'level_name', l.name,
                                          'rented', exists (select 1 from public.room_rentals r where r.office_id = o.id))
                       order by l.sort_order, l.name, o.name)
        from public.offices o join public.levels l on l.id = o.level_id
       where o.workspace_id = p_workspace_id and l.kind = 'external'), '[]'::jsonb));
end;
$fn$;

revoke execute on function public.room_rentals_v1(uuid) from public, anon;
grant execute on function public.room_rentals_v1(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(497);
