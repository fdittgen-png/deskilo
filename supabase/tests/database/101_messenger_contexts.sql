-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1824: every message belongs to a context, and the context decides who
-- reads it. An inquiry is read by exactly the person who asked and the
-- space's hosts (owners, and administrators who opted in as public
-- contacts) -- not a hidden administrator, not a member. A forward is
-- read only in its target; the source records the event and its
-- conversation gets a notice; a locked message and a space with
-- forwarding off refuse; the history of a forward shows its provenance
-- and nothing of the original's story. Account messages gain read
-- receipts, unread counts and deleting one's own; one inbox lists every
-- context; a screen capture is announced unless the space switched the
-- protection off; the event table is never read directly.
begin;
select plan(51);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001824'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@contexts.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6']) suffix;
update public.profiles set display_name = 'Msg'||right(id::text,2) where id::text like '%0000001824a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000001824b1','Context space','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001824a1','dev');
-- a1 owner (host), a2 administrator and public contact (host), a3
-- administrator NOT a public contact, a4 outside, a5 and a6 members.
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001824c1','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001824c2','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824a2',false,true,'active'),
 ('00000000-0000-4000-8000-0000001824c3','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824a3',false,true,'active'),
 ('00000000-0000-4000-8000-0000001824c5','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824a5',false,false,'active'),
 ('00000000-0000-4000-8000-0000001824c6','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824a6',false,false,'active');
insert into public.member_public_contact(member_id,visible) values ('00000000-0000-4000-8000-0000001824c2',true);
insert into public.conversations(id,workspace_id,kind,title,created_by) values
 ('00000000-0000-4000-8000-0000001824d1','00000000-0000-4000-8000-0000001824b1','group','Source group','00000000-0000-4000-8000-0000001824c5'),
 ('00000000-0000-4000-8000-0000001824d2','00000000-0000-4000-8000-0000001824b1','group','Target group','00000000-0000-4000-8000-0000001824c5');
insert into public.conversation_participants(conversation_id,member_id) values
 ('00000000-0000-4000-8000-0000001824d1','00000000-0000-4000-8000-0000001824c5'),
 ('00000000-0000-4000-8000-0000001824d1','00000000-0000-4000-8000-0000001824c6'),
 ('00000000-0000-4000-8000-0000001824d2','00000000-0000-4000-8000-0000001824c5'),
 ('00000000-0000-4000-8000-0000001824d2','00000000-0000-4000-8000-0000001824c3');
insert into public.member_notes(id,workspace_id,from_member_id,to_member_id,body,conversation_id) values
 ('00000000-0000-4000-8000-0000001824e1','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824c5',null,'The plan','00000000-0000-4000-8000-0000001824d1'),
 ('00000000-0000-4000-8000-0000001824e2','00000000-0000-4000-8000-0000001824b1','00000000-0000-4000-8000-0000001824c6',null,'Mine alone','00000000-0000-4000-8000-0000001824d1');

