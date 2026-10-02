-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2012 B (0332) — plan_media_orphans names only what cleanup may remove:
-- an old background and an abandoned plan image of the owner's own
-- workspace. Never a referenced object, a fresh upload, a report image,
-- another workspace's object, nor anything for a non-owner; at most the
-- limit asked.
begin;
select plan(8);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000002012';
  v uuid := '00000000-0000-4000-8000-000000002013';
  ws uuid; ws2 uuid; lv uuid;
  img uuid := '00000000-0000-4000-8000-0000000020aa';
  old timestamptz := now() - interval '3 days';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'orphans@deskilo.test', '', now(), now(), now()),
         (v, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'orphans-other@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Orphans', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Other', 'FR', 'EUR', 'Europe/Paris', v) returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true), (ws2, v, true, true);
  insert into public.levels (workspace_id, name, sort_order) values (ws, 'L', 0) returning id into lv;
  update public.levels set background_path = ws || '/' || lv || '.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
   where id = lv;
  insert into public.plan_images (id, workspace_id, level_id, x, y, w, h, storage_path)
  values (img, ws, lv, 0, 0, 1, 1, ws || '/img/' || img);
  insert into storage.objects (bucket_id, name, created_at) values
    ('floor-plans', ws || '/' || lv || '.aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', old),
    ('floor-plans', ws || '/' || lv, old),
    ('floor-plans', ws || '/img/' || img, old),
    ('floor-plans', ws || '/img/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', old),
    ('floor-plans', ws || '/img/cccccccc-cccc-4ccc-8ccc-cccccccccccc', now()),
    ('floor-plans', ws || '/report/logo.png', old),
    ('floor-plans', ws2 || '/img/dddddddd-dddd-4ddd-8ddd-dddddddddddd', old);
  perform set_config('deskilo.orph.ws', ws::text, false);
  perform set_config('deskilo.orph.ws2', ws2::text, false);
  perform set_config('deskilo.orph.lv', lv::text, false);
  perform set_config('deskilo.orph.u', u::text, false);
  perform set_config('deskilo.orph.v', v::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.orph.' || p), 'role', 'authenticated')::text, false);
$$;
create or replace function pg_temp.named() returns text[] language sql as $$
  select coalesce(array_agg(x order by x), '{}')
    from public.plan_media_orphans(current_setting('deskilo.orph.ws')::uuid) x;
$$;

select pg_temp.as_user('u');
select is(
  pg_temp.named(),
  array[current_setting('deskilo.orph.ws') || '/' || current_setting('deskilo.orph.lv'),
        current_setting('deskilo.orph.ws') || '/img/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'],
  'the owner is told exactly the old background and the abandoned image');
select ok(not (current_setting('deskilo.orph.ws') || '/img/00000000-0000-4000-8000-0000000020aa') = any(pg_temp.named()),
  'a referenced plan image is never named');
select ok(not exists (select 1 from unnest(pg_temp.named()) x where x like '%.aaaaaaaa-%'),
  'the referenced background is never named');
select ok(not exists (select 1 from unnest(pg_temp.named()) x where x like '%cccccccc%'),
  'an upload younger than a day is never named');
select ok(not exists (select 1 from unnest(pg_temp.named()) x where x like '%/report/%'),
  'a report image is never named');
select is(
  (select count(*)::int from public.plan_media_orphans(current_setting('deskilo.orph.ws2')::uuid)),
  0, 'another workspace''s objects are not the owner''s to name');
select is(
  (select count(*)::int from public.plan_media_orphans(current_setting('deskilo.orph.ws')::uuid, 1)),
  1, 'the limit holds');

select pg_temp.as_user('v');
select is(pg_temp.named(), '{}'::text[], 'a non-owner is told nothing');

select * from finish();
rollback;
