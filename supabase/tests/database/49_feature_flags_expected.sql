-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1329 — a feature change is written against the state it was decided
-- on. `set_feature_flags` (0245) takes the preview's read-set and refuses,
-- writing nothing, when any of it moved — including a key the delta does
-- not touch. A null read-set keeps the old unconditional merge.
begin;
select plan(11);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001329';
  m uuid := '00000000-0000-4000-8000-000000001330';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'flags-owner@deskilo.test', '', now(), now(), now()),
         (m, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'flags-member@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Flags', 'FR', 'EUR', 'Europe/Paris', u, '{"multiSite": false}'::jsonb) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u, true, true);
  insert into public.members (workspace_id, user_id) values (ws, m);
  perform set_config('deskilo.ff.ws', ws::text, false);
  perform set_config('deskilo.ff.owner', u::text, false);
  perform set_config('deskilo.ff.member', m::text, false);
end;
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.ff.' || p_who), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', current_setting('deskilo.ff.' || p_who), true);
  execute 'set local role authenticated';
end
$act$;

create or replace function pg_temp.flags() returns jsonb language sql as $$
  select feature_flags from public.workspaces where id = current_setting('deskilo.ff.ws')::uuid;
$$;

select pg_temp.seed();

select is(
  (select count(*)::int from pg_proc where proname = 'set_feature_flags'),
  1, 'one overload: a two-argument call resolves to the defaulted third');

select pg_temp.act_as('owner');

select is(
  public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid, '{"multiSite": true}'::jsonb)->'multiSite',
  'true'::jsonb, 'a call without a read-set merges as before');

-- An absent key compares through the registry default, as the client reads it.
select is(
  public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid, '{"kioskMode": true}'::jsonb,
    jsonb_build_object('kioskMode', (public.feature_registry()->'kioskMode'->>'default')::boolean,
                       'multiSite', true))->'kioskMode',
  'true'::jsonb, 'a fresh read-set writes the exact delta');

select throws_ok(
  $$ select public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
       '{"kioskMode": false}'::jsonb, '{"kioskMode": false}'::jsonb) $$,
  'DK409', 'the features changed since they were read: kioskMode',
  'a stale WRITTEN key is refused');

select throws_ok(
  $$ select public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
       '{"badgeSignIn": true}'::jsonb, '{"multiSite": false}'::jsonb) $$,
  'DK409', 'the features changed since they were read: multiSite',
  'a stale UNWRITTEN key — a prerequisite or dependant the delta does not touch — is refused too');

select ok(not (pg_temp.flags() ? 'badgeSignIn'), 'and a refused write writes nothing');

select is(
  public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
    '{"badgeSignIn": true}'::jsonb, '{"kioskMode": true}'::jsonb)->'multiSite',
  'true'::jsonb, 'an unrelated delta with a valid read-set merges and keeps the other keys');

select is(
  public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
    '{"badgeSignIn": true}'::jsonb, '{"kioskMode": true, "badgeSignIn": true}'::jsonb)->'badgeSignIn',
  'true'::jsonb, 'a repeated identical delta is idempotent');

select throws_ok(
  $$ select public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
       '{"kioskMode": true}'::jsonb, '[]'::jsonb) $$,
  'expected feature flags must be an object', 'a read-set that is not an object is refused');

select throws_ok(
  $$ select public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
       '{"kioskMode": true}'::jsonb, '{"kioskMode": "yes"}'::jsonb) $$,
  'expected feature kioskMode must be true or false', 'a read-set value that is not a boolean is refused');

reset role;
select pg_temp.act_as('member');
select throws_ok(
  $$ select public.set_feature_flags(current_setting('deskilo.ff.ws')::uuid,
       '{"kioskMode": true}'::jsonb, '{"kioskMode": true}'::jsonb) $$,
  'only an owner changes the features', 'a plain member is refused, read-set or not');
reset role;

select * from finish();
rollback;
