-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Optional public facts, inheritance of configured hours and publication boundaries.
begin;
select plan(28);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002832'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@public-defaults.test','',now(),now(),now() from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,address,invoice_legal)
values('00000000-0000-4000-8000-0000002832b1','Local office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002832a1','dev','1 Local Street','{}'),
('00000000-0000-4000-8000-0000002832b2','Draft office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002832a1','dev','9 Private Lane','{"seller_kind":"association"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000002832c1','00000000-0000-4000-8000-0000002832b1','00000000-0000-4000-8000-0000002832a1',true,true,'active'),
('00000000-0000-4000-8000-0000002832c2','00000000-0000-4000-8000-0000002832b2','00000000-0000-4000-8000-0000002832a1',true,true,'active'),
('00000000-0000-4000-8000-0000002832c3','00000000-0000-4000-8000-0000002832b1','00000000-0000-4000-8000-0000002832a2',false,true,'active');

update public.workspaces set booking_rules='{"open_weekdays":[1,2,3,4,5],"work_start_minutes":480,"work_end_minutes":1080}' where id='00000000-0000-4000-8000-0000002832b1';
update public.workspaces set feature_flags=feature_flags||'{"placeBooking":false}'::jsonb where id='00000000-0000-4000-8000-0000002832b2';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":["wifi","meeting_room"],"accessibility":["step_free_entrance"],"description":"Before"}',true,'patch')$q$,'catalogue arrays accepted');
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":"After"}',true,'patch')$q$,'description patch accepted');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document'->'amenities','["wifi","meeting_room"]'::jsonb,'unedited amenities survive');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document'->'accessibility','["step_free_entrance"]'::jsonb,'unedited accessibility survives');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document'->'opening_hours','{"weekdays":[1,2,3,4,5],"start_minutes":480,"end_minutes":1080,"timezone":"Europe/Paris"}'::jsonb,'configured place hours follow booking rules');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"opening_hours":"Other hours"}',true,'patch')$q$,'P0001','opening hours follow availability','place hours cannot acquire a duplicate');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":"wifi"}',true,'patch')$q$,'P0001','invalid public facts','string instead of array refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":[1]}',true,'patch')$q$,'P0001','invalid public facts','non-string item refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":["unknown"]}',true,'patch')$q$,'P0001','invalid public facts','unknown catalogue id refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":["wifi","wifi"]}',true,'patch')$q$,'P0001','invalid public facts','duplicate id refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":["wifi","meeting_room","kitchen","printer","parking","bike_parking","wifi"]}',true,'patch')$q$,'P0001','invalid public facts','overlong array refused');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document'->'amenities','["wifi","meeting_room"]'::jsonb,'invalid writes preserve prior facts');
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":[],"accessibility":null}',true,'patch')$q$,'empty and clear accepted');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document'->'amenities','[]'::jsonb,'empty array remains an array');
select ok(not (public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document') ? 'accessibility','cleared accessibility is unknown, not false');
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b2','{"opening_hours":"By appointment"}',true,'patch')$q$,'business without places publishes a note');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b2')->'document'->'opening_hours','{"note":"By appointment","timezone":"Europe/Paris"}'::jsonb,'note includes the business timezone');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b2',jsonb_build_object('opening_hours',repeat('x',4001)),true,'patch')$q$,'P0001','invalid public field','overlong hours note refused');
reset role;
update public.workspaces set booking_rules=jsonb_set(booking_rules,'{work_end_minutes}','1020'),timezone='Europe/Zurich' where id='00000000-0000-4000-8000-0000002832b1';
set local role anon;
select is((select document->'opening_hours'->>'end_minutes' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002832b1'),'1020','anonymous card follows changed hours');
select is((select document->'opening_hours'->>'timezone' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002832b1'),'Europe/Zurich','anonymous card follows changed timezone');
select ok(public.public_network_descriptor()->'capabilities' ? 'profile_facets','descriptor advertises optional profile facets');
reset role;
select is((select document->>'description' from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b2'),null,'other workspace description untouched');
select is(public.public_opening_hours('{}','Europe/Paris',null,true),null,'unconfigured hours are unknown');
select is(public.public_opening_hours('{"open_weekdays":[8],"work_start_minutes":480,"work_end_minutes":1080}','Europe/Paris',null,true),null,'malformed stored hours are not published');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":["wifi"]}',true,'patch')$q$,'P0001','owner required','admin without ownership cannot publish facts');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"amenities":["wifi"]}',true,'patch')$q$,'42501',null,'anonymous cannot publish facts');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{}',false,'patch')$q$,'withdrawal accepted');
reset role;
set local role anon;
select is((select count(*) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002832b1'),0::bigint,'withdrawn facets absent to anonymous visitors');
reset role;
select * from finish();
rollback;