-- ── inquiries ──
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001824b1','{"host_type":"company"}',true)$$,'the owner publishes the page');
select throws_ok($$select public.start_space_inquiry('00000000-0000-4000-8000-0000001824b1','Me?')$$,'P0001','you host this space','a host does not inquire of their own space');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a4","role":"authenticated"}',true);
select is(jsonb_array_length(public.space_host_roster('00000000-0000-4000-8000-0000001824b1')),2,'the roster names the owner and the public administrator');
select ok(not (public.space_host_roster('00000000-0000-4000-8000-0000001824b1') @> '[{"name":"Msga3"}]'),'the hidden administrator is not on the roster');
select set_config('t.inquiry', public.start_space_inquiry('00000000-0000-4000-8000-0000001824b1','Can I visit?')::text, true);
select is(jsonb_array_length(public.my_inquiries()),1,'the requester sees their inquiry');
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inquiry')::uuid)),1,'the requester reads it');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a1","role":"authenticated"}',true);
select is((public.workspace_inquiries('00000000-0000-4000-8000-0000001824b1')->0->>'unread')::int,1,'the owner sees one unread inquiry message');
select lives_ok(format('select public.mark_inquiry_read(%L)',current_setting('t.inquiry')),'the owner opens it');
select lives_ok(format('select public.send_inquiry_message(%L,%L)',current_setting('t.inquiry'),'Yes, tomorrow'),'the owner answers');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a2","role":"authenticated"}',true);
select is(jsonb_array_length(public.inquiry_messages(current_setting('t.inquiry')::uuid)),2,'the public administrator reads the inquiry');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a3","role":"authenticated"}',true);
select throws_ok(format('select public.inquiry_messages(%L)',current_setting('t.inquiry')),'P0001','inquiry unavailable','a hidden administrator does not read the inquiry');
select throws_ok($$select public.workspace_inquiries('00000000-0000-4000-8000-0000001824b1')$$,'P0001','hosts only','a hidden administrator does not list inquiries');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a5","role":"authenticated"}',true);
select throws_ok(format('select public.inquiry_messages(%L)',current_setting('t.inquiry')),'P0001','inquiry unavailable','a member does not read the inquiry');
select throws_ok($$select * from public.space_inquiry_messages$$,'42501',null,'the inquiry table is never read directly');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a4","role":"authenticated"}',true);
select is((public.my_inquiries()->0->>'unread')::int,1,'the requester has one unread answer');
select lives_ok(format('select public.mark_inquiry_read(%L)',current_setting('t.inquiry')),'the requester opens it');
select is((public.my_inquiries()->0->>'unread')::int,0,'and nothing is unread');
select is((select m->>'read_at' from jsonb_array_elements(public.inquiry_messages(current_setting('t.inquiry')::uuid)) m where (m->>'from_requester')::boolean) is not null,true,'the requester''s own message shows the hosts read it');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"spaceInquiries":false}' where id='00000000-0000-4000-8000-0000001824b1';
set local role authenticated;
-- #1851: off stops NEW inquiries; an open one stays answerable (110).
select throws_ok($$select public.start_space_inquiry('00000000-0000-4000-8000-0000001824b1','Again?')$$,'P0001','inquiries unavailable','inquiries off refuses a new inquiry');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"spaceInquiries":true}' where id='00000000-0000-4000-8000-0000001824b1';
-- a4 lets anyone signed in write to them, so a5 can open a personal thread.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a4","role":"authenticated"}',true);
set local role authenticated;
select public.set_contact_availability(true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a5","role":"authenticated"}',true);
select set_config('t.account', public.send_account_message('00000000-0000-4000-8000-0000001824a4','Hello from the space','00000000-0000-4000-8000-0000001824a5')::text, true);

-- ── forwarding ──
select set_config('t.forward', public.forward_message('member_note','00000000-0000-4000-8000-0000001824e1','conversation','00000000-0000-4000-8000-0000001824d2')::text, true);
select is((select forwarded_from->>'author_name' from public.member_notes where id=current_setting('t.forward')::uuid),'Msga5','the copy names the original author');
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001824d1' and notice->>'kind'='forwarded'),1::bigint,'the source conversation gets a notice');
select throws_ok($$select public.set_message_forward_lock('member_note','00000000-0000-4000-8000-0000001824e2',true)$$,'P0001','only the author can lock a message','only the author locks');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a3","role":"authenticated"}',true);
select is((select count(*) from public.member_notes where id=current_setting('t.forward')::uuid),1::bigint,'a participant of the target reads the forward');
select is((select count(*) from public.member_notes where id='00000000-0000-4000-8000-0000001824e1'),0::bigint,'the forward does not open the original to them');
select is((select count(*) from jsonb_array_elements(public.message_history('member_note',current_setting('t.forward')::uuid)) h where h->>'event'='forwarded_from'),1::bigint,'the forward''s history shows its provenance');
select is((select count(*) from jsonb_array_elements(public.message_history('member_note',current_setting('t.forward')::uuid)) h where h->>'event'='forwarded'),0::bigint,'and nothing of the original''s events');
select throws_ok($$select public.message_history('member_note','00000000-0000-4000-8000-0000001824e1')$$,'P0001','message unavailable','nor the original''s history');
select throws_ok($$select * from public.message_events$$,'42501',null,'the event table is never read directly');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a6","role":"authenticated"}',true);
select is((select count(*) from public.member_notes where id=current_setting('t.forward')::uuid),0::bigint,'a source participant outside the target does not read the forward');
select is((select h->'detail'->>'target_label' from jsonb_array_elements(public.message_history('member_note','00000000-0000-4000-8000-0000001824e1')) h where h->>'event'='forwarded'),'Context space · Target group','the source''s history names who forwarded it where');
select lives_ok($$select public.set_message_forward_lock('member_note','00000000-0000-4000-8000-0000001824e2',true)$$,'the author locks their message');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a5","role":"authenticated"}',true);
select throws_ok($$select public.forward_message('member_note','00000000-0000-4000-8000-0000001824e2','conversation','00000000-0000-4000-8000-0000001824d2')$$,'P0001','the author locked this message','a locked message is refused');
select throws_ok($$select public.forward_message('member_note',(select id from public.member_notes where notice is not null limit 1),'conversation','00000000-0000-4000-8000-0000001824d2')$$,'P0001','a notice cannot be forwarded','a notice is not forwarded');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"messageForwarding":false}' where id='00000000-0000-4000-8000-0000001824b1';
set local role authenticated;
select throws_ok($$select public.forward_message('member_note','00000000-0000-4000-8000-0000001824e1','conversation','00000000-0000-4000-8000-0000001824d2')$$,'P0001','forwarding is off in this space','a space with forwarding off refuses');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"messageForwarding":true}' where id='00000000-0000-4000-8000-0000001824b1';
set local role authenticated;
select lives_ok(format('select public.forward_message(%L,%L,%L,%L,%L)','member_note','00000000-0000-4000-8000-0000001824e1','account_conversation',current_setting('t.account'),'00000000-0000-4000-8000-0000001824a5'),'a space message forwards into a personal conversation');
select throws_ok(format('select public.forward_message(%L,%L,%L,%L,%L)','member_note','00000000-0000-4000-8000-0000001824e1','account_conversation',current_setting('t.account'),'00000000-0000-4000-8000-0000001824a6'),'P0001','account changed','a stale account is refused');

