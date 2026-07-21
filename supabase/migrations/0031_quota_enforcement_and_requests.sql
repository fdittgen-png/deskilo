-- SPDX-License-Identifier: 0BSD
-- Quota enforcement + quota-extension requests. Applied to the hosted
-- reference project on 2026-07-18.
--
-- Reservations must correspond to the subscription: a member's half-days
-- per month are capped at the entitlement ceil(open_days x 2 x pct / 100)
-- (ADR 0008, same formula as member_statement) PLUS any confirmed
-- quota extensions. A member who needs more requests a number of extra
-- half-days; owners/admins validate through the events spine, so the
-- owner's validation_policies rules (required_count = how many admins
-- must approve, eligible admins, owner_required) apply unchanged.
-- Approved extra half-days still bill at the band's overage rate —
-- an extension is permission to consume, not free usage.
--
-- Unanswered requests auto-EXPIRE after 7 days (action 'submitted'
-- follows the sweep's destructive/costly path — extra quota is never
-- granted silently).

-- 1. confirmed extensions, one row per approved request
create table public.quota_extensions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  period text not null check (period ~ '^\d{4}-\d{2}$'),
  half_days int not null check (half_days between 1 and 100),
  event_id uuid references public.events(id),
  created_at timestamptz not null default now()
);
create index quota_extensions_member_period_idx
  on public.quota_extensions (member_id, period);

alter table public.quota_extensions enable row level security;
-- the member sees their own extensions; admins/owners see all. No write
-- policies on purpose — rows are created by respond_to_event on confirm.
create policy quota_extensions_select on public.quota_extensions
  for select using (
    public.is_admin_of(workspace_id)
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );

-- 2. the request travels the events spine as its own type
alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check
  check (type in ('reservation','payment','expense','adjustment','service_charge','quota'));

-- 3. a member requests N extra half-days for a period
create or replace function public.request_quota_extension(
  p_workspace_id uuid, p_period text, p_half_days int
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_member public.members;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_member from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if p_period !~ '^\d{4}-\d{2}$' then raise exception 'period must be YYYY-MM'; end if;
  if p_half_days is null or p_half_days < 1 or p_half_days > 100 then
    raise exception 'half_days must be between 1 and 100';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'quota', 'submitted', v_member.id, v_member.id,
    jsonb_build_object('period', p_period, 'half_days', p_half_days),
    'pending'
  )
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.request_quota_extension(uuid, text, int) from public, anon;

-- 4. the entitlement guard: recount the member's month AFTER an insert;
-- violation raises and rolls the booking back. Usage counting mirrors
-- member_statement v3 exactly (distinct local day + am/pm start slot,
-- statuses reserved/checked_in/completed).
create or replace function public.assert_member_quota(
  p_member_id uuid, p_at timestamptz
) returns void language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_tz text;
  v_open int[];
  v_pct int;
  v_period text;
  v_month_first date;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_open_days int;
  v_included int;
  v_ext int;
  v_used int;
