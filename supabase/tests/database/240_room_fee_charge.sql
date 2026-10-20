-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2575 / 0513: what a member pays for a rented room is charged when the
-- booking lands and the accepted price is frozen. Real roles for the reads;
-- the bookings are inserted as the table owner, the way 232 does. Hand-worked
-- expectations (fees: general half day 15.00, Carol's own half day 10.00, an
-- hour 4.00; the default rules have no granularity, so half days are slots):
--   Ada 2027-04-12 08:00-12:00     one slot            = 1 x 1500 = 1500
--   Bruno 2027-04-13 09:00-10:30   hours 2 x 400 = 800 < slot 1 x 1500
--   Ada 2027-04-14 08:00-18:00     slots 2 x 1500 = 3000 < hours 10 x 400
-- Ada's April ledger ends with charges 1500 + 4000 + 3000 + 2000 + 2000 and
-- the reversals 1500 (moved) + 2000 (released), so her credits are
-- 3500 - 12500 = -9000.
begin;
select plan(44);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.as_int(p_user uuid, p_sql text) returns int
language plpgsql as $$
declare v int;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return -1;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002575' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.paris(p text) returns timestamptz language sql as $$ select (p::timestamp) at time zone 'Europe/Paris'; $$;
create function pg_temp.mem(n int) returns uuid language sql as $$
  select id from public.members where user_id = pg_temp.u(n) and workspace_id = current_setting('t.a')::uuid $$;
-- A booking as the table owner; returns the reservation id.
create function pg_temp.book(p_member uuid, p_office uuid, p_from text, p_to text) returns uuid
language plpgsql as $$
declare v uuid;
begin
  insert into public.reservations (workspace_id, member_id, office_id, starts_at, ends_at)
  values (current_setting('t.a')::uuid, p_member, p_office, pg_temp.paris(p_from), pg_temp.paris(p_to))
  returning id into v;
  return v;
end;
$$;
create function pg_temp.open_amount(p_reservation uuid) returns int language sql as $$
  select amount_cents from public.reservation_charges where reservation_id = p_reservation and reversed_at is null $$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@roomfee.test', '', now(), now(), now()
  from generate_series(1, 4) i;
-- 1 owner, 2 Ada, 3 Bruno, 4 Carol.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Fee A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"levelBooking": true, "externalRooms": true}',
       vat_regime = 'exempt'
 where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, false, 'active', 1, '2026-01-01', 'consumer'),
 (current_setting('t.a')::uuid, pg_temp.u(4), false, false, 'active', 1, '2026-01-01', 'consumer');
insert into public.suppliers (id, workspace_id, supplier_number, name) values
 ('00000000-0000-4000-8000-0000257500a1', current_setting('t.a')::uuid, '1', 'Landlord SA');
insert into public.levels (id, workspace_id, name) values
 ('00000000-0000-4000-8000-0000257500b1', current_setting('t.a')::uuid, 'Own floor'),
 ('00000000-0000-4000-8000-0000257500b2', current_setting('t.a')::uuid, 'Rented floor');
insert into public.offices (id, workspace_id, level_id, name, bookable_as_whole, x, y, w, h) values
 ('00000000-0000-4000-8000-0000257500c1', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000257500b1', 'Own room', true, 0, 0, 10, 10),
 ('00000000-0000-4000-8000-0000257500c2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000257500b2', 'Rented room', true, 0, 0, 10, 10);

select pg_temp.as_json(pg_temp.u(1), format('select public.set_level_kind_v1(%L, %L, ''external'')', current_setting('t.a'), '00000000-0000-4000-8000-0000257500b2'));
select pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_room_rental_v1(%L, %L, %L, ''2027-03-01'', ''2027-08-31'', ''fixed_per_period'', 40000, ''month'', ''active'', null, 0, true)',
  current_setting('t.a'), '00000000-0000-4000-8000-0000257500c2', '00000000-0000-4000-8000-0000257500a1'));
select set_config('t.r', (select id::text from public.room_rentals limit 1), true);
select is(pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_fees_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'),
  jsonb_build_array(jsonb_build_object('unit', 'half_day', 'fee_cents', 1500),
                    jsonb_build_object('unit', 'hour', 'fee_cents', 400),
                    jsonb_build_object('unit', 'half_day', 'fee_cents', 1000, 'member_id', pg_temp.mem(4)))::text))->>'error',
  null, '1 the owner sets a half-day fee, an hourly fee and Carol''s own half-day fee on the active rental open to all');
