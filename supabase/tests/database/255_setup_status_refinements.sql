-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2867 (review 2026-10-22) — the setup status never claims more than the
-- data shows: a milestone is reached only when every required step up to it
-- is ready (checked on every workspace while the fixture has reached one), a
-- step that was ready turns back when its data goes and takes its milestone
-- with it (stale readiness), a step the system verifies cannot be marked
-- done by hand, and an operator's step waits for the operator. Rolls back.
begin;
select plan(9);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values ('00000000-0000-4000-8000-0000002867a5','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a5@refine.test','',now(),now(),now());
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,booking_rules,feature_flags)
values ('00000000-0000-4000-8000-0000002867b5','Refine','FR','EUR','Europe/Paris',
        '00000000-0000-4000-8000-0000002867a5','dev','{"open_weekdays":[1,2,3,4,5]}','{"mcpAccess":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000002867c5','00000000-0000-4000-8000-0000002867b5',
  '00000000-0000-4000-8000-0000002867a5',true,true,'active');
-- A place to book, and members who may book it: Take bookings is reached.
insert into public.levels(id,workspace_id,name)
values ('00000000-0000-4000-8000-0000002867d1','00000000-0000-4000-8000-0000002867b5','Ground');
insert into public.offices(id,workspace_id,level_id,name,x,y,w,h)
values ('00000000-0000-4000-8000-0000002867d2','00000000-0000-4000-8000-0000002867b5',
        '00000000-0000-4000-8000-0000002867d1','Room',0,0,100,100);
insert into public.desks(id,workspace_id,office_id,x,y,w,h)
values ('00000000-0000-4000-8000-0000002867d3','00000000-0000-4000-8000-0000002867b5',
        '00000000-0000-4000-8000-0000002867d2',10,10,20,20);
insert into public.seats(workspace_id,desk_id,x,y)
values ('00000000-0000-4000-8000-0000002867b5','00000000-0000-4000-8000-0000002867d3',12,12);
update public.workspaces set role_permissions = coalesce(role_permissions, '{}'::jsonb) || '{"member":["makeReservations"]}'
 where id = '00000000-0000-4000-8000-0000002867b5';

create function pg_temp.status() returns jsonb language sql as $$
  select public.workspace_setup_status('00000000-0000-4000-8000-0000002867b5')
$$;
create function pg_temp.step(p_step text) returns text language sql as $$
  select s->>'state' from jsonb_array_elements(pg_temp.status()->'steps') s where s->>'step' = p_step
$$;
create function pg_temp.bookable() returns jsonb language sql as $$
  select m from jsonb_array_elements(pg_temp.status()->'milestones') m where m->>'milestone' = 'bookable'
$$;

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000002867a5","role":"authenticated"}', true);
select is(pg_temp.step('hours'), 'ready', 'hours: ready with open weekdays');
select is(pg_temp.step('assistant'), 'needs_operator', 'the assistant step waits for the operator');
select is((pg_temp.bookable()->>'reached')::boolean, true,
  'Take bookings is reached once every required step for it is ready');

-- Every workspace, as its owner: a reached milestone has no required step
-- up to it that is still open.
create temp table _reached(workspace text, milestone text);
create temp table _bad(workspace text, milestone text, step text, state text);
do $inv$
declare r record; v jsonb; v_order text[] := array['bookable','money','invoice','live'];
begin
  for r in select w.id, w.name, m.user_id from public.workspaces w
             join lateral (select user_id from public.members
                            where workspace_id = w.id and is_owner and status = 'active'
                              and user_id is not null limit 1) m on true loop
    perform set_config('request.jwt.claims',
      json_build_object('sub', r.user_id, 'role', 'authenticated')::text, true);
    v := public.workspace_setup_status(r.id);
    insert into _reached select r.name, m->>'milestone'
      from jsonb_array_elements(v->'milestones') m where (m->>'reached')::boolean;
    insert into _bad
    select r.name, m->>'milestone', s->>'step', s->>'state'
      from jsonb_array_elements(v->'milestones') m
      join jsonb_array_elements(v->'steps') s
        on array_position(v_order, s->>'milestone') <= array_position(v_order, m->>'milestone')
     where (m->>'reached')::boolean
       and (s->>'required')::boolean
       and s->>'state' not in ('ready', 'not_applicable');
  end loop;
end $inv$;
select ok((select count(*) from _reached) > 0, 'some milestone is reached, so the check below means something');
select is((select string_agg(workspace || ': ' || milestone || ' reached with ' || step || ' ' || state, '; ') from _bad),
  null, 'no milestone is reached while a required step up to it is open');

select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000002867a5","role":"authenticated"}', true);
update public.workspaces set booking_rules = '{"open_weekdays":[]}'
 where id = '00000000-0000-4000-8000-0000002867b5';
select is(pg_temp.step('hours'), 'needs_configuration',
  'stale readiness: with the open weekdays gone, hours turns back');
select is((pg_temp.bookable()->>'reached')::boolean, false, 'and Take bookings is no longer claimed');
select is((pg_temp.bookable()->>'ready')::int, 3, 'with one ready step less');
select throws_ok($$select public.acknowledge_setup_step('00000000-0000-4000-8000-0000002867b5','hours')$$,
  '22023', null, 'a step the system verifies cannot be marked done by hand');

select * from finish();
rollback;
