-- SPDX-License-Identifier: 0BSD
-- kiosk_act v4 (#430): the kiosk under the presence + one-place rules.
--
-- Field breakage: the check-in path found the member's own reservation
-- only once starts_at <= now(). Badging up to 15 minutes EARLY — the
-- exact leeway 0077 grants everywhere else — fell through to a walk-up
-- INSERT on the same seat, which the 0079 one-place trigger rightly
-- refuses: the member was blocked from checking into their own
-- imminent reservation. (Before 0079 the same fall-through silently
-- created the overlapping double-booking of #412.)
--
-- v4: both find queries use the 15-minute leeway, and the flip paths
-- carry check_in_reservation v3's guards — stale check-ins complete at
-- their own end, a still-running check-in elsewhere refuses with the
-- pinned substring.

create or replace function public.kiosk_act(
  p_workspace_id uuid,
  p_badge_token text,
  p_action text,             -- 'reserve' | 'check_in' | 'check_out'
  p_seat_id uuid default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_level_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_kiosk public.members;
  v_badge public.member_badges;
  v_subject public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_res public.reservations;
  v_id uuid;
begin
  select * into v_kiosk from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and is_kiosk;
  if v_kiosk.id is null then raise exception 'not a kiosk of this workspace'; end if;

  select * into v_badge from public.member_badges
    where workspace_id = p_workspace_id
      and token_hash = public.badge_token_hash(p_badge_token)
      and revoked_at is null;
  if v_badge.id is null then
    raise exception 'badge not recognized';
  end if;
  select * into v_subject from public.members
    where id = v_badge.member_id and status = 'active';
  if v_subject.id is null then raise exception 'badge member not active'; end if;

  if p_action = 'check_out' then
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.status = 'checked_in'
        and (p_seat_id is null or r.seat_id = p_seat_id)
        and (p_level_id is null or r.level_id = p_level_id)
      order by r.checked_in_at desc limit 1;
    if v_res.id is null then raise exception 'not checked in'; end if;
    update public.reservations
      set status = 'completed', checked_out_at = now(),
          ends_at = least(ends_at, now())
      where id = v_res.id;
    return jsonb_build_object('action', 'check_out', 'reservation_id', v_res.id);
  end if;

  if p_action not in ('reserve', 'check_in') then
    raise exception 'unknown kiosk action';
  end if;
  if (p_seat_id is null) = (p_level_id is null)
     or p_starts_at is null or p_ends_at is null then
    raise exception 'seat or level, and window required';
  end if;

  if p_level_id is not null then
    -- Level path: same gates as create_reservation — feature, bookable,
    -- the badge member's personal grant, no conflicts on the level.
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
    if not v_subject.can_reserve_level then
      raise exception 'not allowed to reserve a level';
    end if;

    if p_action = 'check_in' then
      select r.* into v_res from public.reservations r
        where r.member_id = v_subject.id and r.level_id = p_level_id
          and r.status = 'reserved'
          -- 0077 presence leeway (#430): badging up to 15 min early must
          -- find the reservation, not fall through to a walk-up insert
          -- the one-place trigger rightly refuses.
          and r.starts_at - interval '15 minutes' <= now()
          and r.ends_at > now()
        limit 1;
      if v_res.id is not null then
        -- One place (#430, mirroring check_in_reservation v3): stale
        -- check-ins complete at their own end; still-running elsewhere
        -- refuses with the pinned substring.
        update public.reservations
          set status = 'completed', checked_out_at = ends_at
          where member_id = v_subject.id and id <> v_res.id
            and status = 'checked_in' and ends_at <= now();
        if exists (
          select 1 from public.reservations r2
          where r2.member_id = v_subject.id and r2.id <> v_res.id
            and r2.status = 'checked_in' and r2.ends_at > now()
        ) then
          raise exception 'already checked in elsewhere';
        end if;
        update public.reservations
          set status = 'checked_in', checked_in_at = now()
          where id = v_res.id;
        return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
      end if;
    end if;

    perform public.enforce_booking_rules(
      p_workspace_id, p_starts_at, p_ends_at, p_action = 'check_in');
    if public.level_has_conflict(p_level_id, p_starts_at, p_ends_at) then
      raise exception 'the level has reservations in that period';
    end if;

    insert into public.reservations
      (workspace_id, level_id, member_id, starts_at, ends_at, status, checked_in_at)
    values (
      p_workspace_id, p_level_id, v_subject.id, p_starts_at, p_ends_at,
      case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
      case when p_action = 'check_in' then now() end
    )
    returning id into v_id;
    perform public.assert_member_quota(v_subject.id, p_starts_at);
    return jsonb_build_object('action', p_action, 'reservation_id', v_id);
  end if;

  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;
  if v_seat.id is null then raise exception 'unknown seat'; end if;

  if p_action = 'check_in' then
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.seat_id = p_seat_id
        and r.status = 'reserved'
        -- 0077 presence leeway (#430), as on the level path above.
        and r.starts_at - interval '15 minutes' <= now()
        and r.ends_at > now()
      limit 1;
    if v_res.id is not null then
      -- One place (#430): same guards as the level path.
      update public.reservations
        set status = 'completed', checked_out_at = ends_at
        where member_id = v_subject.id and id <> v_res.id
          and status = 'checked_in' and ends_at <= now();
      if exists (
        select 1 from public.reservations r2
        where r2.member_id = v_subject.id and r2.id <> v_res.id
          and r2.status = 'checked_in' and r2.ends_at > now()
      ) then
        raise exception 'already checked in elsewhere';
      end if;
      update public.reservations
        set status = 'checked_in', checked_in_at = now()
        where id = v_res.id;
      return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
    end if;
  end if;

  perform public.enforce_booking_rules(
    p_workspace_id, p_starts_at, p_ends_at, p_action = 'check_in');
  if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
               coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
     && tstzrange(p_starts_at, p_ends_at)
     and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
    raise exception 'seat is blocked in that period';
  end if;
  -- 0059: the seat's DESK reserved as a whole blocks the walk-up too.
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
  if exists (
    select 1 from public.reservations r
    where r.level_id = (select o.level_id from public.offices o where o.id = v_office_id)
      and r.status in ('reserved','checked_in')
      and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
  ) then
    raise exception 'level is reserved as a whole in that period';
  end if;

  insert into public.reservations
    (workspace_id, seat_id, member_id, starts_at, ends_at, status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, v_subject.id, p_starts_at, p_ends_at,
    case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
    case when p_action = 'check_in' then now() end
  )
  returning id into v_id;
  perform public.assert_member_quota(v_subject.id, p_starts_at);
  return jsonb_build_object('action', p_action, 'reservation_id', v_id);
end;
$$;