-- ── account messages catch up ──
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a4","role":"authenticated"}',true);
select is((public.my_account_conversations()->0->>'unread')::int,2,'the recipient has two unread account messages');
select is((select count(*) from jsonb_array_elements(public.my_account_messages(current_setting('t.account')::uuid)) m where jsonb_typeof(m->'forwarded_from')='object'),1::bigint,'the forward arrives with its origin');
select lives_ok(format('select public.mark_account_conversation_read(%L)',current_setting('t.account')),'the recipient reads the thread');
select is((public.my_account_conversations()->0->>'unread')::int,0,'and nothing is unread');
select throws_ok(format('select public.delete_account_message(%L)',(select id from jsonb_to_recordset(public.my_account_messages(current_setting('t.account')::uuid)) as x(id uuid, is_mine boolean) where not x.is_mine limit 1)),'P0001','only the author can delete a message','the recipient cannot delete the sender''s message');
select is((select count(*) from jsonb_array_elements(public.my_inbox()) i where i->>'context_kind'='inquiry_out'),1::bigint,'the requester''s inbox lists the inquiry');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a5","role":"authenticated"}',true);
select is((select count(*) from jsonb_array_elements(public.my_account_messages(current_setting('t.account')::uuid)) m where (m->>'is_mine')::boolean and m->>'read_at' is not null),2::bigint,'the sender sees both messages read');
select lives_ok(format('select public.delete_account_message(%L)',(select id from jsonb_to_recordset(public.my_account_messages(current_setting('t.account')::uuid)) as x(id uuid, forwarded_from jsonb) where x.forwarded_from is null limit 1)),'the author deletes their own message');
select is((select i->>'peer_id' from jsonb_array_elements(public.my_inbox()) i where i->>'context_kind'='account'),'00000000-0000-4000-8000-0000001824a4','the inbox lists the personal thread with its peer');
select is((select count(*) from jsonb_array_elements(public.my_inbox()) i where i->>'context_kind'='space'),2::bigint,'the inbox lists both space groups');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a2","role":"authenticated"}',true);
select is((select count(*) from jsonb_array_elements(public.my_inbox()) i where i->>'context_kind'='inquiry_in'),1::bigint,'a host''s inbox lists the incoming inquiry');

-- ── screen capture ──
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001824a6","role":"authenticated"}',true);
reset role;
update public.workspaces set feature_flags = feature_flags || '{"captureProtection":false}' where id='00000000-0000-4000-8000-0000001824b1';
set local role authenticated;
select public.record_screen_capture('conversation','00000000-0000-4000-8000-0000001824d1');
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001824d1' and notice->>'kind'='captured'),0::bigint,'with the protection off, a capture is not announced');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"captureProtection":true}' where id='00000000-0000-4000-8000-0000001824b1';
set local role authenticated;
select public.record_screen_capture('conversation','00000000-0000-4000-8000-0000001824d1');
select is((select count(*) from public.member_notes where conversation_id='00000000-0000-4000-8000-0000001824d1' and notice->>'kind'='captured'),1::bigint,'a capture is announced in the conversation');
select throws_ok($$select public.record_screen_capture('conversation','00000000-0000-4000-8000-0000001824d2')$$,'P0001','not in this conversation','a capture is recorded only where one takes part');

reset role;
select ok(not has_function_privilege('anon','public.forward_message(text,uuid,text,uuid,uuid)','execute'),'anonymous callers cannot forward');

select * from finish();
rollback;
