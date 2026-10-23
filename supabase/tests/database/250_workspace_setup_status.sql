-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2867 (0539, ADR 0047): one setup status. A step reads ready from what
-- the workspace holds, never from a click: places from a seat, member
-- rights from the members role. A step waits for the step it depends on;
-- a manual step is done when the owner says so, an optional one is only
-- deferred; the bookable milestone is reached when its required steps
-- are; a feature that is off makes its steps not applicable. Only someone
-- who configures the space reads it.
begin;
select plan(14);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000002867'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@setup-status.test','',now(),now(),now()
  from unnest(array['a1','a2']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules)
values('00000000-0000-4000-8000-0000002867b1','Setup status','FR','EUR','Europe/Paris',
       '00000000-0000-4000-8000-0000002867a1','dev','{"open_weekdays":[1,2,3,4,5]}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002867c1','00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000002867c2','00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867a2',false,false,'active');

create function pg_temp.step(p_step text) returns jsonb language sql as $$
  select s from jsonb_array_elements(public.workspace_setup_status('00000000-0000-4000-8000-0000002867b1')->'steps') s
   where s->>'step' = p_step
$$;
create function pg_temp.milestone(p_milestone text) returns jsonb language sql as $$
  select m from jsonb_array_elements(public.workspace_setup_status('00000000-0000-4000-8000-0000002867b1')->'milestones') m
   where m->>'milestone' = p_milestone
$$;

-- A plain member does not configure the space.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002867a2","role":"authenticated"}',true);
select throws_ok($$select public.workspace_setup_status('00000000-0000-4000-8000-0000002867b1')$$,
  'only someone who configures this workspace sees how ready it is',
  'a plain member does not read the setup status');

-- The owner, before anything is placed.
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-0000002867a1","role":"authenticated"}',true);
select is((public.workspace_setup_status('00000000-0000-4000-8000-0000002867b1')->>'version')::int, 8, 'version 8');
select is(pg_temp.step('basics')->>'state', 'ready', 'basics: time zone and currency set');
select is(pg_temp.step('places')->>'state', 'needs_configuration', 'places: no seat yet');
select is(pg_temp.step('first_booking')->>'state', 'blocked', 'the first booking waits for places and member rights');
select ok(pg_temp.step('first_booking')->'blocked_by' ? 'places', 'and names what it waits for');
select is((pg_temp.milestone('bookable')->>'reached')::boolean, false, 'not bookable yet');

-- A seat and the members' right to book: the evidence, not a click.
insert into public.levels(id,workspace_id,name,sort_order) values
 ('00000000-0000-4000-8000-0000002867d1','00000000-0000-4000-8000-0000002867b1','Ground',0);
insert into public.offices(id,workspace_id,level_id,name,color,bookable_as_whole,x,y,w,h) values
 ('00000000-0000-4000-8000-0000002867d2','00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867d1','Open space',1,false,0,0,10,10);
insert into public.desks(id,workspace_id,office_id,name,x,y,w,h) values
 ('00000000-0000-4000-8000-0000002867d3','00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867d2','Table',1,1,4,2);
insert into public.seats(workspace_id,desk_id,name,x,y,orientation,chair,amenities) values
 ('00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867d3','S1',1,1,'n','','{}');
select is(pg_temp.step('places')->>'state', 'ready', 'places: ready once a seat exists');
update public.workspaces set role_permissions = jsonb_build_object('member', jsonb_build_array('makeReservations'))
 where id = '00000000-0000-4000-8000-0000002867b1';
select is(pg_temp.step('member_rights')->>'state', 'ready', 'member rights: ready once members may book');
select is((pg_temp.milestone('bookable')->>'reached')::boolean, true, 'bookable once its required steps are ready');

-- An acknowledgement completes a manual step and only defers an optional one.
select is(pg_temp.step('new_members')->>'state', 'needs_configuration', 'a manual step starts open');
insert into public.readiness_acknowledgements(workspace_id,user_id,section,material_revision) values
 ('00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867a1','new_members',md5('x')),
 ('00000000-0000-4000-8000-0000002867b1','00000000-0000-4000-8000-0000002867a1','recovery',md5('x'));
select is(pg_temp.step('new_members')->>'state', 'ready', 'a manual step marked done is ready');
select is(pg_temp.step('recovery')->>'state', 'deferred', 'an optional verifiable step set aside is deferred, never done');

-- Invoicing off: its steps do not concern this space.
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"invoicing":false}'::jsonb
 where id = '00000000-0000-4000-8000-0000002867b1';
select is(pg_temp.step('legal_identity')->>'state', 'not_applicable', 'invoicing off: the legal identity is not applicable');

select * from finish();
rollback;
