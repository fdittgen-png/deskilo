-- SPDX-License-Identifier: MIT
-- DesKilo booking rules + recurring series (Epic #5, issue #50). Applied to
-- the hosted reference project on 2026-07-07 as "booking_rules_and_series".

-- Owner-editable rules with sane defaults (spec §5.3, subset delivered now).
alter table public.workspaces add column booking_rules jsonb not null default
  '{"advance_horizon_days": 90, "max_series_days": 180, "min_duration_minutes": 30, "max_duration_minutes": 1440}'::jsonb;

create or replace function public.enforce_booking_rules(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns void language plpgsql stable security definer set search_path = public as $$
declare rules jsonb; horizon int; min_min int; max_min int; dur int;
begin
  select booking_rules into rules from public.workspaces where id = p_workspace_id;
  horizon := coalesce((rules->>'advance_horizon_days')::int, 90);
  min_min := coalesce((rules->>'min_duration_minutes')::int, 30);
  max_min := coalesce((rules->>'max_duration_minutes')::int, 1440);
  if p_starts_at > now() + make_interval(days => horizon) then
    raise exception 'beyond the advance-booking horizon of % days', horizon;
  end if;
  dur := extract(epoch from (p_ends_at - p_starts_at))::int / 60;
  if dur < min_min then
    raise exception 'below the minimum duration of % minutes', min_min;
  end if;
  if dur > max_min then
    raise exception 'above the maximum duration of % minutes', max_min;
  end if;
end;
$$;
revoke execute on function public.enforce_booking_rules(uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- Wire rules into single-reservation creation: recreate create_reservation
-- with the rules call (body otherwise identical to migration 0005).
create or replace function public.create_reservation(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_office_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_check_in boolean default false
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_id uuid;
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if (p_seat_id is null) = (p_office_id is null) then
    raise exception 'exactly one of seat or office required';
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at);

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
    select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
    if exists (
      select 1 from public.reservations r
      where r.office_id = v_office_id
        and r.status in ('reserved','checked_in')
        and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
    ) then
      raise exception 'office is reserved as a whole in that period';
    end if;
  else
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
  end if;

  insert into public.reservations
    (workspace_id, seat_id, office_id, member_id, starts_at, ends_at, status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, p_office_id, v_member.id, p_starts_at, p_ends_at,
    case when p_check_in then 'checked_in' else 'reserved' end,
    case when p_check_in then now() end
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- Series creation (spec §5.2): expands the pattern server-side, books free
-- instances, returns booked and skipped starts — never silently partial.
-- p_pattern: 'daily' | 'weekdays' | 'weekly'
create or replace function public.create_series(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_first_start timestamptz,
  p_first_end timestamptz,
  p_pattern text,
  p_until timestamptz
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
begin
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if p_pattern not in ('daily','weekdays','weekly') then
    raise exception 'unknown pattern';
  end if;
  select booking_rules, timezone into v_rules, v_tz
    from public.workspaces where id = p_workspace_id;
  v_max_days := coalesce((v_rules->>'max_series_days')::int, 180);
  if p_until > p_first_start + make_interval(days => v_max_days) then
    raise exception 'series exceeds the maximum of % days', v_max_days;
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_first_start, p_first_end);

  v_step := case when p_pattern = 'weekly' then interval '7 days' else interval '1 day' end;

  while v_start <= p_until loop
    -- weekday filter recurs in workspace-local time (spec §11 DST rule)
    v_dow := extract(isodow from v_start at time zone v_tz)::int;
    if p_pattern <> 'weekdays' or v_dow between 1 and 5 then
      begin
        insert into public.reservations
          (workspace_id, seat_id, member_id, starts_at, ends_at, status, series_id)
        values (p_workspace_id, p_seat_id, v_member.id, v_start, v_end, 'reserved', v_series_id);
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

-- Cancel a whole series or this-and-following from an instant.
create or replace function public.cancel_series(
  p_series_id uuid,
  p_from timestamptz default null
) returns int language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  update public.reservations r
    set status = 'cancelled'
    from public.members m
    where r.series_id = p_series_id
      and m.id = r.member_id
      and m.user_id = auth.uid()
      and r.status = 'reserved'
      and (p_from is null or r.starts_at >= p_from);
  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'nothing to cancel'; end if;
  return v_count;
end;
$$;

revoke execute on function public.create_series(uuid, uuid, timestamptz, timestamptz, text, timestamptz) from public, anon;
revoke execute on function public.cancel_series(uuid, timestamptz) from public, anon;
