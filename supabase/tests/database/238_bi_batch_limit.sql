-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2578 / 0508: the most figures one batched read may carry is the space's
-- setting (default 60, what 0505 hard-coded). Real roles, readbacks.
begin;
select plan(7);
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
  select ('00000000-0000-4000-8000-00002579' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@biLimit.test', '', now(), now(), now()
  from generate_series(1, 3) i;
-- 1 owner of A, 2 plain member of A, 3 owner of B.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Batch A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(3));
select set_config('t.b', public.create_workspace('Batch B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"capacityKpi": true, "workspaceStatus": true, "invoicing": true, "configurableSettings": true}'
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

select ok((pg_temp.batch(pg_temp.u(1), (select jsonb_agg(pg_temp.cap('k' || g, '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')) from generate_series(1, 61) g))::text) like '%between 1 and 60 requests%',
  'S1 by default 61 requests are refused, naming 60');
select pg_temp.act_as(pg_temp.u(1));
select is(public.set_setting(current_setting('t.a')::uuid, 'bi.batch_max_requests', '10'::jsonb, 'smaller reads')->>'status', 'saved',
  'S2 the space lowers the limit');
select ok((pg_temp.batch(pg_temp.u(1), (select jsonb_agg(pg_temp.cap('k' || g, '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')) from generate_series(1, 11) g))::text) like '%between 1 and 10 requests%',
  'S3 11 requests are now refused, naming the space''s limit');
select is(jsonb_array_length(pg_temp.batch(pg_temp.u(1), (select jsonb_agg(pg_temp.cap('k' || g, '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')) from generate_series(1, 10) g)) -> 'results'), 10,
  'S4 exactly 10 requests are answered, one each');
select throws_ok(format('select public.set_setting(%L, ''bi.batch_max_requests'', ''9''::jsonb, ''too small'')', current_setting('t.a')),
  null, null, 'S5 below the registry floor of 10 is refused');
select is(public.setting_value(current_setting('t.a')::uuid, 'bi.batch_max_requests') #>> '{}', '10',
  'S6 readback: the refused value changed nothing');
select ok((pg_temp.batch(pg_temp.u(3), (select jsonb_agg(pg_temp.cap('k' || g, '2026-09-01T00:00:00+02', '2026-10-01T00:00:00+02')) from generate_series(1, 61) g))::text) like '%between 1 and 60 requests%',
  'S7 a stranger is told the default limit (60), not the space''s own setting (10)');

select * from finish();
rollback;
