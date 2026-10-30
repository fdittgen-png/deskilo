-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3074 (0607) — a plan image is a photo or a drawn symbol, never both and
-- never neither: a symbol names one of the eight kinds, carries no storage
-- object and turns 0..3 quarters; a photo keeps its object and no kind.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000003074';
  ws uuid; lv uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'decor@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Decor', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true);
  insert into public.levels (workspace_id, name, sort_order) values (ws, 'L', 0) returning id into lv;
  perform set_config('deskilo.decor.ws', ws::text, false);
  perform set_config('deskilo.decor.lv', lv::text, false);
end;
$seed$;
select pg_temp.seed();

select lives_ok(
  $$insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind, quarter_turns)
    values (current_setting('deskilo.decor.ws')::uuid, current_setting('deskilo.decor.lv')::uuid, 1, 1, 12, 1, 'wall', 3)$$,
  'a wall turned three quarters is a plan image with no photo');

select throws_ok(
  $$insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind)
    values (current_setting('deskilo.decor.ws')::uuid, current_setting('deskilo.decor.lv')::uuid, 1, 1, 2, 2, 'sofa')$$,
  '23514', 'new row for relation "plan_images" violates check constraint "plan_images_kind_check"', 'a kind the server does not know is refused');

select throws_ok(
  $$insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind, storage_path)
    values (current_setting('deskilo.decor.ws')::uuid, current_setting('deskilo.decor.lv')::uuid, 1, 1, 2, 2, 'door', 'a/img/b')$$,
  '23514', 'new row for relation "plan_images" violates check constraint "plan_images_photo_or_symbol"', 'a symbol with a photo object is refused');

select throws_ok(
  $$insert into public.plan_images (workspace_id, level_id, x, y, w, h)
    values (current_setting('deskilo.decor.ws')::uuid, current_setting('deskilo.decor.lv')::uuid, 1, 1, 2, 2)$$,
  '23514', 'new row for relation "plan_images" violates check constraint "plan_images_photo_or_symbol"', 'an image with neither a photo nor a kind is refused');

select throws_ok(
  $$insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind, quarter_turns)
    values (current_setting('deskilo.decor.ws')::uuid, current_setting('deskilo.decor.lv')::uuid, 1, 1, 2, 2, 'pillar', 4)$$,
  '23514', 'new row for relation "plan_images" violates check constraint "plan_images_quarter_turns_check"', 'four quarter turns is not a turn count');

select lives_ok(
  $$insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
    values (current_setting('deskilo.decor.ws')::uuid, current_setting('deskilo.decor.lv')::uuid, 4, 4, 16, 12, 'ws/img/photo')$$,
  'a photo keeps its object and no kind');

select is((select count(*)::int from public.plan_images
            where level_id = current_setting('deskilo.decor.lv')::uuid), 2,
  'only the wall and the photo were kept');

select * from finish();
rollback;
