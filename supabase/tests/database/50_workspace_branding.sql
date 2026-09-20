-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1289 — a workspace's own colours: the keyed write, the validator, the
-- entity, and what an import keeps. The contrast rule is the client's
-- (`auditThemeContrast`, one implementation for the lint and the runtime
-- refusal); the database keeps the shape honest.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000d1';
  u_plain uuid := '00000000-0000-4000-8000-0000000000d2';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'branding-owner@deskilo.test', '', now(), now(), now()),
         (u_plain, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'branding-plain@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Branding', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false);

  perform set_config('deskilo.brand.ws', ws::text, false);
  perform set_config('deskilo.brand.owner', u_owner::text, false);
  perform set_config('deskilo.brand.plain', u_plain::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.brand.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.brand.ws')::uuid;
$$;

create or replace function pg_temp.stored() returns jsonb language sql as $$
  select branding from public.workspaces where id = pg_temp.ws();
$$;

select pg_temp.seed();

select is(pg_temp.stored(), '{}'::jsonb,
  'a workspace that chose nothing carries an empty map, so the app is '
  'pixel-identical to the product palette');

select pg_temp.act_as('owner');
select is(
  public.set_workspace_branding(pg_temp.ws(), '{"seed_color": "#c2410c"}'::jsonb),
  '{"seed_color": "#C2410C"}'::jsonb,
  'a settings manager sets the seed; it is stored upper-case #RRGGBB');

select is(
  public.set_workspace_branding(pg_temp.ws(),
    '{"office_palette": ["#ebdcc9", "#cfe3dc"], "seat_palette": "default"}'::jsonb),
  '{"seed_color": "#C2410C", "office_palette": ["#EBDCC9", "#CFE3DC"], "seat_palette": "default"}'::jsonb,
  'a second write joins the first — the merge is the database''s, so two '
  'owners cannot revert each other');

select is(
  public.set_workspace_branding(pg_temp.ws(), '{"office_palette": null}'::jsonb),
  '{"seed_color": "#C2410C", "seat_palette": "default"}'::jsonb,
  'json null removes a key and leaves the others alone');

select throws_matching(
  format($$ select public.set_workspace_branding(%L, '{"seed_color": "tomato"}'::jsonb) $$, pg_temp.ws()),
  'must be #RRGGBB',
  'a seed that is not #RRGGBB is refused');

select throws_matching(
  format($$ select public.set_workspace_branding(%L, '{"emblem": "x"}'::jsonb) $$, pg_temp.ws()),
  'unknown branding key',
  'a key this slice does not define is refused — the emblem is a file in '
  'storage, never a value here');

select throws_matching(
  format($$ select public.set_workspace_branding(%L, '{"seat_palette": "neon"}'::jsonb) $$, pg_temp.ws()),
  'not a curated set',
  'seat states are never a free colour: only a curated, colourblind-tested '
  'palette key');

select throws_matching(
  format($$ select public.set_workspace_branding(%L, '{"office_palette": ["#111111", "nope"]}'::jsonb) $$, pg_temp.ws()),
  'one to eight #RRGGBB',
  'every office fill is a colour');

select pg_temp.act_as('plain');
select throws_matching(
  format($$ select public.set_workspace_branding(%L, '{"seed_color": "#000000"}'::jsonb) $$, pg_temp.ws()),
  'only workspace settings managers',
  'a member who manages nothing cannot recolour anything — proven beside '
  'the owner''s success above');

select is(
  public.imported_branding('{"seed_color": "#111111", "seat_palette": "default"}'::jsonb,
                           '{"seed_color": "#222222", "bogus": 1, "office_palette": ["nope"]}'::jsonb,
                           'merge'),
  '{"seed_color": "#222222", "seat_palette": "default"}'::jsonb,
  'an import is cleaned leniently (an unknown key and a bad palette are '
  'dropped, not fatal) and a merge keeps what the target already chose');

select pg_temp.act_as('owner');
select is(
  public.export_workspace_configuration(pg_temp.ws())->'workspace'->'branding',
  '{"seed_color": "#C2410C", "seat_palette": "default"}'::jsonb,
  'the configuration export carries the colours');

select is(
  (select e->>'merge_policy' || '/' || (e->>'group')
     from jsonb_array_elements(public.deployable_entities()) e
    where e->>'key' = 'branding'),
  'keyed_update/appearance',
  'the colours travel with a template as the appearance group, keyed, and '
  'the publication rules allow them (colours only; an emblem never leaves)');

select * from finish();
rollback;