select is((select jsonb_agg(jsonb_build_object('unit', f.unit, 'fee_cents', f.fee_cents) order by f.unit) from public.room_fees_for(current_setting('t.r')::uuid, pg_temp.mem(2)) f),
  pg_temp.as_json(pg_temp.u(2), format('select public.room_offer_v1(%L, %L)', current_setting('t.a'), '00000000-0000-4000-8000-0000257500c2'))->'fees',
  '2 the fees a booking is charged are the fees the member is offered');

-- one slot: 1 half day
select set_config('t.r1', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-12 08:00', '2027-04-12 12:00')::text, true);
select is(pg_temp.open_amount(current_setting('t.r1')::uuid), 1500, '3 Ada pays one half day: 15.00');
select is((select row(unit, units, unit_fee_cents, period, description, vat_percent)::text from public.reservation_charges where reservation_id = current_setting('t.r1')::uuid),
  '(half_day,1,1500,2027-04,"Rented room · 2027-04-12",0)', '4 the quote names the unit, the units, the unit fee, the period and the day');
select is((select row(le.kind, le.category, le.amount_cents, le.member_id = pg_temp.mem(2), le.period, le.occurred_on)::text
             from public.reservation_charges c join public.ledger_entries le on le.id = c.ledger_charge_id
            where c.reservation_id = current_setting('t.r1')::uuid),
  '(charge,service,1500,t,2027-04,2027-04-12)', '5 it is one service charge on Ada''s ledger, dated the day of the booking');
-- Carol has her own fee
select is(pg_temp.open_amount(pg_temp.book(pg_temp.mem(4), '00000000-0000-4000-8000-0000257500c2', '2027-04-16 08:00', '2027-04-16 12:00')), 1000,
  '6 Carol pays her own half-day fee: 10.00');
-- the cheapest unit wins: 1.5 h is 2 hours = 800, one slot is 1500
select set_config('t.r3', pg_temp.book(pg_temp.mem(3), '00000000-0000-4000-8000-0000257500c2', '2027-04-13 09:00', '2027-04-13 10:30')::text, true);
select is((select row(unit, units, amount_cents)::text from public.reservation_charges where reservation_id = current_setting('t.r3')::uuid),
  '(hour,2,800)', '7 Bruno''s 90 minutes are two hours at 4.00: the cheaper unit');
-- two slots (2 x 1500) beat ten hours (10 x 400)
select set_config('t.r4', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-14 08:00', '2027-04-14 18:00')::text, true);
select is((select row(unit, units, amount_cents)::text from public.reservation_charges where reservation_id = current_setting('t.r4')::uuid),
  '(half_day,2,3000)', '8 a working day is two half days: 30.00');
-- a day in an own room is not charged
select set_config('t.c1', pg_temp.book(pg_temp.mem(3), '00000000-0000-4000-8000-0000257500c1', '2027-04-19 09:00', '2027-04-19 13:00')::text, true);
select is((select count(*)::int from public.reservation_charges where reservation_id = current_setting('t.c1')::uuid), 0,
  '9 a booking in an own room is not charged');
select is((select count(*)::int from public.ledger_entries where member_id = pg_temp.mem(3)), 1, '9b readback: Bruno''s ledger holds only the room charge');

-- the price is frozen
select is(pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_fees_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'),
  jsonb_build_array(jsonb_build_object('unit', 'half_day', 'fee_cents', 2000),
                    jsonb_build_object('unit', 'hour', 'fee_cents', 600),
                    jsonb_build_object('unit', 'half_day', 'fee_cents', 1000, 'member_id', pg_temp.mem(4)))::text))->>'error',
  null, '10 the owner raises the general half-day fee to 20.00 and the hourly fee to 6.00');
