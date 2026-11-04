-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3269 (0661) -- a reservation is made only by someone who holds
-- makeReservations, on every path that books for the caller: a single
-- booking, the idempotent one, a series, and the kiosk's reserve for the
-- badge's member. On a new space the member matrix is empty (0373), so:
--   * the owner reads the missing right as a required readiness section and an
--     open setup step (the migration does not grant it to a space where nobody
--     books yet; that is the state the product already names);
--   * a plain member and an admin (no 'admin' list: the defaults of
--     member_has_permission do not hold it) are refused, 42501, and nothing is
--     written;
--   * the owner books; an admin booking FOR someone (manageReservations) still
--     works for a subject who lacks the right;
--   * the owner grants the member the right and the member books, singly and as
--     a series; the owner takes it back and the member is refused again;
--   * a custom role that carries the right is enough (customRoles on);
--   * at the kiosk the badge's member needs it to reserve, and a member who
--     lost the right can still be checked OUT: removing a right never traps
--     someone checked in.
begin;
select plan(18);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003269' || p)::uuid
$$;
create function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.mr.ws')::uuid
$$;
create function pg_temp.seat() returns uuid language sql as $$
  select current_setting('deskilo.mr.seat')::uuid
$$;
-- A slot on a later day: the n-th hour, one hour long.
create function pg_temp.slot_from(n int) returns timestamptz language sql as $$
  select date_trunc('day', now() + interval '3 days') + make_interval(hours => n)
$$;
create function pg_temp.slot_to(n int) returns timestamptz language sql as $$
  select date_trunc('day', now() + interval '3 days') + make_interval(hours => n + 1)
$$;
create function pg_temp.book(n int) returns uuid language sql as $$
  select public.create_reservation(pg_temp.ws(), pg_temp.seat(), null, pg_temp.slot_from(n), pg_temp.slot_to(n))
$$;
create function pg_temp.book_once(n int) returns uuid language sql as $$
  select public.create_reservation_once(gen_random_uuid(), pg_temp.ws(), pg_temp.seat(), null, null, null,
    pg_temp.slot_from(n), pg_temp.slot_to(n), false)
$$;
create function pg_temp.series(n int) returns jsonb language sql as $$
  select public.create_series(pg_temp.ws(), pg_temp.seat(), pg_temp.slot_from(n), pg_temp.slot_to(n),
    'daily', pg_temp.slot_from(n) + interval '2 days', null, null, null)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@make-reservations.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3', 'a4', 'a5']) s;
-- a1 owner, a2 plain member, a3 admin, a4 kiosk, a5 member with a custom role.

select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.mr.ws', public.create_workspace(
  'Make reservations', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set booking_rules = booking_rules ||
        '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}',
       feature_flags = feature_flags || '{"customRoles":true,"kioskMode":true}'
 where id = pg_temp.ws();
insert into public.members (workspace_id, user_id, status, is_admin, is_kiosk) values
  (pg_temp.ws(), pg_temp.u('a2'), 'active', false, false),
  (pg_temp.ws(), pg_temp.u('a3'), 'active', true, false),
  (pg_temp.ws(), pg_temp.u('a4'), 'active', false, true),
  (pg_temp.ws(), pg_temp.u('a5'), 'active', false, false);
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
select set_config('deskilo.mr.seat', pg_temp.add_resource()::text, true);
-- A badge for the plain member, read at the kiosk.
insert into public.member_badges (workspace_id, member_id, token_hash)
select pg_temp.ws(), id, public.badge_token_hash('MR-A2') from public.members
 where workspace_id = pg_temp.ws() and user_id = pg_temp.u('a2');
-- A custom role that carries the right, held by a5.
with r as (insert into public.workspace_roles (workspace_id, key, permissions)
           values (pg_temp.ws(), 'booker', array['makeReservations']) returning id)
insert into public.workspace_role_members (workspace_id, role_id, member_id)
select pg_temp.ws(), r.id, m.id from r, public.members m
 where m.workspace_id = pg_temp.ws() and m.user_id = pg_temp.u('a5');

-- 1. Empty matrix: the plain member is refused on every path.
select pg_temp.act_as(pg_temp.u('a2'));
select throws_ok($$ select pg_temp.book(9) $$, '42501', 'not allowed to make reservations',
                 'a plain member without the right cannot book');
select throws_ok($$ select pg_temp.book_once(9) $$, '42501', 'not allowed to make reservations',
                 'nor through the idempotent booking');
select throws_ok($$ select pg_temp.series(9) $$, '42501', 'not allowed to make reservations',
                 'nor a series');
reset role;
select is((select count(*)::int from public.reservations where workspace_id = pg_temp.ws()), 0,
          'and nothing was written');

