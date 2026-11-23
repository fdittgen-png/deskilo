-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- Places and booking events have the same visibility in rules, calendar,
-- direct reads and commands. Unknown and unreadable targets answer alike;
-- the booking's member, the rental audience and sites holders retain access.
begin;
select plan(64);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004153' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'places' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 5) n;
-- administrators read the figures and the bookings, not the sites
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(101), 'Places fixture', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"capacityKpi": true, "placeFeedback": true, "externalRooms": true, "levelBooking": true, "officeBooking": true, "deskBooking": true, "kioskMode": true, "adminSeatBlocking": true}',
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
values (pg_temp.u(501), pg_temp.u(101), 'SUP-FIXTURE', 'Next door');
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



insert into public.members (id, workspace_id, user_id, is_kiosk, status)
values (pg_temp.u(205), pg_temp.u(101), pg_temp.u(5), true, 'active');
insert into public.member_badges (workspace_id, member_id, token_hash)
values (pg_temp.u(101), pg_temp.u(203), public.badge_token_hash('place-outsider')),
       (pg_temp.u(101), pg_temp.u(202), public.badge_token_hash('place-audience'));
update public.workspaces set booking_rules = booking_rules ||
  '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}'
 where id = pg_temp.u(101);
update public.levels set bookable_as_whole = true where workspace_id = pg_temp.u(101);
update public.offices set bookable_as_whole = true where workspace_id = pg_temp.u(101);
update public.desks set bookable_as_whole = true where workspace_id = pg_temp.u(101);
update public.members set can_reserve_level = true where workspace_id = pg_temp.u(101);
-- Check-in and check-out items are selected by their own timestamps.
update public.reservations set checked_in_at = now(), checked_out_at = now()
 where workspace_id = pg_temp.u(101);
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
create function pg_temp.t(h int) returns timestamptz language sql as $$
  select ((current_date + 3)::timestamp + make_interval(hours => h)) at time zone 'Europe/Paris';
$$;
create function pg_temp.visible(n int, kind text, id uuid) returns text language plpgsql as $$
begin
  if kind = 'reservation' then
    return pg_temp.as_user(n, format('select public.reservation_place_visible(%L,%L,%L,null,null,null)', pg_temp.u(101), pg_temp.u(202), id));
  end if;
  return pg_temp.as_user(n, format('select public.%I(%L)', kind, id));
end $$;
select is(pg_temp.visible(3, kind, id), pg_temp.visible(3, kind, pg_temp.u(999)),
          kind || ': unreadable and unknown answers agree')
 from (values ('room_visible',pg_temp.u(312)), ('level_visible',pg_temp.u(302)),
              ('desk_room_visible',pg_temp.u(322)), ('reservation',pg_temp.u(332))) x(kind,id);
select is(pg_temp.visible(3, kind, pg_temp.u(999)), 'false', kind || ': unknown is false')
 from unnest(array['room_visible','level_visible','desk_room_visible','reservation']) kind;
select is(pg_temp.visible(n, kind, id), 'true', kind || ': permitted reader ' || n)
 from (values ('room_visible',pg_temp.u(312)), ('level_visible',pg_temp.u(302)),
              ('desk_room_visible',pg_temp.u(322)), ('reservation',pg_temp.u(332))) x(kind,id)
 cross join unnest(array[1,2]) n;
select is(pg_temp.as_user(2, format('select public.reservation_place_visible(%L,%L,%L,null,null,null)',
 pg_temp.u(999),pg_temp.u(202),pg_temp.u(332))), 'false', 'a place outside the named business is unknown');

select is(pg_temp.as_user(3,format('select public.reservation_place_visible(%L,%L,%L,null,null,null)',
 pg_temp.u(101),pg_temp.u(203),pg_temp.u(332))), 'false', 'naming oneself without a booking does not grant place visibility');
select is(pg_temp.as_user(2,format('select public.reservation_place_visible(%L,%L,%L,null,null,null)',
 pg_temp.u(101),pg_temp.u(202),pg_temp.u(999))), 'false', 'naming oneself does not make an unknown place visible');

create function pg_temp.calendar(n int, kind text) returns text language sql as $$
  select pg_temp.as_user(n, format($q$select count(*) from jsonb_array_elements(public.calendar_items(
    %L,now()-interval '1 day',now()+interval '1 day',array[%L],%L)->'items') i$q$,
    pg_temp.u(101), kind, pg_temp.u(202)));
