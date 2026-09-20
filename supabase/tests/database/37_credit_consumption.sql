-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1279 S3 — beyond the month's entitlement a booking spends carnets;
-- cancelling gives them back; nothing is charged twice.
begin;
select plan(7);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

create or replace function pg_temp.book(p_day int) returns uuid language sql as $b$
  select public.create_reservation(
    current_setting('deskilo.cc.ws')::uuid,
    (select id from public.seats where workspace_id = current_setting('deskilo.cc.ws')::uuid order by name limit 1),
    null,
    ((current_setting('deskilo.cc.base')::date + p_day)::timestamp + time '08:00') at time zone 'Europe/Paris',
    ((current_setting('deskilo.cc.base')::date + p_day)::timestamp + time '12:00') at time zone 'Europe/Paris',
    false, null, null);
$b$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000001371', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'carnet-spender@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-000000001371');
select set_config('deskilo.cc.ws',
  public.create_workspace('Spend', 'FR', 'EUR', 'Europe/Paris', 'dev', false,
    '{"invoicing": true, "carnets": true}'::jsonb)::text, true);
select public.apply_workspace_template(current_setting('deskilo.cc.ws')::uuid,
  (select id from public.workspace_templates where key = 'tiny'));

reset role;
update public.workspaces
   set booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080,"advance_horizon_days":120}'
 where id = current_setting('deskilo.cc.ws')::uuid;
select set_config('deskilo.cc.me',
  (select id from public.members where workspace_id = current_setting('deskilo.cc.ws')::uuid
     and user_id = '00000000-0000-4000-8000-000000001371')::text, true);
update public.members set subscription_pct = 0, overage_policy = 'blocked'
 where id = current_setting('deskilo.cc.me')::uuid;
select set_config('deskilo.cc.base', ((now() at time zone 'Europe/Paris')::date)::text, true);

select pg_temp.act_as('00000000-0000-4000-8000-000000001371');
insert into public.credit_products (workspace_id, name, half_days, price_cents)
values (current_setting('deskilo.cc.ws')::uuid, 'Carnet 3', 3, 1500);
select public.sell_credit(current_setting('deskilo.cc.ws')::uuid, current_setting('deskilo.cc.me')::uuid,
  (select id from public.credit_products where workspace_id = current_setting('deskilo.cc.ws')::uuid));

select lives_ok($$ select pg_temp.book(12), pg_temp.book(13), pg_temp.book(45) $$,
  'three half-days across two months, paid by the carnet');
select is(public.member_credit_balance(current_setting('deskilo.cc.me')::uuid), 0,
  'the carnet is spent');
select throws_ok($$ select pg_temp.book(46) $$,
  'half-day quota exceeded — request additional half-days',
  'the fourth is refused, with the message a member without credits gets');

reset role;
select is(
  (select count(*)::int from public.ledger_entries where member_id = current_setting('deskilo.cc.me')::uuid),
  1,
  'spending posted nothing: the only ledger entry is the sale');

select pg_temp.act_as('00000000-0000-4000-8000-000000001371');
select public.cancel_reservation((select id from public.reservations
  where member_id = current_setting('deskilo.cc.me')::uuid and status = 'reserved'
  order by starts_at limit 1));
select is(public.member_credit_balance(current_setting('deskilo.cc.me')::uuid), 1,
  'cancelling a booking gives its half-day back');
select lives_ok($$ select pg_temp.book(47) $$, 'and it can be spent again');

reset role;
update public.members set subscription_pct = 100 where id = current_setting('deskilo.cc.me')::uuid;
select is(
  (select count(*)::int from public.member_credit_uses u
     join public.member_credits c on c.id = u.credit_id
    where c.member_id = current_setting('deskilo.cc.me')::uuid and u.released_at is null),
  0,
  'a subscription that now covers the bookings gives every credit back');

select * from finish();
rollback;
