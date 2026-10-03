-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2145 — what an assistant needs to answer a person in their own words.
-- A place is named by its level, office and desk and a neutral seat
-- letter, never by the seat's own name; availability filters by level and
-- office and pages through every seat exactly once; the workspace's zone,
-- currency and hours come with its capabilities; the statement needs no
-- member id; a booking an assistant made is recorded once, and is read by
-- its member and the workspace's reservation managers only.
begin;
select plan(17);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000002145';
  v uuid := '00000000-0000-4000-8000-000000002146';
  ws uuid; m uuid; mv uuid; l2 uuid; l0 uuid; office uuid; office0 uuid;
  desk1 uuid; desk2 uuid; desk0 uuid; s1 uuid; s2 uuid; s3 uuid; s0 uuid; r uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'context-2145@deskilo.test', '', now(), now(), now()),
         (v, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'context-other-2145@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Context', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       || '{"open_weekdays": [1, 2, 3, 4, 5, 6, 7], "work_start_minutes": 510}'::jsonb
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;
  insert into public.members (workspace_id, user_id) values (ws, v) returning id into mv;
  insert into public.levels (workspace_id, name, sort_order) values (ws, 'Level 2', 2) returning id into l2;
  insert into public.levels (workspace_id, name, sort_order) values (ws, 'Ground', 0) returning id into l0;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, l2, 'Open space', 0, 0, 20, 20) returning id into office;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, l0, 'Lobby', 0, 0, 10, 10) returning id into office0;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office, 1, 1, 4, 2) returning id into desk1;
  insert into public.desks (workspace_id, office_id, name, x, y, w, h)
  values (ws, office, 'Window', 8, 1, 4, 2) returning id into desk2;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office0, 1, 1, 4, 2) returning id into desk0;
  insert into public.seats (workspace_id, desk_id, name, x, y) values (ws, desk1, 'Florian', 1, 1) returning id into s1;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, desk1, 3, 1) returning id into s2;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, desk2, 9, 1) returning id into s3;
  insert into public.seats (workspace_id, desk_id, x, y) values (ws, desk0, 1, 1) returning id into s0;
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (ws, m, s3, date_trunc('day', now()) + interval '3 days 9 hours',
          date_trunc('day', now()) + interval '3 days 12 hours') returning id into r;
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.u', u::text, false);
  perform set_config('t.v', v::text, false);
  perform set_config('t.m', m::text, false);
  perform set_config('t.l2', l2::text, false);
  perform set_config('t.office0', office0::text, false);
  perform set_config('t.s1', s1::text, false);
  perform set_config('t.s2', s2::text, false);
  perform set_config('t.s3', s3::text, false);
  perform set_config('t.s0', s0::text, false);
  perform set_config('t.r', r::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.read(p_op text, p_args jsonb) returns jsonb language sql as $$
  select public.mcp_read_v1(current_setting('t.ws')::uuid,
    (select m from public.members m where m.id = current_setting('t.m')::uuid), p_op, p_args);
$$;
create or replace function pg_temp.window(p_extra jsonb) returns jsonb language sql as $$
  select jsonb_build_object(
    'starts_at', to_char(date_trunc('day', now()) + interval '1 day 9 hours', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'ends_at', to_char(date_trunc('day', now()) + interval '1 day 12 hours', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')) || p_extra;
$$;

-- Labels: names of the level, office and desk; a letter for the seat.
select is(public.mcp_place_label(current_setting('t.s1')::uuid, null, null, null),
  'Level 2 · Open space · Desk 1 · Seat A', 'an unnamed desk is numbered, a seat gets a letter');
select is(public.mcp_place_label(current_setting('t.s2')::uuid, null, null, null),
  'Level 2 · Open space · Desk 1 · Seat B', 'the next seat on the same desk is B');
select is(public.mcp_place_label(current_setting('t.s3')::uuid, null, null, null),
  'Level 2 · Open space · Window · Seat A', 'a named desk keeps its name');
select is(public.mcp_place_label(null, null, null, current_setting('t.l2')::uuid),
  'Level 2', 'a whole level is named by the level');

-- Availability: one level, paged by two, every seat exactly once.
select set_config('t.p1', pg_temp.read('get_availability',
  pg_temp.window(jsonb_build_object('level_id', current_setting('t.l2'), 'limit', 2)))::text, false);
select is(jsonb_array_length(current_setting('t.p1')::jsonb->'items'), 2, 'a page is the limit');
select set_config('t.p2', pg_temp.read('get_availability',
  pg_temp.window(jsonb_build_object('level_id', current_setting('t.l2'), 'limit', 2,
    'cursor', current_setting('t.p1')::jsonb->>'next_cursor')))::text, false);
select is(jsonb_array_length(current_setting('t.p2')::jsonb->'items'), 1, 'the cursor continues where the ids stopped');
select is((select array_agg(e->>'seat_id' order by e->>'seat_id')
             from (select jsonb_array_elements(current_setting('t.p1')::jsonb->'items')
                   union all select jsonb_array_elements(current_setting('t.p2')::jsonb->'items')) x(e)),
  (select array_agg(id::text order by id::text) from public.seats
    where id in (current_setting('t.s1')::uuid, current_setting('t.s2')::uuid, current_setting('t.s3')::uuid)),
  'the level''s seats, each once, and nothing from another level');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.p1')::jsonb->'items') e
            where e->>'level_id' = current_setting('t.l2') and e ? 'office_id' and e ? 'desk_id'
              and e->>'label' like 'Level 2 · Open space · %'), 2,
  'each item names its place and carries its ids');
select is((select count(*)::int
             from (select jsonb_array_elements(current_setting('t.p1')::jsonb->'items')
                   union all select jsonb_array_elements(current_setting('t.p2')::jsonb->'items')) x(e)
            where e->>'label' like '%Florian%'), 0,
  'a seat''s own name never reaches a label');
select is((select array_agg(e->>'seat_id') from jsonb_array_elements(pg_temp.read('get_availability',
  pg_temp.window(jsonb_build_object('office_id', current_setting('t.office0'))))->'items') e),
  array[current_setting('t.s0')], 'an office filter answers that office only');
select ok((select bool_and(e->>'free' = 'true') from jsonb_array_elements(current_setting('t.p1')::jsonb->'items') e),
  'free is still the engine''s verdict');

-- Own bookings are labelled too.
select is(pg_temp.read('list_my_reservations', jsonb_build_object(
    'from', to_char(date_trunc('day', now()), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'to', to_char(date_trunc('day', now()) + interval '10 days', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))->'items'->0->>'label',
  'Level 2 · Open space · Window · Seat A', 'an own booking says where it is');

-- The workspace's clock and hours.
select is(public.mcp_workspace_context(current_setting('t.ws')::uuid)
            - 'opening_hours' || jsonb_build_object('start', public.mcp_workspace_context(current_setting('t.ws')::uuid)->'opening_hours'->>'work_start'),
  '{"time_zone": "Europe/Paris", "currency": "EUR", "start": "08:30"}'::jsonb,
  'the zone, the currency and the opening time');

-- The facade: the statement needs no member id and names its currency;
-- capabilities carry the context; the create branch records provenance.
select ok(position($$v_args ? 'member_id' and public.mcp_uuid_arg(v_args, 'member_id')$$ in
            pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure)) > 0
       and position('mcp_workspace_context(p_workspace_id)' in
            pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure)) > 0
       and position($$jsonb_build_object('currency'$$ in
            pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure)) > 0,
  'statement and capabilities are patched');

-- Provenance: once per booking, whoever replays it.
select public.mcp_record_reservation_origin(current_setting('t.r')::uuid, current_setting('t.ws')::uuid,
  current_setting('t.m')::uuid, 'client-2145', gen_random_uuid());
select public.mcp_record_reservation_origin(current_setting('t.r')::uuid, current_setting('t.ws')::uuid,
  current_setting('t.m')::uuid, 'client-2145', gen_random_uuid());
select is((select array[count(*)::text, max(client_name), max(channel)] from public.reservation_origins
            where reservation_id = current_setting('t.r')::uuid),
  array['1', 'client-2145', 'assistant'], 'one origin per booking, named by its client');

-- Read by the member who booked (here also the owner) ...
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, false);
set local role authenticated;
select is((select count(*)::int from public.reservation_origins), 1, 'the member and manager reads it');
reset role;
-- ... and by nobody else in the workspace.
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.v'), 'role', 'authenticated')::text, false);
set local role authenticated;
select is((select count(*)::int from public.reservation_origins), 0, 'another member does not');
reset role;

select * from finish();
rollback;
