-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2365: accounting_source_snapshot_v1 delivers the book-profile revisions of
-- the workspace in the same response as the books: every version of every
-- issuer, with a control total (count and sum of revisions) that equals the
-- figures worked out by hand from the seeded rows. Nonempty positive
-- control: W1 has three versions over two issuers (revisions 1, 2, 1 = 4);
-- the profile of another workspace never appears; a workspace with no
-- profile answers an empty list and zero totals; a plain member and another
-- workspace's owner are refused; the read changes no profile row.
begin;
select plan(11);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002365'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@srcprof.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
-- a1 owns W1, a2 is a plain member of W1, a3 owns W2 (W3 has no profile).
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by) values
 ('00000000-0000-4000-8000-0000002365b1','Src prof one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002365a1'),
 ('00000000-0000-4000-8000-0000002365b2','Src prof two','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002365a3'),
 ('00000000-0000-4000-8000-0000002365b3','Src prof bare','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002365a1');
insert into public.members(workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002365b2','00000000-0000-4000-8000-0000002365a3',true,true,'active'),
 ('00000000-0000-4000-8000-0000002365b3','00000000-0000-4000-8000-0000002365a1',true,true,'active');
insert into public.sites(id,workspace_id,name,legal_id) values
 ('00000000-0000-4000-8000-0000002365d1','00000000-0000-4000-8000-0000002365b1','Atelier','111'),
 ('00000000-0000-4000-8000-0000002365d2','00000000-0000-4000-8000-0000002365b1','Annexe','222'),
 ('00000000-0000-4000-8000-0000002365d3','00000000-0000-4000-8000-0000002365b2','Autre','333');
insert into public.book_profiles(workspace_id,issuer_site_id,authority_mode,external_system,functional_currency,
  fiscal_year_start_month,fiscal_year_start_day,accounting_basis,effective_from,revision) values
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365d1','pre_accounting','','EUR',1,1,'accrual','2025-01-01',1),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365d1','pre_accounting','','EUR',7,1,'accrual','2026-01-01',2),
 ('00000000-0000-4000-8000-0000002365b1','00000000-0000-4000-8000-0000002365d2','external_book','DATEV','EUR',4,1,'cash','2026-01-01',1),
 ('00000000-0000-4000-8000-0000002365b2','00000000-0000-4000-8000-0000002365d3','pre_accounting','','EUR',1,1,'accrual','2026-01-01',9);
create temp table sp_before as
  select count(*) as n, coalesce(sum(revision), 0) as rev, md5(string_agg(id::text, ',' order by id)) as ids
    from public.book_profiles;

create or replace function pg_temp.snap(w text) returns jsonb language sql as $$
  select public.accounting_source_snapshot_v1(('00000000-0000-4000-8000-0000002365' || w)::uuid, date '2026-01-01', date '2026-12-31');
$$;
create or replace function pg_temp.act_as(who text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000002365' || who, 'role', 'authenticated')::text, false);
end;
$$;

set local role authenticated;
select pg_temp.act_as('a1');
create temp table sp_got as select pg_temp.snap('b1') as j;

select is((select j->>'status' from sp_got), 'ok', 'the owner is answered');
select is((select jsonb_array_length(j->'book_profiles') from sp_got), 3,
  'positive control: the three versions of the two issuers are delivered, not the other workspace''s');
select is((select (j#>>'{totals,book_profiles,count}')::int from sp_got), 3, 'the control count is the delivered rows');
select is((select (j#>>'{totals,book_profiles,revision_sum}')::int from sp_got), 4,
  'the revision sum is 1 + 2 + 1 worked by hand');
select is((select p->>'fiscal_year_start_month' from sp_got, jsonb_array_elements(j->'book_profiles') p
   where p->>'issuer_site_id' = '00000000-0000-4000-8000-0000002365d1' and p->>'effective_from' = '2026-01-01'),
  '7', 'the version in force for the first issuer starts its year in July');
select is((select string_agg(distinct p->>'workspace_id', ',') from sp_got, jsonb_array_elements(j->'book_profiles') p),
  '00000000-0000-4000-8000-0000002365b1', 'every delivered profile belongs to the asked workspace');
select is((pg_temp.snap('b3')->'book_profiles')::text || (pg_temp.snap('b3')#>>'{totals,book_profiles,count}'), '[]0',
  'a workspace with no profile answers an empty list and a zero total');

select pg_temp.act_as('a2');
select throws_ok($$ select pg_temp.snap('b1') $$, '42501', 'accounting_source_snapshot_v1: not allowed',
  'a plain member without viewFinances is refused');
select pg_temp.act_as('a3');
select throws_ok($$ select pg_temp.snap('b1') $$, '42501', 'accounting_source_snapshot_v1: not allowed',
  'another workspace''s owner is refused');
reset role;

select is((select count(*) || '/' || coalesce(sum(revision), 0) || '/' || md5(string_agg(id::text, ',' order by id))
    from public.book_profiles),
  (select n || '/' || rev || '/' || ids from sp_before), 'the reads and refusals changed no profile row');
select is((select jsonb_typeof(j->'book_profiles') from sp_got), 'array', 'the profiles are an array in the answer');

select * from finish();
rollback;
