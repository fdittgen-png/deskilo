-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1658: a template applies at the revision the owner reviewed, once; a
-- moved template changes nothing; a reused request id conflicts.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000282a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x1658@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000282a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace('Exact', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.tiny', (select id::text from public.workspace_templates where key = 'tiny' and owner_workspace_id is null), true);
select set_config('t.v', (select template_version::text from public.workspace_templates where id = current_setting('t.tiny')::uuid), true);

select is(public.apply_workspace_template_exact(current_setting('t.ws')::uuid, current_setting('t.tiny')::uuid, null,
  current_setting('t.v')::int + 1, '00000000-0000-4000-8000-00000000b001')->>'status', 'stale',
  'a revision other than the reviewed one applies nothing');
select is(public.apply_workspace_template_exact(current_setting('t.ws')::uuid, current_setting('t.tiny')::uuid, null,
  current_setting('t.v')::int, '00000000-0000-4000-8000-00000000b002')->>'status', 'applied', 'the reviewed revision applies');
select is(public.apply_workspace_template_exact(current_setting('t.ws')::uuid, current_setting('t.tiny')::uuid, null,
  current_setting('t.v')::int, '00000000-0000-4000-8000-00000000b002')->>'status', 'replayed', 'a retry replays');
select is(public.apply_workspace_template_exact(current_setting('t.ws')::uuid, current_setting('t.tiny')::uuid, array['space'],
  current_setting('t.v')::int, '00000000-0000-4000-8000-00000000b002')->>'status', 'conflict', 'the same id with other groups conflicts');
reset role;
select is((select count(*)::int from public.workspace_template_applications where workspace_id = current_setting('t.ws')::uuid),
  1, 'applied once, however often it was asked');
select ok((select result is not null from public.workspace_template_applications where workspace_id = current_setting('t.ws')::uuid),
  'the result is recorded with its request');

select * from finish();
rollback;
