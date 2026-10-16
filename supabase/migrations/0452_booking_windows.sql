-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0452 (#2486, S3 of #2483) -- the booking and check-in windows are registry
-- settings; Dart and SQL read the same value.
--
-- Nine rows (groups booking, billing, directory, presence). Defaults are
-- today's values exactly. Three are documented guardrails (editable = false):
-- the reminder lookahead (7 days, a device scheduling horizon), the booking
-- intent ledger cap (20, a local recovery list) and the subscription advance
-- days (28, the server clamps to it).
--
-- Anchored patches (each anchor asserted, so a drifted body fails the
-- migration instead of shipping a silent no-op):
--   check_in_reservation  v_leeway starts from the workspace setting; the
--                         existing greatest(v_leeway, grid step) widening stays,
--                         so the effective allowance is greatest(setting, step)
--   kiosk_act             the two flat 15-minute leeways read the setting
--   calendar_items        the reminder lead (three branches) reads the setting

-- ── the registry rows ────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('booking.check_in_leeway_minutes', 'duration', '15'::jsonb, 0, 240, 'minutes', 'booking', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'check_in_reservation, kiosk_act (0113, 0119, 0122); Reservation.checkInLeeway', 'How many minutes before its start a booking can be checked in. A minute grid wider than this widens it to one grid step.'),
('booking.check_in_reminder_lead_minutes', 'duration', '15'::jsonb, 1, 120, 'minutes', 'booking', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'calendar_items (0133, 0428); upcomingCheckInReminders', 'Minutes before a booking starts at which the check-in reminder is shown.'),
('booking.check_in_reminder_lookahead_days', 'int', '7'::jsonb, 1, 30, 'days', 'booking', array['platform'], 'workspaceSettings', null, false, null, 'upcomingCheckInReminders', 'Guardrail: how many days ahead a device schedules check-in reminders. A device scheduling horizon, not a booking rule.'),
('booking.walk_up_window_minutes', 'duration', '240'::jsonb, 15, 1440, 'minutes', 'booking', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'walkUpWindow', 'Length of the stay booked on the spot (badge or space code) when the workspace books by the minute.'),
('booking.walk_up_floor_minutes', 'duration', '15'::jsonb, 1, 60, 'minutes', 'booking', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'walkUpWindow', 'Shortest stay booked on the spot, used when the usual window would cross the end of the day.'),
('booking.intent_ledger_cap', 'int', '20'::jsonb, 5, 100, 'entries', 'booking', array['platform'], 'workspaceSettings', null, false, null, 'BookingIntentLedger', 'Guardrail: how many unanswered booking questions one device keeps. A local recovery list, not an owner choice.'),
('billing.max_advance_days', 'int', '28'::jsonb, 0, 28, 'days', 'billing', array['platform'], 'manageBilling', null, false, null, 'BillingRules; subscription run clamp (server)', 'Guardrail: the longest lead, in days, of a subscription invoice before the month starts. The server clamps to the same value.'),
('directory.upcoming_window_days', 'int', '14'::jsonb, 1, 90, 'days', 'directory', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'DirectoryReservationRules', 'How many days ahead the member directory shows the next booking of a member.'),
('presence.online_window_minutes', 'duration', '5'::jsonb, 3, 60, 'minutes', 'presence', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'PresenceRules', 'Minutes after its last heartbeat a person still counts as online. Keep it above the 2-minute heartbeat.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the anchored-patch helpers (session-local) ───────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- Patch a function's live definition: every anchor must be present exactly once.
create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  v_next text;
  v_pattern text;
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if position(p_old[i] in v_def) > 0 then
      if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
        raise exception '0452: anchor % occurs more than once in %', i, p_proc;
      end if;
    else
      v_pattern := regexp_replace(btrim(p_old[i], E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
      v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
      if (select count(*) from regexp_matches(v_def, v_pattern, 'g')) <> 1 then
        raise exception '0452: anchor % not found exactly once in %', i, p_proc;
      end if;
    end if;
    v_next := pg_temp.anchor_replace(v_def, p_old[i], p_new[i]);
    if v_next is null or v_next = v_def then
      raise exception '0452: anchor % did not change %', i, p_proc;
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

-- Same, for an anchor that must occur exactly p_n times (the same text in n branches).
create or replace function pg_temp.patch_function_n(p_proc regprocedure, p_old text, p_new text, p_n int)
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, p_old, ''))) <> length(p_old) * p_n then
    raise exception '0452: anchor does not occur exactly % times in %', p_n, p_proc;
  end if;
  v_next := replace(v_def, p_old, p_new);
  if v_next = v_def then
    raise exception '0452: anchor did not change %', p_proc;
  end if;
  execute v_next;
end
$f$;
revoke execute on function pg_temp.patch_function_n(regprocedure, text, text, int) from public;

-- ── check-in leeway ──────────────────────────────────────────────────────
select pg_temp.patch_function('public.check_in_reservation(uuid)'::regprocedure,
  array[
    $a$v_leeway interval := interval '15 minutes';$a$,
    $a$v_gran := v_rules->>'granularity';$a$],
  array[
    $a$v_leeway interval;$a$,
    $a$v_gran := v_rules->>'granularity';
  v_leeway := make_interval(mins => (public.setting_value(v_res.workspace_id, 'booking.check_in_leeway_minutes') #>> '{}')::int);$a$]);

select pg_temp.patch_function_n(
  'public.kiosk_act(uuid, text, text, uuid, timestamptz, timestamptz, uuid)'::regprocedure,
  $a$and (r.starts_at - interval '15 minutes' <= now()$a$,
  $a$and (r.starts_at - make_interval(mins => (public.setting_value(p_workspace_id, 'booking.check_in_leeway_minutes') #>> '{}')::int) <= now()$a$,
  2);

-- ── check-in reminder lead (the reminder item and its two range bounds) ─────
select pg_temp.patch_function_n(
  'public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure,
  $a$r.starts_at - interval '15 minutes'$a$,
  $a$r.starts_at - make_interval(mins => (public.setting_value(p_workspace_id, 'booking.check_in_reminder_lead_minutes') #>> '{}')::int)$a$,
  3);

select public.set_deskilo_schema_version(452);
