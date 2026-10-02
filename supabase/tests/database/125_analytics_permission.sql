-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1921 — who may read the capacity figures: viewAnalytics, from the KPI
-- registry, and nothing broader or narrower. Positive cases beside every
-- refusal.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-00000019210a';
  u_a uuid := '00000000-0000-4000-8000-00000019210b';
  u_m uuid := '00000000-0000-4000-8000-00000019210c';
  u_p uuid := '00000000-0000-4000-8000-00000019210d';
  u_x uuid := '00000000-0000-4000-8000-00000019210e';
  ws uuid; ws2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'analytics-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_m, u_p, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Analytics', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x) returning id into ws2;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"capacityKpi": true}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, true), (ws, u_m, false, false),
         (ws2, u_x, true, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
  values (ws, u_p, false, false, 'paused');
  perform set_config('an.ws', ws::text, false);
  perform set_config('an.owner', u_o::text, false);
  perform set_config('an.admin', u_a::text, false);
  perform set_config('an.member', u_m::text, false);
  perform set_config('an.paused', u_p::text, false);
  perform set_config('an.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('an.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.reads(p_who text) returns boolean
language plpgsql as $r$
begin
  perform pg_temp.act_as(p_who);
  perform public.kpi_seat_capacity(current_setting('an.ws')::uuid,
                                   now() + interval '7 days', now() + interval '8 days');
  return true;
exception when insufficient_privilege then
  return false;
end
$r$;

select pg_temp.seed();

-- ------------------------------------------------- the defaults
select ok(pg_temp.reads('owner'), 'the owner reads the figures');
select ok(pg_temp.reads('admin'), 'an admin reads them by default: viewAnalytics is an admin default');
select ok(not pg_temp.reads('member'), 'a plain member does not');
select ok(not pg_temp.reads('stranger'), 'an owner of another workspace does not');

-- ------------------------------------- a write right is not a read right
update public.workspaces
   set role_permissions = coalesce(role_permissions, '{}'::jsonb)
     || '{"admin": ["manageReservations"], "member": ["exportData"]}'
 where id = current_setting('an.ws')::uuid;
select ok(not pg_temp.reads('admin'),
  'an admin row without viewAnalytics is refused, manageReservations or not');
select ok(not pg_temp.reads('member'), 'exportData alone reads nothing');

-- ------------------------------------------- an explicit grant reads
update public.workspaces
   set role_permissions = role_permissions || '{"member": ["viewAnalytics"]}'
 where id = current_setting('an.ws')::uuid;
select ok(pg_temp.reads('member'),
  'a member granted viewAnalytics reads, with no finance or personal right');
select ok(not pg_temp.reads('paused'), 'a paused member with the same grant does not');

-- ---------------------------------------------------- the registry
select pg_temp.act_as('member');
select ok(not public.kpi_readable(current_setting('an.ws')::uuid, 'finance.revenue'),
  'an unknown KPI is unreadable');
select is(public.kpi_registry() -> 'capacity.seat_utilisation' -> 'permissions',
  '["viewAnalytics"]'::jsonb, 'the registry names the right the read needs');
select ok('viewAnalytics' = any (public.role_permission_catalog()),
  'the roles matrix can grant it');

update public.workspaces set feature_flags = feature_flags || '{"capacityKpi": false}'
 where id = current_setting('an.ws')::uuid;
select ok(not pg_temp.reads('owner'), 'the switch off refuses even the owner');

select * from finish();
rollback;
