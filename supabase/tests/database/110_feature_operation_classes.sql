-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1851: switching a feature off stops NEW business, not the work under
-- way. With spaceInquiries off, nobody can start an inquiry, while an
-- OPEN inquiry can still be read, answered and closed by exactly the
-- people who could before; a closed one stays closed, and an outsider
-- gains nothing. The class matrix is the one
-- test/features/workspace/feature_operation_test.dart pins for Dart.
begin;
select plan(20);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001851'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@operations.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
-- a1 owner (host), a2 asks, a3 outside.
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags)
values('00000000-0000-4000-8000-0000001851b1','Operations space','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000001851a1','dev','{"spaceInquiries":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001851c1','00000000-0000-4000-8000-0000001851b1','00000000-0000-4000-8000-0000001851a1',true,true,'active');

-- ── the class matrix ──
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','spaceInquiries','accept_new'),true,'on: accept_new is open');
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','spaceInquiries','service_existing'),true,'on: service_existing is open');
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','spaceInquiries','suspended'),false,'on: suspended stays shut');
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','spaceInquiries','reopen'),null,'an unknown class answers nothing');
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','noSuchFeature','accept_new'),false,'an unknown feature takes nothing new');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001851b1','{"host_type":"company"}',true)$$,'the owner publishes the page');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851a2","role":"authenticated"}',true);
select set_config('t.inquiry', public.start_space_inquiry('00000000-0000-4000-8000-0000001851b1','Can I visit?')::text, true);

-- ── intake off ──
reset role;
update public.workspaces set feature_flags = feature_flags || '{"spaceInquiries":false}' where id='00000000-0000-4000-8000-0000001851b1';
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','spaceInquiries','accept_new'),false,'off: accept_new is shut');
select is(public.feature_operation_allowed('00000000-0000-4000-8000-0000001851b1','spaceInquiries','service_existing'),true,'off: service_existing stays open');
set local role authenticated;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851a3","role":"authenticated"}',true);
select throws_ok($$select public.start_space_inquiry('00000000-0000-4000-8000-0000001851b1','Hello?')$$,'P0001','inquiries unavailable','off: a new inquiry is refused');
select throws_ok(format('select public.send_inquiry_message(%L,%L)',current_setting('t.inquiry'),'Me too'),'P0001','inquiry unavailable','off: an outsider still cannot write into it');
reset role;
select is((select count(*) from public.space_inquiries where workspace_id='00000000-0000-4000-8000-0000001851b1'),1::bigint,'the refusals created nothing');
set local role authenticated;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851a2","role":"authenticated"}',true);
select lives_ok(format('select public.send_inquiry_message(%L,%L)',current_setting('t.inquiry'),'Still there?'),'off: the requester continues the open inquiry');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851a1","role":"authenticated"}',true);
select is((select count(*) from jsonb_array_elements(public.my_inbox()) i where i->>'context_kind'='inquiry_in'),1::bigint,'off: the host still finds it in the inbox');
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inquiry')::uuid)),2,'off: the host reads the whole conversation');
select lives_ok(format('select public.send_inquiry_message(%L,%L)',current_setting('t.inquiry'),'Yes, we close new ones'),'off: the host answers it');
select lives_ok(format('select public.close_space_inquiry(%L)',current_setting('t.inquiry')),'off: the host closes it');
select throws_ok(format('select public.send_inquiry_message(%L,%L)',current_setting('t.inquiry'),'One more'),'P0001','inquiry closed','a closed inquiry stays closed');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851a2","role":"authenticated"}',true);
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inquiry')::uuid)),3,'the requester keeps the history');
select throws_ok($$select public.start_space_inquiry('00000000-0000-4000-8000-0000001851b1','Again?')$$,'P0001','inquiries unavailable','off: the requester cannot open a new one either');

-- ── intake back on ──
reset role;
update public.workspaces set feature_flags = feature_flags || '{"spaceInquiries":true}' where id='00000000-0000-4000-8000-0000001851b1';
set local role authenticated;
select lives_ok($$select public.start_space_inquiry('00000000-0000-4000-8000-0000001851b1','Again?')$$,'on again: a new inquiry is accepted');

select * from finish();
rollback;
