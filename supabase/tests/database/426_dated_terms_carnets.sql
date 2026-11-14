-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3858 (0766): every state a dated change takes rebalances the member's
-- carnets. A pause scheduled for next month leaves that month with no
-- included half-day, so a booking made after it spends carnets; cancelling
-- the pause gives them back. A carnet is spent by a booking, never by a
-- later change: scheduled again after the bookings, the pause leaves them
-- as use beyond the quota, as a falling share does.
-- Rolled back.
begin;
select plan(5);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- a morning [p_day] days into next month, booked for the member (a booking
-- spends carnets through its own trigger)
create or replace function pg_temp.book(p_day int) returns uuid language sql as $b$
  insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
  values (current_setting('t.ws')::uuid, current_setting('t.me')::uuid,
    (select id from public.seats where workspace_id = current_setting('t.ws')::uuid order by name limit 1),
    ((current_setting('t.next')::date + p_day)::timestamp + time '08:00') at time zone 'Europe/Paris',
    ((current_setting('t.next')::date + p_day)::timestamp + time '12:00') at time zone 'Europe/Paris')
  returning id;
$b$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000004261', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'carnet-owner@deskilo.test', '', now(), now(), now()),
       ('00000000-0000-4000-8000-000000004262', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'carnet-member@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-000000004261');
select set_config('t.ws',
  public.create_workspace('Carnets', 'FR', 'EUR', 'Europe/Paris', 'dev', false,
    '{"invoicing": true, "carnets": true}'::jsonb)::text, true);
select public.apply_workspace_template(current_setting('t.ws')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));

reset role;
update public.workspaces
   set booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080,"advance_horizon_days":120}'
 where id = current_setting('t.ws')::uuid;
insert into public.members (workspace_id, user_id, status, subscription_pct, overage_policy, joined_at)
values (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-000000004262', 'active', 100, 'blocked',
        now() - interval '1 year');
select set_config('t.me',
  (select id from public.members where workspace_id = current_setting('t.ws')::uuid
     and user_id = '00000000-0000-4000-8000-000000004262')::text, true);
select set_config('t.next',
  (date_trunc('month', public.workspace_today(current_setting('t.ws')::uuid)) + interval '1 month')::date::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-000000004261');
insert into public.credit_products (workspace_id, name, half_days, price_cents)
values (current_setting('t.ws')::uuid, 'Carnet 3', 3, 1500);
select public.sell_credit(current_setting('t.ws')::uuid, current_setting('t.me')::uuid,
  (select id from public.credit_products where workspace_id = current_setting('t.ws')::uuid));
-- the pause from next month's first day, scheduled before the bookings
select set_config('t.pause', public.schedule_member_pause(current_setting('t.me')::uuid,
  current_setting('t.next')::date, null, gen_random_uuid()) ->> 'change_id', true);
reset role;

select lives_ok($$ select pg_temp.book(2), pg_temp.book(3) $$,
  'two half-days of the paused month are booked after the pause was scheduled');
select is(public.member_credit_balance(current_setting('t.me')::uuid), 1,
  'a month paused on its first day includes nothing: they spend two carnets');

select pg_temp.act_as('00000000-0000-4000-8000-000000004261');
select is(public.cancel_member_term_change(current_setting('t.pause')::uuid), 1, 'the pause is cancelled');
reset role;
select is(public.member_credit_balance(current_setting('t.me')::uuid), 3,
  'and the month includes its half-days again: both carnets are given back');

select pg_temp.act_as('00000000-0000-4000-8000-000000004261');
select public.schedule_member_pause(current_setting('t.me')::uuid, current_setting('t.next')::date, null, gen_random_uuid());
select is((public.member_statement(current_setting('t.me')::uuid, to_char(current_setting('t.next')::date, 'YYYY-MM'))
            ->> 'extra_half_days')::int || ' / ' || public.member_credit_balance(current_setting('t.me')::uuid), '2 / 3',
  'scheduled again after the bookings, the two half-days count beyond the quota and the carnets stay, as when a share falls');
reset role;

select * from finish();
rollback;
