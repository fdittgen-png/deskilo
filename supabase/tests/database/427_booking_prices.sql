-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3843 (0767): what each booking of a period was or will be charged. A room
-- booking with its open charge gives its amount in the business's currency;
-- a booking paid by a pass or a carnet says so; one that counts toward no
-- quota is free; any other is covered by the subscription when its month
-- has no extra half-days, else it counts toward them, with no amount. Whoever
-- reads the finances reads every booking's; a member reads their own.
-- Rolled back.
begin;
select plan(9);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003843' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'prices' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values (pg_temp.u(101), 'Prices', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"meetingRooms": true}'),
       (pg_temp.u(102), 'Zurich', 'CH', 'CHF', 'Europe/Zurich', pg_temp.u(1), '{"meetingRooms": true}');
-- 201 the owner; 202 a member with an account; 203-208 managed members
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', 100, 'blocked', now() - interval '1 year'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', 100, 'blocked', now() - interval '1 year'),
       (pg_temp.u(301), pg_temp.u(102), pg_temp.u(1), true, true, 'active', 100, 'blocked', now() - interval '1 year');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
select pg_temp.u(200 + n), pg_temp.u(101), 'Member ' || n, 'active', case when n = 3 or n = 4 then 0 else 100 end,
       'blocked', now() - interval '1 year'
  from generate_series(3, 8) n;
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(302), pg_temp.u(102), 'Zurich member', 'active', 100, 'blocked', now() - interval '1 year');

-- places: a seat and rooms
create function pg_temp.place(p_ws int, p_n int, p_kind text) returns uuid language plpgsql as $$
begin
  insert into public.levels (id, workspace_id, name) values (pg_temp.u(p_n), pg_temp.u(p_ws), 'L' || p_n)
  on conflict do nothing;
  insert into public.offices (id, workspace_id, level_id, name, x, y, w, h, area_kind)
  values (pg_temp.u(p_n + 1), pg_temp.u(p_ws), pg_temp.u(p_n), 'O' || p_n, 0, 0, 10, 10,
          case when p_kind = 'parking' then 'parking' else 'workspace' end);
  insert into public.desks (id, workspace_id, office_id, name, x, y, w, h)
  values (pg_temp.u(p_n + 2), pg_temp.u(p_ws), pg_temp.u(p_n + 1), 'D' || p_n, 1, 1, 4, 2);
  insert into public.seats (id, workspace_id, desk_id, name, x, y, resource_kind, capacity, parking_kind)
  values (pg_temp.u(p_n + 3), pg_temp.u(p_ws), pg_temp.u(p_n + 2), 'S' || p_n, 1, 1, p_kind,
          case when p_kind = 'room' then 8 end, case when p_kind = 'parking' then 'standard' end);
  return pg_temp.u(p_n + 3);
end $$;
select set_config('t.seat', pg_temp.place(101, 600, 'seat')::text, true);
select set_config('t.room', pg_temp.place(101, 620, 'room')::text, true);
select set_config('t.zroom', pg_temp.place(102, 630, 'room')::text, true);

-- the first open weekday of next month, at nine (Paris)
select set_config('t.day', (select d from generate_series(
    (date_trunc('month', now() at time zone 'Europe/Paris') + interval '1 month')::date,
    (date_trunc('month', now() at time zone 'Europe/Paris') + interval '1 month')::date + 6, interval '1 day') d
   where extract(isodow from d) between 1 and 5 order by d limit 1)::date::text, true);
create function pg_temp.book(p_id int, p_member int, p_seat text, p_hour int, p_ws int default 101) returns uuid
language sql as $$
  insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at)
  values (pg_temp.u(p_id), pg_temp.u(p_ws), pg_temp.u(p_member), current_setting(p_seat)::uuid,
          (current_setting('t.day')::date + make_interval(hours => p_hour)) at time zone 'Europe/Paris',
          (current_setting('t.day')::date + make_interval(hours => p_hour + 3)) at time zone 'Europe/Paris')
  returning id $$;
-- 202 within the month's quota; 203 with a share of 0 (beyond it)
select pg_temp.book(702, 202, 't.seat', 8);
select pg_temp.book(703, 203, 't.seat', 13);
-- 204 paid by a carnet (a share of 0)
select pg_temp.book(704, 204, 't.seat', 17);
insert into public.member_credits (id, workspace_id, member_id, half_days) values (pg_temp.u(804), pg_temp.u(101), pg_temp.u(204), 3);
insert into public.member_credit_uses (workspace_id, credit_id, reservation_id, half_days)
values (pg_temp.u(101), pg_temp.u(804), pg_temp.u(704), 1)
on conflict do nothing;
-- 205 by a pass
select pg_temp.book(705, 205, 't.room', 8);
insert into public.guest_pass_offers (id, workspace_id, name, unit, price_cents)
values (pg_temp.u(905), pg_temp.u(101), 'Day pass', 'day', 2500);
insert into public.guest_passes (workspace_id, offer_id, member_id, client_request_id, unit, units, unit_price_cents,
                                 amount_cents, starts_at, ends_at, reservation_ids)
