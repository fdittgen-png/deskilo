-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #4148 (0807): a booking needs its place to be visible to the member it is
-- booked for. A place the member may not see is answered exactly as one that
-- does not exist, free or taken, through every booking command; a series
-- tells nothing about its days; who may see it books as before.
begin;
select plan(12);


create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004144' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'places' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 4) n;
-- administrators read the figures and the bookings, not the sites
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(101), 'Places 4144', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"capacityKpi": true, "placeFeedback": true, "externalRooms": true, "levelBooking": true, "officeBooking": true}',
        '{"member": ["makeReservations"], "admin": ["manageReservations", "makeReservations", "viewAnalytics", "viewFinances"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, true, 'active', '2026-01-01');
-- the business's own floor, and an external one whose room is rented to 202
insert into public.levels (id, workspace_id, name, sort_order, kind)
values (pg_temp.u(301), pg_temp.u(101), 'Ground', 0, 'own'),
       (pg_temp.u(302), pg_temp.u(101), 'Next door', 1, 'external');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
values (pg_temp.u(311), pg_temp.u(101), pg_temp.u(301), 'Open space', 0, 0, 10, 10),
       (pg_temp.u(312), pg_temp.u(101), pg_temp.u(302), 'Studio', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, name, x, y, w, h)
values (pg_temp.u(321), pg_temp.u(101), pg_temp.u(311), 'D1', 0, 0, 2, 1),
       (pg_temp.u(322), pg_temp.u(101), pg_temp.u(312), 'D2', 0, 0, 2, 1);
insert into public.seats (id, workspace_id, desk_id, name, x, y)
values (pg_temp.u(331), pg_temp.u(101), pg_temp.u(321), 'S1', 0, 0),
       (pg_temp.u(332), pg_temp.u(101), pg_temp.u(322), 'S2', 0, 0);
insert into public.suppliers (id, workspace_id, supplier_number, name)
values (pg_temp.u(501), pg_temp.u(101), 'SUP-4144', 'Next door');
insert into public.room_rentals (id, workspace_id, office_id, supplier_id, available_from, currency, status)
values (pg_temp.u(502), pg_temp.u(101), pg_temp.u(312), pg_temp.u(501), '2026-01-01', 'EUR', 'active');
insert into public.room_rental_audience (workspace_id, rental_id, member_id)
values (pg_temp.u(101), pg_temp.u(502), pg_temp.u(202));
-- 202 books both seats today; 202 and 203 favour both
insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at, status, space_label)
values (pg_temp.u(401), pg_temp.u(101), pg_temp.u(202), pg_temp.u(331), now() + interval '1 hour', now() + interval '2 hours', 'reserved', 'S1'),
       (pg_temp.u(402), pg_temp.u(101), pg_temp.u(202), pg_temp.u(332), now() + interval '3 hours', now() + interval '4 hours', 'reserved', 'S2');
insert into public.resource_favorites (workspace_id, member_id, kind, resource_id)
values (pg_temp.u(101), pg_temp.u(202), 'seat', pg_temp.u(331)), (pg_temp.u(101), pg_temp.u(202), 'seat', pg_temp.u(332)),
       (pg_temp.u(101), pg_temp.u(203), 'seat', pg_temp.u(331)), (pg_temp.u(101), pg_temp.u(203), 'seat', pg_temp.u(332)),
       (pg_temp.u(101), pg_temp.u(201), 'seat', pg_temp.u(332));


update public.workspaces set booking_rules = coalesce(booking_rules, '{}'::jsonb)
  || '{"open_weekdays": [1,2,3,4,5,6,7], "max_series_days": 180}'::jsonb where id = pg_temp.u(101);
update public.offices set bookable_as_whole = true where id in (pg_temp.u(311), pg_temp.u(312));
update public.members set can_reserve_level = true where id = pg_temp.u(203);
-- 202 (the audience) holds the rented seat tomorrow 10-11 local
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at, status, space_label)
values (pg_temp.u(101), pg_temp.u(202), pg_temp.u(332),
        ((current_date + 1)::timestamp + time '10:00') at time zone 'Europe/Paris',
        ((current_date + 1)::timestamp + time '11:00') at time zone 'Europe/Paris', 'reserved', 'S2');