$$;
select is(pg_temp.calendar(4, kind), '1', 'calendar ' || kind || ' shows only the visible booking')
 from unnest(array['reservation','checkin','checkout','event']) kind;
select is(pg_temp.calendar(n, kind), '2', 'calendar ' || kind || ' retains permitted reader ' || n)
 from unnest(array[1,2]) n cross join unnest(array['reservation','checkin','checkout']) kind;
select is(pg_temp.as_user(4, format('select count(*) from public.events where reservation_id=%L', pg_temp.u(402))),
 '0', 'direct event reads hide the unreadable booking');
select ok(pg_temp.as_user(n, format('select count(*) from public.events where reservation_id=%L', pg_temp.u(402)))::int > 0,
 'direct events retain permitted reader ' || n) from unnest(array[1,2]) n;

create function pg_temp.block(n int, id uuid) returns text language sql as $$
 select pg_temp.as_user(n, format('select public.set_seat_block(%L,%L,%L)', id, pg_temp.t(14), pg_temp.t(13)));
$$;
select is(pg_temp.block(n,pg_temp.u(332)), pg_temp.block(n,pg_temp.u(999)), 'seat block checks authority and visibility before dates for reader ' || n)
 from unnest(array[3,4]) n;
select is(pg_temp.block(3,pg_temp.u(331)), pg_temp.block(3,pg_temp.u(999)), 'no seat lookup precedes the right check');
select ok(pg_temp.block(1,pg_temp.u(332)) like 'ERR %blocked_to must be after blocked_from', 'sites holder reaches date validation');

