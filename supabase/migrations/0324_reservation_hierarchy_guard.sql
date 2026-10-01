-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0324 (#1908) -- a seat and its whole desk, office or level cannot both
-- be reserved, even by two commands at the same instant.
--
-- The exclusion constraints guard one resource column each (seat, desk,
-- office, level). Across the hierarchy, create_reservation's checks
-- (EXISTS / level_has_conflict) run before the insert, so two concurrent
-- commands — a seat and its whole office — could both see "free".
--
-- A BEFORE INSERT trigger now serialises exactly the conflicting work:
--   * it resolves the new row's chain (seat → desk → office → level);
--   * it takes transaction advisory locks along that chain in one fixed
--     order (level, office, desk): EXCLUSIVE on the space reserved as a
--     whole, SHARED on its ancestors. Two seats — even under one desk —
--     share every lock and proceed in parallel; a seat and its whole desk,
--     office or level conflict on one lock and run one after the other;
--   * holding the locks, it re-checks for an overlapping active booking
--     anywhere on the chain, with a fresh snapshot, and refuses (23P01).
-- Same-resource overlaps stay with the exclusion constraints.
--
-- It also takes an exclusive lock per MEMBER first, so one person's two
-- concurrent bookings are counted against each other by the existing
-- one-place / simultaneous-limit triggers instead of both passing.

create or replace function public.reservation_hierarchy_guard()
returns trigger language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_desk uuid;
  v_office uuid;
  v_level uuid;
begin
  if new.status not in ('reserved', 'checked_in') then return new; end if;

  -- One member's bookings run one at a time: the one-place and
  -- simultaneous-limit triggers (reservations_one_place, AFTER-insert
  -- enforce_reservation_limit) then count the member's other commands.
  -- This trigger sorts before reservations_one_place.
  perform pg_advisory_xact_lock(hashtextextended('resv-member:' || new.member_id, 1908));

  v_desk := coalesce(new.desk_id, (select s.desk_id from public.seats s where s.id = new.seat_id));
  v_office := coalesce(new.office_id, (select d.office_id from public.desks d where d.id = v_desk));
  v_level := coalesce(new.level_id, (select o.level_id from public.offices o where o.id = v_office));

  if v_level is not null then
    if new.level_id is not null then
      perform pg_advisory_xact_lock(hashtextextended('resv-space:' || v_level, 1908));
    else
      perform pg_advisory_xact_lock_shared(hashtextextended('resv-space:' || v_level, 1908));
    end if;
  end if;
  if v_office is not null then
    if new.office_id is not null then
      perform pg_advisory_xact_lock(hashtextextended('resv-space:' || v_office, 1908));
    else
      perform pg_advisory_xact_lock_shared(hashtextextended('resv-space:' || v_office, 1908));
    end if;
  end if;
  if v_desk is not null then
    if new.desk_id is not null then
      perform pg_advisory_xact_lock(hashtextextended('resv-space:' || v_desk, 1908));
    else
      perform pg_advisory_xact_lock_shared(hashtextextended('resv-space:' || v_desk, 1908));
    end if;
  end if;

  if exists (
    select 1
      from public.reservations r
      left join public.seats s on s.id = r.seat_id
      left join public.desks d on d.id = coalesce(r.desk_id, s.desk_id)
      left join public.offices o on o.id = coalesce(r.office_id, d.office_id)
     where r.id is distinct from new.id
       and r.status in ('reserved', 'checked_in')
       and tstzrange(r.starts_at, r.ends_at) && tstzrange(new.starts_at, new.ends_at)
       and (
         -- the new booking is an ancestor of an existing one, or the reverse
         (new.level_id is not null and coalesce(r.level_id, o.level_id) = new.level_id and r.level_id is distinct from new.level_id)
         or (new.office_id is not null and (coalesce(r.office_id, d.office_id) = new.office_id and r.office_id is distinct from new.office_id
                                            or r.level_id = v_level))
         or (new.desk_id is not null and (coalesce(r.desk_id, s.desk_id) = new.desk_id and r.desk_id is distinct from new.desk_id
                                          or r.office_id = v_office or r.level_id = v_level))
         or (new.seat_id is not null and (r.desk_id = v_desk or r.office_id = v_office or r.level_id = v_level))
       )
  ) then
    raise exception 'that space is already reserved in that period'
      using errcode = '23P01';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.reservation_hierarchy_guard() from public, anon, authenticated;

drop trigger if exists reservation_hierarchy_guard on public.reservations;
create trigger reservation_hierarchy_guard
  before insert on public.reservations
  for each row execute function public.reservation_hierarchy_guard();

select public.set_deskilo_schema_version(324);
