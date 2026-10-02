-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1869 B: an issuer's chart of accounts and the account each posting role
-- books to. Codes keep their leading zeroes and are unique per issuer;
-- a role maps only to a posting account of the type that fits it, in the
-- same issuer's chart; a mapped account is neither deleted nor re-coded;
-- mappings are versioned; a local book cannot start before customers,
-- revenue and bank are mapped. Members, other workspaces and direct
-- table reads get nothing; with the flag off nothing new is written and
-- the chart stays readable.
begin;
select plan(28);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001870'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@chart.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000001870b1','Chart one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001870a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}'),
 ('00000000-0000-4000-8000-0000001870b2','Chart two','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001870a3','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001870c1','00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001870c2','00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001870c3','00000000-0000-4000-8000-0000001870b2','00000000-0000-4000-8000-0000001870a3',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id) values
 ('00000000-0000-4000-8000-0000001870d1','00000000-0000-4000-8000-0000001870b1','Atelier','111'),
 ('00000000-0000-4000-8000-0000001870d2','00000000-0000-4000-8000-0000001870b1','Annexe','222'),
 ('00000000-0000-4000-8000-0000001870d3','00000000-0000-4000-8000-0000001870b2','Autre','333');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001870a1","role":"authenticated"}',true);
set local role authenticated;
select set_config('t.cust', public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'411000','Clients','asset',true,'suggested',0)->>'id', true);
select set_config('t.rev', public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'706000','Prestations','income',true,'suggested',0)->>'id', true);
select set_config('t.bank', public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'512000','Banque','asset',true,'manual',0)->>'id', true);
select set_config('t.group', public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'41','Tiers','asset',false,'manual',0)->>'id', true);
select set_config('t.other', public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d2',
  null,'411000','Clients annexe','asset',true,'manual',0)->>'id', true);
select is(jsonb_array_length(public.book_chart('00000000-0000-4000-8000-0000001870b1')->'accounts'),5,'five accounts across two issuers');
select is((public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'0100','Capital','equity',true,'manual',0))->>'code','0100','a code keeps its leading zero');
select throws_ok($$select public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'41 1','Bad','asset',true,'manual',0)$$,'22023',null,'a code has no space');
select throws_ok($$select public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'411000','Twice','asset',true,'manual',0)$$,'23505',null,'a code is unique within one issuer''s chart');

select lives_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'customers',%L,'2026-01-01',0)$$, current_setting('t.cust')),'customers maps to a receivable');
select throws_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'revenue',%L,'2026-01-01',0)$$, current_setting('t.cust')),'22023',null,'revenue never books to an asset');
select throws_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'customers',%L,'2026-02-01',0)$$, current_setting('t.group')),'22023',null,'a grouping account takes no postings');
select throws_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'customers',%L,'2026-02-01',0)$$, current_setting('t.other')),'42501',null,'one issuer never books into another''s chart');
select throws_ok(format($$select public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  %L,'411001','Clients','asset',true,'suggested',1)$$, current_setting('t.cust')),'55006',null,'a mapped account keeps its code');
select is((public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  current_setting('t.cust')::uuid,'411000','Clients et comptes rattachés','asset',true,'suggested',1))->>'name',
  'Clients et comptes rattachés','but may be renamed');
select throws_ok(format($$select public.delete_book_account('00000000-0000-4000-8000-0000001870b1',%L,2)$$,
  current_setting('t.cust')),'55006',null,'a mapped account cannot be deleted');
select lives_ok(format($$select public.delete_book_account('00000000-0000-4000-8000-0000001870b1',%L,1)$$,
  current_setting('t.group')),'an unused account can');

-- the local book waits for its required mappings
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'local_book','','EUR',1,1,'accrual','2026-07-01',0)$$,'22023',null,'no local book before revenue and bank are mapped');
select lives_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'external_book','DATEV','EUR',1,1,'accrual','2026-07-01',0)$$,'an external book needs no mapping');
select lives_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'revenue',%L,'2026-01-01',0)$$, current_setting('t.rev')),'revenue mapped');
select lives_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'bank',%L,'2026-03-01',0)$$, current_setting('t.bank')),'bank mapped from March');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'local_book','','EUR',1,1,'accrual','2026-02-01',0)$$,'22023',null,'a local book from February misses the March bank mapping');
select lives_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'local_book','','EUR',1,1,'accrual','2026-09-01',0)$$,'with the three roles mapped, the local book starts');

select lives_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'customers',%L,'2027-01-01',0)$$, current_setting('t.cust')),'a later mapping version');
select is((select count(*) from jsonb_array_elements(public.book_chart('00000000-0000-4000-8000-0000001870b1')->'mappings') m
  where m->>'role'='customers'),2::bigint,'and the earlier one stays as it was');
select throws_ok(format($$select public.save_book_mapping('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  'customers',%L,'2026-01-01',0)$$, current_setting('t.cust')),'40001',null,'a stale mapping save writes nothing');

select throws_ok($$select public.save_book_account('00000000-0000-4000-8000-0000001870b2','00000000-0000-4000-8000-0000001870d3',
  null,'411000','Clients','asset',true,'manual',0)$$,'42501',null,'an owner of W1 writes nothing in W2');
select throws_ok($$select * from public.book_accounts$$,'42501',null,'accounts are never read directly');
select throws_ok($$select * from public.book_mappings$$,'42501',null,'nor mappings');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001870a2","role":"authenticated"}',true);
select throws_ok($$select public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'607','Achats','expense',true,'manual',0)$$,'42501',null,'a plain member writes no account');
select throws_ok($$select public.book_chart('00000000-0000-4000-8000-0000001870b1')$$,'42501',null,'nor reads the chart');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"accountingBook":false}'
 where id='00000000-0000-4000-8000-0000001870b1';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001870a1","role":"authenticated"}',true);
select throws_ok($$select public.save_book_account('00000000-0000-4000-8000-0000001870b1','00000000-0000-4000-8000-0000001870d1',
  null,'607','Achats','expense',true,'manual',0)$$,'42501',null,'flag off: no new account');
select is(jsonb_array_length(public.book_chart('00000000-0000-4000-8000-0000001870b1')->'accounts'),5,'flag off: the chart stays readable');

select * from finish();
rollback;
