-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1908 / 0324: a seat and its whole desk, office or level are never
-- both reserved over the same hours; two seats under one desk, and the
-- same spaces at other hours, still are. (The concurrent race is in
-- scripts/concurrency_check.sh; this file proves the rule.)
begin;
select plan(7);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001908f1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-1908b@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000001908f1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace('Hierarchy', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
select set_config('t.m', (select id::text from public.members where workspace_id = current_setting('t.ws')::uuid limit 1), true);
insert into public.levels (id, workspace_id, name) values ('00000000-0000-4000-8000-0000001908e1', current_setting('t.ws')::uuid, 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h)
  values ('00000000-0000-4000-8000-0000001908e2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908e1', 'O', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, x, y, w, h)
  values ('00000000-0000-4000-8000-0000001908e3', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908e2', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, x, y) values
  ('00000000-0000-4000-8000-0000001908e4', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908e3', 1, 1),
  ('00000000-0000-4000-8000-0000001908e5', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000001908e3', 2, 1);

create function pg_temp.book(p_kind text, p_id uuid, p_from int, p_to int) returns void language plpgsql as $$
begin
  execute format('insert into public.reservations (workspace_id, member_id, %I, starts_at, ends_at) values ($1, $2, $3, $4, $5)', p_kind)
    using current_setting('t.ws')::uuid, current_setting('t.m')::uuid, p_id,
          date_trunc('day', now()) + interval '1 day' + make_interval(hours => p_from),
          date_trunc('day', now()) + interval '1 day' + make_interval(hours => p_to);
end;
$$;

select lives_ok($$select pg_temp.book('seat_id', '00000000-0000-4000-8000-0000001908e4', 9, 12)$$, 'a seat is booked 9–12');
select lives_ok($$select pg_temp.book('seat_id', '00000000-0000-4000-8000-0000001908e5', 9, 12)$$, 'the other seat at the same desk too');
select throws_ok($$select pg_temp.book('desk_id', '00000000-0000-4000-8000-0000001908e3', 10, 11)$$, '23P01', null, 'the whole desk overlapping a seat is refused');
select throws_ok($$select pg_temp.book('office_id', '00000000-0000-4000-8000-0000001908e2', 11, 13)$$, '23P01', null, 'the whole office overlapping a seat is refused');
select throws_ok($$select pg_temp.book('level_id', '00000000-0000-4000-8000-0000001908e1', 8, 10)$$, '23P01', null, 'the whole level overlapping a seat is refused');
select lives_ok($$select pg_temp.book('office_id', '00000000-0000-4000-8000-0000001908e2', 13, 17)$$, 'the whole office at other hours is booked');
select throws_ok($$select pg_temp.book('seat_id', '00000000-0000-4000-8000-0000001908e4', 14, 15)$$, '23P01', null, 'a seat inside the booked office is refused');

select * from finish();
rollback;
