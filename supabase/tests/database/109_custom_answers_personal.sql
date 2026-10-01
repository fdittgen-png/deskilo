-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1912: an answer stored against a member is personal data whatever the
-- question's `personal_data` switch says. Member A's emergency contact
-- and shirt size sit on questions marked NOT personal; A's subject-access
-- export carries them and not member B's; A's own erasure, under the real
-- authenticated role, removes them and their choice links while B's
-- answers and the workspace's questions, choices and labels stay. Only a
-- documented retention hold keeps an answer, stamped with its basis and
-- expiry and readable only by a holder of viewPersonalData; a bare false
-- switch creates no hold, a foreign workspace or a non-owner cannot
-- document one, a repeated request changes nothing, a switch flipped
-- after the answers were entered changes nothing, and the canary answers
-- reach no event or access-log row. Rows are verified after the role is
-- reset, not from returned counts.
begin;
select plan(30);

-- a1 owner · a2 member A · a3 member B · a4 admin holding viewPersonalData
-- a5 plain member C · a6 owner of the foreign workspace.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001912'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@answers.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000001912b1','Answers','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001912a1','dev',
  '{"admin":["viewPersonalData"]}','{"customFields":true}'),
 ('00000000-0000-4000-8000-0000001912b2','Foreign answers','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001912a6','dev',
  '{}','{"customFields":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001912c1','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001912c2','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001912c3','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000001912c4','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912a4',false,true,'active'),
 ('00000000-0000-4000-8000-0000001912c5','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912a5',false,false,'active'),
 ('00000000-0000-4000-8000-0000001912c6','00000000-0000-4000-8000-0000001912b2','00000000-0000-4000-8000-0000001912a6',true,true,'active');
-- Three questions, every one marked NOT personal; `register` is the one
-- a statute makes the association keep.
insert into public.workspace_field_definitions(id,workspace_id,key,type,personal_data,visibility) values
 ('00000000-0000-4000-8000-0000001912d1','00000000-0000-4000-8000-0000001912b1','emergency','text',false,'managers'),
 ('00000000-0000-4000-8000-0000001912d2','00000000-0000-4000-8000-0000001912b1','shirt','single_choice',false,'members'),
 ('00000000-0000-4000-8000-0000001912d3','00000000-0000-4000-8000-0000001912b1','register','text',false,'members'),
 ('00000000-0000-4000-8000-0000001912d9','00000000-0000-4000-8000-0000001912b2','emergency','text',false,'self');
insert into public.workspace_field_labels(workspace_id,definition_id,locale,label) values
 ('00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912d1','en','Emergency contact'),
 ('00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912d2','en','Shirt size');
insert into public.workspace_field_options(id,workspace_id,definition_id,key) values
 ('00000000-0000-4000-8000-0000001912e1','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912d2','s'),
 ('00000000-0000-4000-8000-0000001912e2','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912d2','m');
insert into public.workspace_field_values(id,workspace_id,member_id,definition_id,text_value) values
 ('00000000-0000-4000-8000-0000001912f1','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912c2','00000000-0000-4000-8000-0000001912d1','CANARY-A-EMERGENCY'),
 ('00000000-0000-4000-8000-0000001912f2','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912c2','00000000-0000-4000-8000-0000001912d2',null),
 ('00000000-0000-4000-8000-0000001912f3','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912c2','00000000-0000-4000-8000-0000001912d3','CANARY-A-REGISTER'),
 ('00000000-0000-4000-8000-0000001912f4','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912c3','00000000-0000-4000-8000-0000001912d1','B-EMERGENCY'),
 ('00000000-0000-4000-8000-0000001912f5','00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912c3','00000000-0000-4000-8000-0000001912d2',null);
insert into public.workspace_field_value_options(workspace_id,value_id,option_id) values
 ('00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912f2','00000000-0000-4000-8000-0000001912e2'),
 ('00000000-0000-4000-8000-0000001912b1','00000000-0000-4000-8000-0000001912f5','00000000-0000-4000-8000-0000001912e1');

create temp table seen(k text primary key, v jsonb);
grant select, insert on seen to authenticated;

-- ── positive controls: the fixtures are there ────────────────────────
select is((select count(*)::int from public.workspace_field_values
            where text_value like 'CANARY-A-%'), 2, 'both canary answers of A are seeded');
select is((select count(*)::int from public.workspace_field_value_options
            where value_id = '00000000-0000-4000-8000-0000001912f2'), 1, 'A''s shirt choice is seeded');

-- ── the classification ignores the switch ───────────────────────────
select ok((select bool_and(public.field_answer_is_personal(v.member_id))
             from public.workspace_field_values v
             join public.workspace_field_definitions d on d.id = v.definition_id
            where not d.personal_data), 'an answer on a question marked not personal is still personal');

-- ── A's access export ───────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a2","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('export', public.export_my_data('00000000-0000-4000-8000-0000001912b1')->'custom_fields');
reset role;
select is(jsonb_array_length((select v from seen where k = 'export')), 3, 'A''s export carries all three of A''s answers');
select ok((select v::text from seen where k = 'export') like '%CANARY-A-EMERGENCY%', 'including the emergency contact marked not personal');
select ok((select v from seen where k = 'export') @> '[{"key":"shirt","choices":["m"]}]', 'and the shirt size marked not personal');
select ok((select v::text from seen where k = 'export') not like '%B-EMERGENCY%', 'and nothing of B');

-- ── documenting a hold ──────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.set_workspace_field_retention('00000000-0000-4000-8000-0000001912b1','emergency','Kept because I say so, forever',365)$$,
  'only an owner documents a retention hold', 'a member cannot document a hold on their own answer');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a1","role":"authenticated"}',true);
