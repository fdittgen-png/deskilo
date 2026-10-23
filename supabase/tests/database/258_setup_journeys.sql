-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2868 (workspace_setup_journeys): the owner's answers and levels
-- round-trip through the server; each save bumps the version and a retry
-- under the same request id answers the first save again without a second
-- bump; a save against a version that moved raises 40001 ("setup journey
-- changed: …") and leaves the other configurer's answers as they were;
-- answers that are not booleans and levels that are not names are 22023;
-- someone who does not configure the space is refused (42501), and nobody
-- reads the table directly; and saving answers never changes the space's
-- features or its setup status.
begin;
select plan(26);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002868'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@setup-journeys.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
update public.profiles set first_name = 'Ada', last_name = 'Owner' where id = '00000000-0000-4000-8000-0000002868a1';
update public.profiles set first_name = 'Zoe', last_name = 'Second' where id = '00000000-0000-4000-8000-0000002868a3';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules)
values('00000000-0000-4000-8000-0000002868b1','Setup journeys','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002868a1','dev','{"open_weekdays":[1,2,3,4,5]}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002868c1','00000000-0000-4000-8000-0000002868b1','00000000-0000-4000-8000-0000002868a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002868c2','00000000-0000-4000-8000-0000002868b1','00000000-0000-4000-8000-0000002868a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002868c3','00000000-0000-4000-8000-0000002868b1','00000000-0000-4000-8000-0000002868a3',true,true,'active');

create function pg_temp.save(p_answers jsonb, p_levels jsonb, p_expected int, p_request text)
returns jsonb language sql as $$
  select public.save_setup_journey('00000000-0000-4000-8000-0000002868b1', p_answers, p_levels, p_expected, p_request::uuid)
$$;
create function pg_temp.journey() returns jsonb language sql as $$
  select public.get_setup_journey('00000000-0000-4000-8000-0000002868b1')
$$;
create function pg_temp.status() returns jsonb language sql as $$
  select public.workspace_setup_status('00000000-0000-4000-8000-0000002868b1')
$$;
create function pg_temp.as_user(p_suffix text) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000002868' || p_suffix, 'role', 'authenticated')::text, true)
$$;

select pg_temp.as_user('a1');
create temp table before_journeys as
  select pg_temp.status() as status,
         (select feature_flags from public.workspaces where id = '00000000-0000-4000-8000-0000002868b1') as flags;

-- Round trip, version, idempotent retry.
select is(pg_temp.journey(), null, 'no answers saved yet');
select is(pg_temp.save('{"issue_invoices":true,"vat_registered":false}', '{"money":"invoices","tax":"none"}',
  null, '00000000-0000-4000-8000-000000286801')->>'version', '1', 'the first save is version 1');
select is(pg_temp.journey()->'answers', '{"issue_invoices":true,"vat_registered":false}'::jsonb,
  'the answers read back as saved');
select is(pg_temp.journey()->'levels', '{"money":"invoices","tax":"none"}'::jsonb,
  'and so do the levels');
select is(pg_temp.journey()->>'updated_by_name', 'Ada OWNER', 'naming who saved them');
select is(pg_temp.save('{"issue_invoices":true,"vat_registered":false}', '{"money":"invoices","tax":"none"}',
  null, '00000000-0000-4000-8000-000000286801')->>'version', '1',
  'a retry under the same request id answers the same version');
select is((select version from public.workspace_setup_journeys
            where workspace_id = '00000000-0000-4000-8000-0000002868b1'), 1, 'and bumps nothing');
select is(pg_temp.save('{"issue_invoices":true,"vat_registered":true}', '{"money":"invoices","tax":"vat"}',
  1, '00000000-0000-4000-8000-000000286802')->>'version', '2', 'a save against the version read bumps it');
select is(pg_temp.journey()->'levels', '{"money":"invoices","tax":"vat"}'::jsonb, 'and replaces the levels');

-- Another configurer's stale save is refused and changes nothing.
select pg_temp.as_user('a3');
select is(pg_temp.journey()->>'version', '2', 'a second configurer reads the same answers');
select throws_like($$select pg_temp.save('{"issue_invoices":false}', '{"money":"statements"}', 1, '00000000-0000-4000-8000-000000286803')$$,
  'setup journey changed:%', 'a save against a version that moved is refused');
select throws_ok($$select pg_temp.save('{"issue_invoices":false}', '{"money":"statements"}', 1, '00000000-0000-4000-8000-000000286803')$$,
  '40001', null, 'with the conflict state');
select throws_ok($$select pg_temp.save('{"issue_invoices":false}', '{"money":"statements"}', null, '00000000-0000-4000-8000-000000286804')$$,
  '40001', null, 'and so is one that thinks nothing was saved yet');
select is(pg_temp.journey()->'answers', '{"issue_invoices":true,"vat_registered":true}'::jsonb,
  'the stored answers are untouched');
select is(pg_temp.save('{"issue_invoices":false}', '{"money":"statements"}', 2, '00000000-0000-4000-8000-000000286805')->>'version', '3',
  'a save against the version now read goes through');
select is(pg_temp.journey()->>'updated_by_name', 'Zoe SECOND', 'naming the second configurer');

-- Refusals.
select throws_ok($$select pg_temp.save('[true]', '{}', 3, '00000000-0000-4000-8000-000000286806')$$,
  '22023', null, 'answers that are not an object are refused');
select throws_ok($$select pg_temp.save('{"issue_invoices":"yes"}', '{}', 3, '00000000-0000-4000-8000-000000286807')$$,
  '22023', null, 'an answer that is not true or false is refused');
select throws_ok($$select pg_temp.save('{}', '{"money":3}', 3, '00000000-0000-4000-8000-000000286808')$$,
  '22023', null, 'a level that is not a name is refused');
select throws_ok($$select public.save_setup_journey('00000000-0000-4000-8000-0000002868b1', '{}', '{}', 3, null)$$,
  '22023', null, 'a save without a request id is refused');

select pg_temp.as_user('a2');
select throws_ok($$select pg_temp.journey()$$, '42501', null, 'a plain member cannot read the answers');
select throws_ok($$select pg_temp.save('{}', '{}', 3, '00000000-0000-4000-8000-000000286809')$$,
  '42501', null, 'nor save them');
select ok(not has_table_privilege('authenticated', 'public.workspace_setup_journeys', 'select'),
  'nobody reads the table except through the functions');
select is((select version from public.workspace_setup_journeys
            where workspace_id = '00000000-0000-4000-8000-0000002868b1'), 3, 'the refusals wrote nothing');

-- Answers never change what the space does.
select pg_temp.as_user('a1');
select is((select feature_flags from public.workspaces where id = '00000000-0000-4000-8000-0000002868b1'),
  (select flags from before_journeys), 'the features are the same as before any answer');
select is(pg_temp.status(), (select status from before_journeys),
  'and so is the setup status');

select * from finish();
rollback;
