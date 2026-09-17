-- SPDX-License-Identifier: 0BSD
--
-- #1276 S3 — one change-set, and a merge that really never deletes.
--
-- A full template applied over a workspace that already runs used to fail
-- on the first shared closure day or seeded fee band, and a desk whose
-- name matched lost its price. This file applies EVERYTHING a template
-- carries over a populated target and asserts what survives, that the
-- second preview is all `matching`, that mirror (deployment) still
-- deletes, and that compatibility and authorization hold for the preview
-- as they do for the apply.
begin;
select plan(14);

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
values ('00000000-0000-4000-8000-0000000012d1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'change-set-owner@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-0000000012d2', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'change-set-stranger@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000000012d1');
select set_config('deskilo.cs.src',
  public.create_workspace('Source', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('deskilo.cs.dst',
  public.create_workspace('Target', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('deskilo.cs.src')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));
select public.apply_workspace_template(current_setting('deskilo.cs.dst')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));

reset role;
-- The source: its own schedule, a holiday, a stricter policy, a default rate.
delete from public.fee_bands where workspace_id = current_setting('deskilo.cs.src')::uuid;
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (current_setting('deskilo.cs.src')::uuid, 0, 60, 500, 0),
       (current_setting('deskilo.cs.src')::uuid, 60, 100, 900, 0);
insert into public.closure_days (workspace_id, day, reason)
values (current_setting('deskilo.cs.src')::uuid, '2033-12-25', 'Noël'),
       (current_setting('deskilo.cs.src')::uuid, '2033-01-01', '');
insert into public.validation_policies (workspace_id, event_type, required_count)
values (current_setting('deskilo.cs.src')::uuid, 'reservation_delete', 2);
insert into public.vat_rates (workspace_id, label, percent, category, is_default, group_key)
values (current_setting('deskilo.cs.src')::uuid, 'Normal 20 %', 20, 'S', true, 'standard');
-- The target already runs: priced desks, its own Christmas, its own default.
update public.desks set price_cents = 4200 where workspace_id = current_setting('deskilo.cs.dst')::uuid;
insert into public.closure_days (workspace_id, day, reason)
values (current_setting('deskilo.cs.dst')::uuid, '2033-12-25', 'Christmas');
insert into public.validation_policies (workspace_id, event_type, required_count)
values (current_setting('deskilo.cs.dst')::uuid, 'reservation_delete', 1);
insert into public.vat_rates (workspace_id, label, percent, category, is_default, group_key)
values (current_setting('deskilo.cs.dst')::uuid, 'Taux normal', 20, 'S', true, 'standard');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012d1');
select set_config('deskilo.cs.tpl', public.save_workspace_as_template(
  current_setting('deskilo.cs.src')::uuid, 'everything', 'Everything')::text, true);
select set_config('deskilo.cs.preview1', public.preview_workspace_template(
  current_setting('deskilo.cs.dst')::uuid, current_setting('deskilo.cs.tpl')::uuid)::text, true);

select is(
  (select g->>'state' from jsonb_array_elements(current_setting('deskilo.cs.preview1')::jsonb->'groups') g
    where g->>'group' = 'pricing_credits'),
  'needs_attention',
  'a different fee schedule on the target is flagged before it is replaced');

select lives_ok(
  $$ select public.apply_workspace_template(
       current_setting('deskilo.cs.dst')::uuid, current_setting('deskilo.cs.tpl')::uuid) $$,
  'everything the template carries applies over a populated workspace');

reset role;
select ok(
  (select bool_and(price_cents = 4200) from public.desks
    where workspace_id = current_setting('deskilo.cs.dst')::uuid),
  'desks whose names matched keep their prices');
select is(
  (select reason from public.closure_days
    where workspace_id = current_setting('deskilo.cs.dst')::uuid and day = '2033-12-25'),
  'Christmas',
  'a closure day the target already had is left as it was');
select is(
  (select count(*)::int from public.closure_days
    where workspace_id = current_setting('deskilo.cs.dst')::uuid and day = '2033-01-01'),
  1,
  'a closure day the target lacked is added');
select is(
  (select required_count from public.validation_policies
    where workspace_id = current_setting('deskilo.cs.dst')::uuid and event_type = 'reservation_delete'),
  2,
  'a validation policy is updated by its event type');
select is(
  (select array_agg(label) from public.vat_rates
    where workspace_id = current_setting('deskilo.cs.dst')::uuid and is_default),
  array['Taux normal'],
  'the target keeps its own default VAT rate');
select is(
  (select array_agg(from_pct || '-' || to_pct || ':' || fee_cents order by from_pct) from public.fee_bands
    where workspace_id = current_setting('deskilo.cs.dst')::uuid),
  array['0-60:500', '60-100:900'],
  'a fee schedule is replaced whole, never interleaved');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012d1');
select is(
  (select count(*)::int from jsonb_array_elements(public.preview_workspace_template(
     current_setting('deskilo.cs.dst')::uuid, current_setting('deskilo.cs.tpl')::uuid)->'groups') g
    where g->>'state' <> 'matching'),
  0,
  'once applied, the same template previews as matching in every group');

select lives_ok(
  $$ select public.import_workspace_configuration(
       current_setting('deskilo.cs.dst')::uuid, '{"tables":{"closure_days":[]}}'::jsonb) $$,
  'the import without a mode is still the mirror');
reset role;
select is(
  (select count(*)::int from public.closure_days
    where workspace_id = current_setting('deskilo.cs.dst')::uuid),
  0,
  'mirror still removes what the payload does not name');

update public.workspace_templates set entities = entities || '{from_the_future}'::text[]
 where id = current_setting('deskilo.cs.tpl')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000012d1');
select is(
  array[public.preview_workspace_template(current_setting('deskilo.cs.dst')::uuid,
          current_setting('deskilo.cs.tpl')::uuid)->>'compatibility',
        public.preview_workspace_template(current_setting('deskilo.cs.dst')::uuid,
          current_setting('deskilo.cs.tpl')::uuid, array['hours_booking'])->>'compatibility'],
  array['not_supported', 'partial'],
  'an unknown entity is not supported, and partial only when groups exclude it');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012d2');
select throws_like(
  $$ select public.preview_workspace_template(
       current_setting('deskilo.cs.dst')::uuid,
       (select id from public.workspace_templates where key = 'tiny')) $$,
  'only someone who configures%',
  'a stranger to the target cannot preview a template on it');

reset role;
select ok(
  not has_function_privilege('authenticated',
    'public.configuration_change_set(uuid,jsonb,text[],text)', 'execute'),
  'the comparison itself authorizes nothing and is not callable by clients');

select * from finish();
rollback;
