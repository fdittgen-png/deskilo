-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1822: a group message is read by the people in its conversation, never
-- by every administrator of the space. An owner and an administrator who
-- are not in a group read none of it -- through the table, through
-- my_conversations, through the calendar feed, through their export -- and
-- cannot delete it. A participant reads it; a person who LEFT reads what
-- was said before they left and nothing after; the legacy admin broadcast
-- is still read by owners and administrators and by nobody else.
begin;
select plan(22);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001822'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@group-privacy.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5']) suffix;
update public.profiles set display_name = 'P'||right(id::text,2) where id::text like '%0000001822a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000001822b1','Group privacy','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001822a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001822c1','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001822c2','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822a2',false,true,'active'),
 ('00000000-0000-4000-8000-0000001822c3','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000001822c4','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822a4',false,false,'active'),
 ('00000000-0000-4000-8000-0000001822c5','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822a5',false,false,'active');
-- A group of three members; the owner and the administrator are not in it.
insert into public.conversations(id,workspace_id,kind,title,created_by) values
 ('00000000-0000-4000-8000-0000001822d1','00000000-0000-4000-8000-0000001822b1','group','Private group','00000000-0000-4000-8000-0000001822c3'),
 ('00000000-0000-4000-8000-0000001822d2','00000000-0000-4000-8000-0000001822b1','direct',null,'00000000-0000-4000-8000-0000001822c3');
insert into public.conversation_participants(conversation_id,member_id,is_admin,joined_at,left_at) values
 ('00000000-0000-4000-8000-0000001822d1','00000000-0000-4000-8000-0000001822c3',true, now()-interval '3 hours',null),
 ('00000000-0000-4000-8000-0000001822d1','00000000-0000-4000-8000-0000001822c4',false,now()-interval '3 hours',now()-interval '1 hour'),
 ('00000000-0000-4000-8000-0000001822d1','00000000-0000-4000-8000-0000001822c5',false,now()-interval '3 hours',null),
 ('00000000-0000-4000-8000-0000001822d2','00000000-0000-4000-8000-0000001822c3',false,now()-interval '3 hours',null),
 ('00000000-0000-4000-8000-0000001822d2','00000000-0000-4000-8000-0000001822c5',false,now()-interval '3 hours',null);
-- e1 before a4 left, e2 after; e3 the legacy broadcast; e4 a direct note.
insert into public.member_notes(id,workspace_id,from_member_id,to_member_id,body,conversation_id,created_at) values
 ('00000000-0000-4000-8000-0000001822e1','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822c3',null,'Before the exit','00000000-0000-4000-8000-0000001822d1',now()-interval '2 hours'),
 ('00000000-0000-4000-8000-0000001822e2','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822c5',null,'After the exit','00000000-0000-4000-8000-0000001822d1',now()-interval '30 minutes'),
 ('00000000-0000-4000-8000-0000001822e3','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822c2',null,'To every admin',null,now()-interval '20 minutes'),
 ('00000000-0000-4000-8000-0000001822e4','00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822c3','00000000-0000-4000-8000-0000001822c5','Just us','00000000-0000-4000-8000-0000001822d2',now()-interval '10 minutes');

-- The administrator outside the group.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001822a2","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001822d1'),0::bigint,'an administrator outside the group reads none of its messages');
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001822e4'),0::bigint,'an administrator reads no direct message between two others');
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001822e3'),1::bigint,'the administrator still reads the admin broadcast');
select is((select count(*) from public.my_conversations('00000000-0000-4000-8000-0000001822b1') c where c.id='00000000-0000-4000-8000-0000001822d1'),0::bigint,'my_conversations lists no group the administrator is not in');
select is((select count(*) from jsonb_array_elements(public.calendar_items('00000000-0000-4000-8000-0000001822b1',now()-interval '1 day',now()+interval '1 day',array['message'],'00000000-0000-4000-8000-0000001822c3')->'items') i where i->'link'->>'id'='00000000-0000-4000-8000-0000001822d1'),0::bigint,'another member''s calendar shows the administrator none of the group');
select is((select count(*) from jsonb_array_elements(public.export_my_data('00000000-0000-4000-8000-0000001822b1')->'messages_sent') m where m->>'conversation_id'='00000000-0000-4000-8000-0000001822d1'),0::bigint,'the administrator''s export carries none of the group');
delete from public.member_notes where id='00000000-0000-4000-8000-0000001822e1';
-- The owner outside the group.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001822a1","role":"authenticated"}',true);
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001822d1'),0::bigint,'the owner outside the group reads none of its messages');
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001822e3'),1::bigint,'the owner still reads the admin broadcast');
delete from public.member_notes where id='00000000-0000-4000-8000-0000001822e2';
reset role;
select is((select count(*) from public.member_notes where id in ('00000000-0000-4000-8000-0000001822e1','00000000-0000-4000-8000-0000001822e2')),2::bigint,'neither the owner nor the administrator could delete a group message');

-- A participant.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001822a5","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001822d1'),2::bigint,'a participant reads the whole group');
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001822e3'),0::bigint,'a member who is no administrator does not read the broadcast');
select is((select unread from public.my_conversations('00000000-0000-4000-8000-0000001822b1') c where c.id='00000000-0000-4000-8000-0000001822d1'),1,'the participant''s unread count counts the other''s message');
select is((select count(*) from jsonb_array_elements(public.calendar_items('00000000-0000-4000-8000-0000001822b1',now()-interval '1 day',now()+interval '1 day',array['message'],null)->'items') i where i->'link'->>'id'='00000000-0000-4000-8000-0000001822d1'),2::bigint,'the participant''s own calendar shows the group');
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001822e4'),1::bigint,'the direct recipient reads the direct message');

-- The person who left an hour ago.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001822a4","role":"authenticated"}',true);
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001822d1'),1::bigint,'a person who left reads one message of the group');
select is((select id from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001822d1'),'00000000-0000-4000-8000-0000001822e1'::uuid,'and it is the one from before they left');
select is((select count(*) from jsonb_array_elements(public.calendar_items('00000000-0000-4000-8000-0000001822b1',now()-interval '1 day',now()+interval '1 day',array['message'],null)->'items') i where i->'link'->>'id'='00000000-0000-4000-8000-0000001822d1'),1::bigint,'their calendar shows only what came before they left');

-- The participant who wrote the first message: sender and member.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001822a3","role":"authenticated"}',true);
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001822d1'),2::bigint,'the group''s creator reads the whole group');
delete from public.member_notes where id='00000000-0000-4000-8000-0000001822e1';
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001822e1'),0::bigint,'a sender still deletes their own group message');

-- The function answers for the caller only.
reset role;
select ok(not has_function_privilege('anon','public.can_read_member_note(uuid,uuid,uuid,uuid,timestamptz)','execute'),'anonymous callers cannot ask the reading rule');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001822a2","role":"authenticated"}',true);
set local role authenticated;
select ok(not public.can_read_member_note('00000000-0000-4000-8000-0000001822b1','00000000-0000-4000-8000-0000001822c5',null,'00000000-0000-4000-8000-0000001822d1',now()),'the rule answers false for an administrator outside the group');
reset role;
select is((select count(*) from pg_policy where polrelid='public.member_notes'::regclass and polname in ('member_notes_select','member_notes_delete') and pg_get_expr(polqual,polrelid) like '%is_admin%'),0::bigint,'neither policy carries an administrator clause');

select * from finish();
rollback;
