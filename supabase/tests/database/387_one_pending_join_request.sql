-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3696: asking twice to join the same business leaves one pending
-- membership and one pending request to decide, and the second ask is not
-- an error. (request_public_workspace_profile asks through join_workspace.)
begin;
select plan(4);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000036960'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@onerequest.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,invite_code,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000036960b1','One request','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000036960a1','dev','ONEREQ3696','{}','{}');
insert into public.members(workspace_id,user_id,is_owner,is_admin,co_owner,status) values
 ('00000000-0000-4000-8000-0000036960b1','00000000-0000-4000-8000-0000036960a1',true,true,'none','active');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000036960a2","role":"authenticated"}',true);
set local role authenticated;
select lives_ok($$select public.join_workspace('ONEREQ3696')$$,'the first ask is accepted');
select lives_ok($$select public.join_workspace('ONEREQ3696')$$,'asking again is not an error');
reset role;

select is((select count(*)::int from public.members
            where workspace_id='00000000-0000-4000-8000-0000036960b1'
              and user_id='00000000-0000-4000-8000-0000036960a2' and status='pending'),1,
  'one pending membership');
select is((select count(*)::int from public.events
            where workspace_id='00000000-0000-4000-8000-0000036960b1'
              and type='member_join' and status='pending'),1,
  'one pending request to decide');

select * from finish();
rollback;
