-- SPDX-License-Identifier: 0BSD
-- One place at a time, and whole-space booking the owner can use (#412).
--
-- Field evidence (2026-08-03, hosted): a member walked up and checked in
-- on one seat, then — still checked in there — walked up onto a second
-- seat, and also held overlapping reservations. Every RPC checks whether
-- the TARGET is taken; none ever asked whether the MEMBER is already
-- somewhere else. And the owner could not reserve a whole desk/office/
-- level: the 0050 grant defaults false and nobody self-grants ceremony.
--
-- Four changes:
--
--  1. enforce_one_place — BEFORE INSERT trigger on reservations: a new
--     active row overlapping another active row OF THE SAME MEMBER
--     refuses with a pinned substring. One definition covers walk-up,
--     create_reservation, series instances (the loop's exception
--     handler turns it into a skipped date, like any conflict),
--     admin_create_reservation_for, kiosk_act, and every future path.
--     INSERT only: status flips and check-out truncation never create
--     new overlap.
--
--  2. check_in_reservation v3 — keeps the 0077 presence window and
--     for-others path; additionally a member checked in ELSEWHERE on a
--     still-running reservation is refused (one body, one place), and
--     stale check-ins whose own end has passed are auto-completed
--     first, stamped at their own end (0075 semantics) — forgetting to
--     check out must not wedge tomorrow's check-in.
--
--  3. create_reservation v8 / create_series v3 — the whole-space right
--     accepts can_reserve_level OR is_owner OR is_admin. The grant
--     machinery stays what it is for regular members; owners and
--     admins stop having to grant themselves ceremony. (kiosk_act
--     deliberately keeps the strict stored grant: a badge at a kiosk
--     carries no role context worth trusting.)

-- 1. The one-place trigger.
create or replace function public.enforce_one_place()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('reserved', 'checked_in') and exists (
    select 1 from public.reservations r
    where r.member_id = new.member_id
      and r.id <> new.id
      and r.status in ('reserved', 'checked_in')
      and tstzrange(r.starts_at, r.ends_at)
          && tstzrange(new.starts_at, new.ends_at)
  ) then
    -- the client pins this substring
    raise exception 'you already have a reservation in that period';
  end if;
  return new;
end;
$$;

drop trigger if exists reservations_one_place on public.reservations;
create trigger reservations_one_place
  before insert on public.reservations
  for each row execute function public.enforce_one_place();

-- 2. check_in_reservation v3 (0077 body + the elsewhere guards).
create or replace function public.check_in_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own then
    -- The authorized-for-others path (0077): admin/owner + the
    -- bookForOthers feature (default ON, so ABSENT counts as ON).
    if not (
      public.is_admin_of(v_res.workspace_id)
      and coalesce((
        select w.feature_flags->'bookForOthers' is distinct from 'false'::jsonb
        from public.workspaces w where w.id = v_res.workspace_id
      ), true)
    ) then
      raise exception 'not your reservation';
    end if;
  end if;

  if v_res.status <> 'reserved' then raise exception 'not in reserved state'; end if;

  -- Presence window (0077, spec §4.3).
  if now() < v_res.starts_at - interval '15 minutes' then
    raise exception 'check-in window not open yet';
  end if;
  if now() >= v_res.ends_at then
    raise exception 'check-in window closed';
  end if;

  -- One place at a time (#412): a forgotten check-out whose own end has
  -- passed completes itself (stamped at its own end, 0075 semantics)...
  update public.reservations
    set status = 'completed', checked_out_at = ends_at
    where member_id = v_res.member_id
      and id <> v_res.id
      and status = 'checked_in'
      and ends_at <= now();
  -- ...but a check-in still RUNNING elsewhere means the member is
  -- physically somewhere else: refuse, check out there first.
  if exists (
    select 1 from public.reservations r
    where r.member_id = v_res.member_id
      and r.id <> v_res.id
      and r.status = 'checked_in'
      and r.ends_at > now()
  ) then
    -- the client pins this substring
    raise exception 'already checked in elsewhere';
  end if;

  perform public.assert_workspace_open(v_res.workspace_id, now(), now() + interval '1 minute');
  update public.reservations
    set status = 'checked_in', checked_in_at = now()
    where id = p_reservation_id;
end;
$$;

-- 3. create_reservation v8: 0059 body, whole-space right accepts
--    owner/admin.
create or replace function public.create_reservation(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_office_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_check_in boolean default false,
  p_level_id uuid default null,
  p_desk_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_level_id uuid;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if (case when p_seat_id is null then 0 else 1 end
      + case when p_desk_id is null then 0 else 1 end
      + case when p_office_id is null then 0 else 1 end
      + case when p_level_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of seat, desk, office or level required';
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at, p_check_in);

  if p_seat_id is not null then
    select * into v_seat from public.seats
      where id = p_seat_id and workspace_id = p_workspace_id;
    if v_seat.id is null then raise exception 'unknown seat'; end if;
    if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
                 coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
       && tstzrange(p_starts_at, p_ends_at)
       and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
      raise exception 'seat is blocked in that period';
    end if;
    -- 0059: the seat's DESK reserved as a whole blocks the seat.
    if exists (
      select 1 from public.reservations r
      where r.desk_id = v_seat.desk_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'desk is reserved as a whole in that period';
    end if;
    select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
    if exists (
      select 1 from public.reservations r
      where r.office_id = v_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'office is reserved as a whole in that period';
    end if;
    select o.level_id into v_level_id from public.offices o where o.id = v_office_id;
    if exists (
      select 1 from public.reservations r
      where r.level_id = v_level_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'level is reserved as a whole in that period';
    end if;
  elsif p_desk_id is not null then
    -- Whole-DESK path (0059): the level/office gates, desk-scale.
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not (v_member.can_reserve_level or v_member.is_owner
            or v_member.is_admin) then
      -- the client pins this substring (0050)
      raise exception 'not allowed to reserve a level';
    end if;
    if not exists (
      select 1 from public.desks d
      where d.id = p_desk_id and d.workspace_id = p_workspace_id
        and d.bookable_as_whole
    ) then
      raise exception 'desk not bookable as a whole';
    end if;
    if exists (
      select 1 from public.reservations r
      join public.seats s on s.id = r.seat_id
      where s.desk_id = p_desk_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'a seat on this desk is already reserved in that period';
    end if;
    select d.office_id into v_office_id from public.desks d where d.id = p_desk_id;
    if exists (
      select 1 from public.reservations r
      where r.office_id = v_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'office is reserved as a whole in that period';
    end if;
    select o.level_id into v_level_id from public.offices o where o.id = v_office_id;
    if exists (
      select 1 from public.reservations r
      where r.level_id = v_level_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'level is reserved as a whole in that period';
    end if;
  elsif p_office_id is not null then
    -- Whole-space gates (0057): feature + personal grant, like levels.
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not (v_member.can_reserve_level or v_member.is_owner
            or v_member.is_admin) then
      -- the client pins this substring (0050)
      raise exception 'not allowed to reserve a level';
    end if;
    if not exists (
      select 1 from public.offices o
      where o.id = p_office_id and o.workspace_id = p_workspace_id
        and o.bookable_as_whole
    ) then
      raise exception 'office not bookable as a whole';
    end if;
    if exists (
      select 1 from public.reservations r
      join public.seats s on s.id = r.seat_id
      join public.desks d on d.id = s.desk_id
      where d.office_id = p_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'a seat in this office is already reserved in that period';
    end if;
    -- 0059: a desk inside reserved as a whole blocks the office too.
    if exists (
      select 1 from public.reservations r
      join public.desks d on d.id = r.desk_id
      where d.office_id = p_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'a desk in this office is already reserved in that period';
    end if;
    select o.level_id into v_level_id from public.offices o where o.id = p_office_id;
    if exists (
      select 1 from public.reservations r
      where r.level_id = v_level_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'level is reserved as a whole in that period';
    end if;
  else
    -- Level path: feature on, level bookable, member personally allowed.
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not exists (
      select 1 from public.levels l
      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole
    ) then
      raise exception 'level not bookable as a whole';
    end if;
    if not (v_member.can_reserve_level or v_member.is_owner
            or v_member.is_admin) then
      -- the client pins this substring
      raise exception 'not allowed to reserve a level';
    end if;
    if public.level_has_conflict(p_level_id, p_starts_at, p_ends_at) then
      raise exception 'the level has reservations in that period';
    end if;
  end if;

  insert into public.reservations
    (workspace_id, seat_id, desk_id, office_id, level_id, member_id,
     starts_at, ends_at, status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, p_desk_id, p_office_id, p_level_id,
    v_member.id, p_starts_at, p_ends_at,
    case when p_check_in then 'checked_in' else 'reserved' end,
    case when p_check_in then now() end
  )
  returning id into v_id;
  perform public.assert_member_quota(v_member.id, p_starts_at);

  -- 0059: whole-space bookings route through the REGULAR validation
  -- feature when the owner configured a rule for them — the reservation
  -- blocks the space immediately, validators confirm or reject (a
  -- reject cancels it via respond_to_event's existing branch).
  if p_desk_id is not null or p_office_id is not null
     or p_level_id is not null then
    if exists (
      select 1 from public.validation_policies vp
      where vp.workspace_id = p_workspace_id
        and vp.event_type = 'space_reservation'
    ) then
      update public.events
        set status = 'pending', type = 'space_reservation'
        where reservation_id = v_id and action = 'created';
    end if;
  end if;
  return v_id;
end;
$$;

-- 4. create_series v3: 0065 body, same exemption.
create or replace function public.create_series(
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
    if not (v_member.can_reserve_level or v_member.is_owner
            or v_member.is_admin) then
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

-- 5. Overrule (#412, owner follow-up): "no multiple reservations —
--    owner/admin only can overrule an existing reservation; the other
--    is removed and the user and all admins/owners are notified."
--    cancel_reservation v2 accepts an admin/owner of the workspace for
--    ANOTHER member's reservation. The reservations_log_event trigger
--    (0007) records the cancellation as an event the displaced member
--    sees in their feed (and admins see everything) — that IS the
--    notification channel, the same one every reservation change uses.
create or replace function public.cancel_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own and not public.is_admin_of(v_res.workspace_id) then
    raise exception 'not your reservation';
  end if;

  if v_res.status not in ('reserved','checked_in') then
    raise exception 'not cancellable';
  end if;
  update public.reservations set status = 'cancelled' where id = p_reservation_id;
end;
$$;
