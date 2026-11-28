-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4514 (0999): a business's cash reasons are records: a new business has the built-in ones; a business's old setting
-- became reasons once, its own words named as it typed them; every member reads them and no one writes the table; who
-- configures the tills adds a reason (its code made from its name), renames its own ones, changes their processes and
-- archives one, where cash reasons are on; a cash entry and a count's difference take only an active reason of their
-- process, whatever door writes them, and a reason stored before stays. Rolled back.
begin;
select plan(19);

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
-- [p_user] writes a reason of the business 101
create or replace function pg_temp.save(p_user int, p_code text, p_name text, p_processes text, p_archived boolean default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_cash_reason_save_v1(%L, %L, %L, %L::text[], null, %L)::text',
    pg_temp.u(101), p_code, p_name, p_processes, p_archived))
$f$;
-- the owner records cash of [p_kind] with [p_reason] in the open session
create or replace function pg_temp.entry(p_n int, p_kind text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.counter_cash_entry_v1(%L, %L, %L, %L, 500, %L, null) ->> ''kind''',
    pg_temp.u(101), pg_temp.u(800 + p_n), pg_temp.u(601), p_kind, p_reason))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'treason-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags) values
  (pg_temp.u(101), 'Reasons FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterCashReasons": true}'),
  (pg_temp.u(102), 'Reasons off', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterCashReasons": false}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(1), true, true, 'active');
insert into public.counter_tills (id, workspace_id, name, active) values (pg_temp.u(401), pg_temp.u(101), 'Front', true),
  (pg_temp.u(402), pg_temp.u(101), 'Back', true);
insert into public.counter_till_sessions (id, workspace_id, till_id, float_minor) values (pg_temp.u(601), pg_temp.u(101), pg_temp.u(401), 10000);

-- the reasons a business has
select is((select array_agg(code order by sort_order) from public.counter_cash_reasons where workspace_id = pg_temp.u(101)),
  array['change', 'expense', 'counting_error', 'other'], 'a new business has the built-in reasons');
select public.counter_cash_reasons_seed(pg_temp.u(102), 'change, Pourboires ,expense');
select is((select name from public.counter_cash_reasons where workspace_id = pg_temp.u(102) and code = 'pourboires'), 'Pourboires',
  'an old setting''s own word became a reason named as it was typed');
select is((select count(*)::int from public.counter_cash_reasons where workspace_id = pg_temp.u(102)), 5, 'beside the built-in ones, once each');
select is(pg_temp.run_as(pg_temp.u(2), format('select count(*)::text from public.counter_cash_reasons where workspace_id = %L', pg_temp.u(101))), '4',
  'a member reads the reasons');
select is(pg_temp.run_as(pg_temp.u(1), format('insert into public.counter_cash_reasons (workspace_id, code, name, processes) values (%L, ''x'', ''X'', ''{paid_in}'') returning 1', pg_temp.u(101))),
  'ERR 42501', 'and no one writes the table');

-- writing a reason
select is(pg_temp.save(2, null, 'Tips', '{paid_in}'), 'ERR DKN01', 'a member who does not configure the tills writes no reason');
select is(pg_temp.save(1, null, 'Tips & gifts', '{paid_in}')::jsonb ->> 'code', 'tips_gifts', 'the owner adds one: its code from its name');
select is(pg_temp.save(1, null, 'Tips  gifts', '{paid_in}')::jsonb ->> 'code', 'tips_gifts_2', 'a second of the same code gets its own');
select is(pg_temp.save(1, null, 'tips, gifts', '{paid_in}')::jsonb ->> 'code', 'tips_gifts_3', 'and a third');
select is(pg_temp.save(1, null, '  ', '{paid_in}'), 'ERR DKL13 {"reason": "reason_name"}', 'a reason of the business has a name');
select is(pg_temp.save(1, 'tips_gifts', 'Tips', '{}'), 'ERR DKL13 {"reason": "reason_process"}', 'and serves at least one process');
select is(pg_temp.save(1, 'change', 'Wechselgeld', '{paid_in}')::jsonb ->> 'name', null, 'a built-in reason keeps the app''s words');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.counter_cash_reason_save_v1(%L, null, ''Tips'', ''{paid_in}'', null, null)::text', pg_temp.u(102))),
  'ERR DKN01', 'where cash reasons are off, none is written');

-- what the drawer takes
select is(pg_temp.entry(1, 'paid_out', 'expense'), 'paid_out', 'a paid-out with an active paid-out reason is recorded');
select is(pg_temp.entry(2, 'paid_out', 'change'), 'ERR DKL13 {"reason": "reason_unknown"}', 'a reason no longer for paid-outs is refused');
select ok(pg_temp.save(1, 'tips_gifts', 'Tips & gifts', '{paid_in}', true) like '{%', 'the owner archives a reason');
select is(pg_temp.entry(3, 'paid_in', 'tips_gifts'), 'ERR DKL13 {"reason": "reason_unknown"}', 'an archived reason is refused');
select is(pg_temp.err(format('update public.counter_till_sessions set difference_reason = ''expense'' where id = %L', pg_temp.u(601))),
  'ERR DKL13 {"reason": "reason_unknown"}', 'a count''s difference names a count-difference reason, whatever door writes it');
set session_replication_role = replica;
insert into public.counter_till_sessions (id, workspace_id, company_id, till_id, float_minor, difference_reason)
values (pg_temp.u(602), pg_temp.u(101), pg_temp.u(101), pg_temp.u(402), 0, 'typed before');
set session_replication_role = origin;
select is(pg_temp.err(format('update public.counter_till_sessions set banked_minor = 0 where id = %L', pg_temp.u(602))), 'ok',
  'a reason stored before stays');

select * from finish();
rollback;
