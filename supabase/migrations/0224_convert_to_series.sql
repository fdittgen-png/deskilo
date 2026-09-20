-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0224 (#1394) — converting a booking to a repeat is one act, so it is
-- one transaction.
--
-- `reservation_detail_sheet.dart` did it in two RPCs:
--
--     await repo.cancel(r.id);
--     final result = await repo.createSeries(…);
--
-- Each of those is transactional on its own. The COMPOSITION was not,
-- and the composition is what the member asked for.
--
-- ## The failure is the ordinary path, not a race
--
-- `create_series` wraps every generated date in
-- `begin … exception when others then v_skipped := …`, so a closed day,
-- a blocked seat, a conflict or a quota refusal becomes a SKIPPED date
-- rather than an error. It raises only before the loop.
--
-- So when the seat cannot take the new dates, `createSeries` returns
-- normally with `booked: []`. The client's try/catch never fires,
-- execution reaches the success branch, the sheet pops — and the
-- original booking is already cancelled. The member is left with
-- nothing and is shown no error at all.
--
-- Demonstrated on this project before writing the fix, rolled back:
--
--     after_cancel=cancelled | series_raised=NO booked=0 skipped=3
--     | member_live_rows_now=0
--
-- ## What this function adds
--
-- One transaction, and one rule: **a conversion that books no date is
-- not a conversion**. Raising rolls the cancel back with it, so the
-- member keeps what they had. A partial result is still returned
-- whole — `booked` and `skipped` — because skipping some dates is a
-- real outcome the caller must report, and losing the original is not.
--
-- ## The caller check
--
-- Owner-of-the-row OR `has_permission(ws, 'manageReservations')` — the
-- same pair `cancel_reservation` uses since 0180 replaced `is_admin_of`
-- with the role matrix. Verified live: an owner-member resolves true,
-- a plain member false.
--
-- Note that `cancel_series` still filters on `m.user_id = auth.uid()`
-- with no admin branch, so an admin may cancel a member's single
-- booking but not their series. That asymmetry is recorded on #1394 and
-- is NOT changed here — this migration adds a function, it does not
-- rewrite one whose callers it has not audited.

create or replace function public.convert_to_series(
  p_reservation_id uuid,
  p_pattern text,
  p_until timestamptz
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
  v_series jsonb;
begin
  select r.* into v_res from public.reservations r where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own
     and not public.has_permission(v_res.workspace_id, 'manageReservations') then
    raise exception 'not your reservation';
  end if;

  -- A running or finished booking is not converted: `create_series`
  -- would book from its start, which is in the past.
  if v_res.status <> 'reserved' then
    raise exception 'only an upcoming reservation can become a repeat';
  end if;
  if v_res.seat_id is null then
    raise exception 'only a seat booking can become a repeat';
  end if;
  if v_res.series_id is not null then
    raise exception 'this booking is already part of a repeat';
  end if;

  update public.reservations set status = 'cancelled' where id = p_reservation_id;

  -- Inherits every gate create_series already applies: the member check,
  -- the pattern, max_series_days, enforce_booking_rules, the whole-space
  -- rules, and the per-date skipping.
  v_series := public.create_series(
    v_res.workspace_id, v_res.seat_id, v_res.starts_at, v_res.ends_at,
    p_pattern, p_until);

  -- THE rule this function exists for. The client pins the substring
  -- 'your booking is unchanged'.
  if jsonb_array_length(v_series->'booked') = 0 then
    raise exception
      'the repeat could not book any date — your booking is unchanged';
  end if;

  return v_series;
end;
$$;

revoke execute on function public.convert_to_series(uuid, text, timestamptz)
  from public, anon;
