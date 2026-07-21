-- SPDX-License-Identifier: 0BSD
-- Whole-level reservations. NOT YET applied to the hosted reference
-- project — the orchestrator applies it after review.
--
-- A level (floor) can be reserved/checked into as a whole, like an
-- office: the owner marks a level bookable and prices it per half-day.
-- WHO may book one for themselves is a per-member grant
-- (members.can_reserve_level, owner/admin-set, never self — the 0044
-- reservation-limit shape). Owners always assign level reservations to
-- members; admins do when the workspace enables the adminLevelAssign
-- feature (the adminSeatBlocking delegation idiom). The whole module
-- hides behind the levelBooking feature flag (default OFF).
--
-- Billing: a level reservation consumes half-day quota like any other
-- reservation, PLUS the level's price per distinct half-day — the
-- accessory-supplement shape, summed in member_statement v5.

-- 1. Level bookability + price.
alter table public.levels
  add column if not exists bookable_as_whole boolean not null default false,
  add column if not exists price_cents int not null default 0
    check (price_cents >= 0);

-- 2. Per-member grant.
alter table public.members
  add column if not exists can_reserve_level boolean not null default false;

create or replace function public.set_member_level_permission(
  p_member_id uuid, p_allowed boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_subject public.members;
  v_actor public.members;
begin
  select * into v_subject from public.members where id = p_member_id;
  if v_subject.id is null then raise exception 'unknown member'; end if;
  select * into v_actor from public.members
    where workspace_id = v_subject.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if v_actor.id = v_subject.id then
    raise exception 'cannot change your own level permission';
  end if;
  update public.members set can_reserve_level = p_allowed where id = p_member_id;
end;
$$;
revoke execute on function public.set_member_level_permission(uuid, boolean)
  from public, anon;

-- 3. Reservations may target a level: exactly one of seat/office/level.
alter table public.reservations
  add column if not exists level_id uuid references public.levels(id)
    on delete restrict;
alter table public.reservations drop constraint reservations_one_target;
alter table public.reservations add constraint reservations_one_target check (
  (case when seat_id is null then 0 else 1 end
   + case when office_id is null then 0 else 1 end
   + case when level_id is null then 0 else 1 end) = 1
);
alter table public.reservations add constraint reservations_level_no_overlap
  exclude using gist (
    level_id with =,
    tstzrange(starts_at, ends_at) with &&
  ) where (level_id is not null and status in ('reserved','checked_in'));

-- Helper: is the levelBooking feature on for this workspace? (Server
-- mirror of the client registry default: OFF unless explicitly true.)
create or replace function public.level_booking_enabled(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(w.feature_flags -> 'levelBooking' = to_jsonb(true), false)
    from public.workspaces w where w.id = p_workspace_id;
$$;
revoke execute on function public.level_booking_enabled(uuid) from public, anon;

-- Helper: any seat/office/level reservation overlapping the window
-- anywhere on this level? Used by the level path of every booking RPC.
create or replace function public.level_has_conflict(
  p_level_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.reservations r
    left join public.seats s on s.id = r.seat_id
    left join public.desks d on d.id = s.desk_id
    left join public.offices o on o.id = coalesce(r.office_id, d.office_id)
    where r.status in ('reserved','checked_in')
      and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
      and (r.level_id = p_level_id or o.level_id = p_level_id)
  );
$$;
revoke execute on function public.level_has_conflict(uuid, timestamptz, timestamptz)
  from public, anon;

-- 4. create_reservation v4: 0031 body + the level target. The seat and
-- office paths additionally refuse when their level is reserved whole.
create or replace function public.create_reservation(
  p_workspace_id uuid,
  p_seat_id uuid,
  p_office_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_check_in boolean default false,
  p_level_id uuid default null
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
      + case when p_office_id is null then 0 else 1 end
      + case when p_level_id is null then 0 else 1 end) <> 1 then
    raise exception 'exactly one of seat, office or level required';
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
  elsif p_office_id is not null then
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
    if not v_member.can_reserve_level then
      -- the client pins this substring
      raise exception 'not allowed to reserve a level';
    end if;
    if public.level_has_conflict(p_level_id, p_starts_at, p_ends_at) then
      raise exception 'the level has reservations in that period';
    end if;
  end if;

  insert into public.reservations
    (workspace_id, seat_id, office_id, level_id, member_id, starts_at, ends_at,
     status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, p_office_id, p_level_id, v_member.id,
    p_starts_at, p_ends_at,
    case when p_check_in then 'checked_in' else 'reserved' end,
    case when p_check_in then now() end
  )
  returning id into v_id;
  perform public.assert_member_quota(v_member.id, p_starts_at);
  return v_id;
end;
$$;

-- 5. admin_create_reservation_for v3: 0031 body + optional level target.
-- Owners assign level reservations freely; admins need the
-- adminLevelAssign feature. The SUBJECT needs no personal grant — the
-- assignment right belongs to the actor. Confirmation protocol
-- unchanged: the created event parks pending for the subject.
create or replace function public.admin_create_reservation_for(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_seat_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_level_id uuid default null
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
  if (p_seat_id is null) = (p_level_id is null) then
    raise exception 'exactly one of seat or level required';
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at);

  if p_level_id is not null then
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not v_actor.is_owner and not coalesce(
      (select w.feature_flags -> 'adminLevelAssign' = to_jsonb(true)
         from public.workspaces w where w.id = p_workspace_id), false) then
      raise exception 'admins may not assign level reservations here';
    end if;
    if not exists (
      select 1 from public.levels l
      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole
    ) then
      raise exception 'level not bookable as a whole';
    end if;
    if public.level_has_conflict(p_level_id, p_starts_at, p_ends_at) then
      raise exception 'the level has reservations in that period';
    end if;
  else
    perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);
  end if;

  insert into public.reservations
    (workspace_id, seat_id, level_id, member_id, starts_at, ends_at, status)
  values (p_workspace_id, p_seat_id, p_level_id, p_subject_member_id,
          p_starts_at, p_ends_at, 'reserved')
  returning id into v_res_id;
  perform public.assert_member_quota(p_subject_member_id, p_starts_at);

  update public.events set actor_member_id = v_actor.id, status = 'pending'
    where reservation_id = v_res_id and action = 'created';

  select id into v_event_id from public.events
    where reservation_id = v_res_id and action = 'created';
  return v_event_id;
end;
$$;

-- 6. kiosk_act v2: the wall tablet books a LEVEL too — the member taps
-- their RFID/NFC card or scans/types the badge exactly like for a seat.
-- Signature grows a parameter → drop-and-recreate.
drop function if exists public.kiosk_act(uuid, text, text, uuid, timestamptz, timestamptz);
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
          and r.starts_at <= now() and r.ends_at > now()
        limit 1;
      if v_res.id is not null then
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
        and r.starts_at <= now() and r.ends_at > now()
      limit 1;
    if v_res.id is not null then
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
revoke execute on function public.kiosk_act(uuid, text, text, uuid, timestamptz, timestamptz, uuid)
  from public, anon;

-- 7. member_statement v5: v4 (0041) verbatim + the level price — the
-- accessory-supplement shape: price × distinct (level, day, slot).
-- Additions marked "#level". Balance subtracts the level supplement.
create or replace function public.member_statement(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_caller_is_admin boolean;
  v_band public.fee_bands;
  v_tz text;
  v_open int[];
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_month_first date;
  v_open_days int;
  v_pct int;
  v_included int;
  v_used int;
  v_base int := 0;
  v_overage int := 0;
  v_overage_rate int := 0;
  v_credits int;
  v_extra_half_days int := 0;
  v_supp_on boolean := false;
  v_supp_since timestamptz;
  v_supplement int := 0;
  v_granted int := 0;
  v_cap int := 0;
  v_remaining int := 0;
  -- #level
  v_level_supplement int := 0;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  v_caller_is_admin := public.is_admin_of(v_member.workspace_id);
  if not v_caller_is_admin and not exists (
    select 1 from public.members m
    where m.id = p_member_id and m.user_id = auth.uid()
  ) then
    raise exception 'not your statement';
  end if;

  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5]),
         coalesce(feature_flags -> 'accessorySupplements' = to_jsonb(true), false),
         accessory_supplements_since
    into v_tz, v_open, v_supp_on, v_supp_since
    from public.workspaces where id = v_member.workspace_id;
  v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
  v_month_first := to_date(p_period || '-01', 'YYYY-MM-DD');

  v_pct := coalesce(v_member.subscription_pct, 100);
  select * into v_band from public.fee_bands
    where workspace_id = v_member.workspace_id
      and from_pct < v_pct and v_pct <= to_pct;
  if v_band.id is not null then
    v_base := v_band.fee_cents;
    v_overage_rate := v_band.overage_fee_cents;
  end if;

  select count(*) into v_open_days
  from generate_series(v_month_first,
                       (v_month_first + interval '1 month' - interval '1 day')::date,
                       interval '1 day') d
  where extract(isodow from d)::int = any(v_open)
    and not exists (select 1 from public.closure_days c
                     where c.workspace_id = v_member.workspace_id and c.day = d::date);
  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;

  select count(distinct (date_trunc('day', r.starts_at at time zone v_tz)::date, s.slot))
  into v_used
  from public.reservations r
  cross join lateral (
    select case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  v_extra_half_days := greatest(0, v_used - v_included);
  v_overage := v_extra_half_days * v_overage_rate;

  select coalesce(sum(half_days), 0) into v_granted from public.quota_extensions
    where member_id = p_member_id and period = p_period;
  v_cap := v_included + v_granted;
  v_remaining := greatest(0, v_cap - v_used);

  if v_supp_on and v_supp_since is not null then
    select coalesce(sum(seat_supp.total_cents), 0) into v_supplement
    from (
      select distinct
        r.seat_id,
        date_trunc('day', r.starts_at at time zone v_tz)::date as day,
        case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
      from public.reservations r
      where r.member_id = p_member_id
        and r.seat_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= greatest(v_period_start, v_supp_since)
        and r.starts_at < v_period_end
    ) hd
    join (
      select sa.seat_id, sum(a.supplement_cents)::int as total_cents
      from public.seat_accessories sa
      join public.accessories a on a.id = sa.accessory_id
      where a.active and a.supplement_cents > 0
      group by sa.seat_id
    ) seat_supp on seat_supp.seat_id = hd.seat_id;
  end if;

  -- #level: price × distinct half-days per reserved level. Priced level
  -- reservations only exist while the feature is on, so no extra gate.
  select coalesce(sum(l.price_cents), 0) into v_level_supplement
  from (
    select distinct
      r.level_id,
      date_trunc('day', r.starts_at at time zone v_tz)::date as day,
      case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
    from public.reservations r
    where r.member_id = p_member_id
      and r.level_id is not null
      and r.status in ('reserved','checked_in','completed')
      and r.starts_at >= v_period_start and r.starts_at < v_period_end
  ) lh
  join public.levels l on l.id = lh.level_id;

  select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)
  into v_credits
  from public.ledger_entries
  where member_id = p_member_id and period = p_period;

  return jsonb_build_object(
    'period', p_period,
    'subscription_pct', v_pct,
    'fee_cents', v_base,
    'included_half_days', v_included,
    'open_days', v_open_days,
    'used_half_days', v_used,
    'extra_half_days', v_extra_half_days,
    'overage_cents', v_overage,
    'accessory_supplement_cents', v_supplement,
    -- #level
    'level_supplement_cents', v_level_supplement,
    'credits_cents', v_credits,
    'balance_cents',
      v_credits - v_base - v_overage - v_supplement - v_level_supplement,
    'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
    'overage_rate_cents', v_overage_rate,
    'granted_half_days', v_granted,
    'remaining_half_days', v_remaining
  );
end;
$$;
