-- SPDX-License-Identifier: 0BSD
-- DesKilo availability: owner-configurable open weekdays + closure days
-- (epic #121 task 2, issue #127, ADR 0008). Closed days are rejected for
-- reservation AND check-in; series expansion skips them; they drop out of
-- the entitlement basis (used by member_statement from task 4 on).

-- Open weekdays live inside booking_rules (ISO isodow 1=Mon..7=Sun).
alter table public.workspaces alter column booking_rules set default
  '{"advance_horizon_days": 90, "max_series_days": 180, "min_duration_minutes": 30, "max_duration_minutes": 1440, "open_weekdays": [1,2,3,4,5]}'::jsonb;
update public.workspaces
  set booking_rules = booking_rules || '{"open_weekdays": [1,2,3,4,5]}'::jsonb
  where not booking_rules ? 'open_weekdays';

create table public.closure_days (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  day date not null,
  reason text not null default '',
  created_at timestamptz not null default now(),
  unique (workspace_id, day)
);

alter table public.closure_days enable row level security;
create policy closure_days_read on public.closure_days
  for select using (public.is_member_of(workspace_id));
create policy closure_days_write on public.closure_days
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

-- Raises unless every workspace-local day the range touches is open.
-- The end instant is exclusive: a range ending at local midnight does not
-- touch the next day.
create or replace function public.assert_workspace_open(
  p_workspace_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns void language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text;
  v_open int[];
  v_day date;
  v_last date;
begin
  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5])
    into v_tz, v_open
    from public.workspaces where id = p_workspace_id;
  v_day := (p_starts_at at time zone v_tz)::date;
  v_last := ((p_ends_at - interval '1 second') at time zone v_tz)::date;
  while v_day <= v_last loop
    if not (extract(isodow from v_day)::int = any(v_open)) then
      raise exception 'workspace is closed on % (weekday not open)', v_day;
    end if;
    if exists (select 1 from public.closure_days
                where workspace_id = p_workspace_id and day = v_day) then
      raise exception 'workspace is closed on % (closure day)', v_day;
    end if;
    v_day := v_day + 1;
  end loop;
end;
$$;
revoke execute on function public.assert_workspace_open(uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- enforce_booking_rules is the shared chokepoint of create_reservation
-- (incl. walk-up), create_series, and admin_create_reservation_for —
-- availability slots in here so every booking path gets it.
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
  perform public.assert_workspace_open(p_workspace_id, p_starts_at, p_ends_at);
end;
$$;

-- Series expansion: closed days land in the skipped report instead of
-- failing the whole series. Same signature as migration 0006; the weekday
-- pattern filter stays, availability now also gates every instance.
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
        -- closed days raise here and land in the skipped report, exactly
        -- like seat conflicts
        perform public.assert_workspace_open(p_workspace_id, v_start, v_end);
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

-- Check-in on a day the owner closed after the reservation was made is
-- rejected ("not open for check-in or reservation").
create or replace function public.check_in_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_res public.reservations;
begin
  select r.* into v_res from public.reservations r
    join public.members m on m.id = r.member_id
    where r.id = p_reservation_id and m.user_id = auth.uid();
  if v_res.id is null then raise exception 'not your reservation'; end if;
  if v_res.status <> 'reserved' then raise exception 'not in reserved state'; end if;
  perform public.assert_workspace_open(v_res.workspace_id, now(), now() + interval '1 minute');
  update public.reservations
    set status = 'checked_in', checked_in_at = now()
    where id = p_reservation_id;
end;
$$;
