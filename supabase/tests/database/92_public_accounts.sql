-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1791: exact anonymous projections, withdrawal, own contact opt-in,
-- private account conversations and employment without privilege escalation.
begin;
select plan(29);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000000302'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@public-page.test','',now(),now(),now() from unnest(array['a1','a2','a3']) suffix;
update public.profiles set display_name=case right(id::text,2) when 'a1' then 'Host' when 'a2' then 'Admin' else 'Visitor' end where id::text like '%0302a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000000302b1','Public office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000000302a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000000302c1','00000000-0000-4000-8000-0000000302b1','00000000-0000-4000-8000-0000000302a1',true,true,'active'),
('00000000-0000-4000-8000-0000000302c2','00000000-0000-4000-8000-0000000302b1','00000000-0000-4000-8000-0000000302a2',false,true,'active');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000000302b1','{"host_type":"company"}',true)$$,'P0001','owner required','admin cannot publish an owner page');
select throws_ok($$select public.member_employment_status('00000000-0000-4000-8000-0000000302c2',true)$$,'P0001','owner required','admin cannot appoint their own employment');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a1","role":"authenticated"}',true);
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000000302b1','{"host_type":"person","address":"10 Quiet Street","plans":"Hourly desks","latitude":"48.8","longitude":"2.3"}',true)$$,'owner publishes an explicit public projection');
select is(jsonb_array_length((public.my_workspace_public_page('00000000-0000-4000-8000-0000000302b1')->'document')->'contacts'),1,'owner visible and admin hidden by default');
select ok(public.member_employment_status('00000000-0000-4000-8000-0000000302c2',true),'owner records employed administrator');
select ok(not (select is_owner from public.members where id='00000000-0000-4000-8000-0000000302c2'),'employment does not grant ownership');
select lives_ok($$select public.set_contact_availability(true)$$,'owner enables account messaging');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a2","role":"authenticated"}',true);
select ok(public.my_admin_visibility('00000000-0000-4000-8000-0000000302b1',true),'admin opts into public visibility');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select is((select name from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000000302b1'),'Public office','anonymous visitor sees the workspace');
select is((select jsonb_array_length(document->'contacts') from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000000302b1'),2,'public contacts match explicit visibility');
select ok(not (select document ? 'invite_code' or document ? 'feature_flags' or document ? 'employment' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000000302b1'),'projection excludes private and authority fields');
select throws_ok($$select * from public.workspace_public_pages$$,'42501',null,'anonymous reader cannot read draft rows');
select throws_ok($$select * from public.account_messages$$,'42501',null,'anonymous reader cannot read account messages');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a3","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000000302b1')$$,'public request uses ordinary admission');
select ok(not public.is_member_of('00000000-0000-4000-8000-0000000302b1'),'request does not bypass approval');
select is(jsonb_array_length(public.search_available_accounts('Host')),1,'available account is discoverable');
select is(jsonb_array_length(public.search_available_accounts('Admin')),0,'public admin without account opt-in is not globally discoverable');
-- 0388: public visibility alone opens no inbox: the first message is only a held request.
select lives_ok($$select public.send_account_message('00000000-0000-4000-8000-0000000302a2','Hello','00000000-0000-4000-8000-0000000302a3')$$,'public visibility alone cannot enable an inbox: the message is held as a request');
select lives_ok($$select public.send_account_message('00000000-0000-4000-8000-0000000302a1','Can I visit?','00000000-0000-4000-8000-0000000302a3')$$,'applicant can contact opted-in owner without membership');
reset role;
select set_config('t.thread',(select id::text from public.account_conversations where user_a='00000000-0000-4000-8000-0000000302a1' and user_b='00000000-0000-4000-8000-0000000302a3'),true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok(format('select public.my_account_messages(%L::uuid)',current_setting('t.thread')),'P0001','conversation unavailable','workspace admin cannot read other accounts private discussion');
select is(jsonb_array_length(public.my_account_conversations()),1,'admin lists only their own held request, not other account threads');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a1","role":"authenticated"}',true);
select is(jsonb_array_length(public.my_account_messages(current_setting('t.thread')::uuid)),1,'recipient sees the actual message');
select lives_ok($$select public.set_contact_availability(false)$$,'recipient withdraws global availability');
select lives_ok($$select public.send_account_message('00000000-0000-4000-8000-0000000302a3','Yes, tomorrow.','00000000-0000-4000-8000-0000000302a1')$$,'existing participants can continue discussing');
select throws_ok($$select public.send_account_message('00000000-0000-4000-8000-0000000302a3','Wrong account','00000000-0000-4000-8000-0000000302a2')$$,'P0001','account changed','stale account write denied');
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000000302b1','{"host_type":"person"}',false)$$,'owner withdraws publication');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select is((select count(workspace_id) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000000302b1'),0::bigint,'withdrawn page disappears from the actual public API');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000302a1","role":"authenticated","client_id":"delegate"}',true);
set local role authenticated;
select throws_ok($$select public.set_contact_availability(true)$$,'P0001',null,'MCP cannot change personal contact preferences');
select throws_ok($$select public.my_account_conversations()$$,'P0001',null,'MCP cannot read personal conversations');
reset role;
select * from finish();
rollback;
