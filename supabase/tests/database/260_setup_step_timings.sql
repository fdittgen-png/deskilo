-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2915 (setup_step_timings): a configurer reports a setup session and the
-- same session reported again is kept once; a member is refused (42501),
-- an unknown step and a negative duration are 22023, and a workspace
-- filming with invented people reports nothing; a row names no person even
-- when a signed-in caller wrote it; nobody reads the table; the ranges
-- answer nothing below five sessions and, from five on, the median to the
-- 80th percentile in whole minutes, always at least a minute apart; a
-- signed-out caller reads no range; and a session never moves the status.
begin;
select plan(25);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002915'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@step-timings.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules)
values('00000000-0000-4000-8000-0000002915b1','Step timings','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002915a1','dev','{"open_weekdays":[1,2,3,4,5]}'),
      ('00000000-0000-4000-8000-0000002915b2','Step timings two','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002915a1','dev','{"open_weekdays":[1,2,3,4,5]}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002915c1','00000000-0000-4000-8000-0000002915b1','00000000-0000-4000-8000-0000002915a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002915c2','00000000-0000-4000-8000-0000002915b1','00000000-0000-4000-8000-0000002915a2',false,false,'active');

create function pg_temp.as_user(p_suffix text) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000002915' || p_suffix, 'role', 'authenticated')::text, true)
$$;
create function pg_temp.record(p_step text, p_opened text, p_seconds int)
returns boolean language sql as $$
  select public.record_setup_step_timing('00000000-0000-4000-8000-0000002915b1', p_step, p_opened::timestamptz, p_seconds)
$$;
create function pg_temp.rows_of(p_step text) returns bigint language sql as $$
  select count(*) from public.setup_step_timings
   where workspace_id = '00000000-0000-4000-8000-0000002915b1' and step = p_step
$$;
create function pg_temp.range_of(p_step text) returns jsonb language sql as $$
  select r from jsonb_array_elements(public.setup_step_timing_ranges()) r where r->>'step' = p_step
$$;
create function pg_temp.status() returns jsonb language sql as $$
  select public.workspace_setup_status('00000000-0000-4000-8000-0000002915b1')
$$;

select pg_temp.as_user('a1');
create temp table before_timings as select pg_temp.status() as status;

-- Recording, and the same session again.
select ok(pg_temp.record('basics', '2026-05-13T10:00:00Z', 240), 'a configurer reports a session');
select is(pg_temp.rows_of('basics'), 1::bigint, 'and it is kept');
select is((select duration_seconds from public.setup_step_timings where step = 'basics'
            and workspace_id = '00000000-0000-4000-8000-0000002915b1'), 240, 'with its duration');
select ok(not pg_temp.record('basics', '2026-05-13T10:00:00Z', 240), 'the same session reported again is not new');
select is(pg_temp.rows_of('basics'), 1::bigint, 'and is kept once');
select ok(pg_temp.record('basics', '2026-05-13T11:00:00Z', 120), 'another session on the same step is');

-- No person, whoever wrote it.
select is((select count(*) from public.setup_step_timings
            where created_by_user is not null or modified_by_user is not null), 0::bigint,
  'no row names the caller who reported it');
select is_empty($$ select column_name from information_schema.columns
                    where table_schema = 'public' and table_name = 'setup_step_timings'
                      and (column_name in ('user_id', 'member_id', 'created_by', 'updated_by', 'reported_by')
                           or column_name like '%name%' or column_name like '%email%') $$,
  'the table has no column for a person');
select ok(not has_table_privilege('authenticated', 'public.setup_step_timings', 'select'),
  'nobody reads the table except through the functions');

-- Refusals.
select throws_ok($$select pg_temp.record('nope', '2026-05-13T10:00:00Z', 60)$$, '22023', null,
  'an unknown step is refused');
select throws_ok($$select pg_temp.record('basics', '2026-05-13T12:00:00Z', -1)$$, '22023', null,
  'a negative duration is refused');
select pg_temp.as_user('a2');
select throws_ok($$select pg_temp.record('basics', '2026-05-13T13:00:00Z', 60)$$, '42501', null,
  'a plain member cannot report a session');

