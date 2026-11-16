-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3553 (1a): the public document says what a business is and offers. Its
-- kinds, primary first; its services, published only when active AND marked
-- public, each price in its own currency with its tax treatment (included
-- for a VAT-registered business, excluded for a sales-tax seller, none
-- where no tax applies); whether it takes inquiries. The card and its search
-- text come from one projection: a hidden service is never found by its
-- name, a private business without a published page keeps its minimal card.
-- A service, a kind, the VAT regime changing refreshes the card in the same
-- transaction, without saving the page.
begin;
select plan(28);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000003553a1','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','owner@kinds-3553.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,vat_regime,feature_flags)
values
 ('00000000-0000-4000-8000-0000003553b1','Atelier 3553','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003553a1','dev','vat_registered','{"spaceInquiries":true}'),
 ('00000000-0000-4000-8000-0000003553b2','Zurich practice 3553','CH','CHF','Europe/Zurich','00000000-0000-4000-8000-0000003553a1','dev','not_subject','{}'),
 ('00000000-0000-4000-8000-0000003553b3','New York house 3553','US','USD','America/New_York','00000000-0000-4000-8000-0000003553a1','dev','not_subject','{"salesTax":true}'),
 ('00000000-0000-4000-8000-0000003553b4','Private 3553','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003553a1','dev','vat_registered','{"publicListings":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status)
select ('00000000-0000-4000-8000-0000003553c'||n)::uuid,('00000000-0000-4000-8000-0000003553b'||n)::uuid,
 '00000000-0000-4000-8000-0000003553a1',true,true,'active' from generate_series(1,4) n;
insert into public.setting_values(scope,workspace_id,key,value) values
 ('workspace','00000000-0000-4000-8000-0000003553b1','business.kind','"studio"'),
 ('workspace','00000000-0000-4000-8000-0000003553b1','business.more_kinds','"coworking"'),
 ('workspace','00000000-0000-4000-8000-0000003553b2','business.kind','"practice"');
insert into public.services(id,workspace_id,name,price_cents,active,is_public,category,duration_minutes,sort_order) values
 ('00000000-0000-4000-8000-0000003553d1','00000000-0000-4000-8000-0000003553b1','Yoga flow',2500,true,true,'Classes',60,1),
 ('00000000-0000-4000-8000-0000003553d2','00000000-0000-4000-8000-0000003553b1','SECRET-UNPUBLISHED-3553',1000,true,false,null,null,2),
 ('00000000-0000-4000-8000-0000003553d3','00000000-0000-4000-8000-0000003553b1','INACTIVE-3553',1000,false,true,null,null,3),
 ('00000000-0000-4000-8000-0000003553d4','00000000-0000-4000-8000-0000003553b2','Massage',9500,true,true,'Body',60,1),
 ('00000000-0000-4000-8000-0000003553d5','00000000-0000-4000-8000-0000003553b3','Desk day',3000,true,true,null,null,1),
 ('00000000-0000-4000-8000-0000003553d6','00000000-0000-4000-8000-0000003553b4','HIDDEN-PRIVATE-3553',1000,true,true,null,null,1);

-- The owner publishes three pages; the fourth business is private and has
-- none, so its card is the minimal one.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003553a1","role":"authenticated"}',true);
set local role authenticated;
select public.save_workspace_public_page(('00000000-0000-4000-8000-0000003553b'||n)::uuid,'{"host_type":"company"}',true)
  from generate_series(1,3) n;
select public.set_workspace_visibility('00000000-0000-4000-8000-0000003553b4', 'private');
reset role;

-- What anonymous reads.
select set_config('request.jwt.claims','{}',true);
set local role anon;
select is((select document->'kinds' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 '["studio","coworking"]'::jsonb,'kinds: the primary kind first, then the further ones');
select is((select jsonb_array_length(document->'services') from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 1,'services: only the active and public one');
select is((select document->'services'->0 from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 '{"name":"Yoga flow","category":"Classes","duration_minutes":60,"price_minor":2500,"currency":"EUR","tax_treatment":"included"}'::jsonb,
 'a published service: name, category, duration, price, its currency, included for a VAT-registered business');
select is((select document->'services'->0->>'tax_treatment' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b2'),
 'none','a business no tax applies to: none');
select is((select document->'services'->0->>'currency' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b2'),
 'CHF','each price carries its own currency');
select is((select document->'services'->0->>'tax_treatment' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b3'),
 'excluded','a sales-tax seller: the tax is added at the sale');
select is((select document->>'takes_inquiries' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'true','whether the business takes inquiries');
select is((select count(*) from public.public_workspace_cards where search_text ilike '%Yoga flow%' and workspace_id='00000000-0000-4000-8000-0000003553b1'),
 1::bigint,'search: a published service finds its business (positive control)');
select is((select count(*) from public.public_workspace_cards where search_text ilike '%Classes%' and workspace_id='00000000-0000-4000-8000-0000003553b1'),
 1::bigint,'search: a service category finds its business');
select is((select count(*) from public.public_workspace_cards where document::text like '%SECRET-UNPUBLISHED-3553%' or search_text like '%SECRET-UNPUBLISHED-3553%'
  or document::text like '%INACTIVE-3553%' or search_text like '%INACTIVE-3553%'),
 0::bigint,'an unpublished or inactive service is neither shown nor found');
select is((select array(select jsonb_object_keys(document) order by 1) from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b4'),
 array['address','host_type','name'],'a private business without a published page keeps its minimal card');
select is((select count(*) from public.public_workspace_cards where search_text like '%HIDDEN-PRIVATE-3553%'),
 0::bigint,'and none of its service names reaches the search');
select is((select count(*) from public.public_workspace_cards where document->'kinds' ? 'practice' and name like '%3553%'),
 1::bigint,'the kind filter returns only that kind');
select is((select name from public.public_workspace_cards where document->'kinds' ? 'practice' and name like '%3553%'),
 'Zurich practice 3553','the practice');
reset role;

-- Changes reach the card in the same transaction, without saving the page.
update public.services set is_public=true where id='00000000-0000-4000-8000-0000003553d2';
select ok((select search_text like '%SECRET-UNPUBLISHED-3553%' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'a service marked public is found at once');
update public.services set is_public=false where id='00000000-0000-4000-8000-0000003553d2';
select ok((select not (document::text like '%SECRET-UNPUBLISHED-3553%' or search_text like '%SECRET-UNPUBLISHED-3553%') from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'a service withdrawn leaves the card and the search at once');
update public.services set name='Yoga slow', price_cents=2700 where id='00000000-0000-4000-8000-0000003553d1';
select is((select document->'services'->0->>'name' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'Yoga slow','a renamed service is renamed on the card');
select ok((select search_text like '%Yoga slow%' and search_text not like '%Yoga flow%' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'and in the search, the old name gone');
select is((select (document->'services'->0->>'price_minor')::int from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 2700,'a new price is on the card');
update public.services set active=false where id='00000000-0000-4000-8000-0000003553d1';
select is((select jsonb_array_length(document->'services') from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 0,'a deactivated service leaves the card');
update public.services set active=true where id='00000000-0000-4000-8000-0000003553d1';
delete from public.services where id='00000000-0000-4000-8000-0000003553d1';
select ok((select search_text not like '%Yoga%' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'a deleted service leaves the search');
update public.setting_values set value='"salon"' where workspace_id='00000000-0000-4000-8000-0000003553b1' and key='business.kind';
select is((select document->'kinds'->>0 from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'salon','a new kind reaches the card');
update public.workspaces set vat_regime='vat_registered' where id='00000000-0000-4000-8000-0000003553b2';
select is((select document->'services'->0->>'tax_treatment' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b2'),
 'included','a business that registers for VAT: its prices include it');
update public.workspaces set feature_flags=feature_flags||'{"spaceInquiries":false}' where id='00000000-0000-4000-8000-0000003553b1';
select is((select document->>'takes_inquiries' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'false','a business that stops taking inquiries says so');

-- A card is refreshed by whoever changed something, member or not: the
-- kinds are read all the same.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000003553a9","role":"authenticated"}',true);
select lives_ok($$update public.workspaces set feature_flags=feature_flags||'{"spaceInquiries":true}' where id='00000000-0000-4000-8000-0000003553b1'$$,
 'a card refreshed while a non-member is signed in');
select is((select document->'kinds'->>0 from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b1'),
 'salon','still carries its kinds');
select set_config('request.jwt.claims','{}',true);

-- Twelve at most, in the business's own order.
insert into public.services(workspace_id,name,price_cents,active,is_public,sort_order)
select '00000000-0000-4000-8000-0000003553b2','Extra '||lpad(n::text,2,'0'),100,true,true,n+1 from generate_series(1,14) n;
select is((select jsonb_array_length(document->'services') from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b2'),
 12,'twelve services at most');
select ok((select search_text not like '%Extra 14%' from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000003553b2'),
 'the search covers the published twelve only');

select * from finish();
rollback;
