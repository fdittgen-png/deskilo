-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2578 performance evidence: the BI server read on a synthetic dataset.
--
-- WHAT     One rolled-back transaction. It seeds a synthetic coworking space
--          with generate_series (no real data), prints the row counts, then
--          runs the calls the BI page makes under EXPLAIN (ANALYZE, BUFFERS),
--          as the owner with real JWT claims and `set local role
--          authenticated`, plus a cancellation probe at the declared time
--          budget and the bound checks. Nothing persists: the last statement
--          is `rollback`.
--
-- RUN      On the dev project only, with a client that prints every result
--          set, for example:
--            psql "$DEV_DB_URL" -v ON_ERROR_STOP=1 -f 2578-explain.sql
--          Expect several minutes. Seeding takes most of it: about 600k
--          reservations go through every reservation trigger, one month per
--          statement so each one stays under the 120 s statement timeout.
--          If a client shows only the last result set, the summary (last)
--          and the checks (second to last) still hold every number.
--
-- RESULT SETS, in order
--   1. dataset: exact row counts and the selected filters
--   2. one EXPLAIN plan per step (a, b, c, c2, u1-u3, d1-d3, e1, e2)
--   3. checks: one row per bound, with pass true/false
--   4. summary: step | requests | planning ms | execution ms | shared hit /
--      read | temp written | backend memory | note
--
-- LIMITATIONS (also in the summary notes)
--   * "Cold" is the first call in this session: plpgsql functions not
--     compiled yet, plans not cached. Shared buffers are probably warm,
--     because the seed has just written these pages. A true cold cache
--     (empty shared_buffers and OS cache) cannot be produced inside one
--     transaction. The shared `read` blocks show what came from outside
--     shared buffers.
--   * EXPLAIN of a function call shows one Result node. Its time and buffers
--     include everything the function ran, but the inner plans are not
--     printed. The u1-u3 steps time one request of each kind on its own.
--     d3 prints the plan of the payments page query itself.
--   * Planner statistics are the dev tables' own. ANALYZE is NOT run: it
--     would write pg_class.reltuples in place, and that would survive the
--     rollback. Row estimates still scale with the physical size of the
--     tables.
--   * Memory: the backend's total memory-context size after each step
--     (pg_backend_memory_contexts, null without the privilege). That is not
--     the peak. Spills show as `temp written` blocks.
--   * The rollback leaves dead tuples (about 1.3M rows across reservations,
--     history, events and money tables). Autovacuum reclaims them later.
--
-- Budgets are the ones declared in the settings registry, read at run
-- time: bi.batch_max_requests (0508), bi.batch_time_budget_ms (0620),
-- bi.series_months / _quarters / _years (0627), bi.detail_page_size (0643),
-- kpi.capacity_range_days / kpi.finance_range_months (0457). No SLA is
-- invented here.

begin;
set local statement_timeout = '120s';

-- ------------------------------------------------------------ knobs
-- Dataset shape. 20 levels x 5 rooms x 5 desks x 3 seats = 1,500 seats.
-- 384 bookings per working half-day x ~1,565 half-days in 36 months gives
-- ~600k reservations. Each half-day uses 384 distinct members (of 400) and
-- 384 distinct seats (of 1,500), so no seat and no member is double-booked.
select set_config('perf.tz', 'Europe/Paris', true),
       set_config('perf.members', '400', true),
       set_config('perf.levels', '20', true),
       set_config('perf.rooms_per_level', '5', true),
       set_config('perf.desks_per_room', '5', true),
       set_config('perf.seats_per_desk', '3', true),
       set_config('perf.per_half_day', '384', true),
       set_config('perf.months', '36', true),
       set_config('perf.invoices', '14400', true),  -- = members x months: one 'full' invoice per member-month (the unique index is (member_id, period, kind))
       -- the current month on the workspace clock; the data covers the 36
       -- full months before it
       set_config('perf.cur', (date_trunc('month', now() at time zone 'Europe/Paris'))::date::text, true),
       set_config('perf.m0', ((date_trunc('month', now() at time zone 'Europe/Paris'))::date
                               - interval '36 months')::date::text, true),
       set_config('perf.t_seed0', clock_timestamp()::text, true);

-- ------------------------------------------------------------ scratch tables
-- The ordered members, seats and levels the generators index into, the
-- invoice plan, the captured plans, the step timings and the checks.
create temp table perf_member (idx int primary key, id uuid not null) on commit drop;
create temp table perf_seat (idx int primary key, id uuid not null) on commit drop;
create temp table perf_level (idx int primary key, id uuid not null) on commit drop;
create temp table perf_inv (n int primary key, number text not null, member_idx int not null,
                            month_start date not null, amount int not null,
                            matched_at timestamptz not null) on commit drop;
create temp table perf_plan (step text, ord int, line text) on commit drop;
create temp table perf_step (ord serial, step text, requests int, planning_ms numeric,
                             execution_ms numeric, shared_hit bigint, shared_read bigint,
                             temp_written bigint, mem_bytes bigint, note text) on commit drop;
create temp table perf_check (ord serial, check_name text, expected text, actual text,
                              pass boolean) on commit drop;

-- ------------------------------------------------------------ helpers
-- Impersonation, the same way 334 does it: JWT claims, then the real role.
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

-- The backend's memory-context total, or null without the privilege.
create function pg_temp.mem() returns bigint language plpgsql as $$
begin
  return (select sum(total_bytes)::bigint from pg_backend_memory_contexts);
exception when others then
  return null;
end;
$$;

-- A short reading of an answer: the codes of a batch, the size of a page,
-- or the refusal.
create function pg_temp.describe(v jsonb) returns text language sql as $$
  select case
    when v ? 'code' then 'refused ' || (v ->> 'code') || ': ' || left(v ->> 'error', 80)
    when v ? 'results' then
      (select 'results=' || count(*) || ' [' || string_agg(c || '=' || n, ', ' order by c) || ']'
         from (select coalesce(x ->> 'code', 'ok') c, count(*) n
                 from jsonb_array_elements(v -> 'results') x group by 1) h)
    when v ? 'items' then
      'items=' || jsonb_array_length(v -> 'items') || ' page_size=' || (v ->> 'page_size')
      || ' next=' || (jsonb_typeof(v -> 'next_cursor') = 'object')::text
    else left(v::text, 80) end;
