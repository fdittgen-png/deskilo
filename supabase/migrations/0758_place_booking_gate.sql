-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0758 (#3862) -- with place booking switched off, the server refuses what
-- creates or extends a use of a place (the rule of 0640): a new booking
-- (single, replayable or a series), an administrator's booking for a member,
-- a kiosk's walk-up reservation or check-in, a change that extends or moves a
-- booking, and a carnet sale, with 55000, the code a switched-off functionality
-- answers. What a person does with a booking that exists stays open, at the
-- kiosk as in the app: checking in and out, shortening and cancelling it. The
-- assistant books and changes bookings through the same functions.

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
  -- Applied once: a second run leaves the functions as they are.
  if position('place booking is off in this workspace' in v_def) > 0 then return; end if;
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

  -- kiosk_act: a walk-up reservation or check-in creates a booking and is
  -- refused; checking in to a booking that exists and checking out stay
  -- open (both answer before the booking loop, on the level and seat paths).
  select pg_get_functiondef('public.kiosk_act(uuid,text,text,uuid,timestamp with time zone,timestamp with time zone,uuid)'::regprocedure)
    into v_def;
  if (length(v_def) - length(replace(v_def, $a$for v_attempt in 1..2 loop$a$, '')))
       / length($a$for v_attempt in 1..2 loop$a$) <> 2 then
    raise exception 'an anchor of #3862 was not found in kiosk_act' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, $a$for v_attempt in 1..2 loop$a$,
    ltrim(v_gate, E'\n ') || E'\n  ' || $a$for v_attempt in 1..2 loop$a$);
  execute v_def;

  -- update_reservation: a change that starts earlier or ends later extends or
  -- moves a booking and is refused; one inside the booking's own period
  -- (shortening it) stays open.
  select pg_get_functiondef('public.update_reservation(uuid,timestamp with time zone,timestamp with time zone)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_res.id is null then raise exception 'not your reservation' using errcode = 'DKK29'; end if;$a$,
    $a$  if v_res.id is null then raise exception 'not your reservation' using errcode = 'DKK29'; end if;
  if (p_starts_at < v_res.starts_at or p_ends_at > v_res.ends_at)
     and not public.feature_effective(v_res.workspace_id, 'placeBooking') then
    raise exception 'place booking is off in this workspace' using errcode = '55000';
  end if;$a$);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in update_reservation' using errcode = 'P0001';
  end if;
  execute v_def;

  -- sell_credit: a carnet is spent on places.
  select pg_get_functiondef('public.sell_credit(uuid,uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$
  if not public.feature_effective(p_workspace_id, 'carnets') then$a$,
    v_gate || $a$
  if not public.feature_effective(p_workspace_id, 'carnets') then$a$);
  if v_def is null then
    raise exception 'an anchor of #3862 was not found in sell_credit' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(758);
