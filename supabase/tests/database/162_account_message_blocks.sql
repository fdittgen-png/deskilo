-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2211: every personal-message producer respects either participant's block.
-- Real authenticated RPCs prove forwarding and capture notices cannot bypass
-- direct-send refusals; unblock restores delivery and requests retain their
-- one-message bound. Synthetic accounts and all effects roll back.
begin;
select plan(24);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000221100'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@message-blocks.test','',now(),now(),now()
 from unnest(array['a1','b1','c1']) suffix;

create function pg_temp.actor(p_suffix text) returns void language sql as $$
 select set_config('request.jwt.claims',json_build_object('sub',
   '00000000-0000-4000-8000-0000221100'||p_suffix,'role','authenticated')::text,true)::void;
$$;
create function pg_temp.ref(p_name text) returns uuid language sql as $$
 select current_setting('blocks.'||p_name)::uuid;
$$;

set local role authenticated;
select is(current_user::text,'authenticated','commands run without the postgres RLS bypass');
select pg_temp.actor('b1');
select public.set_visibility('reachability','signed_in');
select pg_temp.actor('c1');
select public.set_visibility('reachability','signed_in');
select pg_temp.actor('a1');
select set_config('blocks.source',public.send_account_message(
 '00000000-0000-4000-8000-0000221100c1','Source','00000000-0000-4000-8000-0000221100a1')::text,true);
select set_config('blocks.target',public.send_account_message(
 '00000000-0000-4000-8000-0000221100b1','Existing conversation','00000000-0000-4000-8000-0000221100a1')::text,true);
select set_config('blocks.message',public.my_account_messages(pg_temp.ref('source'))->0->>'id',true);
select lives_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('target'),auth.uid())$$,'forward to an accepted conversation succeeds');
select is(jsonb_array_length(public.my_account_messages(pg_temp.ref('target'))),2,'forward arrives once');

select pg_temp.actor('b1');
select lives_ok($$select public.block_account('00000000-0000-4000-8000-0000221100a1')$$,'recipient blocks sender');
select is(jsonb_array_length(public.my_blocks()),1,'recipient sees their block');
select pg_temp.actor('a1');
select throws_ok($$select public.send_account_message('00000000-0000-4000-8000-0000221100b1',
 'Blocked',auth.uid())$$,'P0001','recipient unavailable','direct send is refused opaquely');
select throws_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('target'),auth.uid())$$,'P0001','recipient unavailable','forward cannot bypass a recipient block');
select throws_ok($$select public.record_screen_capture('account_conversation',pg_temp.ref('target'))$$,
 'P0001','recipient unavailable','capture notices cannot bypass a recipient block');
select is(jsonb_array_length(public.my_account_messages(pg_temp.ref('target'))),2,'refusals preserve historical messages without new deliveries');
select ok(not (public.visible_account('00000000-0000-4000-8000-0000221100b1')->>'can_message')::boolean,
 'blocked conversation is not advertised as writable');

select pg_temp.actor('b1');
select public.unblock_account('00000000-0000-4000-8000-0000221100a1');
select pg_temp.actor('a1');
select lives_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('target'),auth.uid())$$,'unblock restores forwarding');
select public.block_account('00000000-0000-4000-8000-0000221100b1');
select throws_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('target'),auth.uid())$$,'P0001','recipient unavailable','the senders own block also prevents forwarding');
select is(jsonb_array_length(public.my_account_messages(pg_temp.ref('target'))),3,'reverse block also leaves message history unchanged');
select public.unblock_account('00000000-0000-4000-8000-0000221100b1');
select lives_ok($$select public.record_screen_capture('account_conversation',pg_temp.ref('target'))$$,
 'unblocked capture notice still works');
select is(jsonb_array_length(public.my_account_messages(pg_temp.ref('target'))),4,'allowed capture creates one notice');

-- C and B have no conversation: B now requires a request from strangers.
select pg_temp.actor('b1');
select public.set_visibility('reachability','my_spaces');
select pg_temp.actor('c1');
select set_config('blocks.request',public.send_account_message(
 '00000000-0000-4000-8000-0000221100b1','Request',auth.uid())::text,true);
select throws_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('request'),auth.uid())$$,'P0001','request pending','pending request cannot be extended by a forward');
select pg_temp.actor('b1');
select is(jsonb_array_length(public.my_message_requests()),1,'recipient sees the request');
select public.respond_to_message_request(pg_temp.ref('request'),false);
select is(jsonb_array_length(public.my_message_requests()),0,'ignored request leaves the recipients queue');
select pg_temp.actor('c1');
select throws_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('request'),auth.uid())$$,'P0001','request pending','ignored and pending refusals are indistinguishable');
select pg_temp.actor('b1');
select lives_ok($$select public.send_account_message('00000000-0000-4000-8000-0000221100c1',
 'I can reply now',auth.uid())$$,'recipient reply accepts the conversation');
select pg_temp.actor('c1');
select lives_ok($$select public.forward_message('account_message',pg_temp.ref('message'),
 'account_conversation',pg_temp.ref('request'),auth.uid())$$,'accepted request allows forwarding');
select is(jsonb_array_length(public.my_account_messages(pg_temp.ref('request'))),3,'request, reply and permitted forward each arrive once');
reset role;
select ok(not has_function_privilege('authenticated','public.account_message_request_guard()','execute'),
 'the shared insert guard remains private');
select ok(not has_function_privilege('anon','public.forward_message(text,uuid,text,uuid,uuid)','execute'),
 'forwarding remains unavailable anonymously');
select * from finish();
rollback;
