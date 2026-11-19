-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4216 (0813): a booking's own member always sees it, whatever place it
-- names; a booking that names no place (its place was removed, its label
-- kept) is the business's, as it was: listed, its events shown, exported to
-- its member and cancelled by whoever may cancel bookings. Deciding a booking
-- request needs the right to see the booking; whoever holds the sites right
-- adds an external level and reads it back; a business without an external
-- level answers the booking rule at once.
begin;
select plan(20);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004216' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'places4216-' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 4) n;
-- administrators read the figures and the bookings, not the sites
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(101), 'Places 4216', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"capacityKpi": true, "placeFeedback": true, "externalRooms": true}',
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

-- [p_sql] as user [n]: its answer as text, or 'ERR <sqlstate> <message>'.
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(v, 'null');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate || ' ' || sqlerrm;
end $f$;
create function pg_temp.events_of(n int, r int) returns text language sql as $$
  select pg_temp.as_user(n, format('select count(*)::text from public.events where reservation_id = %L', pg_temp.u(r)));
$$;
create function pg_temp.row_of(n int, r int) returns text language sql as $$
  select pg_temp.as_user(n, format('select count(*)::text from public.reservations where id = %L', pg_temp.u(r)));
$$;
create function pg_temp.cancel(n int, r int) returns text language sql as $$
  select pg_temp.as_user(n, format('select public.cancel_reservation(%L)::text', pg_temp.u(r)));
$$;
create function pg_temp.decide(n int, p_event uuid) returns text language sql as $$
  select pg_temp.as_user(n, format('select public.respond_to_event(%L, true)::text', p_event));
$$;

-- Bookings of 202 that name no place any more: their place was removed from
-- the plan and only its label is kept. One checked in, two reserved.
insert into public.reservations (id, workspace_id, member_id, starts_at, ends_at, status, space_label)
values (pg_temp.u(403), pg_temp.u(101), pg_temp.u(202), now() - interval '1 hour', now() + interval '1 hour', 'checked_in', 'Terrace'),
       (pg_temp.u(404), pg_temp.u(101), pg_temp.u(202), now() + interval '5 hours', now() + interval '6 hours', 'reserved', 'Terrace'),
       (pg_temp.u(405), pg_temp.u(101), pg_temp.u(202), now() + interval '7 hours', now() + interval '8 hours', 'reserved', 'Terrace');

-- ── 1, 2: a booking that names no place, in a business with an external level ──
select is(pg_temp.row_of(2, 403), '1', 'its member lists a booking whose place was removed');
select is(pg_temp.events_of(2, 403), '1', 'and sees its events');
select is(pg_temp.row_of(1, 403) || '/' || pg_temp.events_of(1, 403), '1/1', 'the owner lists it and sees its events');
select is(pg_temp.row_of(4, 403) || '/' || pg_temp.events_of(4, 403), '1/1', 'an administrator lists it and sees its events');
select is(pg_temp.row_of(3, 403) || '/' || pg_temp.events_of(3, 403), pg_temp.row_of(3, 401) || '/' || pg_temp.events_of(3, 401),
  'another member reads it as a booking of the business''s own floor');
select ok(pg_temp.as_user(2, format('select public.export_my_data(%L)->>''events''', pg_temp.u(101)))
            like '%' || (select id::text from public.events where reservation_id = pg_temp.u(403) limit 1) || '%',
  'the member''s own export carries its events');
select is(pg_temp.cancel(2, 404), '', 'its member cancels it');
select is(pg_temp.cancel(1, 405), '', 'the owner cancels it');
select is(pg_temp.cancel(2, 403), '', 'a checked-in one is cancelled by its member');
select is((select string_agg(status, ',' order by id) from public.reservations where id in (pg_temp.u(403), pg_temp.u(404), pg_temp.u(405))),
  'cancelled,cancelled,cancelled', 'all three are cancelled');

-- ── the 0809 rules hold: the rented room's booking stays hidden ──
select is(pg_temp.events_of(3, 402), '0', 'another member does not see the events of a booking in a room hidden from them');
select is(pg_temp.events_of(2, 402), '1', 'its member does');

-- ── 4: deciding a booking request needs the right to see the booking ──
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, reservation_id, payload, status)
values (pg_temp.u(601), pg_temp.u(101), 'reservation', 'created', pg_temp.u(202), pg_temp.u(202), pg_temp.u(402), '{}', 'pending'),
       (pg_temp.u(602), pg_temp.u(101), 'reservation', 'created', pg_temp.u(202), pg_temp.u(202), pg_temp.u(401), '{}', 'pending');
select is(pg_temp.decide(4, pg_temp.u(601)), pg_temp.decide(4, gen_random_uuid()),
  'a request for a booking the administrator may not see is answered as an unknown event');
select ok(pg_temp.decide(4, pg_temp.u(602)) not like '%unknown event%',
  'a request for a booking the administrator sees is not');

-- ── 5: the sites right adds an external level and reads it back ──
select is(pg_temp.as_user(1, format(
  'insert into public.levels (workspace_id, name, sort_order, kind) values (%L, ''Annex'', 2, ''external'') returning name',
  pg_temp.u(101))), 'Annex', 'whoever holds the sites right adds an external level and reads it back');

-- ── 3: a business without an external level answers at once ──
select ok(not exists (select 1 from regexp_split_to_table(pg_temp.as_user(3, 'select coalesce(string_agg(x::text, '',''), '''') from public.member_workspaces_without_external_level() x'), ',') w where w = pg_temp.u(101)::text),
  'a business with an external level is not among the caller''s businesses without one');
delete from public.room_rental_audience where rental_id = pg_temp.u(502);
delete from public.reservations where id = pg_temp.u(402);
delete from public.room_rentals where id = pg_temp.u(502);
update public.levels set kind = 'own' where workspace_id = pg_temp.u(101);
select is(pg_temp.as_user(3, format('select public.booking_event_visible(%L, %L)::text', pg_temp.u(101), gen_random_uuid())),
  'true', 'without an external level the booking rule answers at once');
select is(pg_temp.events_of(2, 403) || '/' || pg_temp.events_of(1, 403), '2/2',
  'there the member and the owner see the events of a booking that names no place');
select ok(exists (select 1 from regexp_split_to_table(pg_temp.as_user(3, 'select coalesce(string_agg(x::text, '',''), '''') from public.member_workspaces_without_external_level() x'), ',') w where w = pg_temp.u(101)::text),
  'once it has none, it is');
select ok(not has_function_privilege('anon', 'public.member_workspaces_without_external_level()', 'execute'),
  'no one signed out asks it');

select * from finish();
rollback;
