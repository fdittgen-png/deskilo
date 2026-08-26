-- SPDX-License-Identifier: 0BSD
-- #628 configurable SIMULTANEOUS reservations + #629 auto-validated
-- delete requests for admins/owners. APPLIED to the hosted reference
-- project and live-verified there.
--
-- ============================ #628 ============================
-- "One place at a time" (#412, migration 0079) was a constant. Three
-- call sites hard-coded it: enforce_one_place (0079/0083),
-- check_in_reservation's still-running-elsewhere guard (v4, 0113) and
-- kiosk_act's twin guards on the level and seat paths (v6, 0116). Some
-- workspaces legitimately want a member to hold two or three places at
-- once (a desk plus a meeting room, a coach plus their room).
--
-- The allowance is now resolved by ONE helper,
-- member_simultaneous_allowance, and all three call sites ask it:
--
--   1. members.max_simultaneous_reservations — the explicit per-member
--      permission (null = follow the workspace), sanity-bounded 1..20,
--      set through set_member_simultaneous_limit, modeled exactly on
--      set_member_reservation_limit (0044): owner/admin of that
--      workspace, never for themselves.
--   2. booking_rules.simultaneous_reservations — the workspace default.
--   3. absent or invalid at both levels → 1, today's behavior EXACTLY:
--      at allowance 1 `count(*) >= 1` is the old `exists` test and
--      every pinned refusal fires on the same input as before.
--
-- The two pinned substrings the client maps
-- ('you already have a reservation in that period',
--  'already checked in elsewhere') are preserved verbatim.
--
-- ============================ #629 ============================
-- validation_policies gains auto_validate_admin / auto_validate_owner
-- (both default false) and request_reservation_deletion v3 settles its
-- own event when the requester's role is auto-validated.
--
-- DESIGN NOTE — READ BEFORE GENERALIZING. This is a DELIBERATE,
-- owner-configured exception to the 0086 rule that nobody validates
-- their own event. Three fences keep it honest:
--   * it is scoped to reservation deletions ONLY — the lookup below
--     reads the workspace's own 'reservation_delete' policy row and
--     deliberately ignores the null fallback row, so switching it on
--     can never spill onto payments, expenses, role changes or joins;
--   * both booleans default FALSE, so nothing changes until an owner
--     turns one on in the validation-rules screen;
--   * the settled event carries payload.auto_validated = true, so the
--     feed and the audit trail can always tell a self-settled deletion
--     from a peer-reviewed one.
-- It must NEVER be generalized silently to other event types. Widening
-- it needs its own issue, its own migration and its own review.
--
-- Bodies are GENERATED from their latest prior definitions with only
-- the patches above:
--   check_in_reservation        v4 → v5   from 0113
--   kiosk_act                   v6 → v7   from 0116
--   request_reservation_deletion v2 → v3  from 0111
--   enforce_one_place           v1 → v2   from 0079 (rewritten: the
--                               exists test becomes a count test)

-- ---------------------------------------------------------------- #628
-- 1. The per-member permission. 1..20 is a sanity fence, not a policy:
-- a workspace wanting more has a data-entry bug, not a use case.
alter table public.members
  add column max_simultaneous_reservations int
  check (max_simultaneous_reservations between 1 and 20);

-- 2. The setter — set_member_reservation_limit (0044) with the column
-- and the bounds swapped, same authorization, same self-service ban.
create or replace function public.set_member_simultaneous_limit(
  p_member_id uuid, p_limit int
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_target public.members;
  v_caller public.members;
begin
  select * into v_target from public.members where id = p_member_id;
  if v_target.id is null then raise exception 'unknown member'; end if;
  select * into v_caller from public.members
    where workspace_id = v_target.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_caller.id is null then
    raise exception 'not an admin of this workspace';
  end if;
  if v_caller.id = v_target.id then
    -- governance, not self-service: nobody tunes their own allowance
    raise exception 'cannot set your own simultaneous limit';
  end if;
  if p_limit is not null and (p_limit < 1 or p_limit > 20) then
    raise exception 'limit must be between 1 and 20 (or null for the workspace default)';
  end if;
  update public.members set max_simultaneous_reservations = p_limit
    where id = p_member_id;
end;
$$;
revoke execute on function public.set_member_simultaneous_limit(uuid, int)
  from public, anon;

-- 3. THE allowance resolver — the single definition every enforcement
-- site below asks. Member override, else the workspace default, else 1.
-- "Invalid" is generous on purpose: the client writes a jsonb number,
-- but a hand-edited string of digits reads the same, and anything else
-- (null, text, 0, negative, absent) falls back to 1 rather than
-- accidentally opening the workspace up.
create or replace function public.member_simultaneous_allowance(
  p_member_id uuid
) returns int language plpgsql stable security definer
  set search_path = public as $$
declare
  v_override int;
  v_raw text;
  v_ws int;
begin
  select m.max_simultaneous_reservations,
         w.booking_rules->>'simultaneous_reservations'
    into v_override, v_raw
    from public.members m
    join public.workspaces w on w.id = m.workspace_id
   where m.id = p_member_id;
  if v_override is not null then
    return least(greatest(v_override, 1), 20);
  end if;
  if v_raw is not null and trim(v_raw) ~ '^[0-9]+$' then
    v_ws := trim(v_raw)::int;
    if v_ws >= 1 then return least(v_ws, 20); end if;
  end if;
  return 1;
end;
$$;
revoke execute on function public.member_simultaneous_allowance(uuid)
  from public, anon, authenticated;

-- 4. enforce_one_place v2 — the 0079 trigger, counting instead of
-- existence-testing. At allowance 1 the two are the same predicate.
create or replace function public.enforce_one_place()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_allowance int;
  v_overlaps int;
begin
  if new.status in ('reserved', 'checked_in') then
    v_allowance := public.member_simultaneous_allowance(new.member_id);
    select count(*) into v_overlaps from public.reservations r
      where r.member_id = new.member_id
        and r.id <> new.id
        and r.status in ('reserved', 'checked_in')
        and tstzrange(r.starts_at, r.ends_at)
            && tstzrange(new.starts_at, new.ends_at);
    if v_overlaps >= v_allowance then
      -- the client pins the leading substring; the count is context
      raise exception
        'you already have a reservation in that period (at most % at a time)',
        v_allowance;
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_one_place()
  from public, anon, authenticated;

-- 5. check_in_reservation v5 — the 0113 body, the still-running
-- guard counting against the allowance.
create or replace function public.check_in_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
  v_rules jsonb;
  v_tz text;
  v_gran text;
  v_leeway interval := interval '15 minutes';
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

  -- Presence window (0077 → #573). Day-based and hours granularity: the
  -- slot IS the working day, so any same-workspace-day arrival counts
  -- as presence. Minute grids: the leeway widens to one grid step.
  select w.booking_rules, w.timezone into v_rules, v_tz
    from public.workspaces w where w.id = v_res.workspace_id;
  v_gran := v_rules->>'granularity';
  if v_gran in ('minutes_5','minutes_15','minutes_30','minutes_60') then
    v_leeway := greatest(v_leeway,
      make_interval(mins => split_part(v_gran, '_', 2)::int));
  end if;
  if now() < v_res.starts_at - v_leeway
     and not (v_gran in ('half_day','full_day','hours')
              and (v_res.starts_at at time zone v_tz)::date
                  = (now() at time zone v_tz)::date) then
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
  -- ...but check-ins still RUNNING elsewhere mean the member is
  -- physically somewhere else. #628: how many "elsewhere" the member
  -- may hold is the configured allowance — at allowance 1 the count
  -- test below IS the historical `exists` test, unchanged.
  if (
    select count(*) from public.reservations r
    where r.member_id = v_res.member_id
      and r.id <> v_res.id
      and r.status = 'checked_in'
      and r.ends_at > now()
  ) >= public.member_simultaneous_allowance(v_res.member_id) then
    -- the client pins this substring
    raise exception 'already checked in elsewhere';
  end if;

  perform public.assert_workspace_open(v_res.workspace_id, now(), now() + interval '1 minute');
  update public.reservations
    set status = 'checked_in', checked_in_at = now()
    where id = p_reservation_id;
end;
$$;

-- 6. kiosk_act v7 — the 0116 body, the same allowance on BOTH the
-- level path and the seat path.
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
  v_rules jsonb;
  v_tz text;
  v_gran text;
  v_canon timestamptz;
  v_snapped boolean := false;
  v_starts timestamptz;
  v_ends timestamptz;
  v_attempt int;
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

  select w.booking_rules, w.timezone into v_rules, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  v_gran := v_rules->>'granularity';

  if p_action = 'check_out' then
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.status = 'checked_in'
        and (p_seat_id is null or r.seat_id = p_seat_id)
        and (p_level_id is null or r.level_id = p_level_id)
      order by r.checked_in_at desc limit 1;
    if v_res.id is null then raise exception 'not checked in'; end if;
    perform public.complete_check_out(v_res.id);
    return jsonb_build_object('action', 'check_out', 'reservation_id', v_res.id);
  end if;

  if p_action not in ('reserve', 'check_in') then
    raise exception 'unknown kiosk action';
  end if;
  if (p_seat_id is null) = (p_level_id is null)
     or p_starts_at is null or p_ends_at is null then
    raise exception 'seat or level, and window required';
  end if;

  v_starts := p_starts_at;
  v_ends := p_ends_at;
  -- #573: a day-based walk-up check-in books the SLOT the chosen end
  -- belongs to — the start snaps back, the member's chosen end stays.
  if p_action = 'check_in' then
    v_canon := public.canonical_walkup_start(
      p_workspace_id, p_starts_at, p_ends_at);
    if v_canon is not null and v_canon < v_starts then
      v_starts := v_canon;
      v_snapped := true;
    end if;
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
          and r.ends_at > now()
          -- #573: the 15-minute leeway (0077/#430) OR the reservation's
          -- own workspace day under day-based/hours granularity — being
          -- early on your own slot's day is presence.
          and (r.starts_at - interval '15 minutes' <= now()
               or (v_gran in ('half_day','full_day','hours')
                   and (r.starts_at at time zone v_tz)::date
                       = (now() at time zone v_tz)::date))
        order by r.starts_at limit 1;
      if v_res.id is not null then
        -- One place (#430, mirroring check_in_reservation): stale
        -- check-ins complete at their own end; still-running elsewhere
        -- refuses with the pinned substring once the #628
        -- allowance is reached.
        update public.reservations
          set status = 'completed', checked_out_at = ends_at
          where member_id = v_subject.id and id <> v_res.id
            and status = 'checked_in' and ends_at <= now();
        if (
          select count(*) from public.reservations r2
          where r2.member_id = v_subject.id and r2.id <> v_res.id
            and r2.status = 'checked_in' and r2.ends_at > now()
        ) >= public.member_simultaneous_allowance(v_subject.id) then
          raise exception 'already checked in elsewhere';
        end if;
        update public.reservations
          set status = 'checked_in', checked_in_at = now()
          where id = v_res.id;
        return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
      end if;
    end if;

    for v_attempt in 1..2 loop
      begin
        perform public.enforce_booking_rules(
          p_workspace_id, v_starts, v_ends, p_action = 'check_in');
        if public.level_has_conflict(p_level_id, v_starts, v_ends) then
          raise exception 'the level has reservations in that period';
        end if;

        insert into public.reservations
          (workspace_id, level_id, member_id, starts_at, ends_at, status, checked_in_at)
        values (
          p_workspace_id, p_level_id, v_subject.id, v_starts, v_ends,
          case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
          case when p_action = 'check_in' then now() end
        )
        returning id into v_id;
        exit;
      exception when others then
        if v_attempt = 1 and v_snapped
           and v_starts < now() and now() < v_ends then
          v_starts := now();
        else
          raise;
        end if;
      end;
    end loop;
    perform public.assert_member_quota(v_subject.id, v_starts);
    return jsonb_build_object('action', p_action, 'reservation_id', v_id);
  end if;

  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;
  if v_seat.id is null then raise exception 'unknown seat'; end if;

  if p_action = 'check_in' then
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.seat_id = p_seat_id
        and r.status = 'reserved'
        and r.ends_at > now()
        -- #573: leeway OR same workspace day, as on the level path.
        and (r.starts_at - interval '15 minutes' <= now()
             or (v_gran in ('half_day','full_day','hours')
                 and (r.starts_at at time zone v_tz)::date
                     = (now() at time zone v_tz)::date))
      order by r.starts_at limit 1;
    if v_res.id is not null then
      -- One place (#430) + the #628 allowance: same guards as the
      -- level path.
      update public.reservations
        set status = 'completed', checked_out_at = ends_at
        where member_id = v_subject.id and id <> v_res.id
          and status = 'checked_in' and ends_at <= now();
      if (
        select count(*) from public.reservations r2
        where r2.member_id = v_subject.id and r2.id <> v_res.id
          and r2.status = 'checked_in' and r2.ends_at > now()
      ) >= public.member_simultaneous_allowance(v_subject.id) then
        raise exception 'already checked in elsewhere';
      end if;
      update public.reservations
        set status = 'checked_in', checked_in_at = now()
        where id = v_res.id;
      return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
    end if;
  end if;

  for v_attempt in 1..2 loop
    begin
      perform public.enforce_booking_rules(
        p_workspace_id, v_starts, v_ends, p_action = 'check_in');
      if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
                   coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
         && tstzrange(v_starts, v_ends)
         and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
        raise exception 'seat is blocked in that period';
      end if;
      -- 0059: the seat's DESK reserved as a whole blocks the walk-up too.
      if exists (
        select 1 from public.reservations r
        where r.desk_id = v_seat.desk_id
          and r.status in ('reserved','checked_in')
          and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
      ) then
        raise exception 'desk is reserved as a whole in that period';
      end if;
      select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
      if exists (
        select 1 from public.reservations r
        where r.office_id = v_office_id
          and r.status in ('reserved','checked_in')
          and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
      ) then
        raise exception 'office is reserved as a whole in that period';
      end if;
      if exists (
        select 1 from public.reservations r
        where r.level_id = (select o.level_id from public.offices o where o.id = v_office_id)
          and r.status in ('reserved','checked_in')
          and tstzrange(r.starts_at, r.ends_at) && tstzrange(v_starts, v_ends)
      ) then
        raise exception 'level is reserved as a whole in that period';
      end if;

      insert into public.reservations
        (workspace_id, seat_id, member_id, starts_at, ends_at, status, checked_in_at)
      values (
        p_workspace_id, p_seat_id, v_subject.id, v_starts, v_ends,
        case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
        case when p_action = 'check_in' then now() end
      )
      returning id into v_id;
      exit;
    exception when others then
      if v_attempt = 1 and v_snapped
         and v_starts < now() and now() < v_ends then
        v_starts := now();
      else
        raise;
      end if;
    end;
  end loop;
  perform public.assert_member_quota(v_subject.id, v_starts);
  return jsonb_build_object('action', p_action, 'reservation_id', v_id);
end;
$$;

-- ---------------------------------------------------------------- #629
-- 7. The two auto-validation switches. Both default false: an existing
-- workspace behaves exactly as before this migration.
alter table public.validation_policies
  add column auto_validate_admin boolean not null default false,
  add column auto_validate_owner boolean not null default false;

-- 8. request_reservation_deletion v3 — the 0111 body plus the
-- auto-validation branch. Read the DESIGN NOTE at the top of this file
-- before touching it.
create or replace function public.request_reservation_deletion(
  p_reservation_id uuid, p_reason text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_member public.members;
  v_id uuid;
  v_policy public.validation_policies;
  v_auto boolean := false;
begin
  select * into v_res from public.reservations where id = p_reservation_id;
  if v_res.id is null then raise exception 'unknown reservation'; end if;
  select * into v_member from public.members
    where workspace_id = v_res.workspace_id and user_id = auth.uid()
      and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if v_res.member_id <> v_member.id then
    raise exception 'only your own reservation';
  end if;
  if v_res.status not in ('reserved','checked_in','completed') then
    raise exception 'nothing to delete';
  end if;
  if v_res.status = 'reserved' and v_res.starts_at > now() then
    raise exception 'cancel directly — this booking has not started';
  end if;
  -- #629 — the owner-configured auto-validation exception, decided
  -- BEFORE the insert. Scoped to the workspace's OWN reservation_delete
  -- policy row: the null fallback row is deliberately NOT consulted, so
  -- the exception can never leak to another event type.
  select * into v_policy from public.validation_policies
    where workspace_id = v_res.workspace_id
      and event_type = 'reservation_delete';
  v_auto := (v_member.is_owner and coalesce(v_policy.auto_validate_owner, false))
         or (v_member.is_admin and coalesce(v_policy.auto_validate_admin, false));

  -- #562: supersede, don't refuse — a fresh PENDING insert re-triggers
  -- the validator notification (an auto-validated request never asks).
  update public.events
     set status = 'expired'
   where type = 'reservation_delete' and status = 'pending'
     and (payload->>'reservation_id')::uuid = p_reservation_id;

  -- Auto-validated requests are born SETTLED. Inserting them pending
  -- and confirming a statement later would emit a real "please
  -- validate" ping (realtime + the pending push mirror) for something
  -- already decided — validators chasing a closed question. The audit
  -- keeps everything that matters: the event, its actor, a system
  -- decision row and the payload flag.
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values (
    v_res.workspace_id, 'reservation_delete', 'submitted',
    v_member.id, v_member.id,
    jsonb_build_object(
      'reservation_id', v_res.id,
      'starts_at', v_res.starts_at,
      'ends_at', v_res.ends_at,
      'was_checked_in', v_res.status <> 'reserved',
      'reason', left(coalesce(p_reason, ''), 300)
    ) || case when v_auto
           then jsonb_build_object('auto_validated', true)
           else '{}'::jsonb end,
    case when v_auto then 'confirmed' else 'pending' end,
    case when v_auto then now() end
  )
  returning id into v_id;

  if v_auto then
    -- The 0017 idiom for a decision no human made: member_id null,
    -- decided_by_system true. Attributing it to the requester would
    -- forge exactly the peer review that 0086 forbids — the rule
    -- settled this, not a colleague.
    insert into public.event_decisions
      (event_id, member_id, decision, decided_by_system)
      values (v_id, null, 'accept', true);
    -- Same effect as respond_to_event's reservation_delete confirm
    -- branch (0101): the booking goes away.
    update public.reservations set status = 'cancelled'
      where id = v_res.id
        and status in ('reserved','checked_in','completed');
  end if;
  return v_id;
end;
$$;

revoke execute on function
  public.request_reservation_deletion(uuid, text) from public, anon;
