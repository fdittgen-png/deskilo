-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1656 group 4: invitation texts publish only on explicit opt-in, and
-- a text that still names the space refuses the save.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000279a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'w1656@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000279a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace('Atelier Nord', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set invitation_templates = '{"fr":"Bienvenue chez Atelier Nord, {firstName}"}' where id = current_setting('t.ws')::uuid;
set local role authenticated;

select throws_ok(format($$select public.save_workspace_as_template(%L, 'w_named', 'Named', '', 'private', '{}', array['wording','invitation_texts'])$$,
  current_setting('t.ws')), 'P0001', null, 'a text naming the space refuses the save');

reset role;
update public.workspaces set invitation_templates = '{"fr":"Bienvenue chez {workspaceName}, {firstName}"}' where id = current_setting('t.ws')::uuid;
set local role authenticated;
select public.save_workspace_as_template(current_setting('t.ws')::uuid, 'w_clean', 'Clean', '', 'private', '{}', array['wording','invitation_texts']);
select public.save_workspace_as_template(current_setting('t.ws')::uuid, 'w_noopt', 'No opt-in', '', 'private', '{}', array['wording']);
select public.save_workspace_as_template(current_setting('t.ws')::uuid, 'w_all', 'All', '', 'private', '{}', null);
reset role;

select is((select configuration->'workspace'->'invitation_templates' from public.workspace_templates
            where key = 'w_clean' and owner_workspace_id = current_setting('t.ws')::uuid),
  '{"fr": "Bienvenue chez {workspaceName}, {firstName}"}'::jsonb, 'a placeholder text travels on opt-in');
select ok(not coalesce((select configuration->'workspace' ? 'invitation_templates' from public.workspace_templates
            where key = 'w_noopt' and owner_workspace_id = current_setting('t.ws')::uuid), false),
  'the wording group alone does not carry it');
select ok(not coalesce((select configuration->'workspace' ? 'invitation_templates' from public.workspace_templates
            where key = 'w_all' and owner_workspace_id = current_setting('t.ws')::uuid), false),
  'publishing everything does not imply it');

select * from finish();
rollback;
