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

-- What catches a booking refusal catches it by its code too: sample data
-- still skips a refused booking, and joining by invitation still answers its
-- own refusals. The assistant's reads and writes, restated whole below,
-- answer "refused" with its reason, as for P0001 before.
do $handlers$
declare
  v_def text;
begin
  -- create_sample_data
  select pg_get_functiondef('public.create_sample_data(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$when raise_exception or exclusion_violation or unique_violation then$r$,
    $r$when raise_exception or exclusion_violation or unique_violation
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36' then$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in create_sample_data'; end if;
  execute v_def;

  -- join_by_invitation
  select pg_get_functiondef('public.join_by_invitation(text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def, $r$when raise_exception then$r$,
    $r$when raise_exception
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36' then$r$);
  if v_def is null then raise exception 'an anchor of #3810 was not found in join_by_invitation'; end if;
  execute v_def;



end;
$handlers$;

-- The assistant's reads and writes, and the outcome they answer.
-- mcp_execute_v1: restated whole (an MCP operation's gate changes whole, #2392).
CREATE OR REPLACE FUNCTION public.mcp_execute_v1(p_installation_id uuid, p_workspace_id uuid, p_operation text, p_arguments jsonb, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.mcp_call_context;
  v_args jsonb := coalesce(p_arguments, '{}'::jsonb);
  v_read boolean;
  v_digest text;
  v_stop jsonb;
  v_retry integer;
  v_out jsonb;
  v_envelope jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  c := public.mcp_authorize(p_installation_id, p_workspace_id, p_operation);
  c.request_id := p_request_id;
  if c.refusal is null and to_regprocedure(
       format('public.%I(public.mcp_call_context, jsonb)', 'mcp_op_' || p_operation)) is null then
    c.refusal := 'unknown_operation';
  end if;
  if c.refusal is not null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
      case when c.refusal = 'unknown_operation' then 'validation_error' else 'denied' end, null, c.refusal));
  end if;
  v_read := c.spec->>'mutation' = 'read';
  if not v_read then
    if p_request_id is null then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
        'validation_error', null, 'invalid_arguments', jsonb_build_object('request_id', 'required')));
    end if;
    v_digest := md5(p_workspace_id::text || '|' || p_operation || '|' || (v_args - 'request_id')::text);
    v_stop := public.mcp_idempotent(c, p_request_id, v_digest);
    if v_stop is not null then return v_stop; end if;
  end if;
  -- #1630 — limited once authorised (a replay is not a new call), before work.
  v_retry := public.mcp_limit_retry_after(p_workspace_id, c.client_id, not v_read);
  if v_retry is not null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
      'rate_limited', null, 'rate_limited') || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry)));
  end if;
  if not v_read and c.spec->>'confirmation' = 'native' then
    v_stop := public.mcp_confirm(c, p_request_id, v_digest, v_args);
    if v_stop is not null then return v_stop; end if;
  end if;
  begin
    execute format('select public.%I($1, $2)', 'mcp_op_' || p_operation) into v_out using c, v_args;
  exception
    when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      v_out := public.mcp_outcome_of(sqlstate, sqlerrm);
    when raise_exception or check_violation or exclusion_violation or unique_violation
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36' then
      if v_read then raise; end if;
      v_out := public.mcp_outcome_of(sqlstate, sqlerrm);
  end;
  v_envelope := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, v_out->>'status',
    case when v_out->>'status' = 'validation_error' then null else v_out->'data' end, v_out->>'code', v_out->'fields');
  if not v_read and v_out->>'status' <> 'validation_error' then
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), c.client_id, p_request_id, p_workspace_id, p_operation, v_digest,
            case when v_out->>'status' in ('completed', 'pending_validation') then 'applied' else 'refused' end,
            v_envelope);
  end if;
  return public.mcp_usage_note(c.spec, v_envelope);
end;
$function$;
revoke execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) to authenticated;

