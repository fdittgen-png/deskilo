-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1276 S2 — a template carries configuration, published through an
-- allow-list, applied as a merge, and it remembers being applied.
--
-- The four promises 0229 makes, each one a way a template could hurt:
--   * publication strips what is the source's own (identifiers, bank
--     details, addresses) SERVER-SIDE, and every deployable entity is
--     classified — a new entity is unpublishable until somebody decides;
--   * applying never deletes: fee bands and closure days the target had
--     are still there after a merge;
--   * a snapshot this server does not understand is refused, not guessed;
--   * only someone who configures the target applies, and it is recorded.
begin;
select plan(13);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000012c1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'template-owner@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-0000000012c2', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'template-stranger@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000000012c1');
select set_config('deskilo.tpl.src',
  public.create_workspace('Source', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('deskilo.tpl.dst',
  public.create_workspace('Target', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);

-- What the source must never publish, and what the target already holds.
reset role;
update public.workspaces
   set vat_id = 'FR99TEMPLATE', legal_id = '987654321', street = '1 rue du secret',
       payment_instructions = '{"iban":"FR76TEMPLATESECRET"}',
       booking_rules = '{"granularity":"half_day"}'
 where id = current_setting('deskilo.tpl.src')::uuid;
insert into public.sites (workspace_id, name, street)
values (current_setting('deskilo.tpl.src')::uuid, 'Head office', '9 rue privée');
delete from public.fee_bands where workspace_id = current_setting('deskilo.tpl.dst')::uuid;
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents)
values (current_setting('deskilo.tpl.dst')::uuid, 0, 50, 1000),
       (current_setting('deskilo.tpl.dst')::uuid, 50, 100, 2000);
insert into public.closure_days (workspace_id, day)
values (current_setting('deskilo.tpl.dst')::uuid, '2031-01-01');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012c1');
select set_config('deskilo.tpl.id', public.save_workspace_as_template(
  current_setting('deskilo.tpl.src')::uuid, 'rules_only', 'Rules only')::text, true);

reset role;
select is(
  (select configuration::text ~* 'FR99TEMPLATE|987654321|secret|privée'
     from public.workspace_templates where id = current_setting('deskilo.tpl.id')::uuid),
  false,
  'no identifier, address or bank detail reaches the stored snapshot');
select ok(
  not (select entities && array['sites', 'payment_instructions', 'invitations',
                                 'document_links', 'document_design']
         from public.workspace_templates where id = current_setting('deskilo.tpl.id')::uuid),
  'denied entities are not carried');
select is(
  (select count(*)::int from jsonb_array_elements(public.deployable_entities()) e
    where not public.template_publication_rules() ? (e.value->>'key')),
  0,
  'every deployable entity is classified for publication');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012c1');
select public.save_workspace_as_template(
  current_setting('deskilo.tpl.src')::uuid, 'rules_only', 'Rules only');
reset role;
select is(
  (select template_version from public.workspace_templates
    where id = current_setting('deskilo.tpl.id')::uuid),
  2,
  'publishing over the same key bumps the version in place');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012c1');
select lives_ok(
  $$ select public.apply_workspace_template(
       current_setting('deskilo.tpl.dst')::uuid,
       current_setting('deskilo.tpl.id')::uuid, array['hours_booking']) $$,
  'the owner applies the hours group');

reset role;
select is(
  (select count(*)::int from public.fee_bands
    where workspace_id = current_setting('deskilo.tpl.dst')::uuid),
  2,
  'the target''s fee bands survive the merge');
select is(
  (select count(*)::int from public.closure_days
    where workspace_id = current_setting('deskilo.tpl.dst')::uuid
      and day = '2031-01-01'),
  1,
  'the target''s closure day survives the merge');
select is(
  (select booking_rules->>'granularity' from public.workspaces
    where id = current_setting('deskilo.tpl.dst')::uuid),
  'half_day',
  'the chosen group was applied');
select is(
  (select entities from public.workspace_template_applications
    where workspace_id = current_setting('deskilo.tpl.dst')::uuid),
  array['booking_rules'],
  'the application is recorded with exactly what it applied');

update public.workspace_templates set schema_version = 999
 where id = current_setting('deskilo.tpl.id')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000012c1');
select throws_like(
  $$ select public.apply_workspace_template(
       current_setting('deskilo.tpl.dst')::uuid, current_setting('deskilo.tpl.id')::uuid) $$,
  'not supported:%',
  'a snapshot format this server does not know is refused');

reset role;
update public.workspace_templates
   set schema_version = 1, entities = entities || '{from_the_future}'::text[]
 where id = current_setting('deskilo.tpl.id')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000012c1');
select throws_like(
  $$ select public.apply_workspace_template(
       current_setting('deskilo.tpl.dst')::uuid, current_setting('deskilo.tpl.id')::uuid) $$,
  '%no entity from_the_future%',
  'an entity this server does not know fails the whole application closed');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012c2');
select throws_like(
  $$ select public.apply_workspace_template(
       current_setting('deskilo.tpl.dst')::uuid,
       (select id from public.workspace_templates where key = 'tiny')) $$,
  'only someone who configures%',
  'a stranger to the target cannot apply a template to it');

reset role;
select ok(
  not has_function_privilege('anon', 'public.apply_workspace_template(uuid,uuid,text[])', 'execute'),
  'anon cannot apply a template');

select * from finish();
rollback;
