-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2569 / 0482 (C2a): the year-end settlement of a lease's service charges.
-- Real roles; every refusal is followed by a readback. Expected values are
-- written by hand: advances 200.00 a month from 1 January 2025.
--   2025 billed 2 700.00 against 12 x 200.00 = 2 400.00: 300.00 is owed,
--        as ONE occurrence due 1 February 2026, listed as an "other" term
--   first half of 2026 billed 1 000.00 against 6 x 200.00: a credit of 200.00,
--        recorded, no occurrence
begin;
select plan(16);

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
  select ('00000000-0000-4000-8000-00002573' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.settle(p_user uuid, p_rev int, p_from date, p_to date, p_actual bigint, p_due date, p_req int) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.settle_lease_charges_v1(%L, %L, %s, %L, %L, %s, %L, %L)',
    current_setting('t.a'), current_setting('t.id'), p_rev, p_from, p_to, p_actual, p_due, pg_temp.rq(p_req)));
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@settle.test', '', now(), now(), now()
  from generate_series(1, 2) i;
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Settle A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb)
  || '{"supplyExpenses": true, "scheduledExpenses": true, "premisesLease": true}' where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at)
values (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name, status)
values ('00000000-0000-4000-8000-0000257300a1', current_setting('t.a')::uuid, '1', 'SCI Les Halles', 'active');

select set_config('t.id', (pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_premises_lease_v1(%L, null, 0, %L::jsonb, %L)', current_setting('t.a'),
  '{"supplier_id":"00000000-0000-4000-8000-0000257300a1","premises":"12 rue des Halles","starts_on":"2025-01-01","notice_months":3}',
  pg_temp.rq(1))) ->> 'id'), true);
select pg_temp.as_json(pg_temp.u(1), format(
  'select public.add_lease_term_v1(%L, %L, 1, ''service_charge_advance'', '''', 20000, 1, ''2025-01-01'', %L)',
  current_setting('t.a'), current_setting('t.id'), pg_temp.rq(2)));
select pg_temp.act_as(pg_temp.u(1));
select public.sweep_expense_schedules(current_setting('t.a')::uuid);
reset role;

select ok((pg_temp.settle(pg_temp.u(2), 2, '2025-01-01', '2025-12-31', 270000, '2026-02-01', 3)::text) like '%may not manage the lease%',
  'a plain member settles nothing');
select ok((pg_temp.settle(pg_temp.u(1), 2, '2025-01-01', '2099-12-31', 270000, '2099-12-31', 4)::text) like '%at most 400 days%',
  'a period longer than 400 days is refused');
select ok((pg_temp.settle(pg_temp.u(1), 2, '2026-01-01', '2099-01-01', 1, '2099-02-01', 5)::text) like '%at most 400 days%'
       or (pg_temp.settle(pg_temp.u(1), 2, '2026-10-01', '2099-01-01', 1, '2099-02-01', 5)::text) like '%once it is over%',
  'a period still running is refused');
select ok((pg_temp.settle(pg_temp.u(1), 2, '2025-01-01', '2025-12-31', 270000, '2025-06-01', 6)::text) like '%due on or after%',
  'the due day is not before the end of the period');
select is((select count(*)::int from public.lease_settlements), 0, 'readback: no refusal left a settlement');

select set_config('t.s1', pg_temp.settle(pg_temp.u(1), 2, '2025-01-01', '2025-12-31', 270000, '2026-02-01', 7)::text, true);
select is(current_setting('t.s1')::jsonb -> 'settlements' -> 0 ->> 'advances_cents', '240000', 'golden: twelve advances of 200.00 are 2 400.00');
select is(current_setting('t.s1')::jsonb -> 'settlements' -> 0 ->> 'balance_cents', '30000', 'and 2 700.00 billed leaves 300.00 owed');
select is(pg_temp.settle(pg_temp.u(1), 2, '2025-01-01', '2025-12-31', 270000, '2026-02-01', 7), current_setting('t.s1')::jsonb,
  'the same request answers the original');
select is((select count(*)::int from public.lease_settlements), 1, 'and files no second settlement');
select ok((pg_temp.settle(pg_temp.u(1), 3, '2025-06-01', '2025-07-31', 1, '2025-08-01', 8)::text) like '%already settled%',
  'a period that overlaps a settled one is refused');

select pg_temp.act_as(pg_temp.u(1));
select public.sweep_expense_schedules(current_setting('t.a')::uuid);
reset role;
select is((select string_agg(o.due_on::text || ':' || o.amount_cents::text, ',')
             from public.expense_occurrences o join public.lease_terms t on t.schedule_id = o.schedule_id
            where t.kind = 'other'), '2026-02-01:30000', 'the 300.00 is ONE occurrence, due on the day asked');
select is((select origin from public.expense_schedules s join public.lease_terms t on t.schedule_id = s.id where t.kind = 'other'),
  'workspace_contract', 'it is an expected obligation of the space, never a member outlay');

select set_config('t.s2', pg_temp.settle(pg_temp.u(1), 3, '2026-01-01', '2026-06-30', 100000, '2026-07-31', 9)::text, true);
select is(current_setting('t.s2')::jsonb -> 'settlements' -> 1 ->> 'credit_cents', '20000', 'less billed than advanced: a credit of 200.00');
select is((select count(*)::int from public.lease_terms where kind = 'other'), 1, 'and no occurrence for a credit');

select throws_ok('update public.lease_settlements set actual_cents = 1', null, null, 'a settlement is never edited');
select throws_ok('delete from public.lease_settlements', null, null, 'nor deleted');

select * from finish();
rollback;