$$;

-- EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) of p_sql as p_user (null = the
-- connecting role). It returns the plan lines and records the timings in
-- perf_step. A call that raises has no plan: it records the refusal and
-- the clock time around it instead.
create function pg_temp.explain(p_step text, p_user uuid, p_sql text, p_requests int default null)
returns table (query_plan text) language plpgsql as $$
declare
  v_lines text[] := '{}';
  v_line text;
  v_t0 timestamptz;
  v_ms numeric;
  v_err text;
  v_buf text;
  v_all text;
begin
  v_t0 := clock_timestamp();
  begin
    if p_user is not null then perform pg_temp.act_as(p_user); end if;
    for v_line in execute 'explain (analyze, buffers, format text) ' || p_sql loop
      v_lines := v_lines || v_line;
    end loop;
    execute 'reset role';
  exception when others then
    v_err := sqlstate || ' ' || sqlerrm;
  end;
  execute 'reset role';
  v_ms := extract(epoch from clock_timestamp() - v_t0) * 1000;
  if v_err is not null then
    v_lines := v_lines || format('-- no plan: the call raised %s after %s ms (clock time around it)',
                                 v_err, round(v_ms, 1));
  end if;
  v_all := array_to_string(v_lines, E'\n');
  -- The first Buffers line belongs to the top node and includes the function's work.
  select l into v_buf from unnest(v_lines) with ordinality u(l, i)
   where l ~ '^\s*Buffers:' order by i limit 1;
  insert into perf_plan select p_step, i, l from unnest(v_lines) with ordinality u(l, i);
  insert into perf_step (step, requests, planning_ms, execution_ms, shared_hit, shared_read,
                         temp_written, mem_bytes, note)
  values (p_step, p_requests,
          substring(v_all from 'Planning Time: ([0-9.]+) ms')::numeric,
          coalesce(substring(v_all from 'Execution Time: ([0-9.]+) ms')::numeric, v_ms),
          substring(substring(v_buf from 'shared ([^,]*)') from 'hit=([0-9]+)')::bigint,
          coalesce(substring(substring(v_buf from 'shared ([^,]*)') from 'read=([0-9]+)')::bigint, 0),
          coalesce(substring(substring(v_buf from 'temp ([^,]*)') from 'written=([0-9]+)')::bigint, 0),
          pg_temp.mem(),
          case when v_err is not null then 'raised ' || left(v_err, 90) end);
  return query select l from unnest(v_lines) l;
end;
$$;

-- p_sql as p_user, plainly (no EXPLAIN), to read the answer. It returns the
-- answer, or {error, code} when the call raised, and records the clock time
-- when p_step is given.
create function pg_temp.call(p_step text, p_user uuid, p_sql text, p_requests int default null)
returns jsonb language plpgsql as $$
declare
  v jsonb;
  v_t0 timestamptz := clock_timestamp();
  v_ms numeric;
begin
  begin
    if p_user is not null then perform pg_temp.act_as(p_user); end if;
    execute p_sql into v;
    execute 'reset role';
  exception when others then
    v := jsonb_build_object('error', sqlerrm, 'code', sqlstate);
  end;
  execute 'reset role';
  v_ms := extract(epoch from clock_timestamp() - v_t0) * 1000;
  if p_step is not null then
    insert into perf_step (step, requests, execution_ms, mem_bytes, note)
    values (p_step, p_requests, v_ms, pg_temp.mem(), 'clock, no EXPLAIN: ' || pg_temp.describe(v));
  end if;
  return v;
end;
$$;

-- The cancellation probe. The CALLER sets statement_timeout in the
-- statement before this one, because a timeout is armed when a top-level
-- statement starts. bi_query_batch_v1's own handler never catches 57014,
-- so the cancel reaches this handler.
create function pg_temp.cancel_probe(p_step text, p_user uuid, p_sql text, p_requests int)
returns text language plpgsql as $$
declare
  v jsonb;
  v_t0 timestamptz := clock_timestamp();
  v_ms numeric;
  v_out text;
begin
  begin
    perform pg_temp.act_as(p_user);
    execute p_sql into v;
    execute 'reset role';
    v_ms := extract(epoch from clock_timestamp() - v_t0) * 1000;
    v_out := format('not cancelled: completed in %s ms under statement_timeout=%s; %s',
                    round(v_ms, 1), current_setting('statement_timeout'), pg_temp.describe(v));
  exception when query_canceled then
    v_ms := extract(epoch from clock_timestamp() - v_t0) * 1000;
    v_out := format('cancelled (57014) after %s ms under statement_timeout=%s',
                    round(v_ms, 1), current_setting('statement_timeout'));
  end;
  execute 'reset role';
  insert into perf_step (step, requests, execution_ms, mem_bytes, note)
  values (p_step, p_requests, v_ms, pg_temp.mem(), v_out);
  return v_out;
end;
$$;

-- Request builders, written the way BiBatchRequest.toJson does it: UTC ISO
-- instants at local midnight, metric_version 1, from_month/to_month for
-- the finance figures.
create function pg_temp.iso(t timestamptz) returns text language sql immutable as $$
  select to_char(t at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS".000Z"');
$$;
-- Local midnight of month k relative to the current month (0 = current).
create function pg_temp.mstart(k int) returns timestamptz language sql stable as $$
  select (current_setting('perf.cur')::date + make_interval(months => k))::timestamp
         at time zone current_setting('perf.tz');
$$;
create function pg_temp.mlabel(k int) returns text language sql stable as $$
  select to_char(current_setting('perf.cur')::date + make_interval(months => k), 'YYYY-MM');
$$;
create function pg_temp.cap(p_key text, p_from timestamptz, p_to timestamptz, p_level uuid default null)
returns jsonb language sql stable as $$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'capacity.seat_utilisation',
    'metric_version', 1, 'from', pg_temp.iso(p_from), 'to', pg_temp.iso(p_to))
    || case when p_level is null then '{}'::jsonb else jsonb_build_object('level_id', p_level) end;
