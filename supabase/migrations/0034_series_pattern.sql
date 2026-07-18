-- SPDX-License-Identifier: MIT
-- Persist the repetition modality. Applied to the hosted reference
-- project on 2026-07-19.
--
-- Series instances only carried a grouping series_id; the PATTERN
-- (daily / weekdays / weekly) was expanded at creation and lost, so no
-- surface could tell the user HOW a booking repeats. The column rides
-- every instance; pre-0034 rows stay null and read as a generic
-- recurring booking.

alter table public.reservations
  add column series_pattern text
  check (series_pattern in ('daily','weekdays','weekly'));

-- create_series: body = 0031 verbatim + series_pattern on the insert.
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
        -- blocked seats too (#161)
        perform public.assert_seat_not_blocked(p_seat_id, v_start, v_end);
        insert into public.reservations
          (workspace_id, seat_id, member_id, starts_at, ends_at, status,
           series_id, series_pattern)
        values (p_workspace_id, p_seat_id, v_member.id, v_start, v_end,
                'reserved', v_series_id, p_pattern);
        -- beyond-quota instances are skipped, not booked
        perform public.assert_member_quota(v_member.id, v_start);
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
