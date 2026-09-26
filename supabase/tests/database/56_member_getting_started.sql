-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1654: the native join/booking journey against real membership, RLS and
-- the same replayable booking RPC the app calls. Fixtures roll back;
-- authenticated role is active for every member/stranger assertion.
begin;
select plan(13);

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
values
 ('00000000-0000-4000-8000-000000001654', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'guidance-owner@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-000000001655', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'guidance-member@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-000000001656', '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'guidance-stranger@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-000000001654');
select set_config('deskilo.gs.ws', public.create_workspace(
  'Guidance journey', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('deskilo.gs.ws')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));
select set_config('deskilo.gs.code',
  (select invite_code from public.workspaces where id = current_setting('deskilo.gs.ws')::uuid), true);
select set_config('deskilo.gs.seat',
  (select id::text from public.seats where workspace_id = current_setting('deskilo.gs.ws')::uuid
   order by id limit 1), true);
select set_config('deskilo.gs.day', ((now() at time zone 'Europe/Paris')::date + 7)::text, true);

reset role;
-- Deterministic fixture hours, including weekends; no special booking rights.
update public.workspaces set booking_rules = booking_rules ||
  '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id = current_setting('deskilo.gs.ws')::uuid;

create function pg_temp.book(p_day_offset integer) returns uuid language sql as $$
  select public.create_reservation_once(gen_random_uuid(),
    current_setting('deskilo.gs.ws')::uuid, current_setting('deskilo.gs.seat')::uuid,
    null, null, null,
    (current_setting('deskilo.gs.day')::date + p_day_offset + time '08:00') at time zone 'Europe/Paris',
    (current_setting('deskilo.gs.day')::date + p_day_offset + time '12:00') at time zone 'Europe/Paris',
    false);
$$;

select pg_temp.act_as('00000000-0000-4000-8000-000000001655');
select is(public.join_workspace(current_setting('deskilo.gs.code')),
  current_setting('deskilo.gs.ws')::uuid, 'join returns the actual workspace context');
select is((select status::text from public.members
  where workspace_id = current_setting('deskilo.gs.ws')::uuid and user_id = auth.uid()),
  'pending', 'a successful join is still pending admission');
select throws_ok($$ select pg_temp.book(0) $$, 'not an active member',
  'optional guidance cannot grant a pending member permission to book');

reset role;
select is((select count(*)::int from public.reservations
  where workspace_id = current_setting('deskilo.gs.ws')::uuid), 0,
  'the refused booking created no reservation');
-- Reuse the existing owner admission command; the member never self-promotes.
select pg_temp.act_as('00000000-0000-4000-8000-000000001654');
select is((public.request_member_status_change(
  (select id from public.members where workspace_id = current_setting('deskilo.gs.ws')::uuid
    and user_id = '00000000-0000-4000-8000-000000001655'), 'active')->>'pending'),
  'false', 'the authorized owner admits the member through the existing command');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000001655');
select is((select status::text from public.members
  where workspace_id = current_setting('deskilo.gs.ws')::uuid and user_id = auth.uid()),
  'active', 'the admitted member can read their actual membership');
select set_config('deskilo.gs.booking', pg_temp.book(0)::text, true);
select ok(current_setting('deskilo.gs.booking')::uuid is not null,
  'the existing booking RPC returns an actual reservation ID');
select is((select status::text from public.reservations
  where id = current_setting('deskilo.gs.booking')::uuid), 'reserved',
  'the member can read the authoritative returned booking state');
select is((select member_id from public.reservations
  where id = current_setting('deskilo.gs.booking')::uuid),
  (select id from public.members where workspace_id = current_setting('deskilo.gs.ws')::uuid
   and user_id = auth.uid()), 'the result belongs to the member who confirmed it');

reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000001654');
select public.set_feature_flags(current_setting('deskilo.gs.ws')::uuid,
  '{"memberGettingStarted":false}'::jsonb);
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000001655');
select lives_ok($$ select pg_temp.book(1) $$,
  'turning optional guidance off leaves ordinary booking usable');

reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000001656');
select is((select count(*)::int from public.reservations
  where workspace_id = current_setting('deskilo.gs.ws')::uuid), 0,
  'a stranger cannot read either reservation');
select throws_ok($$ select pg_temp.book(2) $$, 'not an active member',
  'a stranger cannot book by knowing the workspace and seat IDs');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000001655');
select is((select count(*)::int from public.reservations
  where workspace_id = current_setting('deskilo.gs.ws')::uuid), 2,
  'the same two real reservations remain visible to the authorized member');

select * from finish();
rollback;
