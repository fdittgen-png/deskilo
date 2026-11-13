-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0757 (#3862) -- place booking switched off is refused by the server, not
-- only hidden by the app (the rule of 0640). With `placeBooking` off, a new
-- booking (single, replayable or a series), an administrator's booking for a member, a kiosk's
-- reservation or check-in, and a carnet sale are refused with 55000, the code
-- a switched-off functionality answers. Cancelling a booking and checking out
-- stay open, so nothing stays trapped. The assistant books through
-- create_reservation_once and meets the same refusal.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  -- An anchor names one place: it occurs exactly once, or nothing is patched.
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_gate constant text := $g$
  if not public.feature_effective(p_workspace_id, 'placeBooking') then
    raise exception 'place booking is off in this workspace' using errcode = '55000';
  end if;$g$;
  v_member_check constant text :=
    $a$  if v_member.id is null then raise exception 'not an active member' using errcode = 'DKK27'; end if;$a$;
begin
  -- create_reservation_once (the app's and the assistant's booking).
  select pg_get_functiondef('public.create_reservation_once(uuid,uuid,uuid,uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,boolean)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def, v_member_check, v_member_check || v_gate);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in create_reservation_once' using errcode = 'P0001';
  end if;
  execute v_def;

  -- create_reservation.
  select pg_get_functiondef('public.create_reservation(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,boolean,uuid,uuid)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def, v_member_check, v_member_check || v_gate);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in create_reservation' using errcode = 'P0001';
  end if;
  execute v_def;

  -- create_series.
  select pg_get_functiondef('public.create_series(uuid,uuid,timestamp with time zone,timestamp with time zone,text,timestamp with time zone,uuid,uuid,uuid)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def, v_member_check, v_member_check || v_gate);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in create_series' using errcode = 'P0001';
  end if;
  execute v_def;

  -- admin_create_reservation_for.
  select pg_get_functiondef('public.admin_create_reservation_for(uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,uuid)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_actor.id is null then raise exception 'not an admin of this workspace' using errcode = 'DKN01'; end if;$a$,
    $a$  if v_actor.id is null then raise exception 'not an admin of this workspace' using errcode = 'DKN01'; end if;$a$ || v_gate);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in admin_create_reservation_for' using errcode = 'P0001';
  end if;
  execute v_def;

  -- kiosk_act: reserving and checking in; checking out stays open.
  select pg_get_functiondef('public.kiosk_act(uuid,text,text,uuid,timestamp with time zone,timestamp with time zone,uuid)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if p_action not in ('reserve', 'check_in') then
    raise exception 'unknown kiosk action';
  end if;$a$,
    $a$  if p_action not in ('reserve', 'check_in') then
    raise exception 'unknown kiosk action';
  end if;$a$ || v_gate);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in kiosk_act' using errcode = 'P0001';
  end if;
  execute v_def;

  -- sell_credit: a carnet is spent on places.
  select pg_get_functiondef('public.sell_credit(uuid,uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    raise exception 'carnets are off in this workspace';
  end if;$a$,
    $a$    raise exception 'carnets are off in this workspace';
  end if;$a$ || v_gate);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in sell_credit' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(757);