select throws_ok($$select public.set_workspace_field_retention('00000000-0000-4000-8000-0000001912b2','emergency','Association register, law of 1901 art. 5',365)$$,
  'only an owner documents a retention hold', 'an owner cannot document a hold in a foreign workspace');
select throws_ok($$select public.set_workspace_field_retention('00000000-0000-4000-8000-0000001912b1','register','short',365)$$,
  'a retention hold names its legal basis in 10 to 500 characters', 'a hold without a stated basis is refused');
select throws_ok($$select public.set_workspace_field_retention('00000000-0000-4000-8000-0000001912b1','register','Association register, law of 1901 art. 5',null)$$,
  'a retention hold lasts between 1 and 3650 days', 'a hold without an expiry is refused');
select lives_ok($$select public.set_workspace_field_retention('00000000-0000-4000-8000-0000001912b1','register','Association register, law of 1901 art. 5',365)$$,
  'the owner documents a hold on the register question');
reset role;
select is((select count(*)::int from public.workspace_field_retention_holds
            where workspace_id = '00000000-0000-4000-8000-0000001912b1'), 1, 'a bare false switch creates no hold: only the documented one exists');
select is((select definition_id from public.workspace_field_retention_holds
            where workspace_id = '00000000-0000-4000-8000-0000001912b1'), '00000000-0000-4000-8000-0000001912d3'::uuid,
  'the hold names the definition of the owner''s own workspace');

-- ── A erases, as A ──────────────────────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a2","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.erase_my_membership('00000000-0000-4000-8000-0000001912b1')$$, 'A erases their membership');
reset role;
select is((select count(*)::int from public.workspace_field_values
            where member_id = '00000000-0000-4000-8000-0000001912c2' and held_until is null), 0,
  'A''s unheld answers are gone, false switch or not');
select is((select count(*)::int from public.workspace_field_value_options
            where option_id = '00000000-0000-4000-8000-0000001912e2'), 0, 'and A''s choice link with them');
select is((select hold_basis from public.workspace_field_values where id = '00000000-0000-4000-8000-0000001912f3'),
  'Association register, law of 1901 art. 5', 'the held answer carries its basis');
select ok((select held_until between now() + interval '364 days' and now() + interval '366 days'
             from public.workspace_field_values where id = '00000000-0000-4000-8000-0000001912f3'), 'and its expiry');
select is((select count(*)::int from public.workspace_field_values
            where member_id = '00000000-0000-4000-8000-0000001912c3'), 2, 'B''s answers stay');
select is((select count(*)::int from public.workspace_field_value_options
            where option_id = '00000000-0000-4000-8000-0000001912e1'), 1, 'and B''s choice link');
select is((select count(*)::int from public.workspace_field_definitions where workspace_id = '00000000-0000-4000-8000-0000001912b1')
          + (select count(*)::int from public.workspace_field_options where workspace_id = '00000000-0000-4000-8000-0000001912b1')
          + (select count(*)::int from public.workspace_field_labels where workspace_id = '00000000-0000-4000-8000-0000001912b1'),
  7, 'the workspace''s questions, choices and labels stay');

-- ── the held answer is restricted ───────────────────────────────────
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a5","role":"authenticated"}',true);
set local role authenticated;
insert into seen values ('plain', to_jsonb((select count(*) from public.workspace_field_values where id = '00000000-0000-4000-8000-0000001912f3')));
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a4","role":"authenticated"}',true);
insert into seen values ('manager', to_jsonb((select count(*) from public.workspace_field_values where id = '00000000-0000-4000-8000-0000001912f3')));
reset role;
select is((select v from seen where k = 'plain'), '0'::jsonb, 'a member cannot read a held answer the question once showed to every member');
select is((select v from seen where k = 'manager'), '1'::jsonb, 'a holder of viewPersonalData can');

-- ── a repeated request changes nothing ──────────────────────────────
insert into seen values ('held', (select to_jsonb(v) from public.workspace_field_values v where id = '00000000-0000-4000-8000-0000001912f3'));
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a2","role":"authenticated"}',true);
set local role authenticated;
select throws_like($$select public.erase_my_membership('00000000-0000-4000-8000-0000001912b1')$$, '%', 'a second erasure is refused: A is no longer a member');
reset role;
select is((select to_jsonb(v) from public.workspace_field_values v where id = '00000000-0000-4000-8000-0000001912f3'),
  (select v from seen where k = 'held'), 'and the held answer is unchanged');

-- ── a switch flipped after the answers were entered ─────────────────
update public.workspace_field_definitions set personal_data = true where id = '00000000-0000-4000-8000-0000001912d2';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001912a3","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.erase_my_membership('00000000-0000-4000-8000-0000001912b1')$$, 'B erases after the shirt switch was flipped');
reset role;
select is((select count(*)::int from public.workspace_field_values
            where member_id = '00000000-0000-4000-8000-0000001912c3'), 0, 'both of B''s answers are gone, flipped switch or not');

-- ── canaries reach no log ───────────────────────────────────────────
select is((select count(*)::int from public.events e where to_jsonb(e)::text like '%CANARY-A-%')
          + (select count(*)::int from public.data_access_log a where to_jsonb(a)::text like '%CANARY-A-%'),
  0, 'no event or access-log row carries a canary answer');

-- ── an expired hold ends ────────────────────────────────────────────
update public.workspace_field_values set held_until = now() - interval '1 second'
 where id = '00000000-0000-4000-8000-0000001912f3';
select is(public.purge_expired_field_answer_holds(), 1, 'the purge removes the expired held answer');

select * from finish();
rollback;
