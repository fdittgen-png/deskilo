-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1656 group 2: floor-plan prices travel beside the stripped plan in
-- their currency, land only in a workspace with that currency, and a
-- different currency leaves every target price untouched.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000278a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p1656@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000278a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.src', public.create_workspace('Priced src', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.eur', public.create_workspace('Priced eur', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.chf', public.create_workspace('Priced chf', 'CH', 'CHF', 'Europe/Zurich', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.src')::uuid,
  (select id from public.workspace_templates where key = 'tiny' and owner_workspace_id is null), null);
reset role;
update public.levels set price_cents = 5000 where workspace_id = current_setting('t.src')::uuid;
update public.offices set price_cents = 2500 where workspace_id = current_setting('t.src')::uuid;
update public.desks set price_cents = 900 where workspace_id = current_setting('t.src')::uuid;
set local role authenticated;
select set_config('t.tpl', public.save_workspace_as_template(current_setting('t.src')::uuid, 'priced_src', 'Priced src')::text, true);
select set_config('t.r_eur', public.apply_workspace_template(current_setting('t.eur')::uuid, current_setting('t.tpl')::uuid, null)::text, true);
select set_config('t.r_chf', public.apply_workspace_template(current_setting('t.chf')::uuid, current_setting('t.tpl')::uuid, null)::text, true);
reset role;

select ok((select floor_plan::text not like '%price_cents%' from public.workspace_templates where id = current_setting('t.tpl')::uuid),
  'the published plan itself still carries no price');
select is((select plan_prices->>'currency' from public.workspace_templates where id = current_setting('t.tpl')::uuid),
  'EUR', 'the prices travel with their currency');
select is(current_setting('t.r_eur')::jsonb->>'prices', 'applied', 'the same currency: applied');
select is((select array[(select max(price_cents) from public.levels where workspace_id = current_setting('t.eur')::uuid),
                        (select max(price_cents) from public.offices where workspace_id = current_setting('t.eur')::uuid),
                        (select max(price_cents) from public.desks where workspace_id = current_setting('t.eur')::uuid)]),
  array[5000, 2500, 900], 'level, office and desk prices land');
select is(current_setting('t.r_chf')::jsonb->>'prices', 'currency_mismatch', 'another currency: said, not relabelled');
select is((select array[(select max(price_cents) from public.levels where workspace_id = current_setting('t.chf')::uuid),
                        (select max(price_cents) from public.offices where workspace_id = current_setting('t.chf')::uuid),
                        (select max(price_cents) from public.desks where workspace_id = current_setting('t.chf')::uuid)]),
  array[0, 0, 0], 'and no target price moved');

select * from finish();
rollback;
