-- SPDX-License-Identifier: 0BSD
--
-- #1280 S3 — a template publishes the groups its owner chose, and the
-- owner is shown what never travels and which names go with the plan.
begin;
select plan(7);

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
values ('00000000-0000-4000-8000-0000000012e1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'publish-owner@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-0000000012e2', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'publish-stranger@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000000012e1');
select set_config('deskilo.pub.ws',
  public.create_workspace('Publisher', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('deskilo.pub.ws')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));
select set_config('deskilo.pub.all',
  public.template_publication_preview(current_setting('deskilo.pub.ws')::uuid)::text, true);

select ok(
  exists (select 1 from jsonb_array_elements(current_setting('deskilo.pub.all')::jsonb->'never_published') n
           where n.value->>'entity' = 'payment_instructions' and n.value->>'reason' <> ''),
  'bank details are listed as never published, with a reason');
select cmp_ok(
  jsonb_array_length(current_setting('deskilo.pub.all')::jsonb->'plan_names'), '>', 0,
  'the plan names that will be published are shown');
select is(
  (select jsonb_agg(p.value->>'entity')
     from jsonb_array_elements(public.template_publication_preview(
       current_setting('deskilo.pub.ws')::uuid, array['hours_booking'])->'published') p),
  '["booking_rules"]'::jsonb,
  'choosing a group narrows what would be published');

select set_config('deskilo.pub.tpl', public.save_workspace_as_template(
  current_setting('deskilo.pub.ws')::uuid, 'hours_only', 'Hours only', '', 'private', '{}',
  array['hours_booking'])::text, true);
reset role;
select is(
  (select entities from public.workspace_templates where id = current_setting('deskilo.pub.tpl')::uuid),
  array['booking_rules'],
  'the saved template carries exactly the chosen group');
select is(
  (select jsonb_array_length(floor_plan) from public.workspace_templates
    where id = current_setting('deskilo.pub.tpl')::uuid),
  0,
  'a template without the space group carries no plan');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012e1');
-- The group has to be one no entity belongs to, which is the whole
-- point: a chosen group that yields nothing publishable is refused
-- rather than saved as an empty template. `forms` was that group until
-- #1288 put the workspace's own questions in it, so the name moved and
-- the rule did not.
select throws_like(
  $$ select public.save_workspace_as_template(current_setting('deskilo.pub.ws')::uuid,
       'empty_group', 'Nothing', '', 'private', '{}', array['nothing_publishable']) $$,
  '%carry nothing that may be published%',
  'groups with nothing publishable are refused, not saved empty');

select pg_temp.act_as('00000000-0000-4000-8000-0000000012e2');
select throws_like(
  $$ select public.template_publication_preview(current_setting('deskilo.pub.ws')::uuid) $$,
  'only an owner publishes%',
  'only an owner of the workspace may see its publication preview');

select * from finish();
rollback;
