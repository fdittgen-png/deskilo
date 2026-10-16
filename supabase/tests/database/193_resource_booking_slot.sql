-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2631 / 0441: a resource carries its own booking slot. Under a half-day
-- workspace an hour on a plain seat is refused while the same hour on a
-- seat with a 60-minute slot passes; a seat with no slot, and a call with no
-- seat, keep the workspace value.
begin;
select plan(9);

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
 ('00000000-0000-4000-8000-0000002631a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2631@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000002631a1');
select set_config('t.ws', public.create_workspace('Slots', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set booking_rules = '{"granularity":"half_day"}'::jsonb
  where id = current_setting('t.ws')::uuid;
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000002631b1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002631b2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002631b1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000002631b3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002631b2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y, slot_minutes) values
  ('00000000-0000-4000-8000-0000002631b4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002631b3', 1, 1, null),
  ('00000000-0000-4000-8000-0000002631b5', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002631b3', 8, 1, 60),
  ('00000000-0000-4000-8000-0000002631b6', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002631b3', 15, 1, 1440);

select ok(pg_temp.refusal('10:00', '11:00', '00000000-0000-4000-8000-0000002631b4') like '%half-day%',
  'an hour on a seat without a slot is refused (half-day workspace)');
select is(pg_temp.refusal('08:00', '12:00', '00000000-0000-4000-8000-0000002631b4'), null,
  'the morning on a seat without a slot passes');
select is(pg_temp.refusal('10:00', '11:00', '00000000-0000-4000-8000-0000002631b5'), null,
  'an hour on a 60-minute resource passes');
select ok(pg_temp.refusal('10:30', '11:30', '00000000-0000-4000-8000-0000002631b5') like '%60-minute grid%',
  'a half-past hour on a 60-minute resource is refused');
select ok(pg_temp.refusal('10:00', '11:00', null) like '%half-day%',
  'no seat: the workspace value');
select ok(pg_temp.refusal('08:00', '12:00', '00000000-0000-4000-8000-0000002631b6') like '%cover the full day%',
  'a day-slot resource refuses the morning');
select is(pg_temp.refusal('08:00', '17:00', '00000000-0000-4000-8000-0000002631b6'), null,
  'a day-slot resource accepts the working day');
select throws_ok($$update public.seats set slot_minutes = 7 where id = '00000000-0000-4000-8000-0000002631b4'$$,
  '23514', null, 'an unknown slot is refused by the table');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace
    and p.proname in ('create_reservation','create_series','admin_create_reservation_for','update_reservation')
    and p.prosrc ~ 'enforce_booking_rules\([^;]*seat'), 4,
  'the seat-booking callers pass their seat');

select * from finish();
rollback;
