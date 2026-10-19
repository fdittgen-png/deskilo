-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2578 / 0505 (C1): one read for many figures. A batch is answered by the
-- existing KPI functions on the snapshot of one call; a request that fails
-- on its own does not blank the others; the reader's own refusal refuses the
-- batch. Real roles, readbacks.
begin;
select plan(14);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
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
create function pg_temp.owner_err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002578' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@biBatch.test', '', now(), now(), now()
  from generate_series(1, 3) i;
-- 1 owner of A, 2 plain member of A, 3 owner of B.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Batch A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(3));
select set_config('t.b', public.create_workspace('Batch B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"capacityKpi": true, "workspaceStatus": true, "invoicing": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer');

create function pg_temp.batch(p_user uuid, p_requests jsonb) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.bi_query_batch_v1(%L, %L::jsonb)', current_setting('t.a'), p_requests::text));
end;
$$;
create function pg_temp.cap(p_key text, p_from text, p_to text) returns jsonb language sql as $$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'capacity.seat_utilisation', 'from', p_from, 'to', p_to);
$$;

select ok((pg_temp.batch(pg_temp.u(2), jsonb_build_array(pg_temp.cap('a', '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')))::text) like '%not allowed%',
  'B1 a plain member refuses the whole batch');
select ok((pg_temp.as_json(pg_temp.u(3), format('select public.bi_query_batch_v1(%L, ''[]'')', current_setting('t.a')))::text) like '%between 1 and 60%',
  'B2 an empty batch is refused');
select ok((pg_temp.batch(pg_temp.u(3), jsonb_build_array(pg_temp.cap('a', '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')))::text) like '%not allowed%',
  'B3 a foreign owner is refused');
select ok((pg_temp.batch(pg_temp.u(1), (select jsonb_agg(pg_temp.cap('k' || g, '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')) from generate_series(1, 61) g))::text) like '%between 1 and 60%',
  'B4 61 requests are refused');

select set_config('t.r', pg_temp.batch(pg_temp.u(1), jsonb_build_array(
  pg_temp.cap('sep', '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02'),
  pg_temp.cap('bad', '2026-10-01T00:00:00+02', '2026-09-01T00:00:00+02'),
  jsonb_build_object('request_key', 'nope', 'metric_id', 'finance.unknown'),
  jsonb_build_object('request_key', 'lvl', 'metric_id', 'capacity.seat_utilisation', 'from', '2026-09-01T00:00:00+02',
                     'to', '2026-10-01T00:00:00+02', 'level_id', '00000000-0000-4000-8000-000000000000'),
  jsonb_build_object('request_key', 'fin', 'metric_id', 'finance.invoiced', 'from_month', '2026-08', 'to_month', '2026-09')))::text, true);
select is(jsonb_array_length(current_setting('t.r')::jsonb -> 'results'), 5, 'B5 one answer per request, in order');
select is((select string_agg((x ->> 'request_key') || ':' || (x ->> 'ok'), ',' order by ord)
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'results') with ordinality t(x, ord)),
  'sep:true,bad:false,nope:false,lvl:false,fin:true', 'B6 the good ones answer, the others fail on their own');
select is((current_setting('t.r')::jsonb -> 'results' -> 1) ->> 'code', '22023', 'B7 a backwards period is a 22023 of that request');
select is((current_setting('t.r')::jsonb -> 'results' -> 2) ->> 'code', '0A000', 'B8 an unsupported metric is a 0A000 of that request');
select is((current_setting('t.r')::jsonb -> 'results' -> 3) ->> 'code', '22023', 'B9 an unknown level is a 22023 of that request');
select is((current_setting('t.r')::jsonb -> 'results' -> 0 -> 'result') - 'computed_at',
  (select public.kpi_seat_capacity(current_setting('t.a')::uuid, timestamptz '2026-09-01T00:00:00+02', timestamptz '2026-10-01T00:00:00+02', null) - 'computed_at'),
  'B10 the batch answer is the existing KPI function''s, unchanged');
select is((current_setting('t.r')::jsonb -> 'results' -> 4 -> 'result') - 'computed_at',
  (select public.kpi_finance_summary(current_setting('t.a')::uuid, '2026-08', '2026-09') - 'computed_at'),
  'B11 and so is the finance one');
select is((current_setting('t.r')::jsonb -> 'results' -> 0) ->> 'metric_version', '1', 'B12 each answer names its metric version');
select ok(current_setting('t.r')::jsonb ? 'computed_at', 'B13 the batch names when it was computed');
select is((select count(*)::int from public.reservations where workspace_id = current_setting('t.a')::uuid), 0, 'B14 readback: a read changes nothing');

select * from finish();
rollback;
