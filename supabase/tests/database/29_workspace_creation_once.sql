-- SPDX-License-Identifier: 0BSD
--
-- #1303 S0 — creating a workspace is one act, and asking twice makes one.
--
-- Onboarding used to create the workspace and then apply its template in
-- two requests. A lost response and a retry made a second workspace — and
-- a second dev/prod pair; a template failing after the workspace existed
-- reported the whole creation as failed. `create_workspace_once` claims the
-- client's request id, creates, and applies the template in ONE
-- transaction: the same id twice gives one workspace and one pair; a
-- template that cannot be applied leaves nothing behind, not even the claim.
begin;
select plan(7);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000013a1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'create-once@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000000013a1');

select lives_ok(
  $$ select set_config('deskilo.once.first', public.create_workspace_once(
       '00000000-0000-4000-8000-0000000013b1', 'Once', 'FR', 'EUR', 'Europe/Paris',
       'dev', true, null,
       (select id from public.workspace_templates where key = 'tiny'))::text, true) $$,
  'the first request creates the workspace with its template');

select is(
  public.create_workspace_once(
    '00000000-0000-4000-8000-0000000013b1', 'Once', 'FR', 'EUR', 'Europe/Paris',
    'dev', true, null, (select id from public.workspace_templates where key = 'tiny')),
  current_setting('deskilo.once.first')::uuid,
  'the same request id returns the same workspace');

reset role;
select is(
  (select count(*)::int from public.workspaces
    where created_by = '00000000-0000-4000-8000-0000000013a1'),
  2,
  'one workspace and its twin — not two pairs');
select cmp_ok(
  (select count(*)::int from public.levels
    where workspace_id = current_setting('deskilo.once.first')::uuid),
  '>', 0,
  'the template was applied, once, in the same act');

select pg_temp.act_as('00000000-0000-4000-8000-0000000013a1');
select throws_ok(
  $$ select public.create_workspace_once(
       '00000000-0000-4000-8000-0000000013b2', 'Broken', 'FR', 'EUR', 'Europe/Paris',
       'dev', true, null, '00000000-0000-4000-8000-0000000013ff') $$,
  null,
  'an unreadable template refuses the creation');
reset role;

-- throws_ok ran the call in a subtransaction that rolled back: what a
-- client sees as a failed request.
select is(
  (select count(*)::int from public.workspaces
    where created_by = '00000000-0000-4000-8000-0000000013a1' and name = 'Broken'),
  0,
  'the failed creation left no workspace');

select pg_temp.act_as('00000000-0000-4000-8000-0000000013a1');
select throws_ok(
  $$ select count(*) from public.workspace_creation_requests $$,
  '42501',
  null,
  'the claim ledger is the server''s own bookkeeping');
reset role;

select * from finish();
rollback;