begin
  select * into v_member from public.members where id = p_member_id;
  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5])
    into v_tz, v_open
    from public.workspaces where id = v_member.workspace_id;

  v_period := to_char(p_at at time zone v_tz, 'YYYY-MM');
  v_month_first := to_date(v_period || '-01', 'YYYY-MM-DD');
  v_period_start := to_timestamp(v_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(v_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;

  v_pct := coalesce(v_member.subscription_pct, 100);
  select count(*) into v_open_days
  from generate_series(v_month_first,
                       (v_month_first + interval '1 month' - interval '1 day')::date,
                       interval '1 day') d
  where extract(isodow from d)::int = any(v_open)
    and not exists (select 1 from public.closure_days c
                     where c.workspace_id = v_member.workspace_id and c.day = d::date);
  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;

  select coalesce(sum(half_days), 0) into v_ext from public.quota_extensions
    where member_id = p_member_id and period = v_period;

  select count(distinct (date_trunc('day', r.starts_at at time zone v_tz)::date, s.slot))
  into v_used
  from public.reservations r
  cross join lateral (
    select case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  if v_used > v_included + v_ext then
    -- the client pins the substring 'half-day quota' of this message
    raise exception 'half-day quota exceeded — request additional half-days';
  end if;
end;
$$;
revoke execute on function public.assert_member_quota(uuid, timestamptz) from public, anon, authenticated;

-- 5. create_reservation: body = 0026 verbatim + the quota guard after the
-- insert (walk-ups included — beyond-quota presence needs an extension
-- like any other booking).
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
  perform public.assert_member_quota(v_member.id, p_starts_at);
  return v_id;
end;
$$;

-- 6. admin_create_reservation_for: body = 0021 verbatim + the quota guard
-- for the SUBJECT after the insert.
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
  perform public.assert_member_quota(p_subject_member_id, p_starts_at);

  -- the trigger just logged an 'applied' created event attributed to the
  -- subject; repoint that audit line to the actor and park the decision
  update public.events set actor_member_id = v_actor.id, status = 'pending'
    where reservation_id = v_res_id and action = 'created';

  select id into v_event_id from public.events
    where reservation_id = v_res_id and action = 'created';
  return v_event_id;
end;
$$;

-- 7. create_series: body = 0021 verbatim + the quota guard inside the
-- per-instance block — instances beyond the quota land in the skipped
-- report exactly like closed days, blocked seats and seat conflicts.
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

-- 8. respond_to_event: body = 0017 verbatim + the quota apply branch —
-- a confirmed request materializes as a quota_extensions row.
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_caller public.members;
  v_policy record;
  v_subject_decides boolean;
  v_in_pool boolean;
  v_pool_size int;
  v_required int;
  v_accepts int;
  v_subject_ok boolean;
  v_owner_ok boolean;
begin
  select e.* into v_event from public.events e where e.id = p_event_id;
  if v_event.id is null then raise exception 'unknown event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  select m.* into v_caller from public.members m
    where m.workspace_id = v_event.workspace_id and m.user_id = auth.uid()
      and m.status = 'active';
  if v_caller.id is null then raise exception 'not a member'; end if;
  if exists (select 1 from public.event_decisions d
              where d.event_id = p_event_id and d.member_id = v_caller.id) then
    raise exception 'you already decided this event';
  end if;

  select * into v_policy from public.validation_policies
    where workspace_id = v_event.workspace_id and event_type = v_event.type;
  if v_policy is null then
    select * into v_policy from public.validation_policies
      where workspace_id = v_event.workspace_id and event_type is null;
  end if;
  if v_policy is null then
    -- pre-0017 behavior
    select null::uuid as id, v_event.workspace_id as workspace_id,
           null::text as event_type, 1 as required_count,
           true as admins_may_validate, '{}'::uuid[] as eligible_admin_ids,
           false as owner_required
      into v_policy;
  end if;

  -- admin-initiated events are accepted by their subject; self-initiated
  -- money events need validators
  v_subject_decides := v_event.type = 'reservation'
    or (v_event.type in ('payment','service_charge')
        and v_event.actor_member_id <> v_event.subject_member_id);

  -- validator pool: owners always; admins per policy; never the actor or
  -- subject. #107 escape hatch: an actor-admin alone in the pool may
  -- self-decide.
  select count(*) into v_pool_size from public.members m
    where m.workspace_id = v_event.workspace_id and m.status = 'active'
      and m.id not in (v_event.actor_member_id, v_event.subject_member_id)
      and (m.is_owner or (m.is_admin and v_policy.admins_may_validate
           and (cardinality(v_policy.eligible_admin_ids) = 0
                or m.id = any(v_policy.eligible_admin_ids))));

  -- the #107 escape hatch lifts BOTH exclusions on admin-decided events
  -- (a solo admin's own expense makes them actor AND subject); on
  -- subject-decides events the subject stays out of the pool — their
  -- mandatory accept is counted separately below
  v_in_pool := (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate
                and (cardinality(v_policy.eligible_admin_ids) = 0
                     or v_caller.id = any(v_policy.eligible_admin_ids))))
    and (v_caller.id <> v_event.subject_member_id
         or (not v_subject_decides and v_pool_size = 0))
    and (v_caller.id <> v_event.actor_member_id or v_pool_size = 0);
  if v_pool_size = 0 and (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then
    -- solo-admin workspaces: the pool collapses to the actor (#107)
    v_pool_size := 1;
  end if;

  if v_subject_decides and v_caller.id = v_event.subject_member_id then
    null; -- the subject's decision is always admissible (and mandatory)
  elsif v_in_pool then
    null;
  else
    raise exception 'you are not an eligible validator for this event';
  end if;

  insert into public.event_decisions (event_id, member_id, decision)
  values (p_event_id, v_caller.id, case when p_accept then 'accept' else 'reject' end);

  if not p_accept then
    update public.events set status = 'rejected', decided_at = now()
      where id = p_event_id;
    if v_event.reservation_id is not null then
      update public.reservations set status = 'cancelled'
        where id = v_event.reservation_id and status in ('reserved','checked_in');
    end if;
    return;
  end if;

  -- confirmation check: enough accepts, subject on board, owner on board
  select count(*) into v_accepts from public.event_decisions
    where event_id = p_event_id and decision = 'accept';
  v_required := greatest(1, least(v_policy.required_count,
    v_pool_size + case when v_subject_decides then 1 else 0 end));
  v_subject_ok := not v_subject_decides or exists (
    select 1 from public.event_decisions d
    where d.event_id = p_event_id and d.decision = 'accept'
      and d.member_id = v_event.subject_member_id);
  v_owner_ok := not v_policy.owner_required or exists (
    select 1 from public.event_decisions d
    join public.members m on m.id = d.member_id
    where d.event_id = p_event_id and d.decision = 'accept' and m.is_owner);

  if v_accepts >= v_required and v_subject_ok and v_owner_ok then
    update public.events set status = 'confirmed', decided_at = now()
      where id = p_event_id;

    if v_event.type in ('payment','expense') then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'credit',
        case when v_event.type = 'payment' then 'payment' else 'expense' end,
        (v_event.payload->>'amount_cents')::int,
        coalesce(v_event.payload->>'note', ''),
        to_char(now(), 'YYYY-MM'),
        v_event.id
      );
    elsif v_event.type = 'service_charge' then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id
      );
    elsif v_event.type = 'quota' then
      -- the granted extension raises the member's cap for that period;
      -- consumption beyond the base entitlement still bills at the
      -- band's overage rate (member_statement is unchanged)
      insert into public.quota_extensions
        (workspace_id, member_id, period, half_days, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id,
        v_event.payload->>'period',
        (v_event.payload->>'half_days')::int,
        v_event.id
      );
    end if;
  end if;
end;
$$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
