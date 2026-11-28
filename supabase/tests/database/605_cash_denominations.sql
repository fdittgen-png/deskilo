-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4511 (0997): the notes and coins of a currency are one reference that everyone signed in reads and no one writes; a
-- till counts in its own pick of its business currency's, or all of them; who manages the sites picks, among the
-- currency's current values only; a float or count by denomination names only the till's values, and a count stored
-- before keeps its values, as does a till whose currency the reference does not list. Rolled back.
begin;
select plan(15);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.err(p_sql text) returns text language plpgsql as $f$
declare d text;
begin
  execute p_sql;
  return 'ok';
exception when others then
  get stacked diagnostics d = pg_exception_detail;
  return 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
end
$f$;
create or replace function pg_temp.pick(p_user int, p_till int, p_values text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_till_denominations_set_v1(%L, %L, %L::bigint[])::text',
    pg_temp.u(101), pg_temp.u(p_till), p_values))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tcash-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags) values
  (pg_temp.u(101), 'Cash EUR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}'),
  (pg_temp.u(102), 'Cash THB', 'FR', 'THB', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.counter_tills (id, workspace_id, name, active) values
  (pg_temp.u(401), pg_temp.u(101), 'Front', true),
  (pg_temp.u(402), pg_temp.u(101), 'Back', true),
  (pg_temp.u(403), pg_temp.u(102), 'Thai', true),
  (pg_temp.u(404), pg_temp.u(101), 'Side', true);

-- the reference
select is((select count(*)::int from public.cash_denominations where currency = 'EUR'), 15, 'the euro has its 8 coins and 7 notes');
select is((select count(*)::int from public.cash_denominations where currency = 'USD' and value_minor = 100), 2,
  'a dollar is a note and a coin');
select is(pg_temp.run_as(pg_temp.u(2), 'select count(*)::text from public.cash_denominations where currency = ''JPY'''), '10',
  'a member reads the reference');
select is(pg_temp.run_as(pg_temp.u(1), 'insert into public.cash_denominations (currency, value_minor, form) values (''EUR'', 300, ''note'') returning 1'),
  'ERR 42501', 'and no one writes it');

-- a till's pick
select is(pg_temp.pick(2, 401, '{1,2}'), 'ERR DKN01', 'a member who does not manage the sites picks nothing');
select is(pg_temp.pick(1, 401, '{300}'), 'ERR DKL02 {"value": 300, "reason": "denomination"}', 'a value the euro has no note or coin of is refused');
select is(pg_temp.pick(1, 401, '{5,10,20,50,100,200,500,1000,2000,5000}')::jsonb -> 'values',
  '[5000, 2000, 1000, 500, 200, 100, 50, 20, 10, 5]'::jsonb, 'the owner picks the front till''s drawer: no 1 and 2 cent coins, no large notes');
select is((select cardinality(public.counter_till_cash_values(t)) from public.counter_tills t where t.id = pg_temp.u(402)), 15,
  'another till counts in every current value');

-- counts
select is(pg_temp.err(format('insert into public.counter_till_sessions (workspace_id, till_id, float_minor, float_denominations) values (%L, %L, 2003, %L)',
  pg_temp.u(101), pg_temp.u(401), '{"2000": 1, "1": 3}')), 'ERR DKL02 {"value": 1, "reason": "denomination"}',
  'a float naming a coin the till does not carry is refused');
select is(pg_temp.err(format('insert into public.counter_till_sessions (workspace_id, till_id, float_minor, float_denominations) values (%L, %L, 3000, %L)',
  pg_temp.u(101), pg_temp.u(401), '{"2000": 1, "500": 2}')), 'ok', 'a float in the till''s notes is kept');
select is(pg_temp.err(format('insert into public.counter_till_sessions (workspace_id, till_id, float_minor, float_denominations) values (%L, %L, 2003, %L)',
  pg_temp.u(101), pg_temp.u(402), '{"2000": 1, "1": 3}')), 'ok', 'the back till carries the cents');
-- a count stored before the pick keeps its values
select ok(pg_temp.pick(1, 404, '{5,10,20,50,100,200,500,1000,2000,5000}') like '{%', 'the side till carries what the front one does');
set session_replication_role = replica;
insert into public.counter_till_sessions (id, workspace_id, company_id, till_id, float_minor, float_denominations)
values (pg_temp.u(901), pg_temp.u(101), pg_temp.u(101), pg_temp.u(404), 301, '{"300": 1, "1": 1}');
set session_replication_role = origin;
select is(pg_temp.err(format('update public.counter_till_sessions set float_denominations = %L where id = %L',
  '{"300": 1, "1": 1, "500": 0}', pg_temp.u(901))), 'ok', 'a count stored before keeps the values it named');
select is(pg_temp.err(format('update public.counter_till_sessions set float_denominations = %L where id = %L',
  '{"300": 1, "1": 1, "7": 1}', pg_temp.u(901))), 'ERR DKL02 {"value": 7, "reason": "denomination"}', 'but takes no new one');
select is(pg_temp.err(format('insert into public.counter_till_sessions (workspace_id, till_id, float_minor, float_denominations) values (%L, %L, 2300, %L)',
  pg_temp.u(102), pg_temp.u(403), '{"2000": 1, "300": 1}')), 'ok', 'a till whose currency the reference does not list counts as before');

select * from finish();
rollback;
