-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2578 — an analyst without finance rights. viewAnalytics alone reads
-- the capacity figures; a batch that also asks a finance figure is refused
-- whole (the reader's own refusal, 42501), never answered with the
-- capacity half and a quiet gap; no answer to that member carries a
-- finance amount. Real roles, readbacks.
begin;
select plan(5);
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

select set_config('t.cap', pg_temp.batch(pg_temp.u(2), jsonb_build_array(pg_temp.cap()))::text, true);
select set_config('t.mixed', pg_temp.batch(pg_temp.u(2), jsonb_build_array(pg_temp.cap(), pg_temp.fin()))::text, true);

select is(current_setting('t.cap')::jsonb #>> '{results,0,ok}', 'true',
  'A1 the analyst reads the capacity figure');
select is(current_setting('t.mixed')::jsonb ->> 'code', '42501',
  'A2 a batch that also asks a finance figure is refused whole');
select ok(current_setting('t.mixed')::jsonb -> 'results' is null,
  'A3 the refusal carries no partial results');
select ok(position('_minor' in current_setting('t.cap')) = 0
          and position('_minor' in current_setting('t.mixed')) = 0,
  'A4 no answer to the analyst names a finance amount');
select is(pg_temp.batch(pg_temp.u(1), jsonb_build_array(pg_temp.cap(), pg_temp.fin())) #>> '{results,1,ok}', 'true',
  'A5 the owner reads both');

select * from finish();
rollback;
