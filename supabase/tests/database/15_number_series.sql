-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0217 — #1320: a number series never issues the same number twice.
--
-- A restart finer than the printed date, or a restart changed inside a
-- period, re-issued numbers that already existed: invoicing then failed
-- on the unique index for the whole period, and member numbers were
-- duplicated silently. Each scenario below failed before 0217 for the
-- reason it names. Period keys are computed with the workspace's own
-- number_sequence_period_key, so the file holds on any date.
begin;
select plan(18);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000f1';
  ws uuid;
begin
  -- The profile comes from the trigger on `auth.users`; never insert it.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'series-owner@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Series', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true);
  perform set_config('deskilo.series.ws', ws::text, true);
  perform set_config('deskilo.series.owner', u_owner::text, true);
end
$seed$;

-- The row as a draw finds it, written directly (as the database would
-- hold it after years of use).
create or replace function pg_temp.state(p_date text, p_reset text, p_key text, p_next bigint)
returns void language sql as $state$
  insert into public.number_sequences (workspace_id, journal, prefix, date_part, reset, period_key, next_value)
  values (current_setting('deskilo.series.ws')::uuid, 'zz_series', 'H-', p_date, p_reset, p_key, p_next)
  on conflict (workspace_id, journal) do update
    set prefix = excluded.prefix, suffix = '', date_part = excluded.date_part,
        reset = excluded.reset, period_key = excluded.period_key, next_value = excluded.next_value;
$state$;

create or replace function pg_temp.key(p_reset text, p_back interval default '0'::interval)
returns text language sql as $key$
  select public.number_sequence_period_key(current_setting('deskilo.series.ws')::uuid, p_reset, now() - p_back);
$key$;

create or replace function pg_temp.draw() returns text language sql as $draw$
  select public.next_document_number(current_setting('deskilo.series.ws')::uuid, 'zz_series');
$draw$;

-- set_number_sequence as the owner, through the authenticated role.
create or replace function pg_temp.configure(p_prefix text, p_date text, p_reset text)
returns void language plpgsql as $configure$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.series.owner'), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', current_setting('deskilo.series.owner'), true);
  execute 'set local role authenticated';
  perform public.set_number_sequence(current_setting('deskilo.series.ws')::uuid, 'zz_series',
    p_prefix, '', p_date, 4, p_reset);
  execute 'reset role';
exception when others then
  execute 'reset role';
  raise;
end
$configure$;

select pg_temp.seed();

-- ------------------------------------------------------------ pairs
select pg_temp.state('year', 'yearly', '', 1);
select throws_matching($$select pg_temp.configure('H-', 'none', 'yearly')$$,
  'cannot restart more often', 'no date, restart every year: refused');
select throws_matching($$select pg_temp.configure('H-', 'none', 'monthly')$$,
  'cannot restart more often', 'no date, restart every month: refused');
select throws_matching($$select pg_temp.configure('H-', 'year', 'monthly')$$,
  'cannot restart more often', 'the year, restart every month: refused');
select lives_ok($$select pg_temp.configure('H-', 'none', 'never')$$, 'no date, never: accepted');
select lives_ok($$select pg_temp.configure('H-', 'year', 'never')$$, 'the year, never: accepted');
select lives_ok($$select pg_temp.configure('H-', 'year', 'yearly')$$, 'the year, every year: accepted');
select lives_ok($$select pg_temp.configure('H-', 'year_month', 'never')$$, 'year and month, never: accepted');
select lives_ok($$select pg_temp.configure('H-', 'year_month', 'yearly')$$, 'year and month, every year: accepted');
select lives_ok($$select pg_temp.configure('H-', 'year_month', 'monthly')$$, 'year and month, every month: accepted');

-- ------------------------------------------------------------ draws
-- Before 0217 changing the restart moved the key at once, and the next
-- draw restarted inside a year that had already issued 0001.
select pg_temp.state('year', 'yearly', pg_temp.key('yearly'), 3);
select pg_temp.configure('H-', 'year', 'never');
select is(pg_temp.draw(), 'H-' || pg_temp.key('yearly') || '-0003',
  'a restart changed mid-period continues the counter');

-- A legacy row printed no date but restarted yearly: drawn as never.
select pg_temp.state('none', 'yearly', pg_temp.key('yearly', '1 year'), 7);
select is(public.preview_document_number(current_setting('deskilo.series.ws')::uuid, 'zz_series'),
  'H-0007', 'the preview of a legacy invalid pair continues too');
select is(pg_temp.draw(), 'H-0007', 'a legacy invalid pair continues instead of printing H-0001 again');

-- A genuinely new period of the same granularity still restarts.
select pg_temp.state('year', 'yearly', pg_temp.key('yearly', '1 year'), 9);
select is(pg_temp.draw(), 'H-' || pg_temp.key('yearly') || '-0001', 'a new year restarts the counter');
select is(pg_temp.draw(), 'H-' || pg_temp.key('yearly') || '-0002', 'and counts on from there');

-- monthly → yearly inside a year-month series: before 0217 the next draw
-- restarted and printed this month's 0001 a second time.
select pg_temp.state('year_month', 'monthly', pg_temp.key('monthly'), 4);
select pg_temp.configure('H-', 'year_month', 'yearly');
select is(pg_temp.draw(), 'H-' || pg_temp.key('monthly') || '-0004',
  'switching to a coarser restart mid-month continues the counter');

-- ------------------------------------------------------------ removing the date
select pg_temp.state('year', 'yearly', pg_temp.key('yearly'), 5);
select throws_matching($$select pg_temp.configure('H-', 'none', 'never')$$,
  'removing the date', 'removing the date after numbers were issued needs a new prefix or suffix');
select lives_ok($$select pg_temp.configure('H2-', 'none', 'never')$$,
  'with a new prefix the date may go');

-- ------------------------------------------------------------ uniqueness
select ok(exists (select 1 from pg_indexes where indexname = 'members_workspace_member_number_key'),
  'member numbers are unique within a workspace');

select * from finish();
rollback;
