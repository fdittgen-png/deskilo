-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0471 (#2660, remaining scope of #2631) -- rooms and parking travel with the
-- plan, and only a seat uses the seat quota.
--
-- A. The floor plan deployment (0188) carries the resource graph:
--    * `export_floor_plan` adds an office's `area_kind` and, on every seat,
--      `resource_kind`, `capacity`, `parking_kind`, `slot_minutes` and its
--      charging `station` (name, connector, power, service state, the NAME of
--      its fee accessory).
--    * `merge_floor_plan` writes them back by the same identity as before
--      (level name, office and desk and seat by name or position). A present
--      key is a value, an absent key keeps what the target has, so an old
--      seat-only document keeps its defaults. The kind of an existing slot is
--      never changed (the seats guard says so too): a document that wants a
--      seat to become a room or a parking slot is refused, and so is an
--      unknown kind, a station on a slot that is not an EV slot, and a
--      station naming an accessory the target does not have. Nothing is
--      silently downgraded to a seat. A station is upserted on its slot, so a
--      repeated transfer adds no second charger. Foreign keys are resolved in
--      the target workspace by name; no source id is ever copied.
--
-- B. `reservation_uses_seat_quota(reservation)`: one condition, shared by the
--    member statement and the two quota checks. A room booked by the hour or a
--    parking slot booked by the day is recorded and billed on its own
--    (usage records, accessory supplements) but never consumes the half-days
--    of the seat allowance. Desk, office and level bookings carry no slot row
--    and count as before.

-- ── A. the plan tree ────────────────────────────────────────────────────
create or replace function public.export_floor_plan(p_workspace_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce((select jsonb_agg(jsonb_build_object(
    'name', l.name, 'sort_order', l.sort_order,
    'bookable_as_whole', coalesce(l.bookable_as_whole, false), 'price_cents', coalesce(l.price_cents, 0),
    'background_path', coalesce(l.background_path, ''),
    'site', (select s.name from public.sites s where s.id = l.site_id),
    'images', coalesce((select jsonb_agg(jsonb_build_object('x', i.x, 'y', i.y, 'w', i.w, 'h', i.h, 'storage_path', i.storage_path)
                order by i.storage_path) from public.plan_images i where i.level_id = l.id), '[]'::jsonb),
    'offices', coalesce((select jsonb_agg(jsonb_build_object(
      'name', o.name, 'color', o.color, 'bookable_as_whole', o.bookable_as_whole, 'price_cents', coalesce(o.price_cents, 0),
      'area_kind', o.area_kind,
      'x', o.x, 'y', o.y, 'w', o.w, 'h', o.h,
      'desks', coalesce((select jsonb_agg(jsonb_build_object(
        'name', d.name, 'x', d.x, 'y', d.y, 'w', d.w, 'h', d.h,
        'bookable_as_whole', coalesce(d.bookable_as_whole, false), 'price_cents', coalesce(d.price_cents, 0),
        'seats', coalesce((select jsonb_agg(jsonb_build_object(
          'name', st.name, 'x', st.x, 'y', st.y, 'orientation', st.orientation, 'chair', st.chair,
          'amenities', to_jsonb(st.amenities),
          'resource_kind', st.resource_kind, 'capacity', st.capacity,
          'parking_kind', st.parking_kind, 'slot_minutes', st.slot_minutes,
          'station', (select jsonb_build_object(
                        'name', cs.name, 'connector', cs.connector, 'power_kw', cs.power_kw,
                        'active', cs.active,
                        'accessory', (select a.name from public.accessories a where a.id = cs.accessory_id))
                      from public.charging_stations cs where cs.seat_id = st.id),
          'accessories', coalesce((select jsonb_agg(a.name order by a.name) from public.seat_accessories sa
                                    join public.accessories a on a.id = sa.accessory_id where sa.seat_id = st.id), '[]'::jsonb))
          order by st.name, st.x, st.y) from public.seats st where st.desk_id = d.id), '[]'::jsonb))
        order by d.name, d.x, d.y) from public.desks d where d.office_id = o.id), '[]'::jsonb))
      order by o.name, o.x, o.y) from public.offices o where o.level_id = l.id), '[]'::jsonb))
    order by l.sort_order, l.name) from public.levels l where l.workspace_id = p_workspace_id), '[]'::jsonb);
$fn$;
revoke execute on function public.export_floor_plan(uuid) from public, anon, authenticated;

create or replace function public.merge_floor_plan(p_workspace_id uuid, p_tree jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_l jsonb; v_o jsonb; v_d jsonb; v_s jsonb; v_i jsonb; v_acc text; v_st jsonb;
  v_lid uuid; v_oid uuid; v_did uuid; v_sid uuid; v_aid uuid; v_site uuid;
  v_jobs jsonb := '[]'::jsonb; v_from text; v_to text; v_name text;
  v_kind text; v_area text; v_have_kind text; v_have_area text;
begin
  if p_tree is null or jsonb_typeof(p_tree) <> 'array' then return jsonb_build_object('copy_jobs', v_jobs); end if;
  for v_l in select value from jsonb_array_elements(p_tree) loop
    select id into v_site from public.sites where workspace_id = p_workspace_id and name = v_l->>'site' limit 1;
    select id into v_lid from public.levels where workspace_id = p_workspace_id and name = v_l->>'name' order by created_at limit 1;
    -- the background: the same path under this workspace's prefix
    v_from := coalesce(v_l->>'background_path', '');
    v_to := case when v_from = '' then null else regexp_replace(v_from, '^[^/]+', p_workspace_id::text) end;
    if v_lid is null then
      insert into public.levels (workspace_id, name, sort_order, bookable_as_whole, price_cents, site_id, background_path)
      values (p_workspace_id, v_l->>'name', coalesce((v_l->>'sort_order')::int, 0), coalesce((v_l->>'bookable_as_whole')::boolean, false),
              coalesce((v_l->>'price_cents')::int, 0), v_site, v_to)
      returning id into v_lid;
    else
      update public.levels set sort_order = coalesce((v_l->>'sort_order')::int, sort_order),
        bookable_as_whole = coalesce((v_l->>'bookable_as_whole')::boolean, bookable_as_whole),
        price_cents = coalesce((v_l->>'price_cents')::int, price_cents),
        site_id = coalesce(v_site, site_id),
        background_path = coalesce(v_to, background_path)
       where id = v_lid;
    end if;
    if v_to is not null and v_from <> v_to then
      v_jobs := v_jobs || jsonb_build_object('from', v_from, 'to', v_to);
    end if;
    -- images by their path under the prefix
    for v_i in select value from jsonb_array_elements(coalesce(v_l->'images', '[]'::jsonb)) loop
      v_from := v_i->>'storage_path';
      v_to := regexp_replace(v_from, '^[^/]+', p_workspace_id::text);
      if exists (select 1 from public.plan_images where level_id = v_lid and storage_path = v_to) then
        update public.plan_images set x = (v_i->>'x')::int, y = (v_i->>'y')::int, w = (v_i->>'w')::int, h = (v_i->>'h')::int
         where level_id = v_lid and storage_path = v_to;
      else
        insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
        values (p_workspace_id, v_lid, (v_i->>'x')::int, (v_i->>'y')::int, (v_i->>'w')::int, (v_i->>'h')::int, v_to);
      end if;
      if v_from <> v_to then v_jobs := v_jobs || jsonb_build_object('from', v_from, 'to', v_to); end if;
    end loop;
    -- offices
    for v_o in select value from jsonb_array_elements(coalesce(v_l->'offices', '[]'::jsonb)) loop
      v_name := coalesce(v_o->>'name', '');
      v_area := v_o->>'area_kind';
      if v_area is not null and v_area not in ('workspace', 'parking') then
        raise exception 'unknown area kind %', v_area;
      end if;
      select id, area_kind into v_oid, v_have_area from public.offices where level_id = v_lid
        and (case when v_name <> '' then name = v_name else name = '' and x = (v_o->>'x')::int and y = (v_o->>'y')::int end)
        order by created_at limit 1;
      if v_oid is null then
        insert into public.offices (workspace_id, level_id, name, color, bookable_as_whole, price_cents, area_kind, x, y, w, h)
        values (p_workspace_id, v_lid, v_name, coalesce((v_o->>'color')::int, 0), coalesce((v_o->>'bookable_as_whole')::boolean, false),
                coalesce((v_o->>'price_cents')::int, 0), coalesce(v_area, 'workspace'),
                (v_o->>'x')::int, (v_o->>'y')::int, (v_o->>'w')::int, (v_o->>'h')::int)
        returning id into v_oid;
      else
        if v_area is not null and v_area <> v_have_area then
          raise exception 'the area % cannot become %', v_name, v_area;
        end if;
        update public.offices set color = coalesce((v_o->>'color')::int, color),
          bookable_as_whole = coalesce((v_o->>'bookable_as_whole')::boolean, bookable_as_whole),
          price_cents = coalesce((v_o->>'price_cents')::int, price_cents),
          x = (v_o->>'x')::int, y = (v_o->>'y')::int, w = (v_o->>'w')::int, h = (v_o->>'h')::int
         where id = v_oid;
      end if;
      -- desks
      for v_d in select value from jsonb_array_elements(coalesce(v_o->'desks', '[]'::jsonb)) loop
        v_name := coalesce(v_d->>'name', '');
        select id into v_did from public.desks where office_id = v_oid
          and (case when v_name <> '' then name = v_name else name = '' and x = (v_d->>'x')::int and y = (v_d->>'y')::int end)
          order by created_at limit 1;
        if v_did is null then
          insert into public.desks (workspace_id, office_id, name, x, y, w, h, bookable_as_whole, price_cents)
          values (p_workspace_id, v_oid, v_name, (v_d->>'x')::int, (v_d->>'y')::int, (v_d->>'w')::int, (v_d->>'h')::int,
                  coalesce((v_d->>'bookable_as_whole')::boolean, false), coalesce((v_d->>'price_cents')::int, 0))
          returning id into v_did;
        else
          update public.desks set x = (v_d->>'x')::int, y = (v_d->>'y')::int, w = (v_d->>'w')::int, h = (v_d->>'h')::int,
            bookable_as_whole = coalesce((v_d->>'bookable_as_whole')::boolean, bookable_as_whole),
            price_cents = coalesce((v_d->>'price_cents')::int, price_cents)
           where id = v_did;
        end if;
        -- seats, rooms and parking slots
        for v_s in select value from jsonb_array_elements(coalesce(v_d->'seats', '[]'::jsonb)) loop
          v_name := coalesce(v_s->>'name', '');
          v_kind := v_s->>'resource_kind';
          if v_kind is not null and v_kind not in ('seat', 'room', 'parking') then
            raise exception 'unknown resource kind %', v_kind;
          end if;
          select id, resource_kind into v_sid, v_have_kind from public.seats where desk_id = v_did
            and (case when v_name <> '' then name = v_name else name = '' and x = (v_s->>'x')::int and y = (v_s->>'y')::int end)
            order by created_at limit 1;
          if v_sid is null then
            insert into public.seats (workspace_id, desk_id, name, x, y, orientation, chair, amenities,
                                      resource_kind, capacity, parking_kind, slot_minutes)
            values (p_workspace_id, v_did, v_name, (v_s->>'x')::int, (v_s->>'y')::int, coalesce(v_s->>'orientation', 'n'),
                    coalesce(v_s->>'chair', ''), public.jsonb_text_array(v_s->'amenities'),
                    coalesce(v_kind, 'seat'), (v_s->>'capacity')::int, v_s->>'parking_kind',
                    (v_s->>'slot_minutes')::int)
            returning id into v_sid;
          else
            if v_kind is not null and v_kind <> v_have_kind then
              raise exception 'the slot % is a % here and cannot become a %', v_name, v_have_kind, v_kind;
            end if;
            update public.seats set x = (v_s->>'x')::int, y = (v_s->>'y')::int, orientation = coalesce(v_s->>'orientation', orientation),
              chair = coalesce(v_s->>'chair', chair),
              amenities = public.jsonb_text_array(v_s->'amenities'),
              capacity = case when v_s ? 'capacity' then (v_s->>'capacity')::int else capacity end,
              parking_kind = case when v_s ? 'parking_kind' then v_s->>'parking_kind' else parking_kind end,
              slot_minutes = case when v_s ? 'slot_minutes' then (v_s->>'slot_minutes')::int else slot_minutes end
             where id = v_sid;
          end if;
          -- accessories by name: the source's set becomes the seat's set
          delete from public.seat_accessories where seat_id = v_sid;
          for v_acc in select jsonb_array_elements_text(coalesce(v_s->'accessories', '[]'::jsonb)) loop
            select id into v_aid from public.accessories where workspace_id = p_workspace_id and name = v_acc limit 1;
            if v_aid is not null then
              insert into public.seat_accessories (workspace_id, seat_id, accessory_id) values (p_workspace_id, v_sid, v_aid)
              on conflict do nothing;
            end if;
          end loop;
          -- its charging station: one per EV slot, upserted on the slot
          v_st := v_s->'station';
          if v_st is not null and jsonb_typeof(v_st) = 'object' then
            v_aid := null;
            if coalesce(v_st->>'accessory', '') <> '' then
              select id into v_aid from public.accessories
               where workspace_id = p_workspace_id and name = v_st->>'accessory' limit 1;
              if v_aid is null then
                raise exception 'the charging station of % names the accessory %, which this space does not have',
                  v_name, v_st->>'accessory';
              end if;
            end if;
            insert into public.charging_stations (workspace_id, seat_id, name, connector, power_kw, accessory_id, active)
            values (p_workspace_id, v_sid, coalesce(v_st->>'name', ''), v_st->>'connector',
                    (v_st->>'power_kw')::numeric, v_aid, coalesce((v_st->>'active')::boolean, true))
            on conflict (seat_id) do update
              set name = excluded.name, connector = excluded.connector, power_kw = excluded.power_kw,
                  accessory_id = excluded.accessory_id, active = excluded.active;
          end if;
        end loop;
      end loop;
    end loop;
  end loop;
  return jsonb_build_object('copy_jobs', v_jobs);
end;
$fn$;
revoke execute on function public.merge_floor_plan(uuid, jsonb) from public, anon, authenticated;

-- ── B. one condition for the seat quota ─────────────────────────────────
create or replace function public.reservation_uses_seat_quota(r public.reservations)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((select s.resource_kind = 'seat' from public.seats s where s.id = r.seat_id), true);
$fn$;
revoke execute on function public.reservation_uses_seat_quota(public.reservations)
  from public, anon, authenticated;

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0471: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

-- The statement counts the half-days of SEATS; the supplements (accessories,
-- a charger's fee) keep reading every counted booking, so they are billed once
-- and on their own.
select pg_temp.patch_function('public.member_statement(uuid, text)'::regprocedure,
  array[
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz);

  -- #446 hours granularity: booked time per day converts$a$,
    $a$where true
        and r.starts_at >= v_period_start
      group by 1$a$],
  array[
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
    and public.reservation_uses_seat_quota(r);

  -- #446 hours granularity: booked time per day converts$a$,
    $a$where true
        and r.starts_at >= v_period_start
        and public.reservation_uses_seat_quota(r)
      group by 1$a$]);

select pg_temp.patch_function('public.assert_member_quota(uuid, timestamptz)'::regprocedure,
  array[
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz);

  -- #446 hours granularity: same half-day-equivalent conversion as$a$,
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
      group by 1$a$],
  array[
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
    and public.reservation_uses_seat_quota(r);

  -- #446 hours granularity: same half-day-equivalent conversion as$a$,
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
        and public.reservation_uses_seat_quota(r)
      group by 1$a$]);

select pg_temp.patch_function('public.member_quota_shortfall(uuid, timestamptz)'::regprocedure,
  array[
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz);

  -- #446 hours granularity: same half-day-equivalent conversion as$a$,
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
      group by 1$a$],
  array[
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
    and public.reservation_uses_seat_quota(r);

  -- #446 hours granularity: same half-day-equivalent conversion as$a$,
    $a$and public.reservation_counts_for_usage(r, v_rules, v_tz)
        and public.reservation_uses_seat_quota(r)
      group by 1$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(471);
