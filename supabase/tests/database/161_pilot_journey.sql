-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1974: the pilot's operational journey, chained on the real schema with
-- the authenticated role active for every member and stranger step. An
-- owner opens the space; two people join and wait; the owner admits them;
-- one books the seat now and another the same seat at the same time and is
-- refused; the first checks in and out; a future booking is cancelled and
-- the seat is free again for the other; an ordinary member and a stranger
-- cannot administer, and the stranger reads nothing. The last read comes
-- from a fresh role switch: what persisted, not what a step returned.
begin;
select plan(14);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-0000001974' || s)::uuid, '00000000-0000-0000-0000-000000000000',
       'authenticated', 'authenticated', s || '@pilot-journey.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3', 'a4']) s;
-- a1 owner, a2 and a3 members, a4 a stranger.

select pg_temp.act_as('00000000-0000-4000-8000-0000001974a1');
select set_config('deskilo.j.ws', public.create_workspace(
  'Pilot journey', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('deskilo.j.ws')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));
select set_config('deskilo.j.code',
  (select invite_code from public.workspaces where id = current_setting('deskilo.j.ws')::uuid), true);
select set_config('deskilo.j.seat',
  (select id::text from public.seats where workspace_id = current_setting('deskilo.j.ws')::uuid
   order by id limit 1), true);

reset role;
-- Open every day and hour, any duration: the file passes whenever it runs.
update public.workspaces set booking_rules = booking_rules ||
  '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}'
 where id = current_setting('deskilo.j.ws')::uuid;
-- Now until an hour from now, or the end of the Paris day; and next week.
select set_config('deskilo.j.s', now()::text, true);
select set_config('deskilo.j.e', least(now() + interval '1 hour',
  (date_trunc('day', now() at time zone 'Europe/Paris') + interval '1 day' - interval '1 minute')
    at time zone 'Europe/Paris')::text, true);
select set_config('deskilo.j.fs', ((((now() at time zone 'Europe/Paris')::date + 7) + time '09:00')
  at time zone 'Europe/Paris')::text, true);
select set_config('deskilo.j.fe', ((((now() at time zone 'Europe/Paris')::date + 7) + time '11:00')
  at time zone 'Europe/Paris')::text, true);

create function pg_temp.book(p_from text, p_to text) returns uuid language sql as $$
  select public.create_reservation_once(gen_random_uuid(),
    current_setting('deskilo.j.ws')::uuid, current_setting('deskilo.j.seat')::uuid,
    null, null, null, current_setting(p_from)::timestamptz, current_setting(p_to)::timestamptz, false);
$$;
create function pg_temp.member(p_user text) returns uuid language sql as $$
  select id from public.members where workspace_id = current_setting('deskilo.j.ws')::uuid
     and user_id = ('00000000-0000-4000-8000-0000001974' || p_user)::uuid;
$$;

-- Joining: both wait for the owner.
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a2');
select is(public.join_workspace(current_setting('deskilo.j.code')),
  current_setting('deskilo.j.ws')::uuid, 'the invitation code joins the space');
select is((select status::text from public.members
  where workspace_id = current_setting('deskilo.j.ws')::uuid and user_id = auth.uid()),
  'pending', 'and the person waits for admission');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a3');
select public.join_workspace(current_setting('deskilo.j.code'));
reset role;
select set_config('deskilo.j.ma', pg_temp.member('a2')::text, true);
select set_config('deskilo.j.mb', pg_temp.member('a3')::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a1');
select is((public.request_member_status_change(current_setting('deskilo.j.ma')::uuid, 'active')->>'pending')
       || (public.request_member_status_change(current_setting('deskilo.j.mb')::uuid, 'active')->>'pending'),
  'falsefalse', 'the owner admits both');

-- Booking, read back, and the same seat refused to the second member.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a2');
select set_config('deskilo.j.now', pg_temp.book('deskilo.j.s', 'deskilo.j.e')::text, true);
select is((select status::text from public.reservations where id = current_setting('deskilo.j.now')::uuid),
  'reserved', 'the booking reads back as reserved');
select set_config('deskilo.j.fut', pg_temp.book('deskilo.j.fs', 'deskilo.j.fe')::text, true);
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a3');
select throws_ok($$ select pg_temp.book('deskilo.j.s', 'deskilo.j.e') $$, '23P01', null,
  'the same seat at the same time is refused to the other member');
select throws_ok($$ select public.cancel_reservation(current_setting('deskilo.j.fut')::uuid) $$,
  'not your reservation', 'nor can they cancel someone else''s booking');
select throws_ok($$ select public.request_member_status_change(current_setting('deskilo.j.ma')::uuid, 'paused') $$,
  'not allowed to change memberships', 'an ordinary member does not administer memberships');

-- Presence: in, then out.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a2');
select lives_ok($$ select public.check_in_reservation(current_setting('deskilo.j.now')::uuid) $$,
  'the member checks in within the window');
select lives_ok($$ select public.check_out_reservation(current_setting('deskilo.j.now')::uuid) $$,
  'and checks out');
select lives_ok($$ select public.cancel_reservation(current_setting('deskilo.j.fut')::uuid) $$,
  'the member cancels their future booking');

-- The cancelled slot is free again.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a3');
select lives_ok($$ select pg_temp.book('deskilo.j.fs', 'deskilo.j.fe') $$,
  'and the other member can book the freed seat');

-- A stranger reads nothing and administers nothing.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a4');
select is((select count(*)::int from public.reservations
  where workspace_id = current_setting('deskilo.j.ws')::uuid), 0,
  'a stranger reads none of the space''s bookings');
select throws_ok($$ select public.request_member_status_change(current_setting('deskilo.j.ma')::uuid, 'paused') $$,
  'not a member of this workspace', 'nor changes a membership');

-- What persisted, read afresh by the member.
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000001974a2');
select is((select string_agg(status::text, ',' order by starts_at) from public.reservations
  where workspace_id = current_setting('deskilo.j.ws')::uuid
    and member_id = current_setting('deskilo.j.ma')::uuid),
  'completed,cancelled', 'the member reads the stay as completed and the cancelled booking as cancelled');

select * from finish();
rollback;