$$;
create function pg_temp.fin(p_key text, p_from text, p_to text) returns jsonb language sql as $$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'finance.collected',
    'metric_version', 1, 'from_month', p_from, 'to_month', p_to);
$$;

-- One BI page of p_n requests. In order: the monthly capacity series
-- (bi.series_months points, the current month last, c*), the same months'
-- collected figure (f*), then one capacity figure per level for the last
-- full month and for the same month a year earlier, and so on (l*). The
-- first p_n are taken.
create function pg_temp.page_batch(p_n int) returns jsonb language sql stable as $$
  with p as (select current_setting('perf.series_months')::int m,
                    (select count(*)::int from perf_level) nl),
  reqs as (
    select 1 grp, i ord, pg_temp.cap('c' || i, pg_temp.mstart(i - p.m + 1), pg_temp.mstart(i - p.m + 2)) r
      from p, generate_series(0, p.m - 1) i
    union all
    select 2, i, pg_temp.fin('f' || i, pg_temp.mlabel(i - p.m + 1), pg_temp.mlabel(i - p.m + 1))
      from p, generate_series(0, p.m - 1) i
    union all
    select 3, i, pg_temp.cap('l' || i, pg_temp.mstart(-1 - 12 * (i / p.nl)), pg_temp.mstart(-12 * (i / p.nl)), l.id)
      from p cross join generate_series(0, p_n) i join perf_level l on l.idx = i % p.nl
  )
  select jsonb_agg(r order by grp, ord)
    from (select grp, ord, r from reqs order by grp, ord limit p_n) x;
$$;

-- The yearly series the app reads in one batch: bi.series_years calendar
-- years up to the current one (each at most 366 days, within the 400-day
-- capacity bound and the 24-month finance bound).
create function pg_temp.year_batch(p_metric text) returns jsonb language sql stable as $$
  with p as (select current_setting('perf.series_years')::int y,
                    extract(year from current_setting('perf.cur')::date)::int cur_y)
  select jsonb_agg(case when p_metric = 'capacity.seat_utilisation'
           then pg_temp.cap('y' || k,
                  make_date(p.cur_y - p.y + 1 + k, 1, 1)::timestamp at time zone current_setting('perf.tz'),
                  make_date(p.cur_y - p.y + 2 + k, 1, 1)::timestamp at time zone current_setting('perf.tz'))
           else pg_temp.fin('y' || k, (p.cur_y - p.y + 1 + k) || '-01', (p.cur_y - p.y + 1 + k) || '-12') end
         order by k)
    from p, generate_series(0, p.y - 1) k;
$$;

-- The SQL of one batch call, with its payload as a literal (no pg_temp
-- reference runs under the authenticated role).
create function pg_temp.batch_sql(p_requests jsonb) returns text language sql stable as $$
  select format('select public.bi_query_batch_v1(%L::uuid, %L::jsonb)', current_setting('perf.ws'), p_requests::text);
$$;
create function pg_temp.payments_sql(p_from date, p_to date, p_after jsonb, p_limit int) returns text
language sql stable as $$
  select format('select public.workspace_recorded_payments_v1(%L::uuid, %L::date, %L::date, %s, %s)',
                current_setting('perf.ws'), p_from, p_to,
                coalesce(quote_literal(p_after::text) || '::jsonb', 'null'),
                coalesce(p_limit::text, 'null'));
$$;

-- One month of reservations (p_month 0..35 from perf.m0): two half-days
-- per working day (08:00-13:00 and 13:00-18:00 local). In slot t, booking
-- n goes to member (n + t) mod 400 on seat (3n + 7t) mod 1500. All of
-- them are in the past, so they are 'completed', checked in and out at
-- their bounds.
create function pg_temp.seed_reservations(p_month int) returns bigint language plpgsql as $$
declare
  v_ws uuid := current_setting('perf.ws')::uuid;
  v_tz text := current_setting('perf.tz');
  v_m0 date := current_setting('perf.m0')::date;
  v_nm int := (select count(*) from perf_member);
  v_ns int := (select count(*) from perf_seat);
  v_from date := (current_setting('perf.m0')::date + make_interval(months => p_month))::date;
  v_to date := (current_setting('perf.m0')::date + make_interval(months => p_month + 1))::date;
  v_n bigint;
begin
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at, status,
                                   checked_in_at, checked_out_at)
  select v_ws, m.id, s.id, t.s_at, t.e_at, 'completed', t.s_at, t.e_at
    from generate_series(v_from::timestamp, (v_to - 1)::timestamp, interval '1 day') d(day)
    cross join (values (0, 480, 780), (1, 780, 1080)) h(half, s_min, e_min)
    cross join generate_series(0, current_setting('perf.per_half_day')::int - 1) n
    cross join lateral (
      select (d.day::date - v_m0) * 2 + h.half as slot,
             (d.day + make_interval(mins => h.s_min)) at time zone v_tz as s_at,
             (d.day + make_interval(mins => h.e_min)) at time zone v_tz as e_at) t
    join perf_member m on m.idx = (n + t.slot) % v_nm
    join perf_seat s on s.idx = (3 * n + 7 * t.slot) % v_ns
   where extract(isodow from d.day) <= 5;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- ------------------------------------------------------------ seed: people and the space
-- 402 accounts: 0 is the owner, 1 the analyst (viewAnalytics, no
-- viewFinances), 2..401 the 400 members who book.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-2578' || lpad(i::text, 8, '0'))::uuid,
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'perf2578-' || i || '@deskilo.test', '', now(), now(), now()
  from generate_series(0, current_setting('perf.members')::int + 1) i;
select set_config('perf.owner', '00000000-0000-4000-8000-257800000000', true),
       set_config('perf.analyst', '00000000-0000-4000-8000-257800000001', true);

-- The workspace, as 334 does it. Then its declared flags, its opening hours
-- (Mon-Fri 08:00-18:00) and the plain member role granted viewAnalytics
-- only (as 319). The hours go through the analytics trigger.
with w as (
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Perf 2578', 'FR', 'EUR', current_setting('perf.tz'), current_setting('perf.owner')::uuid)
  returning id)
