-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3074 — the drawn room belongs to the workspace that drew it. Decor is a
-- row of plan_images (a kind, no photo), so it travels under the plan's own
-- policies: a plain member READS the symbols of their workspace and cannot
-- insert, change or delete one; another workspace's symbols are invisible
-- to them. One thing varies per case: the person (plain member / owner of
-- the same workspace / owner of the other) or the workspace the row is in.
-- Every statement runs as `authenticated`; the fixture is seeded as the
-- test owner before the role is set.
begin;
select plan(14);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_member uuid := '00000000-0000-4000-8000-00000000d301';
  u_owner  uuid := '00000000-0000-4000-8000-00000000d302';
  u_other  uuid := '00000000-0000-4000-8000-00000000d303';
  lv_a uuid := '00000000-0000-4000-8000-00000000d311';
  lv_b uuid := '00000000-0000-4000-8000-00000000d312';
  wall_a uuid := '00000000-0000-4000-8000-00000000d321';
  couch_a uuid := '00000000-0000-4000-8000-00000000d322';
  table_b uuid := '00000000-0000-4000-8000-00000000d323';
  ws_a uuid; ws_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'decor-rls-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_member, 'member'), (u_owner, 'owner'), (u_other, 'other')) v(u, n);
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Decor A', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Decor B', 'FR', 'EUR', 'Europe/Paris', u_other) returning id into ws_b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_owner, true, true), (ws_a, u_member, false, false),
         (ws_b, u_other, true, true);

  delete from public.levels where workspace_id in (ws_a, ws_b);
  insert into public.levels (id, workspace_id, name, sort_order)
  values (lv_a, ws_a, 'Ground', 0), (lv_b, ws_b, 'Ground', 0);
  insert into public.plan_images (id, workspace_id, level_id, x, y, w, h, kind, quarter_turns)
  values (wall_a, ws_a, lv_a, 2, 3, 12, 1, 'wall', 0),
         (couch_a, ws_a, lv_a, 20, 8, 10, 6, 'couch', 1),
         (table_b, ws_b, lv_b, 5, 5, 8, 4, 'table', 0);

  perform set_config('deskilo.dr.ws_a', ws_a::text, false);
  perform set_config('deskilo.dr.ws_b', ws_b::text, false);
  perform set_config('deskilo.dr.lv_a', lv_a::text, false);
  perform set_config('deskilo.dr.lv_b', lv_b::text, false);
  perform set_config('deskilo.dr.wall_a', wall_a::text, false);
  perform set_config('deskilo.dr.table_b', table_b::text, false);
  perform set_config('deskilo.dr.member', u_member::text, false);
  perform set_config('deskilo.dr.owner', u_owner::text, false);
  perform set_config('deskilo.dr.other', u_other::text, false);
end
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.dr.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.dr.' || p)::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();
set local role authenticated;

-- ── a plain member: reads, never writes ────────────────────────────────
select pg_temp.act_as('member');
select is((select count(*)::int from public.plan_images
            where workspace_id = pg_temp.id('ws_a') and kind is not null), 2,
  'a member reads both symbols of their workspace');
select is((select count(*)::int from public.plan_images
            where workspace_id = pg_temp.id('ws_b')), 0,
  'and none of the other workspace''s');
select is((select count(*)::int from public.plan_images where kind is not null), 2,
  'so the symbols visible to them are exactly their workspace''s two');

select throws_ok(format($$ insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind)
    values (%L, %L, 1, 1, 4, 2, 'door') $$, pg_temp.id('ws_a'), pg_temp.id('lv_a')),
  '42501', null, 'a member cannot draw a symbol in their own workspace');
with moved as (update public.plan_images set x = 99 where id = pg_temp.id('wall_a') returning 1)
select is((select count(*)::int from moved), 0, 'nor move one');
select is((select x from public.plan_images where id = pg_temp.id('wall_a')), 2,
  'and the symbol stays where it was');
with gone as (delete from public.plan_images where id = pg_temp.id('wall_a') returning 1)
select is((select count(*)::int from gone), 0, 'nor delete one');
select is((select count(*)::int from public.plan_images
            where workspace_id = pg_temp.id('ws_a') and kind is not null), 2,
  'and both symbols are still there');
select throws_ok(format($$ insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind)
    values (%L, %L, 1, 1, 4, 2, 'door') $$, pg_temp.id('ws_b'), pg_temp.id('lv_b')),
  '42501', null, 'and cannot draw in the other workspace either');

-- ── the other workspace's owner sees only their own ────────────────────
select pg_temp.act_as('other');
select is((select count(*)::int from public.plan_images
            where workspace_id = pg_temp.id('ws_b')), 1,
  'the other workspace''s owner reads their one symbol');
select is((select count(*)::int from public.plan_images
            where workspace_id = pg_temp.id('ws_a')), 0,
  'and none of the first workspace''s');

-- ── the same statements as the workspace owner (positive control) ──────
select pg_temp.act_as('owner');
select lives_ok(format($$ insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind)
    values (%L, %L, 1, 1, 4, 2, 'door') $$, pg_temp.id('ws_a'), pg_temp.id('lv_a')),
  'the owner draws a symbol');
with moved as (update public.plan_images set x = 99 where id = pg_temp.id('wall_a') returning 1)
select is((select count(*)::int from moved), 1, 'moves one');
with gone as (delete from public.plan_images where id = pg_temp.id('wall_a') returning 1)
select is((select count(*)::int from gone), 1, 'and deletes one');

reset role;
select * from finish();
rollback;
