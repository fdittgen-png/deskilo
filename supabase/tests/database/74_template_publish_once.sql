-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0286: a template is published once per request: a retry replays, a
-- reused request id with another form conflicts, a non-owner is refused.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000286a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'po@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000286a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'px@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000286a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c286', 'Publish test', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
select set_config('t.r1', public.save_workspace_as_template_once(current_setting('t.ws')::uuid, 'once_test', 'Once', '', 'private', '{}', null, '00000000-0000-4000-8000-0000000286f1')::text, true);
select set_config('t.r2', public.save_workspace_as_template_once(current_setting('t.ws')::uuid, 'once_test', 'Once', '', 'private', '{}', null, '00000000-0000-4000-8000-0000000286f1')::text, true);
select set_config('t.r3', public.save_workspace_as_template_once(current_setting('t.ws')::uuid, 'once_test', 'Once again', '', 'private', '{}', null, '00000000-0000-4000-8000-0000000286f1')::text, true);
reset role;

select is(current_setting('t.r1')::jsonb->>'status', 'published', 'the first request publishes');
select is(current_setting('t.r2')::jsonb->>'status', 'replayed', 'the same request again is a retry');
select is(current_setting('t.r2')::jsonb->>'template_id', current_setting('t.r1')::jsonb->>'template_id', 'and answers the same template');
select is((select template_version from public.workspace_templates
            where id = (current_setting('t.r1')::jsonb->>'template_id')::uuid), 1,
  'published once: the version did not move');
select is(current_setting('t.r3')::jsonb->>'status', 'conflict', 'the same request with another form conflicts');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000286a2","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format($$select public.save_workspace_as_template_once(%L, 'x_test', 'X', '', 'private', '{}', null, gen_random_uuid())$$, current_setting('t.ws')),
  'only an owner publishes a template from a workspace');
reset role;

select * from finish();
rollback;
