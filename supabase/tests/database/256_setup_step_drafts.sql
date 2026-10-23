-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2869 (setup_step_drafts): a step's draft round-trips through the
-- server; each write bumps its version and a retry under the same request
-- id answers the first write again without a second bump; a write against
-- a version that moved raises 40001 ("setup draft changed: …") and leaves
-- the other configurer's draft as it was, also after a discard restarted
-- the step; an unknown step and a payload that is not an object are 22023;
-- someone who does not configure the space is refused (42501); a discard
-- leaves no draft; and nothing a draft does moves the setup status.
begin;
select plan(30);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002869'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@step-drafts.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
update public.profiles set first_name = 'Ada', last_name = 'Owner' where id = '00000000-0000-4000-8000-0000002869a1';
update public.profiles set first_name = 'Zoe', last_name = 'Second' where id = '00000000-0000-4000-8000-0000002869a3';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules)
values('00000000-0000-4000-8000-0000002869b1','Step drafts','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002869a1','dev','{"open_weekdays":[1,2,3,4,5]}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002869c1','00000000-0000-4000-8000-0000002869b1','00000000-0000-4000-8000-0000002869a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002869c2','00000000-0000-4000-8000-0000002869b1','00000000-0000-4000-8000-0000002869a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002869c3','00000000-0000-4000-8000-0000002869b1','00000000-0000-4000-8000-0000002869a3',true,true,'active');

create function pg_temp.save(p_payload jsonb, p_expected int, p_request text, p_step text default 'basics')
returns jsonb language sql as $$
  select public.save_setup_step_draft('00000000-0000-4000-8000-0000002869b1', p_step, p_payload, p_expected, p_request::uuid)
$$;
create function pg_temp.draft() returns jsonb language sql as $$
  select public.get_setup_step_draft('00000000-0000-4000-8000-0000002869b1', 'basics')
$$;
create function pg_temp.status() returns jsonb language sql as $$
  select public.workspace_setup_status('00000000-0000-4000-8000-0000002869b1')
$$;
create function pg_temp.as_user(p_suffix text) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000002869' || p_suffix, 'role', 'authenticated')::text, true)
$$;

select pg_temp.as_user('a1');
create temp table before_drafts as select pg_temp.status() as status;

-- Round trip, version, idempotent retry.
select is(pg_temp.draft(), null, 'no draft yet');
select is(pg_temp.save('{"country_code":"DE"}', null, '00000000-0000-4000-8000-000000286901')->>'version', '1',
  'the first save is version 1');
select is(pg_temp.draft()->'payload', '{"country_code":"DE"}'::jsonb, 'and reads back as saved');
select is(pg_temp.draft()->>'updated_by_name', 'Ada OWNER', 'naming who saved it');
select is(pg_temp.save('{"country_code":"DE"}', null, '00000000-0000-4000-8000-000000286901')->>'version', '1',
  'a retry under the same request id answers the same version');
select is((select version from public.setup_step_drafts where step = 'basics'
            and workspace_id = '00000000-0000-4000-8000-0000002869b1'), 1, 'and bumps nothing');
select is(pg_temp.save('{"country_code":"IT"}', 1, '00000000-0000-4000-8000-000000286902')->>'version', '2',
  'a save against the version read bumps it');
select is(pg_temp.draft()->'payload', '{"country_code":"IT"}'::jsonb, 'and replaces the answers');

-- Another configurer's stale write is refused and changes nothing.
select pg_temp.as_user('a3');
select is(pg_temp.draft()->>'version', '2', 'a second configurer reads the same draft');
select throws_like($$select pg_temp.save('{"country_code":"ES"}', 1, '00000000-0000-4000-8000-000000286903')$$,
  'setup draft changed:%', 'a save against a version that moved is refused');
select throws_ok($$select pg_temp.save('{"country_code":"ES"}', 1, '00000000-0000-4000-8000-000000286903')$$,
  '40001', null, 'with the conflict state');
select throws_ok($$select pg_temp.save('{"country_code":"ES"}', null, '00000000-0000-4000-8000-000000286904')$$,
  '40001', null, 'and so is one that thinks there is no draft yet');
select is(pg_temp.draft()->'payload', '{"country_code":"IT"}'::jsonb, 'the stored answers are untouched');
select is(pg_temp.draft()->>'version', '2', 'and so is the version');
select is(pg_temp.save('{"country_code":"ES"}', 2, '00000000-0000-4000-8000-000000286905')->>'version', '3',
  'keeping mine: a save against the version now read goes through');
select is(pg_temp.draft()->>'updated_by_name', 'Zoe SECOND', 'naming the second configurer');

-- Refusals.
select throws_ok($$select pg_temp.save('{}', null, '00000000-0000-4000-8000-000000286906', 'nope')$$,
  '22023', null, 'an unknown step is refused');
select throws_ok($$select pg_temp.save('[1]', 3, '00000000-0000-4000-8000-000000286907')$$,
  '22023', null, 'a payload that is not an object is refused');
select throws_ok($$insert into public.setup_step_drafts(workspace_id, step, payload)
  values ('00000000-0000-4000-8000-0000002869b1', 'nope', '{}')$$,
  '22023', null, 'the table itself refuses a step the catalogue does not name');

select pg_temp.as_user('a2');
select throws_ok($$select pg_temp.draft()$$, '42501', null, 'a plain member cannot read a draft');
select throws_ok($$select pg_temp.save('{"country_code":"FR"}', 3, '00000000-0000-4000-8000-000000286908')$$,
  '42501', null, 'nor save one');
select throws_ok($$select public.discard_setup_step_draft('00000000-0000-4000-8000-0000002869b1', 'basics', 3)$$,
  '42501', null, 'nor discard one');
select ok(not has_table_privilege('authenticated', 'public.setup_step_drafts', 'select'),
  'nobody reads the table except through the functions');

-- Discard, and a version number that is never handed out twice.
select pg_temp.as_user('a1');
select throws_ok($$select public.discard_setup_step_draft('00000000-0000-4000-8000-0000002869b1', 'basics', 2)$$,
  '40001', null, 'a discard against a version that moved is refused');
select ok(public.discard_setup_step_draft('00000000-0000-4000-8000-0000002869b1', 'basics', 3),
  'a discard against the version read removes the draft');
select is(pg_temp.draft(), null, 'and then there is no draft');
select ok(not public.discard_setup_step_draft('00000000-0000-4000-8000-0000002869b1', 'basics', 3),
  'discarding nothing says so');
select throws_ok($$select pg_temp.save('{"country_code":"PT"}', 3, '00000000-0000-4000-8000-000000286909')$$,
  '40001', null, 'a save holding the discarded version is refused');
select is(pg_temp.save('{"country_code":"PT"}', null, '00000000-0000-4000-8000-000000286910')->>'version', '5',
  'a new draft keeps counting past the discarded one');

-- A draft is never configuration.
select is(pg_temp.status(), (select status from before_drafts),
  'the setup status is the same as before any draft');

select * from finish();
rollback;
