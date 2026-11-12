-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3648 (0737): the day a week starts on is a member's preference. The
-- profile holds it (default `locale`, the format locale's own first day);
-- set_personal_preferences accepts locale, monday, sunday and saturday and
-- refuses anything else; my_personal_preferences reads it back, personal and
-- per workspace; the registry names the platform's default; the profile's
-- system columns are untouched. Rolled back.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare u uuid := '00000000-0000-4000-8000-000000003648'; ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'week-start@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Week space', 'US', 'USD', 'America/New_York', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
  values (ws, u, true, true, 'active');
  perform set_config('t.u', u::text, false);
  perform set_config('t.ws', ws::text, false);
end;
$seed$;
select pg_temp.seed();

-- Runs [sql] as the member; answers the error code, or 'ok'.
create or replace function pg_temp.as_member(sql text) returns text language plpgsql as $f$
declare v_state text := 'ok';
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    execute sql;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    v_state := v_state || ': ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v_state;
end
$f$;

create or replace function pg_temp.read(p_ws uuid default null) returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.my_personal_preferences(p_ws);
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

select is((select week_start from public.profiles where id = current_setting('t.u')::uuid), 'locale',
  'a profile starts on its format locale''s own first day');

select throws_ok(
  format($$update public.profiles set week_start = 'friday' where id = %L$$, current_setting('t.u')),
  '23514', null, 'the profile holds no other day');

select is(pg_temp.as_member($$select public.set_personal_preferences('{"week_start": "monday"}'::jsonb)$$), 'ok',
  'a member sets Monday');
select is((select week_start from public.profiles where id = current_setting('t.u')::uuid), 'monday',
  'and the profile holds it');
select is(pg_temp.read() -> 'defaults' ->> 'week_start', 'monday',
  'my_personal_preferences reads it back');

select is((select string_agg(pg_temp.as_member(format(
            $$select public.set_personal_preferences(jsonb_build_object('week_start', %L))$$, d)), ',')
             from unnest(array['sunday', 'saturday', 'locale']) d), 'ok,ok,ok',
  'Sunday, Saturday and the locale''s own are accepted');

select ok(pg_temp.as_member($$select public.set_personal_preferences('{"week_start": "friday"}'::jsonb)$$)
  ~ '^P0001: invalid preference value', 'any other day is refused');
select ok(pg_temp.as_member($$select public.set_personal_preferences('{"week_start": 1}'::jsonb)$$)
  ~ '^P0001: invalid preference value', 'and so is a number');

select is(pg_temp.as_member(format(
  $$select public.set_personal_preferences('{"week_start": "sunday"}'::jsonb, %L)$$, current_setting('t.ws'))), 'ok',
  'a member sets Sunday for one workspace');
select is(pg_temp.read(current_setting('t.ws')::uuid) -> 'overrides' ->> 'week_start', 'sunday',
  'and reads that workspace''s choice back');

select is((select default_value #>> '{}' from public.setting_definitions where key = 'locale.default_week_start'),
  'locale', 'the platform''s default is the format locale''s own first day');

select ok(not exists (select 1 from unnest(public.system_column_names()) c
                      where not exists (select 1 from information_schema.columns
                                         where table_schema = 'public' and table_name = 'profiles'
                                           and column_name = c)),
  'the profile keeps every system column');

select * from finish();
rollback;
