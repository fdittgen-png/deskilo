-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1656 group 1: a template saved from a workspace records where it was
-- made as a suggestion; a builtin records nothing; applying a template
-- never changes a populated workspace's currency, country or timezone.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000277a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'r1656@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000277a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.src', public.create_workspace('Regional src', 'DE', 'EUR', 'Europe/Berlin', 'dev', false, null)::text, true);
select set_config('t.dst', public.create_workspace('Regional dst', 'CH', 'CHF', 'Europe/Zurich', 'dev', false, null)::text, true);
select set_config('t.tpl', public.save_workspace_as_template(current_setting('t.src')::uuid, 'regional_src', 'Regional src')::text, true);
select public.apply_workspace_template(current_setting('t.dst')::uuid, current_setting('t.tpl')::uuid, null);
reset role;

select is((select regional - 'origin' from public.workspace_templates where id = current_setting('t.tpl')::uuid),
  '{"country_code": "DE", "currency_code": "EUR", "timezone": "Europe/Berlin"}'::jsonb,
  'the saved template records where it was made');
select is((select regional->>'origin' from public.workspace_templates where id = current_setting('t.tpl')::uuid),
  'source_workspace', 'and says where the suggestion comes from');
select is((select regional from public.workspace_templates where key = 'tiny' and owner_workspace_id is null),
  '{}'::jsonb, 'a builtin suggests nothing');
select is((select currency_code || '/' || country_code || '/' || timezone from public.workspaces where id = current_setting('t.dst')::uuid),
  'CHF/CH/Europe/Zurich', 'applying a template never changes a populated workspace''s region');

select * from finish();
rollback;
