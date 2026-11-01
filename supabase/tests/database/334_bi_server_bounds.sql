-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2578 — the server side of the edges bi_bounds_history_test pins in the
-- client (#3193), through bi_query_batch_v1 with the payload the app sends
-- (request_key, metric_id, metric_version, from/to as UTC ISO instants,
-- level_id; from_month/to_month for the finance figures).
--
--   1. A monthly series from March to November 2026 crosses both Paris
--      clock changes: the server holds each month at local midnight of its
--      first day, neighbours meet, March has 743 open hours and October
--      745, the months add up to the whole span, and a booking or a matched
--      payment at 00:30 local falls in its local month (1 April and
--      1 November are still March and October in UTC).
--   2. Leap years: February 2028 counts 29 days, February 2027 28; the
--      quarters and the year of 2028 meet at the months' instants and add
--      up to them.
--   3. A floor that exists only in the history: the floors the client asks
--      for are today's, the total still holds the closed floor, so its share
--      is the remainder (total 50/100, today's floor 20/40, remainder
--      30/60), and asked by its own id it answers its own figure.
--   4. Two workspaces with the same plan, the same request keys and bounds:
--      each batch answers its own workspace; a level of the other space is
--      refused on its own (22023), another space's batch is refused whole
--      (42501), and nothing of one ever appears in the other's answers.
--
-- Fixture rows the booking rules would refuse (past days) are written past
-- the triggers; every date is fixed. Real roles for the reads.
begin;
select plan(23);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-000025783341';
  u_b uuid := '00000000-0000-4000-8000-000025783342';
  tz text := 'Europe/Paris';
  ws_a uuid; ws_b uuid; ws_h uuid; m_a uuid; m_b uuid; m_h uuid;
  l_a uuid; l_b uuid; l_now uuid; l_gone uuid;
  o uuid; d uuid; d_gone uuid; o_gone uuid; s_a uuid; s_b uuid;
  inv_a uuid; inv_b uuid; pay uuid; r record; i int;
  s_now uuid[] := '{}'; s_gone uuid[] := '{}'; s uuid;
  flags jsonb := '{"capacityKpi": true, "workspaceStatus": true, "invoicing": true, "moneyTab": true}';
  -- Open every day, all day: an hour of the calendar is an open hour.
  all_day jsonb := '{"open_weekdays": [1,2,3,4,5,6,7], "work_start_minutes": 0, "work_end_minutes": 1440}';
  day_10h jsonb := '{"open_weekdays": [1,2,3,4,5,6,7], "work_start_minutes": 480, "work_end_minutes": 1080}';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'bounds-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_a, u_b]) u;
  -- u_a owns W-A and W-H; u_b owns W-B.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Bounds A', 'FR', 'EUR', tz, u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Bounds B', 'FR', 'EUR', tz, u_b) returning id into ws_b;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Bounds H', 'FR', 'EUR', tz, u_a) returning id into ws_h;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb) || flags,
         booking_rules = coalesce(booking_rules, '{}'::jsonb)
                         || case when id = ws_h then day_10h else all_day end
   where id in (ws_a, ws_b, ws_h);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws_a, u_a, true, true, 'active', '2025-01-01') returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws_b, u_b, true, true, 'active', '2025-01-01') returning id into m_b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws_h, u_a, true, true, 'active', '2025-01-01') returning id into m_h;

  -- W-A and W-B: the same plan, one floor "Floor 1" with one seat.
  insert into public.levels (workspace_id, name, sort_order) values (ws_a, 'Floor 1', 0) returning id into l_a;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws_a, l_a, 'Room', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h) values (ws_a, o, 1, 1, 4, 2) returning id into d;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws_a, d, 1, 1) returning id into s_a;
  insert into public.levels (workspace_id, name, sort_order) values (ws_b, 'Floor 1', 0) returning id into l_b;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws_b, l_b, 'Room', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h) values (ws_b, o, 1, 1, 4, 2) returning id into d;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws_b, d, 1, 1) returning id into s_b;

  -- W-H: today's floor "Now" (4 seats) and "Gone" (6 seats), closed since.
  insert into public.levels (workspace_id, name, sort_order) values (ws_h, 'Now', 0) returning id into l_now;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws_h, l_now, 'Room now', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h) values (ws_h, o, 1, 1, 8, 2) returning id into d;
  for i in 1..4 loop
    insert into public.seats (workspace_id, desk_id, x, y) values (ws_h, d, i, 1) returning id into s;
    s_now := s_now || s;
  end loop;
  insert into public.levels (workspace_id, name, sort_order) values (ws_h, 'Gone', 1) returning id into l_gone;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws_h, l_gone, 'Room gone', 0, 0, 10, 10) returning id into o_gone;
  insert into public.desks (workspace_id, office_id, x, y, w, h) values (ws_h, o_gone, 1, 1, 8, 2) returning id into d_gone;
  for i in 1..6 loop
    insert into public.seats (workspace_id, desk_id, x, y) values (ws_h, d_gone, i, 1) returning id into s;
    s_gone := s_gone || s;
  end loop;

  -- The recorded history began on 1 January 2025 (the fixture shifts what
  -- the triggers wrote).
  update public.analytics_history set since = '2025-01-01 00:00+01'
   where workspace_id in (ws_a, ws_b, ws_h);
  update public.seat_history set valid = tstzrange('2025-01-01 00:00+01', null, '[)')
   where workspace_id in (ws_a, ws_b, ws_h);
  update public.opening_hours_history set valid = tstzrange('2025-01-01 00:00+01', null, '[)')
   where workspace_id in (ws_a, ws_b, ws_h);

  set local session_replication_role = replica;
  -- W-A: an hour at 00:30 local on both change days and on the first day
  -- after each, and an hour on the leap day.
  insert into public.reservations (workspace_id, company_id, member_id, seat_id, starts_at, ends_at, status)
  select ws_a, ws_a, m_a, s_a, t::timestamp at time zone tz, (t::timestamp + interval '1 hour') at time zone tz, st
    from (values ('2026-03-29 00:30', 'completed'), ('2026-04-01 00:30', 'completed'),
                 ('2026-10-25 00:30', 'completed'), ('2026-11-01 00:30', 'completed'),
                 ('2028-02-29 12:00', 'reserved')) v(t, st);
  -- W-B: nine hours in March, on its own floor.
  insert into public.reservations (workspace_id, company_id, member_id, seat_id, starts_at, ends_at, status)
  values (ws_b, ws_b, m_b, s_b, timestamp '2026-03-10 10:00' at time zone tz,
          timestamp '2026-03-10 19:00' at time zone tz, 'completed');
  -- W-H on Monday 5 January 2026: two seats of Now and three of Gone,
  -- booked for the whole 10-hour day.
  foreach s in array s_now[1:2] || s_gone[1:3] loop
    insert into public.reservations (workspace_id, company_id, member_id, seat_id, starts_at, ends_at, status)
    values (ws_h, ws_h, m_h, s, timestamp '2026-01-05 08:00' at time zone tz,
            timestamp '2026-01-05 18:00' at time zone tz, 'completed');
  end loop;
  insert into public.reservation_target_history (workspace_id, company_id, reservation_id, seat_id, recorded_at)
  select ws_h, ws_h, x.id, x.seat_id, timestamptz '2025-12-20 10:00+01'
    from public.reservations x where x.seat_id = any (s_gone);
  set local session_replication_role = origin;

  -- Gone closes, as a plan delete does: its bookings are detached, its
  -- seats, desk, room and floor deleted.
  update public.reservations set seat_id = null, space_label = 'Bounds H · Gone'
   where seat_id = any (s_gone);
  delete from public.seats where id = any (s_gone);
  delete from public.desks where id = d_gone;
  delete from public.offices where id = o_gone;
  delete from public.levels where id = l_gone;

  -- Matched payments (the collected figure) at the same edges in W-A, one
  -- in March in W-B.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
                               lines, total_cents, currency, member_name, workspace_name,
                               issuer_name, signature, period, kind)
  values (ws_a, m_a, m_a, 'A-1', 'March', '[]', 900000, 'EUR', 'Payer A', 'Bounds A', 'A', 's', '2026-03', 'full')
  returning id into inv_a;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
                               lines, total_cents, currency, member_name, workspace_name,
                               issuer_name, signature, period, kind)
  values (ws_b, m_b, m_b, 'B-1', 'March', '[]', 900000, 'EUR', 'Payer B', 'Bounds B', 'B', 's', '2026-03', 'full')
  returning id into inv_b;
  for r in select * from (values
      (ws_a, m_a, inv_a, 101, '2026-03-29 00:30'),
      (ws_a, m_a, inv_a, 202, '2026-04-01 00:30'),
      (ws_a, m_a, inv_a, 303, '2026-10-25 00:30'),
      (ws_a, m_a, inv_a, 404, '2026-11-01 00:30'),
      (ws_a, m_a, inv_a, 505, '2028-02-29 23:30'),
      (ws_a, m_a, inv_a, 606, '2028-03-01 00:30'),
      (ws_b, m_b, inv_b, 777, '2026-03-15 12:00')) v(ws, m, inv, amount, local_at) loop
    insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                       amount_cents, description, period)
    values (r.ws, r.m, 'credit', 'payment', r.amount, 'bank transfer', left(r.local_at, 7))
    returning id into pay;
    insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id,
                                               amount_cents, resolution, matched_at)
    values (r.ws, r.inv, pay, r.amount, 'under_accepted', r.local_at::timestamp at time zone tz);
  end loop;

  perform set_config('t.a', ws_a::text, true);
  perform set_config('t.b', ws_b::text, true);
  perform set_config('t.h', ws_h::text, true);
  perform set_config('t.ua', u_a::text, true);
  perform set_config('t.ub', u_b::text, true);
  perform set_config('t.la', l_a::text, true);
  perform set_config('t.lb', l_b::text, true);
  perform set_config('t.lnow', l_now::text, true);
  perform set_config('t.lgone', l_gone::text, true);
