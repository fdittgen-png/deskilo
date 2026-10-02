-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1827 B (0339) — the installation's assistant switches answer the
-- instance operator only, and every change needs the second factor.
-- A member who is not the operator is refused the overview; the operator
-- reads it; a change at aal1 is refused before anything is touched; at
-- aal2 the change reaches the same internal rules the CLI uses (a target
-- without an identity binding is still refused by them).
begin;
select plan(6);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  op uuid := '00000000-0000-4000-8000-000000000a41';
  other uuid := '00000000-0000-4000-8000-000000000a42';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (op, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'operator-341@deskilo.test', '', now(), now(), now()),
         (other, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'other-341@deskilo.test', '', now(), now(), now());
  insert into public.platform_admins (user_id) values (op);
  perform set_config('deskilo.op', op::text, false);
  perform set_config('deskilo.other', other::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as(p_user text, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', current_setting('deskilo.' || p_user), 'role', 'authenticated',
    'aal', p_aal)::text, false);
$$;

select pg_temp.as('other', 'aal2');
select throws_like($$ select public.instance_mcp_overview() $$,
  '%only the instance operator%',
  'someone who is not the instance operator is refused the overview');

select pg_temp.as('op', 'aal1');
select ok(public.instance_mcp_overview() ?& array['enabled', 'blockers', 'administrators', 'candidates', 'clients'],
  'the operator reads the installation overview');
select is(public.instance_mcp_overview()->>'second_factor', 'false',
  'and is told the session has no second factor');
select throws_like(
  format($$ select public.instance_grant_database_admin(%L) $$, current_setting('deskilo.other')),
  '%second factor%',
  'a change at aal1 is refused before anything is touched');
select throws_like($$ select public.instance_set_mcp_runtime(true) $$,
  '%second factor%',
  'so is the runtime switch');

select pg_temp.as('op', 'aal2');
select throws_like(
  format($$ select public.instance_grant_database_admin(%L) $$, current_setting('deskilo.other')),
  '%no verified identity binding%',
  'at aal2 the change reaches the same rules as the CLI');

select * from finish();
rollback;
