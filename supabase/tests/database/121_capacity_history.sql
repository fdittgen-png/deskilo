-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1920 — a past period keeps the plan, the hours and the bookings it had.
--
-- History began 30 days ago (the fixture shifts what the triggers wrote).
-- Two weeks ago, on a Monday: level L1 held desk D1 (2 seats, booked
-- whole for 2 h), level L2 held desk D2 (seats S21, S22; S22 booked 1 h),
-- hours 08:00-16:00. Today D1 moves to L2, the hours become 08:00-18:00,
-- and S22 is detached from its booking and deleted, as a plan delete
-- does. The past Monday must read as it was; the future as it is now.
begin;
select plan(11);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-00000019200a';
  u_m uuid := '00000000-0000-4000-8000-00000019200b';
  tz text := 'Europe/Paris';
  ws uuid; m_m uuid; l1 uuid; l2 uuid; l3 uuid; o1 uuid; o2 uuid; o3 uuid;
  d1 uuid; d2 uuid; d3 uuid; s22 uuid; s3 uuid; rd uuid; past date; fut date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_o, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'history-owner@deskilo.test', '', now(), now(), now()),
         (u_m, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'history-member@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('History', 'FR', 'EUR', tz, u_o) returning id into ws;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"capacityKpi": true}',
         booking_rules = coalesce(booking_rules, '{}'::jsonb)
           || '{"open_weekdays": [1,2,3,4,5], "work_start_minutes": 480, "work_end_minutes": 960}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin,
                              max_simultaneous_reservations)
  values (ws, u_m, false, false, 10) returning id into m_m;
  insert into public.levels (workspace_id, name) values (ws, 'L1') returning id into l1;
  insert into public.levels (workspace_id, name) values (ws, 'L2') returning id into l2;
  insert into public.levels (workspace_id, name) values (ws, 'L3') returning id into l3;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, l1, 'O1', 0, 0, 10, 10) returning id into o1;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, l2, 'O2', 0, 0, 10, 10) returning id into o2;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, l3, 'O3', 0, 0, 10, 10) returning id into o3;
  insert into public.desks (workspace_id, office_id, x, y, w, h, bookable_as_whole)
  values (ws, o1, 1, 1, 4, 2, true) returning id into d1;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, o2, 1, 1, 4, 2) returning id into d2;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, o3, 1, 1, 4, 2) returning id into d3;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, d1, 1, 1), (ws, d1, 2, 1), (ws, d2, 1, 1);
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, d2, 2, 1) returning id into s22;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, d3, 1, 1) returning id into s3;

  -- The recorded history began 30 days ago.
  update public.analytics_history set since = now() - interval '30 days' where workspace_id = ws;
  update public.seat_history set valid = tstzrange(now() - interval '30 days', null, '[)')
   where workspace_id = ws;
  update public.opening_hours_history set valid = tstzrange(now() - interval '30 days', null, '[)')
   where workspace_id = ws;

  past := (date_trunc('week', now() at time zone tz) - interval '14 days')::date;
  fut := (date_trunc('week', now() at time zone tz) + interval '7 days')::date;

  -- Fixture rows the booking rules would refuse today (a past day; 1200
  -- slots), written past the triggers; their targets as they were booked.
  set local session_replication_role = replica;
  insert into public.reservations (workspace_id, company_id, member_id, desk_id, starts_at, ends_at, status)
  values (ws, ws, m_m, d1, (past + time '09:00') at time zone tz, (past + time '11:00') at time zone tz, 'completed')
  returning id into rd;
  insert into public.reservations (workspace_id, company_id, member_id, seat_id, starts_at, ends_at, status)
  values (ws, ws, m_m, s22, (past + time '09:00') at time zone tz, (past + time '10:00') at time zone tz, 'completed');
  insert into public.reservation_target_history (workspace_id, company_id, reservation_id, desk_id, recorded_at)
  values (ws, ws, rd, d1, now() - interval '20 days');
  insert into public.reservation_target_history (workspace_id, company_id, reservation_id, seat_id, recorded_at)
  select ws, ws, r.id, s22, now() - interval '20 days' from public.reservations r where r.seat_id = s22;
  -- More rows than any API page: 75 weekdays x 16 half-hours on S3.
  insert into public.reservations (workspace_id, company_id, member_id, seat_id, starts_at, ends_at, status)
  select ws, ws, m_m, s3,
         (dd + make_interval(mins => 480 + 30 * k)) at time zone tz,
         (dd + make_interval(mins => 510 + 30 * k)) at time zone tz, 'reserved'
    from (select (fut + i)::timestamp dd from generate_series(0, 200) i
           where extract(isodow from fut + i) < 6 order by 1 limit 75) days,
         generate_series(0, 15) k;
  set local session_replication_role = origin;

  -- Today, through the real writers and their triggers.
  update public.desks set office_id = o2 where id = d1;
  update public.workspaces set booking_rules = booking_rules || '{"work_end_minutes": 1080}' where id = ws;
  update public.reservations set seat_id = null, space_label = 'History · L2 · O2 · D2 · S22'
   where seat_id = s22;
  delete from public.seats where id = s22;

  perform set_config('hist.ws', ws::text, false);
  perform set_config('hist.l1', l1::text, false);
  perform set_config('hist.l2', l2::text, false);
  perform set_config('hist.l3', l3::text, false);
  perform set_config('hist.d1', d1::text, false);
  perform set_config('hist.rd', rd::text, false);
  perform set_config('hist.past', past::text, false);
  perform set_config('hist.fut', fut::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u_o, 'role', 'authenticated')::text, false);