update public.reservations set status = 'checked_in' where id = current_setting('t.r1')::uuid;
select is(pg_temp.open_amount(current_setting('t.r1')::uuid), 1500, '11 a booking already made keeps its 15.00 (and checking in changes nothing)');
select is((select count(*)::int from public.ledger_entries where member_id = pg_temp.mem(2)), 2, '11b readback: no entry was added or reversed for it (Ada has two bookings)');
select set_config('t.r5', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-15 08:00', '2027-04-15 12:00')::text, true);
select is(pg_temp.open_amount(current_setting('t.r5')::uuid), 2000, '12 a new booking is charged the new fee');

-- a booking whose billable shape changes is re-quoted
update public.reservations
   set ends_at = pg_temp.paris('2027-04-12 18:00') where id = current_setting('t.r1')::uuid;
select is(pg_temp.open_amount(current_setting('t.r1')::uuid), 4000, '13 moved to a whole day it is two half days at the current 20.00');
select is((select count(*)::int from public.reservation_charges where reservation_id = current_setting('t.r1')::uuid and reversed_at is not null), 1,
  '13b the first quote is kept, reversed');
select is((select row(le.kind, le.category, le.amount_cents, le.description, le.period)::text
             from public.reservation_charges c join public.ledger_entries le on le.id = c.ledger_reversal_id
            where c.reservation_id = current_setting('t.r1')::uuid and c.reversed_at is not null),
  '(credit,adjustment,1500,"Cancelled: Rented room · 2027-04-12",2027-04)', '13c the reversal is a credit adjustment of the same amount and period');
-- the same shape keeps the price even when the booking is touched again
update public.reservations set ends_at = pg_temp.paris('2027-04-12 17:00') where id = current_setting('t.r1')::uuid;
select is(pg_temp.open_amount(current_setting('t.r1')::uuid), 4000, '14 still two half days: the quote stays');

-- cancelling reverses
update public.reservations set status = 'cancelled' where id = (select reservation_id from public.reservation_charges where member_id = pg_temp.mem(4) and reversed_at is null);
select is((select count(*)::int from public.reservation_charges where member_id = pg_temp.mem(4) and reversed_at is null), 0, '15 a cancelled booking has no open charge');
select is((select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)::int from public.ledger_entries where member_id = pg_temp.mem(4)), 0,
  '15b readback: Carol''s ledger nets to zero');
-- 'released' reverses too, and a booking made again counts again
update public.reservations set status = 'released' where id = current_setting('t.r5')::uuid;
select is(pg_temp.open_amount(current_setting('t.r5')::uuid), null, '16 a released booking has no open charge');
update public.reservations set status = 'reserved' where id = current_setting('t.r5')::uuid;
select is(pg_temp.open_amount(current_setting('t.r5')::uuid), 2000, '17 reserved again, it is charged again at the current fee');
-- deleting reverses before the row goes
delete from public.reservations where id = current_setting('t.r3')::uuid;
select is((select row(reservation_id is null, reversed_at is not null, ledger_reversal_id is not null)::text from public.reservation_charges where member_id = pg_temp.mem(3)),
  '(t,t,t)', '18 a deleted booking keeps a reversed quote');
select is((select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)::int from public.ledger_entries where member_id = pg_temp.mem(3)), 0,
  '18b readback: Bruno''s ledger nets to zero');

-- what Ada owes in April, through the statement and the invoice lines
-- charges 1500 + 4000 + 3000 + 2000 + 2000 = 12500, reversals 1500 + 2000
select pg_temp.act_as(pg_temp.u(1));
select is((public.member_statement(pg_temp.mem(2), '2027-04')->>'credits_cents')::int, -9000,
  '19 the statement counts the charges against her credits: 125.00 charged, 35.00 reversed');
reset role;
select is((select sum((l->>'amount_cents')::int)::int from jsonb_array_elements(public.invoice_lines_for(pg_temp.mem(2), '2027-04')) l where l->>'kind' = 'service'), 12500,
  '20 the invoice carries the five service lines');
select is((select sum((l->>'amount_cents')::int)::int from jsonb_array_elements(public.invoice_lines_for(pg_temp.mem(2), '2027-04')) l where l->>'kind' = 'adjustment'), -3500,
  '21 and the two reversals as negative lines');

-- who reads a charge
select is(pg_temp.as_int(pg_temp.u(2), 'select count(*) from public.reservation_charges where reversed_at is null'), 3,
  '22 Ada reads her three open charges');
select is(pg_temp.as_int(pg_temp.u(3), 'select count(*) from public.reservation_charges'), 1,
  '23 Bruno reads his own (reversed) quote and nobody''s else');
select is(pg_temp.as_int(pg_temp.u(1), 'select count(*) from public.reservation_charges'), 7,
  '24 the owner, who reads finances, reads all seven rows');
select is(pg_temp.as_json(pg_temp.u(2), 'insert into public.reservation_charges (workspace_id, member_id, rental_revision, unit, units, unit_fee_cents, amount_cents, vat_percent, period, description, ledger_charge_id) select workspace_id, member_id, 1, ''hour'', 1, 100, 100, 0, period, ''x'', ledger_charge_id from public.reservation_charges limit 1')->>'error' is not null,
  true, '25 nobody writes a quote directly');

