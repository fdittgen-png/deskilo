-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1908 / 0326: moving an active reservation onto hours where its whole
-- desk is booked is refused; moving it elsewhere, or a status change that
-- leaves the hours alone (check-in), still works.
begin;
select plan(3);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001908c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-1908c@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001908c2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mate-1908c@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000001908c1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace('Moves', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, status, is_admin)
  values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908c2', 'active', false);
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000001908d1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000001908d2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908d1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000001908d3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908d2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y)
  values ('00000000-0000-4000-8000-0000001908d4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908d3', 1, 1);
-- The whole desk 13–17 (owner); a seat at that desk 9–12 (mate).
insert into public.reservations (workspace_id, member_id, desk_id, starts_at, ends_at)
  select current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000001908d3',
         date_trunc('day', now()) + interval '1 day 13 hours', date_trunc('day', now()) + interval '1 day 17 hours'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid
     and m.user_id = '00000000-0000-4000-8000-0000001908c1';
insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at)
  select '00000000-0000-4000-8000-0000001908d5', current_setting('t.ws')::uuid, m.id, '00000000-0000-4000-8000-0000001908d4',
         date_trunc('day', now()) + interval '1 day 9 hours', date_trunc('day', now()) + interval '1 day 12 hours'
    from public.members m where m.workspace_id = current_setting('t.ws')::uuid
     and m.user_id = '00000000-0000-4000-8000-0000001908c2';

select throws_ok($$update public.reservations set ends_at = date_trunc('day', now()) + interval '1 day 14 hours'
                   where id = '00000000-0000-4000-8000-0000001908d5'$$,
  '23P01', null, 'extending the seat into the whole-desk booking is refused');
select lives_ok($$update public.reservations set starts_at = date_trunc('day', now()) + interval '1 day 8 hours'
                  where id = '00000000-0000-4000-8000-0000001908d5'$$,
  'moving the seat earlier, clear of the desk booking, works');
select lives_ok($$update public.reservations set status = 'cancelled'
                  where id = '00000000-0000-4000-8000-0000001908d5'$$,
  'a status change to inactive is never guarded');

select * from finish();
rollback;
