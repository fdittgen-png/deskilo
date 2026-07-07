-- SPDX-License-Identifier: MIT
-- DesKilo reservations (Epic #4, issue #41). Applied to the hosted reference
-- project on 2026-07-07 as "reservations_schema_and_rpcs".
-- The exclusion constraint is the hard guarantee against double-booking
-- (spec §4.2 pitfall); RPCs are the only write path and run the softer
-- business checks.

create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  -- on delete RESTRICT: the editor must resolve reservations before removing
  -- a seat/office (spec §10 guarded deletion)
  seat_id uuid references public.seats(id) on delete restrict,
  office_id uuid references public.offices(id) on delete restrict,
  member_id uuid not null references public.members(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'reserved'
    check (status in ('reserved','checked_in','completed','cancelled','released')),
  series_id uuid,
  checked_in_at timestamptz,
  checked_out_at timestamptz,
  created_at timestamptz not null default now(),
  constraint reservations_time_valid check (ends_at > starts_at),
  constraint reservations_one_target check ((seat_id is null) <> (office_id is null))
);
create index reservations_workspace_time_idx
  on public.reservations (workspace_id, starts_at);
create index reservations_member_idx on public.reservations (member_id);
create index reservations_seat_idx on public.reservations (seat_id);

-- No two active bookings may overlap on the same seat / same office.
alter table public.reservations add constraint reservations_seat_no_overlap
  exclude using gist (seat_id with =, tstzrange(starts_at, ends_at) with &&)
  where (status in ('reserved','checked_in') and seat_id is not null);
alter table public.reservations add constraint reservations_office_no_overlap
  exclude using gist (office_id with =, tstzrange(starts_at, ends_at) with &&)
  where (status in ('reserved','checked_in') and office_id is not null);

alter table public.reservations enable row level security;
create policy reservations_select on public.reservations
  for select using (public.is_member_of(workspace_id));
-- writes via SECURITY DEFINER RPCs only (default-deny)

-- Creates a reservation for the CALLER (admin-for-others goes through the
-- Epic-#6 confirmation protocol, never directly here). p_check_in makes it
-- an atomic walk-up: reservation + check-in in one transaction (spec §4.2).
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

  if p_seat_id is not null then
    select * into v_seat from public.seats
      where id = p_seat_id and workspace_id = p_workspace_id;
    if v_seat.id is null then raise exception 'unknown seat'; end if;
    -- blocked for maintenance?
    if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
                 coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
       && tstzrange(p_starts_at, p_ends_at)
       and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
      raise exception 'seat is blocked in that period';
    end if;
    -- the seat's office booked as a whole?
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
    -- any seat inside already booked?
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

create or replace function public.check_in_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_res public.reservations;
begin
  select r.* into v_res from public.reservations r
    join public.members m on m.id = r.member_id
    where r.id = p_reservation_id and m.user_id = auth.uid();
  if v_res.id is null then raise exception 'not your reservation'; end if;
  if v_res.status <> 'reserved' then raise exception 'not in reserved state'; end if;
  update public.reservations
    set status = 'checked_in', checked_in_at = now()
    where id = p_reservation_id;
end;
$$;

-- Check-out truncates ends_at to now so the seat frees immediately.
create or replace function public.check_out_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_res public.reservations;
begin
  select r.* into v_res from public.reservations r
    join public.members m on m.id = r.member_id
    where r.id = p_reservation_id and m.user_id = auth.uid();
  if v_res.id is null then raise exception 'not your reservation'; end if;
  if v_res.status <> 'checked_in' then raise exception 'not checked in'; end if;
  update public.reservations
    set status = 'completed',
        checked_out_at = now(),
        ends_at = least(ends_at, now())
    where id = p_reservation_id;
end;
$$;

create or replace function public.cancel_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_res public.reservations;
begin
  select r.* into v_res from public.reservations r
    join public.members m on m.id = r.member_id
    where r.id = p_reservation_id and m.user_id = auth.uid();
  if v_res.id is null then raise exception 'not your reservation'; end if;
  if v_res.status not in ('reserved','checked_in') then
    raise exception 'not cancellable';
  end if;
  update public.reservations set status = 'cancelled' where id = p_reservation_id;
end;
$$;

revoke execute on function public.create_reservation(uuid, uuid, uuid, timestamptz, timestamptz, boolean) from public, anon;
revoke execute on function public.check_in_reservation(uuid) from public, anon;
revoke execute on function public.check_out_reservation(uuid) from public, anon;
revoke execute on function public.cancel_reservation(uuid) from public, anon;