select set_config('perf.ws', id::text, true) from w;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
                       || '{"capacityKpi": true, "workspaceStatus": true, "invoicing": true, "moneyTab": true}',
       booking_rules = coalesce(booking_rules, '{}'::jsonb)
                       || '{"open_weekdays": [1,2,3,4,5], "work_start_minutes": 480, "work_end_minutes": 1080}',
       role_permissions = coalesce(role_permissions, '{}'::jsonb) || '{"member": ["viewAnalytics"]}'
 where id = current_setting('perf.ws')::uuid;

-- Members with joined_at before the data. They pay as they go
-- (subscription 100 %), so a booking draws no credits.
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at,
                            subscription_pct, overage_policy)
select current_setting('perf.ws')::uuid,
       ('00000000-0000-4000-8000-2578' || lpad(i::text, 8, '0'))::uuid,
       i = 0, i = 0, 'active', current_setting('perf.m0')::date - interval '1 month', 100, 'payg'
  from generate_series(0, current_setting('perf.members')::int + 1) i;
select set_config('perf.owner_member', (select id::text from public.members
         where workspace_id = current_setting('perf.ws')::uuid and is_owner), true);
insert into perf_member
select (right(m.user_id::text, 8)::int - 2), m.id from public.members m
 where m.workspace_id = current_setting('perf.ws')::uuid
   and right(m.user_id::text, 8)::int >= 2;

-- The plan: 20 levels, 5 rooms per level, 5 desks per room, 3 seats per desk.
insert into public.levels (workspace_id, name, sort_order)
select current_setting('perf.ws')::uuid, 'Level ' || lpad(i::text, 2, '0'), i - 1
  from generate_series(1, current_setting('perf.levels')::int) i;
insert into public.offices (workspace_id, level_id, name, x, y, w, h)
select l.workspace_id, l.id, l.name || ' room ' || r, 0, (r - 1) * 12, 30, 10
  from public.levels l, generate_series(1, current_setting('perf.rooms_per_level')::int) r
 where l.workspace_id = current_setting('perf.ws')::uuid;
insert into public.desks (workspace_id, office_id, x, y, w, h)
select o.workspace_id, o.id, 1 + (k - 1) * 5, 1, 4, 2
  from public.offices o, generate_series(1, current_setting('perf.desks_per_room')::int) k
 where o.workspace_id = current_setting('perf.ws')::uuid;
insert into public.seats (workspace_id, desk_id, x, y)
select d.workspace_id, d.id, d.x + j - 1, 1
  from public.desks d, generate_series(1, current_setting('perf.seats_per_desk')::int) j
 where d.workspace_id = current_setting('perf.ws')::uuid;
insert into perf_level
select (row_number() over (order by l.sort_order) - 1)::int, l.id
  from public.levels l where l.workspace_id = current_setting('perf.ws')::uuid;
insert into perf_seat
select (row_number() over (order by l.sort_order, o.name, d.x, s.x) - 1)::int, s.id
  from public.seats s join public.desks d on d.id = s.desk_id
  join public.offices o on o.id = d.office_id join public.levels l on l.id = o.level_id
 where s.workspace_id = current_setting('perf.ws')::uuid;

-- The recorded history begins with the data (34 months before the page's
-- first month). As in 334, the rows the triggers wrote are moved back.
-- The rows are updated; no trigger is disabled.
update public.analytics_history
   set since = current_setting('perf.m0')::timestamp at time zone current_setting('perf.tz')
 where workspace_id = current_setting('perf.ws')::uuid;
update public.seat_history
   set valid = tstzrange(current_setting('perf.m0')::timestamp at time zone current_setting('perf.tz'), null, '[)')
 where workspace_id = current_setting('perf.ws')::uuid and upper_inf(valid);
update public.opening_hours_history
   set valid = tstzrange(current_setting('perf.m0')::timestamp at time zone current_setting('perf.tz'), null, '[)')
 where workspace_id = current_setting('perf.ws')::uuid and upper_inf(valid);

-- ------------------------------------------------------------ seed: reservations
-- One statement per month, through every reservation trigger (events,
-- target history, one-place, hierarchy, rental, room charge, credits,
-- limit). Each row prints the month's count.
select pg_temp.seed_reservations(0);  select pg_temp.seed_reservations(1);  select pg_temp.seed_reservations(2);
select pg_temp.seed_reservations(3);  select pg_temp.seed_reservations(4);  select pg_temp.seed_reservations(5);
select pg_temp.seed_reservations(6);  select pg_temp.seed_reservations(7);  select pg_temp.seed_reservations(8);
select pg_temp.seed_reservations(9);  select pg_temp.seed_reservations(10); select pg_temp.seed_reservations(11);
select pg_temp.seed_reservations(12); select pg_temp.seed_reservations(13); select pg_temp.seed_reservations(14);
select pg_temp.seed_reservations(15); select pg_temp.seed_reservations(16); select pg_temp.seed_reservations(17);
select pg_temp.seed_reservations(18); select pg_temp.seed_reservations(19); select pg_temp.seed_reservations(20);
select pg_temp.seed_reservations(21); select pg_temp.seed_reservations(22); select pg_temp.seed_reservations(23);
select pg_temp.seed_reservations(24); select pg_temp.seed_reservations(25); select pg_temp.seed_reservations(26);
select pg_temp.seed_reservations(27); select pg_temp.seed_reservations(28); select pg_temp.seed_reservations(29);
select pg_temp.seed_reservations(30); select pg_temp.seed_reservations(31); select pg_temp.seed_reservations(32);
select pg_temp.seed_reservations(33); select pg_temp.seed_reservations(34); select pg_temp.seed_reservations(35);