-- Recording privacy: nothing is kept.
select pg_temp.as_user('a1');
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"recordingPrivacy": true}'::jsonb
 where id = '00000000-0000-4000-8000-0000002915b1';
select ok(not pg_temp.record('basics', '2026-05-13T14:00:00Z', 60),
  'a workspace filming with invented people reports nothing');
select is(pg_temp.rows_of('basics'), 2::bigint, 'and nothing was kept');
update public.workspaces set feature_flags = feature_flags - 'recordingPrivacy'
 where id = '00000000-0000-4000-8000-0000002915b1';

-- The ranges: below five sessions nothing, from five on the median to the
-- 80th percentile, over the instance (two workspaces here).
insert into public.setup_step_timings (workspace_id, step, opened_at, duration_seconds)
select '00000000-0000-4000-8000-0000002915b2', 'hours', ('2026-05-13T10:00:00Z'::timestamptz + make_interval(mins => i)), 300
  from generate_series(1, 4) i;
select is(pg_temp.range_of('hours'), null, 'four sessions answer no range');
select is(pg_temp.range_of('basics'), null, 'nor do two');
-- basics: 240 and 120 above; 180, 300 and 600 here -> 120 180 240 300 600:
-- the median is 240 s (4 min), the 80th percentile 360 s (6 min).
insert into public.setup_step_timings (workspace_id, step, opened_at, duration_seconds) values
 ('00000000-0000-4000-8000-0000002915b2', 'basics', '2026-05-13T10:00:00Z', 180),
 ('00000000-0000-4000-8000-0000002915b2', 'basics', '2026-05-13T11:00:00Z', 300),
 ('00000000-0000-4000-8000-0000002915b2', 'basics', '2026-05-13T12:00:00Z', 600);
select is(pg_temp.range_of('basics') - 'samples', '{"step":"basics","low_minutes":4,"high_minutes":6}'::jsonb,
  'five sessions answer the median to the 80th percentile, in minutes');
select is(pg_temp.range_of('basics')->>'samples', '5', 'counting them over the instance');
-- Six sessions of exactly one minute: the range is still a range.
insert into public.setup_step_timings (workspace_id, step, opened_at, duration_seconds)
select '00000000-0000-4000-8000-0000002915b2', 'places', ('2026-05-13T10:00:00Z'::timestamptz + make_interval(mins => i)), 60
  from generate_series(1, 6) i;
select is(pg_temp.range_of('places') - 'samples', '{"step":"places","low_minutes":1,"high_minutes":2}'::jsonb,
  'a median equal to the 80th percentile still spans a minute');
-- Seconds under a minute never read as nothing.
insert into public.setup_step_timings (workspace_id, step, opened_at, duration_seconds)
select '00000000-0000-4000-8000-0000002915b2', 'invite', ('2026-05-13T10:00:00Z'::timestamptz + make_interval(mins => i)), 20
  from generate_series(1, 5) i;
select is(pg_temp.range_of('invite') - 'samples', '{"step":"invite","low_minutes":1,"high_minutes":2}'::jsonb,
  'a step done in seconds reads as a minute or two');
select is((select count(*) from jsonb_array_elements(public.setup_step_timing_ranges())), 3::bigint,
  'and only the steps with enough sessions are answered');
select is((select jsonb_agg(r->>'step') from jsonb_array_elements(public.setup_step_timing_ranges()) r),
  '["basics","invite","places"]'::jsonb, 'in step order');

-- A plain member reads the ranges (they name no space); a signed-out caller does not.
select pg_temp.as_user('a2');
select is(pg_temp.range_of('basics')->>'low_minutes', '4', 'a member reads the same ranges');
select set_config('request.jwt.claims', '', true);
select throws_ok($$select public.setup_step_timing_ranges()$$, '42501', null,
  'a signed-out caller reads none');

-- A session never moves the setup status.
select pg_temp.as_user('a1');
select is(pg_temp.status(), (select status from before_timings),
  'the setup status is the same as before any session');

select * from finish();
rollback;
