-- SPDX-License-Identifier: MIT
-- Members edit their own reservations. Applied to the hosted reference
-- project on 2026-07-19.
--
-- The detail sheet gains Edit/Cancel everywhere (hub plan, Day, Week,
-- calendar timeline); cancel_reservation (0005) already covers delete,
-- this adds the atomic time edit: same seat, new window, every guard
-- re-checked in one transaction (the exclusion constraint re-validates
-- overlap against everyone else while ignoring the row's own old range).

-- The 0007 audit trigger only logged 'modified' on end changes; a pure
-- start move (edit) must audit too.
create or replace function public.log_reservation_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_action text;
begin
  if tg_op = 'INSERT' then
    v_action := 'created';
  elsif new.status = 'cancelled' and old.status <> 'cancelled' then
    v_action := 'cancelled';
  elsif new.status <> old.status
     or new.ends_at <> old.ends_at
     or new.starts_at <> old.starts_at then
    v_action := 'modified';
  else
    return new;
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     reservation_id, payload, status)
  values
    (new.workspace_id, 'reservation', v_action, new.member_id, new.member_id,
     new.id,
     jsonb_build_object(
       'starts_at', new.starts_at, 'ends_at', new.ends_at,
       'status', new.status, 'seat_id', new.seat_id, 'office_id', new.office_id
     ),
     'applied');
  return new;
end;
$$;

-- Atomic own-reservation time edit: still 'reserved', rules + closure +
-- seat block + quota all re-checked for the NEW window.
create or replace function public.update_reservation(
  p_reservation_id uuid, p_starts_at timestamptz, p_ends_at timestamptz
) returns void language plpgsql security definer set search_path = public as $$
declare v_res public.reservations;
begin
  select r.* into v_res from public.reservations r
    join public.members m on m.id = r.member_id
    where r.id = p_reservation_id and m.user_id = auth.uid();
  if v_res.id is null then raise exception 'not your reservation'; end if;
  if v_res.status <> 'reserved' then
    raise exception 'only upcoming reservations can be edited';
  end if;
  perform public.enforce_booking_rules(
    v_res.workspace_id, p_starts_at, p_ends_at);
  if v_res.seat_id is not null then
    perform public.assert_seat_not_blocked(
      v_res.seat_id, p_starts_at, p_ends_at);
  end if;
  update public.reservations
    set starts_at = p_starts_at, ends_at = p_ends_at
    where id = p_reservation_id;
  perform public.assert_member_quota(v_res.member_id, p_starts_at);
end;
$$;
revoke execute on function public.update_reservation(uuid, timestamptz, timestamptz) from public, anon;
