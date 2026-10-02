-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0335 (#1920) -- the history the capacity KPI needs, recorded where it
-- is written.
--
-- capacity.seat_utilisation (0333) read today's plan, today's opening
-- hours and today's seat blocks for every period, so a past month changed
-- whenever a seat moved. Four append-only facts, captured by triggers at
-- the actual writers, make a past period explainable:
--   * analytics_history          -- when a workspace's history begins.
--   * seat_history               -- each seat's desk/room/level and block,
--                                   with the interval it held (no FK: a
--                                   deleted seat keeps the time it existed).
--   * opening_hours_history      -- the open weekdays and hours, per interval.
--   * reservation_target_history -- what each reservation booked, as booked;
--                                   a plan delete detaches the reservation
--                                   (0115), this keeps where it was.
-- Business records stay the authority; nothing is rewritten. Existing
-- workspaces start their history NOW: earlier time is unknown, is not
-- filled in with today's plan, and the KPI says so (`history_since`).
--
-- The KPI stays a direct server-side aggregate over the whole authorized
-- scope (no REST page can truncate it), so a late cancellation or a
-- correction counts on the next read: there is no persisted aggregate to
-- refresh, back-fill or invalidate.

-- ------------------------------------------------------------ the facts
-- When the history of a workspace begins. Before it, nothing is known:
-- the KPI counts only from here and says so.
create table if not exists public.analytics_history (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  since timestamptz not null default now()
);
select public.ensure_system_columns('analytics_history');

-- Each seat's placement and block, with the interval it held. No foreign
-- key to seats: a deleted seat keeps the time it existed.
create table if not exists public.seat_history (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  seat_id uuid not null,
  desk_id uuid not null,
  office_id uuid not null,
  level_id uuid not null,
  blocked_from timestamptz,
  blocked_to timestamptz,
  valid tstzrange not null,
  constraint seat_history_one_at_a_time
    exclude using gist (seat_id with =, valid with &&)
);
select public.ensure_system_columns('seat_history');
create index if not exists seat_history_by_workspace
  on public.seat_history using gist (workspace_id, valid);

-- The opening days and hours, with the interval they held.
create table if not exists public.opening_hours_history (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  open_weekdays int[] not null,
  work_start_minutes int not null,
  work_end_minutes int not null,
  valid tstzrange not null,
  constraint opening_hours_history_one_at_a_time
    exclude using gist (workspace_id with =, valid with &&)
);
select public.ensure_system_columns('opening_hours_history');

-- What each reservation booked, as booked: a plan delete detaches the
-- reservation from its place (0115); this keeps where it was.
create table if not exists public.reservation_target_history (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  seat_id uuid,
  desk_id uuid,
  office_id uuid,
  level_id uuid,
  recorded_at timestamptz not null default now(),
  constraint reservation_target_history_one_target
    check (num_nonnulls(seat_id, desk_id, office_id, level_id) = 1)
);
select public.ensure_system_columns('reservation_target_history');
create index if not exists reservation_target_history_latest
  on public.reservation_target_history (reservation_id, recorded_at desc);

-- No client reads or writes these; the KPI reads them as definer.
alter table public.analytics_history enable row level security;
revoke all on table public.analytics_history from public, anon, authenticated;
drop policy if exists mcp_delegated_deny on public.analytics_history;
create policy mcp_delegated_deny on public.analytics_history
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
alter table public.seat_history enable row level security;
revoke all on table public.seat_history from public, anon, authenticated;
drop policy if exists mcp_delegated_deny on public.seat_history;
create policy mcp_delegated_deny on public.seat_history
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
alter table public.opening_hours_history enable row level security;
revoke all on table public.opening_hours_history from public, anon, authenticated;
drop policy if exists mcp_delegated_deny on public.opening_hours_history;
create policy mcp_delegated_deny on public.opening_hours_history
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
alter table public.reservation_target_history enable row level security;
revoke all on table public.reservation_target_history from public, anon, authenticated;
drop policy if exists mcp_delegated_deny on public.reservation_target_history;
create policy mcp_delegated_deny on public.reservation_target_history
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ------------------------------------------------------------ the writers
-- Close a seat's open interval now and open the next with what the seat
-- is now. Within one transaction (now() is constant) the open row is
-- rewritten instead of leaving an empty interval.
create or replace function public.analytics_seat_reopen(p_seat_id uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
begin
  delete from public.seat_history
   where seat_id = p_seat_id and upper_inf(valid) and lower(valid) >= now();
  update public.seat_history
     set valid = tstzrange(lower(valid), now(), '[)')
   where seat_id = p_seat_id and upper_inf(valid);
  insert into public.seat_history (workspace_id, seat_id, desk_id, office_id,
                                   level_id, blocked_from, blocked_to, valid)
  select s.workspace_id, s.id, s.desk_id, d.office_id, o.level_id,
         s.blocked_from, s.blocked_to, tstzrange(now(), null, '[)')
    from public.seats s
    join public.desks d on d.id = s.desk_id
    join public.offices o on o.id = d.office_id
   where s.id = p_seat_id;
end
$fn$;
revoke execute on function public.analytics_seat_reopen(uuid) from public, anon, authenticated;

create or replace function public.analytics_seat_changed()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if tg_table_name = 'seats' then
    perform public.analytics_seat_reopen(coalesce(new.id, old.id));
  elsif tg_table_name = 'desks' then
    perform public.analytics_seat_reopen(s.id)
       from public.seats s where s.desk_id = new.id;
  elsif tg_table_name = 'offices' then
    perform public.analytics_seat_reopen(s.id)
       from public.seats s join public.desks d on d.id = s.desk_id
      where d.office_id = new.id;
  end if;
  return null;
end
$fn$;
revoke execute on function public.analytics_seat_changed() from public, anon, authenticated;

drop trigger if exists analytics_seat_history on public.seats;
create trigger analytics_seat_history
  after insert or delete on public.seats
  for each row execute function public.analytics_seat_changed();
drop trigger if exists analytics_seat_history_update on public.seats;
create trigger analytics_seat_history_update
  after update of desk_id, blocked_from, blocked_to on public.seats
  for each row when (new.desk_id is distinct from old.desk_id
                     or new.blocked_from is distinct from old.blocked_from
                     or new.blocked_to is distinct from old.blocked_to)
  execute function public.analytics_seat_changed();
drop trigger if exists analytics_seat_history on public.desks;
create trigger analytics_seat_history
  after update of office_id on public.desks
  for each row when (new.office_id is distinct from old.office_id)
  execute function public.analytics_seat_changed();
drop trigger if exists analytics_seat_history on public.offices;
create trigger analytics_seat_history
  after update of level_id on public.offices
  for each row when (new.level_id is distinct from old.level_id)
  execute function public.analytics_seat_changed();

-- The opening hours as the KPI reads them: the booking rules with the
-- server's defaults (Mon-Fri, 08:00-17:00).
create or replace function public.analytics_hours_of(p_rules jsonb)
returns table (open_weekdays int[], work_start_minutes int, work_end_minutes int)
language sql immutable set search_path = public as $fn$
  select coalesce((select array_agg(x::int order by x::int)
                     from jsonb_array_elements_text(
                            coalesce(p_rules->'open_weekdays', '[1,2,3,4,5]'::jsonb)) x),
                  '{}'),
         coalesce((p_rules->>'work_start_minutes')::int, 480),
         coalesce((p_rules->>'work_end_minutes')::int, 1020);
$fn$;
revoke execute on function public.analytics_hours_of(jsonb) from public, anon, authenticated;

create or replace function public.analytics_workspace_changed()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_new record; v_old record;
begin
  select * into v_new from public.analytics_hours_of(coalesce(new.booking_rules, '{}'::jsonb));
  if tg_op = 'INSERT' then
    insert into public.analytics_history (workspace_id, since)
    values (new.id, now()) on conflict (workspace_id) do nothing;
  else
    select * into v_old from public.analytics_hours_of(coalesce(old.booking_rules, '{}'::jsonb));
    if (v_new.open_weekdays, v_new.work_start_minutes, v_new.work_end_minutes)
       is not distinct from
       (v_old.open_weekdays, v_old.work_start_minutes, v_old.work_end_minutes) then
      return null;
    end if;
  end if;
  delete from public.opening_hours_history
   where workspace_id = new.id and upper_inf(valid) and lower(valid) >= now();
  update public.opening_hours_history
     set valid = tstzrange(lower(valid), now(), '[)')
   where workspace_id = new.id and upper_inf(valid);
  insert into public.opening_hours_history (workspace_id, open_weekdays,
              work_start_minutes, work_end_minutes, valid)
  values (new.id, v_new.open_weekdays, v_new.work_start_minutes,
          v_new.work_end_minutes, tstzrange(now(), null, '[)'));
  return null;
end
$fn$;
revoke execute on function public.analytics_workspace_changed() from public, anon, authenticated;

drop trigger if exists analytics_opening_hours on public.workspaces;
create trigger analytics_opening_hours
  after insert or update of booking_rules on public.workspaces
  for each row execute function public.analytics_workspace_changed();

create or replace function public.analytics_reservation_target()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  -- A detach (every target null) is not a new target: the last one stays.
  if num_nonnulls(new.seat_id, new.desk_id, new.office_id, new.level_id) = 1
     and (tg_op = 'INSERT'
          or (new.seat_id, new.desk_id, new.office_id, new.level_id)
             is distinct from (old.seat_id, old.desk_id, old.office_id, old.level_id)) then
    insert into public.reservation_target_history
      (workspace_id, reservation_id, seat_id, desk_id, office_id, level_id)
    values (new.workspace_id, new.id, new.seat_id, new.desk_id, new.office_id, new.level_id);
  end if;
  return null;
end
$fn$;
revoke execute on function public.analytics_reservation_target() from public, anon, authenticated;

drop trigger if exists analytics_reservation_target on public.reservations;
create trigger analytics_reservation_target
  after insert or update of seat_id, desk_id, office_id, level_id
  on public.reservations for each row
  execute function public.analytics_reservation_target();

-- ------------------------------------------------------------ the start
-- History begins now for every existing workspace: what came before is
-- unknown and is not filled in with today's plan.
insert into public.analytics_history (workspace_id, since)
select w.id, now() from public.workspaces w
on conflict (workspace_id) do nothing;

insert into public.seat_history (workspace_id, seat_id, desk_id, office_id,
                                 level_id, blocked_from, blocked_to, valid)
select s.workspace_id, s.id, s.desk_id, d.office_id, o.level_id,
       s.blocked_from, s.blocked_to, tstzrange(now(), null, '[)')
  from public.seats s
  join public.desks d on d.id = s.desk_id
  join public.offices o on o.id = d.office_id
 where not exists (select 1 from public.seat_history h
                    where h.seat_id = s.id and upper_inf(h.valid));

insert into public.opening_hours_history (workspace_id, open_weekdays,
            work_start_minutes, work_end_minutes, valid)
select w.id, h.open_weekdays, h.work_start_minutes, h.work_end_minutes,
       tstzrange(now(), null, '[)')
  from public.workspaces w,
       lateral public.analytics_hours_of(coalesce(w.booking_rules, '{}'::jsonb)) h
 where not exists (select 1 from public.opening_hours_history x
                    where x.workspace_id = w.id and upper_inf(x.valid));

insert into public.reservation_target_history
  (workspace_id, reservation_id, seat_id, desk_id, office_id, level_id)
select r.workspace_id, r.id, r.seat_id, r.desk_id, r.office_id, r.level_id
  from public.reservations r
 where num_nonnulls(r.seat_id, r.desk_id, r.office_id, r.level_id) = 1
   and not exists (select 1 from public.reservation_target_history t
                    where t.reservation_id = r.id);

-- ------------------------------------------------------------ the reader
-- capacity.seat_utilisation v1 now reads the recorded history instead of
-- today's plan: each seat under the desk, room and level it belonged to
-- at the time, with the block it had then; the opening hours that held
-- on each day; each reservation on the place it booked, even after a
-- plan delete detached it. Time before the workspace's history began is
-- not counted and is named (`history_since`).
create or replace function public.kpi_seat_capacity(
  p_workspace_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_level_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tz text; v_since timestamptz; v_covered tstzmultirange; v_open tstzmultirange;
  v_seats int; v_physical numeric; v_offered numeric; v_reserved numeric;
  v_outside numeric; v_overlap numeric; v_unattributed int;
  v_rooms int; v_room_offered numeric; v_room_reserved numeric;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > interval '400 days' then
    raise exception 'the KPI period must be [from, to) with from < to, at most 400 days'
      using errcode = '22023';
  end if;
  if not public.has_permission(p_workspace_id, 'manageReservations') then
    raise exception 'not allowed to read the capacity figures of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'capacityKpi') then
    raise exception 'the capacity KPI is not enabled for this workspace'
      using errcode = '42501';
  end if;
  if p_level_id is not null and not exists (
       select 1 from public.levels l
        where l.id = p_level_id and l.workspace_id = p_workspace_id)
     and not exists (
       select 1 from public.seat_history h
        where h.level_id = p_level_id and h.workspace_id = p_workspace_id) then
    raise exception 'unknown level for this workspace' using errcode = '22023';
  end if;

  select w.timezone into v_tz from public.workspaces w where w.id = p_workspace_id;
  select a.since into v_since from public.analytics_history a
   where a.workspace_id = p_workspace_id;
  v_since := coalesce(v_since, now());
  v_covered := case when greatest(p_from, v_since) < p_to
                    then tstzmultirange(tstzrange(greatest(p_from, v_since), p_to, '[)'))
                    else '{}'::tstzmultirange end;

  -- The opening intervals, each day under the hours that held then.
  select coalesce(range_agg(tstzrange(
           (g.d + make_interval(mins => h.work_start_minutes)) at time zone v_tz,
           (g.d + make_interval(mins => h.work_end_minutes)) at time zone v_tz, '[)')
           * h.valid), '{}'::tstzmultirange) * v_covered
    into v_open
    from generate_series((p_from at time zone v_tz)::date::timestamp,
                         (p_to at time zone v_tz)::date::timestamp,
                         interval '1 day') g(d)
    join public.opening_hours_history h
      on h.workspace_id = p_workspace_id
     and h.valid && tstzrange(p_from, p_to, '[)')
   where h.work_end_minutes > h.work_start_minutes
     and extract(isodow from g.d)::int = any (h.open_weekdays)
     and not exists (select 1 from public.closure_days c
                      where c.workspace_id = p_workspace_id
                        and c.day = g.d::date);

  with scope as (
    select h.seat_id, h.desk_id, h.office_id, h.level_id,
           tstzmultirange(h.valid) * v_covered as held,
           case when h.blocked_from is null then '{}'::tstzmultirange
                else tstzmultirange(tstzrange(h.blocked_from, h.blocked_to, '[)'))
           end as blocked
      from public.seat_history h
     where h.workspace_id = p_workspace_id
       and h.valid && tstzrange(p_from, p_to, '[)')
       and (p_level_id is null or h.level_id = p_level_id)
  ), targets as (
    select r.starts_at, r.ends_at,
           case when t.reservation_id is null then r.seat_id else t.seat_id end as seat_id,
           case when t.reservation_id is null then r.desk_id else t.desk_id end as desk_id,
           case when t.reservation_id is null then r.office_id else t.office_id end as office_id,
           case when t.reservation_id is null then r.level_id else t.level_id end as level_id
      from public.reservations r
      left join lateral (
        select x.reservation_id, x.seat_id, x.desk_id, x.office_id, x.level_id
          from public.reservation_target_history x
         where x.reservation_id = r.id
         order by x.recorded_at desc, x.id desc limit 1) t on true
     where r.workspace_id = p_workspace_id
       and r.status in ('reserved', 'checked_in', 'completed')
       and r.starts_at < p_to and r.ends_at > p_from
  ), bound as (
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held as rng
      from targets tg
      join scope sc
        on tg.seat_id = sc.seat_id or tg.desk_id = sc.desk_id
        or tg.office_id = sc.office_id or tg.level_id = sc.level_id
  ), per_seat as (
    select sc.seat_id,
           range_agg(v_open * sc.held) as open_time,
           range_agg((v_open * sc.held) - sc.blocked) as offered
      from scope sc
     group by sc.seat_id
  ), measured as (
    select p.seat_id, p.open_time, p.offered,
           coalesce((select range_agg(b.rng) from bound b where b.seat_id = p.seat_id),
                    '{}'::tstzmultirange) as reserved,
           coalesce((select sum(public.kpi_multirange_hours(b.rng))
                       from bound b where b.seat_id = p.seat_id), 0) as raw_hours
      from per_seat p
  )
  select count(*)::int,
         coalesce(sum(public.kpi_multirange_hours(m.open_time)), 0),
         coalesce(sum(public.kpi_multirange_hours(m.offered)), 0),
         coalesce(sum(public.kpi_multirange_hours(m.reserved * m.offered)), 0),
         coalesce(sum(public.kpi_multirange_hours(m.reserved - m.offered)), 0),
         coalesce(sum(m.raw_hours - public.kpi_multirange_hours(m.reserved)), 0)
    into v_seats, v_physical, v_offered, v_reserved, v_outside, v_overlap
    from measured m;

  -- Rooms without a single seat: room-hours, never seat-hours. Rooms have
  -- no recorded history yet, so they are read as they are today.
  with rooms as (
    select o.id, o.level_id
      from public.offices o
     where o.workspace_id = p_workspace_id
       and (p_level_id is null or o.level_id = p_level_id)
       and not exists (select 1 from public.desks d
                         join public.seats s on s.desk_id = d.id
                        where d.office_id = o.id)
  )
  select count(*)::int,
         count(*) * public.kpi_multirange_hours(v_open),
         coalesce(sum(public.kpi_multirange_hours(
           coalesce((select range_agg(tstzrange(r.starts_at, r.ends_at, '[)'))
                       from public.reservations r
                      where r.workspace_id = p_workspace_id
                        and (r.office_id = rm.id or r.level_id = rm.level_id)
                        and r.status in ('reserved', 'checked_in', 'completed')),
                    '{}'::tstzmultirange) * v_open)), 0)
    into v_rooms, v_room_offered, v_room_reserved
    from rooms rm;

  -- Active reservations in the period with no place, then or now.
  select count(*)::int into v_unattributed
    from public.reservations r
   where r.workspace_id = p_workspace_id and p_level_id is null
     and r.status in ('reserved', 'checked_in', 'completed')
     and r.starts_at < p_to and r.ends_at > p_from
     and num_nonnulls(r.seat_id, r.desk_id, r.office_id, r.level_id) = 0
     and not exists (select 1 from public.reservation_target_history x
                      where x.reservation_id = r.id);

  if v_covered = '{}'::tstzmultirange then
    v_quality := v_quality || 'not_recorded'::text;
    v_reasons := v_reasons || 'history_not_recorded_before'::text;
  elsif v_offered = 0 then
    v_quality := v_quality || 'not_applicable'::text;
    v_reasons := v_reasons || 'no_offered_capacity'::text;
  elsif v_reserved = 0 then
    v_quality := v_quality || 'known_zero'::text;
  end if;
  if p_from < v_since and v_covered <> '{}'::tstzmultirange then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'history_not_recorded_before'::text;
  end if;
  if v_unattributed > 0 then
    if not ('partial' = any (v_quality)) then
      v_quality := v_quality || 'partial'::text;
    end if;
    v_reasons := v_reasons || 'unattributed_reservations'::text;
  end if;
  if v_outside > 0 then
    v_reasons := v_reasons || 'reserved_outside_offered_hours'::text;
  end if;
  if v_overlap > 0 then
    v_reasons := v_reasons || 'overlapping_reservations'::text;
  end if;
  if v_rooms > 0 and p_from < now() then
    v_reasons := v_reasons || 'rooms_current_structure'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'capacity.seat_utilisation', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz, 'level_id', p_level_id,
    'history_since', v_since,
    'seats', v_seats,
    'physical_seat_hours', round(v_physical, 2),
    'offered_seat_hours', round(v_offered, 2),
    'reserved_seat_hours', round(v_reserved, 2),
    'reserved_outside_offered_seat_hours', round(v_outside, 2),
    'overlapping_seat_hours', round(v_overlap, 2),
    'rooms_without_seats', v_rooms,
    'offered_room_hours', round(v_room_offered, 2),
    'reserved_room_hours', round(v_room_reserved, 2),
    'unattributed_reservations', v_unattributed,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;

revoke execute on function public.kpi_seat_capacity(uuid, timestamptz, timestamptz, uuid)
  from public, anon;
grant execute on function public.kpi_seat_capacity(uuid, timestamptz, timestamptz, uuid)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(335);
