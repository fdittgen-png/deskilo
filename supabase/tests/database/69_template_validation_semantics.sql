-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1657: a validation policy keeps its meaning when it travels: the
-- threshold travels; a named-validator restriction travels as a flag,
-- never as identities, and is never written open on the target.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000281a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'v1657@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000281a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.src', public.create_workspace('Val src', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.dst', public.create_workspace('Val dst', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.validation_policies (workspace_id, event_type, required_count, validator_scope, eligible_admin_ids, min_amount_cents)
values (current_setting('t.src')::uuid, 'expense', 1, 'listed',
        array[(select id from public.members where workspace_id = current_setting('t.src')::uuid limit 1)], 5000),
       (current_setting('t.src')::uuid, 'payment', 2, 'admins', '{}', 1000)
on conflict on constraint validation_policies_workspace_id_event_type_key do update
  set required_count = excluded.required_count, validator_scope = excluded.validator_scope,
      eligible_admin_ids = excluded.eligible_admin_ids, min_amount_cents = excluded.min_amount_cents;
insert into public.validation_policies (workspace_id, event_type, required_count, validator_scope, min_amount_cents)
values (current_setting('t.dst')::uuid, 'expense', 3, 'admins', 7)
on conflict on constraint validation_policies_workspace_id_event_type_key do update
  set required_count = 3, validator_scope = 'admins', min_amount_cents = 7;
set local role authenticated;
select set_config('t.tpl', public.save_workspace_as_template(current_setting('t.src')::uuid, 'val_src', 'Val src')::text, true);
select set_config('t.res', public.apply_workspace_template(current_setting('t.dst')::uuid, current_setting('t.tpl')::uuid, null)::text, true);
select set_config('t.needs', public.template_local_needs(current_setting('t.tpl')::uuid)::text, true);
reset role;

select ok((select configuration::text not like '%eligible_admin_ids%' from public.workspace_templates where id = current_setting('t.tpl')::uuid),
  'no validator identity is published');
select is((select e->'named_validators' from public.workspace_templates t, jsonb_array_elements(t.configuration->'tables'->'validation_policies') e
            where t.id = current_setting('t.tpl')::uuid and e->>'event_type' = 'expense'), 'true'::jsonb,
  'the restriction travels as a flag');
select is(current_setting('t.res')::jsonb->'validation_blocked', '["expense"]'::jsonb, 'apply names what is left for local choice');
select is((select required_count || '/' || validator_scope || '/' || min_amount_cents from public.validation_policies
            where workspace_id = current_setting('t.dst')::uuid and event_type = 'expense'),
  '3/admins/7', 'the target keeps its own expense policy: never opened to everyone');
select is((select min_amount_cents from public.validation_policies
            where workspace_id = current_setting('t.dst')::uuid and event_type = 'payment'),
  1000, 'the threshold travels');
select ok(exists (select 1 from jsonb_array_elements(current_setting('t.needs')::jsonb) x
                   where x->>'slot' = 'named_validators' and x->>'event_type' = 'expense'),
  'the template names the validators to choose locally');

select * from finish();
rollback;
