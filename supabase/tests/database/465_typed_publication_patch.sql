-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Owner-only patch, clear and legacy replacement semantics, through the real RPC.
begin;
select plan(29);
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

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":"Old text","latitude":43.4,"longitude":3.4,"plans":"Keep this","host_type":"person"}',true,'replace')$q$,'numeric coordinates accepted');
reset role;
select is((select jsonb_typeof(document->'latitude') from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b1'),'number','coordinates are stored as numbers');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":"Changed"}',true,'patch')$q$,'description-only patch accepted');
reset role;
select is((select document from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b1'),'{"description":"Changed","latitude":43.4,"longitude":3.4,"plans":"Keep this","host_type":"person"}'::jsonb,'patch preserves every unedited value');
select is(jsonb_typeof(public.public_workspace_document('00000000-0000-4000-8000-0000002832b1')->'latitude'),'string','public v1 decimal representation remains readable');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"host_type":null}',true,'patch')$q$,'null restores inheritance');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'following'->'host_type','true'::jsonb,'cleared host type follows workspace');
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"plans":""}',true,'patch')$q$,'blank text is a stored override');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002832b1')->'document'->>'plans','','blank differs from omission');
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"latitude":null,"longitude":null}',true,'patch')$q$,'both coordinates clear');
reset role;
select ok((select not document ?| array['latitude','longitude'] from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b1'),'clear removes coordinate keys');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"latitude":43.4}',true,'patch')$q$,'P0001','invalid coordinates','half a place refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"latitude":91,"longitude":3}',true,'patch')$q$,'P0001','invalid coordinates','out of range refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":[]}',true,'patch')$q$,'P0001','invalid public field','array in text field refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"latitude":{},"longitude":3}',true,'patch')$q$,'P0001','invalid coordinates','object coordinate refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"latitude":"NaN","longitude":"3"}',true,'patch')$q$,'P0001','invalid coordinates','nonfinite coordinate refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"secret":"never public"}',true,'patch')$q$,'P0001','invalid public field','unknown field refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"website":"http://invalid.example"}',true,'patch')$q$,'P0001','public links require HTTPS','non-HTTPS link refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":"no"}',true,'merge')$q$,'P0001','invalid public page','unknown mode refused');
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1',jsonb_build_object('description',repeat('x',4001)),true,'patch')$q$,'P0001','invalid public field','overlong value refused');
reset role;
select is((select document->>'description' from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b1'),'Changed','refused writes leave prior document unchanged');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":"Legacy","latitude":"43.4","longitude":"3.4"}',true)$q$,'legacy string-only replacement still accepted');
reset role;
select ok((select not document ? 'plans' and jsonb_typeof(document->'latitude')='number' from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b1'),'replacement removes omitted fields and normalizes legacy coordinates');
select is((select count(*) from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000002832b2'),0::bigint,'other workspace remains untouched');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{"description":"Forbidden"}',true,'patch')$q$,'P0001','owner required','administrator without ownership refused');
reset role;
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000002832c4','00000000-0000-4000-8000-0000002832b1','00000000-0000-4000-8000-0000002832a3',false,false,'active');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{}',true,'patch')$q$,'P0001','owner required','ordinary member cannot write');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{}',true,'patch')$q$,'42501',null,'anonymous cannot write');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002832a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($q$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002832b1','{}',false,'patch')$q$,'withdrawal accepted without dropping fields');
reset role;
set local role anon;
select is((select count(*) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002832b1'),0::bigint,'withdrawn card is absent to anonymous readers');
reset role;
select * from finish();
rollback;
