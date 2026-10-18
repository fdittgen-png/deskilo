-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2590 / 0477 (C1): reading a month of usage is observational, preparing it
-- is a command. Real roles; every refusal is followed by a readback.
-- Expected values are written by hand: two members each booked two hours last
-- week; nothing is recorded until someone prepares the month.
--   A the pure read says "incomplete", not "zero"   B it writes nothing
--   C refusals   D the explicit preparation   E replay and idempotence
--   F the compatibility wrapper still prepares   G nobody reads another's
begin;
select plan(23);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002590' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int) returns uuid language sql as $$
  select id from public.members where user_id = pg_temp.u(n) and workspace_id = current_setting('t.a')::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.read(p_user uuid, p_period text, p_member uuid default null) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.usage_records_read_v1(%L, %L, %L)',
    current_setting('t.a'), p_period, p_member));
end;
$$;
create function pg_temp.counts() returns text language sql as $$
  select (select count(*) from public.usage_records)::text || '/' || (select count(*) from public.events)::text
         || '/' || (select count(*) from public.ledger_entries)::text || '/' || (select count(*) from public.invoices)::text;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@usage.test', '', now(), now(), now()
  from generate_series(1, 5) i;
-- 1 owner of A, 2 and 3 plain members of A, 5 owner of B.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Usage A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(5));
select public.create_workspace('Usage B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null);
reset role;
update public.workspaces set booking_rules = '{"granularity":"half_day"}'::jsonb where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, false, 'active', 100, '2026-01-01');
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000259000b1', current_setting('t.a')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000259000b2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000259000b1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000259000b3', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000259000b2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y) values
 ('00000000-0000-4000-8000-0000259000b4', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000259000b3', 1, 1),
 ('00000000-0000-4000-8000-0000259000b5', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000259000b3', 8, 1);

-- last week's Monday, two hours each, one per member, inside working hours
select set_config('t.mon', (date_trunc('week', now() - interval '7 days') + interval '9 hours')::text, true);
select set_config('t.period', to_char(current_setting('t.mon')::timestamp, 'YYYY-MM'), true);
insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at, status) values
 ('00000000-0000-4000-8000-0000259000e1', current_setting('t.a')::uuid,
  (select id from public.members where user_id = pg_temp.u(2) and workspace_id = current_setting('t.a')::uuid),
  '00000000-0000-4000-8000-0000259000b4',
  current_setting('t.mon')::timestamp at time zone 'Europe/Paris',
  (current_setting('t.mon')::timestamp + interval '2 hours') at time zone 'Europe/Paris', 'completed'),
 ('00000000-0000-4000-8000-0000259000e2', current_setting('t.a')::uuid,
  (select id from public.members where user_id = pg_temp.u(3) and workspace_id = current_setting('t.a')::uuid),
  '00000000-0000-4000-8000-0000259000b5',
  current_setting('t.mon')::timestamp at time zone 'Europe/Paris',
  (current_setting('t.mon')::timestamp + interval '2 hours') at time zone 'Europe/Paris', 'completed');
select set_config('t.before', pg_temp.counts(), true);

-- ── A: incomplete, not zero ────────────────────────────────────────────
select is(jsonb_array_length(pg_temp.read(pg_temp.u(2), current_setting('t.period')) -> 'records'), 0, 'A: before preparation the month holds no record');
select is(pg_temp.read(pg_temp.u(2), current_setting('t.period')) #>> '{coverage,complete}', 'false', 'A: and says it is incomplete, not zero');
select is(pg_temp.read(pg_temp.u(2), current_setting('t.period')) #>> '{coverage,unprepared_reservations}', '1', 'A: a member counts their own unprepared booking only');
select is(pg_temp.read(pg_temp.u(1), current_setting('t.period')) #>> '{coverage,unprepared_reservations}', '2', 'A: the owner counts both: the money gate lets them see both members');

-- ── B: nothing is written by a read ────────────────────────────────────
select pg_temp.read(pg_temp.u(1), current_setting('t.period'));
select pg_temp.read(pg_temp.u(1), current_setting('t.period'), pg_temp.mem(2));
select pg_temp.read(pg_temp.u(3), current_setting('t.period'));
select is(pg_temp.counts(), current_setting('t.before'), 'B: repeated reads left usage, events, ledger and invoices as they were');

-- ── C: refusals ────────────────────────────────────────────────────────
select ok((pg_temp.read(pg_temp.u(2), '2026-13')::text) like '%invalid period%', 'C: a month 13 is refused, not mapped to today');
select ok((pg_temp.read(pg_temp.u(2), 'last month')::text) like '%invalid period%', 'C: nor free text');
select ok((pg_temp.read(pg_temp.u(5), current_setting('t.period'))::text) like '%not a member%', 'C: a foreign owner reads nothing');
select ok((pg_temp.as_json(pg_temp.u(5), format('select public.prepare_usage_period_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.period'), pg_temp.rq(1)))::text) like '%not a member%',
  'C: nor prepares');
select ok((pg_temp.as_json(pg_temp.u(2), format('select public.prepare_usage_period_v1(%L, ''2026-00'', %L)', current_setting('t.a'), pg_temp.rq(2)))::text) like '%invalid period%',
  'C: an invalid period is not prepared');
select is(pg_temp.counts(), current_setting('t.before'), 'C: readback: no refusal wrote anything');

-- ── D: the explicit preparation ────────────────────────────────────────
select set_config('t.p1', pg_temp.as_json(pg_temp.u(2), format('select public.prepare_usage_period_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.period'), pg_temp.rq(3)))::text, true);
select is(current_setting('t.p1')::jsonb ->> 'prepared', '2', 'D: preparing the month records both bookings, as the materialiser always did');
select is((select count(*)::int from public.usage_records where workspace_id = current_setting('t.a')::uuid), 2, 'D: and exactly two records exist');
select is(jsonb_array_length(pg_temp.read(pg_temp.u(2), current_setting('t.period')) -> 'records'), 1, 'D: the member then reads their own record');
select is(pg_temp.read(pg_temp.u(2), current_setting('t.period')) #>> '{coverage,complete}', 'true', 'D: and the month reads as complete');
select is(jsonb_array_length(pg_temp.read(pg_temp.u(1), current_setting('t.period')) -> 'records'), 2, 'D: the owner reads both');

-- ── E: replay and idempotence ──────────────────────────────────────────
select is(pg_temp.as_json(pg_temp.u(2), format('select public.prepare_usage_period_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.period'), pg_temp.rq(3))),
  current_setting('t.p1')::jsonb, 'E: the same request answers the original');
select is(pg_temp.as_json(pg_temp.u(3), format('select public.prepare_usage_period_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.period'), pg_temp.rq(4))) ->> 'prepared', '0',
  'E: a second request over the same month prepares nothing more');
select is((select count(*)::int from public.usage_records where workspace_id = current_setting('t.a')::uuid), 2, 'E: and no duplicate row exists');

-- ── F: the compatibility wrapper keeps its documented semantics ────────
update public.usage_records set reservation_id = null where reservation_id = '00000000-0000-4000-8000-0000259000e2';
delete from public.usage_records where reservation_id is null and workspace_id = current_setting('t.a')::uuid;
select is(jsonb_array_length(pg_temp.read(pg_temp.u(1), current_setting('t.period')) -> 'records'), 1, 'F: one record is missing again');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.usage_records_for(%L, %L)', current_setting('t.a'), current_setting('t.period'))) -> 'records'), 2,
  'F: the legacy read still prepares as it always did (old clients keep working)');

-- ── G: nobody reads another's ──────────────────────────────────────────
select is(jsonb_array_length(pg_temp.read(pg_temp.u(1), current_setting('t.period'), pg_temp.mem(2)) -> 'records'), 1,
  'G: positive control: the owner asking for that member''s month gets it');
select is(jsonb_array_length(pg_temp.read(pg_temp.u(3), current_setting('t.period'), pg_temp.mem(2)) -> 'records'), 0,
  'G: a plain member asking for another member''s month gets nothing');

select * from finish();
rollback;
