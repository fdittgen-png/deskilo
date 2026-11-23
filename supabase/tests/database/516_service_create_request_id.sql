-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4376 (0888): creating a service is safe to retry. One request id creates the service once; the same id with the
-- same content answers the first service; the same id with other content is refused in words and creates nothing;
-- another business neither replays nor reads it; a member without manageServices, an assistant and a caller with no
-- session are refused; an unknown field and an empty name are refused. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.create_as(p_user int, p_req int, p_service text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(case when p_user = 0 then null else pg_temp.u(p_user) end,
    format('select public.create_service_v1(%L, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_req), p_service), p_delegated)
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'svc-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Catalogue A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true}', '{}'),
  (pg_temp.u(102), 'Catalogue B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"services": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');

select is(pg_temp.f(pg_temp.create_as(1, 701, '{"name": "Coaching hour", "price_cents": 6000, "category": "coaching"}'), 'name'), 'Coaching hour', 'the owner creates a service');
select is((select count(*)::int from public.services where workspace_id = pg_temp.u(101)), 1, 'one service exists');
select is(pg_temp.f(pg_temp.create_as(1, 701, '{"name": "Coaching hour", "price_cents": 6000, "category": "coaching"}'), 'id'),
          (select id::text from public.services where workspace_id = pg_temp.u(101)), 'the same request id and content answer the first service');
select is((select count(*)::int from public.services where workspace_id = pg_temp.u(101)), 1, 'and create no second one');
select is(pg_temp.create_as(1, 701, '{"name": "Coaching hour", "price_cents": 6500}'), 'ERR P0001', 'the same id with other content is refused');
select is((select count(*)::int from public.services where workspace_id = pg_temp.u(101)), 1, 'and creates nothing');
select is(pg_temp.create_as(4, 702, '{"name": "Intruder"}', 101), 'ERR DKN01', 'another business creates nothing here');
select is(pg_temp.f(pg_temp.create_as(4, 701, '{"name": "Coaching hour", "price_cents": 6000, "category": "coaching"}', 102), 'id') is distinct from
          (select id::text from public.services where workspace_id = pg_temp.u(101)), true, 'and the same id in its own business is its own service, not the first one');
select is(pg_temp.create_as(2, 703, '{"name": "Plain member"}'), 'ERR DKN01', 'a member without manageServices is refused');
select is(pg_temp.create_as(1, 704, '{"name": "Assistant"}', 101, true), 'ERR DKN01', 'an assistant is refused');
select is(pg_temp.create_as(0, 705, '{"name": "No session"}'), 'ERR DKN01', 'a caller with no session is refused');
select is(pg_temp.create_as(1, 706, '{"name": "Odd", "colour": "red"}'), 'ERR 22023', 'an unknown field is refused');
select is(pg_temp.create_as(1, 707, '{"name": "   "}'), 'ERR 22023', 'an empty name is refused');

-- ── a service's VAT rate belongs to its business ──
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values
  (pg_temp.u(801), pg_temp.u(101), 'Own 20', 20, 'S', false, 'standard'),
  (pg_temp.u(802), pg_temp.u(102), 'Other 20', 20, 'S', false, 'standard');
select is(pg_temp.f(pg_temp.create_as(1, 708, format('{"name": "With own rate", "vat_rate_id": "%s"}', pg_temp.u(801))), 'vat_rate_id'), pg_temp.u(801)::text, 'a rate of the business is taken');
select is(left(pg_temp.create_as(1, 709, format('{"name": "With a foreign rate", "vat_rate_id": "%s"}', pg_temp.u(802))), 9), 'ERR DKG11', 'a rate of another business is refused by the command');
select is((select count(*)::int from public.services where workspace_id = pg_temp.u(101) and name = 'With a foreign rate'), 0, 'and no service is made');
create or replace function pg_temp.sqlstate_of(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'none'; exception when others then return sqlstate; end
$f$;
select is(pg_temp.sqlstate_of(format('insert into public.services (workspace_id, name, price_cents, vat_rate_id) values (%L, %L, 100, %L)', pg_temp.u(101), 'Direct foreign rate', pg_temp.u(802))),
  '23503', 'and so is a direct insert naming it');

select * from finish();
rollback;