-- mcp_read_v1: restated whole (an MCP operation's gate changes whole, #2392).
CREATE OR REPLACE FUNCTION public.mcp_read_v1(p_workspace_id uuid, p_member members, p_operation text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit integer := least(greatest(coalesce((p_args->>'limit')::integer, 25), 1), 100);
  v_from timestamptz;
  v_to timestamptz;
  v_after_at timestamptz;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_event public.events;
  v_can boolean;
  v_reason text;
  v_level uuid;
  v_office uuid;
  v_kind text;
  v_page jsonb;
  v_more boolean;
  -- #2391 — beyond her own rows only when her consent reaches the
  -- workspace (the facade always says which; a direct definer call is the
  -- service role's).
  v_wide boolean := coalesce(p_args->>'_ceiling', 'workspace') = 'workspace';
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > make_interval(days => (public.setting_value(null, 'mcp.read_range_days') #>> '{}')::int) then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id, x.desk_id, x.office_id, x.level_id),
                 'starts_at', x.starts_at, 'ends_at', x.ends_at, 'status', x.status) as r
          from public.reservations x
         where x.workspace_id = p_workspace_id and x.member_id = p_member.id
           and x.starts_at < v_to and x.ends_at > v_from
           and (v_after_at is null or (x.starts_at, x.id) > (v_after_at, v_after_id))
         order by x.starts_at, x.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'starts_at')::timestamptz, (v_last->>'reservation_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_availability' then
    -- #2145 — optionally one level or one office; #2391 — every kind the app
    -- books (seats, and desks, offices and levels booked as a whole),
    -- optionally one kind. A page is the next place ids in order; it is
    -- shown by label, and the cursor follows the ids it paged by. "free" is
    -- the booking engine's own verdict (0345), asked only for this page.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    v_kind := nullif(p_args->>'kind', '');
    if v_kind is not null and v_kind not in ('seat', 'desk', 'office', 'level', 'room', 'parking') then
      raise exception using errcode = '22023', message = 'kind';
    end if;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.id), '[]'::jsonb) into v_page
      from (select p.*
              from (select s.resource_kind as kind, s.id, s.id as seat_id, d.id as desk_id, o.id as office_id,
                           o.level_id, s.name
                      from public.seats s
                      join public.desks d on d.id = s.desk_id
                      join public.offices o on o.id = d.office_id
                     where s.workspace_id = p_workspace_id
                       and public.resource_kind_enabled(p_workspace_id, s.resource_kind)
                    union all
                    select 'desk', d.id, null, d.id, o.id, o.level_id, d.name
                      from public.desks d
                      join public.offices o on o.id = d.office_id
                     where d.workspace_id = p_workspace_id and d.bookable_as_whole
                    union all
                    select 'office', o.id, null, null, o.id, o.level_id, o.name
                      from public.offices o
                     where o.workspace_id = p_workspace_id and o.bookable_as_whole
                    union all
                    select 'level', l.id, null, null, null, l.id, l.name
                      from public.levels l
                     where l.workspace_id = p_workspace_id and l.bookable_as_whole) p
             where public.place_visible_to(p_member.id, p.office_id, case when p.kind = 'level' then p.level_id end)
               and (v_kind is null or p.kind = v_kind)
               and (v_level is null or p.level_id = v_level)
               and (v_office is null or p.office_id = v_office)
               and (v_after_id is null or p.id > v_after_id)
             order by p.id
             limit v_limit + 1) q;
    v_more := jsonb_array_length(v_page) > v_limit;
    if v_more then
      v_page := v_page - v_limit;
    end if;
    select coalesce(jsonb_agg(r order by r->>'label', r->>'kind', coalesce(r->>'seat_id', r->>'desk_id',
                                 r->>'office_id', r->>'level_id')), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('kind', x.kind, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end),
                 'name', x.name,
                 'free', public.mcp_place_bookable(p_workspace_id, x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end, v_from, v_to) is null) as r
          from jsonb_to_recordset(v_page) as x(kind text, id uuid, seat_id uuid, desk_id uuid,
                                               office_id uuid, level_id uuid, name text)) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(),
          (v_page->(jsonb_array_length(v_page) - 1)->>'id')::uuid) end,
      'not_checked', jsonb_build_array('price', 'approval'));
  end if;

  if p_operation = 'list_my_invoices' then
    select coalesce(jsonb_agg(r order by (r->>'issued_at')::timestamptz desc, r->>'invoice_id' desc), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('invoice_id', i.id, 'number', i.number, 'period', i.period,
                 'kind', i.kind, 'total_cents', i.total_cents, 'currency', i.currency,
                 'issued_at', i.issued_at, 'voided', i.voided_at is not null) as r
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = p_member.id
           and (v_after_at is null or (i.issued_at, i.id) < (v_after_at, v_after_id))
         order by i.issued_at desc, i.id desc
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'issued_at')::timestamptz, (v_last->>'invoice_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'list_pending_validations' then
    -- Pending events the caller authored or is the subject of; under a
    -- workspace ceiling also the ones she may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (e.actor_member_id = p_member.id or e.subject_member_id = p_member.id
                or (v_wide and (p_member.is_owner or p_member.is_admin
                                or public.may_validate_event_type(p_workspace_id, e.type))))
           and (v_after_at is null or (e.created_at, e.id) > (v_after_at, v_after_id))
         order by e.created_at, e.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'requested_at')::timestamptz, (v_last->>'event_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null
       or not (v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id
               or (v_wide and (p_member.is_owner or p_member.is_admin
                               or public.may_validate_event_type(p_workspace_id, v_event.type)))) then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_can := false;
    if v_event.status = 'pending' then
      begin
        perform public.respond_to_event(v_event.id, true);
        raise exception using errcode = 'P0002', message = 'mcp preview';
      exception
        when no_data_found then
          v_can := sqlerrm = 'mcp preview';
        when raise_exception
      -- #3810: a booking refusal carries its DKK code (0739).
      or sqlstate 'DKK01' or sqlstate 'DKK02' or sqlstate 'DKK03' or sqlstate 'DKK04' or sqlstate 'DKK05' or sqlstate 'DKK06' or sqlstate 'DKK07' or sqlstate 'DKK08' or sqlstate 'DKK09' or sqlstate 'DKK10' or sqlstate 'DKK11' or sqlstate 'DKK12' or sqlstate 'DKK13' or sqlstate 'DKK15' or sqlstate 'DKK16' or sqlstate 'DKK17' or sqlstate 'DKK18' or sqlstate 'DKK19' or sqlstate 'DKK20' or sqlstate 'DKK21' or sqlstate 'DKK22' or sqlstate 'DKK23' or sqlstate 'DKK25' or sqlstate 'DKK26' or sqlstate 'DKK27' or sqlstate 'DKK28' or sqlstate 'DKK29' or sqlstate 'DKK30' or sqlstate 'DKK31' or sqlstate 'DKK32' or sqlstate 'DKK33' or sqlstate 'DKK34' or sqlstate 'DKK35' or sqlstate 'DKK36' then
          v_reason := left(sqlerrm, 120);
        when others then
          v_reason := 'unavailable';
      end;
    end if;
    return jsonb_build_object(
      'event_id', v_event.id, 'type', v_event.type, 'status', v_event.status,
      'requested_at', v_event.created_at,
      'decisions', (select count(*) from public.event_decisions d where d.event_id = v_event.id),
      'can_respond', v_can, 'reason', v_reason);
  end if;

  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$function$;
revoke execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) from public, anon, authenticated;

-- mcp_outcome_of: restated whole (an MCP operation's gate changes whole, #2392).
CREATE OR REPLACE FUNCTION public.mcp_outcome_of(p_sqlstate text, p_message text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    when p_sqlstate = '22023' and p_message ilike '%not in this workspace%'
      then public.mcp_outcome('not_found', null, 'not_found')
    when p_sqlstate in ('22023', '22P02', '22007', '22008')
      then public.mcp_outcome('validation_error', null, 'invalid_arguments')
    else public.mcp_outcome('conflict',
           jsonb_build_object('reason', case when p_sqlstate = 'P0001' or p_sqlstate like 'DKK%' then left(p_message, 200) end), 'refused')
  end;
$function$;
revoke execute on function public.mcp_outcome_of(text, text) from public, anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(739);
