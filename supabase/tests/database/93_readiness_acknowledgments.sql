-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0307: "I'll do it later" is an explicit acknowledgement, keyed by
-- installation, workspace, user and section at one material revision.
-- Only someone who configures the space sets an optional, open section
-- aside; it never makes anything ready, and a changed section, another
-- account, workspace or installation never shares it.
begin;
select plan(38);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000307a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ack-owner@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000307a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ack-member@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000307a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ack-foreign@deskilo.test', '', now(), now(), now());

create function pg_temp.sec(p text, s text) returns jsonb language sql as $$
  select e from jsonb_array_elements(current_setting(p)::jsonb) e where e->>'section' = s
$$;
grant execute on function pg_temp.sec(text, text) to authenticated;

-- The owner's two spaces, the foreign owner's one, a plain member in the first.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c307', 'Acknowledged', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
select set_config('t.ws2', public.create_workspace_once('00000000-0000-4000-8000-00000000c317', 'Other space', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a3","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.wsf', public.create_workspace_once('00000000-0000-4000-8000-00000000c327', 'Foreign space', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000000307a2', 'active', false, 100);

-- The owner sets payments and recovery aside, and reads them back.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r0', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select set_config('t.ack', (select to_jsonb(a) from public.acknowledge_readiness_section(current_setting('t.ws')::uuid, 'payments') a)::text, true);
select public.acknowledge_readiness_section(current_setting('t.ws')::uuid, 'recovery');
select set_config('t.r1', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select set_config('t.r1b', public.workspace_readiness(current_setting('t.ws2')::uuid)::text, true);
select set_config('t.own', (select count(*) from public.readiness_acknowledgements
  where workspace_id = current_setting('t.ws')::uuid)::text, true);
select throws_ok(format('select public.acknowledge_readiness_section(%L, %L)', current_setting('t.ws'), 'resources'),
  '22023', null, 'a required section cannot be set aside');
select throws_ok(format('select public.acknowledge_readiness_section(%L, %L)', current_setting('t.ws'), 'pricing'),
  '22023', null, 'a ready section cannot be set aside');
select throws_ok(format('select public.acknowledge_readiness_section(%L, %L)', current_setting('t.ws'), 'nonsense'),
  '22023', null, 'a section the space does not have cannot be set aside');
-- Undo: set first_booking aside, then take it back.
select public.acknowledge_readiness_section(current_setting('t.ws')::uuid, 'first_booking');
select set_config('t.r2', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select set_config('t.cleared', public.clear_readiness_acknowledgement(current_setting('t.ws')::uuid, 'first_booking')::text, true);
select set_config('t.r3', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select set_config('t.gone', (select count(*) from public.readiness_acknowledgements
  where workspace_id = current_setting('t.ws')::uuid and section = 'first_booking')::text, true);
reset role;

-- The same owner through a delegated assistant token.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a1","role":"authenticated","client_id":"assistant"}', true);
set local role authenticated;
select throws_ok(format('select public.acknowledge_readiness_section(%L, %L)', current_setting('t.ws'), 'first_booking'),
  '42501', null, 'an assistant token cannot set a section aside');
select throws_ok(format('select public.clear_readiness_acknowledgement(%L, %L)', current_setting('t.ws'), 'payments'),
  '42501', null, 'nor take one back');
reset role;

-- The plain member: no manageConfiguration, even for a row of their own.
insert into public.readiness_acknowledgements (workspace_id, user_id, section, material_revision)
values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000000307a2', 'payments', md5('x'));
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a2","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.acknowledge_readiness_section(%L, %L)', current_setting('t.ws'), 'payments'),
  '42501', null, 'a plain member cannot set a section aside');
select set_config('t.mem', (select count(*) from public.readiness_acknowledgements)::text, true);
reset role;

-- The foreign owner.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a3","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.acknowledge_readiness_section(%L, %L)', current_setting('t.ws'), 'payments'),
  '42501', null, 'a foreign owner cannot set another space''s section aside');
select throws_ok(format('select public.clear_readiness_acknowledgement(%L, %L)', current_setting('t.ws'), 'payments'),
  '42501', null, 'nor take one back');
select set_config('t.for', (select count(*) from public.readiness_acknowledgements
  where workspace_id = current_setting('t.ws')::uuid)::text, true);
select set_config('t.rf', public.workspace_readiness(current_setting('t.wsf')::uuid)::text, true);
reset role;

-- Anonymous.
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
do $$ begin
  perform public.acknowledge_readiness_section(current_setting('t.ws')::uuid, 'payments');
  perform set_config('t.anon', 'called', true);
exception when others then
  perform set_config('t.anon', sqlstate, true);
end $$;
reset role;

-- Another installation's acknowledgement, at the section's current revision.
insert into public.readiness_acknowledgements (installation_id, workspace_id, user_id, section, material_revision)
values (gen_random_uuid(), current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000000307a1', 'first_booking',
        public.readiness_section_revision(pg_temp.sec('t.r0', 'first_booking')));
-- Payments become ready; recovery's evidence turns up, but stale.
update public.workspaces set payment_instructions = '{"iban": "FR7630006000011234567890189"}'::jsonb
 where id = current_setting('t.ws')::uuid;
insert into public.workspace_recovery_evidence (workspace_id, recorded_at, sha256, row_count)
values (current_setting('t.ws')::uuid, now() - interval '100 days', repeat('a', 64), 1);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000307a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r4', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select set_config('t.inst', (select count(*) from public.readiness_acknowledgements
  where workspace_id = current_setting('t.ws')::uuid and section = 'first_booking')::text, true);
