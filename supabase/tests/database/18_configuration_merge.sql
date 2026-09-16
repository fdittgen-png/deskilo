-- SPDX-License-Identifier: 0BSD
--
-- #1276 S1 — the configuration import has a mode, and the default is the
-- old behaviour.
--
-- `import_workspace_configuration` is a MIRROR: it deletes fee bands,
-- closure days, validation policies and documents, and deactivates every
-- package, service, plan, accessory and VAT rate the payload does not
-- name. That is right for a production deployment, whose job is to make
-- the target equal the source.
--
-- It is wrong for a template. Applying "the French coworking rules" to a
-- space that already runs must add and update, never remove — nobody
-- should lose their own closure days by accepting a set of booking rules.
--
-- The risk this file guards is the other direction: the writer is SHARED
-- with production deployment, so a wrong default would leave prod
-- carrying rows dev deleted. `mirror` stays the default, and a
-- two-argument call still means mirror.
begin;
select plan(10);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000d1';
  u_member uuid := '00000000-0000-4000-8000-0000000000d2';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'merge-owner@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'merge-member@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Merge', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_member, false, false);

  -- Configuration this workspace already has, which no template names.
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
  values (ws, 0, 50, 5000, 0), (ws, 50, 100, 10000, 0);
  insert into public.closure_days (workspace_id, day, reason)
  values (ws, date '2026-03-03', 'its own');
  insert into public.services (workspace_id, name, price_cents, active)
  values (ws, 'Coffee', 200, true);

  perform set_config('deskilo.merge.ws', ws::text, false);
  perform set_config('deskilo.merge.owner', u_owner::text, false);
  perform set_config('deskilo.merge.member', u_member::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.merge.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.bands() returns int language sql as $$
  select count(*)::int from public.fee_bands
   where workspace_id = current_setting('deskilo.merge.ws')::uuid;
$$;
create or replace function pg_temp.closures() returns int language sql as $$
  select count(*)::int from public.closure_days
   where workspace_id = current_setting('deskilo.merge.ws')::uuid;
$$;
create or replace function pg_temp.active_services() returns int language sql as $$
  select count(*)::int from public.services
   where workspace_id = current_setting('deskilo.merge.ws')::uuid and active;
$$;

select pg_temp.seed();
select pg_temp.act_as('owner');

-- ------------------------------------------------------ merge keeps
-- A payload naming only booking rules, and an EMPTY services list: the
-- mirror would delete the bands and deactivate the service.
select public.import_workspace_configuration(
  current_setting('deskilo.merge.ws')::uuid,
  '{"workspace": {"booking_rules": {"open_weekdays": [1,2,3]}}, "tables": {"services": []}}'::jsonb,
  'merge');

select is(pg_temp.bands(), 2,
  'merge keeps fee bands the payload does not name — the mirror deletes them');
select is(pg_temp.closures(), 1,
  'merge keeps closure days: nobody loses their own by accepting booking rules');
select is(pg_temp.active_services(), 1,
  'merge deactivates nothing the payload omits');

-- ------------------------------------------------------- idempotence
select public.import_workspace_configuration(
  current_setting('deskilo.merge.ws')::uuid,
  '{"workspace": {"booking_rules": {"open_weekdays": [1,2,3]}}, "tables": {"services": []}}'::jsonb,
  'merge');
select is(pg_temp.bands(), 2, 'a second merge changes nothing');
select is(pg_temp.closures(), 1, 'a second merge adds no duplicate closure day');

-- --------------------------------------------- mirror is still mirror
-- TWO arguments: the third parameter defaults. This is why dropping the
-- old signature is safe, and it is the property a deployment relies on.
select public.import_workspace_configuration(
  current_setting('deskilo.merge.ws')::uuid,
  '{"workspace": {}, "tables": {"fee_bands": [{"from_pct": 0, "to_pct": 100, "fee_cents": 1}], "services": []}}'::jsonb);

select is(pg_temp.bands(), 1,
  'a defaulted call still MIRRORS: the band set is replaced, not merged');
select is(pg_temp.active_services(), 0,
  'and a service the payload omits is still deactivated');

-- ------------------------------------------------------ authorization
select pg_temp.act_as('member');
select throws_matching(
  format($$ select public.import_workspace_configuration(%L, '{"workspace": {}}'::jsonb, 'merge') $$,
         current_setting('deskilo.merge.ws')),
  'only an owner',
  'merge is no wider than mirror: a member without manageConfiguration is refused');

-- --------------------------------------------------- the entity keys
-- Counted against the registry, not pinned to a number. The first
-- version said 18, and #1295's nineteenth entity broke it the moment a
-- new entity was legitimate — which is the opposite of what this
-- assertion means. The invariant is EVERY, whatever the total.
select is(
  (select count(*)::int from jsonb_array_elements(public.deployable_entities()) e
    where e ? 'merge_policy' and e ? 'group'),
  (select count(*)::int from jsonb_array_elements(public.deployable_entities()) e),
  'every entity declares how it merges and which group it belongs to');

select is(
  (select e->>'merge_policy' from jsonb_array_elements(public.deployable_entities()) e
    where e->>'key' = 'tariffs'),
  'replace_setting',
  'fee bands PARTITION 0-100, so tariffs travel whole or not at all — '
  'merging them by from_pct leaves overlapping ranges and member_statement '
  'then picks a band arbitrarily');

select * from finish();
rollback;