values (pg_temp.u(101), pg_temp.u(905), pg_temp.u(205), gen_random_uuid(), 'day', 1, 2500, 2500,
        now(), now() + interval '1 day', array[pg_temp.u(705)]);
-- 206 a room with its charge
select pg_temp.book(706, 206, 't.room', 13);
create function pg_temp.charge(p_ws int, p_member int, p_booking int, p_cents int) returns void language plpgsql as $$
declare v_ledger uuid := gen_random_uuid();
begin
  insert into public.ledger_entries (id, workspace_id, member_id, kind, category, amount_cents, description, period, vat_percent)
  values (v_ledger, pg_temp.u(p_ws), pg_temp.u(p_member), 'charge', 'adjustment', p_cents, 'Room', to_char(now(), 'YYYY-MM'), 0);
  insert into public.reservation_charges (workspace_id, reservation_id, member_id, rental_revision, unit, units,
                                          unit_fee_cents, amount_cents, vat_percent, period, description, ledger_charge_id)
  values (pg_temp.u(p_ws), pg_temp.u(p_booking), pg_temp.u(p_member), 1, 'half_day', 1, p_cents, p_cents, 0,
          to_char(now(), 'YYYY-MM'), 'Room', v_ledger);
end $$;
select pg_temp.charge(101, 206, 706, 5000);
-- 207 a cancelled booking; 208 a room with no charge (a room counts toward no quota)
select pg_temp.book(707, 207, 't.seat', 20);
update public.reservations set status = 'cancelled' where id = pg_temp.u(707);
select pg_temp.book(708, 208, 't.room', 17);
-- in Zurich, a room with its charge
select pg_temp.book(712, 302, 't.zroom', 8, 102);
select pg_temp.charge(102, 302, 712, 4000);
grant execute on all functions in schema pg_temp to authenticated;

create function pg_temp.prices(p_ws int) returns text language sql as $$
  select string_agg(right(p.member_id::text, 3) || ':' || p.kind
                    || coalesce(' ' || p.amount_cents || ' ' || p.currency, ''), ', ' order by p.member_id)
    from public.booking_prices(pg_temp.u(p_ws), now(), now() + interval '3 months') p $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── whoever reads the finances ──
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select is(pg_temp.prices(101),
  '202:subscription, 203:overage, 204:carnet, 205:pass, 206:charge 5000 EUR, 208:free',
  'each booking says what it was charged: covered, beyond the quota, a carnet, a pass, the room''s charge, free');
select is((select count(*)::int from public.booking_prices(pg_temp.u(101), now(), now() + interval '3 months')
            where reservation_id = pg_temp.u(707)), 0, 'a cancelled booking is not listed');
select is(pg_temp.prices(102), '302:charge 4000 CHF', 'a charge is in its business''s currency');
select is((select count(*)::int from public.booking_prices(pg_temp.u(101), now(), now() + interval '3 months')
            where amount_cents is not null and kind <> 'charge'), 0,
  'nothing but a room''s charge carries an amount');
select throws_ok(format($$ select * from public.booking_prices(%L, now(), now()) $$, pg_temp.u(101)),
  '22023', 'a period ends after it starts', 'a period ends after it starts');
reset role;

-- ── a member ──
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select is(pg_temp.prices(101), '202:subscription', 'a member reads only their own bookings');
select throws_ok(format($$ select * from public.booking_prices(%L, now(), now() + interval '1 day') $$, pg_temp.u(102)),
  'DKN01', 'not a member of this workspace', 'and none of a business they are not a member of');
reset role;

-- ── a charge reversed ──
update public.reservation_charges set reversed_at = now(),
       ledger_reversal_id = (select ledger_charge_id from public.reservation_charges where reservation_id = pg_temp.u(706))
 where reservation_id = pg_temp.u(706);
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select is((select kind from public.booking_prices(pg_temp.u(101), now(), now() + interval '3 months')
            where reservation_id = pg_temp.u(706)), 'free',
  'a reversed charge is not one: the room, which counts toward no quota, is free');
reset role;
select pg_temp.act_as(pg_temp.u(3));
set local role authenticated;
select throws_ok(format($$ select * from public.booking_prices(%L, now(), now() + interval '1 day') $$, pg_temp.u(101)),
  'DKN01', 'not a member of this workspace', 'someone who is not a member reads nothing');
reset role;

select * from finish();
rollback;
