-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0326 (#1908) -- a reservation MOVED in time or space, or re-activated,
-- meets the same hierarchy guard and member serialisation as a new one.
--
-- 0325's guard ran on INSERT only. An update that changes the hours, the
-- space or the member of an active reservation — or turns an inactive one
-- active again — could still overlap a seat and its whole desk, office or
-- level. The same function now also runs BEFORE UPDATE of exactly those
-- columns; it excludes the row itself from its re-check (`r.id is
-- distinct from new.id`) and ignores rows that end up inactive.

drop trigger if exists reservation_hierarchy_guard_update on public.reservations;
create trigger reservation_hierarchy_guard_update
  before update of starts_at, ends_at, seat_id, desk_id, office_id, level_id, member_id, status
  on public.reservations
  for each row
  when (new.status in ('reserved', 'checked_in')
        and (old.starts_at, old.ends_at, old.seat_id, old.desk_id, old.office_id, old.level_id, old.member_id, old.status)
            is distinct from
            (new.starts_at, new.ends_at, new.seat_id, new.desk_id, new.office_id, new.level_id, new.member_id, new.status))
  execute function public.reservation_hierarchy_guard();

select public.set_deskilo_schema_version(326);
