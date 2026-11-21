-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4168 (0845): Me names the kind of each business the person belongs to: the kind
-- they SET, for the businesses they are an active member of and no other; a business
-- that never chose one has none; a pending member and a stranger read nothing; and a
-- delegated session reads nothing.
begin;
select plan(7);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004168' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'kinds' || n || '@example.test', '', now(), now(), now() from generate_series(1, 4) n;
-- 1 owns A (a freelancer) and is a member of B (no kind chosen); 2 owns C (a studio); 3 is pending in A; 4 is a stranger
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Kinds A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1)),
       (pg_temp.u(102), 'Kinds B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2)),
       (pg_temp.u(103), 'Kinds C', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2));
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(102), pg_temp.u(1), false, false, 'active', '2026-01-01'),
       (pg_temp.u(102), pg_temp.u(2), true, true, 'active', '2026-01-01'),
       (pg_temp.u(103), pg_temp.u(2), true, true, 'active', '2026-01-01'),
       (pg_temp.u(101), pg_temp.u(3), false, false, 'pending', null);
insert into public.setting_values (scope, workspace_id, key, value, note) values
  ('workspace', pg_temp.u(101), 'business.kind', '"freelancer"'::jsonb, ''),
  ('workspace', pg_temp.u(103), 'business.kind', '"studio"'::jsonb, '');

create function pg_temp.kinds(p_user int, p_claims jsonb default '{}'::jsonb) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (json_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::jsonb || p_claims)::text, true);
  execute 'set local role authenticated';
  select coalesce(string_agg(w.name || '=' || k.kind, ',' order by w.name), '-') into v
    from public.my_business_kinds_v1() k join public.workspaces w on w.id = k.workspace_id;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(pg_temp.kinds(1), 'Kinds A=freelancer', 'a member reads the kind their business set, and none for one that chose none');
select is(pg_temp.kinds(2), 'Kinds C=studio', 'an owner reads their own businesses'' kinds only');
select is(pg_temp.kinds(3), '-', 'a pending member reads nothing');
select is(pg_temp.kinds(4), '-', 'a stranger reads nothing');
select is(pg_temp.kinds(1, '{"client_id": "assistant"}'::jsonb), '-', 'a delegated session reads nothing');
-- a changed kind is a new version: only the open one is read
update public.setting_values set valid_to = now() where workspace_id = pg_temp.u(101) and key = 'business.kind';
insert into public.setting_values (scope, workspace_id, key, value, valid_from, note)
values ('workspace', pg_temp.u(101), 'business.kind', '"service"'::jsonb, now(), '');
select is(pg_temp.kinds(1), 'Kinds A=service', 'a changed kind is read once, as it now stands');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'my_business_kinds_v1' and has_function_privilege('anon', p.oid, 'execute')), 0,
  'anon cannot call it');

select * from finish();
rollback;
