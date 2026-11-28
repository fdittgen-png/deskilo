-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4495 (0985): a scanned code that two places carry is not resolved to the first of them. Two sites each have a SHOP: the code SHOP answers
-- both places (id, code, name, full path site › place) and no single place; a code one place carries still answers that place; the barcode
-- of a place is unique and still answers it; an assistant is given the names and the paths, never the ids; an archived place is not offered.
-- Rolled back.
begin;
select plan(8);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.res(p_code text, p_delegated boolean default false) returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  select public.stock_resolve_code_v1(pg_temp.u(101), p_code) into v;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'scanplace-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Scan places', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code, name, barcode) values
  (pg_temp.u(501), pg_temp.u(101), null, 'site', 'SITE-A', 'Site A', null),
  (pg_temp.u(502), pg_temp.u(101), null, 'site', 'SITE-B', 'Site B', null),
  (pg_temp.u(511), pg_temp.u(101), pg_temp.u(501), 'zone', 'SHOP', 'Shop', '2000000000511'),
  (pg_temp.u(512), pg_temp.u(101), pg_temp.u(502), 'zone', 'SHOP', 'Shop', '2000000000512'),
  (pg_temp.u(513), pg_temp.u(101), pg_temp.u(502), 'zone', 'BACK', 'Back room', null),
  (pg_temp.u(503), pg_temp.u(101), null, 'site', 'SITE-C', 'Site C', null);
insert into public.stock_locations (id, workspace_id, parent_id, kind, code, name, active) values
  (pg_temp.u(514), pg_temp.u(101), pg_temp.u(503), 'zone', 'SHOP', 'Closed shop', false);

select is(jsonb_array_length(pg_temp.res('SHOP') -> 'places'), 2, 'a code two places carry answers both places');
select is(pg_temp.res('SHOP') ? 'place', false, 'and no single place');
select is(pg_temp.res('SHOP') #>> '{places,0,path}', 'SITE-A › SHOP', 'each with its full path, in order');
select is(pg_temp.res('BACK') #>> '{place,name}', 'Back room', 'a code one place carries answers that place, as before');
select is(pg_temp.res('2000000000512') #>> '{place,id}', pg_temp.u(512)::text, 'a barcode names its one place');
select is((pg_temp.res('SHOP', true) #> '{places,0}') ? 'id', false, 'an assistant is told the paths and no identifier');
select is(jsonb_array_length(pg_temp.res('SHOP') -> 'places'), 2, 'an archived place is not offered');
update public.stock_locations set active = false where id = pg_temp.u(511);
select is(pg_temp.res('SHOP') #>> '{place,id}', pg_temp.u(512)::text, 'once only one is in use the code answers it');

select * from finish();
rollback;
