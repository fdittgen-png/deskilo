-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2576 / 0507: the most rows a batch of valuations may carry is the space's
-- setting (default 2000, what 0500 hard-coded). Real roles; every refusal is
-- followed by a readback.
begin;
select plan(6);
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
  select ('00000000-0000-4000-8000-00002577' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.mem(n int, w text) returns uuid language sql as $$
  select id from public.members
   where user_id = pg_temp.u(n) and workspace_id = current_setting(w)::uuid;
$$;
create function pg_temp.ev(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002577e' || lpad(n::text, 3, '0'))::uuid;
$$;


insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@valuationlimit.test', '', now(), now(), now()
  from generate_series(1, 2) i;
-- 1 owner of A, 2 plain member of A.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Limit A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb)
       || '{"purchases": true, "supplyExpenses": true, "assetRegister": true, "configurableSettings": true}'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity)
values (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer');

create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.hash(p text) returns text language sql as $$ select md5(p) || md5(p || 'x'); $$;
create function pg_temp.meta(p_hash text) returns jsonb language sql as $$
  select jsonb_build_object('basis', 'book', 'source_system', 'Cabinet Martin', 'source_reference', 'FY2026',
    'source_hash', pg_temp.hash(p_hash), 'period_from', date '2026-01-01', 'period_to', date '2026-12-31',
    'currency', 'EUR', 'movements', 'period', 'complete_scope', false);
$$;
create function pg_temp.rows(n int) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('asset_number', i, 'external_reference', 'X' || i)) from generate_series(1, n) i;
$$;
create function pg_temp.stage(p_user uuid, p_hash text, p_rows jsonb, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.stage_asset_valuations_v1(%L, %L, %L::jsonb, %L::jsonb)',
    current_setting('t.a'), pg_temp.rq(p_req), pg_temp.meta(p_hash)::text, p_rows::text));
end;
$$;

-- A hundred registered assets; the purchase lines behind them are not what is
-- tested, so their foreign key is not checked for these synthetic rows.
reset role;
set local session_replication_role = replica;
insert into public.workspace_assets (workspace_id, company_id, asset_number, description, purchase_line_id, currency)
select current_setting('t.a')::uuid, current_setting('t.a')::uuid, i, 'Asset ' || i, gen_random_uuid(), 'EUR' from generate_series(1, 100) i;
set local session_replication_role = origin;

select ok((pg_temp.stage(pg_temp.u(1), 'l1', pg_temp.rows(2001), 1)::text) like '%between 1 and 2000 rows%',
  'L1 by default 2001 rows are refused, naming the limit');
select pg_temp.act_as(pg_temp.u(1));
select is(public.set_setting(current_setting('t.a')::uuid, 'assets.valuation_max_rows', '100'::jsonb, 'smaller files')->>'status', 'saved',
  'L2 the space lowers the limit');
select ok((pg_temp.stage(pg_temp.u(1), 'l2', pg_temp.rows(101), 2)::text) like '%between 1 and 100 rows%',
  'L3 101 rows are now refused, naming the space''s limit');
select is((pg_temp.stage(pg_temp.u(1), 'l3', pg_temp.rows(100), 3) ->> 'rows')::int, 100,
  'L4 exactly 100 rows are staged');
select throws_ok(format('select public.set_setting(%L, ''assets.valuation_max_rows'', ''99''::jsonb, ''too small'')', current_setting('t.a')),
  null, null, 'L5 below the registry floor of 100 is refused');
select is((select count(*)::int from public.asset_valuation_rows r join public.asset_valuation_batches b on b.id = r.batch_id
            where b.workspace_id = current_setting('t.a')::uuid), 100,
  'L6 readback: only the batch of 100 rows exists, nothing was cut or half-staged');

select * from finish();
rollback;
