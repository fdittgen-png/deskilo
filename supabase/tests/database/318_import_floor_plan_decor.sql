-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3074 / 0624: importing a workspace file brings back the drawn room. The
-- import replaces the plan, so the level's symbols are written with it: the
-- right kinds on the right level at the right place and turn; a file without
-- symbols leaves none; an unknown kind and a malformed entry are refused and
-- leave the plan as it was.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000003183e1';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'decor-import@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Decor import', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true);
  perform set_config('deskilo.test.ws', ws::text, false);
  perform set_config('deskilo.test.u', u::text, false);
end;
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select pg_temp.seed();

create or replace function pg_temp.import(p_plan jsonb) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.test.u'), 'role', 'authenticated')::text, true);
  perform public.import_floor_plan_v3(current_setting('deskilo.test.ws')::uuid, p_plan, '[]'::jsonb);
end;
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create or replace function pg_temp.decor() returns jsonb language sql as $f$
  select coalesce(jsonb_agg(jsonb_build_object('level', l.name, 'kind', i.kind, 'x', i.x, 'y', i.y, 'w', i.w, 'h', i.h, 'turns', i.quarter_turns)
                            order by l.sort_order, i.kind), '[]'::jsonb)
    from public.plan_images i join public.levels l on l.id = i.level_id
   where i.workspace_id = current_setting('deskilo.test.ws')::uuid;
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select lives_ok($$select pg_temp.import('[
  {"name": "RDC", "sort_order": 0, "offices": [], "decor": [
     {"kind": "wall", "x": 0, "y": 6, "w": 12, "h": 1, "quarter_turns": 0},
     {"kind": "door", "x": 4, "y": 6, "w": 3, "h": 3, "quarter_turns": 2}]},
  {"name": "Étage", "sort_order": 1, "offices": [], "decor": [
     {"kind": "wc", "x": 1, "y": 1, "w": 2, "h": 2}]}]'::jsonb)$$,
  'a plan with symbols imports');
select is(pg_temp.decor(), '[
  {"level": "RDC", "kind": "door", "x": 4, "y": 6, "w": 3, "h": 3, "turns": 2},
  {"level": "RDC", "kind": "wall", "x": 0, "y": 6, "w": 12, "h": 1, "turns": 0},
  {"level": "Étage", "kind": "wc", "x": 1, "y": 1, "w": 2, "h": 2, "turns": 0}]'::jsonb,
  'each symbol is on its own level, at its place and turn (a missing turn is 0)');
select is((select count(*)::int from public.plan_images
            where workspace_id = current_setting('deskilo.test.ws')::uuid and storage_path is not null), 0,
  'and none of them is a photo');

select throws_ok($$select pg_temp.import('[{"name": "RDC", "sort_order": 0, "offices": [],
  "decor": [{"kind": "sofa", "x": 0, "y": 0, "w": 2, "h": 2}]}]'::jsonb)$$, null, null,
  'an unknown kind is refused');
select throws_ok($$select pg_temp.import('[{"name": "RDC", "sort_order": 0, "offices": [],
  "decor": [{"kind": "wall", "x": "0", "y": 0, "w": 2, "h": 1}]}]'::jsonb)$$, 'P0001', 'malformed plan: bad decor',
  'a malformed entry is refused by name');
select is(jsonb_array_length(pg_temp.decor()), 3, 'a refused file leaves the plan as it was');

select pg_temp.import('[{"name": "RDC", "sort_order": 0, "offices": []}]'::jsonb);
select is(pg_temp.decor(), '[]'::jsonb, 'a file without symbols replaces the plan with none');

select * from finish();
rollback;
