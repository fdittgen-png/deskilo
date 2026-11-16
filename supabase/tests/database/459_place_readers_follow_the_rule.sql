-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4144 (0806): the server functions that read reservations and places follow
-- their reading rules. A room on an external level, rented to an audience, is
-- seen by those who manage the sites and by its audience; its bookings by
-- their own member and by whoever sees it. The calendar shows another member's bookings as the
-- bookings table would; the capacity figures of a level the caller may not
-- see are those of an unknown level, error and all; a member's favourites
-- show the places they may see.
begin;
select plan(11);

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
-- The labels of [p_member]'s bookings user [n] finds in the calendar.
create function pg_temp.calendar_labels(n int, p_member int) returns text language sql as $$
  select pg_temp.as_user(n, format(
    $q$select coalesce(string_agg(i ->> 'title', ',' order by i ->> 'title'), '')
         from jsonb_array_elements(public.calendar_items(%L, now(), now() + interval '1 day', array['reservation'], %L) -> 'items') i$q$,
    pg_temp.u(101), pg_temp.u(200 + p_member)));
$$;
create function pg_temp.capacity(n int, p_level uuid) returns text language sql as $$
  select pg_temp.as_user(n, format(
    $q$select (public.kpi_seat_capacity(%L, now() - interval '1 day', now(), %L) ->> 'level_id')$q$,
    pg_temp.u(101), p_level));
$$;
create function pg_temp.favourites(n int) returns text language sql as $$
  select pg_temp.as_user(n, format(
    $q$select coalesce(string_agg(f ->> 'resource_id', ',' order by f ->> 'resource_id'), '')
         from jsonb_array_elements(public.my_favorites(%L)) f$q$, pg_temp.u(101)));
$$;

-- ── the calendar's bookings ──
select is(pg_temp.calendar_labels(3, 2), 'S1',
  'another member finds a member''s booking of the floor they see, not of the rented room they are not open to');
select is(pg_temp.calendar_labels(4, 2), 'S1', 'so does an administrator who does not manage the sites');
-- 202 leaves the room's audience: their own bookings still come
delete from public.room_rental_audience where rental_id = pg_temp.u(502) and member_id = pg_temp.u(202);
select is(pg_temp.calendar_labels(2, 2), 'S1,S2',
  'the member finds their own bookings, wherever they are, even in a room no longer open to them');
insert into public.room_rental_audience (workspace_id, rental_id, member_id)
values (pg_temp.u(101), pg_temp.u(502), pg_temp.u(202));
select is(pg_temp.calendar_labels(1, 2), 'S1,S2', 'and who manages the sites finds them all');

-- ── the capacity of a level ──
select is(pg_temp.capacity(4, pg_temp.u(301)), pg_temp.u(301)::text, 'the figures of a level the caller sees');
select is(pg_temp.capacity(4, pg_temp.u(302)), pg_temp.capacity(4, gen_random_uuid()),
  'a level the caller may not see is answered as an unknown level');
select ok(pg_temp.capacity(4, pg_temp.u(302)) like 'ERR 22023 unknown level%', 'the same error, the same code');
select is(pg_temp.capacity(1, pg_temp.u(302)), pg_temp.u(302)::text, 'who manages the sites reads it');

-- ── favourites ──
select is(pg_temp.favourites(3), pg_temp.u(331)::text, 'a member''s favourites show the places they may see, not a room not open to them');
select is(pg_temp.favourites(2), pg_temp.u(331)::text || ',' || pg_temp.u(332)::text, 'the room''s audience sees it among their favourites');
select is(pg_temp.favourites(1), pg_temp.u(332)::text, 'who manages the sites sees the room they favour');

select * from finish();
rollback;