end
$seed$;

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
-- One batch as p_user for the workspace named by p_ws, or why it was refused.
create function pg_temp.batch(p_user text, p_ws text, p_requests jsonb) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(current_setting(p_user)::uuid);
  execute format('select public.bi_query_batch_v1(%L, %L::jsonb)',
                 current_setting(p_ws), p_requests::text) into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm, 'code', sqlstate);
end;
$$;
-- Local midnight of the first day of month p_m of year p_y (p_m may run
-- past 12), the bound the client's biInterval computes.
create function pg_temp.m(p_y int, p_m int) returns timestamptz language sql as $$
  select (make_date(p_y, 1, 1) + make_interval(months => p_m - 1))::timestamp at time zone 'Europe/Paris';
$$;
-- A capacity request as BiBatchRequest.toJson writes it.
create function pg_temp.cap(p_key text, p_from timestamptz, p_to timestamptz, p_level text default null)
returns jsonb language sql as $$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'capacity.seat_utilisation',
    'metric_version', 1,
    'from', to_char(p_from at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS".000Z"'),
    'to', to_char(p_to at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS".000Z"'))
    || case when p_level is null then '{}'::jsonb else jsonb_build_object('level_id', p_level) end;
$$;
create function pg_temp.fin(p_key text, p_from text, p_to text) returns jsonb language sql as $$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'finance.collected',
    'metric_version', 1, 'from_month', p_from, 'to_month', p_to);
$$;
-- The answer to request p_key of a stored batch.
create function pg_temp.res(p_batch text, p_key text) returns jsonb language sql as $$
  select x from jsonb_array_elements(current_setting(p_batch)::jsonb -> 'results') x
   where x ->> 'request_key' = p_key;
$$;
create function pg_temp.hours(p_batch text, p_key text, p_field text) returns int language sql as $$
  select (pg_temp.res(p_batch, p_key) -> 'result' ->> p_field)::numeric::int;
$$;
create function pg_temp.bound(p_batch text, p_key text, p_field text) returns timestamptz language sql as $$
  select (pg_temp.res(p_batch, p_key) -> 'result' ->> p_field)::timestamptz;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- ------------------------------------------- 1. both Paris clock changes
-- Months March..November 2026 (keys m0..m8), the whole span, and the
-- collected figure of each month (keys f0..f8), in one batch.
select set_config('t.dst', pg_temp.batch('t.ua', 't.a',
  (select jsonb_agg(pg_temp.cap('m' || k, pg_temp.m(2026, 3 + k), pg_temp.m(2026, 4 + k)) order by k)
     from generate_series(0, 8) k)
  || jsonb_build_array(pg_temp.cap('all', pg_temp.m(2026, 3), pg_temp.m(2026, 12)))
  || (select jsonb_agg(pg_temp.fin('f' || k, to_char(make_date(2026, 3 + k, 1), 'YYYY-MM'),
                                   to_char(make_date(2026, 3 + k, 1), 'YYYY-MM')) order by k)
        from generate_series(0, 8) k))::text, true);

select is((select count(*)::int from generate_series(0, 8) k
            where pg_temp.res('t.dst', 'm' || k) -> 'result' ->> 'timezone' = 'Europe/Paris'
              and (pg_temp.bound('t.dst', 'm' || k, 'from') at time zone 'Europe/Paris')
                  = make_date(2026, 3 + k, 1)::timestamp),
  9, 'D1 every month is held from local midnight of its first day in the workspace zone');
select is(pg_temp.bound('t.dst', 'm0', 'from') || ' .. ' || pg_temp.bound('t.dst', 'm8', 'to'),
  timestamptz '2026-02-28 23:00+00' || ' .. ' || timestamptz '2026-11-30 23:00+00',
  'D2 the series runs from 28 Feb 23:00 UTC to 30 Nov 23:00 UTC, as the client asks');
select is((select count(*)::int from generate_series(1, 8) k
            where pg_temp.bound('t.dst', 'm' || k, 'from') = pg_temp.bound('t.dst', 'm' || (k - 1), 'to')),
  8, 'D3 consecutive months meet: no gap, no overlap');
select is((select string_agg(pg_temp.hours('t.dst', 'm' || k, 'physical_seat_hours')::text, ',' order by k)
             from generate_series(0, 8) k),
  '743,720,744,720,744,744,720,745,720',
  'D4 open hours per month: March loses the hour, October gains it');
select is((select sum(pg_temp.hours('t.dst', 'm' || k, 'physical_seat_hours'))::int from generate_series(0, 8) k)
          || '/' || pg_temp.hours('t.dst', 'all', 'physical_seat_hours'),
  '6600/6600', 'D5 the months add up to the whole span, which is 275 days of 24 hours');
select is((select string_agg(pg_temp.hours('t.dst', 'm' || k, 'reserved_seat_hours')::text, ',' order by k)
             from generate_series(0, 8) k),
  '1,1,0,0,0,0,0,1,1',
  'D6 a booking at 00:30 local counts in its local month (1 April and 1 November are not March and October)');
select is((select string_agg(pg_temp.res('t.dst', 'f' || k) -> 'result' ->> 'collected_minor', ',' order by k)
             from generate_series(0, 8) k),
  '101,202,0,0,0,0,0,303,404',
  'D7 a payment matched at 00:30 local is collected in its local month');

-- --------------------------------------------------------- 2. leap years
-- Months January..March 2028 (j1..j3), February 2027 (c2), quarters of
-- 2028 (q1..q4), the year 2028 (y), and the collected figures.
select set_config('t.leap', pg_temp.batch('t.ua', 't.a',
  (select jsonb_agg(pg_temp.cap('j' || k, pg_temp.m(2028, k), pg_temp.m(2028, k + 1)) order by k)
     from generate_series(1, 3) k)
  || jsonb_build_array(pg_temp.cap('c2', pg_temp.m(2027, 2), pg_temp.m(2027, 3)))
  || (select jsonb_agg(pg_temp.cap('q' || k, pg_temp.m(2028, 3 * k - 2), pg_temp.m(2028, 3 * k + 1)) order by k)
        from generate_series(1, 4) k)
  || jsonb_build_array(pg_temp.cap('y', pg_temp.m(2028, 1), pg_temp.m(2029, 1)),
       pg_temp.fin('f2', '2028-02', '2028-02'), pg_temp.fin('f3', '2028-03', '2028-03'),
       pg_temp.fin('fq1', '2028-01', '2028-03'), pg_temp.fin('fc2', '2027-02', '2027-02')))::text, true);

select is((pg_temp.hours('t.leap', 'j2', 'physical_seat_hours') / 24) || ',' ||
          (pg_temp.hours('t.leap', 'c2', 'physical_seat_hours') / 24),
  '29,28', 'L1 February 2028 counts 29 days, February 2027 28');
select ok(pg_temp.bound('t.leap', 'q1', 'from') = pg_temp.bound('t.leap', 'j1', 'from')
          and pg_temp.bound('t.leap', 'q1', 'to') = pg_temp.bound('t.leap', 'j3', 'to')
          and pg_temp.bound('t.leap', 'q2', 'from') = pg_temp.bound('t.leap', 'q1', 'to')
          and pg_temp.bound('t.leap', 'q3', 'from') = pg_temp.bound('t.leap', 'q2', 'to')
          and pg_temp.bound('t.leap', 'q4', 'from') = pg_temp.bound('t.leap', 'q3', 'to')
          and pg_temp.bound('t.leap', 'y', 'from') = pg_temp.bound('t.leap', 'q1', 'from')
          and pg_temp.bound('t.leap', 'y', 'to') = pg_temp.bound('t.leap', 'q4', 'to'),
  'L2 the quarters and the year of 2028 meet at the instants of their months');
select is(pg_temp.hours('t.leap', 'q1', 'physical_seat_hours') || '=' ||
          (pg_temp.hours('t.leap', 'j1', 'physical_seat_hours') + pg_temp.hours('t.leap', 'j2', 'physical_seat_hours')
           + pg_temp.hours('t.leap', 'j3', 'physical_seat_hours')),
  '2183=2183', 'L3 Q1 2028 is its three months: 91 days less the March hour');
select is((select sum(pg_temp.hours('t.leap', 'q' || k, 'physical_seat_hours'))::int from generate_series(1, 4) k)
          || '/' || pg_temp.hours('t.leap', 'y', 'physical_seat_hours'),
  '8784/8784', 'L4 the quarters add up to the year: 366 days of 24 hours');
select is(pg_temp.hours('t.leap', 'j2', 'reserved_seat_hours') || ',' || pg_temp.hours('t.leap', 'j3', 'reserved_seat_hours')
          || ' ' || (pg_temp.res('t.leap', 'f2') -> 'result' ->> 'collected_minor')
          || ',' || (pg_temp.res('t.leap', 'f3') -> 'result' ->> 'collected_minor')
          || ',' || (pg_temp.res('t.leap', 'fq1') -> 'result' ->> 'collected_minor')
          || ',' || (pg_temp.res('t.leap', 'fc2') -> 'result' ->> 'collected_minor'),
  '1,0 505,606,1111,0',
  'L5 the leap day belongs to February; 1 March 00:30 local (still 29 February in UTC) to March');

-- ---------------------------------------- 3. a floor only in the history
-- What the client asks: the floors it reads today, then the total and one
-- figure per floor.
select pg_temp.act_as(current_setting('t.ua')::uuid);
select set_config('t.floors', (select coalesce(string_agg(l.id::text || '=' || l.name, ',' order by l.sort_order), '')
                                 from public.levels l where l.workspace_id = current_setting('t.h')::uuid), true);
reset role;
select set_config('t.hist', pg_temp.batch('t.ua', 't.h', jsonb_build_array(
  pg_temp.cap('0', timestamptz '2026-01-05 00:00+01', timestamptz '2026-01-06 00:00+01'),
  pg_temp.cap('1', timestamptz '2026-01-05 00:00+01', timestamptz '2026-01-06 00:00+01', current_setting('t.lnow')),
  pg_temp.cap('gone', timestamptz '2026-01-05 00:00+01', timestamptz '2026-01-06 00:00+01', current_setting('t.lgone'))))::text, true);

select is(current_setting('t.floors'), current_setting('t.lnow') || '=Now',
  'H1 the floors read today are only Now: the closed floor is not asked for');
select is(pg_temp.hours('t.hist', '0', 'reserved_seat_hours') || '/' || pg_temp.hours('t.hist', '0', 'offered_seat_hours'),
  '50/100', 'H2 the total still holds the closed floor');
select is(pg_temp.hours('t.hist', '1', 'reserved_seat_hours') || '/' || pg_temp.hours('t.hist', '1', 'offered_seat_hours'),
  '20/40', 'H3 today''s floor is its own share');
select is((pg_temp.hours('t.hist', '0', 'reserved_seat_hours') - pg_temp.hours('t.hist', '1', 'reserved_seat_hours'))
          || '/' || (pg_temp.hours('t.hist', '0', 'offered_seat_hours') - pg_temp.hours('t.hist', '1', 'offered_seat_hours')),
  '30/60', 'H4 the closed floor''s share stays in the remainder, not lost');
select is((pg_temp.res('t.hist', 'gone') ->> 'ok') || ' ' || pg_temp.hours('t.hist', 'gone', 'reserved_seat_hours')
          || '/' || pg_temp.hours('t.hist', 'gone', 'offered_seat_hours') || ' seats ' || pg_temp.hours('t.hist', 'gone', 'seats'),
  'true 30/60 seats 6', 'H5 asked by its own id, the closed floor answers its own figure, not today''s floor');

-- --------------------------------------- 4. two spaces, the same request
-- The same keys and bounds; each owner names its own floor.
select set_config('t.wa', pg_temp.batch('t.ua', 't.a', jsonb_build_array(
  pg_temp.cap('0', pg_temp.m(2026, 3), pg_temp.m(2026, 4)),
  pg_temp.cap('1', pg_temp.m(2026, 3), pg_temp.m(2026, 4), current_setting('t.la')),
  pg_temp.fin('2', '2026-03', '2026-03')))::text, true);
select set_config('t.wb', pg_temp.batch('t.ub', 't.b', jsonb_build_array(
  pg_temp.cap('0', pg_temp.m(2026, 3), pg_temp.m(2026, 4)),
  pg_temp.cap('1', pg_temp.m(2026, 3), pg_temp.m(2026, 4), current_setting('t.lb')),
  pg_temp.fin('2', '2026-03', '2026-03')))::text, true);
-- W-B asking for W-A's floor; W-A's owner asking W-B; a W-A batch naming
-- the floors of both.
select set_config('t.wb_x', pg_temp.batch('t.ub', 't.b', jsonb_build_array(
  pg_temp.cap('1', pg_temp.m(2026, 3), pg_temp.m(2026, 4), current_setting('t.la'))))::text, true);
select set_config('t.wa_on_b', pg_temp.batch('t.ua', 't.b', jsonb_build_array(
  pg_temp.cap('0', pg_temp.m(2026, 3), pg_temp.m(2026, 4))))::text, true);
select set_config('t.wa_mix', pg_temp.batch('t.ua', 't.a', jsonb_build_array(
  pg_temp.cap('1', pg_temp.m(2026, 3), pg_temp.m(2026, 4), current_setting('t.la')),
  pg_temp.cap('2', pg_temp.m(2026, 3), pg_temp.m(2026, 4), current_setting('t.lb'))))::text, true);

select is(pg_temp.hours('t.wa', '0', 'reserved_seat_hours') || '|' || pg_temp.hours('t.wa', '1', 'reserved_seat_hours')
          || '|' || (pg_temp.res('t.wa', '2') -> 'result' ->> 'collected_minor'),
  '1|1|101', 'W1 W-A''s batch answers W-A''s figures');
select is(pg_temp.hours('t.wb', '0', 'reserved_seat_hours') || '|' || pg_temp.hours('t.wb', '1', 'reserved_seat_hours')
          || '|' || (pg_temp.res('t.wb', '2') -> 'result' ->> 'collected_minor'),
  '9|9|777', 'W2 the same request to W-B answers W-B''s figures');
select is((pg_temp.res('t.wb_x', '1') ->> 'ok') || ' ' || (pg_temp.res('t.wb_x', '1') ->> 'code')
          || ' ' || (pg_temp.res('t.wb_x', '1') ? 'result')::text,
  'false 22023 false', 'W3 a floor of the other space is refused on its own, with no figure');
select is((current_setting('t.wa_on_b')::jsonb ->> 'code') || ' ' || (current_setting('t.wa_on_b')::jsonb ? 'results')::text,
  '42501 false', 'W4 a batch for a space one is not a member of is refused whole');
select is((select string_agg((x ->> 'request_key') || ':' || (x ->> 'ok') || ':' || coalesce(x ->> 'code', ''), ',' order by ord)
             from jsonb_array_elements(current_setting('t.wa_mix')::jsonb -> 'results') with ordinality t(x, ord)),
  '1:true:,2:false:22023', 'W5 a batch naming both spaces'' floors answers its own and refuses the other');
select ok(not jsonb_path_exists(jsonb_build_array(current_setting('t.wa')::jsonb, current_setting('t.wa_mix')::jsonb,
                                                  current_setting('t.wa_on_b')::jsonb),
            '$[*].results[*].result ? (@.reserved_seat_hours == 9 || @.collected_minor == "777" || @.level_id == $lb)',
            jsonb_build_object('lb', current_setting('t.lb')))
          and not jsonb_path_exists(jsonb_build_array(current_setting('t.wb')::jsonb, current_setting('t.wb_x')::jsonb),
            '$[*].results[*].result ? (@.reserved_seat_hours == 1 || @.collected_minor == "101" || @.level_id == $la)',
            jsonb_build_object('la', current_setting('t.la'))),
  'W6 no answer to one space carries the other''s figures or floor');

select * from finish();
rollback;