create function pg_temp.try(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return 'OK ' || left(coalesce(v, 'null'), 160);
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate || ' ' || sqlerrm;
end $f$;
-- the times: tomorrow 10-11 (the rented seat taken by 202) and 14-15 (free)
create function pg_temp.t(h int) returns timestamptz language sql as $$
  select ((current_date + 1)::timestamp + make_interval(hours => h)) at time zone 'Europe/Paris';
$$;
create function pg_temp.book(n int, p_seat uuid, p_office uuid, h int) returns text language sql as $$
  select pg_temp.try(n, format('select public.create_reservation(%L,%L,%L,%L,%L)::text',
    pg_temp.u(101), p_seat, p_office, pg_temp.t(h), pg_temp.t(h + 1)));
$$;
create function pg_temp.book_for(p_seat uuid, h int) returns text language sql as $$
  select pg_temp.try(4, format('select public.admin_create_reservation_for(%L,%L,%L,%L,%L)::text',
    pg_temp.u(101), pg_temp.u(203), p_seat, pg_temp.t(h), pg_temp.t(h + 1)));
$$;
create function pg_temp.series(p_seat uuid) returns text language sql as $$
  select regexp_replace(pg_temp.try(3, format('select (r - ''series_id'')::text from public.create_series(%L,%L,%L,%L,%L,%L) r',
    pg_temp.u(101), p_seat, pg_temp.t(10), pg_temp.t(11), 'daily', pg_temp.t(10) + interval '3 days')), '"series_id": "[^"]*",?', '');
$$;
create temp table unknown_place as select gen_random_uuid() as id;

-- ── a seat ──
select is(pg_temp.book(3, pg_temp.u(332), null, 10), pg_temp.book(3, (select id from unknown_place), null, 10),
  'a seat of a room the member may not see, taken, is answered as an unknown seat');
select is(pg_temp.book(3, pg_temp.u(332), null, 14), pg_temp.book(3, (select id from unknown_place), null, 14),
  'and so is it free');
select ok(pg_temp.book(3, pg_temp.u(332), null, 14) like 'ERR P0001 unknown seat%', 'the answer is the unknown seat''s');
-- a seat with a booking slot of its own: a window off the business's grid
update public.seats set slot_minutes = 60 where id = pg_temp.u(332);
create function pg_temp.book_off_grid(p_seat uuid) returns text language sql as $$
  select pg_temp.try(3, format('select public.create_reservation(%L,%L,null,%L,%L)::text',
    pg_temp.u(101), p_seat, pg_temp.t(14) + interval '7 minutes', pg_temp.t(15) + interval '7 minutes'));
$$;
select is(pg_temp.book_off_grid(pg_temp.u(332)), pg_temp.book_off_grid((select id from unknown_place)),
  'a seat the member may not see, with a booking slot of its own, is answered as an unknown seat off the business''s grid');
update public.seats set slot_minutes = null where id = pg_temp.u(332);

-- ── a room as a whole ──
select is(pg_temp.book(3, null, pg_temp.u(312), 10), pg_temp.book(3, null, (select id from unknown_place), 10),
  'a room the member may not see, one of its seats taken, is answered as an unknown room');
select is(pg_temp.book(3, null, pg_temp.u(312), 14), pg_temp.book(3, null, (select id from unknown_place), 14),
  'and so is it free');
-- ── a series ──
select is(pg_temp.series(pg_temp.u(332)), pg_temp.series((select id from unknown_place)),
  'a series on such a seat tells nothing more than one on an unknown seat');
-- ── booked for a member ──
select is(pg_temp.book_for(pg_temp.u(332), 10), pg_temp.book_for((select id from unknown_place), 10),
  'booked for a member who may not see it, taken, as an unknown seat');
select is(pg_temp.book_for(pg_temp.u(332), 14), pg_temp.book_for((select id from unknown_place), 14),
  'and free');
-- ── who may see it books as before ──
select ok(pg_temp.book(2, pg_temp.u(332), null, 14) like 'OK %', 'the room''s audience books its free seat');
select ok(pg_temp.book(3, pg_temp.u(331), null, 14) like 'OK %', 'a member books a seat of the business''s own floor');
select ok(not has_function_privilege('authenticated', 'public.booking_place_hidden(uuid, uuid, uuid, uuid, uuid)', 'execute'),
  'no client asks whether a place is hidden');

select * from finish();
rollback;
