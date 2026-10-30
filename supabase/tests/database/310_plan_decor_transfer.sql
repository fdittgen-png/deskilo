-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3074 (0608) — a level holding a drawn symbol transfers whole: the export
-- names the symbol's kind and turns beside the photo's path, the merge into a
-- second workspace recreates both, and a repeated merge adds no second wall.
begin;
select plan(4);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000003075';
  ws uuid; ws2 uuid; lv uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'decor-transfer@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Source', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Target', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true), (ws2, u, true, true);
  insert into public.levels (workspace_id, name, sort_order) values (ws, 'L', 0) returning id into lv;
  insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind, quarter_turns)
  values (ws, lv, 1, 1, 1, 12, 'wall', 1);
  insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path)
  values (ws, lv, 4, 4, 16, 12, ws || '/img/photo');
  perform set_config('deskilo.dt.ws', ws::text, false);
  perform set_config('deskilo.dt.ws2', ws2::text, false);
  perform public.merge_floor_plan(ws2, public.export_floor_plan(ws));
  perform public.merge_floor_plan(ws2, public.export_floor_plan(ws));
end;
$seed$;
select pg_temp.seed();

select is(
  (select jsonb_array_length(public.export_floor_plan(current_setting('deskilo.dt.ws')::uuid) -> 0 -> 'images')),
  2, 'the export names the symbol and the photo');

select is(
  (select count(*)::int from public.plan_images i join public.levels l on l.id = i.level_id
    where l.workspace_id = current_setting('deskilo.dt.ws2')::uuid),
  2, 'a repeated merge adds no second wall');

select is(
  (select count(*)::int from public.plan_images i join public.levels l on l.id = i.level_id
    where l.workspace_id = current_setting('deskilo.dt.ws2')::uuid
      and i.kind = 'wall' and i.quarter_turns = 1 and i.w = 1 and i.h = 12),
  1, 'the wall keeps its kind, its turn and its footprint');

select is(
  (select count(*)::int from public.plan_images i join public.levels l on l.id = i.level_id
    where l.workspace_id = current_setting('deskilo.dt.ws2')::uuid
      and i.storage_path = current_setting('deskilo.dt.ws2') || '/img/photo'),
  1, 'the photo lands under the target workspace prefix');

select * from finish();
rollback;