-- ------------------------------------------------------------ seed: money
-- 14,400 invoices = 400 members x 36 months: exactly one 'full' subscription
-- invoice per member and month (400 a month). Invoice n goes to member
-- (n-1) mod 400 and month ((n-1) div 400) mod 36, so no two invoices share
-- (member, month): the unique index invoices_member_period_kind_uniq
-- (member_id, period, kind) holds. The earlier mapping, month (n-1) mod 36,
-- repeated (member, month) from n = 3601 on (lcm(400,36) = 3600) and failed
-- with 23505.
-- Each is paid once: a credit ledger row (the payment), its invoice_match
-- and its invoice_match_payment, matched inside the invoice's own month at
-- a spread instant. The collected figure and the payments read sum
-- exactly those rows.
insert into perf_inv
-- mapping: injective (member, month); the old month=(n-1)%36 repeated them from n=3601 (lcm(400,36)=3600) -> 23505 on invoices_member_period_kind_uniq
select n, 'PERF-' || lpad(n::text, 5, '0'), (n - 1) % current_setting('perf.members')::int,
       ms, 20000 + (n * 137) % 30000,
       (ms + make_interval(mins => (n * 7919) % ((((ms + interval '1 month')::date - ms) * 1440))))::timestamp
         at time zone current_setting('perf.tz')
  from generate_series(1, current_setting('perf.invoices')::int) n,
       lateral (select (current_setting('perf.m0')::date
                        + make_interval(months => ((n - 1) / current_setting('perf.members')::int) % current_setting('perf.months')::int))::date ms) x;
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name,
                             signature, period, kind)
select current_setting('perf.ws')::uuid, m.id, current_setting('perf.owner_member')::uuid, p.number,
       'Subscription ' || to_char(p.month_start, 'YYYY-MM'),
       jsonb_build_array(jsonb_build_object('label', 'Subscription', 'amount_cents', p.amount)),
       p.amount, 'EUR', 'Perf member ' || p.member_idx, 'Perf 2578', 'Perf owner', 's',
       to_char(p.month_start, 'YYYY-MM'), 'full'
  from perf_inv p join perf_member m on m.idx = p.member_idx;
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents,
                                   description, period, occurred_on)
select current_setting('perf.ws')::uuid, m.id, 'credit', 'payment', p.amount,
       'PERF payment ' || p.number, to_char(p.month_start, 'YYYY-MM'),
       (p.matched_at at time zone current_setting('perf.tz'))::date
  from perf_inv p join perf_member m on m.idx = p.member_idx;
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at,
                                    payment_ledger_id)
select i.workspace_id, i.id, p.amount, 'exact', p.matched_at, le.id
  from perf_inv p
  join public.invoices i on i.workspace_id = current_setting('perf.ws')::uuid and i.number = p.number
  join public.ledger_entries le on le.workspace_id = i.workspace_id
                               and le.description = 'PERF payment ' || p.number;
insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents,
                                           resolution, matched_at)
select i.workspace_id, i.id, le.id, p.amount, 'exact', p.matched_at
  from perf_inv p
  join public.invoices i on i.workspace_id = current_setting('perf.ws')::uuid and i.number = p.number
  join public.ledger_entries le on le.workspace_id = i.workspace_id
                               and le.description = 'PERF payment ' || p.number;

insert into perf_step (step, execution_ms, mem_bytes, note)
values ('seed (all statements)',
        extract(epoch from clock_timestamp() - current_setting('perf.t_seed0')::timestamptz) * 1000,
        pg_temp.mem(), 'clock time of the whole synthetic seed, triggers included');

