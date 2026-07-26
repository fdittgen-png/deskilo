-- SPDX-License-Identifier: 0BSD
-- Whole-space SERIES (field request): tables and rooms/levels must
-- offer the same repetition as seats. create_series v2 accepts exactly
-- one of seat/desk/office/level. Whole-space targets pass the same
-- one-time gates as create_reservation (feature + personal grant +
-- bookable-as-whole) and each occurrence re-runs the same cross-scale
-- conflict checks; conflicting/closed/beyond-quota occurrences land in
-- the skipped report exactly like seat series. When the owner
-- configured a 'space_reservation' validation rule, every BOOKED
-- whole-space occurrence routes through the regular quorum (a reject
-- cancels just that occurrence via respond_to_event's existing branch).

drop function public.create_series(uuid, uuid, timestamptz, timestamptz, text, timestamptz);
create function public.create_series(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_first_start timestamptz,
  p_first_end timestamptz,
  p_pattern text,
  p_until timestamptz,
  p_desk_id uuid default null,
  p_office_id uuid default null,
  p_level_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_rules jsonb;
  v_max_days int;
  v_series_id uuid := gen_random_uuid();
  v_start timestamptz := p_first_start;
  v_end timestamptz := p_first_end;
  v_tz text;
  v_booked jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
  v_step interval;
  v_dow int;
  v_office_of uuid;
  v_level_of uuid;
  v_space boolean;
  v_validated boolean := false;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if p_pattern not in ('daily','weekdays','weekly') then
    raise exception 'unknown pattern';
  end if;
  if (case when p_seat_id is null then 0 else 1 end
      + case when p_desk_id is null then 0 else 1 end
      + case when p_office_id is null then 0 else 1 end
      + case when p_level_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of seat, desk, office or level required';
  end if;
  v_space := p_seat_id is null;

  select booking_rules, timezone into v_rules, v_tz
    from public.workspaces where id = p_workspace_id;
  v_max_days := coalesce((v_rules->>'max_series_days')::int, 180);
  if p_until > p_first_start + make_interval(days => v_max_days) then
    raise exception 'series exceeds the maximum of % days', v_max_days;
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_first_start, p_first_end);

  -- One-time whole-space gates — identical to create_reservation v7.
  if v_space then
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not v_member.can_reserve_level then
      -- the client pins this substring (0050)
      raise exception 'not allowed to reserve a level';
    end if;
    if p_desk_id is not null then
      if not exists (
        select 1 from public.desks d
        where d.id = p_desk_id and d.workspace_id = p_workspace_id
          and d.bookable_as_whole
      ) then
        raise exception 'desk not bookable as a whole';
      end if;
      select d.office_id into v_office_of from public.desks d where d.id = p_desk_id;
      select o.level_id into v_level_of from public.offices o where o.id = v_office_of;
    elsif p_office_id is not null then
      if not exists (
        select 1 from public.offices o
        where o.id = p_office_id and o.workspace_id = p_workspace_id
          and o.bookable_as_whole
      ) then
        raise exception 'office not bookable as a whole';
      end if;
      select o.level_id into v_level_of from public.offices o where o.id = p_office_id;
    else
      if not exists (
        select 1 from public.levels l
        where l.id = p_level_id and l.workspace_id = p_workspace_id
          and l.bookable_as_whole
      ) then
        raise exception 'level not bookable as a whole';
      end if;
    end if;
    v_validated := exists (
      select 1 from public.validation_policies vp
      where vp.workspace_id = p_workspace_id
        and vp.event_type = 'space_reservation');
  end if;

  v_step := case when p_pattern = 'weekly' then interval '7 days' else interval '1 day' end;

  while v_start <= p_until loop
    -- weekday filter recurs in workspace-local time (spec §11 DST rule)
    v_dow := extract(isodow from v_start at time zone v_tz)::int;
    if p_pattern <> 'weekdays' or v_dow between 1 and 5 then
      begin
        -- closed days raise here and land in the skipped report, exactly
        -- like conflicts
        perform public.assert_workspace_open(p_workspace_id, v_start, v_end);
        if p_seat_id is not null then
          -- blocked seats too (#161)
          perform public.assert_seat_not_blocked(p_seat_id, v_start, v_end);
        elsif p_desk_id is not null then
          -- Cross-scale conflicts, desk scale (create_reservation v7).
          if exists (
            select 1 from public.reservations r
            join public.seats s on s.id = r.seat_id
            where s.desk_id = p_desk_id
              and r.status in ('reserved','checked_in')
              and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_start, v_end)
          ) then
            raise exception 'a seat on this desk is already reserved in that period';
          end if;
          if exists (
            select 1 from public.reservations r
            where r.office_id = v_office_of
              and r.status in ('reserved','checked_in')
              and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_start, v_end)
          ) then
            raise exception 'office is reserved as a whole in that period';
          end if;
          if exists (
            select 1 from public.reservations r
            where r.level_id = v_level_of
              and r.status in ('reserved','checked_in')
              and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_start, v_end)
          ) then
            raise exception 'level is reserved as a whole in that period';
          end if;
        elsif p_office_id is not null then
          if exists (
            select 1 from public.reservations r
            join public.seats s on s.id = r.seat_id
            join public.desks d on d.id = s.desk_id
            where d.office_id = p_office_id
              and r.status in ('reserved','checked_in')
              and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_start, v_end)
          ) then
            raise exception 'a seat in this office is already reserved in that period';
          end if;
          if exists (
            select 1 from public.reservations r
            join public.desks d on d.id = r.desk_id
            where d.office_id = p_office_id
              and r.status in ('reserved','checked_in')
              and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_start, v_end)
          ) then
            raise exception 'a desk in this office is already reserved in that period';
          end if;
          if exists (
            select 1 from public.reservations r
            where r.level_id = v_level_of
              and r.status in ('reserved','checked_in')
              and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_start, v_end)
          ) then
            raise exception 'level is reserved as a whole in that period';
          end if;
        else
          if public.level_has_conflict(p_level_id, v_start, v_end) then
            raise exception 'the level has reservations in that period';
          end if;
        end if;

        insert into public.reservations
          (workspace_id, seat_id, desk_id, office_id, level_id, member_id,
           starts_at, ends_at, status, series_id)
        values (p_workspace_id, p_seat_id, p_desk_id, p_office_id,
                p_level_id, v_member.id, v_start, v_end, 'reserved',
                v_series_id)
        returning id into v_id;
        -- beyond-quota instances are skipped, not booked
        perform public.assert_member_quota(v_member.id, v_start);
        if v_validated then
          update public.events
            set status = 'pending', type = 'space_reservation'
            where reservation_id = v_id and action = 'created';
        end if;
        v_booked := v_booked || to_jsonb(v_start);
      exception when others then
        v_skipped := v_skipped || to_jsonb(v_start);
      end;
    end if;
    v_start := v_start + v_step;
    v_end := v_end + v_step;
  end loop;

  return jsonb_build_object(
    'series_id', v_series_id,
    'booked', v_booked,
    'skipped', v_skipped
  );
end;
$$;
revoke execute on function public.create_series(
  uuid, uuid, timestamptz, timestamptz, text, timestamptz,
  uuid, uuid, uuid) from public, anon;
