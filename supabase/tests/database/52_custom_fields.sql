-- SPDX-License-Identifier: 0BSD
--
-- #1288 S1 — questions a workspace asks, and the answers.
--
-- The claim this file defends is that a custom field is as governed as a
-- built-in one: the definition is validated when it is written, the
-- answer is validated when it is saved, and who may read it is the
-- definition's own business rather than a policy written by hand on six
-- tables.
--
-- Visibility is asserted through `member_field_readable`, which is what
-- the value policies call. Asserting it through a direct select would
-- need a second role and would prove nothing more: the policy IS that
-- function, and a test that re-implements the rule agrees with itself.
begin;
select plan(30);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000f1';
  u_plain uuid := '00000000-0000-4000-8000-0000000000f2';
  u_other uuid := '00000000-0000-4000-8000-0000000000f3';
  ws uuid;
  m_owner uuid;
  m_plain uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'fields-owner@deskilo.test', '', now(), now(), now()),
         (u_plain, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'fields-plain@deskilo.test', '', now(), now(), now()),
         (u_other, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'fields-other@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, default_locale, feature_flags)
  values ('Questions', 'FR', 'EUR', 'Europe/Paris', u_owner, 'en',
          '{"customFields": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false) returning id into m_plain;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_other, false, false);

  perform set_config('deskilo.fields.ws', ws::text, false);
  perform set_config('deskilo.fields.owner', u_owner::text, false);
  perform set_config('deskilo.fields.plain', u_plain::text, false);
  perform set_config('deskilo.fields.other', u_other::text, false);
  perform set_config('deskilo.fields.m_plain', m_plain::text, false);
  perform set_config('deskilo.fields.m_owner', m_owner::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.fields.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.fields.ws')::uuid;
$$;
create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select current_setting('deskilo.fields.m_' || p_who)::uuid;
$$;
create or replace function pg_temp.field(p_key text) returns uuid language sql as $$
  select id from public.workspace_field_definitions
   where workspace_id = pg_temp.ws() and key = p_key;
$$;

select pg_temp.seed();
select pg_temp.act_as('owner');

-- ── the definition is validated where it is written ──────────────────

select isnt(
  public.set_workspace_field(pg_temp.ws(), 'committee', 'text',
    '{"en": "Committee role", "fr": "Fonction au bureau"}'::jsonb,
    true, true, 'managers', array['profile'], 'general', 1,
    '{"max_length": 20}'::jsonb),
  null,
  'an owner asks a question, in the languages the space reads');

select is(
  (select l.label from public.workspace_field_labels l
    where l.definition_id = pg_temp.field('committee') and l.locale = 'fr'),
  'Fonction au bureau',
  'the label is a row per language, so a member reads the question in '
  'their own and not the owner''s');

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'joined', 'nope', '{"en":"a"}'::jsonb) $$, pg_temp.ws()),
  'unknown field type nope',
  'an answer type the product cannot store is refused');

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'joined', 'text', '{"en":"a"}'::jsonb, false, true, 'self', array['nowhere']) $$, pg_temp.ws()),
  'unknown context nowhere',
  'a context is a code registry: a question can only be asked where a '
  'form exists to ask it');

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'joined', 'text', '{"en":"a"}'::jsonb, false, true, 'self', array[]::text[]) $$, pg_temp.ws()),
  'no context is asked nowhere',
  'a question with no context would be invisible everywhere');

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'joined', 'text', '{"en":"a"}'::jsonb, false, true, 'self', array['profile'], 'general', 0, '{"regex":"x"}'::jsonb) $$, pg_temp.ws()),
  'unknown validation rule regex',
  'validation is a closed vocabulary — a definition travels with a '
  'template, and a template must not be able to run something');

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'joined', 'text', '{"en":"a"}'::jsonb, false, true, 'self', array['profile'], 'general', 0, '{"named":"iban"}'::jsonb) $$, pg_temp.ws()),
  'unknown validator iban',
  'the named validators are a curated list, not a plugin point');

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'joined', 'text', '{"it":"a"}'::jsonb) $$, pg_temp.ws()),
  'reads en and the question has no label',
  'a question nobody in this space can read is not a question');

