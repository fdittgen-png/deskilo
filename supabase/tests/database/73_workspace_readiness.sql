-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0285: workspace_readiness reads a space's setup, section by section,
-- for whoever configures it, and refuses everyone else.
begin;
select plan(7);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000285a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rd@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000285a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rx@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000285a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c285', 'Readiness test', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
select set_config('t.r', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select set_config('t.local', public.workspace_local_readiness(current_setting('t.ws')::uuid)::text, true);
reset role;

select is((select string_agg(e->>'section', ',' order by o) from jsonb_array_elements(current_setting('t.r')::jsonb) with ordinality x(e, o) where o <= 7),
  'region_rules,resources,pricing,invitations,payments,roles_validation,recovery', 'seven sections in the order a space is set up (0295 adds roles and validation)');
-- 0399 (#2332): what members may do follows, always required — a new
-- space grants plain members nothing, so nobody but its staff can book.
select is((select e->>'section' || ':' || (e->>'required') || ':' || (e->>'reason') from jsonb_array_elements(current_setting('t.r')::jsonb) with ordinality x(e, o) where o = 8),
  'member_permissions:true:members_cannot_book', 'members cannot book until the owner grants it');
-- 0287: the local setup the switched-on features need, as one more
-- section, never blocking a first booking.
select is((select coalesce(bool_or((e->>'required')::boolean), false) from jsonb_array_elements(current_setting('t.r')::jsonb) e where e->>'section' = 'local_setup'),
  false, 'and never blocks a first booking');
select is((select e->>'state' from jsonb_array_elements(current_setting('t.r')::jsonb) e where e->>'section' = 'recovery'),
  'unverified', 'recovery is never claimed without evidence');
select is((select string_agg(e->>'section', ',') from jsonb_array_elements(current_setting('t.r')::jsonb) e where (e->>'required')::boolean),
  'region_rules,resources,member_permissions'
    || case when public.feature_effective(current_setting('t.ws')::uuid, 'invoicing') then ',legal_identity' else '' end,
  'rules, places, members'' permissions and — under invoicing — the legal identity are required, while no policy is short');
select is((select e->>'state' from jsonb_array_elements(current_setting('t.r')::jsonb) e where e->>'section' = 'invitations'),
  'needs_configuration', 'a space of one has invited nobody yet');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000285a2","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.workspace_readiness(%L)', current_setting('t.ws')),
  'only someone who configures this workspace sees how ready it is');
reset role;

select * from finish();
rollback;
