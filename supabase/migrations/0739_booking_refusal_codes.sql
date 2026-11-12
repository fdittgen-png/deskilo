-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0739 — #3810 (part of #3657, i18n I11b): a booking refusal carries a code
-- and its values, so the app maps codes, never sentences. Every refusal a
-- person can meet while booking, editing, cancelling, checking in or out
-- raises a DKK errcode; one that names a value (days, minutes) carries it
-- as JSON in DETAIL. The English message stays as it was: an app from
-- before still recognises it, and nothing else about a function changes.
-- What a person cannot meet (a malformed request, the kiosk's badge steps)
-- keeps its message only.
--
--   DKK01 the workspace is closed        DKK19 you already have a booking then
--   DKK02 the half-day quota is used     DKK20 already checked in elsewhere
--   DKK03 the reservation limit          DKK21 not allowed to reserve a level
--   DKK04 a half-day or the working day  DKK22 not bookable as a whole
--   DKK05 the full working day           DKK23 level booking is off
--   DKK06 the minute grid {minutes}      DKK24 (not issued: the hierarchy
--                                              guard keeps Postgres's 23P01)
--   DKK07 the seat is blocked            DKK25 not checked in
--   DKK08 beyond the horizon {days}      DKK26 the place is taken then
--   DKK09 below the minimum {minutes}    DKK27 the membership is not active
--   DKK10 above the maximum {minutes}    DKK28 not a member of the workspace
--   DKK11 entirely in the past           DKK29 not your reservation
--   DKK12 a walk-up starts today         DKK30 not cancellable
--   DKK13 ends on the day it starts      DKK31 a running booking keeps its start
--   DKK14 (not issued: no function says  DKK32 the new end must lie ahead
--          it any more)
--   DKK15 outside hours: walk-ups only   DKK33 only upcoming bookings change
--   DKK16 outside hours: none            DKK34 a series is too long {days}
--   DKK17 check-in not open yet          DKK35 an admin may not assign a level
--   DKK18 check-in closed                DKK36 the booking is no longer reserved

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  -- admin_create_reservation_for
  select pg_get_functiondef('public.admin_create_reservation_for(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level booking is not enabled';$r$,
    $r$raise exception 'level booking is not enabled' using errcode = 'DKK23';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'admins may not assign level reservations here';$r$,
    $r$raise exception 'admins may not assign level reservations here' using errcode = 'DKK35';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level not bookable as a whole';$r$,
    $r$raise exception 'level not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'the level has reservations in that period';$r$,
    $r$raise exception 'the level has reservations in that period' using errcode = 'DKK26';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in admin_create_reservation_for'; end if;
  execute v_def;

  -- assert_member_quota
  select pg_get_functiondef('public.assert_member_quota(uuid,timestamp with time zone)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'half-day quota exceeded — request additional half-days';$r$,
    $r$raise exception 'half-day quota exceeded — request additional half-days' using errcode = 'DKK02';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in assert_member_quota'; end if;
  execute v_def;

  -- assert_seat_not_blocked
  select pg_get_functiondef('public.assert_seat_not_blocked(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'seat is blocked in that period';$r$,
    $r$raise exception 'seat is blocked in that period' using errcode = 'DKK07';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in assert_seat_not_blocked'; end if;
  execute v_def;

  -- assert_workspace_open
  select pg_get_functiondef('public.assert_workspace_open(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'workspace is closed on % (weekday not open)', v_day;$r$,
    $r$raise exception 'workspace is closed on % (weekday not open)', v_day using errcode = 'DKK01';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'workspace is closed on % (closure day)', v_day;$r$,
    $r$raise exception 'workspace is closed on % (closure day)', v_day using errcode = 'DKK01';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in assert_workspace_open'; end if;
  execute v_def;

  -- cancel_reservation
  select pg_get_functiondef('public.cancel_reservation(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not your reservation';$r$,
    $r$raise exception 'not your reservation' using errcode = 'DKK29';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not cancellable';$r$,
    $r$raise exception 'not cancellable' using errcode = 'DKK30';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in cancel_reservation'; end if;
  execute v_def;

  -- check_in_reservation
  select pg_get_functiondef('public.check_in_reservation(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not your reservation';$r$,
    $r$raise exception 'not your reservation' using errcode = 'DKK29';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not in reserved state';$r$,
    $r$raise exception 'not in reserved state' using errcode = 'DKK36';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'check-in window not open yet';$r$,
    $r$raise exception 'check-in window not open yet' using errcode = 'DKK17';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'check-in window closed';$r$,
    $r$raise exception 'check-in window closed' using errcode = 'DKK18';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'already checked in elsewhere';$r$,
    $r$raise exception 'already checked in elsewhere' using errcode = 'DKK20';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in check_in_reservation'; end if;
  execute v_def;

  -- check_out_reservation
  select pg_get_functiondef('public.check_out_reservation(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not your reservation';$r$,
    $r$raise exception 'not your reservation' using errcode = 'DKK29';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not checked in';$r$,
    $r$raise exception 'not checked in' using errcode = 'DKK25';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in check_out_reservation'; end if;
  execute v_def;

  -- create_reservation
  select pg_get_functiondef('public.create_reservation(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,boolean,uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an active member';$r$,
    $r$raise exception 'not an active member' using errcode = 'DKK27';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'seat is blocked in that period';$r$,
    $r$raise exception 'seat is blocked in that period' using errcode = 'DKK07';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'desk is reserved as a whole in that period';$r$,
    $r$raise exception 'desk is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'office is reserved as a whole in that period';$r$,
    $r$raise exception 'office is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level is reserved as a whole in that period';$r$,
    $r$raise exception 'level is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level booking is not enabled';$r$,
    $r$raise exception 'level booking is not enabled' using errcode = 'DKK23';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to reserve a level';$r$,
    $r$raise exception 'not allowed to reserve a level' using errcode = 'DKK21';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'desk not bookable as a whole';$r$,
    $r$raise exception 'desk not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a seat on this desk is already reserved in that period';$r$,
    $r$raise exception 'a seat on this desk is already reserved in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'office not bookable as a whole';$r$,
    $r$raise exception 'office not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a seat in this office is already reserved in that period';$r$,
    $r$raise exception 'a seat in this office is already reserved in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a desk in this office is already reserved in that period';$r$,
    $r$raise exception 'a desk in this office is already reserved in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level not bookable as a whole';$r$,
    $r$raise exception 'level not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'the level has reservations in that period';$r$,
    $r$raise exception 'the level has reservations in that period' using errcode = 'DKK26';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in create_reservation'; end if;
  execute v_def;

  -- create_reservation_once
  select pg_get_functiondef('public.create_reservation_once(uuid,uuid,uuid,uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,boolean)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an active member';$r$,
    $r$raise exception 'not an active member' using errcode = 'DKK27';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in create_reservation_once'; end if;
  execute v_def;

  -- create_series
  select pg_get_functiondef('public.create_series(uuid,uuid,timestamp with time zone,timestamp with time zone,text,timestamp with time zone,uuid,uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not an active member';$r$,
    $r$raise exception 'not an active member' using errcode = 'DKK27';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'series exceeds the maximum of % days', v_max_days;$r$,
    $r$raise exception 'series exceeds the maximum of % days', v_max_days using errcode = 'DKK34', detail = json_build_object('days', v_max_days)::text;$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level booking is not enabled';$r$,
    $r$raise exception 'level booking is not enabled' using errcode = 'DKK23';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to reserve a level';$r$,
    $r$raise exception 'not allowed to reserve a level' using errcode = 'DKK21';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'desk not bookable as a whole';$r$,
    $r$raise exception 'desk not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'office not bookable as a whole';$r$,
    $r$raise exception 'office not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level not bookable as a whole';$r$,
    $r$raise exception 'level not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a seat on this desk is already reserved in that period';$r$,
    $r$raise exception 'a seat on this desk is already reserved in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'office is reserved as a whole in that period';$r$,
    $r$raise exception 'office is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level is reserved as a whole in that period';$r$,
    $r$raise exception 'level is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a seat in this office is already reserved in that period';$r$,
    $r$raise exception 'a seat in this office is already reserved in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a desk in this office is already reserved in that period';$r$,
    $r$raise exception 'a desk in this office is already reserved in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'the level has reservations in that period';$r$,
    $r$raise exception 'the level has reservations in that period' using errcode = 'DKK26';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in create_series'; end if;
  execute v_def;

  -- enforce_booking_rules
  select pg_get_functiondef('public.enforce_booking_rules(uuid,timestamp with time zone,timestamp with time zone,boolean,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'beyond the advance-booking horizon of % days', horizon;$r$,
    $r$raise exception 'beyond the advance-booking horizon of % days', horizon using errcode = 'DKK08', detail = json_build_object('days', horizon)::text;$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'below the minimum duration of % minutes', min_min;$r$,
    $r$raise exception 'below the minimum duration of % minutes', min_min using errcode = 'DKK09', detail = json_build_object('minutes', min_min)::text;$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'above the maximum duration of % minutes', max_min;$r$,
    $r$raise exception 'above the maximum duration of % minutes', max_min using errcode = 'DKK10', detail = json_build_object('minutes', max_min)::text;$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'the booking lies entirely in the past';$r$,
    $r$raise exception 'the booking lies entirely in the past' using errcode = 'DKK11';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a walk-up check-in must start today';$r$,
    $r$raise exception 'a walk-up check-in must start today' using errcode = 'DKK12';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a booking must end on the day it starts';$r$,
    $r$raise exception 'a booking must end on the day it starts' using errcode = 'DKK13';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'bookings outside the opening hours are not allowed';$r$,
    $r$raise exception 'bookings outside the opening hours are not allowed' using errcode = 'DKK16';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only spontaneous check-ins are possible outside the opening hours — booking ahead is not';$r$,
    $r$raise exception 'only spontaneous check-ins are possible outside the opening hours — booking ahead is not' using errcode = 'DKK15';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'walk-ups must end at the half-day boundary or the end of the working day';$r$,
    $r$raise exception 'walk-ups must end at the half-day boundary or the end of the working day' using errcode = 'DKK04';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'bookings must cover a half-day or the full working day';$r$,
    $r$raise exception 'bookings must cover a half-day or the full working day' using errcode = 'DKK04';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'bookings must cover the full day (working hours)';$r$,
    $r$raise exception 'bookings must cover the full day (working hours)' using errcode = 'DKK05';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'bookings must start and end on the %-minute grid', slot;$r$,
    $r$raise exception 'bookings must start and end on the %-minute grid', slot using errcode = 'DKK06', detail = json_build_object('minutes', slot)::text;$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in enforce_booking_rules'; end if;
  execute v_def;

  -- enforce_one_place
  select pg_get_functiondef('public.enforce_one_place()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception
        'you already have a reservation in that period (at most % at a time)',
        v_allowance;$r$,
    $r$raise exception 'you already have a reservation in that period (at most % at a time)',
        v_allowance using errcode = 'DKK19';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in enforce_one_place'; end if;
  execute v_def;

  -- enforce_reservation_limit
  select pg_get_functiondef('public.enforce_reservation_limit()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'reservation limit reached — at most % open reservations',
      v_limit;$r$,
    $r$raise exception 'reservation limit reached — at most % open reservations',
      v_limit using errcode = 'DKK03';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in enforce_reservation_limit'; end if;
  execute v_def;

  -- kiosk_act
  select pg_get_functiondef('public.kiosk_act(uuid,text,text,uuid,timestamp with time zone,timestamp with time zone,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not checked in';$r$,
    $r$raise exception 'not checked in' using errcode = 'DKK25';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level booking is not enabled';$r$,
    $r$raise exception 'level booking is not enabled' using errcode = 'DKK23';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level not bookable as a whole';$r$,
    $r$raise exception 'level not bookable as a whole' using errcode = 'DKK22';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not allowed to reserve a level';$r$,
    $r$raise exception 'not allowed to reserve a level' using errcode = 'DKK21';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'already checked in elsewhere';$r$,
    $r$raise exception 'already checked in elsewhere' using errcode = 'DKK20';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'the level has reservations in that period';$r$,
    $r$raise exception 'the level has reservations in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'seat is blocked in that period';$r$,
    $r$raise exception 'seat is blocked in that period' using errcode = 'DKK07';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'desk is reserved as a whole in that period';$r$,
    $r$raise exception 'desk is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'office is reserved as a whole in that period';$r$,
    $r$raise exception 'office is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'level is reserved as a whole in that period';$r$,
    $r$raise exception 'level is reserved as a whole in that period' using errcode = 'DKK26';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in kiosk_act'; end if;
  execute v_def;

  -- my_active_member
  select pg_get_functiondef('public.my_active_member(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not a member of this workspace';$r$,
    $r$raise exception 'not a member of this workspace' using errcode = 'DKK28';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in my_active_member'; end if;
  execute v_def;

  -- update_reservation
  select pg_get_functiondef('public.update_reservation(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'not your reservation';$r$,
    $r$raise exception 'not your reservation' using errcode = 'DKK29';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'a running booking keeps its start';$r$,
    $r$raise exception 'a running booking keeps its start' using errcode = 'DKK31';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'the new end must lie ahead';$r$,
    $r$raise exception 'the new end must lie ahead' using errcode = 'DKK32';$r$);
  v_def := pg_temp.anchor_replace(v_def, $r$raise exception 'only upcoming reservations can be edited';$r$,
    $r$raise exception 'only upcoming reservations can be edited' using errcode = 'DKK33';$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in update_reservation'; end if;
  execute v_def;
end;
$migration$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(739);
