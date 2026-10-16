-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2631 / 0444: a parking is an area of a level holding slots of three
-- kinds, each booked per day, behind the parking flag. Off, no area and no
-- slot is created and none booked; on, a slot takes the day slot, sits in a
-- parking area and only there, and is named apart in the capacity figures
-- and in availability.
begin;
select plan(11);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

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

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002633a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2633@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000002633a1');
select set_config('t.ws', public.create_workspace('Parking', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set booking_rules = '{"granularity":"half_day"}'::jsonb
  where id = current_setting('t.ws')::uuid;
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000002633b1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002633b2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002633b3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b2', 1, 1, 4, 2);

select throws_ok($$insert into public.offices (workspace_id, level_id, name, x, y, w, h, area_kind)
    values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b1', 'P', 20, 0, 10, 10, 'parking')$$,
  '42501', null, 'flag off: a parking area cannot be created');

update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"parking": true}'
  where id = current_setting('t.ws')::uuid;
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h, area_kind)
  values ('00000000-0000-4000-8000-0000002633b4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b1', 'P', 20, 0, 10, 10, 'parking');
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002633b5', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b4', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y, resource_kind, parking_kind) values
  ('00000000-0000-4000-8000-0000002633b6', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b5', 1, 1, 'parking', 'standard'),
  ('00000000-0000-4000-8000-0000002633b7', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b5', 8, 1, 'parking', 'ev');

select is((select slot_minutes from public.seats where id = '00000000-0000-4000-8000-0000002633b6'), 1440,
  'a parking slot is booked per day');
select throws_ok($$insert into public.seats (workspace_id, desk_id, x, y)
    values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b5', 15, 1)$$,
  null, 'a parking slot sits in a parking area, and only there', 'a seat does not sit in a parking area');
select throws_ok($$insert into public.seats (workspace_id, desk_id, x, y, resource_kind, parking_kind)
    values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b3', 15, 1, 'parking', 'standard')$$,
  null, 'a parking slot sits in a parking area, and only there', 'a slot does not sit outside a parking area');
select throws_ok($$insert into public.seats (workspace_id, desk_id, x, y, resource_kind)
    values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002633b5', 20, 1, 'parking')$$,
  '23514', null, 'a parking slot has a kind');
select throws_ok($$update public.offices set area_kind = 'workspace' where id = '00000000-0000-4000-8000-0000002633b4'$$,
  null, 'the kind of an area cannot change', 'the kind of an area is fixed');

select ok(pg_temp.refusal('08:00', '12:00', '00000000-0000-4000-8000-0000002633b6') like '%cover the full day%',
  'the morning is refused on a day slot');
select is(pg_temp.refusal('08:00', '17:00', '00000000-0000-4000-8000-0000002633b6'), null,
  'the working day is accepted');

select is(public.kpi_resource_counts(current_setting('t.ws')::uuid, now(), now() + interval '60 days', null)
    -> 'resources' -> 'parking' ->> 'resources', '2',
  'the capacity figures name the parking apart');
select is(jsonb_array_length(public.mcp_read_v1(current_setting('t.ws')::uuid,
    (select m from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1),
    'get_availability', jsonb_build_object('starts_at', now() + interval '20 days',
      'ends_at', now() + interval '20 days 1 hour', 'kind', 'parking', '_ceiling', 'workspace')) -> 'items'), 2,
  'availability lists the slots under kind parking');

update public.workspaces set feature_flags = feature_flags || '{"parking": false}'
  where id = current_setting('t.ws')::uuid;
select throws_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000002633b6',
         now() + interval '30 days', now() + interval '30 days 8 hours'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1$$,
  '42501', null, 'flag off: a slot cannot be booked');

select * from finish();
rollback;
