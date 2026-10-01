-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1847: the public network boundary, operation by operation, against the
-- real grants, RLS and RPC bodies. Public (directory.sources.list,
-- directory.workspaces.search/detail): anonymous reads of published cards
-- only, only the granted columns, only the contract's document keys, no
-- draft and no canary. Management (publication.page.read/save): the owner
-- only; anonymous, a stranger, an administrator and a delegated assistant
-- token are refused. Participant (directory.sources.register,
-- workspace.profile.request): signed-in accounts only, and only for a
-- published workspace.
begin;
select plan(31);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001847'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@public-network.test','',now(),now(),now() from unnest(array['a1','a2','a3']) suffix;
update public.profiles set display_name=case right(id::text,2) when 'a1' then 'Network owner' when 'a2' then 'Network admin' else 'Network stranger' end where id::text like '%1847a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment)
values('00000000-0000-4000-8000-0000001847b1','Published office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001847a1','dev'),
('00000000-0000-4000-8000-0000001847b2','Draft office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001847a1','dev');
update public.workspaces set invite_code='CANARY1847INVITE' where id='00000000-0000-4000-8000-0000001847b1';
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000001847c1','00000000-0000-4000-8000-0000001847b1','00000000-0000-4000-8000-0000001847a1',true,true,'active'),
('00000000-0000-4000-8000-0000001847c2','00000000-0000-4000-8000-0000001847b2','00000000-0000-4000-8000-0000001847a1',true,true,'active'),
('00000000-0000-4000-8000-0000001847c3','00000000-0000-4000-8000-0000001847b1','00000000-0000-4000-8000-0000001847a2',false,true,'active');

-- Management: the owner authors one published page and one draft.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847b1','{"host_type":"company","description":"Open desks","address":"1 Public Street"}',true)$$,'publication.page.save: the owner publishes');
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847b2','{"host_type":"company","description":"DRAFT-CANARY-1847","plans":"DRAFT-PRICE-CANARY 42 EUR"}',false)$$,'publication.page.save: the owner keeps a draft');
select is((public.my_workspace_public_page('00000000-0000-4000-8000-0000001847b2')->>'published')::boolean,false,'publication.page.read: the owner reads the draft as unpublished');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000001847b2')->'document'->>'description','DRAFT-CANARY-1847','publication.page.read: the owner reads the draft text');
select throws_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847b1','{"host_type":"company","internal_note":"never public"}',true)$$,'P0001','invalid public field','publication.page.save: an input key the contract does not list is refused');
reset role;

-- Public: anonymous reads.
select set_config('request.jwt.claims','{}',true);
set local role anon;
select is((select count(workspace_id) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001847b1'),1::bigint,'directory.workspaces.detail: anonymous reads the published card');
select is((select count(workspace_id) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001847b2'),0::bigint,'directory.workspaces.detail: anonymous does not read the draft');
select is((select count(workspace_id) from public.public_workspace_cards where search_text ilike '%Public Street%' and workspace_id in ('00000000-0000-4000-8000-0000001847b1','00000000-0000-4000-8000-0000001847b2')),1::bigint,'directory.workspaces.search: anonymous finds the published card by address');
select is((select count(workspace_id) from public.public_workspace_cards where document::text like '%CANARY%' or name like '%CANARY%' or search_text like '%CANARY%'),0::bigint,'no draft, price or invitation canary in any public card');
select ok((select array(select jsonb_object_keys(document) order by 1) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001847b1') <@ array['address','booking_unit','contacts','currency','description','email','host_type','image_url','latitude','longitude','name','phone','plan_url','plans','website'],'the published document carries only the contract keys');
select ok((select document->>'description' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001847b1')='Open desks','the published document carries what the owner published');
select throws_ok($$select company_id from public.public_workspace_cards$$,'42501',null,'anonymous cannot read operator columns of a card');
select throws_ok($$select * from public.workspace_public_pages$$,'42501',null,'anonymous cannot read draft pages');
select lives_ok($$select origin,publishable_key from public.public_directory_sources$$,'directory.sources.list: anonymous reads registered endpoints');
select throws_ok($$select registered_by from public.public_directory_sources$$,'42501',null,'anonymous cannot read who registered an endpoint');
select throws_ok($$select public.my_workspace_public_page('00000000-0000-4000-8000-0000001847b1')$$,'42501',null,'publication.page.read: anonymous cannot call management');
select throws_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847b1','{"host_type":"company"}',false)$$,'42501',null,'publication.page.save: anonymous cannot call management');
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847b1')$$,'42501',null,'workspace.profile.request: anonymous cannot act as a participant');
select throws_ok($$select public.register_public_directory('https://other.example','sb_publishable_anonymous_1847')$$,'42501',null,'directory.sources.register: anonymous cannot register an endpoint');
reset role;

-- A signed-in stranger: public reads yes, management no.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847a3","role":"authenticated"}',true);
set local role authenticated;
select is((select count(workspace_id) from public.public_workspace_cards where workspace_id in ('00000000-0000-4000-8000-0000001847b1','00000000-0000-4000-8000-0000001847b2')),1::bigint,'a signed-in stranger reads the published card and not the draft');
select throws_ok($$select public.my_workspace_public_page('00000000-0000-4000-8000-0000001847b2')$$,'P0001','owner required','publication.page.read: a stranger cannot read the draft');
select throws_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847b1','{"host_type":"person"}',false)$$,'P0001','owner required','publication.page.save: a stranger cannot withdraw the page');
select throws_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847b2')$$,'P0001','workspace not published','workspace.profile.request: a draft cannot be applied to');
select lives_ok($$select public.request_public_workspace_profile('00000000-0000-4000-8000-0000001847b1')$$,'workspace.profile.request: a published workspace can be asked');
select ok(not public.is_member_of('00000000-0000-4000-8000-0000001847b1'),'the request does not grant membership');
select lives_ok($$select public.register_public_directory('https://other-1847.example','sb_publishable_participant_1847')$$,'directory.sources.register: a signed-in account registers an endpoint');
reset role;
select is((select count(workspace_id) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001847b1'),1::bigint,'the stranger''s refused withdrawal left the card published');

-- An administrator is not the owner; a delegated assistant token is not native.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.my_workspace_public_page('00000000-0000-4000-8000-0000001847b1')$$,'P0001','owner required','publication.page.read: an administrator is not the owner');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847a1","role":"authenticated","client_id":"delegate"}',true);
set local role authenticated;
select throws_ok($$select public.my_workspace_public_page('00000000-0000-4000-8000-0000001847b1')$$,'P0001',null,'publication.page.read: a delegated assistant token cannot manage the page');
reset role;

-- The owner withdraws; the public read answers no row at once.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001847a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000001847b1','{"host_type":"company"}',false)$$,'publication.page.save: the owner withdraws');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select is((select count(workspace_id) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001847b1'),0::bigint,'directory.workspaces.detail: a withdrawn card is no row');
reset role;
select * from finish();
rollback;