-- Server-only event readers receive the caller's identity from their facade.
create function pg_temp.server_as(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute p_sql into v;
  return coalesce(v, 'null');
end $f$;
create function pg_temp.validation(n int, id uuid) returns text language sql as $$
 select pg_temp.server_as(n,format($q$select public.mcp_read_v1(%L,
 (select m from public.members m where id=%L),'get_validation',jsonb_build_object('event_id',%L))::text$q$,
 pg_temp.u(101),pg_temp.u(200+n),id));
$$;
create temp table booking_events as select reservation_id,id from public.events
 where reservation_id in (pg_temp.u(401),pg_temp.u(402));
select is(pg_temp.validation(4,(select id from booking_events where reservation_id=pg_temp.u(402))),
 pg_temp.validation(4,pg_temp.u(999)), 'event details answer unreadable and unknown alike');
select ok(pg_temp.validation(n,(select id from booking_events where reservation_id=pg_temp.u(402))) like '%event_id%',
 'permitted event reader ' || n) from unnest(array[1,2]) n;
select is(pg_temp.server_as(4,format($q$select public.mcp_target(%L,'respond_to_validation',jsonb_build_object('event_id',%L,'accept',true))$q$,
 pg_temp.u(101),(select id from booking_events where reservation_id=pg_temp.u(402)))), 'null',
 'command target resolution follows event visibility');
update public.events set status='pending' where id in (select id from booking_events);
select is(pg_temp.server_as(4,format($q$select jsonb_array_length(public.mcp_read_v1(%L,
 (select m from public.members m where id=%L),'list_pending_validations','{}')->'items')$q$,
 pg_temp.u(101),pg_temp.u(204))), '1', 'pending list retains only the visible booking');
select is(pg_temp.server_as(2,format($q$select jsonb_array_length(public.mcp_read_v1(%L,
 (select m from public.members m where id=%L),'list_pending_validations','{}')->'items')$q$,
 pg_temp.u(101),pg_temp.u(202))), '2', 'pending list retains the members own bookings');
-- The actor of an event may differ from the member who booked.
update public.events set actor_member_id=pg_temp.u(204) where reservation_id=pg_temp.u(402);
select is(pg_temp.as_user(4,format($q$select count(*) from jsonb_array_elements(public.export_my_data(%L)->'events') e
 where e->>'reservation_id'=%L$q$,pg_temp.u(101),pg_temp.u(402))), '0', 'personal export applies booking visibility even to the actor');
select is(pg_temp.as_user(2,format($q$select count(*) from jsonb_array_elements(public.export_my_data(%L)->'events') e
 where e->>'reservation_id'=%L$q$,pg_temp.u(101),pg_temp.u(402))), '1', 'personal export retains the booking member event');
insert into public.event_decisions(event_id,member_id,decision)
 select id,pg_temp.u(201),'accept' from booking_events;
select is(pg_temp.calendar(4,'validation'), '1', 'calendar decisions follow booking visibility');
select is(pg_temp.calendar(2,'validation'), '2', 'calendar decisions retain own bookings');
update public.events set status='applied' where id in (select id from booking_events);

-- A removed audience does not hide the member's own booking and its events.
delete from public.room_rental_audience where rental_id=pg_temp.u(502);
select is(pg_temp.visible(2,'reservation',pg_temp.u(332)), 'true', 'own booking survives audience removal');
select ok(pg_temp.as_user(2, format('select count(*) from public.events where reservation_id=%L',pg_temp.u(402)))::int > 0,
 'own booking events survive audience removal');
insert into public.room_rental_audience (workspace_id,rental_id,member_id) values (pg_temp.u(101),pg_temp.u(502),pg_temp.u(202));

-- Every kind of favourite follows the same rule.
insert into public.resource_favorites(workspace_id,member_id,kind,resource_id)
 select pg_temp.u(101),pg_temp.u(200+n),kind,id from unnest(array[2,3]) n
 cross join (values ('desk',pg_temp.u(322)),('office',pg_temp.u(312)),('level',pg_temp.u(302))) x(kind,id);
select is(pg_temp.as_user(3,format('select jsonb_array_length(public.my_favorites(%L))',pg_temp.u(101))), '1', 'only the visible favourite remains');
select is(pg_temp.as_user(2,format('select jsonb_array_length(public.my_favorites(%L))',pg_temp.u(101))), '5', 'audience retains all favourite kinds');

create function pg_temp.series(kind text, id uuid) returns text language sql as $$
 select pg_temp.as_user(3,format('select public.create_series(%L,null,%L,%L,''daily'',%L,%L,%L,%L)',
 pg_temp.u(101),pg_temp.t(10),pg_temp.t(11),pg_temp.t(10)+interval '1 day',
 case when kind='desk' then id end,case when kind='office' then id end,case when kind='level' then id end));
$$;
select is(pg_temp.series(kind,id),pg_temp.series(kind,pg_temp.u(999)), 'series on unreadable ' || kind || ' answers as unknown')
 from (values ('desk',pg_temp.u(322)),('office',pg_temp.u(312)),('level',pg_temp.u(302))) x(kind,id);
select is(pg_temp.series(kind,id), 'ERR DKK22 ' || kind || ' not bookable as a whole', 'series reaches the ' || kind || ' lookup')
 from (values ('desk',pg_temp.u(322)),('office',pg_temp.u(312)),('level',pg_temp.u(302))) x(kind,id);
create function pg_temp.kiosk(badge text, kind text, id uuid) returns text language sql as $$
 select pg_temp.as_user(5,format('select public.kiosk_act(%L,%L,''reserve'',%L,%L,%L,%L)',
 pg_temp.u(101),badge,case when kind='seat' then id end,pg_temp.t(15),pg_temp.t(16),case when kind='level' then id end));
$$;
select is(pg_temp.kiosk('place-outsider',kind,id),pg_temp.kiosk('place-outsider',kind,pg_temp.u(999)),
 'badge holder outside the audience: kiosk ' || kind || ' answers as unknown')
 from (values ('seat',pg_temp.u(332)),('level',pg_temp.u(302))) x(kind,id);
select is(pg_temp.kiosk('place-outsider','seat',pg_temp.u(332)), 'ERR P0001 unknown seat', 'kiosk reaches the seat lookup');
select is(pg_temp.kiosk('place-outsider','level',pg_temp.u(302)), 'ERR DKK22 level not bookable as a whole', 'kiosk reaches the level lookup');
select ok(pg_temp.kiosk('place-audience','seat',pg_temp.u(332)) like '%reservation_id%', 'audience badge books the seat');
create function pg_temp.cancel(n int, id uuid) returns text language sql as $$
 select pg_temp.as_user(n, format('select public.cancel_reservation(%L)', id));
$$;
select is(pg_temp.cancel(4,pg_temp.u(402)), pg_temp.cancel(4,pg_temp.u(999)), 'cancel hidden and unknown give the same code and message');
select is((select status from public.reservations where id=pg_temp.u(402)), 'reserved', 'refused cancellation leaves the booking');

select is(pg_temp.cancel(2,pg_temp.u(402)), '', 'the booking member can cancel');
select * from finish();
rollback;
