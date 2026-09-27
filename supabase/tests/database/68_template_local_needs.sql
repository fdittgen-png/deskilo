-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1656 group 5: a template names the local setup its features need; a
-- space lists what it still lacks, to those who configure it only.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000280a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 's1656@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000280a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 's1656m@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000280a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace('Needs', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}') || '{"invoicing":true,"onlinePayments":true}'
 where id = current_setting('t.ws')::uuid;
insert into public.members (workspace_id, user_id, status) values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000000280a2', 'active');
insert into public.workspace_templates (key, name, visibility, owner_workspace_id, configuration, entities)
values ('needs_tpl', 'Needs', 'private', current_setting('t.ws')::uuid,
        '{"workspace":{"feature_flags":{"invoicing":true,"onlinePayments":false,"multiSite":true}}}', '{features}');
set local role authenticated;
select set_config('t.needs', public.template_local_needs((select id from public.workspace_templates where key = 'needs_tpl'))::text, true);
select set_config('t.before', public.workspace_local_readiness(current_setting('t.ws')::uuid)::text, true);
reset role;
update public.workspaces set legal_id = 'FR123', street = '1 rue' where id = current_setting('t.ws')::uuid;
set local role authenticated;
select set_config('t.after', public.workspace_local_readiness(current_setting('t.ws')::uuid)::text, true);

select is((select jsonb_agg(x->>'slot') from jsonb_array_elements(current_setting('t.needs')::jsonb) x),
  '["legal_identity", "payment_details", "site"]'::jsonb, 'a template names what its features need');
select is((select x->'filled' from jsonb_array_elements(current_setting('t.before')::jsonb) x where x->>'slot' = 'legal_identity'),
  'false'::jsonb, 'a space without a legal identity lacks it');
select is((select x->'filled' from jsonb_array_elements(current_setting('t.after')::jsonb) x where x->>'slot' = 'legal_identity'),
  'true'::jsonb, 'and has it once filled');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000280a2","role":"authenticated"}', true);
select throws_ok(format($$select public.workspace_local_readiness(%L)$$, current_setting('t.ws')), 'P0001', null,
  'a member who does not configure the space is refused');

select * from finish();
rollback;