-- ------------------------------------------------------------ the declared bounds
-- Read from the registry the way the server reads them (setting_value: the
-- workspace's value, otherwise the platform's, otherwise the default).
select set_config('perf.batch_max', (public.setting_value(current_setting('perf.ws')::uuid, 'bi.batch_max_requests') #>> '{}'), true),
       set_config('perf.budget_ms', (public.setting_value(current_setting('perf.ws')::uuid, 'bi.batch_time_budget_ms') #>> '{}'), true),
       set_config('perf.series_months', (public.setting_value(current_setting('perf.ws')::uuid, 'bi.series_months') #>> '{}'), true),
       set_config('perf.series_quarters', (public.setting_value(current_setting('perf.ws')::uuid, 'bi.series_quarters') #>> '{}'), true),
       set_config('perf.series_years', (public.setting_value(current_setting('perf.ws')::uuid, 'bi.series_years') #>> '{}'), true),
       set_config('perf.page_size', (public.setting_value(current_setting('perf.ws')::uuid, 'bi.detail_page_size') #>> '{}'), true),
       set_config('perf.cap_days', (public.setting_value(null, 'kpi.capacity_range_days') #>> '{}'), true),
       set_config('perf.fin_months', (public.setting_value(null, 'kpi.finance_range_months') #>> '{}'), true);

-- The payments window: the last 24 full months (the read's own maximum),
-- and a cursor about 10,000 rows in (kept at least two pages before the end).
select set_config('perf.pay_from', (current_setting('perf.cur')::date - interval '24 months')::date::text, true),
       set_config('perf.pay_to', (current_setting('perf.cur')::date - 1)::text, true);
select set_config('perf.pay_rows', count(*)::text, true)
  from public.invoice_match_payments mp
 where mp.workspace_id = current_setting('perf.ws')::uuid
   and mp.matched_at >= current_setting('perf.pay_from')::timestamp at time zone current_setting('perf.tz')
   and mp.matched_at < current_setting('perf.cur')::timestamp at time zone current_setting('perf.tz');
select set_config('perf.cursor_row', greatest(1, least(10000, current_setting('perf.pay_rows')::int
                                     - 2 * current_setting('perf.page_size')::int))::text, true);
select set_config('perf.cursor', jsonb_build_object('matched_at', x.matched_at, 'id', x.id)::text, true)
  from (select mp.matched_at, mp.id from public.invoice_match_payments mp
         where mp.workspace_id = current_setting('perf.ws')::uuid
           and mp.matched_at >= current_setting('perf.pay_from')::timestamp at time zone current_setting('perf.tz')
           and mp.matched_at < current_setting('perf.cur')::timestamp at time zone current_setting('perf.tz')
         order by mp.matched_at desc, mp.id desc
        offset current_setting('perf.cursor_row')::int - 1 limit 1) x;

-- ============================================================ RESULT 1: the dataset
-- Exact row counts of the seeded workspace, then the filters each step uses.
with ws as (select current_setting('perf.ws')::uuid id)
select item, row_count, detail from (
  select 1 as o, 'workspaces' as item, (select count(*) from public.workspaces w, ws where w.id = ws.id) as row_count, 'Europe/Paris, EUR' as detail
  union all select 2, 'members', (select count(*) from public.members m, ws where m.workspace_id = ws.id),
                   '1 owner + 1 analyst (viewAnalytics, no viewFinances) + ' || current_setting('perf.members') || ' booking members'
  union all select 3, 'levels', (select count(*) from public.levels l, ws where l.workspace_id = ws.id), null
  union all select 4, 'offices', (select count(*) from public.offices o, ws where o.workspace_id = ws.id), null
  union all select 5, 'desks', (select count(*) from public.desks d, ws where d.workspace_id = ws.id), null
  union all select 6, 'seats', (select count(*) from public.seats s, ws where s.workspace_id = ws.id), null
  union all select 7, 'seat_history', (select count(*) from public.seat_history h, ws where h.workspace_id = ws.id), 'valid from ' || current_setting('perf.m0')
  union all select 8, 'opening_hours_history', (select count(*) from public.opening_hours_history h, ws where h.workspace_id = ws.id), 'Mon-Fri 08:00-18:00'
  union all select 9, 'reservations', (select count(*) from public.reservations r, ws where r.workspace_id = ws.id),
                   (select 'completed, ' || min(starts_at)::date || ' .. ' || max(ends_at)::date
                      from public.reservations r, ws where r.workspace_id = ws.id)
  union all select 10, 'reservation_target_history', (select count(*) from public.reservation_target_history t, ws where t.workspace_id = ws.id), 'written by the trigger'
  union all select 11, 'events (reservation)', (select count(*) from public.events e, ws where e.workspace_id = ws.id and e.type = 'reservation'), 'written by the trigger'
  union all select 12, 'invoices', (select count(*) from public.invoices i, ws where i.workspace_id = ws.id),
                   (select min(period) || ' .. ' || max(period) from public.invoices i, ws where i.workspace_id = ws.id)
  union all select 13, 'ledger_entries', (select count(*) from public.ledger_entries le, ws where le.workspace_id = ws.id), 'credit / payment'
  union all select 14, 'invoice_matches', (select count(*) from public.invoice_matches im, ws where im.workspace_id = ws.id), null
  union all select 15, 'invoice_match_payments', (select count(*) from public.invoice_match_payments mp, ws where mp.workspace_id = ws.id), null
  union all select 20, 'filter: BI page months', current_setting('perf.series_months')::bigint,
                   pg_temp.mlabel(1 - current_setting('perf.series_months')::int) || ' .. ' || pg_temp.mlabel(0) || ' (current month last)'
  union all select 21, 'filter: BI page requests', current_setting('perf.batch_max')::bigint,
                   'bi.batch_max_requests: monthly capacity + collected, then capacity per level'
  union all select 22, 'filter: yearly series', current_setting('perf.series_years')::bigint, 'bi.series_years calendar years'
  union all select 23, 'filter: payments window rows', current_setting('perf.pay_rows')::bigint,
                   current_setting('perf.pay_from') || ' .. ' || current_setting('perf.pay_to') || ', page ' || current_setting('perf.page_size')
                   || ', deep cursor at row ' || current_setting('perf.cursor_row')
  union all select 24, 'bound: bi.batch_time_budget_ms', current_setting('perf.budget_ms')::bigint, 'also the cancellation probe''s statement_timeout'
  union all select 25, 'bound: kpi.capacity_range_days', current_setting('perf.cap_days')::bigint, null
  union all select 26, 'bound: kpi.finance_range_months', current_setting('perf.fin_months')::bigint, 'months beyond the first'
) t order by o;

-- ============================================================ RESULT 2: the plans
-- (a) One BI page, cold: the first call in this session, with the maximum
--     number of requests the batch takes.
select * from pg_temp.explain('a page cold', current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int)),
  current_setting('perf.batch_max')::int);
-- (b) The same page again, warm.
select * from pg_temp.explain('b page warm', current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int)),
  current_setting('perf.batch_max')::int);
-- (a') The same page a third time without EXPLAIN, to keep the answer:
--      how many figures were computed within the time budget, how many
--      came back as over budget (54000).
select set_config('perf.r_page', pg_temp.call('a'' page answer', current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int)),
  current_setting('perf.batch_max')::int)::text, true) is not null as page_answer_kept;

-- (c) One yearly series (capacity), as _capacitySeries sends it, and
-- (c2) the same years' collected figure.
select * from pg_temp.explain('c yearly capacity', current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.year_batch('capacity.seat_utilisation')), current_setting('perf.series_years')::int);
select * from pg_temp.explain('c2 yearly collected', current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.year_batch('finance.collected')), current_setting('perf.series_years')::int);
select set_config('perf.r_year', pg_temp.call(null, current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.year_batch('capacity.seat_utilisation')))::text, true) is not null as year_answer_kept;

-- (u1-u3) The unit cost: one request of each kind on its own, the KPI
-- functions the batch calls (last full month).
select * from pg_temp.explain('u1 capacity month total', current_setting('perf.owner')::uuid,
  format('select public.kpi_seat_capacity(%L::uuid, %L::timestamptz, %L::timestamptz, null)',
         current_setting('perf.ws'), pg_temp.mstart(-1), pg_temp.mstart(0)), 1);
select * from pg_temp.explain('u2 capacity month 1 level', current_setting('perf.owner')::uuid,
  format('select public.kpi_seat_capacity(%L::uuid, %L::timestamptz, %L::timestamptz, %L::uuid)',
         current_setting('perf.ws'), pg_temp.mstart(-1), pg_temp.mstart(0),
         (select id from perf_level where idx = 0)), 1);
select * from pg_temp.explain('u3 collected month', current_setting('perf.owner')::uuid,
  format('select public.kpi_finance_summary(%L::uuid, %L, %L)',
         current_setting('perf.ws'), pg_temp.mlabel(-1), pg_temp.mlabel(-1)), 1);

-- (d1) The payments behind the collected figure: the first page of the
--      24-month window. (d2) A page deep into the cursor.
select * from pg_temp.explain('d1 payments first page', current_setting('perf.owner')::uuid,
  pg_temp.payments_sql(current_setting('perf.pay_from')::date, current_setting('perf.pay_to')::date, null, null));
select * from pg_temp.explain('d2 payments deep page', current_setting('perf.owner')::uuid,
  pg_temp.payments_sql(current_setting('perf.pay_from')::date, current_setting('perf.pay_to')::date,
                       current_setting('perf.cursor')::jsonb, null));
-- (d3) The page query inside d2 itself, with the same bounds and cursor,
--      to show its plan (run as the connecting role; not an app call).
select * from pg_temp.explain('d3 deep page inner query', null, format($q$
  select mp.matched_at, mp.id, i.number, le.occurred_on
    from public.invoice_match_payments mp
    left join public.invoices i on i.id = mp.invoice_id
    left join public.ledger_entries le on le.id = mp.payment_ledger_id
   where mp.workspace_id = %L::uuid
     and mp.matched_at >= %L::timestamptz and mp.matched_at < %L::timestamptz
     and (mp.matched_at, mp.id) < (%L::timestamptz, %L::uuid)
   order by mp.matched_at desc, mp.id desc
   limit %s$q$,
  current_setting('perf.ws'),
  current_setting('perf.pay_from')::timestamp at time zone current_setting('perf.tz'),
  current_setting('perf.cur')::timestamp at time zone current_setting('perf.tz'),
  current_setting('perf.cursor')::jsonb ->> 'matched_at', current_setting('perf.cursor')::jsonb ->> 'id',
  current_setting('perf.page_size')::int + 1));
select set_config('perf.r_p1', pg_temp.call(null, current_setting('perf.owner')::uuid,
         pg_temp.payments_sql(current_setting('perf.pay_from')::date, current_setting('perf.pay_to')::date, null, null))::text, true) is not null as first_page_kept,
       set_config('perf.r_p2', pg_temp.call(null, current_setting('perf.owner')::uuid,
         pg_temp.payments_sql(current_setting('perf.pay_from')::date, current_setting('perf.pay_to')::date,
                              current_setting('perf.cursor')::jsonb, null))::text, true) is not null as deep_page_kept;

-- (e1) The analyst (viewAnalytics, no viewFinances) asks one collected
--      figure: the refusal path, timed. (e2) The analyst opens the whole
--      page: capacity first, then the first finance figure refuses it.
select * from pg_temp.explain('e1 analyst finance refusal', current_setting('perf.analyst')::uuid,
  pg_temp.batch_sql(jsonb_build_array(pg_temp.fin('f', pg_temp.mlabel(-1), pg_temp.mlabel(-1)))), 1);
select * from pg_temp.explain('e2 analyst whole page', current_setting('perf.analyst')::uuid,
  pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int)),
  current_setting('perf.batch_max')::int);
select set_config('perf.r_e1', pg_temp.call(null, current_setting('perf.analyst')::uuid,
         pg_temp.batch_sql(jsonb_build_array(pg_temp.fin('f', pg_temp.mlabel(-1), pg_temp.mlabel(-1)))))::text, true) is not null as e1_kept,
       set_config('perf.r_e2', pg_temp.call(null, current_setting('perf.analyst')::uuid,
         pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int)))::text, true) is not null as e2_kept;

-- ------------------------------------------------------------ 4. cancellation
-- The largest page under statement_timeout = bi.batch_time_budget_ms. The
-- timeout is set in its own statement, so it is armed when the probe
-- starts. Then the harness's 120 s comes back.
select set_config('statement_timeout', current_setting('perf.budget_ms') || 'ms', true);
select pg_temp.cancel_probe('cancel page at budget', current_setting('perf.owner')::uuid,
  pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int)),
  current_setting('perf.batch_max')::int) as cancellation;
set local statement_timeout = '120s';
select set_config('perf.cancel', (select note from perf_step where step = 'cancel page at budget'), true) is not null as cancel_kept;

-- ------------------------------------------------------------ 5. bounds
-- One batch above bi.batch_max_requests; one capacity figure past
-- kpi.capacity_range_days and one finance figure past
-- kpi.finance_range_months (each refused on its own); a payments page
-- asked with a limit above bi.detail_page_size; a payments window past 24
-- months.
select set_config('perf.r_over', pg_temp.call(null, current_setting('perf.owner')::uuid,
         pg_temp.batch_sql(pg_temp.page_batch(current_setting('perf.batch_max')::int + 1)))::text, true) is not null as over_kept,
       set_config('perf.r_range', pg_temp.call(null, current_setting('perf.owner')::uuid,
         pg_temp.batch_sql(jsonb_build_array(
           pg_temp.cap('cap_long', pg_temp.mstart(-1) - make_interval(days => current_setting('perf.cap_days')::int + 1), pg_temp.mstart(-1)),
           pg_temp.fin('fin_long', pg_temp.mlabel(-2 - current_setting('perf.fin_months')::int), pg_temp.mlabel(-1)))))::text, true) is not null as range_kept,
       set_config('perf.r_p3', pg_temp.call(null, current_setting('perf.owner')::uuid,
         pg_temp.payments_sql(current_setting('perf.pay_from')::date, current_setting('perf.pay_to')::date,
                              null, 10 * current_setting('perf.page_size')::int))::text, true) is not null as clamp_kept,
       set_config('perf.r_p4', pg_temp.call(null, current_setting('perf.owner')::uuid,
         pg_temp.payments_sql((current_setting('perf.cur')::date - interval '25 months')::date,
                              current_setting('perf.pay_to')::date, null, null))::text, true) is not null as window_kept;

insert into perf_check (check_name, expected, actual, pass)
select 'B1 a batch above bi.batch_max_requests is refused whole',
       '22023, no results', coalesce(v ->> 'code', 'answered') || ', results ' || (v ? 'results')::text,
       v ->> 'code' = '22023' and not (v ? 'results')
  from (select current_setting('perf.r_over')::jsonb v) x
union all
select 'B2 the page answers exactly its requests (= bi.batch_max_requests)',
       current_setting('perf.batch_max'), jsonb_array_length(v -> 'results')::text,
       jsonb_array_length(v -> 'results') = current_setting('perf.batch_max')::int
  from (select current_setting('perf.r_page')::jsonb v) x
union all
select 'B3 every answer of the page is a figure or named over budget (54000)',
       'only ok / 54000', pg_temp.describe(v),
       not exists (select 1 from jsonb_array_elements(v -> 'results') r
                    where not (r ->> 'ok')::boolean and r ->> 'code' <> '54000')
  from (select current_setting('perf.r_page')::jsonb v) x
union all
select 'B4 the monthly series has bi.series_months points per metric, no more',
       current_setting('perf.series_months') || ' / ' || current_setting('perf.series_months'),
       (select count(*) from jsonb_array_elements(v -> 'results') r where r ->> 'request_key' like 'c%')
       || ' / ' || (select count(*) from jsonb_array_elements(v -> 'results') r where r ->> 'request_key' like 'f%'),
       (select count(*) from jsonb_array_elements(v -> 'results') r where r ->> 'request_key' like 'c%')
         = current_setting('perf.series_months')::int
       and (select count(*) from jsonb_array_elements(v -> 'results') r where r ->> 'request_key' like 'f%')
         = current_setting('perf.series_months')::int
  from (select current_setting('perf.r_page')::jsonb v) x
union all
select 'B5 the level groups of the page are bounded by the batch (requests - 2 x months)',
       '<= ' || (current_setting('perf.batch_max')::int - 2 * current_setting('perf.series_months')::int),
       (select count(*) from jsonb_array_elements(v -> 'results') r where r ->> 'request_key' like 'l%')::text,
       (select count(*) from jsonb_array_elements(v -> 'results') r where r ->> 'request_key' like 'l%')
         <= current_setting('perf.batch_max')::int - 2 * current_setting('perf.series_months')::int
  from (select current_setting('perf.r_page')::jsonb v) x
union all
select 'B6 the yearly series has bi.series_years points',
       current_setting('perf.series_years'), jsonb_array_length(v -> 'results')::text,
       jsonb_array_length(v -> 'results') = current_setting('perf.series_years')::int
  from (select current_setting('perf.r_year')::jsonb v) x
union all
select 'B7 capacity past kpi.capacity_range_days and finance past kpi.finance_range_months are refused on their own',
       'cap_long 22023, fin_long 22023',
       (select string_agg((r ->> 'request_key') || ' ' || coalesce(r ->> 'code', 'ok'), ', ' order by r ->> 'request_key')
          from jsonb_array_elements(v -> 'results') r),
       (select bool_and(r ->> 'code' = '22023') and count(*) = 2 from jsonb_array_elements(v -> 'results') r)
  from (select current_setting('perf.r_range')::jsonb v) x
union all
select 'B8 the first payments page holds bi.detail_page_size rows and names the next page',
       current_setting('perf.page_size') || ', next true',
       jsonb_array_length(v -> 'items') || ', next ' || (jsonb_typeof(v -> 'next_cursor') = 'object')::text,
       jsonb_array_length(v -> 'items') = current_setting('perf.page_size')::int
       and jsonb_typeof(v -> 'next_cursor') = 'object'
  from (select current_setting('perf.r_p1')::jsonb v) x
union all
select 'B9 the deep page holds at most bi.detail_page_size rows, all after the cursor',
       '<= ' || current_setting('perf.page_size') || ', after true',
       jsonb_array_length(v -> 'items') || ', after ' ||
       coalesce((select bool_and(((i ->> 'matched_at')::timestamptz, (i ->> 'id')::uuid)
                                 < ((c ->> 'matched_at')::timestamptz, (c ->> 'id')::uuid))::text
                   from jsonb_array_elements(v -> 'items') i), 'no rows'),
       jsonb_array_length(v -> 'items') between 1 and current_setting('perf.page_size')::int
       and (select bool_and(((i ->> 'matched_at')::timestamptz, (i ->> 'id')::uuid)
                            < ((c ->> 'matched_at')::timestamptz, (c ->> 'id')::uuid))
              from jsonb_array_elements(v -> 'items') i)
  from (select current_setting('perf.r_p2')::jsonb v, current_setting('perf.cursor')::jsonb c) x
union all
select 'B10 a limit above bi.detail_page_size is clamped to it',
       current_setting('perf.page_size'), coalesce(jsonb_array_length(v -> 'items')::text, v ->> 'code'),
       jsonb_array_length(v -> 'items') = current_setting('perf.page_size')::int
  from (select current_setting('perf.r_p3')::jsonb v) x
union all
select 'B11 a payments window past 24 months is refused',
       '22023', coalesce(v ->> 'code', 'answered'), v ->> 'code' = '22023'
  from (select current_setting('perf.r_p4')::jsonb v) x
union all
select 'B12 the analyst''s finance request is refused whole',
       '42501, no results', coalesce(v ->> 'code', 'answered') || ', results ' || (v ? 'results')::text,
       v ->> 'code' = '42501' and not (v ? 'results')
  from (select current_setting('perf.r_e1')::jsonb v) x
union all
-- If the capacity half uses up the time budget, the finance request is
-- answered 54000 before its reader check runs, and the page is answered
-- instead of refused. This row shows which one happened.
select 'B13 the analyst''s whole page is refused whole (not answered with gaps)',
       '42501, no results', coalesce(v ->> 'code', pg_temp.describe(v)) || ', results ' || (v ? 'results')::text,
       v ->> 'code' = '42501' and not (v ? 'results')
  from (select current_setting('perf.r_e2')::jsonb v) x
union all
select 'B14 the largest page under statement_timeout = bi.batch_time_budget_ms',
       'cancelled (57014) caught, or completed within it', current_setting('perf.cancel'),
       current_setting('perf.cancel') is not null;

-- ============================================================ RESULT 3: the checks
select check_name, expected, actual, pass from perf_check order by ord;

-- ============================================================ RESULT 4: the summary
-- Times in ms. EXPLAIN steps use the plan's Planning/Execution Time and the
-- top node's Buffers line. Clock steps (seed, a', cancel) have no planning
-- time and no buffers. Every plan is in result set 2.
select step,
       requests,
       round(planning_ms, 3) as planning_ms,
       round(execution_ms, 1) as execution_ms,
       shared_hit,
       shared_read,
       temp_written,
       round(mem_bytes / 1048576.0, 1) as backend_mem_mb,
       note
  from perf_step order by ord;

rollback;
