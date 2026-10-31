-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0620 (#2578 BI B1) — a report read is bounded in time: the figures a
-- batch has not reached within bi.batch_time_budget_ms are answered as over
-- budget (54000), each named; the computed ones stand. A figure is made
-- slow on purpose (a stub that sleeps 0.3 s, rolled back with the test) and
-- the budget is its minimum, 500 ms.
begin;
select plan(5);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000002578';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'bi-budget@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('BI budget', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true);
  perform set_config('t.ws', ws::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, true);
end;
$seed$;

select pg_temp.seed();

select is(public.bi_batch_time_budget_ms(current_setting('t.ws')::uuid), 4000,
  'the registry default is 4000 ms');

-- A slow figure and the minimum budget.
alter function public.kpi_finance_summary(uuid, text, text) rename to kpi_finance_summary_real;
create function public.kpi_finance_summary(p_ws uuid, p_from text, p_to text) returns jsonb
language plpgsql as $s$
begin
  perform pg_sleep(0.3);
  return jsonb_build_object('from_month', p_from);
end
$s$;
create or replace function public.bi_batch_time_budget_ms(p_workspace_id uuid)
returns int language sql as $b$ select 500 $b$;

select set_config('t.res', public.bi_query_batch_v1(current_setting('t.ws')::uuid,
  (select jsonb_agg(jsonb_build_object('request_key', i::text, 'metric_id', 'finance.invoiced',
                                       'from_month', '2026-0' || i, 'to_month', '2026-0' || i))
     from generate_series(1, 6) i))::text, true);

select is((select count(*)::int from jsonb_array_elements(current_setting('t.res')::jsonb -> 'results')), 6,
  'every request is answered');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.res')::jsonb -> 'results') e
            where (e ->> 'ok')::boolean), 2,
  'the figures computed within the budget stand');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.res')::jsonb -> 'results') e
            where e ->> 'code' = '54000'), 4,
  'the rest are answered as over budget, not dropped');
select is((select string_agg(e ->> 'request_key', ',' order by (e ->> 'request_key'))
             from jsonb_array_elements(current_setting('t.res')::jsonb -> 'results') e
            where e ->> 'code' = '54000'), '3,4,5,6',
  'each over-budget answer names its request');

select * from finish();
rollback;
