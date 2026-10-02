-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1918 — capacity.seat_utilisation against an independently counted
-- fixture, and who may read it.
--
-- 10 seats (a whole-bookable desk of 4, a desk of 6) x 8 opening hours =
-- 80 seat-hours; two seats blocked 2 h each = 76 offered. The whole desk
-- for 2 h binds 8 seat-hours (not 2, not more); one seat-hour on another
-- seat; a seat booked 15:00-17:00 adds 1 inside and 1 outside the
-- offered hours; a cancelled booking adds nothing. A room with no seat
-- is counted in room-hours: 8 offered, 3 reserved.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-00000019180a';
  u_m uuid := '00000000-0000-4000-8000-00000019180b';
  u_x uuid := '00000000-0000-4000-8000-00000019180c';
  tz text := 'Europe/Paris';
  ws uuid; ws2 uuid; m_m uuid; lv uuid; lv2 uuid; o1 uuid; o2 uuid;
  da uuid; db uuid; sb uuid[] := '{}'; s uuid; i int; d date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_o, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'kpi-owner@deskilo.test', '', now(), now(), now()),
         (u_m, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'kpi-member@deskilo.test', '', now(), now(), now()),
         (u_x, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'kpi-stranger@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('KPI', 'FR', 'EUR', tz, u_o) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('KPI other', 'FR', 'EUR', tz, u_x) returning id into ws2;
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
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws2, u_x, true, true);

  insert into public.levels (workspace_id, name) values (ws, 'L1') returning id into lv;
  insert into public.levels (workspace_id, name) values (ws, 'L2') returning id into lv2;
  insert into public.levels (workspace_id, name) values (ws2, 'X');
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lv, 'O1', 0, 0, 10, 10) returning id into o1;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h, bookable_as_whole)
  values (ws, lv, 'O2', 20, 0, 10, 10, true) returning id into o2;
  insert into public.desks (workspace_id, office_id, x, y, w, h, bookable_as_whole)
  values (ws, o1, 1, 1, 4, 2, true) returning id into da;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, o1, 1, 5, 6, 2) returning id into db;
  for i in 1..4 loop
    insert into public.seats (workspace_id, desk_id, x, y) values (ws, da, i, 1);
  end loop;
  for i in 1..6 loop
    insert into public.seats (workspace_id, desk_id, x, y)
    values (ws, db, i, 5) returning id into s;
    sb := sb || s;
  end loop;

  -- Next Monday on the workspace clock: in the future, so the answer is
  -- not qualified as resting on today's plan.
  d := (date_trunc('week', now() at time zone tz) + interval '7 days')::date;
  update public.seats
     set blocked_from = (d + time '10:00') at time zone tz,
         blocked_to = (d + time '12:00') at time zone tz
   where id in (sb[1], sb[2]);
  insert into public.reservations (workspace_id, member_id, desk_id, starts_at, ends_at)
  values (ws, m_m, da, (d + time '09:00') at time zone tz, (d + time '11:00') at time zone tz);
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (ws, m_m, sb[3], (d + time '09:00') at time zone tz, (d + time '10:00') at time zone tz),
         (ws, m_m, sb[4], (d + time '15:00') at time zone tz, (d + time '17:00') at time zone tz);
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at, status)
  values (ws, m_m, sb[5], (d + time '09:00') at time zone tz, (d + time '16:00') at time zone tz, 'cancelled');
  insert into public.reservations (workspace_id, member_id, office_id, starts_at, ends_at)
  values (ws, m_m, o2, (d + time '09:00') at time zone tz, (d + time '12:00') at time zone tz);

  perform set_config('kpi.ws', ws::text, false);
  perform set_config('kpi.lv2', lv2::text, false);
  perform set_config('kpi.foreign_level',
    (select id::text from public.levels where workspace_id = ws2), false);
  perform set_config('kpi.from', (d::timestamp at time zone tz)::text, false);
  perform set_config('kpi.to', ((d + 1)::timestamp at time zone tz)::text, false);
  perform set_config('kpi.owner', u_o::text, false);
  perform set_config('kpi.member', u_m::text, false);
  perform set_config('kpi.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('kpi.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.kpi(p_level text default null) returns jsonb
language sql as $$
  select public.kpi_seat_capacity(current_setting('kpi.ws')::uuid,
                                  current_setting('kpi.from')::timestamptz,
                                  current_setting('kpi.to')::timestamptz,
                                  p_level::uuid);
$$;

select pg_temp.seed();

-- ------------------------------------------------------------- who
select pg_temp.act_as('stranger');
select throws_matching($$ select pg_temp.kpi() $$, 'not allowed',
  'another workspace''s owner may not read these figures');
select pg_temp.act_as('member');
select throws_matching($$ select pg_temp.kpi() $$, 'not allowed',
  'a member without manageReservations may not read them');

select pg_temp.act_as('owner');
select throws_matching($$ select pg_temp.kpi(current_setting('kpi.foreign_level')) $$,
  'unknown level', 'a level of another workspace is refused, not computed');

-- ----------------------------------------------------------- numbers
select is((pg_temp.kpi() ->> 'physical_seat_hours')::numeric, 80.00,
  '10 seats x 8 opening hours = 80 physical seat-hours');
select is((pg_temp.kpi() ->> 'offered_seat_hours')::numeric, 76.00,
  'two seats blocked 2 h each leave 76 offered seat-hours');
select is((pg_temp.kpi() ->> 'reserved_seat_hours')::numeric, 10.00,
  'the whole desk binds its 4 seats once (8) + 1 + 1 inside the hours; '
  'the cancelled booking adds nothing');
select is((pg_temp.kpi() ->> 'reserved_outside_offered_seat_hours')::numeric, 1.00,
  'the hour booked after closing is shown beside the ratio, not clamped away');
select is((pg_temp.kpi() ->> 'reserved_room_hours')::numeric, 3.00,
  'the seatless room counts room-hours, never seat-hours');
select is(pg_temp.kpi() -> 'quality', '[]'::jsonb,
  'a future period with bookings is neither partial nor zero');
select is(pg_temp.kpi(current_setting('kpi.lv2')) -> 'quality', '["not_applicable"]'::jsonb,
  'a level with no seat offers nothing: undefined, not 0 %');

-- ------------------------------------------------------ the DST day
update public.workspaces
   set booking_rules = booking_rules
     || '{"open_weekdays": [1,2,3,4,5,6,7], "work_start_minutes": 0, "work_end_minutes": 1440}'
 where id = current_setting('kpi.ws')::uuid;
select is((public.kpi_seat_capacity(current_setting('kpi.ws')::uuid,
            '2027-03-28'::timestamp at time zone 'Europe/Paris',
            '2027-03-29'::timestamp at time zone 'Europe/Paris') ->> 'physical_seat_hours')::numeric,
  230.00, 'the spring-forward day has 23 hours: 10 seats x 23');

-- ------------------------------------------------------ the switch
update public.workspaces set feature_flags = feature_flags || '{"capacityKpi": false}'
 where id = current_setting('kpi.ws')::uuid;
select throws_matching($$ select pg_temp.kpi() $$, 'not enabled',
  'with capacityKpi off even the owner is refused');

select * from finish();
rollback;
