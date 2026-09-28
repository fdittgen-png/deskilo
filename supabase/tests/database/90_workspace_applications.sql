-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1791: refusing admission preserves an explained, private discussion;
-- quick decisions obey the validation quorum and never grant access by chat.
begin;
select plan(30);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000000300'||suffix)::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated',suffix||'@admission.test','',now(),now(),now()
from unnest(array['a1','a2','a3','a4']) suffix;
update public.profiles set display_name=case right(id::text,2)
 when 'a1' then 'Owner' when 'a2' then 'Reviewer' when 'a3' then 'Applicant' else 'Other' end
where id::text like '%0300a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000000300b1','Application space','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000000300a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000000300c1','00000000-0000-4000-8000-0000000300b1','00000000-0000-4000-8000-0000000300a1',true,true,'active'),
('00000000-0000-4000-8000-0000000300c2','00000000-0000-4000-8000-0000000300b1','00000000-0000-4000-8000-0000000300a2',false,true,'active'),
('00000000-0000-4000-8000-0000000300c3','00000000-0000-4000-8000-0000000300b1','00000000-0000-4000-8000-0000000300a3',false,false,'pending');
insert into public.validation_policies(workspace_id,event_type,required_count,admins_may_validate,owner_required)
values('00000000-0000-4000-8000-0000000300b1','member_join',2,true,true);
insert into public.events(id,workspace_id,type,action,actor_member_id,subject_member_id,payload,status)
values('00000000-0000-4000-8000-0000000300d1','00000000-0000-4000-8000-0000000300b1','member_join','submitted',
'00000000-0000-4000-8000-0000000300c3','00000000-0000-4000-8000-0000000300c3','{}','pending');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.decide_workspace_application('00000000-0000-4000-8000-0000000300c3',true,'Self approval')$$,
 'P0001',null,'a pending applicant cannot validate their own request');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.decide_member_join('00000000-0000-4000-8000-0000000300c3',true)$$,'old quick action enters the same quorum');
select is((select status from public.members where id='00000000-0000-4000-8000-0000000300c3'),'pending','one of two validators cannot activate membership');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a2","role":"authenticated"}',true);
select lives_ok($$select public.decide_workspace_application('00000000-0000-4000-8000-0000000300c3',false,'No desk is currently available; please contact me.')$$,'reviewer refuses with an explanation');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a3","role":"authenticated"}',true);
select is(public.my_workspace_applications()->0->>'status','rejected','applicant still sees refused application');
select is(public.my_workspace_applications()->0->>'workspace_name','Application space','refusal retains the workspace identity without granting its data');
select is((select status from public.members where id='00000000-0000-4000-8000-0000000300c3'),'exited','refusal grants no active membership');
select ok(not public.is_member_of('00000000-0000-4000-8000-0000000300b1'),'refused applicant is not a workspace member');
select ok(exists(select 1 from jsonb_array_elements(public.workspace_application_thread('00000000-0000-4000-8000-0000000300d1')) message
 where message->>'author_name'='Reviewer' and message->>'body'='No desk is currently available; please contact me.'),'applicant reads the reviewer explanation');
