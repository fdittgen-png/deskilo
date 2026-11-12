-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3062 -- a new owner reaches a first booking on a CLEAN workspace (no
-- template), every step through the real commands as the authenticated role,
-- and every state read back from what the database holds, never from a route
-- visit or a returned value.
--
--   1. The owner creates the space and reads its setup status: the hours and
--      the basics are there from the start; the places and the members'
--      booking right are missing, each named, each with the canonical
--      workspace setup route (/setup/step/<id>), none under /settings; the
--      booking step waits for exactly those two, and the "bookable" outcome is
--      not reached.
--   2. A person joins with the code and the owner admits them.
--   3. The owner adds one resource. The status is read again (the "reload"):
--      the places are ready, the booking right still is not -- nothing is
--      completed falsely and the progress made stays.
--   4. The owner grants the booking right. The "bookable" outcome is reached
--      and the booking step is open, not ready.
--   5. A booking the rules refuse (too short) is refused; the member books a
--      valid slot.
--   6. The owner reads the SAME booking (workspace, resource, time, member)
--      and the booking step is ready. The outcome stays reached, and the
--      remaining required work (money, invoice, live) is listed, not hidden.
--      Reading the status changes nothing: two reads are equal.
begin;
select plan(25);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.fb.ws')::uuid
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- One step of the status as the owner reads it: "state|route|blocked_by".
create function pg_temp.step(p_step text) returns text language sql as $$
  select s->>'state' || '|' || (s->>'route') || '|' || (s->'blocked_by')::text
    from jsonb_array_elements(public.workspace_setup_status(pg_temp.ws())->'steps') s
   where s->>'step' = p_step
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The outcome "bookable": "reached|ready/required".
create function pg_temp.bookable() returns text language sql as $$
  select (m->>'reached') || '|' || (m->>'ready') || '/' || (m->>'required')
    from jsonb_array_elements(public.workspace_setup_status(pg_temp.ws())->'milestones') m
   where m->>'milestone' = 'bookable'
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000003062' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@first-booking.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3']) s;
-- a1 owner, a2 the member, a3 a stranger.

