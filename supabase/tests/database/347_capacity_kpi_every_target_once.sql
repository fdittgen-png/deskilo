-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2578 — the capacity figure joins reservations to seats one key at a time
-- (0662). A reservation of a seat, a desk, a room or a whole level binds
-- every seat it covers exactly once (the hierarchy guard keeps a seat booking
-- out of a booked level, so no seat is covered twice at the same time).
--
-- 3 seats x 8 opening hours = 24 seat-hours. A level booking 09:00-11:00
-- binds 3 x 2 = 6; a seat booking 13:00-14:00 on one of them adds 1.
begin;
select plan(5);

create function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000257800';
  tz text := 'Europe/Paris';
  ws uuid; m uuid; lv uuid; o uuid; dk uuid; s uuid[] := '{}'; x uuid; i int; d date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'kpi-once@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('KPI once', 'FR', 'EUR', tz, u) returning id into ws;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"capacityKpi": true}',
         booking_rules = coalesce(booking_rules, '{}'::jsonb)
           || '{"open_weekdays": [1,2,3,4,5], "work_start_minutes": 480, "work_end_minutes": 960}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.levels (workspace_id, name) values (ws, 'L1') returning id into lv;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lv, 'O1', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, o, 1, 1, 4, 2) returning id into dk;
  for i in 1..3 loop
    insert into public.seats (workspace_id, desk_id, x, y) values (ws, dk, i, 1)
    returning id into x;
    s := s || x;
  end loop;
  d := (date_trunc('week', now() at time zone tz) + interval '7 days')::date;
  insert into public.reservations (workspace_id, member_id, level_id, starts_at, ends_at)
  values (ws, m, lv, (d + time '09:00') at time zone tz, (d + time '11:00') at time zone tz);
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (ws, m, s[1], (d + time '13:00') at time zone tz, (d + time '14:00') at time zone tz);
  perform set_config('kpi.ws', ws::text, false);
  perform set_config('kpi.from', (d::timestamp at time zone tz)::text, false);
  perform set_config('kpi.to', ((d + 1)::timestamp at time zone tz)::text, false);
  perform set_config('kpi.owner', u::text, false);
end
$seed$;
select pg_temp.seed();
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('kpi.owner'), 'role', 'authenticated')::text, true);

create function pg_temp.kpi() returns jsonb language sql as $$
  select public.kpi_seat_capacity(current_setting('kpi.ws')::uuid,
    current_setting('kpi.from')::timestamptz, current_setting('kpi.to')::timestamptz, null);
$$;
-- END FIXTURE

select is((pg_temp.kpi() ->> 'seats')::int, 3, 'the three seats are the scope');
select is((pg_temp.kpi() ->> 'physical_seat_hours')::numeric, 24.00,
  '3 seats x 8 opening hours');
select is((pg_temp.kpi() ->> 'reserved_seat_hours')::numeric, 7.00,
  'the level booking binds each seat once (6) and the seat booking adds its own hour (1)');
select is((pg_temp.kpi() ->> 'overlapping_seat_hours')::numeric, 0.00,
  'no hour is covered twice, so there is no overlap');
select is((pg_temp.kpi() ->> 'reserved_room_hours')::numeric, 0.00,
  'a room with seats counts no room-hours');

select * from finish();
rollback;
