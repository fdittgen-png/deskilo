-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0301: recovery evidence is a completed export the app recorded, never a
-- checkbox. Recent within 90 days is ready, older is stale, none is none;
-- only someone who may export records one, and nobody reads the table.
begin;
select plan(14);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000301a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 're-owner@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000301a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 're-member@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000301a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000c301', 'Recovery evidence', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
select set_config('t.r0', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select throws_ok(format('select public.record_workspace_export(%L, %L, 3)', current_setting('t.ws'), 'not-a-hash'),
  '22023', null, 'a hash that is not 64 hexadecimal characters is refused');
select throws_ok(format('select public.record_workspace_export(%L, %L, -1)', current_setting('t.ws'), repeat('a', 64)),
  '22023', null, 'a negative row count is refused');
select set_config('t.row', (select to_jsonb(ev) from public.record_workspace_export(
  current_setting('t.ws')::uuid, repeat('AB', 32), 42) ev)::text, true);
select set_config('t.r1', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
select throws_ok('select * from public.workspace_recovery_evidence', '42501', null,
  'the evidence table is not readable by a signed-in client');
reset role;

update public.workspace_recovery_evidence set recorded_at = now() - interval '100 days'
 where workspace_id = current_setting('t.ws')::uuid;
set local role authenticated;
select set_config('t.r2', public.workspace_readiness(current_setting('t.ws')::uuid)::text, true);
reset role;

insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000000301a2', 'active', false, 100);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000301a2","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format('select public.record_workspace_export(%L, %L, 1)', current_setting('t.ws'), repeat('c', 64)),
  '42501', null, 'a member without exportData records nothing');
reset role;

create function pg_temp.rec(p text) returns jsonb language sql as $$
  select e from jsonb_array_elements(current_setting(p)::jsonb) e where e->>'section' = 'recovery'
$$;
select is(pg_temp.rec('t.r0')->>'reason', 'no_evidence', 'a new space has no recovery evidence');
select is(pg_temp.rec('t.r0')->>'state', 'unverified', 'and stays unverified');
select is(pg_temp.rec('t.r1')->>'state', 'ready', 'a recorded export makes recovery ready');
select is(pg_temp.rec('t.r1')->>'reason', 'recent_export', 'because the export is recent');
select ok(pg_temp.rec('t.r1')->>'recorded_at' is not null, 'and says when');
select is(current_setting('t.row')::jsonb->>'sha256', repeat('ab', 32), 'the hash is stored lower-case');
select is(current_setting('t.row')::jsonb->>'recorded_by', '00000000-0000-4000-8000-0000000301a1', 'by the caller');
select is(pg_temp.rec('t.r2')->>'reason', 'stale_export', 'an export older than 90 days is stale');
select is(pg_temp.rec('t.r2')->>'state', 'unverified', 'and no longer verifies recovery');
select ok(not has_function_privilege('anon', 'public.record_workspace_export(uuid,text,integer)', 'execute'),
  'anon cannot record an export');

select * from finish();
rollback;