-- 1. A clean space.
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a1');
select set_config('deskilo.fb.ws', public.create_workspace(
  'First booking', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('deskilo.fb.code',
  (select invite_code from public.workspaces where id = pg_temp.ws()), true);

select is(pg_temp.step('basics'), 'ready|/setup/step/basics|[]',
          'the basics (timezone, currency) are there from the start');
select is(pg_temp.step('hours'), 'ready|/setup/step/hours|[]',
          'so are the opening days');
select is(pg_temp.step('places'), 'needs_configuration|/setup/step/places|[]',
          'no resource yet: the places step names itself and its setup route');
select is(pg_temp.step('member_rights'), 'needs_configuration|/setup/step/member_rights|[]',
          'the members'' booking right is missing and says where it is set');
select is(pg_temp.step('first_booking'), 'blocked|/reserve|["places", "member_rights"]',
          'the booking step waits for exactly those two');
select is(pg_temp.bookable(), 'false|2/4', 'the bookable outcome is not reached: 2 of 4 required steps');
select is((select count(*)::int from jsonb_array_elements(public.workspace_setup_status(pg_temp.ws())->'steps') s
            where s->>'route' like '/settings%' and s->>'milestone' = 'bookable'), 0,
          'no step of the first-booking path sends the owner to a personal /settings screen');

-- 2. A member joins and is admitted; the right is not granted yet.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a2');
select is(public.join_workspace(current_setting('deskilo.fb.code')), pg_temp.ws(),
          'the member joins with the invitation code');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a1');
select is((public.request_member_status_change(
            (select id from public.members where workspace_id = pg_temp.ws()
                and user_id = '00000000-0000-4000-8000-0000003062a2'), 'active')->>'pending'),
          'false', 'the owner admits the member');

-- 3. One resource, then the status is read again.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a1');
create function pg_temp.add_resource() returns uuid language plpgsql as $f$
declare l uuid; o uuid; d uuid; st uuid;
begin
  insert into public.levels (workspace_id, name) values (pg_temp.ws(), 'Ground') returning id into l;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
    values (pg_temp.ws(), l, 'Open space', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
    values (pg_temp.ws(), o, 1, 1, 4, 2) returning id into d;
  insert into public.seats (workspace_id, desk_id, x, y)
    values (pg_temp.ws(), d, 1, 1) returning id into st;
  return st;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select set_config('deskilo.fb.seat', pg_temp.add_resource()::text, true);
select is(pg_temp.step('places'), 'ready|/setup/step/places|[]',
          'after the reload the places step is ready: it reads the seat, not a visit');
select is(pg_temp.step('hours'), 'ready|/setup/step/hours|[]',
          'and the step done before stays done');
select is(pg_temp.step('member_rights'), 'needs_configuration|/setup/step/member_rights|[]',
          'while the booking right is still open: nothing was completed falsely');
select is(pg_temp.step('first_booking'), 'blocked|/reserve|["member_rights"]',
          'the booking step now waits for the right alone');
select is(pg_temp.bookable(), 'false|3/4', 'the outcome is not reached: 3 of 4');

-- The member cannot book yet.
reset role;
-- A weekday: move to the next Monday when tomorrow is a weekend day.
select set_config('deskilo.fb.from', ((((now() at time zone 'Europe/Paris')::date + 1
    + case extract(isodow from (now() at time zone 'Europe/Paris')::date + 1) when 6 then 2 when 7 then 1 else 0 end)
    + time '09:00') at time zone 'Europe/Paris')::text, true);
select set_config('deskilo.fb.to', ((((now() at time zone 'Europe/Paris')::date + 1
    + case extract(isodow from (now() at time zone 'Europe/Paris')::date + 1) when 6 then 2 when 7 then 1 else 0 end)
    + time '11:00') at time zone 'Europe/Paris')::text, true);
create function pg_temp.book(p_from text, p_to text) returns uuid language sql as $$
  select public.create_reservation_once(gen_random_uuid(), pg_temp.ws(),
    current_setting('deskilo.fb.seat')::uuid, null, null, null,
    current_setting(p_from)::timestamptz, current_setting(p_to)::timestamptz, false)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- (The server does not yet refuse a member without the right: #3269. The app
-- gates /reserve and /plan on it, so the journey grants it before booking.)

-- 4. The owner grants the right.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a1');
select lives_ok($$ select public.set_role_permission(pg_temp.ws(), 'member', 'makeReservations', true) $$,
                'the owner grants the members the right to book');
select is(pg_temp.step('member_rights'), 'ready|/setup/step/member_rights|[]', 'the right step is ready');
select is(pg_temp.bookable(), 'true|4/4', 'the bookable outcome is reached');
select is(pg_temp.step('first_booking'), 'needs_configuration|/reserve|[]',
          'the booking step is open, not ready: no booking exists yet');

-- 5. A booking the rules refuse names the rule; a valid one is made.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a2');
select set_config('deskilo.fb.short', (select (current_setting('deskilo.fb.from')::timestamptz + interval '5 minutes')::text), true);
select throws_ok($$ select pg_temp.book('deskilo.fb.from', 'deskilo.fb.short') $$, 'DKK09',  -- #3810: its code
                 'below the minimum duration of 30 minutes',
                 'a booking shorter than the space allows is refused and names the rule and the minimum');
select set_config('deskilo.fb.booking', pg_temp.book('deskilo.fb.from', 'deskilo.fb.to')::text, true);
select is((select status::text from public.reservations where id = current_setting('deskilo.fb.booking')::uuid),
          'reserved', 'the member''s valid booking reads back as reserved');

-- 6. The owner sees the same booking and the setup shows it.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a1');
select is((select workspace_id::text || '/' || seat_id::text || '/' || member_id::text || '/' || status::text
             from public.reservations where id = current_setting('deskilo.fb.booking')::uuid),
          pg_temp.ws()::text || '/' || current_setting('deskilo.fb.seat') || '/'
            || (select id::text from public.members where workspace_id = pg_temp.ws()
                   and user_id = '00000000-0000-4000-8000-0000003062a2') || '/reserved',
          'the owner reads the same booking: same space, resource and member');
select is((select starts_at = current_setting('deskilo.fb.from')::timestamptz
                and ends_at = current_setting('deskilo.fb.to')::timestamptz
             from public.reservations where id = current_setting('deskilo.fb.booking')::uuid),
          true, 'at the same time');
select is(pg_temp.step('first_booking'), 'ready|/reserve|[]', 'the booking step is ready');
select ok(public.workspace_setup_status(pg_temp.ws()) = public.workspace_setup_status(pg_temp.ws())
          and pg_temp.bookable() = 'true|4/4'
          and (select count(*) from jsonb_array_elements(public.workspace_setup_status(pg_temp.ws())->'milestones') m
                where m->>'reached' = 'false') = 3,
          'reading the status changes nothing, the outcome stays reached and three outcomes remain to do');

-- A stranger reads none of it.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000003062a3');
select is((select count(*)::int from public.reservations where workspace_id = pg_temp.ws()), 0,
          'a stranger reads none of the space''s bookings');

select * from finish();
rollback;