end
$seed$;

-- The KPI for [day + p_start, day + p_end) local days, one level.
create or replace function pg_temp.kpi(p_day text, p_start int, p_end int, p_level text)
returns jsonb language sql as $$
  select public.kpi_seat_capacity(
    current_setting('hist.ws')::uuid,
    ((current_setting(p_day)::date + p_start)::timestamp at time zone 'Europe/Paris'),
    ((current_setting(p_day)::date + p_end)::timestamp at time zone 'Europe/Paris'),
    nullif(current_setting(p_level, true), '')::uuid);
$$;

select pg_temp.seed();

-- ------------------------------------------------- the past, as it was
select is((pg_temp.kpi('hist.past', 0, 1, 'hist.l1') ->> 'offered_seat_hours')::numeric, 16.00,
  'two weeks ago L1 held D1: 2 seats x 8 h, though D1 is on L2 today');
select is((pg_temp.kpi('hist.past', 0, 1, 'hist.l1') ->> 'reserved_seat_hours')::numeric, 4.00,
  'the whole-desk booking binds the seats D1 had then, on the level it was on');
select is((pg_temp.kpi('hist.past', 0, 1, 'hist.l2') ->> 'offered_seat_hours')::numeric, 16.00,
  'L2 then: S21 and the since-deleted S22, under the old 8-hour day');
select is((pg_temp.kpi('hist.past', 0, 1, 'hist.l2') ->> 'reserved_seat_hours')::numeric, 1.00,
  'the detached booking of the deleted seat still counts where it was booked');

-- ------------------------------------------------ the future, as it is
select is((pg_temp.kpi('hist.fut', 0, 1, 'hist.l2') ->> 'seats')::int, 3,
  'L2 now: D1''s two seats and S21');
select is((pg_temp.kpi('hist.fut', 0, 1, 'hist.l2') ->> 'offered_seat_hours')::numeric, 30.00,
  '3 seats x the new 10-hour day');

-- ------------------------------------------------------- completeness
select is((pg_temp.kpi('hist.fut', 0, 120, 'hist.l3') ->> 'reserved_seat_hours')::numeric, 600.00,
  '1200 half-hour bookings = 600 seat-hours: a server aggregate, not a first page');

-- ---------------------------------------------------- unknown history
select is(pg_temp.kpi('hist.past', -30, 1, 'hist.l1') -> 'quality', '["partial"]'::jsonb,
  'a period starting before the history is partial, counted from history_since');
select is(pg_temp.kpi('hist.past', -60, -45, 'hist.l1') -> 'quality', '["not_recorded"]'::jsonb,
  'a period wholly before the history is not recorded, never today''s plan');

-- --------------------------------------------- corrections and capture
update public.reservations set status = 'cancelled' where id = current_setting('hist.rd')::uuid;
select is((pg_temp.kpi('hist.past', 0, 1, 'hist.l1') ->> 'reserved_seat_hours')::numeric, 0.00,
  'a late cancellation counts on the next read: nothing to refresh');
select is((select count(*)::int from public.seat_history
            where desk_id = current_setting('hist.d1')::uuid and upper_inf(valid)
              and level_id = current_setting('hist.l2')::uuid),
  2, 'moving the desk closed its seats'' rows and opened them on the new level');

select * from finish();
rollback;
