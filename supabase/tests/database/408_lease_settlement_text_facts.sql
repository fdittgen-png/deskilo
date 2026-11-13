-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3813 (0744, part of #3657): a lease settlement's pre-filled texts are
-- facts, not English. The settlement writes its period on the lease term and
-- its supplier on the expense schedule as facts, beside the English text
-- kept as the fallback; the lease the app reads carries the term's facts; an
-- owner's edit of the schedule's title drops its facts, any other edit keeps
-- them; malformed facts are refused. The fixture is 225's. Rolled back.
begin;
select plan(7);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
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
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003813' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0003813-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.settle(p_user uuid, p_rev int, p_from date, p_to date, p_actual bigint, p_due date, p_req int) returns jsonb
language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.settle_lease_charges_v1(%L, %L, %s, %L, %L, %s, %L, %L)',
    current_setting('t.a'), current_setting('t.id'), p_rev, p_from, p_to, p_actual, p_due, pg_temp.rq(p_req)));
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@settle-facts.test', '', now(), now(), now()
  from generate_series(1, 2) i;
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Settle facts', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb)
  || '{"supplyExpenses": true, "scheduledExpenses": true, "premisesLease": true}' where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at)
values (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name, status)
values ('00000000-0000-4000-8000-0000381300a1', current_setting('t.a')::uuid, '1', 'SCI Les Halles', 'active');

select set_config('t.id', (pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_premises_lease_v1(%L, null, 0, %L::jsonb, %L)', current_setting('t.a'),
  '{"supplier_id":"00000000-0000-4000-8000-0000381300a1","premises":"12 rue des Halles","starts_on":"2025-01-01","notice_months":3}',
  pg_temp.rq(1))) ->> 'id'), true);
select pg_temp.as_json(pg_temp.u(1), format(
  'select public.add_lease_term_v1(%L, %L, 1, ''service_charge_advance'', '''', 20000, 1, ''2025-01-01'', %L)',
  current_setting('t.a'), current_setting('t.id'), pg_temp.rq(2)));
select pg_temp.act_as(pg_temp.u(1));
select public.sweep_expense_schedules(current_setting('t.a')::uuid);
reset role;


select set_config('t.settled', pg_temp.settle(pg_temp.u(1), 2, '2025-01-01', '2025-12-31', 270000, '2026-02-01', 3)::text, true);
select set_config('t.term', (select id::text from public.lease_terms
                              where lease_id = current_setting('t.id')::uuid and kind = 'other'), true);
select set_config('t.schedule', (select schedule_id::text from public.lease_terms
                                  where id = current_setting('t.term')::uuid), true);

select is((select text_facts from public.lease_terms where id = current_setting('t.term')::uuid),
  '{"kind": "settlement_period", "version": 1, "values": {"from": "2025-01-01", "to": "2025-12-31"}}'::jsonb,
  'the term states its period as facts');
select is((select label from public.lease_terms where id = current_setting('t.term')::uuid),
  'Settlement 2025-01-01 to 2025-12-31', 'and keeps its text as the fallback');
select is((select text_facts from public.expense_schedules where id = current_setting('t.schedule')::uuid),
  '{"kind": "service_charge_settlement", "version": 1, "values": {"supplier": "SCI Les Halles"}}'::jsonb,
  'the schedule states its supplier as facts');
select is((select t -> 'text' from jsonb_array_elements(
             pg_temp.as_json(pg_temp.u(1), format('select public.premises_leases_v1(%L)', current_setting('t.a'))) -> 'leases' -> 0 -> 'terms') t
            where t ->> 'id' = current_setting('t.term')),
  (select text_facts from public.lease_terms where id = current_setting('t.term')::uuid),
  'the lease the app reads carries the term''s facts');

update public.expense_schedules set amount_cents = amount_cents where id = current_setting('t.schedule')::uuid;
select ok((select text_facts is not null from public.expense_schedules where id = current_setting('t.schedule')::uuid),
  'an edit that leaves the title keeps the facts');
update public.expense_schedules set title = 'Charges 2025, Halles' where id = current_setting('t.schedule')::uuid;
select ok((select text_facts is null from public.expense_schedules where id = current_setting('t.schedule')::uuid),
  'an owner''s title is their own text: the facts go');

select throws_ok(format($$update public.expense_schedules set text_facts = '{"kind": 1}' where id = %L$$,
                        current_setting('t.schedule')),
  '23514', null, 'facts without a kind, a version and values are refused');

select * from finish();
rollback;
