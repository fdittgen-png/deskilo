-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2631 / 0446: an EV parking slot has a charging station and is booked with
-- it. A non-EV slot never has one; an EV slot cannot be booked without an
-- active station; the usage fee rides the existing accessory supplement of
-- the slot; members read stations, only the layout permission writes them.
begin;
select plan(11);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002634a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2634@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002634a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-2634@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000002634a1');
select set_config('t.ws', public.create_workspace('Chargers', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
  values ('00000000-0000-4000-8000-0000002634c2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634a2', false, false, 'active');
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"parking": true}'
  where id = current_setting('t.ws')::uuid;
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000002634b1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h, area_kind)
  values ('00000000-0000-4000-8000-0000002634b2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634b1', 'P', 0, 0, 10, 10, 'parking');
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002634b3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634b2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y, resource_kind, parking_kind) values
  ('00000000-0000-4000-8000-0000002634b4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634b3', 1, 1, 'parking', 'standard'),
  ('00000000-0000-4000-8000-0000002634b5', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634b3', 8, 1, 'parking', 'ev');
insert into public.accessories (id, workspace_id, name, supplement_cents)
  values ('00000000-0000-4000-8000-0000002634d1', current_setting('t.ws')::uuid, 'Charge', 300);

select throws_ok($$insert into public.charging_stations (workspace_id, seat_id, connector, power_kw)
    values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634b4', 'type2', 11)$$,
  null, 'a charging station belongs to an EV parking slot', 'a standard slot has no charger');

select throws_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000002634b5',
         now() + interval '30 days', now() + interval '30 days 8 hours'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid and m.is_owner$$,
  null, 'the charging station of this slot is not available', 'an EV slot without a charger is not booked');

insert into public.charging_stations (id, workspace_id, seat_id, connector, power_kw, accessory_id)
  values ('00000000-0000-4000-8000-0000002634e1', current_setting('t.ws')::uuid,
          '00000000-0000-4000-8000-0000002634b5', 'type2', 11, '00000000-0000-4000-8000-0000002634d1');

select ok(exists (select 1 from public.seat_accessories
    where seat_id = '00000000-0000-4000-8000-0000002634b5' and accessory_id = '00000000-0000-4000-8000-0000002634d1'),
  'the usage fee rides the slot as an accessory supplement');

select lives_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000002634b5',
         now() + interval '30 days', now() + interval '30 days 8 hours'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid and m.is_owner$$,
  'with its charger the EV slot is booked');
select throws_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634c2',
          '00000000-0000-4000-8000-0000002634b5', now() + interval '30 days 1 hour', now() + interval '30 days 5 hours')$$,
  '23P01', null, 'the charger is booked with the slot: a second booking is refused');

update public.charging_stations set active = false where id = '00000000-0000-4000-8000-0000002634e1';
select throws_ok($$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002634c2',
          '00000000-0000-4000-8000-0000002634b5', now() + interval '40 days', now() + interval '40 days 8 hours')$$,
  null, 'the charging station of this slot is not available', 'a charger out of service blocks the slot');

select throws_ok($$update public.seats set parking_kind = 'standard' where id = '00000000-0000-4000-8000-0000002634b5'$$,
  null, 'a slot with a charging station stays an EV slot', 'a slot with a charger stays EV');

-- members read stations; only the layout permission writes
select pg_temp.act_as('00000000-0000-4000-8000-0000002634a2');
select is((select count(*)::int from public.charging_stations), 1, 'a member reads the stations');
update public.charging_stations set power_kw = 22;
reset role;
select is((select power_kw from public.charging_stations), 11.0,
  'a member changes no station');

update public.charging_stations set accessory_id = null where id = '00000000-0000-4000-8000-0000002634e1';
select ok(not exists (select 1 from public.seat_accessories where seat_id = '00000000-0000-4000-8000-0000002634b5'),
  'dropping the fee detaches the accessory');
select throws_ok($$update public.charging_stations set connector = 'usb' where id = '00000000-0000-4000-8000-0000002634e1'$$,
  '23514', null, 'an unknown connector is refused');

select * from finish();
rollback;
