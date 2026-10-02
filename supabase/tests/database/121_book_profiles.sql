-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1869: a book profile is set per issuer by someone who manages billing,
-- with the accountingBook flag accepting new work, against the revision
-- they read. Two issuers of one workspace keep two books; a site of
-- another workspace cannot be named as issuer; a member, another
-- workspace's owner and a direct table read get nothing; switching the
-- flag off stops new profiles but leaves the configured ones readable.
begin;
select plan(22);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001869'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@books.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
-- a1 owns W1, a2 is a plain member of W1, a3 owns W2.
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000001869b1','Books one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001869a1','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}'),
 ('00000000-0000-4000-8000-0000001869b2','Books two','CH','CHF','Europe/Zurich','00000000-0000-4000-8000-0000001869a3','dev',
  '{"moneyTab":true,"invoicing":true,"accountingBook":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001869c1','00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001869c2','00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000001869c3','00000000-0000-4000-8000-0000001869b2','00000000-0000-4000-8000-0000001869a3',true,true,'active');
-- Two issuers of W1 with the SAME name, and one of W2.
insert into public.sites(id,workspace_id,name,legal_id) values
 ('00000000-0000-4000-8000-0000001869d1','00000000-0000-4000-8000-0000001869b1','Atelier','111'),
 ('00000000-0000-4000-8000-0000001869d2','00000000-0000-4000-8000-0000001869b1','Atelier','222'),
 ('00000000-0000-4000-8000-0000001869d3','00000000-0000-4000-8000-0000001869b2','Atelier','333');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001869a1","role":"authenticated"}',true);
set local role authenticated;
select is((public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d1',
  'local_book','','EUR',7,1,'accrual','2026-07-01',0))->>'revision','1','the owner sets a first profile');
select is(jsonb_array_length(public.book_profiles('00000000-0000-4000-8000-0000001869b1')),1,'and reads it back');
select is((public.book_profiles('00000000-0000-4000-8000-0000001869b1')->0->>'fiscal_year_start_month'),'7','with its fiscal year');
select lives_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d2',
  'external_book','Pennylane','EUR',1,1,'cash','2026-07-01',0)$$,'a second issuer of the same name keeps its own book');
select is((select count(distinct e->>'issuer_site_id') from jsonb_array_elements(public.book_profiles('00000000-0000-4000-8000-0000001869b1')) e),
  2::bigint,'two issuers, two books');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d1',
  'local_book','','EUR',1,1,'accrual','2026-07-01',0)$$,'40001',null,'a "new" save over an existing version is stale');
select is((public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d1',
  'local_book','','EUR',1,1,'accrual','2026-07-01',1))->>'revision','2','the revision read is the revision replaced');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d1',
  'pre_accounting','','EUR',1,1,'accrual','2026-07-01',1)$$,'40001',null,'a save over a newer revision is stale');
select lives_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d1',
  'external_book','DATEV','EUR',1,1,'accrual','2027-01-01',0)$$,'a later version is a new row from its own date');
select is((select count(*) from jsonb_array_elements(public.book_profiles('00000000-0000-4000-8000-0000001869b1')) e
  where e->>'issuer_site_id'='00000000-0000-4000-8000-0000001869d1'),2::bigint,'the earlier version stays as it was');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d2',
  'external_book','','EUR',1,1,'accrual','2027-01-01',0)$$,'22023',null,'an external book names its system');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d2',
  'local_book','','EUR',2,29,'accrual','2027-01-01',0)$$,'22023',null,'a fiscal year never starts on 29 February');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d3',
  'local_book','','EUR',1,1,'accrual','2027-01-01',0)$$,'42501',null,'another workspace''s site is no issuer here');
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b2','00000000-0000-4000-8000-0000001869d3',
  'local_book','','CHF',1,1,'accrual','2027-01-01',0)$$,'42501',null,'an owner of W1 sets nothing in W2');
select throws_ok($$select public.book_profiles('00000000-0000-4000-8000-0000001869b2')$$,'42501',null,'nor reads its books');
select throws_ok($$select * from public.book_profiles$$,'42501',null,'the table is never read directly');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001869a2","role":"authenticated"}',true);
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d2',
  'local_book','','EUR',1,1,'accrual','2027-01-01',0)$$,'42501',null,'a plain member sets no book');
select throws_ok($$select public.book_profiles('00000000-0000-4000-8000-0000001869b1')$$,'42501',null,'and reads none');

reset role;
select is((select count(*) from public.book_profiles where workspace_id='00000000-0000-4000-8000-0000001869b2'),0::bigint,
  'the refusals wrote nothing in W2');
update public.workspaces set feature_flags = feature_flags || '{"accountingBook":false}'
 where id='00000000-0000-4000-8000-0000001869b1';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001869a1","role":"authenticated"}',true);
select throws_ok($$select public.save_book_profile('00000000-0000-4000-8000-0000001869b1','00000000-0000-4000-8000-0000001869d2',
  'local_book','','EUR',1,1,'accrual','2027-01-01',0)$$,'42501',null,'flag off: no new profile');
select is(jsonb_array_length(public.book_profiles('00000000-0000-4000-8000-0000001869b1')),3,'flag off: the configured books stay readable');
reset role;
select is((select count(*) from public.book_profiles),3::bigint,'exactly the three accepted saves exist');

select * from finish();
rollback;
