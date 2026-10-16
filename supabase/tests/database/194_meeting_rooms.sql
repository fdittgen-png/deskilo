-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2631 / 0442: a meeting room is a resource of the plan behind the
-- meetingRooms flag. Off, none is created or booked; on, it takes the
-- one-hour slot, holds a capacity, may be booked beside a seat at the
-- same time, never enters the seat history, and is named apart in the
-- capacity figures and in availability.
begin;
select plan(13);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002632a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2632@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000002632a1');
select set_config('t.ws', public.create_workspace('Rooms', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set booking_rules = '{"granularity":"half_day"}'::jsonb
  where id = current_setting('t.ws')::uuid;
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000002632b1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002632b2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002632b1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002632b3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002632b2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y)
  values ('00000000-0000-4000-8000-0000002632b4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002632b3', 1, 1);

select throws_ok($$insert into public.seats (workspace_id, desk_id, x, y, resource_kind, capacity)
    values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002632b3', 8, 1, 'room', 6)$$,
  '42501', null, 'flag off: a room cannot be created');

update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"meetingRooms": true}'
  where id = current_setting('t.ws')::uuid;
insert into public.seats (id, workspace_id, desk_id, x, y, resource_kind, capacity)
  values ('00000000-0000-4000-8000-0000002632b5', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002632b3', 8, 1, 'room', 6);

select is((select slot_minutes from public.seats where id = '00000000-0000-4000-8000-0000002632b5'), 60,
  'a room takes the one-hour slot');
select is((select capacity from public.seats where id = '00000000-0000-4000-8000-0000002632b5'), 6,
  'a room holds its capacity');
select throws_ok($$update public.seats set capacity = 3 where id = '00000000-0000-4000-8000-0000002632b4'$$,
  '23514', null, 'a seat holds no capacity');
select throws_ok($$update public.seats set resource_kind = 'room' where id = '00000000-0000-4000-8000-0000002632b4'$$,
  null, 'the kind of a resource cannot change', 'the kind is fixed at creation');

create function pg_temp.refusal(p_start time, p_end time, p_seat uuid) returns text
language plpgsql as $$
declare d timestamp := date_trunc('week', now() + interval '14 days') + interval '2 days';
begin
  perform public.enforce_booking_rules(current_setting('t.ws')::uuid,
    (d + p_start) at time zone 'Europe/Paris', (d + p_end) at time zone 'Europe/Paris',
    false, p_seat);
  return null;
exception when others then return sqlerrm;
end;
$$;
select is(pg_temp.refusal('10:00', '11:00', '00000000-0000-4000-8000-0000002632b5'), null,
  'the room is booked 10:00-11:00');
select ok(pg_temp.refusal('10:00', '11:00', '00000000-0000-4000-8000-0000002632b4') like '%half-day%',
  'an hour on a seat is still refused');

-- a member holds a seat for the morning and the room within it
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000002632b4',
         (date_trunc('week', now() + interval '14 days') + interval '2 days 8 hours') at time zone 'Europe/Paris',
         (date_trunc('week', now() + interval '14 days') + interval '2 days 12 hours') at time zone 'Europe/Paris'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1;
select lives_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000002632b5',
         (date_trunc('week', now() + interval '14 days') + interval '2 days 10 hours') at time zone 'Europe/Paris',
         (date_trunc('week', now() + interval '14 days') + interval '2 days 11 hours') at time zone 'Europe/Paris'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1$$,
  'a room is booked beside the seat in the same hours');

select is((select count(*)::int from public.seat_history where seat_id = '00000000-0000-4000-8000-0000002632b5'), 0,
  'a room never enters the seat history');
select is((select count(*)::int from public.seat_history where seat_id = '00000000-0000-4000-8000-0000002632b4'), 1,
  'a seat does');
select is(public.kpi_resource_counts(current_setting('t.ws')::uuid, now(), now() + interval '60 days', null)
    -> 'resources' -> 'room' ->> 'resources', '1',
  'the capacity figures name the room apart');

select is(jsonb_array_length(public.mcp_read_v1(current_setting('t.ws')::uuid,
    (select m from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1),
    'get_availability', jsonb_build_object('starts_at', now() + interval '20 days',
      'ends_at', now() + interval '20 days 1 hour', 'kind', 'room', '_ceiling', 'workspace')) -> 'items'), 1,
  'availability lists the room under kind room');

update public.workspaces set feature_flags = feature_flags || '{"meetingRooms": false}'
  where id = current_setting('t.ws')::uuid;
select throws_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000002632b5',
         now() + interval '30 days', now() + interval '30 days 1 hour'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1$$,
  '42501', null, 'flag off: the room cannot be booked');

select * from finish();
rollback;
