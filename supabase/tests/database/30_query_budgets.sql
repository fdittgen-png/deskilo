-- SPDX-License-Identifier: 0BSD
--
-- #1236 — the database half of the performance budgets.
--
-- "Feels fast on my phone" was the standard, and it was the one thing in
-- the #1225 programme with no evidence at all. `grep -rniE "Stopwatch|
-- elapsedMilliseconds|benchmark"` over the repository returned nothing;
-- the only number anywhere was a 12-second Android boot budget whose own
-- comment says it was set to stop a flake.
--
-- Two kinds of assertion here, and the difference matters:
--
--   * **the indexes exist** — deterministic, machine-independent, and
--     the thing that actually decides whether a query is fast. A table
--     added without one, or an index dropped in a refactor, fails here
--     rather than on somebody's phone eighteen months later.
--
--   * **the plan uses them at realistic scale** — 5 000 reservations in
--     one workspace, analyzed, then EXPLAIN. Postgres will happily seq
--     scan a fixture-sized table and be right to, so a plan assertion is
--     meaningless until there are enough rows for the planner to have a
--     choice. This is that many.
--
-- A wall-clock ceiling sits at the end, deliberately loose. On the dev
-- project `member_statement` over twelve months of ledger measures 73 ms;
-- the budget is 400. Its job is to catch a 5x regression on a shared
-- runner, not to measure the runner.
begin;
select plan(9);

-- ------------------------------------------------------- the indexes
select has_index('public', 'reservations', 'reservations_workspace_time_idx',
  'the hub''s window query — workspace and a time range — has its index');
select has_index('public', 'reservations', 'reservations_member_idx',
  'and "my bookings" has its own');
select has_index('public', 'ledger_entries', 'ledger_member_period_idx',
  'a member''s statement for one period has its index');
select has_index('public', 'invoices', 'invoices_workspace_idx',
  'the invoice register has its index');
select has_index('public', 'events', 'events_pending_idx',
  'the bell badge — what is waiting on me — has its index');

-- --------------------------------------------------- at realistic scale
create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000000e9';
  ws uuid; m uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'scale@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Scale', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;

  -- Five-hour spacing so the blocks do not overlap: `enforce_one_place`
  -- allows a member one reservation at a time, and 5 000 overlapping
  -- rows is not a shape this app can ever hold.
  insert into public.reservations (workspace_id, member_id, starts_at, ends_at,
                                   space_label)
  select ws, m,
         now() - (i * 5 || ' hours')::interval,
         now() - (i * 5 || ' hours')::interval + interval '4 hours',
         'seat ' || i
    from generate_series(1, 5000) i;

  -- Twelve rows is not a scale. The planner seq scans a one-page table
  -- and is RIGHT to — this file says so three paragraphs up, and then
  -- the first version of it asserted an index scan over twelve rows and
  -- was correctly refused. A real workspace's ledger is every member's
  -- charges, credits and payments for years: 5 000 rows across five
  -- years of periods is the shape, and it is the volume at which
  -- `ledger_member_period_idx` earns its keep.
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  select ws, m, 'charge', 'subscription', 10000 + i, 'month',
         to_char(now() - ((i % 60) || ' months')::interval, 'YYYY-MM')
    from generate_series(1, 5000) i;

  -- Without this the planner is working from an empty table's statistics
  -- and every plan below is a guess about a table it thinks has one row.
  analyze public.reservations;
  analyze public.ledger_entries;

  perform set_config('deskilo.scale.ws', ws::text, false);
  perform set_config('deskilo.scale.member', m::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.plan_for(p_sql text) returns text
language plpgsql as $p$
declare r record; out text := '';
begin
  for r in execute 'explain (format text) ' || p_sql loop
    out := out || r."QUERY PLAN" || E'\n';
  end loop;
  return out;
end;
$p$;

select matches(
  pg_temp.plan_for(format(
    $$ select * from public.reservations
        where workspace_id = %L::uuid
          and starts_at >= now() - interval '7 days'
          and starts_at < now() $$,
    current_setting('deskilo.scale.ws'))),
  'Index Scan using reservations_workspace_time_idx',
  'the hub''s week window uses its index at 5 000 rows, not a seq scan');

-- `ok(... not like ...)` rather than pgTAP's `unlike`: that function
-- takes its pattern as `text` and a bare literal arrives as `unknown`,
-- so the overload does not resolve. The assertion is the same one.
select ok(
  pg_temp.plan_for(format(
    $$ select * from public.reservations
        where workspace_id = %L::uuid
          and starts_at >= now() - interval '7 days'
          and starts_at < now() $$,
    current_setting('deskilo.scale.ws'))) not like '%Seq Scan on reservations%',
  'and reads none of the rows outside the window');

select ok(
  pg_temp.plan_for(format(
    $$ select * from public.ledger_entries
        where member_id = %L::uuid and period = %L $$,
    current_setting('deskilo.scale.member'),
    to_char(now(), 'YYYY-MM'))) not like '%Seq Scan on ledger_entries%',
  'a member''s month of ledger is found by an index, not by reading five '
  'years of it');

-- ------------------------------------------------------ the one ceiling
do $time$
declare t0 timestamptz := clock_timestamp();
begin
  perform public.member_statement(
    current_setting('deskilo.scale.member')::uuid,
    to_char(now(), 'YYYY-MM'));
  perform set_config('deskilo.scale.ms',
    round(extract(epoch from clock_timestamp() - t0) * 1000)::text, false);
end;
$time$;

select cmp_ok(
  current_setting('deskilo.scale.ms')::int, '<', 400,
  'member_statement over twelve months answers well inside its budget '
  '(73 ms on the dev project; 400 is the ceiling, loose on purpose)');

select * from finish();
rollback;
