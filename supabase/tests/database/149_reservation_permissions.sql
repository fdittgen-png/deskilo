-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2137 / 0364 — manageReservations, given through a role, works.
--
-- The matrix, for each door 0364 opened: a member who holds the
-- permission ONLY through one of the workspace's own roles succeeds; the
-- built-in Administrator succeeds; a member without it is refused; the
-- owner still succeeds. "Never your own allowance" stays. Every call runs
-- as `authenticated`.
begin;
select plan(20);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner   uuid := '00000000-0000-4000-8000-0000000007e1';
  u_admin   uuid := '00000000-0000-4000-8000-0000000007e2';
  u_role    uuid := '00000000-0000-4000-8000-0000000007e3';
  u_plain   uuid := '00000000-0000-4000-8000-0000000007e4';
  u_subject uuid := '00000000-0000-4000-8000-0000000007e5';
  ws uuid; r uuid; m_role uuid; m_subject uuid;
  lvl uuid; upstairs uuid; office uuid; desk uuid; seat uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'resv-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_admin, 'admin'), (u_role, 'role'),
                 (u_plain, 'plain'), (u_subject, 'subject')) v(u, n);
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags)
  values ('Reservation permissions', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true, "levelBooking": true}'::jsonb)
  returning id into ws;
  -- Bookings below are for the coming days through the real RPCs: open
  -- every weekday so the file does not turn red on a Friday.
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       || '{"open_weekdays": [1, 2, 3, 4, 5, 6, 7]}'::jsonb
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_admin, false, true),
         (ws, u_plain, false, false);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_role, false, false) returning id into m_role;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_subject, false, false) returning id into m_subject;
  insert into public.workspace_roles (workspace_id, key, permissions, names)
  values (ws, 'front_desk', array['manageReservations'], '{"en": "Front desk"}'::jsonb)
  returning id into r;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r, m_role);

  delete from public.levels where workspace_id = ws;
  insert into public.levels (workspace_id, name, sort_order) values (ws, 'Ground', 0)
  returning id into lvl;
  insert into public.levels (workspace_id, name, sort_order, bookable_as_whole)
  values (ws, 'Upstairs', 1, true) returning id into upstairs;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lvl, 'Open space', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y)
  values (ws, desk, 1, 1) returning id into seat;

  perform set_config('deskilo.rp.ws', ws::text, false);
  perform set_config('deskilo.rp.seat', seat::text, false);
  perform set_config('deskilo.rp.upstairs', upstairs::text, false);
  perform set_config('deskilo.rp.m_role', m_role::text, false);
  perform set_config('deskilo.rp.m_subject', m_subject::text, false);
  perform set_config('deskilo.rp.owner', u_owner::text, false);
  perform set_config('deskilo.rp.admin', u_admin::text, false);
  perform set_config('deskilo.rp.role', u_role::text, false);
  perform set_config('deskilo.rp.plain', u_plain::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.rp.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.rp.' || p)::uuid;
$$;

-- Nine to one, `p_days` from today: one window per booking, so no two
-- bookings of the subject ever overlap.
create or replace function pg_temp.at(p_days int) returns timestamptz language sql as $$
  select date_trunc('day', now()) + make_interval(days => p_days, hours => 9);
$$;

-- Booking FOR the subject, on the seat, `p_days` from today.
create or replace function pg_temp.book_for(p_days int) returns text language sql as $$
  select format($q$ select public.admin_create_reservation_for(%L, %L, %L, %L, %L) $q$,
    pg_temp.id('ws'), pg_temp.id('m_subject'), pg_temp.id('seat'),
    pg_temp.at(p_days), pg_temp.at(p_days) + interval '4 hours');
$$;

-- Booking the whole Upstairs level for oneself, `p_days` from today.
create or replace function pg_temp.book_level(p_days int) returns text language sql as $$
  select format($q$ select public.create_reservation(%L, null, null, %L, %L, false, %L, null) $q$,
    pg_temp.id('ws'), pg_temp.at(p_days), pg_temp.at(p_days) + interval '4 hours',
    pg_temp.id('upstairs'));
$$;

select pg_temp.seed();
set local role authenticated;

-- ── a member holding manageReservations through a role ─────────────────
select pg_temp.act_as('role');
select lives_ok(pg_temp.book_for(1), 'a role holder books for another member');
select lives_ok(format($$ select public.set_member_reservation_limit(%L, 5) $$, pg_temp.id('m_subject')),
  'sets a member''s reservation limit');
select lives_ok(format($$ select public.set_member_simultaneous_limit(%L, 2) $$, pg_temp.id('m_subject')),
  'and their simultaneous allowance');
select lives_ok(format($$ select public.set_member_level_permission(%L, true) $$, pg_temp.id('m_subject')),
  'and whether they may reserve a whole level');
select throws_ok(format($$ select public.set_member_reservation_limit(%L, 50) $$, pg_temp.id('m_role')),
  'P0001', 'cannot set your own reservation limit', 'but never their own allowance');
select lives_ok(pg_temp.book_level(2), 'books a whole level as staff');
select lives_ok(format($$ select public.create_series(%L, null, %L, %L, 'weekly', %L, null, null, %L) $$,
    pg_temp.id('ws'), pg_temp.at(3), pg_temp.at(3) + interval '4 hours', pg_temp.at(10),
    pg_temp.id('upstairs')),
  'and a weekly series of the whole level');

-- ── the built-in Administrator ─────────────────────────────────────────
select pg_temp.act_as('admin');
select lives_ok(pg_temp.book_for(4), 'the Administrator books for another member');
select lives_ok(format($$ select public.set_member_reservation_limit(%L, 6) $$, pg_temp.id('m_subject')),
  'and sets their limit');
select lives_ok(pg_temp.book_level(5), 'and books a whole level');

-- ── a member without the permission ────────────────────────────────────
select pg_temp.act_as('plain');
select throws_ok(pg_temp.book_for(6), 'P0001', 'not an admin of this workspace',
  'a plain member books for nobody');
select throws_ok(format($$ select public.set_member_reservation_limit(%L, 7) $$, pg_temp.id('m_subject')),
  'P0001', 'not an admin of this workspace', 'sets no limit');
select throws_ok(format($$ select public.set_member_simultaneous_limit(%L, 3) $$, pg_temp.id('m_subject')),
  'P0001', 'not an admin of this workspace', 'nor a simultaneous allowance');
select throws_ok(format($$ select public.set_member_level_permission(%L, false) $$, pg_temp.id('m_subject')),
  'P0001', 'not an admin of this workspace', 'nor a level permission');
select throws_ok(pg_temp.book_level(6), 'P0001', 'not allowed to reserve a level',
  'and books no whole level without being allowed to');
select throws_ok(format($$ select public.create_series(%L, null, %L, %L, 'weekly', %L, null, null, %L) $$,
    pg_temp.id('ws'), pg_temp.at(6), pg_temp.at(6) + interval '4 hours', pg_temp.at(13),
    pg_temp.id('upstairs')),
  'P0001', 'not allowed to reserve a level', 'nor a series of one');

-- ── the owner still does ───────────────────────────────────────────────
select pg_temp.act_as('owner');
select lives_ok(pg_temp.book_for(7), 'the owner books for another member');
select lives_ok(format($$ select public.set_member_simultaneous_limit(%L, 1) $$, pg_temp.id('m_subject')),
  'and sets their simultaneous allowance');

-- ── what the role holder did is recorded as theirs ─────────────────────
reset role;
select is((select max_active_reservations from public.members where id = pg_temp.id('m_subject')), 6,
  'the subject carries the last limit set');
select is((select count(*)::int from public.reservations
            where member_id = pg_temp.id('m_subject') and status = 'reserved'), 3,
  'three bookings were made for the subject, none by the plain member');

select * from finish();
rollback;
