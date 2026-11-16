-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3967 (0791) -- the price read learns the extra half-days of all its
-- member-months in one pass. The gate is the equality: for EVERY member-month
-- of this fixture, member_months_extra_half_days equals
-- member_statement(...)->'extra_half_days', so a later change to either side
-- that breaks it fails here. The fixture covers a full share, a small share
-- over its quota, a share of 0, a member who joins later, credits used, two
-- halves of one day, two months, and a business that counts by the hour. A
-- business of 200 members prints its timing and asserts its result. Rolled
-- back.
begin;
select plan(8);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003967' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'onepass' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, booking_rules)
values (pg_temp.u(101), 'One pass slots', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}'),
       (pg_temp.u(102), 'One pass hours', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2),
        '{"granularity": "hours", "half_day_hours": 4}'),
       (pg_temp.u(103), 'One pass many', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', now() - interval '1 year'),
       (pg_temp.u(202), pg_temp.u(102), pg_temp.u(2), true, true, 'active', now() - interval '1 year'),
       (pg_temp.u(203), pg_temp.u(103), pg_temp.u(3), true, true, 'active', now() - interval '1 year');
-- slots: 211 full share, 212 share 5 (over its quota), 213 share 0,
-- 214 joins after the month, 215 share 5 with credits; hours: 221 share 5
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(211), pg_temp.u(101), 'Full', 'active', 100, 'blocked', now() - interval '1 year'),
       (pg_temp.u(212), pg_temp.u(101), 'Small', 'active', 5, 'blocked', now() - interval '1 year'),
       (pg_temp.u(213), pg_temp.u(101), 'None', 'active', 0, 'blocked', now() - interval '1 year'),
       (pg_temp.u(214), pg_temp.u(101), 'Later', 'active', 100, 'blocked',
        date_trunc('month', now()) + interval '2 months'),
       (pg_temp.u(215), pg_temp.u(101), 'Credits', 'active', 5, 'blocked', now() - interval '1 year'),
       (pg_temp.u(221), pg_temp.u(102), 'Hours', 'active', 5, 'blocked', now() - interval '1 year');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
select ('00000000-0000-4000-8000-0000396' || lpad(n::text, 5, '0'))::uuid, pg_temp.u(103), 'M' || n,
       'active', 100, 'blocked', now() - interval '1 year'
  from generate_series(1, 200) n;

create function pg_temp.place(p_ws int, p_n int, p_seats int) returns void language plpgsql as $$
begin
  insert into public.levels (id, workspace_id, name) values (pg_temp.u(p_n), pg_temp.u(p_ws), 'L' || p_n);
  insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values (pg_temp.u(p_n + 1), pg_temp.u(p_ws), pg_temp.u(p_n), 'O' || p_n, 0, 0, 10, 10);
  insert into public.desks (id, workspace_id, office_id, name, x, y, w, h)
  values (pg_temp.u(p_n + 2), pg_temp.u(p_ws), pg_temp.u(p_n + 1), 'D' || p_n, 1, 1, 4, 2);
  insert into public.seats (id, workspace_id, desk_id, name, x, y)
  select ('00000000-0000-4000-8000-000' || lpad((p_ws * 1000 + s)::text, 9, '0'))::uuid,
         pg_temp.u(p_ws), pg_temp.u(p_n + 2), 'S' || s, 1, 1
    from generate_series(1, p_seats) s;