select lives_ok($$select public.send_workspace_application_message('00000000-0000-4000-8000-0000000300d1','Could I visit next month instead?')$$,'refused applicant can discuss the decision');
select throws_ok($$select public.send_workspace_application_message('00000000-0000-4000-8000-0000000300d1','Late reply','00000000-0000-4000-8000-0000000300a2')$$,'P0001','account changed','late replies cannot be attributed to another account');
select throws_ok($$select * from public.workspace_application_messages$$,'42501',null,'thread table cannot be enumerated directly');
select throws_ok($$select public.decide_workspace_application('00000000-0000-4000-8000-0000000300c3',true,'')$$,'P0001',null,'applicant cannot approve themselves');
select throws_ok($$select public.send_workspace_application_message('00000000-0000-4000-8000-0000000300d1',' ')$$,'P0001','invalid message','empty messages rejected');
select throws_ok($$select public.send_workspace_application_message('00000000-0000-4000-8000-0000000300d1',repeat('x',4001))$$,'P0001','invalid message','unbounded messages rejected');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a4","role":"authenticated"}',true);
select is(public.my_workspace_applications(),'[]'::jsonb,'unrelated account sees no application history');
select throws_ok($$select public.workspace_application_thread('00000000-0000-4000-8000-0000000300d1')$$,'P0001','application unavailable','unrelated account cannot read a known thread ID');
select throws_ok($$select public.send_workspace_application_message('00000000-0000-4000-8000-0000000300d1','Forged reviewer')$$,'P0001','application unavailable','discussion cannot create reviewer authority');
reset role;
update public.members set status='exited' where id='00000000-0000-4000-8000-0000000300c2';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a2","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.send_workspace_application_message('00000000-0000-4000-8000-0000000300d1','I have passed your question to the owner.')$$,'the actual reviewer can continue their own discussion');
select ok(not public.is_member_of('00000000-0000-4000-8000-0000000300b1'),'discussion does not restore departed reviewer membership');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a3","role":"authenticated","client_id":"delegated"}',true);
select throws_ok($$select public.my_workspace_applications()$$,'P0001',null,'delegated clients cannot read personal applications');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($$select public.my_workspace_applications()$$,'42501',null,'anonymous requests cannot enumerate applications');
reset role;
-- Rejoining preserves the old request and starts a distinct validation event.
update public.members set status='pending' where id='00000000-0000-4000-8000-0000000300c3';
update public.validation_policies set required_count=1 where workspace_id='00000000-0000-4000-8000-0000000300b1';
insert into public.events(id,workspace_id,type,action,actor_member_id,subject_member_id,payload,status)
values('00000000-0000-4000-8000-0000000300d2','00000000-0000-4000-8000-0000000300b1','member_join','submitted',
'00000000-0000-4000-8000-0000000300c3','00000000-0000-4000-8000-0000000300c3','{}','pending');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.decide_workspace_application('00000000-0000-4000-8000-0000000300c3',true,'A desk is now available.')$$,'later application can be approved');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a3","role":"authenticated"}',true);
select is((select status from public.members where id='00000000-0000-4000-8000-0000000300c3'),'active','completed validation activates the profile');
select is(jsonb_array_length(public.my_workspace_applications()),2,'rejoining does not erase the previous refusal');
select lives_ok($$select public.set_personal_preferences('{"clock":"12h"}')$$,'accepted user configures their personal default');
select is(public.my_personal_preferences('00000000-0000-4000-8000-0000000300b1')->'defaults'->>'clock','12h','accepted workspace inherits the user setting');
select ok(jsonb_array_length(public.export_my_data('00000000-0000-4000-8000-0000000300b1')->'application_messages')>0,'subject export includes the admission discussion');
reset role;
delete from auth.users where id='00000000-0000-4000-8000-0000000300a3';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a1","role":"authenticated"}',true);
set local role authenticated;
select set_config('t.claim',public.create_invitation('00000000-0000-4000-8000-0000000300b1',false,'','',
  '00000000-0000-4000-8000-0000000300c3'),true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000000300a4","role":"authenticated"}',true);
select public.join_workspace(current_setting('t.claim'));
select ok(not exists(select 1 from jsonb_array_elements(public.my_workspace_applications()) application
 where application->>'id' in ('00000000-0000-4000-8000-0000000300d1','00000000-0000-4000-8000-0000000300d2')),
 'claiming a retained membership does not inherit the previous account request history');
select throws_ok($$select public.workspace_application_thread('00000000-0000-4000-8000-0000000300d1')$$,'P0001','application unavailable','a reclaimed member cannot read the former account private discussion');
reset role;
select * from finish();
rollback;
