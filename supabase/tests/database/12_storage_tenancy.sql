-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0215 — #1316: two workspaces, and neither can read the other's files.
--
-- `10_tenancy_isolation.sql` and `11_tenancy_matrix.sql` sweep tables.
-- Storage was never in either, and that is where a live leak was found:
-- a hand-made policy let every signed-in person read every workspace's
-- `floor-plans` objects. The replay these tests run never had that
-- policy, so this file is not what caught it — the drift check in the
-- doctor is (#1313). What this file does is pin the property itself, so
-- a migration that writes a broad storage read fails here.
--
-- Same idiom as the table tests: real JWT claims, then
-- `set local role authenticated`, because as `postgres` every policy is
-- bypassed and every assertion would pass while proving nothing.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-0000000000c1';
  u_b uuid := '00000000-0000-4000-8000-0000000000c2';
  ws_a uuid; ws_b uuid;
begin
  -- The profile comes from the trigger on `auth.users`; never insert it.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'storage-a@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'storage-b@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Storage A', 'FR', 'EUR', 'Europe/Paris', u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Storage B', 'FR', 'EUR', 'Europe/Paris', u_b) returning id into ws_b;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true), (ws_b, u_b, true, true);

  -- One object in EACH workspace, so "sees nothing" cannot pass because
  -- there was nothing to see.
  insert into storage.objects (bucket_id, name)
  values ('floor-plans', ws_a::text || '/levels/background.png'),
         ('floor-plans', ws_b::text || '/report/logo.png');

  perform set_config('deskilo.storage.u_a', u_a::text, true);
  perform set_config('deskilo.storage.u_b', u_b::text, true);
  perform set_config('deskilo.storage.ws_a', ws_a::text, true);
  perform set_config('deskilo.storage.ws_b', ws_b::text, true);
end
$seed$;

-- Before any object can exist, the bucket must. 0215 creates it; until
-- then, no instance built from the migrations had one.
select ok(
  exists (select 1 from storage.buckets
           where id = 'floor-plans' and not public
             and file_size_limit = 10485760
             and allowed_mime_types @> array['image/png', 'image/jpeg', 'image/webp']),
  'the migrations create the private floor-plans bucket, with its limits');

select pg_temp.seed();

select cmp_ok(
  (select count(*)::int from storage.objects
    where bucket_id = 'floor-plans'
      and (storage.foldername(name))[1] in (current_setting('deskilo.storage.ws_a'),
                                            current_setting('deskilo.storage.ws_b'))),
  '=', 2,
  'the seed really wrote one object into each workspace');

-- ------------------------------------------------------------ as A
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.storage.u_a'), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', current_setting('deskilo.storage.u_a'), true);
set local role authenticated;

select is(
  (select count(*)::int from storage.objects
    where bucket_id = 'floor-plans' and (storage.foldername(name))[1] = current_setting('deskilo.storage.ws_a')),
  1, 'a member reads their own workspace''s floor-plans object');

select is(
  (select count(*)::int from storage.objects
    where bucket_id = 'floor-plans' and (storage.foldername(name))[1] = current_setting('deskilo.storage.ws_b')),
  0, 'a member of A cannot read B''s floor-plans objects');

select is(
  (select array_agg(distinct (storage.foldername(name))[1]) from storage.objects
    where bucket_id = 'floor-plans'
      and (storage.foldername(name))[1] in (current_setting('deskilo.storage.ws_a'),
                                            current_setting('deskilo.storage.ws_b'))),
  array[current_setting('deskilo.storage.ws_a')],
  'listing the bucket shows A only its own workspace folder');

reset role;

-- ------------------------------------------------------------ as B
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.storage.u_b'), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', current_setting('deskilo.storage.u_b'), true);
set local role authenticated;

select is(
  (select count(*)::int from storage.objects
    where bucket_id = 'floor-plans' and (storage.foldername(name))[1] = current_setting('deskilo.storage.ws_b')),
  1, 'a member of B reads B''s object');

select is(
  (select count(*)::int from storage.objects
    where bucket_id = 'floor-plans' and (storage.foldername(name))[1] = current_setting('deskilo.storage.ws_a')),
  0, 'a member of B cannot read A''s floor-plans objects');

reset role;

-- ------------------------------------------------------------ the catalogue
-- The rule, stated where a future migration will trip it: a permissive
-- read on a workspace-folder bucket must ask about the workspace.
select is(
  (select count(*)::int from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and permissive = 'PERMISSIVE' and cmd in ('SELECT', 'ALL')
      and qual ilike '%floor-plans%'
      and qual not ilike '%is_member_of%' and qual not ilike '%is_owner_of%'),
  0, 'no floor-plans read policy grants without a workspace predicate');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'floor_plans_read'),
  0, 'the broad floor_plans_read policy does not exist');

select * from finish();
rollback;