-- The owner is told, on the surfaces that already exist: the setup step and the
-- readiness section name the missing right (a space where nobody has booked yet
-- keeps the empty matrix: the migration only protects people who already book).
reset role;
select pg_temp.act_as(pg_temp.u('a1'));
select is((select s->>'state' || '/' || (s->>'required') || '/' || coalesce(s->>'reason', '')
             from jsonb_array_elements(public.workspace_readiness(pg_temp.ws())) s
            where s->>'section' = 'member_permissions'),
          'needs_configuration/true/members_cannot_book',
          'the owner reads the missing right as a required readiness section');
select is((select s->>'state' from jsonb_array_elements(public.workspace_setup_status(pg_temp.ws())->'steps') s
            where s->>'step' = 'member_rights'),
          'needs_configuration', 'and as an open setup step');

-- 2. An admin: the 'admin' list is absent, its defaults do not hold the right.
select pg_temp.act_as(pg_temp.u('a3'));
select throws_ok($$ select pg_temp.book(10) $$, '42501', 'not allowed to make reservations',
                 'an admin on the defaults cannot book for themselves either');

-- 3. The owner books; an admin booking FOR the member still works.
reset role;
select pg_temp.act_as(pg_temp.u('a1'));
select lives_ok($$ select pg_temp.book(11) $$, 'the owner books');
reset role;
select pg_temp.act_as(pg_temp.u('a1'));
select lives_ok(format($t$ select public.admin_create_reservation_for(%L, %L, %L, %L, %L) $t$,
          pg_temp.ws(),
          (select id from public.members where workspace_id = pg_temp.ws() and user_id = pg_temp.u('a2')),
          pg_temp.seat(), pg_temp.slot_from(12), pg_temp.slot_to(12)),
        'an admin books FOR a member who lacks the right: that authority is the admin''s');

-- 4. The owner grants the right: the member books, singly and as a series.
reset role;
select pg_temp.act_as(pg_temp.u('a1'));
select lives_ok($$ select public.set_role_permission(pg_temp.ws(), 'member', 'makeReservations', true) $$,
                'the owner grants the members the right');
reset role;
select pg_temp.act_as(pg_temp.u('a2'));
select lives_ok($$ select pg_temp.book(13) $$, 'the member now books');
select lives_ok($$ select pg_temp.book_once(14) $$, 'through the idempotent booking too');
select lives_ok($$ select pg_temp.series(15) $$, 'and as a series');

-- 5. Taken back: refused again.
reset role;
select pg_temp.act_as(pg_temp.u('a1'));
select public.set_role_permission(pg_temp.ws(), 'member', 'makeReservations', false);
reset role;
select pg_temp.act_as(pg_temp.u('a2'));
select throws_ok($$ select pg_temp.book(18) $$, '42501', 'not allowed to make reservations',
                 'once the right is taken back the member is refused again');

-- 6. A custom role that carries the right is enough.
reset role;
select pg_temp.act_as(pg_temp.u('a5'));
select lives_ok($$ select pg_temp.book(19) $$, 'a member whose custom role carries the right books');

-- 7. The kiosk: reserve for the badge's member needs the right; check-out does not.
reset role;
select pg_temp.act_as(pg_temp.u('a4'));
select throws_ok(format($t$ select public.kiosk_act(%L, 'MR-A2', 'reserve', %L, %L, %L) $t$,
          pg_temp.ws(), pg_temp.seat(), pg_temp.slot_from(20), pg_temp.slot_to(20)),
        '42501', 'not allowed to make reservations',
        'at the kiosk the badge''s member needs the right to reserve');
reset role;
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at, status)
select pg_temp.ws(), m.id, pg_temp.seat(), now() - interval '1 hour', now() + interval '1 hour', 'checked_in'
  from public.members m where m.workspace_id = pg_temp.ws() and m.user_id = pg_temp.u('a2');
select pg_temp.act_as(pg_temp.u('a4'));
select lives_ok(format($t$ select public.kiosk_act(%L, 'MR-A2', 'check_out') $t$, pg_temp.ws()),
        'a member who lost the right can still be checked out: nobody is trapped');

-- 8. The three checks are in the functions.
reset role;
select ok((select bool_and(prosrc ~ 'member_has_permission\([a-z_.]+, ''makeReservations''\)'
                              and prosrc ~ 'not allowed to make reservations')
             from pg_proc where oid in (
               'public.create_reservation(uuid, uuid, uuid, timestamp with time zone, timestamp with time zone, boolean, uuid, uuid)'::regprocedure,
               'public.create_series(uuid, uuid, timestamp with time zone, timestamp with time zone, text, timestamp with time zone, uuid, uuid, uuid)'::regprocedure,
               'public.kiosk_act(uuid, text, text, uuid, timestamp with time zone, timestamp with time zone, uuid)'::regprocedure)),
          'create_reservation, create_series and kiosk_act each carry the check');

select * from finish();
rollback;
