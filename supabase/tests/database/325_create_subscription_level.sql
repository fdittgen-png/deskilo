-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3132 (0637, decided in #3012): create_subscription_level adds one level to
-- the workspace's offered subscription levels under the manageBilling right,
-- which the command re-checks itself. A preset percentage is enabled, any other
-- joins the extra levels, both stay sorted, allow_custom is kept; a member
-- without the right, another workspace's manager, nobody signed in, a
-- percentage outside the registry's bounds and a level already offered are
-- refused with their own errcode and change nothing.
begin;
select plan(19);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case when p_user is null then '' else
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text end, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.levels(p_workspace uuid) returns jsonb language sql as $$
  select subscription_levels from public.workspaces where id = p_workspace;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The owner (a1), an admin holding manageBilling through the role list (a2), a
-- plain member (a3), and the manager of another workspace (a4).
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003132' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@subscription-level.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3', 'a4']) s;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, role_permissions) values
 ('00000000-0000-4000-8000-0000003132b1', 'Levels A', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003132a1', '{"admin": ["manageBilling"]}'),
 ('00000000-0000-4000-8000-0000003132b2', 'Levels B', 'FR', 'EUR', 'Europe/Paris',
  '00000000-0000-4000-8000-0000003132a4', '{"admin": ["manageBilling"]}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-0000003132b1', '00000000-0000-4000-8000-0000003132a1', true, true, 'active'),
 ('00000000-0000-4000-8000-0000003132b1', '00000000-0000-4000-8000-0000003132a2', false, true, 'active'),
 ('00000000-0000-4000-8000-0000003132b1', '00000000-0000-4000-8000-0000003132a3', false, false, 'active'),
 ('00000000-0000-4000-8000-0000003132b2', '00000000-0000-4000-8000-0000003132a4', false, true, 'active');
update public.workspaces
   set subscription_levels = '{"enabled_presets": [50, 100], "extra_levels": [], "allow_custom": true}'
 where id = '00000000-0000-4000-8000-0000003132b1';

select ok(not has_function_privilege('anon', 'public.create_subscription_level(uuid,int)', 'execute'),
  'anon cannot execute the command');
select ok(has_function_privilege('authenticated', 'public.create_subscription_level(uuid,int)', 'execute'),
  'a signed-in person can call it, the right is checked inside');

-- ── refusals first: nothing changes ────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000003132a3');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 40)$$,
  '42501', null, 'a member without manageBilling is refused');
select pg_temp.act_as('00000000-0000-4000-8000-0000003132a4');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 40)$$,
  '42501', null, 'another workspace''s billing manager is refused');
select pg_temp.act_as(null);
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 40)$$,
  '42501', null, 'nobody signed in is refused');
select pg_temp.act_as('00000000-0000-4000-8000-0000003132a1');
select throws_ok($$select public.create_subscription_level(null, 40)$$,
  '42501', null, 'no workspace is refused');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132ff', 40)$$,
  '42501', null, 'a workspace that does not exist is refused');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 0)$$,
  '22023', null, 'zero is below the bounds');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 101)$$,
  '22023', null, '101 is above the bounds');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', -5)$$,
  '22023', null, 'a negative percentage is refused');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', null)$$,
  '22023', null, 'no percentage is refused');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 50)$$,
  '23505', null, 'a preset already enabled is refused');
select is(pg_temp.levels('00000000-0000-4000-8000-0000003132b1'),
  '{"enabled_presets": [50, 100], "extra_levels": [], "allow_custom": true}'::jsonb,
  'the refusals changed nothing');

-- ── the happy paths ────────────────────────────────────────────────────
select is(public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 30),
  '{"enabled_presets": [50, 100], "extra_levels": [30], "allow_custom": true}'::jsonb,
  'the owner adds an extra level and gets the offered levels back');
select pg_temp.act_as('00000000-0000-4000-8000-0000003132a2');
select is(public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 25),
  '{"enabled_presets": [25, 50, 100], "extra_levels": [30], "allow_custom": true}'::jsonb,
  'a billing manager enables a preset that was off, sorted');
select is(public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 1),
  '{"enabled_presets": [25, 50, 100], "extra_levels": [1, 30], "allow_custom": true}'::jsonb,
  'the lower bound is a level, sorted among the extras');
select throws_ok($$select public.create_subscription_level('00000000-0000-4000-8000-0000003132b1', 30)$$,
  '23505', null, 'an extra level already offered is refused');
select is(pg_temp.levels('00000000-0000-4000-8000-0000003132b1'),
  '{"enabled_presets": [25, 50, 100], "extra_levels": [1, 30], "allow_custom": true}'::jsonb,
  'the stored document is what the commands returned');
select is(pg_temp.levels('00000000-0000-4000-8000-0000003132b2'),
  '{"enabled_presets": [25, 50, 75, 100], "extra_levels": [], "allow_custom": false}'::jsonb,
  'another workspace keeps the default levels');

select * from finish();
rollback;