select pg_temp.act_as('plain');
select throws_matching(
  format($$ select public.set_workspace_field(%L, 'sneaky', 'text', '{"en":"a"}'::jsonb) $$, pg_temp.ws()),
  'only an owner defines the questions',
  'defining what a space asks its members is the owner''s');

-- ── the answer is validated where it is saved ────────────────────────

select throws_matching(
  format($$ select public.set_member_field_values(%L, 'profile', '{"committee": "a very very long answer indeed"}'::jsonb) $$, pg_temp.member('plain')),
  'at most 20 characters',
  'the rule the definition carries is enforced on the server, so a '
  'client that forgets it cannot store a value the form would refuse');

select throws_matching(
  format($$ select public.set_member_field_values(%L, 'profile', '{"nothere": "x"}'::jsonb) $$, pg_temp.member('plain')),
  'is not a question asked here',
  'an answer to a question this space does not ask has nowhere to go');

select lives_ok(
  format($$ select public.set_member_field_values(%L, 'profile', '{"committee": "tresorier"}'::jsonb) $$, pg_temp.member('plain')),
  'a member answers their own question');

select is(
  (select v.text_value from public.workspace_field_values v
    where v.member_id = pg_temp.member('plain')
      and v.definition_id = pg_temp.field('committee')),
  'tresorier',
  'the answer is stored in the column its type names, not in a bag of '
  'json nobody can query');

select throws_matching(
  format($$ select public.set_member_field_values(%L, 'profile', '{"committee": ""}'::jsonb) $$, pg_temp.member('plain')),
  'must be answered',
  'a required question cannot be emptied by saving a blank');

select throws_matching(
  format($$ select public.set_member_field_values(%L, 'profile', '{"committee": "president"}'::jsonb) $$, pg_temp.member('owner')),
  'only the member, or whoever may see personal data',
  'answering FOR somebody else needs the permission that already '
  'governs their personal data');

-- ── who may read it is the definition's business ─────────────────────

select is(
  public.member_field_readable(pg_temp.member('plain'), pg_temp.field('committee')),
  true,
  'your own answer is yours to read, whatever the visibility says');

select pg_temp.act_as('other');
select is(
  public.member_field_readable(pg_temp.member('plain'), pg_temp.field('committee')),
  false,
  'another member does not read a `managers` answer — the policy on the '
  'values table asks this function, so this IS the policy');

select pg_temp.act_as('owner');
select is(
  public.member_field_readable(pg_temp.member('plain'), pg_temp.field('committee')),
  true,
  'somebody who may see personal data reads it, proven beside the '
  'refusal above rather than on its own');

-- ── evolution is a decision, never a silent reinterpretation ─────────

select throws_matching(
  format($$ select public.set_workspace_field(%L, 'committee', 'integer', '{"en":"Role"}'::jsonb) $$, pg_temp.ws()),
  'cannot change while it has answers',
  'a type change under existing answers would reinterpret them; #1288 '
  'calls that a conflict, and a conflict is something a person decides');

-- ── erasure reaches the answers, and stops there (0249) ──────────────

select pg_temp.act_as('owner');
select public.set_workspace_field(pg_temp.ws(), 'shirt', 'text',
  '{"en": "Shirt size"}'::jsonb, false, false, 'members');

select pg_temp.act_as('plain');
select lives_ok(
  format($$ select public.set_member_field_values(%L, 'profile', '{"committee": "tresorier", "shirt": "M"}'::jsonb) $$, pg_temp.member('plain')),
  'the member answers a personal question and a non-personal one');

select lives_ok(
  format($$ select public.erase_my_membership(%L) $$, pg_temp.ws()),
  'and then leaves');

