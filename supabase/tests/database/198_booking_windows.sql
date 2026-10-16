-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2486 / 0452 (S3 of #2483): the booking and check-in windows are registry
-- settings; Dart and SQL read the same value. Each scene first proves today's
-- behaviour at the default, then the changed value.
--   A the rows and their defaults; the guardrails refuse a write
--   B the check-in leeway (15 min) at the default, set to 5 for one
--     workspace (another keeps 15), set to 30, and the exact endpoint
--   C the minute grid still widens the leeway: greatest(setting, step)
--   D the check-in reminder lead of the calendar
begin;
select plan(18);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-00002486' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@booking-windows.test', '', now(), now(), now()
  from unnest(array['0001', '0002']) s;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-000024860001');

select pg_temp.act_as('00000000-0000-4000-8000-000024860001');
select set_config('t.w1', public.create_workspace('Windows one', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.w1')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000024860002');
select set_config('t.w2', public.create_workspace('Windows two', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.w2')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));
reset role;
update public.workspaces set booking_rules = booking_rules ||
  '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}',
  feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true}'
 where id in (current_setting('t.w1')::uuid, current_setting('t.w2')::uuid);

-- A value read as the owner of [p_ws] (the reader checks membership).
create function pg_temp.sv(p_user text, p_ws text, p_key text) returns text language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(('00000000-0000-4000-8000-00002486' || p_user)::uuid);
  v := public.setting_value(current_setting(p_ws)::uuid, p_key)::text;
  reset role;
  return v;
end;
$$;
-- A workspace value written the way the server writes it.
create function pg_temp.setv(p_ws text, p_key text, p_value int) returns void language plpgsql as $$
begin
  perform public.store_setting(current_setting(p_ws)::uuid, p_key, to_jsonb(p_value), 'test', null);
end;
$$;

-- A reservation of the owner of workspace [p_ws] starting [p_min] minutes from
-- now (one minute long), on that workspace's first seat.
create function pg_temp.book(p_user text, p_ws text, p_min numeric) returns uuid language plpgsql as $$
declare v_s timestamptz := now() + make_interval(secs => (p_min * 60)::int);
begin
  perform pg_temp.act_as(('00000000-0000-4000-8000-00002486' || p_user)::uuid);
  return public.create_reservation_once(gen_random_uuid(), current_setting(p_ws)::uuid,
    (select id from public.seats where workspace_id = current_setting(p_ws)::uuid order by id limit 1),
    null, null, null, v_s, v_s + interval '1 minute', false);
end;
$$;
-- The refusal text of a check-in by the owner [p_user] right now ('' when it
-- worked; the booking is then cancelled so the next case is not blocked by a
-- person who is already checked in).
create function pg_temp.check_in_error(p_user text, p_res uuid) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(('00000000-0000-4000-8000-00002486' || p_user)::uuid);
  perform public.check_in_reservation(p_res);
  reset role;
  update public.reservations set status = 'cancelled' where id = p_res;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;

-- ── A: the rows ────────────────────────────────────────────────────────
select is((select count(*)::int from public.setting_definitions where key in (
  'booking.check_in_leeway_minutes', 'booking.check_in_reminder_lead_minutes',
  'booking.check_in_reminder_lookahead_days', 'booking.walk_up_window_minutes',
  'booking.walk_up_floor_minutes', 'booking.intent_ledger_cap', 'billing.max_advance_days',
  'directory.upcoming_window_days', 'presence.online_window_minutes')), 9, 'the nine rows exist');
select is(concat_ws('/', public.setting_value(null, 'booking.check_in_leeway_minutes'),
  public.setting_value(null, 'booking.check_in_reminder_lead_minutes'),
  public.setting_value(null, 'booking.check_in_reminder_lookahead_days'),
  public.setting_value(null, 'booking.walk_up_window_minutes'),
  public.setting_value(null, 'booking.walk_up_floor_minutes'),
  public.setting_value(null, 'booking.intent_ledger_cap'),
  public.setting_value(null, 'billing.max_advance_days'),
  public.setting_value(null, 'directory.upcoming_window_days'),
  public.setting_value(null, 'presence.online_window_minutes')),
  '15/15/7/240/15/20/28/14/5', 'the defaults are today''s values');
select pg_temp.act_as('00000000-0000-4000-8000-000024860001');
select throws_like($$ select public.set_setting(null, 'booking.check_in_reminder_lookahead_days', '14', 'x') $$,
  '%', 'the lookahead guardrail refuses a write');
select throws_like($$ select public.set_setting(null, 'booking.intent_ledger_cap', '30', 'x') $$,
  '%', 'the intent cap guardrail refuses a write');
reset role;

-- ── B: the check-in leeway ─────────────────────────────────────────────
select set_config('t.r14', pg_temp.book('0001', 't.w1', 14)::text, true);
select set_config('t.r20', pg_temp.book('0001', 't.w1', 20)::text, true);
reset role;
select is(pg_temp.check_in_error('0001', current_setting('t.r14')::uuid), '', 'golden: 14 minutes before the start, check-in works');
select is(pg_temp.check_in_error('0001', current_setting('t.r20')::uuid), 'check-in window not open yet', 'golden: 20 minutes before the start, it is refused');
select set_config('t.r6', pg_temp.book('0001', 't.w1', 6)::text, true);
select set_config('t.o6', pg_temp.book('0002', 't.w2', 6)::text, true);
reset role;
select pg_temp.setv('t.w1', 'booking.check_in_leeway_minutes', 5);
select is(pg_temp.sv('0001', 't.w1', 'booking.check_in_leeway_minutes'), '5', 'workspace one reads 5');
select is(pg_temp.sv('0002', 't.w2', 'booking.check_in_leeway_minutes'), '15', 'workspace two keeps 15');
select is(pg_temp.check_in_error('0001', current_setting('t.r6')::uuid), 'check-in window not open yet', 'leeway 5: 6 minutes before the start is refused');
select is(pg_temp.check_in_error('0002', current_setting('t.o6')::uuid), '', 'the other workspace still accepts 6 minutes before');
select pg_temp.setv('t.w1', 'booking.check_in_leeway_minutes', 30);
select is(pg_temp.check_in_error('0001', current_setting('t.r20')::uuid), '', 'leeway 30: 20 minutes before the start now works');

-- The exact endpoint: a start exactly [leeway] ahead is refused the instant before
-- it opens and accepted at it (the clock is frozen inside a transaction).
select pg_temp.setv('t.w1', 'booking.check_in_leeway_minutes', 10);
select set_config('t.r10', pg_temp.book('0001', 't.w1', 10.5)::text, true);
select set_config('t.r9', pg_temp.book('0001', 't.w1', 9.5)::text, true);
reset role;
select is(pg_temp.check_in_error('0001', current_setting('t.r10')::uuid), 'check-in window not open yet', 'leeway 10: 10.5 minutes before is refused');
select is(pg_temp.check_in_error('0001', current_setting('t.r9')::uuid), '', 'leeway 10: 9.5 minutes before is accepted');

-- ── C: the grid widens the leeway: greatest(setting, step) ─────────────
select pg_temp.setv('t.w1', 'booking.check_in_leeway_minutes', 5);
select set_config('t.g6', pg_temp.book('0001', 't.w1', 40)::text, true);
select set_config('t.g20', pg_temp.book('0001', 't.w1', 50)::text, true);
reset role;
-- booked on the flexible grid, checked on a 5-minute grid and a 30-minute grid
update public.reservations set starts_at = now() + interval '7 minutes 30 seconds', ends_at = now() + interval '8 minutes 30 seconds'
 where id = current_setting('t.g6')::uuid;
update public.workspaces set booking_rules = booking_rules || '{"granularity":"minutes_5"}'
 where id = current_setting('t.w1')::uuid;
select is(pg_temp.check_in_error('0001', current_setting('t.g6')::uuid), 'check-in window not open yet', 'leeway 5 on a 5-minute grid: 7.5 minutes before is refused');
update public.workspaces set booking_rules = booking_rules || '{"granularity":"minutes_15"}'
 where id = current_setting('t.w1')::uuid;
select is(pg_temp.check_in_error('0001', current_setting('t.g6')::uuid), '', 'leeway 5 on a 15-minute grid: the grid step is the allowance, 7.5 minutes is accepted');
update public.reservations set starts_at = now() + interval '25 minutes', ends_at = now() + interval '26 minutes'
 where id = current_setting('t.g20')::uuid;
update public.workspaces set booking_rules = booking_rules || '{"granularity":"minutes_30"}'
 where id = current_setting('t.w1')::uuid;
select is(pg_temp.check_in_error('0001', current_setting('t.g20')::uuid), '', 'leeway 5 on a 30-minute grid: 25 minutes before is accepted');

-- ── D: the reminder lead ───────────────────────────────────────────────
select set_config('t.d1', pg_temp.book('0002', 't.w2', 90)::text, true);
create function pg_temp.reminder_lead() returns interval language plpgsql as $$
declare v_at timestamptz;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-000024860002');
  select (i->>'at')::timestamptz into v_at
    from jsonb_array_elements(public.calendar_items(current_setting('t.w2')::uuid,
      now(), now() + interval '2 days', array['reminder'], null)->'items') i
   where i->'link'->>'id' = current_setting('t.d1');
  reset role;
  return (select starts_at from public.reservations where id = current_setting('t.d1')::uuid) - v_at;
end;
$$;
reset role;
select is(pg_temp.reminder_lead(), interval '15 minutes', 'golden: the reminder is 15 minutes before the start');
select pg_temp.setv('t.w2', 'booking.check_in_reminder_lead_minutes', 30);
select is(pg_temp.reminder_lead(), interval '30 minutes', 'lead 30: the reminder moves, at once');

select * from finish();
rollback;
