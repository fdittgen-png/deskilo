-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2863: the supplier lookup's registry wait and per-person quota are
-- platform settings the edge function reads with the caller's own token.
-- Their registry rows, what a member resolves (default, stored platform
-- value, clamped value, a workspace row ignored for a platform-only key),
-- and the refusal of a stranger. Real roles, readbacks.
begin;
select plan(8);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.read_as(p_user uuid, p_key text) returns text
language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(p_user);
  v := public.setting_value(current_setting('t.a')::uuid, p_key) #>> '{}';
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002863' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@supplierLookup.test', '', now(), now(), now()
  from generate_series(1, 2) i;
-- 1 owner of A, 2 a stranger to A.

-- Seeds are direct inserts as postgres: no session is needed to create
-- the workspace, and only the reads below run as `authenticated`.
select set_config('t.a', '00000000-0000-4000-8000-0000286a0001', true);
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment)
values (current_setting('t.a')::uuid, 'Lookup A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
values (current_setting('t.a')::uuid, pg_temp.u(1), true, true, 'active');

select is(
  (select jsonb_build_array(type, default_value, min_value, max_value, scopes, editable)
     from public.setting_definitions where key = 'purchase.supplier_lookup_timeout_seconds'),
  '["duration", 15, 3, 30, ["platform"], true]'::jsonb,
  'L1 the registry wait is a platform duration, 3..30 s, default 15');
select is(
  (select jsonb_build_array(type, default_value, min_value, max_value, scopes, editable)
     from public.setting_definitions where key = 'purchase.supplier_lookup_per_minute'),
  '["int", 20, 1, 120, ["platform"], true]'::jsonb,
  'L2 the quota is a platform count, 1..120, default 20');

-- Nothing stored for either key yet, whatever the dev data holds.
delete from public.setting_values
 where key in ('purchase.supplier_lookup_timeout_seconds', 'purchase.supplier_lookup_per_minute');

select is(pg_temp.read_as(pg_temp.u(1), 'purchase.supplier_lookup_timeout_seconds'), '15',
  'L3 a member resolves the default wait');
select is(pg_temp.read_as(pg_temp.u(1), 'purchase.supplier_lookup_per_minute'), '20',
  'L4 a member resolves the default quota');

insert into public.setting_values (scope, workspace_id, key, value, note)
values ('platform', null, 'purchase.supplier_lookup_timeout_seconds', '25'::jsonb, 'slow registry');
select is(pg_temp.read_as(pg_temp.u(1), 'purchase.supplier_lookup_timeout_seconds'), '25',
  'L5 the platform value is what the function reads');

insert into public.setting_values (scope, workspace_id, key, value, note)
values ('platform', null, 'purchase.supplier_lookup_per_minute', '500'::jsonb, 'out of bounds');
select is(pg_temp.read_as(pg_temp.u(1), 'purchase.supplier_lookup_per_minute'), '120',
  'L6 a stored value over the bound is held at 120');

insert into public.setting_values (scope, workspace_id, key, value, note)
values ('workspace', current_setting('t.a')::uuid, 'purchase.supplier_lookup_timeout_seconds', '3'::jsonb, 'not this scope');
select is(pg_temp.read_as(pg_temp.u(1), 'purchase.supplier_lookup_timeout_seconds'), '25',
  'L7 a workspace row never overrides a platform-only key');

select ok(pg_temp.read_as(pg_temp.u(2), 'purchase.supplier_lookup_timeout_seconds') like 'ERROR: %not a member%',
  'L8 a stranger to the workspace is refused');

select * from finish();
rollback;
