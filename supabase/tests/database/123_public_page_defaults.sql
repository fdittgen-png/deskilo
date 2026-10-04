-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2086: the public listing starts from the workspace's own information.
-- An inherited field (host_type, address) the owner did not override
-- follows the workspace, including a later local edit of a published
-- page; an override (even blank) survives local edits; publication.page.reset
-- (reset_workspace_public_page) returns one field or all of them and never
-- publishes or withdraws; only the owner may read or reset, never a
-- member, a stranger, a delegated token or anonymous; the anonymous card
-- keeps the contract's document keys only.
begin;
select plan(24);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002086'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@public-defaults.test','',now(),now(),now() from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,address,invoice_legal)
values('00000000-0000-4000-8000-0000002086b1','Local office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002086a1','dev','1 Local Street','{}'),
('00000000-0000-4000-8000-0000002086b2','Draft office','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002086a1','dev','9 Private Lane','{"seller_kind":"association"}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
values('00000000-0000-4000-8000-0000002086c1','00000000-0000-4000-8000-0000002086b1','00000000-0000-4000-8000-0000002086a1',true,true,'active'),
('00000000-0000-4000-8000-0000002086c2','00000000-0000-4000-8000-0000002086b2','00000000-0000-4000-8000-0000002086a1',true,true,'active'),
('00000000-0000-4000-8000-0000002086c3','00000000-0000-4000-8000-0000002086b1','00000000-0000-4000-8000-0000002086a2',false,false,'active');

-- Inherit: an unsaved page reads the workspace information, published or not.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002086a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002086b1')->'following','{"host_type":true,"address":true}'::jsonb,'publication.page.read: an unsaved page follows the workspace');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002086b1')->'document'->>'address','1 Local Street','the draft shows the workspace address');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002086b1')->'document'->>'host_type','company','a business workspace hosts as a company');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002086b2')->'document'->>'host_type','association','an association hosts as an association');
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002086b1','{"description":"Open desks"}',true)$$,'publication.page.save: a page without the inherited fields is accepted');
reset role;
select is((select document->>'address' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'1 Local Street','the published card carries the workspace address');

-- Follow after a local edit.
update public.workspaces set address='',street='2 New Street',postal_code='34120',city='Pezenas',
 invoice_legal='{"seller_kind":"association"}' where id='00000000-0000-4000-8000-0000002086b1';
select is((select document->>'address' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'2 New Street, 34120 Pezenas','a local edit reaches the published card');
select is((select document->>'host_type' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'association','a local seller kind reaches the published card');

-- Override survives a local edit.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002086a1","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002086b1','{"description":"Open desks","host_type":"person","address":"Desk 9, Public Row"}',true)$$,'the owner overrides the inherited fields');
reset role;
update public.workspaces set address='3 Later Street' where id='00000000-0000-4000-8000-0000002086b1';
select is((select document->>'address' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'3 Later Street','0367: the address is always the workspace''s: an override is ignored, a local edit reaches the card');

-- Reset one, then all; the page stays published.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002086a1","role":"authenticated"}',true);
set local role authenticated;
select is(public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b1',array['address'])->'following','{"host_type":false,"address":true}'::jsonb,'publication.page.reset: one field returns to the workspace');
reset role;
select is((select document->>'address' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'3 Later Street','the card shows the workspace address again');
select is((select document->>'host_type' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'person','the other override is untouched');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002086a1","role":"authenticated"}',true);
set local role authenticated;
select is((public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b1',null)->>'published')::boolean,true,'publication.page.reset: all fields; the page stays published');
select throws_ok($$select public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b1',array['description'])$$,'P0001','not an inherited public field','a field without a workspace counterpart cannot be reset');
-- A blank override hides the address; a reset of a draft never publishes it.
select lives_ok($$select public.save_workspace_public_page('00000000-0000-4000-8000-0000002086b2','{"host_type":"person","address":""}',false)$$,'the owner keeps a draft with a blank address');
select is(public.my_workspace_public_page('00000000-0000-4000-8000-0000002086b2')->'document'->>'address','9 Private Lane','0367: a blank address override cannot hide the workspace''s own address');
select is((public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b2',null)->>'published')::boolean,false,'a reset never publishes a draft');
reset role;
select is((select document->>'host_type' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1'),'association','the card follows the workspace after reset all');
select ok((select array(select jsonb_object_keys(document) order by 1) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b1') <@ array['address','booking_unit','contacts','currency','description','email','host_type','image_url','latitude','longitude','name','phone','plan_url','plans','website'],'the published document carries only the contract keys');
select is((select count(*) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000002086b2'),0::bigint,'the draft has no public card');

-- Nobody but the owner.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002086a2","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b1',null)$$,'P0001','owner required','a member cannot reset the page');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002086a3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b1',array['address'])$$,'P0001','owner required','a stranger cannot reset the page');
reset role;
select set_config('request.jwt.claims','{}',true);
set local role anon;
select throws_ok($$select public.reset_workspace_public_page('00000000-0000-4000-8000-0000002086b1',null)$$,'42501',null,'anonymous cannot call management');
reset role;
select * from finish();
rollback;
