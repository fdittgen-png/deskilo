-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1303 S3 — before a workspace exists, a template says what it sets up,
-- and a template this server cannot apply says so before anyone presses
-- Create.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000001391', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'outline-newcomer@deskilo.test', '', now(), now(), now());

-- A newcomer: signed in, no workspace yet.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-000000001391', 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000001391', true);

select is(
  public.template_outline((select id from public.workspace_templates where key = 'tiny'))->>'compatibility',
  'supported',
  'a builtin template is supported for someone with no workspace');

select ok(
  public.template_outline((select id from public.workspace_templates where key = 'tiny'))->'groups'
    @> '[{"group": "space"}]'::jsonb,
  'the plan is named under its group');

select throws_ok(
  $$ select public.template_outline(gen_random_uuid()) $$,
  'unknown template',
  'an id nobody may read is unknown');

update public.workspace_templates set entities = entities || '{no_such_entity}' where key = 'tiny';

select is(
  public.template_outline((select id from public.workspace_templates where key = 'tiny'))->>'compatibility',
  'not_supported',
  'an entity this server lacks is refused in the outline, as the apply refuses it');

select is(
  jsonb_array_length(public.template_outline((select id from public.workspace_templates where key = 'tiny'))->'groups'),
  0,
  'a refused template promises no groups');

select ok(
  not has_function_privilege('anon', 'public.template_outline(uuid)', 'execute'),
  'anon cannot ask');

select * from finish();
rollback;