-- the workspace's granularity: hours per day, capped at two
update public.workspaces set booking_rules = coalesce(booking_rules, '{}'::jsonb) || '{"granularity": "hours", "half_day_hours": 4}'
 where id = current_setting('t.a')::uuid;
select pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_fees_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'),
  jsonb_build_array(jsonb_build_object('unit', 'half_day', 'fee_cents', 2000))::text));
select set_config('t.b1', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-21 09:00', '2027-04-21 13:00')::text, true);
select is((select row(unit, units, amount_cents)::text from public.reservation_charges where reservation_id = current_setting('t.b1')::uuid),
  '(half_day,1,2000)', '26 hours mode: four hours are one half day (a slot count would say two)');
select set_config('t.b2', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-22 09:00', '2027-04-22 14:00')::text, true);
select is((select row(unit, units, amount_cents)::text from public.reservation_charges where reservation_id = current_setting('t.b2')::uuid),
  '(half_day,2,4000)', '27 hours mode: five hours are two half days');
select set_config('t.b3', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-23 08:00', '2027-04-23 19:00')::text, true);
select is((select row(unit, units, amount_cents)::text from public.reservation_charges where reservation_id = current_setting('t.b3')::uuid),
  '(half_day,2,4000)', '28 hours mode: a long day is capped at two half days');
-- a booking over two days
select set_config('t.b4', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-04-26 15:00', '2027-04-27 11:00')::text, true);
select is((select row(unit, units, amount_cents)::text from public.reservation_charges where reservation_id = current_setting('t.b4')::uuid),
  '(half_day,4,8000)', '29 over midnight: two half days a local day (nine hours, then eleven), counted per day');

-- VAT of a registered workspace
update public.workspaces set vat_regime = 'vat_registered', booking_rules = booking_rules - 'granularity' where id = current_setting('t.a')::uuid;
select set_config('t.r9', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-05-03 08:00', '2027-05-03 12:00')::text, true);
select is((select vat_percent from public.reservation_charges where reservation_id = current_setting('t.r9')::uuid),
  coalesce(public.workspace_default_vat_percent(current_setting('t.a')::uuid, '2027-05-03'::date), 0),
  '30 a VAT-registered space charges its default rate on the day of the booking');
update public.reservations set status = 'cancelled' where id = current_setting('t.r9')::uuid;
select is((select le.vat_percent from public.reservation_charges c join public.ledger_entries le on le.id = c.ledger_reversal_id where c.reservation_id = current_setting('t.r9')::uuid),
  (select vat_percent from public.reservation_charges where reservation_id = current_setting('t.r9')::uuid),
  '31 the reversal carries the same rate');

-- a rental that ends does not unwind what was charged
update public.room_rentals set status = 'ended' where id = current_setting('t.r')::uuid;
select is(pg_temp.open_amount(current_setting('t.r4')::uuid), 3000, '32 an ended rental keeps the charges already made');
update public.reservations set status = 'completed' where id = current_setting('t.r4')::uuid;
select is(pg_temp.open_amount(current_setting('t.r4')::uuid), 3000, '33 and a completed booking keeps its quote');

-- no free quote and no zero charge
update public.room_rentals set status = 'active' where id = current_setting('t.r')::uuid;
select pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_fees_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'), '[]'));
select set_config('t.c2', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000257500c2', '2027-05-05 08:00', '2027-05-05 12:00')::text, true);
select is((select count(*)::int from public.reservation_charges where reservation_id = current_setting('t.c2')::uuid), 0,
  '34 a room with no fee charges nothing');

-- the ledger stays append-only: nothing above rewrote an entry
select is((select count(*)::int from public.ledger_entries where member_id = pg_temp.mem(2) and kind = 'credit' and category = 'adjustment'), 3,
  '35 Ada''s reversals are three credit rows, never an edit (the moved, the released and the cancelled May booking)');
select is((select count(*)::int from public.reservation_charges c where c.reversed_at is null and not exists (select 1 from public.reservations r where r.id = c.reservation_id and r.status in ('reserved', 'checked_in', 'completed'))), 0,
  '36 no open charge belongs to a booking that does not count');
select is((select count(*)::int from public.reservation_charges c where c.reversed_at is null group by c.reservation_id having count(*) > 1), null,
  '37 a booking never has two open charges');
select is((select sum(amount_cents)::int from public.reservation_charges where reversed_at is null and member_id = pg_temp.mem(2) and period = '2027-04'), 4000 + 3000 + 2000 + 2000 + 4000 + 4000 + 8000,
  '38 Ada''s open April quotes add up');
select * from finish();
rollback;
