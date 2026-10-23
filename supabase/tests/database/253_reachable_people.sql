-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2472: my_reachable_people lists the people of every workspace I am an
-- active member of whose reachability allows me — the rule of the account
-- search. Not me, not a person who left or is not active, not a blocked
-- account (either way), not a stranger, nobody of a space whose community
-- directory (membersDirectory) is off; one row per shared workspace.
-- Synthetic accounts; everything rolls back.
begin;
select plan(11);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002472'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@reachable.test','',now(),now(),now()
  from unnest(array['a1','a2','a3','a4','a5','a6','a7']) suffix;
update public.profiles set display_name = 'Reach'||right(id::text,2)
 where id::text like '%0000002472a%';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment) values
 ('00000000-0000-4000-8000-0000002472b1','Atelier','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002472a1','dev'),
 ('00000000-0000-4000-8000-0000002472b2','Loft','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002472a1','dev'),
 ('00000000-0000-4000-8000-0000002472b3','Elsewhere','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002472a6','dev'),
 ('00000000-0000-4000-8000-0000002472b4','Quiet','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000002472a1','dev');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002472c1','00000000-0000-4000-8000-0000002472b1','00000000-0000-4000-8000-0000002472a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002472c2','00000000-0000-4000-8000-0000002472b1','00000000-0000-4000-8000-0000002472a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002472c3','00000000-0000-4000-8000-0000002472b2','00000000-0000-4000-8000-0000002472a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002472c4','00000000-0000-4000-8000-0000002472b2','00000000-0000-4000-8000-0000002472a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000002472c5','00000000-0000-4000-8000-0000002472b1','00000000-0000-4000-8000-0000002472a3',false,false,'active'),
 ('00000000-0000-4000-8000-0000002472c6','00000000-0000-4000-8000-0000002472b1','00000000-0000-4000-8000-0000002472a4',false,false,'active'),
 ('00000000-0000-4000-8000-0000002472c7','00000000-0000-4000-8000-0000002472b3','00000000-0000-4000-8000-0000002472a6',true,true,'active'),
 ('00000000-0000-4000-8000-0000002472c8','00000000-0000-4000-8000-0000002472b4','00000000-0000-4000-8000-0000002472a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002472c9','00000000-0000-4000-8000-0000002472b4','00000000-0000-4000-8000-0000002472a7',false,false,'active');
-- Quiet's community directory is off: a7, who shares only Quiet with a1, is
-- listed once it is back on.
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"membersDirectory": false}'
 where id = '00000000-0000-4000-8000-0000002472b4';
-- a5 shares nothing with a1; a3 keeps reachability for nobody.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002472a3","role":"authenticated"}',true);
select public.set_visibility('reachability','nobody');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002472a1","role":"authenticated"}',true);
select is(jsonb_array_length(public.my_reachable_people()),3,
 'a2 in two workspaces and a4 in one — a3 chose nobody, a5/a6 share nothing, a7 only a space whose directory is off, I am not listed');
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a1'),0,
 'I am never listed');
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a7'),0,
 'nobody of a space whose community directory is off is listed');
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a2'),2,
 'a person sharing two workspaces appears once per workspace');
select is(public.my_reachable_people()->0->>'workspace_name','Atelier','rows come ordered by workspace name');
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a3'),0,
 'a person who made themselves reachable for nobody is not listed');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"membersDirectory": true}'
 where id = '00000000-0000-4000-8000-0000002472b4';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002472a1","role":"authenticated"}',true);
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a7'),1,
 'with the community directory back on, the space lists its people');

reset role;
update public.members set status = 'exited' where id = '00000000-0000-4000-8000-0000002472c6';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002472a1","role":"authenticated"}',true);
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a4'),0,
 'a member who is no longer active is not listed');

select public.block_account('00000000-0000-4000-8000-0000002472a2');
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a2'),0,
 'an account I blocked is not listed');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002472a2","role":"authenticated"}',true);
select is((select count(*)::int from jsonb_array_elements(public.my_reachable_people()) r where r->>'id'='00000000-0000-4000-8000-0000002472a1'),0,
 'nor does the blocked one see the blocker');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002472a5","role":"authenticated"}',true);
select is(public.my_reachable_people(),'[]'::jsonb,'someone with no workspace sees nobody');
select * from finish();
rollback;
