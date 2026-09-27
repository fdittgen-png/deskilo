-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0284: a space created as a dev + prod pair from a template gets the
-- template on both sides and stays shown as one space.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000284a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tw@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000284a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c001', 'Twin test', 'FR', 'EUR', 'Europe/Paris', 'dev', true, null,
  (select id from public.workspace_templates where key = 'tiny' and owner_workspace_id is null))::text, true);
reset role;
select set_config('t.pair', (select pair_id::text from public.workspaces where id = current_setting('t.ws')::uuid), true);

select is((select count(*)::int from public.workspaces where pair_id = current_setting('t.pair')::uuid), 2, 'a pair');
select ok((select bool_and((select count(*) from public.levels l where l.workspace_id = w.id) > 0)
             from public.workspaces w where w.pair_id = current_setting('t.pair')::uuid),
  'both sides got the template''s plan');
select is((select count(distinct (select count(*) from public.seats s where s.workspace_id = w.id))::int
             from public.workspaces w where w.pair_id = current_setting('t.pair')::uuid), 1,
  'the same plan on both sides');
select ok((select bool_and((feature_flags->>'environmentPairs')::boolean)
             from public.workspaces where pair_id = current_setting('t.pair')::uuid),
  'both sides say they are a pair, so it is shown as one space');

select * from finish();
rollback;
