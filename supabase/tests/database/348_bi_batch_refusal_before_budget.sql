-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2578 (0663) — the refusal does not depend on the clock. An analyst
-- without finance rights sends a batch whose capacity figures spend the whole
-- time budget (a stub that sleeps 0.3 s each, budget 500 ms, rolled back with
-- the test) and whose last request is a finance figure. It is refused whole
-- (42501), not answered with the capacity half and the finance figure marked
-- over budget (54000).
begin;
select plan(3);
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002579' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.batch(p_user uuid, p_requests jsonb) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute format('select public.bi_query_batch_v1(%L, %L::jsonb)',
                 current_setting('t.a'), p_requests::text) into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm, 'code', sqlstate);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@biAnalyst.test', '', now(), now(), now()
  from generate_series(1, 2) i;
-- 1 owner of A, 2 a member granted viewAnalytics and nothing else.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Analyst A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"capacityKpi": true, "workspaceStatus": true, "invoicing": true}',
       role_permissions = coalesce(role_permissions, '{}'::jsonb) || '{"member": ["viewAnalytics"]}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer');

create function pg_temp.cap() returns jsonb language sql as $$
  select jsonb_build_object('request_key', 'cap', 'metric_id', 'capacity.seat_utilisation',
    'from', '2026-09-01T00:00:00+02', 'to', '2026-10-01T00:00:00+02');
$$;
create function pg_temp.fin() returns jsonb language sql as $$
  select jsonb_build_object('request_key', 'fin', 'metric_id', 'finance.invoiced',
    'from_month', '2026-09', 'to_month', '2026-09');
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- Slow capacity figures and the minimum budget.
alter function public.kpi_seat_capacity(uuid, timestamptz, timestamptz, uuid) rename to kpi_seat_capacity_real;
create function public.kpi_seat_capacity(p_ws uuid, p_from timestamptz, p_to timestamptz, p_level uuid default null)
returns jsonb language plpgsql as $s$
begin
  perform pg_sleep(0.3);
  return jsonb_build_object('from', p_from);
end
$s$;
create or replace function public.bi_batch_time_budget_ms(p_workspace_id uuid)
returns int language sql as $b$ select 500 $b$;

select set_config('t.slow', pg_temp.batch(pg_temp.u(2),
  jsonb_build_array(pg_temp.cap(), pg_temp.cap(), pg_temp.cap(), pg_temp.cap(), pg_temp.fin()))::text, true);
select set_config('t.fast', pg_temp.batch(pg_temp.u(2), jsonb_build_array(pg_temp.cap()))::text, true);
-- END FIXTURE

select is(current_setting('t.slow')::jsonb ->> 'code', '42501',
  'B1 the finance request is refused whole although the time budget is spent before it');
select ok(current_setting('t.slow')::jsonb -> 'results' is null,
  'B2 the refusal carries no partial results and no over-budget answer');
select is(current_setting('t.fast')::jsonb #>> '{results,0,ok}', 'true',
  'B3 a batch the analyst may read is still answered');

select * from finish();
rollback;
