-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1908 / 0321: every reservation transition reads its row under the row
-- lock, so a second concurrent command judges the state the first left.
-- The race itself needs two connections (scripts/concurrency_check.sh,
-- "cancel vs check-in"); this file pins the lock in each body and the
-- sequential consequence: a cancelled reservation cannot be checked in or
-- cancelled again.
begin;
select plan(6);

select ok(pg_get_functiondef('public.cancel_reservation(uuid)'::regprocedure) like '%p_reservation_id for update;%',
  'cancel_reservation reads its row under the lock');
select ok(pg_get_functiondef('public.check_in_reservation(uuid)'::regprocedure) like '%p_reservation_id for update;%',
  'check_in_reservation reads its row under the lock');
select ok(pg_get_functiondef('public.check_out_reservation(uuid)'::regprocedure) like '%p_reservation_id for update;%',
  'check_out_reservation reads its row under the lock');
select ok(pg_get_functiondef('public.complete_check_out(uuid)'::regprocedure) like '%p_reservation_id for update;%',
  'complete_check_out reads its row under the lock');

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001908a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-1908@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000001908a1');
select set_config('t.ws', public.create_workspace('Transitions', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000001908b1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000001908b2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908b1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000001908b3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908b2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y)
  values ('00000000-0000-4000-8000-0000001908b4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908b3', 1, 1);
insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at)
  select '00000000-0000-4000-8000-0000001908c1', current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000001908b4',
         date_trunc('day', now()) + interval '1 day 9 hours', date_trunc('day', now()) + interval '1 day 13 hours'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid limit 1;

select pg_temp.act_as('00000000-0000-4000-8000-0000001908a1');
select lives_ok($$select public.cancel_reservation('00000000-0000-4000-8000-0000001908c1')$$, 'the owner cancels');
select throws_ok($$select public.check_in_reservation('00000000-0000-4000-8000-0000001908c1')$$,
  'P0001', null, 'a cancelled reservation is never checked in');

select * from finish();
rollback;
