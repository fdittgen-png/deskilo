-- SPDX-License-Identifier: MIT
-- Per-member cap on SIMULTANEOUS open reservations. NOT YET applied to
-- the hosted reference project — the orchestrator applies it after review.
--
-- Each member can hold at most `max_active_reservations` open bookings at
-- once (status reserved/checked_in and not yet ended). NULL = unlimited,
-- the default. Owners and admins set the cap FOR OTHER members — never
-- for themselves, and members can never set their own: the number is a
-- governance knob, not a preference.
--
-- Enforcement is an AFTER INSERT trigger, not per-RPC guard calls: every
-- booking path (create_reservation, admin_create_reservation_for, series
-- instances, kiosk_act) inserts into reservations, so the trigger covers
-- them all — series instances beyond the cap land in the skipped report
-- exactly like closed days, and checking IN to an existing booking never
-- inserts, so it is never blocked.

alter table public.members
  add column max_active_reservations int
  check (max_active_reservations between 1 and 100);

-- 1. the setter: admin/owner, never self
create or replace function public.set_member_reservation_limit(
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
    -- governance, not self-service: nobody tunes their own cap
    raise exception 'cannot set your own reservation limit';
  end if;
  if p_limit is not null and (p_limit < 1 or p_limit > 100) then
    raise exception 'limit must be between 1 and 100 (or null for none)';
  end if;
  update public.members set max_active_reservations = p_limit
    where id = p_member_id;
end;
$$;
revoke execute on function public.set_member_reservation_limit(uuid, int) from public, anon;

-- 2. the guard trigger
create or replace function public.enforce_reservation_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_limit int;
  v_active int;
begin
  select max_active_reservations into v_limit
    from public.members where id = new.member_id;
  if v_limit is null then return new; end if;
  select count(*) into v_active from public.reservations r
    where r.member_id = new.member_id
      and r.status in ('reserved', 'checked_in')
      and r.ends_at > now();
  if v_active > v_limit then
    -- the client pins the substring 'reservation limit'
    raise exception 'reservation limit reached — at most % open reservations',
      v_limit;
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_reservation_limit() from public, anon, authenticated;

create trigger enforce_reservation_limit
after insert on public.reservations
for each row execute function public.enforce_reservation_limit();
