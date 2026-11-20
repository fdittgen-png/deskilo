-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0815 (#4223): "Prices and plans" applies only to a business with places. It
-- prices presence (levels, extra half-days, day packs), so a business whose
-- places are off does not have it, and the step that waits on it
-- (payment_methods) is not held back; a business with places keeps its step,
-- one with billing off keeps today's answer, and the catalogue names the second
-- feature on that step alone.
begin;
select plan(9);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-000000004681', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pricing-places@deskilo.test', '', now(), now(), now());

create function pg_temp.step(p_ws uuid, p_step text) returns jsonb language sql as $$
  select s from jsonb_array_elements(public.workspace_setup_status(p_ws) -> 'steps') s where s->>'step' = p_step
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000004681","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.a', public.create_workspace_once('00000000-0000-4000-8000-00000000c681', 'With places', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.b', public.create_workspace_once('00000000-0000-4000-8000-00000000c682', 'Without places', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.c', public.create_workspace_once('00000000-0000-4000-8000-00000000c683', 'Without billing', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"placeBooking": false}'::jsonb
 where id = current_setting('t.b')::uuid;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"moneyTab": false}'::jsonb
 where id = current_setting('t.c')::uuid;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000004681","role":"authenticated"}', true);
set local role authenticated;
select isnt(pg_temp.step(current_setting('t.a')::uuid, 'pricing') ->> 'state', 'not_applicable',
  'a business with places and billing has the pricing step');
select is(pg_temp.step(current_setting('t.b')::uuid, 'pricing') ->> 'state', 'not_applicable',
  'a business whose places are off does not');
select is(pg_temp.step(current_setting('t.c')::uuid, 'pricing') ->> 'state', 'not_applicable',
  'nor one whose billing is off, as before');
select ok(not (pg_temp.step(current_setting('t.b')::uuid, 'payment_methods') -> 'blocked_by') ? 'pricing',
  'the payment methods of a business without places do not wait on prices and plans');
select isnt(pg_temp.step(current_setting('t.b')::uuid, 'payment_methods') ->> 'state', 'not_applicable',
  'and the step stays theirs to do');
select is(pg_temp.step(current_setting('t.a')::uuid, 'places') ->> 'state' is not null, true,
  'the steps for places are unchanged for a business with places');
reset role;

select is((select s ->> 'also_needs' from jsonb_array_elements(public.setup_step_catalogue()) s where s ->> 'id' = 'pricing'),
  'placeBooking', 'the catalogue names the places as the second feature of the pricing step');
select is((select count(*)::int from jsonb_array_elements(public.setup_step_catalogue()) s where s ? 'also_needs'),
  1, 'and of no other step');
select is((select (length(pg_get_functiondef(p.oid)) - length(replace(pg_get_functiondef(p.oid), 'also_needs', ''))) / length('also_needs')
             from pg_proc p where p.proname = 'workspace_setup_status' and p.pronamespace = 'public'::regnamespace),
  2, 'the status function reads the second feature once, in its two places');

select * from finish();
rollback;
