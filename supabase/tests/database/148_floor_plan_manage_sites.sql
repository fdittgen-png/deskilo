-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2137 / 0363 — editing the floor plan is delegable through manageSites.
--
-- The matrix: a member who holds manageSites ONLY through one of the
-- workspace's own roles edits the plan (tables, the plan's files in the
-- floor-plans bucket, the definers the editor calls); the built-in
-- Administrator does by default; a member without it is refused; the owner
-- still edits. The bucket's document images (`<ws>/report/...`) stay with
-- their own policies. Every write runs as `authenticated`.
begin;
select plan(28);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000006e1';
  u_admin uuid := '00000000-0000-4000-8000-0000000006e2';
  u_role  uuid := '00000000-0000-4000-8000-0000000006e3';
  u_plain uuid := '00000000-0000-4000-8000-0000000006e4';
  ws uuid;
  r uuid;
  m_role uuid;
  lv uuid := '00000000-0000-4000-8000-0000000006f1';
  lv2 uuid := '00000000-0000-4000-8000-0000000006f2';
  of uuid := '00000000-0000-4000-8000-0000000006f3';
  dk uuid := '00000000-0000-4000-8000-0000000006f4';
  st uuid := '00000000-0000-4000-8000-0000000006f5';
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'sites-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_admin, 'admin'), (u_role, 'role'),
                 (u_plain, 'plain')) v(u, n);
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags)
  values ('Sites', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_admin, false, true),
         (ws, u_plain, false, false);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_role, false, false) returning id into m_role;
  insert into public.workspace_roles (workspace_id, key, permissions, names)
  values (ws, 'facilities', array['manageSites'], '{"en": "Facilities"}'::jsonb)
  returning id into r;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r, m_role);

  delete from public.levels where workspace_id = ws;
  insert into public.levels (id, workspace_id, name, sort_order)
  values (lv, ws, 'Ground', 0), (lv2, ws, 'First', 1);
  insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values (of, ws, lv, 'Open space', 0, 0, 10, 10);
  insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values (dk, ws, of, 1, 1, 4, 2);
  insert into public.seats (id, workspace_id, desk_id, x, y)
  values (st, ws, dk, 1, 1);

  perform set_config('deskilo.ps.ws', ws::text, false);
  perform set_config('deskilo.ps.lv', lv::text, false);
  perform set_config('deskilo.ps.lv2', lv2::text, false);
  perform set_config('deskilo.ps.of', of::text, false);
  perform set_config('deskilo.ps.dk', dk::text, false);
  perform set_config('deskilo.ps.st', st::text, false);
  perform set_config('deskilo.ps.owner', u_owner::text, false);
  perform set_config('deskilo.ps.admin', u_admin::text, false);
  perform set_config('deskilo.ps.role', u_role::text, false);
  perform set_config('deskilo.ps.plain', u_plain::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.ps.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.ps.' || p)::uuid;
$$;

select pg_temp.seed();
set local role authenticated;

-- ── a member holding manageSites through a role ────────────────────────
select pg_temp.act_as('role');
select lives_ok(format($$ insert into public.levels (workspace_id, name, sort_order) values (%L, 'Mezzanine', 2) $$, pg_temp.id('ws')),
  'a role holder adds a level');
select lives_ok(format($$ insert into public.offices (workspace_id, level_id, name, x, y, w, h) values (%L, %L, 'Booth', 20, 0, 4, 4) $$, pg_temp.id('ws'), pg_temp.id('lv')),
  'adds an office');
select lives_ok(format($$ insert into public.desks (workspace_id, office_id, x, y, w, h) values (%L, %L, 6, 1, 2, 2) $$, pg_temp.id('ws'), pg_temp.id('of')),
  'adds a desk');
select lives_ok(format($$ insert into public.seats (workspace_id, desk_id, x, y) values (%L, %L, 2, 2) $$, pg_temp.id('ws'), pg_temp.id('dk')),
  'adds a seat');
select lives_ok(format($$ insert into public.plan_images (workspace_id, level_id, x, y, w, h, storage_path) values (%L, %L, 0, 0, 1, 1, %L) $$, pg_temp.id('ws'), pg_temp.id('lv'), pg_temp.id('ws') || '/img/00000000-0000-4000-8000-0000000006a1'),
  'places a plan image');
with moved as (update public.seats set x = 3 where id = pg_temp.id('st') returning 1)
select is((select count(*)::int from moved), 1, 'moves a seat');
select is(public.reorder_levels(pg_temp.id('ws'),
    array[pg_temp.id('lv2'), pg_temp.id('lv')] || array(select id from public.levels where workspace_id = pg_temp.id('ws') and name = 'Mezzanine'),
    array[pg_temp.id('lv'), pg_temp.id('lv2')] || array(select id from public.levels where workspace_id = pg_temp.id('ws') and name = 'Mezzanine'))->>'status',
  'saved', 'arranges the levels');
select lives_ok(format($$ insert into storage.objects (bucket_id, name) values ('floor-plans', %L) $$, pg_temp.id('ws') || '/img/00000000-0000-4000-8000-0000000006a1'),
  'uploads a plan image to the floor-plans bucket');
select lives_ok(format($$ insert into storage.objects (bucket_id, name) values ('floor-plans', %L) $$, pg_temp.id('ws') || '/' || pg_temp.id('lv')),
  'uploads a level background');
select throws_ok(format($$ insert into storage.objects (bucket_id, name) values ('floor-plans', %L) $$, pg_temp.id('ws') || '/report/logo.png'),
  '42501', null, 'but not a document image: manageSites is the plan''s files only');
select lives_ok(format($$ select count(*) from public.plan_media_orphans(%L) $$, pg_temp.id('ws')),
  'asks which plan files are orphaned');
select lives_ok(format($$ select public.delete_plan_object('seat', %L) $$, pg_temp.id('st')),
  'deletes a seat through the editor''s definer');
select is((select count(*)::int from public.seats where id = pg_temp.id('st')), 0,
  'and the seat is gone');

-- ── the built-in Administrator (manageSites by default) ────────────────
select pg_temp.act_as('admin');
select lives_ok(format($$ insert into public.levels (workspace_id, name, sort_order) values (%L, 'Attic', 3) $$, pg_temp.id('ws')),
  'the Administrator adds a level');
select lives_ok(format($$ select public.delete_plan_object('desk', %L) $$, pg_temp.id('dk')),
  'and deletes a desk');

-- ── a member without the permission ────────────────────────────────────
select pg_temp.act_as('plain');
select throws_ok(format($$ insert into public.levels (workspace_id, name, sort_order) values (%L, 'Sneaky', 9) $$, pg_temp.id('ws')),
  '42501', null, 'a plain member adds no level');
select throws_ok(format($$ insert into public.offices (workspace_id, level_id, name, x, y, w, h) values (%L, %L, 'Sneaky', 0, 0, 1, 1) $$, pg_temp.id('ws'), pg_temp.id('lv')),
  '42501', null, 'nor an office');
with moved as (update public.offices set x = 99 where id = pg_temp.id('of') returning 1)
select is((select count(*)::int from moved), 0, 'nor moves one');
select throws_ok(format($$ select public.delete_plan_object('office', %L) $$, pg_temp.id('of')),
  'P0001', 'owner only', 'nor deletes one');
select throws_ok(format($$ select public.reorder_levels(%L, array[%L, %L]::uuid[], array[%L, %L]::uuid[]) $$,
    pg_temp.id('ws'), pg_temp.id('lv'), pg_temp.id('lv2'), pg_temp.id('lv2'), pg_temp.id('lv')),
  'P0001', 'only the owner arranges the levels', 'nor arranges the levels');
select throws_ok(format($$ insert into storage.objects (bucket_id, name) values ('floor-plans', %L) $$, pg_temp.id('ws') || '/img/00000000-0000-4000-8000-0000000006a2'),
  '42501', null, 'nor uploads a plan image');
select is((select count(*)::int from public.plan_media_orphans(pg_temp.id('ws'))), 0,
  'and is told no orphaned plan file');
select throws_matching(format($$ select public.import_floor_plan_v3(%L, '[]'::jsonb, '[]'::jsonb) $$, pg_temp.id('ws')),
  'only the owner may import a floor plan', 'nor imports a floor plan');

-- ── the owner still edits ──────────────────────────────────────────────
select pg_temp.act_as('owner');
select lives_ok(format($$ insert into public.levels (workspace_id, name, sort_order) values (%L, 'Roof', 4) $$, pg_temp.id('ws')),
  'the owner adds a level');
select lives_ok(format($$ select public.delete_plan_object('office', %L) $$, pg_temp.id('of')),
  'and deletes an office');

-- ── an Administrator whose matrix row lacks manageSites ────────────────
reset role;
update public.workspaces set role_permissions = '{"admin": ["manageMembers"]}'::jsonb
 where id = pg_temp.id('ws');
set local role authenticated;
select pg_temp.act_as('admin');
select throws_ok(format($$ insert into public.levels (workspace_id, name, sort_order) values (%L, 'Cellar', 5) $$, pg_temp.id('ws')),
  '42501', null, 'an Administrator the owner took manageSites from adds no level');

-- ── importing: the role holder (last, it replaces the plan) ────────────
select pg_temp.act_as('role');
select lives_ok(format($$ select public.import_floor_plan_v3(%L, '[]'::jsonb, '[]'::jsonb) $$, pg_temp.id('ws')),
  'a role holder imports a floor plan');
select is((select count(*)::int from public.levels where workspace_id = pg_temp.id('ws')), 0,
  'and the import replaced the plan');

reset role;
select * from finish();
rollback;
