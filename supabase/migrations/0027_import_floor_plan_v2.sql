-- SPDX-License-Identifier: 0BSD
-- DesKilo workspace XML import, schema v2 (#180). NOT YET applied to the
-- hosted reference project — the orchestrator applies it after review.
--
-- import_floor_plan_v2 is 0023's import_floor_plan plus the accessory
-- catalog (#166/#168): p_accessories carries the whole exported catalog
-- (inactive entries included) and each seat's plan node may carry an
-- `accessories` array of catalog NAMES. The catalog is UPSERTED by
-- (workspace_id, name) — existing rows get the file's supplement/active/
-- sort_order, missing ones are created, rows absent from the file are
-- left untouched (no deletion: reservation accessory supplements, 0024,
-- may reference them). seat_accessories join rows are then inserted by
-- resolving names → the workspace's accessory ids; an unknown name in a
-- seat ref raises 'malformed plan: unknown accessory'.
--
-- 0023's 2-arg import_floor_plan(uuid, jsonb) stays in place untouched
-- for v1 clients; this is a separate function.
--
-- Safety (unchanged from 0023): owner-only, and a workspace with ANY
-- reservation row refuses the import. reservations.seat_id / office_id
-- are ON DELETE RESTRICT (0005) because billing counts reservations —
-- even cancelled/completed rows must keep their seat. Rather than
-- surface a raw FK error, we raise the typed 'workspace has reservations'
-- the client maps to a clear message.

create or replace function public.import_floor_plan_v2(
  p_workspace_id uuid,
  p_plan jsonb,
  p_accessories jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_accessory jsonb;
  v_level jsonb;
  v_office jsonb;
  v_desk jsonb;
  v_seat jsonb;
  v_amenity jsonb;
  v_accessory_name jsonb;
  v_level_id uuid;
  v_office_id uuid;
  v_desk_id uuid;
  v_seat_id uuid;
  v_accessory_id uuid;
  v_amenities text[];
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner may import a floor plan';
  end if;

  -- Imports only into reservation-free workspaces: reservations reference
  -- seats/offices (0005, on delete RESTRICT) and billing counts them, so
  -- history must never be destroyed. ANY status counts — cancelled and
  -- completed rows still reference their seat.
  if exists (
    select 1 from public.reservations r where r.workspace_id = p_workspace_id
  ) then
    raise exception 'workspace has reservations';
  end if;

  if p_plan is null or jsonb_typeof(p_plan) <> 'array' then
    raise exception 'malformed plan: expected an array of levels';
  end if;
  if jsonb_typeof(coalesce(p_accessories, '[]'::jsonb)) <> 'array' then
    raise exception 'malformed plan: expected an array of accessories';
  end if;

  -- Catalog upsert BEFORE the plan so seat references resolve. Upsert by
  -- the 0022 (workspace_id, name) unique key: no deletion, a backup
  -- restore must never orphan rows the file does not know about.
  for v_accessory in
    select value from jsonb_array_elements(coalesce(p_accessories, '[]'::jsonb))
  loop
    if jsonb_typeof(v_accessory) <> 'object'
       or jsonb_typeof(v_accessory->'name') <> 'string'
       or jsonb_typeof(v_accessory->'supplement_cents') <> 'number'
       or jsonb_typeof(v_accessory->'active') <> 'boolean'
       or jsonb_typeof(v_accessory->'sort_order') <> 'number' then
      raise exception 'malformed plan: bad accessory';
    end if;
    -- Name length and supplement_cents >= 0 re-validate via the 0022
    -- column checks on insert/update.
    insert into public.accessories
      (workspace_id, name, supplement_cents, active, sort_order)
    values (
      p_workspace_id,
      v_accessory->>'name',
      (v_accessory->>'supplement_cents')::int,
      (v_accessory->>'active')::boolean,
      (v_accessory->>'sort_order')::int
    )
    on conflict (workspace_id, name) do update
      set supplement_cents = excluded.supplement_cents,
          active = excluded.active,
          sort_order = excluded.sort_order;
  end loop;

  -- Transactional replace. Deleting levels cascades through the FK chain
  -- verified in 0003/0022:
  --   offices.level_id  → levels.id   on delete cascade (0003)
  --   desks.office_id   → offices.id  on delete cascade (0003)
  --   seats.desk_id     → desks.id    on delete cascade (0003)
  --   seat_accessories.seat_id → seats.id on delete cascade (0022)
  -- The accessories catalog rows themselves only reference the workspace
  -- and survive; the loop above already merged the file's entries in.
  delete from public.levels where workspace_id = p_workspace_id;

  for v_level in select value from jsonb_array_elements(p_plan) loop
    if jsonb_typeof(v_level) <> 'object'
       or jsonb_typeof(v_level->'name') <> 'string'
       or jsonb_typeof(v_level->'sort_order') <> 'number'
       or jsonb_typeof(coalesce(v_level->'offices', '[]'::jsonb)) <> 'array' then
      raise exception 'malformed plan: bad level';
    end if;
    insert into public.levels (workspace_id, name, sort_order)
      values (p_workspace_id, v_level->>'name', (v_level->>'sort_order')::int)
      returning id into v_level_id;

    for v_office in
      select value from jsonb_array_elements(coalesce(v_level->'offices', '[]'::jsonb))
    loop
      if jsonb_typeof(v_office) <> 'object'
         or jsonb_typeof(v_office->'name') <> 'string'
         or jsonb_typeof(v_office->'color') <> 'number'
         or jsonb_typeof(v_office->'bookable_as_whole') <> 'boolean'
         or jsonb_typeof(v_office->'x') <> 'number'
         or jsonb_typeof(v_office->'y') <> 'number'
         or jsonb_typeof(v_office->'w') <> 'number'
         or jsonb_typeof(v_office->'h') <> 'number'
         or jsonb_typeof(coalesce(v_office->'desks', '[]'::jsonb)) <> 'array' then
        raise exception 'malformed plan: bad office';
      end if;
      -- Geometry ranges (x/y >= 0, w/h > 0) and name lengths re-validate
      -- via the 0003 column checks on insert.
      insert into public.offices
        (workspace_id, level_id, name, color, bookable_as_whole, x, y, w, h)
      values (
        p_workspace_id, v_level_id,
        v_office->>'name',
        (v_office->>'color')::int,
        (v_office->>'bookable_as_whole')::boolean,
        (v_office->>'x')::int, (v_office->>'y')::int,
        (v_office->>'w')::int, (v_office->>'h')::int
      )
      returning id into v_office_id;

      for v_desk in
        select value from jsonb_array_elements(coalesce(v_office->'desks', '[]'::jsonb))
      loop
        if jsonb_typeof(v_desk) <> 'object'
           or jsonb_typeof(v_desk->'name') <> 'string'
           or jsonb_typeof(v_desk->'x') <> 'number'
           or jsonb_typeof(v_desk->'y') <> 'number'
           or jsonb_typeof(v_desk->'w') <> 'number'
           or jsonb_typeof(v_desk->'h') <> 'number'
           or jsonb_typeof(coalesce(v_desk->'seats', '[]'::jsonb)) <> 'array' then
          raise exception 'malformed plan: bad desk';
        end if;
        insert into public.desks (workspace_id, office_id, name, x, y, w, h)
        values (
          p_workspace_id, v_office_id,
          v_desk->>'name',
          (v_desk->>'x')::int, (v_desk->>'y')::int,
          (v_desk->>'w')::int, (v_desk->>'h')::int
        )
        returning id into v_desk_id;

        for v_seat in
          select value from jsonb_array_elements(coalesce(v_desk->'seats', '[]'::jsonb))
        loop
          if jsonb_typeof(v_seat) <> 'object'
             or jsonb_typeof(v_seat->'name') <> 'string'
             or jsonb_typeof(v_seat->'x') <> 'number'
             or jsonb_typeof(v_seat->'y') <> 'number'
             or jsonb_typeof(v_seat->'orientation') <> 'string'
             or jsonb_typeof(coalesce(v_seat->'chair', '""'::jsonb)) <> 'string'
             or jsonb_typeof(coalesce(v_seat->'amenities', '[]'::jsonb)) <> 'array'
             or jsonb_typeof(coalesce(v_seat->'accessories', '[]'::jsonb)) <> 'array'
             or jsonb_typeof(coalesce(v_seat->'blocked_from', 'null'::jsonb))
                not in ('string', 'null')
             or jsonb_typeof(coalesce(v_seat->'blocked_to', 'null'::jsonb))
                not in ('string', 'null') then
            raise exception 'malformed plan: bad seat';
          end if;
          v_amenities := '{}';
          for v_amenity in
            select value from jsonb_array_elements(coalesce(v_seat->'amenities', '[]'::jsonb))
          loop
            if jsonb_typeof(v_amenity) <> 'string' then
              raise exception 'malformed plan: bad amenity';
            end if;
            v_amenities := v_amenities || (v_amenity #>> '{}');
          end loop;
          -- orientation re-validates via the 0003 check (n|e|s|w).
          insert into public.seats
            (workspace_id, desk_id, name, x, y, orientation, chair,
             amenities, blocked_from, blocked_to)
          values (
            p_workspace_id, v_desk_id,
            v_seat->>'name',
            (v_seat->>'x')::int, (v_seat->>'y')::int,
            v_seat->>'orientation',
            coalesce(v_seat->>'chair', ''),
            v_amenities,
            (v_seat->>'blocked_from')::timestamptz,
            (v_seat->>'blocked_to')::timestamptz
          )
          returning id into v_seat_id;

          -- v2: seat → accessory joins, resolving catalog names to the
          -- (possibly just upserted) workspace accessory ids. The 0022
          -- same-workspace trigger re-derives workspace_id from the seat.
          for v_accessory_name in
            select value from jsonb_array_elements(coalesce(v_seat->'accessories', '[]'::jsonb))
          loop
            if jsonb_typeof(v_accessory_name) <> 'string' then
              raise exception 'malformed plan: bad seat accessory';
            end if;
            select a.id into v_accessory_id
              from public.accessories a
              where a.workspace_id = p_workspace_id
                and a.name = (v_accessory_name #>> '{}');
            if v_accessory_id is null then
              raise exception 'malformed plan: unknown accessory';
            end if;
            insert into public.seat_accessories (workspace_id, seat_id, accessory_id)
              values (p_workspace_id, v_seat_id, v_accessory_id)
              on conflict (seat_id, accessory_id) do nothing;
          end loop;
        end loop;
      end loop;
    end loop;
  end loop;
end;
$$;

grant execute on function public.import_floor_plan_v2(uuid, jsonb, jsonb) to authenticated;
revoke execute on function public.import_floor_plan_v2(uuid, jsonb, jsonb) from public, anon;