end $$;
create function pg_temp.seat(p_ws int, s int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-000' || lpad((p_ws * 1000 + s)::text, 9, '0'))::uuid;
$$;
select pg_temp.place(101, 600, 6);
select pg_temp.place(102, 620, 2);
select pg_temp.place(103, 640, 200);

-- the weekdays of the coming month and of this one
create temp table days as
select d::date as day, row_number() over (order by d) as k
  from generate_series(date_trunc('month', now() at time zone 'Europe/Paris') + interval '1 month',
                       date_trunc('month', now() at time zone 'Europe/Paris') + interval '2 months' - interval '1 day',
                       interval '1 day') d
 where extract(isodow from d) between 1 and 5;
grant select on days to authenticated;

create function pg_temp.book(p_ws int, p_member int, p_seat int, p_day date, p_from int, p_to int)
returns uuid language sql as $$
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (pg_temp.u(p_ws), pg_temp.u(p_member), pg_temp.seat(p_ws, p_seat),
          (p_day + make_interval(hours => p_from)) at time zone 'Europe/Paris',
          (p_day + make_interval(hours => p_to)) at time zone 'Europe/Paris')
  returning id $$;

-- 211: one morning, and a morning and an afternoon of one day
select pg_temp.book(101, 211, 1, (select day from days where k = 1), 8, 11);
select pg_temp.book(101, 211, 1, (select day from days where k = 2), 8, 11);
select pg_temp.book(101, 211, 1, (select day from days where k = 2), 14, 17);
-- 212 and 213: six mornings each
select pg_temp.book(101, 212, 2, day, 8, 11) from days where k between 1 and 6;
select pg_temp.book(101, 213, 3, day, 8, 11) from days where k between 1 and 6;
-- 214: before joining
select pg_temp.book(101, 214, 4, (select day from days where k = 3), 8, 11);
-- 215: six mornings, two of them drawn from a credit
select pg_temp.book(101, 215, 5, day, 8, 11) from days where k between 1 and 6;
insert into public.member_credits (id, workspace_id, member_id, half_days, source)
values (pg_temp.u(901), pg_temp.u(101), pg_temp.u(215), 10, 'gift');
insert into public.member_credit_uses (workspace_id, credit_id, reservation_id, half_days)
select pg_temp.u(101), pg_temp.u(901), r.id, 1
  from public.reservations r where r.member_id = pg_temp.u(215)
 order by r.starts_at limit 2;
-- 221 (by the hour): three days of six hours, one of three
select pg_temp.book(102, 221, 1, day, 9, 15) from days where k between 1 and 3;
select pg_temp.book(102, 221, 1, (select day from days where k = 4), 9, 12);
-- the 200: one morning each
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
select pg_temp.u(103), ('00000000-0000-4000-8000-0000396' || lpad(n::text, 5, '0'))::uuid, pg_temp.seat(103, n),
       ((select day from days where k = 1) + interval '8 hours') at time zone 'Europe/Paris',
       ((select day from days where k = 1) + interval '11 hours') at time zone 'Europe/Paris'
  from generate_series(1, 200) n;

-- Every member-month with a booking, side by side: the statement (read as
-- the business's owner) and the one pass.
create function pg_temp.compare(p_ws int, p_owner int) returns table(pairs int, mismatches int)
language plpgsql as $$
declare v_members uuid[]; v_periods text[];
begin
  select array_agg(m order by m, p), array_agg(p order by m, p) into v_members, v_periods
    from (select distinct r.member_id m, to_char(r.starts_at at time zone 'Europe/Paris', 'YYYY-MM') p
            from public.reservations r where r.workspace_id = pg_temp.u(p_ws)) x;
  perform pg_temp.act_as(pg_temp.u(p_owner));
  return query
  select count(*)::int,
         count(*) filter (where o.extra_half_days is distinct from
           coalesce((public.member_statement(o.member_id, o.period) ->> 'extra_half_days')::int, 0))::int
    from public.member_months_extra_half_days(pg_temp.u(p_ws), v_members, v_periods) o;
end $$;

select is((select (pairs, mismatches)::text from pg_temp.compare(101, 1)), '(5,0)',
  'by half-day: every member-month equals its statement');
select is((select (pairs, mismatches)::text from pg_temp.compare(102, 2)), '(1,0)',
  'by the hour: the member-month equals its statement');
select ok((select bool_or(extra_half_days > 0) and bool_or(extra_half_days = 0)
             from public.member_months_extra_half_days(pg_temp.u(101),
               array[pg_temp.u(211), pg_temp.u(212), pg_temp.u(214)],
               array_fill(to_char((select day from days where k = 1), 'YYYY-MM'), array[3]))),
  'the fixture holds a month over its quota and months within it');
select is((select extra_half_days from public.member_months_extra_half_days(pg_temp.u(101),
             array[pg_temp.u(214)], array[to_char((select day from days where k = 3), 'YYYY-MM')])), 0,
  'a month before the member joined owes no extra half-day');

-- the price read: the kinds it gave before
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
create temp table kinds as
select member_id, kind, count(*)::int n
  from public.booking_prices(pg_temp.u(101),
         (select min(day) from days)::timestamptz - interval '1 day',
         (select max(day) from days)::timestamptz + interval '2 days')
 group by 1, 2;
reset role;
select is((select string_agg(kind || ':' || n, ',' order by kind) from kinds where member_id = pg_temp.u(212)),
  'overage:6', 'a member over the quota of the month: every counted booking is overage');
select is((select string_agg(kind || ':' || n, ',' order by kind) from kinds where member_id = pg_temp.u(211)),
  'subscription:3', 'a member within it: subscription');

-- 200 members: the result asserted, the time printed
select pg_temp.act_as(pg_temp.u(3));
set local role authenticated;
select set_config('t.t0', clock_timestamp()::text, true);
create temp table many as
select kind, count(*)::int n
  from public.booking_prices(pg_temp.u(103),
         (select day from days where k = 1)::timestamptz - interval '1 day',
         (select day from days where k = 1)::timestamptz + interval '2 days')
 group by 1;
select set_config('t.ms', round(extract(epoch from clock_timestamp() - current_setting('t.t0')::timestamptz) * 1000)::text, true);
reset role;
select diag('200 members, one booking each: booking_prices took ' || current_setting('t.ms') || ' ms');
select is((select string_agg(kind || ':' || n, ',') from many), 'subscription:200',
  '200 members, one booking each: every booking is read, within its quota');
select is((select (pairs, mismatches)::text from pg_temp.compare(103, 3)), '(200,0)',
  '200 members: every member-month equals its statement');

select * from finish();
rollback;