reset role;

select is(current_setting('t.ack')::jsonb->>'user_id', '00000000-0000-4000-8000-0000000307a1', 'the acknowledgement belongs to the caller');
select is(current_setting('t.ack')::jsonb->>'material_revision', public.readiness_section_revision(pg_temp.sec('t.r0', 'payments')),
  'at the section''s current material revision');
select ok(pg_temp.sec('t.r0', 'payments')->'acknowledged' is null, 'nothing is acknowledged before anyone says so');
select is((pg_temp.sec('t.r1', 'payments')->>'acknowledged')::boolean, true, 'the owner reads payments back as acknowledged');
select is(pg_temp.sec('t.r1', 'payments')->>'state', 'needs_configuration', 'and it still needs configuration');
select is((pg_temp.sec('t.r1', 'recovery')->>'acknowledged')::boolean, true, 'recovery can be set aside too');
select is(pg_temp.sec('t.r1', 'recovery')->>'state', 'unverified', 'but it stays unverified: an acknowledgement is never evidence');
select ok(pg_temp.sec('t.r1', 'first_booking')->'acknowledged' is null, 'a section nobody set aside is not acknowledged');
select ok(pg_temp.sec('t.r1b', 'payments')->'acknowledged' is null, 'the owner''s other space is not affected');
select is(current_setting('t.own'), '2', 'the owner reads their own two rows back');
select is((pg_temp.sec('t.r2', 'first_booking')->>'acknowledged')::boolean, true, 'first booking set aside');
select is(current_setting('t.cleared'), 'true', 'clear says it removed something');
select ok(pg_temp.sec('t.r3', 'first_booking')->'acknowledged' is null, 'and the section is open again');
select is(current_setting('t.gone'), '0', 'its row is gone');
select is(current_setting('t.mem'), '0', 'a plain member reads no rows, not even one with their own name');
select is(current_setting('t.for'), '0', 'a foreign owner reads none of another space''s rows');
select ok(pg_temp.sec('t.rf', 'payments')->'acknowledged' is null, 'and their own space shares nothing');
select is(current_setting('t.anon'), '42501', 'anon cannot call it');
select ok(not has_function_privilege('anon', 'public.clear_readiness_acknowledgement(uuid,text)', 'execute'), 'nor clear');
select ok(not has_table_privilege('anon', 'public.readiness_acknowledgements', 'select'), 'nor read the table');
select ok(not has_table_privilege('authenticated', 'public.readiness_acknowledgements', 'insert'), 'no client inserts directly');
select ok(not has_table_privilege('authenticated', 'public.readiness_acknowledgements', 'update'), 'or updates');
select ok(pg_temp.sec('t.r4', 'first_booking')->'acknowledged' is null, 'another installation''s acknowledgement never applies here');
select is(current_setting('t.inst'), '0', 'nor is it readable here');
select is(pg_temp.sec('t.r4', 'payments')->>'state', 'ready', 'payments are ready once instructions exist');
select ok(pg_temp.sec('t.r4', 'payments')->'acknowledged' is null, 'and its acknowledgement no longer applies');
select is(pg_temp.sec('t.r4', 'recovery')->>'reason', 'stale_export', 'recovery now has stale evidence');
select is(pg_temp.sec('t.r4', 'recovery')->>'state', 'unverified', 'which stays unverified');
select ok(pg_temp.sec('t.r4', 'recovery')->'acknowledged' is null, 'and the changed material drops the acknowledgement');
select is(pg_temp.sec('t.r0', 'pricing')->>'state' || '/' || (pg_temp.sec('t.r0', 'pricing')->>'required'), 'ready/false',
  'the refused ready section really was ready and optional');

select * from finish();
rollback;
