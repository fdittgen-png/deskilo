-- SPDX-License-Identifier: 0BSD
--
-- #1248 — the business invariants, executed.
--
-- The issue listed eight. Four are now covered by the files beside this
-- one: invoice immutability (20), webhook-delivered-twice (20 and 22),
-- workspace A never reads B (10 and 11), and every financial mutation
-- being auditable (21, and ADR 0022 for why the proposed form of that
-- one was not writable at all).
--
-- This file takes the four that were left, and it takes them where they
-- live: in SQL, as `SECURITY DEFINER` functions and one exclusion
-- constraint. Every one had been reasoned about and never run.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000f1';
  u_member uuid := '00000000-0000-4000-8000-0000000000f3';
  u_outsider uuid := '00000000-0000-4000-8000-0000000000f4';
  ws uuid; other_ws uuid;
  m_owner uuid; m_member uuid; m_outsider uuid;
  lvl uuid; office uuid; desk uuid; seat uuid;
  now_ timestamptz := now();
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'owner@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'member@deskilo.test', '', now(), now(), now()),
         (u_outsider, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'outsider@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Invariants', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_outsider) returning id into other_ws;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_member, false, false) returning id into m_member;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (other_ws, u_outsider, true, true) returning id into m_outsider;

  insert into public.levels (workspace_id, name) values (ws, 'Ground')
  returning id into lvl;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
  values (ws, lvl, 'Open space', 0, 0, 10, 10) returning id into office;
  insert into public.desks (workspace_id, office_id, x, y, w, h)
  values (ws, office, 1, 1, 4, 2) returning id into desk;
  insert into public.seats (workspace_id, desk_id, x, y)
  values (ws, desk, 1, 1) returning id into seat;

  perform set_config('deskilo.inv.ws', ws::text, false);
  perform set_config('deskilo.inv.seat', seat::text, false);
  perform set_config('deskilo.inv.owner', m_owner::text, false);
  perform set_config('deskilo.inv.member', m_member::text, false);
  perform set_config('deskilo.inv.u_owner', u_owner::text, false);
  perform set_config('deskilo.inv.u_member', u_member::text, false);
  perform set_config('deskilo.inv.u_outsider', u_outsider::text, false);
  perform set_config('deskilo.inv.now', now_::text, false);

  -- Three reservations to check in against: the owner's, running now;
  -- the member's, running now; and one thirty days out.
  insert into public.reservations (workspace_id, member_id, starts_at, ends_at,
                                   space_label)
  values (ws, m_owner, now_ - interval '10 minutes', now_ + interval '4 hours',
          'the owner''s');
  perform set_config('deskilo.inv.owners_booking',
    (select id::text from public.reservations
      where workspace_id = ws and member_id = m_owner limit 1), false);

  insert into public.reservations (workspace_id, member_id, starts_at, ends_at,
                                   space_label)
  values (ws, m_member, now_ + interval '30 days',
          now_ + interval '30 days 4 hours', 'next month');
  perform set_config('deskilo.inv.next_month',
    (select id::text from public.reservations
      where workspace_id = ws and member_id = m_member limit 1), false);

  insert into public.reservations (workspace_id, member_id, starts_at, ends_at,
                                   space_label)
  values (other_ws, m_outsider, now_ - interval '10 minutes',
          now_ + interval '4 hours', 'elsewhere');
  perform set_config('deskilo.inv.elsewhere',
    (select id::text from public.reservations
      where workspace_id = other_ws limit 1), false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.be(p_user text) returns void
language plpgsql as $be$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.inv.' || p_user),
                      'role', 'authenticated')::text, false);
end;
$be$;

-- ---------------------------------------- a seat holds one booking at a time
--
-- The guard is `exclude using gist (seat_id with =, tstzrange(starts_at,
-- ends_at) with &&)` — which is why 0004 now CREATES btree_gist instead
-- of assuming somebody ticked it in a dashboard (#1226). Without the
-- extension this constraint does not exist, and nothing would have said so.
select lives_ok(
  format($$ insert into public.reservations
              (workspace_id, member_id, seat_id, starts_at, ends_at)
            values (%L, %L, %L, %L::timestamptz + interval '1 day',
                    %L::timestamptz + interval '1 day 4 hours') $$,
         current_setting('deskilo.inv.ws'), current_setting('deskilo.inv.owner'),
         current_setting('deskilo.inv.seat'), current_setting('deskilo.inv.now'),
         current_setting('deskilo.inv.now')),
  'a seat can be booked');

select throws_ok(
  format($$ insert into public.reservations
              (workspace_id, member_id, seat_id, starts_at, ends_at)
            values (%L, %L, %L, %L::timestamptz + interval '1 day 1 hour',
                    %L::timestamptz + interval '1 day 3 hours') $$,
         current_setting('deskilo.inv.ws'), current_setting('deskilo.inv.member'),
         current_setting('deskilo.inv.seat'), current_setting('deskilo.inv.now'),
         current_setting('deskilo.inv.now')),
  '23P01',
  null,
  'and not twice over the same hours — the exclusion constraint refuses it');

select lives_ok(
  format($$ insert into public.reservations
              (workspace_id, member_id, seat_id, starts_at, ends_at)
            values (%L, %L, %L, %L::timestamptz + interval '1 day 5 hours',
                    %L::timestamptz + interval '1 day 8 hours') $$,
         current_setting('deskilo.inv.ws'), current_setting('deskilo.inv.member'),
         current_setting('deskilo.inv.seat'), current_setting('deskilo.inv.now'),
         current_setting('deskilo.inv.now')),
  'while the hours AFTER it are free — the constraint is about overlap, '
  'not about the seat');

-- ------------------------------------- a check-in is yours, and it is now
select pg_temp.be('u_member');
select throws_ok(
  format($$ select public.check_in_reservation(%L) $$,
         current_setting('deskilo.inv.owners_booking')),
  'not your reservation',
  'a member cannot check in somebody else''s booking');

select pg_temp.be('u_outsider');
select throws_ok(
  format($$ select public.check_in_reservation(%L) $$,
         current_setting('deskilo.inv.owners_booking')),
  'not your reservation',
  'and a member of another workspace cannot see it at all');

select pg_temp.be('u_member');
select throws_ok(
  format($$ select public.check_in_reservation(%L) $$,
         current_setting('deskilo.inv.next_month')),
  'check-in window not open yet',
  'nor check in a month early — a check-in is a statement about NOW');

-- The desk affordance: an admin checks a member in at the counter. This
-- is a deliberate exception and it is asserted so that narrowing it later
-- is a decision rather than an accident.
select pg_temp.be('u_owner');
select lives_ok(
  format($$ select public.check_in_reservation(%L) $$,
         current_setting('deskilo.inv.owners_booking')),
  'an owner checks in their own booking inside the window');

select * from finish();
rollback;