select is(
  (select count(*)::int from public.workspace_field_values v
     join public.workspace_field_definitions d on d.id = v.definition_id
    where v.member_id = pg_temp.member('plain') and d.personal_data),
  0,
  'the answers to the PERSONAL questions are gone — erasure is erasure');

select is(
  (select v.text_value from public.workspace_field_values v
     join public.workspace_field_definitions d on d.id = v.definition_id
    where v.member_id = pg_temp.member('plain') and not d.personal_data),
  'M',
  'and the one the owner marked NOT personal stays: a size for the '
  'association''s next order is the space''s operational data, not a '
  'fact about a person. Deleting everything would be simpler and would '
  'throw that away; deleting nothing would be a broken promise');

-- ── the questions travel; the answers never do (0250) ────────────────

-- The owner again: the member erased their membership above, and
-- exporting a configuration is the owner's in any case.
select pg_temp.act_as('owner');

select is(
  (select e->>'merge_policy' || '/' || (e->>'group')
     from jsonb_array_elements(public.deployable_entities()) e
    where e->>'key' = 'field_definitions'),
  'keyed_update/forms',
  'the questions are a deployable entity, keyed on the question''s own '
  'key so a redeployment updates rather than duplicates');

select is(
  (select jsonb_array_length(
      public.export_workspace_configuration(pg_temp.ws())
        #> '{tables,workspace_field_definitions}') > 0),
  true,
  'and they are in what a template actually carries, not only in the '
  'helper that builds them');

select is(
  (select count(*)::int
     from jsonb_array_elements(
       public.export_workspace_configuration(pg_temp.ws())
         #> '{tables,workspace_field_definitions}') e
    where e.value ? 'answer' or e.value ? 'values'),
  0,
  'an ANSWER never travels: it is a fact about a person, and the person '
  'does not exist in the space the template is applied to');

select ok(
  not has_table_privilege('authenticated', 'public.workspace_field_values', 'INSERT')
  and not has_table_privilege('authenticated', 'public.workspace_field_definitions', 'INSERT'),
  'neither a definition nor an answer takes a write from a signed-in '
  'client: both arrive through a definer that validated them');

-- ── #1532: the question and its choices are one save ─────────────────
--
-- Two calls meant a refused choice arrived after the definition had
-- already landed, and the screen said "The question was not saved."

select pg_temp.act_as('owner');

select throws_matching(
  format($$ select public.save_workspace_field(%L, 'shirt', 'single_choice',
    '{"en":"Shirt"}'::jsonb, false, true, 'self', array['profile'], 'general',
    0, '{}'::jsonb, true, '[{"key":"NOT A KEY","labels":{"en":"L"}}]'::jsonb) $$,
    pg_temp.ws()),
  'a choice key is lower-case letters',
  'a malformed choice is refused, exactly as set_workspace_field_options '
  'refuses it — the composite adds no authority and removes no rule');

select is(
  (select count(*)::int from public.workspace_field_definitions
    where workspace_id = pg_temp.ws() and key = 'shirt'),
  0,
  'and the question does not exist afterwards. One transaction: the '
  'definition goes back with the choices that were refused, instead of '
  'sitting there live with none while the owner is told nothing saved');

select public.save_workspace_field(pg_temp.ws(), 'diet', 'single_choice',
  '{"en":"Diet"}'::jsonb, false, true, 'self', array['profile'], 'general',
  0, '{}'::jsonb, true,
  '[{"key":"vegan","labels":{"en":"Vegan"}},
    {"key":"other","labels":{"en":"Other"}}]'::jsonb);

select is(
  (select count(*)::int from public.workspace_field_options o
     join public.workspace_field_definitions d on d.id = o.definition_id
    where d.workspace_id = pg_temp.ws() and d.key = 'diet'),
  2,
  'and the happy path writes the question and both its choices in that '
  'same one call');

select * from finish();
rollback;
