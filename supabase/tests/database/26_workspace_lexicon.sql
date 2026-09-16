-- SPDX-License-Identifier: 0BSD
--
-- #1277 S1 — a workspace may say its own words, and only the words it is
-- allowed to say.
--
-- The allow-list is the security boundary: a workspace may rename a
-- seat, and may NOT rewrite an error message, a legal mention or a
-- confirmation, because those keys are not in `lexicon_allowed_keys()`.
-- So the refusals here matter more than the happy path.
--
-- Seeded by inserting into `workspaces` and `members` directly, which is
-- what every other file in this suite does. `25_new_member_defaults.sql`
-- was the one that called `create_workspace()` instead, and that made it
-- the only file whose setup nothing else exercised.
begin;
select plan(12);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000c1';
  u_plain uuid := '00000000-0000-4000-8000-0000000000c2';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'lexicon-owner@deskilo.test', '', now(), now(), now()),
         (u_plain, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'lexicon-plain@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Lexicon', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false);

  perform set_config('deskilo.lex.ws', ws::text, false);
  perform set_config('deskilo.lex.owner', u_owner::text, false);
  perform set_config('deskilo.lex.plain', u_plain::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.lex.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.term(p_locale text, p_key text)
returns text language sql as $$
  select lexicon->p_locale->>p_key from public.workspaces
   where id = current_setting('deskilo.lex.ws')::uuid;
$$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.lex.ws')::uuid;
$$;

select pg_temp.seed();

-- ------------------------------------------- a space that said nothing
select is(
  (select lexicon from public.workspaces where id = pg_temp.ws()),
  '{}'::jsonb,
  'a workspace that has never said a word carries an empty lexicon, so '
  'every screen renders exactly as it did before this existed');

-- --------------------------------------------------------- the writer
select pg_temp.act_as('owner');
select lives_ok(
  format($$ select public.set_workspace_lexicon_term(%L, 'fr', 'spaceKindSeat', 'Place') $$,
         pg_temp.ws()),
  'a settings manager may rename a seat');
select is(pg_temp.term('fr', 'spaceKindSeat'), 'Place',
  'and the word is stored under its locale');

select public.set_workspace_lexicon_term(pg_temp.ws(), 'fr', 'legendFree', 'Libre');
select is(pg_temp.term('fr', 'spaceKindSeat') || '/' || pg_temp.term('fr', 'legendFree'),
  'Place/Libre',
  'a second word joins the first rather than replacing the map — the '
  'merge is the database''s, so two editors cannot revert each other');

-- ------------------------------------------- reset REMOVES, never sets
select public.set_workspace_lexicon_term(pg_temp.ws(), 'fr', 'legendFree', null);
select is(
  coalesce(pg_temp.term('fr', 'legendFree'), '<removed>') || '/' ||
  coalesce(pg_temp.term('fr', 'spaceKindSeat'), '<LOST>'),
  '<removed>/Place',
  'a reset removes the override instead of storing the product default, '
  'which would freeze that word against every future rewording — and it '
  'leaves the other words alone');

-- ------------------------------------------------ the allow-list holds
select is(
  (select count(*)::int from public.lexicon_allowed_keys()),
  33,
  'the allow-list is the 33 product terms, each verified against '
  'app_en.arb as a simple message with no ICU plural or select — and '
  'each one actually rendered by a widget, so renaming it changes '
  'something a member can see');

select throws_matching(
  format($$ select public.set_workspace_lexicon_term(%L, 'fr', 'bookingPastError', 'Nope') $$,
         pg_temp.ws()),
  'unknown wording key',
  'a key that is not product terminology is refused: a workspace may '
  'rename a seat and may NOT rewrite an error message');

select throws_matching(
  format($$ select public.set_workspace_lexicon_term(%L, 'zz', 'legendFree', 'X') $$,
         pg_temp.ws()),
  'unsupported locale',
  'and a locale the app does not ship is refused');

select throws_matching(
  format($$ select public.set_workspace_lexicon_term(%L, 'fr', 'legendFree', 'Libre {count}') $$,
         pg_temp.ws()),
  'placeholders',
  'an override whose placeholder set differs from the declared one is '
  'refused — today every allow-listed key declares none, so the rule is '
  'in place before the first key that needs it');

select throws_matching(
  format($$ select public.set_workspace_lexicon_term(%L, 'fr', 'legendFree', %L) $$,
         pg_temp.ws(), repeat('x', 121)),
  'at most 120 characters',
  'a word is a word, not a paragraph');

-- ------------------------------------------------------- who may write
-- The assertion that matters: this function is SECURITY DEFINER and
-- writes to `workspaces`, so the gate is the only thing between a plain
-- member and the workspace configuration.
select pg_temp.act_as('plain');
select throws_matching(
  format($$ select public.set_workspace_lexicon_term(%L, 'fr', 'legendFree', 'Pirate') $$,
         pg_temp.ws()),
  'only workspace settings managers',
  'a member who manages nothing cannot rename anything — proven beside '
  'the owner''s success above, so a gate that refused everybody could '
  'not read as a pass');

-- ------------------------------------------------------- and it travels
select is(
  (select e->>'merge_policy' || '/' || (e->>'group')
     from jsonb_array_elements(public.deployable_entities()) e
    where e->>'key' = 'lexicon'),
  'keyed_update/wording',
  'the words travel with a template keyed on (locale, key): a template '
  'that supplies French words must not delete the German ones a space '
  'already wrote');

select * from finish();
rollback;
