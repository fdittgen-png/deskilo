-- SPDX-License-Identifier: MIT
-- DesKilo seat blocking from the Plan screen (issue #161). NOT YET applied
-- to the hosted reference project.
--
-- The owner (always) — or an admin, when the owner switched the
-- 'adminSeatBlocking' feature on (#146 registry; key mirrors the Dart
-- WorkspaceFeature.adminSeatBlocking.dbKey) — sets or clears a seat's
-- maintenance block (seats.blocked_from / blocked_to from migration 0003).
-- NULL/NULL clears the block; blocked_from set + blocked_to NULL blocks
-- open-endedly, matching Seat.isBlockedAt's open-ended semantics.
--
-- create_reservation has rejected blocked seats since migration 0005 (kept
-- in 0006); admin_create_reservation_for (0007) and create_series (0013)
-- did NOT — they are re-created below with only the blocked-seat guard
-- added, bodies otherwise copied verbatim from those migrations.

-- Shared blocked-seat guard (mirrors assert_workspace_open from 0013 and
-- the inline check create_reservation carries since 0005): raises when the
-- seat is blocked for ANY part of [p_starts_at, p_ends_at). blocked_from
-- NULL = since forever, blocked_to NULL = forever; both NULL = not blocked.
create or replace function public.assert_seat_not_blocked(
  p_seat_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns void language plpgsql stable security definer set search_path = public as $$
declare v_seat public.seats;
begin
  select * into v_seat from public.seats where id = p_seat_id;
  if v_seat.id is null then raise exception 'unknown seat'; end if;
  if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
               coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
     && tstzrange(p_starts_at, p_ends_at)
     and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
    raise exception 'seat is blocked in that period';
  end if;
end;
$$;
revoke execute on function public.assert_seat_not_blocked(uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- Sets (or, with NULL/NULL, clears) a seat's maintenance block. Permitted
-- for the workspace owner, or for an admin when the workspace's
-- feature_flags carry 'adminSeatBlocking' = true (absent key = the
-- registry default = OFF).
create or replace function public.set_seat_block(
  p_seat_id uuid,
  p_blocked_from timestamptz,
  p_blocked_to timestamptz
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_workspace_id uuid;
begin
  select workspace_id into v_workspace_id
    from public.seats where id = p_seat_id;
  if v_workspace_id is null then raise exception 'unknown seat'; end if;
  if p_blocked_from is not null and p_blocked_to is not null
     and p_blocked_to <= p_blocked_from then
    raise exception 'blocked_to must be after blocked_from';
  end if;
  if not (
    public.is_owner_of(v_workspace_id)
    or (
      public.is_admin_of(v_workspace_id)
      -- jsonb equality: true only for a stored JSON boolean true — junk
      -- values count as OFF, like the client's resolveEnabledFeatures.
      and coalesce((
        select w.feature_flags->'adminSeatBlocking' = 'true'::jsonb
        from public.workspaces w where w.id = v_workspace_id
      ), false)
    )
  ) then
    raise exception 'only the owner, or an admin with the adminSeatBlocking feature, may block seats';
  end if;
  update public.seats
    set blocked_from = p_blocked_from,
        blocked_to = p_blocked_to
    where id = p_seat_id;
end;
$$;
grant execute on function public.set_seat_block(uuid, timestamptz, timestamptz) to authenticated;
revoke execute on function public.set_seat_block(uuid, timestamptz, timestamptz) from public, anon;

-- admin_create_reservation_for: body copied verbatim from migration 0007;
-- the only change is the assert_seat_not_blocked guard next to
-- enforce_booking_rules.
create or replace function public.admin_create_reservation_for(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_seat_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_res_id uuid;
  v_event_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not exists (
    select 1 from public.members
    where id = p_subject_member_id and workspace_id = p_workspace_id and status = 'active'
  ) then raise exception 'unknown subject member'; end if;
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at);
  perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);

  -- tentative reservation: blocks the slot (exclusion constraint applies)
  insert into public.reservations
    (workspace_id, seat_id, member_id, starts_at, ends_at, status)
  values (p_workspace_id, p_seat_id, p_subject_member_id, p_starts_at, p_ends_at, 'reserved')
  returning id into v_res_id;

  -- the trigger just logged an 'applied' created event attributed to the
  -- subject; repoint that audit line to the actor and park the decision
  update public.events set actor_member_id = v_actor.id, status = 'pending'
    where reservation_id = v_res_id and action = 'created';

  select id into v_event_id from public.events
    where reservation_id = v_res_id and action = 'created';
  return v_event_id;
end;
$$;

-- create_series: body copied verbatim from migration 0013; the only change
-- is the assert_seat_not_blocked guard next to assert_workspace_open, so
-- instances on a blocked seat land in the skipped report exactly like
-- closed days and seat conflicts.
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
