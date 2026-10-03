-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1851 C: the remaining operation owners (0356). With each feature off,
-- nothing NEW starts, and the work it already created can still be
-- cleaned up by exactly the people who could before:
--   * customRoles off: a custom role cannot be given, but can be taken back;
--   * adminSeatBlocking off: an admin cannot place a block, but can lift
--     one; the owner's own right is unchanged;
--   * autoCheckInOut off: the day-end job does nothing.
-- Every positive case sits beside its refusal, each refusal is read back
-- to prove it changed nothing, and a replayed clean-up changes nothing twice.
begin;
select plan(16);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000001851'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@operation-owners.test','',now(),now(),now()
  from unnest(array['d1','d2','d3']) suffix;
-- d1 owner, d2 admin, d3 member.
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags)
values('00000000-0000-4000-8000-0000001851e1','Owners space','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000001851d1','dev',
       '{"customRoles":true,"adminSeatBlocking":true,"autoCheckInOut":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000001851f1','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-0000001851d1',true,true,'active'),
 ('00000000-0000-4000-8000-0000001851f2','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-0000001851d2',false,true,'active'),
 ('00000000-0000-4000-8000-0000001851f3','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-0000001851d3',false,false,'active');
insert into public.workspace_roles(id,workspace_id,key,permissions,names,active,builtin) values
 ('00000000-0000-4000-8000-000000185101','00000000-0000-4000-8000-0000001851e1','treasurer','{viewFinances}','{"en":"Treasurer"}',true,false);
insert into public.workspace_role_members(workspace_id,role_id,member_id) values
 ('00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-000000185101','00000000-0000-4000-8000-0000001851f3');
insert into public.levels(id,workspace_id,name) values ('00000000-0000-4000-8000-000000185121','00000000-0000-4000-8000-0000001851e1','L');
insert into public.offices(id,workspace_id,level_id,name,x,y,w,h)
  values ('00000000-0000-4000-8000-000000185122','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-000000185121','O',0,0,10,10);
insert into public.desks(id,workspace_id,office_id,x,y,w,h)
  values ('00000000-0000-4000-8000-000000185123','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-000000185122',1,1,4,2);
insert into public.seats(id,workspace_id,desk_id,x,y,blocked_from,blocked_to)
  values ('00000000-0000-4000-8000-000000185124','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-000000185123',1,1,now(),now()+interval '7 days');
insert into public.reservations(id,workspace_id,member_id,seat_id,starts_at,ends_at,status)
  values ('00000000-0000-4000-8000-000000185131','00000000-0000-4000-8000-0000001851e1','00000000-0000-4000-8000-0000001851f3',
          '00000000-0000-4000-8000-000000185124',now()-interval '2 days',now()-interval '2 days'+interval '2 hours','reserved');

-- ── every feature off ──
update public.workspaces
   set feature_flags = feature_flags || '{"customRoles":false,"adminSeatBlocking":false,"autoCheckInOut":false}'
 where id='00000000-0000-4000-8000-0000001851e1';

-- customRoles: give refused, take back allowed (owner).
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851d1","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.assign_workspace_role('00000000-0000-4000-8000-0000001851f2','00000000-0000-4000-8000-000000185101',true)$$,
  'P0001','custom roles are off in this workspace','off: a custom role is not given');
select lives_ok($$select public.assign_workspace_role('00000000-0000-4000-8000-0000001851f3','00000000-0000-4000-8000-000000185101',false)$$,
  'off: the owner takes a custom role back');
reset role;
select is((select count(*) from public.workspace_role_members where role_id='00000000-0000-4000-8000-000000185101'),0::bigint,
  'the role is gone and nothing was given');
set local role authenticated;
-- a replayed take-back (a lost answer, a second tap) changes nothing twice.
select lives_ok($$select public.assign_workspace_role('00000000-0000-4000-8000-0000001851f3','00000000-0000-4000-8000-000000185101',false)$$,
  'off: taking it back again is harmless');
reset role;
select is((select count(*) from public.events where workspace_id='00000000-0000-4000-8000-0000001851e1'
           and type='role_change' and subject_member_id='00000000-0000-4000-8000-0000001851f3'),1::bigint,
  'the replay recorded no second change');
set local role authenticated;

-- adminSeatBlocking: the admin places nothing new, lifts the existing block.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851d2","role":"authenticated"}',true);
select throws_ok($$select public.set_seat_block('00000000-0000-4000-8000-000000185124',now(),now()+interval '1 day')$$,
  'P0001',null,'off: an admin places no new block');
reset role;
select isnt((select blocked_to from public.seats where id='00000000-0000-4000-8000-000000185124'),null,
  'the refused block left the existing one as it was');
set local role authenticated;
select lives_ok($$select public.set_seat_block('00000000-0000-4000-8000-000000185124',null,null)$$,
  'off: the admin lifts the existing block');
reset role;
select is((select blocked_from from public.seats where id='00000000-0000-4000-8000-000000185124'),null,'the block is lifted');
-- a plain member still cannot touch blocks.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851d3","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.set_seat_block('00000000-0000-4000-8000-000000185124',null,null)$$,
  'P0001',null,'off: lifting stays with who could block');
-- the owner's own right is unchanged.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000001851d1","role":"authenticated"}',true);
select lives_ok($$select public.set_seat_block('00000000-0000-4000-8000-000000185124',now(),now()+interval '1 day')$$,
  'off: the owner still blocks a seat');

-- autoCheckInOut: the day-end job does nothing while off.
select lives_ok($$select public.sweep_day_end('00000000-0000-4000-8000-0000001851e1')$$,'off: the sweep runs');
reset role;
select is((select status from public.reservations where id='00000000-0000-4000-8000-000000185131'),'reserved',
  'off: the sweep completed nothing');

-- ── back on: the new business is accepted again ──
update public.workspaces
   set feature_flags = feature_flags || '{"customRoles":true,"autoCheckInOut":true}'
 where id='00000000-0000-4000-8000-0000001851e1';
set local role authenticated;
select lives_ok($$select public.assign_workspace_role('00000000-0000-4000-8000-0000001851f3','00000000-0000-4000-8000-000000185101',true)$$,
  'on: the custom role is given');
select lives_ok($$select public.sweep_day_end('00000000-0000-4000-8000-0000001851e1')$$,'on: the sweep runs');
reset role;
select is((select status from public.reservations where id='00000000-0000-4000-8000-000000185131'),'completed',
  'on: the sweep completes the past booking');

select * from finish();
rollback;
