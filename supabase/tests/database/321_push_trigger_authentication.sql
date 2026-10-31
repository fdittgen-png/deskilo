-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Every database push caller carries the Vault secret; opaque acceptance is
-- not evidence of delivery. Legacy unconfigured installations still queue.
begin;
select plan(13);
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003092' || lpad(n::text,4,'0'))::uuid;
$$;
-- Hide any existing installation secret inside this rolled-back fixture.
select vault.update_secret(id, new_name => name || '_test_hidden_' || gen_random_uuid()::text)
 from vault.secrets where name='deskilo_push_shared_secret';
select ok(not (public.push_delivery_headers('public-test-key') ? 'x-deskilo-push-secret'),'unconfigured installations keep the legacy headers');
select ok(not has_function_privilege('anon','public.push_delivery_headers(text)','execute'),'anonymous clients cannot extract the push secret');
select ok(not has_function_privilege('authenticated','public.push_delivery_headers(text)','execute'),'members cannot extract the push secret');
select ok(has_function_privilege('service_role','public.push_delivery_headers(text)','execute'),'the service role retains the trusted path');
select vault.create_secret('test-only-push-secret','deskilo_push_shared_secret');
insert into public.push_config(id,functions_url,anon_key) values(true,'https://push-fixture.example.test','public-test-key')
 on conflict(id) do update set functions_url=excluded.functions_url,anon_key=excluded.anon_key;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values(pg_temp.u(1),'00000000-0000-0000-0000-000000000000','authenticated','authenticated','push-security@example.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,feature_flags)
values(pg_temp.u(101),'Push security','FR','EUR','Europe/Paris',pg_temp.u(1),'{"eventsTab":true,"memberNotifications":true,"dunning":true,"paymentReminders":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values(pg_temp.u(201),pg_temp.u(101),pg_temp.u(1),true,true,'active');
insert into public.invoices(id,workspace_id,member_id,issuer_member_id,number,title,lines,total_cents,currency,member_name,workspace_name,issuer_name,signature,issued_at)
values(pg_temp.u(401),pg_temp.u(101),pg_temp.u(201),pg_temp.u(201),'PUSH-TEST','Test','[]',1000,'EUR','Owner','Push security','Owner','fixture',now());
insert into public.reminder_intents(id,workspace_id,invoice_id,level,origin,status,collectible_cents,currency)
values(pg_temp.u(501),pg_temp.u(101),pg_temp.u(401),1,'manual','prepared',1000,'EUR');
insert into public.events(id,workspace_id,type,action,actor_member_id,subject_member_id,status,payload)
values(pg_temp.u(301),pg_temp.u(101),'quota','created',pg_temp.u(201),pg_temp.u(201),'pending','{"days":1}');
insert into public.member_notes(id,workspace_id,from_member_id,to_member_id,body)
values(pg_temp.u(601),pg_temp.u(101),pg_temp.u(201),pg_temp.u(201),'Fixture');
select public.reminder_queue_push(pg_temp.u(501),pg_temp.u(302));
-- END FIXTURE
select is((select count(*)::int from net.http_request_queue where url='https://push-fixture.example.test/send-push' and convert_from(body,'UTF8')::jsonb->>'event_id'=pg_temp.u(301)::text),1,'the pending event trigger queues its push');
select is((select count(*)::int from net.http_request_queue where url='https://push-fixture.example.test/send-push' and convert_from(body,'UTF8')::jsonb->>'note_id'=pg_temp.u(601)::text),1,'the note trigger queues its push');
select is((select count(*)::int from net.http_request_queue where url='https://push-fixture.example.test/send-push' and convert_from(body,'UTF8')::jsonb->>'event_id'=pg_temp.u(302)::text),1,'the reminder path queues its push');
select is((select count(*)::int from net.http_request_queue where url='https://push-fixture.example.test/send-push' and headers->>'x-deskilo-push-secret'='test-only-push-secret'),3,'all three callers carry the Vault secret');
select ok((select bool_and(headers->>'Authorization'='Bearer public-test-key') from net.http_request_queue where url='https://push-fixture.example.test/send-push'),'gateway authorization is retained');
insert into net._http_response(id,status_code,content,timed_out,created)
select net_request_id,202,'{"accepted":true}',false,now() from public.reminder_attempts where intent_id=pg_temp.u(501);
select public.reconcile_reminder_attempts();
select is((select status from public.reminder_intents where id=pg_temp.u(501)),'unknown','opaque acceptance leaves device delivery unknown');
select is((select collectible_cents from public.reminder_intents where id=pg_temp.u(501)),1000,'acceptance changes no collectible amount');
select vault.update_secret(id, new_name => name || '_test_removed_' || gen_random_uuid()::text)
 from vault.secrets where name='deskilo_push_shared_secret';
insert into public.member_notes(id,workspace_id,from_member_id,to_member_id,body)
values(pg_temp.u(602),pg_temp.u(101),pg_temp.u(201),pg_temp.u(201),'Legacy fixture');
select is((select count(*)::int from net.http_request_queue where url='https://push-fixture.example.test/send-push' and convert_from(body,'UTF8')::jsonb->>'note_id'=pg_temp.u(602)::text),1,'a legacy unconfigured installation still queues delivery');
select ok((select not (headers ? 'x-deskilo-push-secret') from net.http_request_queue where url='https://push-fixture.example.test/send-push' and convert_from(body,'UTF8')::jsonb->>'note_id'=pg_temp.u(602)::text),'legacy requests carry no invented secret');
select * from finish();
rollback;
