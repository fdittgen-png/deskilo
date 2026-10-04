-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0367: a workspace is public or private, listed either way with its own
-- address, and its licence follows from what it is. Public: free (the
-- launch offer, then up to 8 users and 5 subscribers, or a verified
-- non-profit up to 12 users). Private, or public above those limits: paid.
-- A READ only: nothing is enforced.
begin;
select plan(15);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001918'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@licence.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags,invoice_legal,street,postal_code,city) values
 ('00000000-0000-4000-8000-0000001918b1','Licence','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000001918a1','dev',
  '{"publicListings":true}','{"seller_kind":"association"}','1 Rue Test','34000','Montpellier');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001918c1','00000000-0000-4000-8000-0000001918b1','00000000-0000-4000-8000-0000001918a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001918c2','00000000-0000-4000-8000-0000001918b1','00000000-0000-4000-8000-0000001918a2',false,false,'active');

create or replace function pg_temp.status(p_on date default current_date) returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001918a1","role":"authenticated"}',true);
  return public.workspace_licence_status('00000000-0000-4000-8000-0000001918b1', p_on);
end $$;

select is((select visibility || '/' || (visibility_set_at is null)::text from public.workspaces
            where id='00000000-0000-4000-8000-0000001918b1'), 'private/true',
  'a workspace starts private and unlisted until its owner chooses');
select is(pg_temp.status()->>'plan', 'private', 'private: the private plan');
select is((pg_temp.status()->>'monthly_price_cents')::int, 3000, 'at 30.00 EUR a month');
select is((pg_temp.status()->>'enforced')::boolean, false, 'and nothing is enforced');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001918a1","role":"authenticated"}',true);
select public.set_workspace_visibility('00000000-0000-4000-8000-0000001918b1', 'public');
select is(pg_temp.status()->>'plan', 'public_launch', 'public: the launch offer, free');
select is(pg_temp.status(date '2028-01-01')->>'plan', 'community',
  'after the offer a small public workspace (2 users) is free');

update public.licence_plans set max_users = 1 where code = 'community';
select is(pg_temp.status(date '2028-01-01')->>'plan', 'public_standard',
  'above the community limits it is paid');
insert into public.workspace_licences(workspace_id, nonprofit_verified)
  values ('00000000-0000-4000-8000-0000001918b1', true);
select is(pg_temp.status(date '2028-01-01')->>'plan', 'association',
  'a verified non-profit association is free up to 12 users');
update public.workspace_licences set plan_override = 'private'
 where workspace_id = '00000000-0000-4000-8000-0000001918b1';
select is(pg_temp.status()->>'plan' || '/' || (pg_temp.status()->>'override'), 'private/true',
  'a negotiated plan wins and says so');

select is((select count(*)::int from public.public_workspace_cards
            where workspace_id='00000000-0000-4000-8000-0000001918b1'), 1,
  'a workspace whose owner chose is listed');
insert into public.workspace_public_pages(workspace_id, published, document)
  values ('00000000-0000-4000-8000-0000001918b1', true, '{"address":"Somewhere else"}');
select is((select document->>'address' from public.public_workspace_cards
            where workspace_id='00000000-0000-4000-8000-0000001918b1'),
  '1 Rue Test, 34000 Montpellier', 'the public address is the workspace''s own, whatever the page says');
delete from public.workspace_public_pages where workspace_id='00000000-0000-4000-8000-0000001918b1';
select public.set_workspace_visibility('00000000-0000-4000-8000-0000001918b1', 'private');
select is((select array(select k from jsonb_object_keys(document) k order by k)
             from public.public_workspace_cards where workspace_id='00000000-0000-4000-8000-0000001918b1'),
  array['address','host_type','name'], 'a private workspace is listed by name and address only');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001918a2","role":"authenticated"}',true);
select throws_ok($$select public.workspace_licence_status('00000000-0000-4000-8000-0000001918b1')$$,
  'P0001', 'not allowed to read the licence', 'a plain member cannot read the licence');
select throws_ok($$select public.set_workspace_visibility('00000000-0000-4000-8000-0000001918b1','public')$$,
  'P0001', 'owner required', 'and cannot change the visibility');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001918a1","role":"authenticated"}',true);
select throws_ok($$select public.set_workspace_visibility('00000000-0000-4000-8000-0000001918b1','hidden')$$,
  'P0001', 'unknown visibility', 'only public or private exist');

select * from finish();
rollback;
