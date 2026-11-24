-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4416 (0953): an error report reaches the installation through submit_trace_report_v1 only: a signed-in person,
-- never an assistant's session; the device's hourly budget and the size cap are the installation's settings and
-- answer, never raise; reports past the retention are deleted when a new one arrives; only the installation's
-- operator reads them. Rolled back.
begin;
select plan(22);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004416' || lpad(n::text, 4, '0'))::uuid;
$$;
-- the answer of a statement run as a signed-in user (null = nobody, negative = that user's assistant session),
-- or ERR and its code
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', case
    when n is null then ''
    when n < 0 then json_build_object('sub', pg_temp.u(-n), 'role', 'authenticated', 'client_id', 'assistant')::text
    else json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text end, true);
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  return coalesce(v, 'null');
end $f$;
create function pg_temp.send(n int, p_device text, p_stack text default 'at main (app.dart:1)') returns text
language sql as $$
  select pg_temp.as_user(n, format(
    $q$select public.submit_trace_report_v1(%L, '2.2.0', 953, 'android', 'StateError', 'DKN01', %L)$q$,
    p_device, p_stack))
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'trace' || n || '@example.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.platform_admins (user_id) values (pg_temp.u(2));

-- ── the settings: the installation's, bounded, with their defaults ──
select is((select (default_value, min_value, max_value, unit)::text from public.setting_definitions
            where key = 'trace.reports_per_hour'), '(20,0,600,"per hour")', 'reports per device and hour: 20, 0..600');
select is((select (default_value, min_value, max_value, unit)::text from public.setting_definitions
            where key = 'trace.report_max_bytes'), '(16384,1024,262144,bytes)', 'the size cap: 16384 bytes, 1024..262144');
select is((select (default_value, min_value, max_value, unit)::text from public.setting_definitions
            where key = 'trace.report_retention_days'), '(30,1,365,days)', 'the retention: 30 days, 1..365');
select is((select array_agg(distinct s) from public.setting_definitions, unnest(scopes) s where key like 'trace.%'),
  array['platform'], 'all three belong to the installation, not to a workspace');

-- ── the table: no door but the two functions ──
select ok((select relrowsecurity from pg_class where oid = 'public.trace_reports'::regclass), 'row level security is on');
select ok(not has_table_privilege('authenticated', 'public.trace_reports', 'select, insert, update, delete'),
  'a signed-in person cannot touch the table itself');
select ok(not has_table_privilege('anon', 'public.trace_reports', 'select, insert'), 'nor can anybody');

-- ── who may send ──
select is(pg_temp.send(null, 'device-aaaa-1'), 'ERR DKN01', 'nobody signed in sends nothing');
select is(pg_temp.send(-1, 'device-aaaa-1'), 'ERR DKN01', 'an assistant''s session sends nothing');
select is(pg_temp.send(1, 'bad id'), 'malformed', 'a malformed device id is answered, not stored');
select is(pg_temp.send(1, 'device-aaaa-1'), 'stored', 'a signed-in person''s report is stored');
select is((select (app_version, schema_version, platform, failure_type, failure_code, created_by_user)::text
             from public.trace_reports where device_id = 'device-aaaa-1'),
  format('(2.2.0,953,android,StateError,DKN01,%s)', pg_temp.u(1)), 'with its versions, platform, type, code and sender');

-- ── the size cap ──
select is(pg_temp.send(1, 'device-aaaa-1', repeat('x', 16385)), 'too_large', 'a report over the cap is answered, not stored');
insert into public.setting_values (scope, key, value) values ('platform', 'trace.report_max_bytes', '20000');
select is(pg_temp.send(1, 'device-aaaa-1', repeat('x', 16385)), 'stored', 'the cap is the installation''s setting');

-- ── the hourly budget, per device ──
insert into public.setting_values (scope, key, value) values ('platform', 'trace.reports_per_hour', '3');
select is(pg_temp.send(1, 'device-aaaa-1'), 'stored', 'the third report of the hour is stored');
select is(pg_temp.send(1, 'device-aaaa-1'), 'rate_limited', 'the fourth is answered over budget, not stored');
select is((select count(*)::int from public.trace_reports where device_id = 'device-aaaa-1'), 3,
  'the device holds three reports of this hour');
select is(pg_temp.send(1, 'device-bbbb-2'), 'stored', 'another device has its own budget');
update public.setting_values set value = '0' where scope = 'platform' and key = 'trace.reports_per_hour';
select is(pg_temp.send(1, 'device-cccc-3'), 'rate_limited', '0 turns error reports off');
update public.setting_values set value = '3' where scope = 'platform' and key = 'trace.reports_per_hour';

-- ── the retention ──
insert into public.trace_reports (device_id, app_version, platform, failure_type, reported_at)
values ('device-old-0001', '2.1.0', 'ios', 'TypeError', now() - make_interval(days => 31));
select pg_temp.send(1, 'device-dddd-4');
select is((select count(*)::int from public.trace_reports where device_id = 'device-old-0001'), 0,
  'a report past the retention is gone once a new one arrives');

-- ── who reads ──
select is(pg_temp.as_user(1, 'select public.instance_trace_reports_v1(10)::text') like 'ERR %', true,
  'a person who is no operator reads nothing');
select is(pg_temp.as_user(2, $q$select (public.instance_trace_reports_v1(10)->0->>'device_id')$q$), 'device-dddd-4',
  'the operator reads the newest report first');

select * from finish();
rollback;
