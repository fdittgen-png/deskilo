-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3308 (0685) -- a guest pass sold at the desk: the pass's own price and
-- units, the guest's customer record (a managed profile of origin 'guest',
-- one per sale), the booking on the seat, the charge and its invoice,
-- the recorded payment, the replay of the same request, and the refusals
-- (flag off, a seller without issueInvoices, an inactive pass, a guest
-- without a name). Who reads the offers and the sales.
begin;
select plan(22);

create or replace function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003308' || p)::uuid
$$;
create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.gp.ws')::uuid
$$;
create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
-- A local day three days ahead, at the given hour of the space (Paris).
create or replace function pg_temp.at(p_day int, p_hour numeric) returns timestamptz language sql as $$
  select ((current_date + 3 + p_day)::timestamp + make_interval(mins => (p_hour * 60)::int))
         at time zone 'Europe/Paris'
$$;
create or replace function pg_temp.sell(p_req text, p_offer text, p_guest jsonb, p_from timestamptz,
                                        p_to timestamptz, p_paid boolean default false, p_days int default 1)
returns jsonb language sql as $$
  select public.sell_guest_pass(pg_temp.ws(), current_setting('deskilo.gp.' || p_offer)::uuid, p_guest,
    current_setting('deskilo.gp.seat')::uuid, p_from, p_to, pg_temp.u(p_req), p_paid, 'card', p_days)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@guest-pass.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3']) s;
-- a1 owner, a2 plain member, a3 a stranger (signed in, no membership).
with w as (
  insert into public.workspaces(name, country_code, currency_code, timezone, created_by, street, city,
                                postal_code, vat_regime, vat_id, feature_flags, booking_rules)
  values ('Guest passes', 'FR', 'EUR', 'Europe/Paris', pg_temp.u('a1'), '1 rue du Pass', 'Pézenas', '34120',
          'vat_registered', 'FR12345678901', '{"invoicing":true,"guestPasses":true}',
          '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}')
  returning id)
select set_config('deskilo.gp.ws', (select id from w)::text, true);
insert into public.members(workspace_id, user_id, is_owner, is_admin, joined_at)
values (pg_temp.ws(), pg_temp.u('a1'), true, true, '2026-01-01');
insert into public.members(workspace_id, user_id, joined_at) values (pg_temp.ws(), pg_temp.u('a2'), '2026-01-01');
insert into public.vat_rates(workspace_id, label, percent, is_default) values (pg_temp.ws(), 'Standard', 20, true);
create or replace function pg_temp.seat() returns uuid language plpgsql as $f$
declare l uuid; o uuid; d uuid; st uuid;
begin
  insert into public.levels (workspace_id, name) values (pg_temp.ws(), 'Ground') returning id into l;
  insert into public.offices (workspace_id, level_id, name, x, y, w, h)
    values (pg_temp.ws(), l, 'Open space', 0, 0, 10, 10) returning id into o;
  insert into public.desks (workspace_id, office_id, x, y, w, h) values (pg_temp.ws(), o, 1, 1, 4, 2) returning id into d;
  insert into public.seats (workspace_id, desk_id, x, y) values (pg_temp.ws(), d, 1, 1) returning id into st;
  return st;
end $f$;
select set_config('deskilo.gp.seat', pg_temp.seat()::text, true);

-- the owner lists two passes
select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.gp.hour', public.save_guest_pass_offer(pg_temp.ws(), null, 'Hourly pass', 'hour', 600, null, true)::text, true);
select set_config('deskilo.gp.day', public.save_guest_pass_offer(pg_temp.ws(), null, 'Day pass', 'day', 2400, null, true)::text, true);
select set_config('deskilo.gp.off', public.save_guest_pass_offer(pg_temp.ws(), null, 'Old pass', 'day', 1000, null, false)::text, true);

-- 1-2. the registry
reset role;
select is(public.feature_registry() -> 'guestPasses' ->> 'parent', 'invoicing', 'the pass sits under invoicing');
select is(public.feature_registry() -> 'guestPasses' ->> 'default', 'false', 'and is off by default');

-- 3-9. an hourly pass, 10:00 to 12:30: three started hours
select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.gp.s1', pg_temp.sell('b1', 'hour',
  '{"first_name":"Gina","last_name":"Guest","email":"Gina@Guest.test"}', pg_temp.at(0, 10), pg_temp.at(0, 12.5))::text, true);
reset role;
select is((current_setting('deskilo.gp.s1')::jsonb ->> 'units')::int, 3, 'three started hours');
select is((current_setting('deskilo.gp.s1')::jsonb ->> 'amount_cents')::int, 1800, 'priced by the server: 3 × 6.00');
select ok((select m.origin = 'guest' and m.user_id is null and m.subscription_pct = 0 and m.status = 'active'
             from public.members m where m.id = (current_setting('deskilo.gp.s1')::jsonb ->> 'member_id')::uuid),
  'the guest is a customer record: origin guest, no account, no subscription');
select ok(exists (select 1 from public.reservations r
                   where r.id = (current_setting('deskilo.gp.s1')::jsonb -> 'reservation_ids' ->> 0)::uuid
                     and r.member_id = (current_setting('deskilo.gp.s1')::jsonb ->> 'member_id')::uuid
                     and r.seat_id = current_setting('deskilo.gp.seat')::uuid
                     and r.starts_at = pg_temp.at(0, 10) and r.ends_at = pg_temp.at(0, 12.5)),
  'the seat is booked for the guest, for the sold window');
select is((select i.total_cents from public.invoices i
            where i.id = (current_setting('deskilo.gp.s1')::jsonb ->> 'invoice_id')::uuid), 1800,
  'the invoice is the pass, and only the pass (no fee band, no overage)');
select ok((select i.member_name ilike '%Gina%' and i.kind = 'full' from public.invoices i
            where i.id = (current_setting('deskilo.gp.s1')::jsonb ->> 'invoice_id')::uuid),
  'issued to the guest by name');
select is((select count(*)::int from public.guest_passes where workspace_id = pg_temp.ws()), 1, 'one pass recorded');

-- the guest's profile write is logged, as for any profile someone creates
select ok(exists (select 1 from public.data_access_log l
                   where l.workspace_id = pg_temp.ws() and l.category = 'profile'
                     and l.subject_member_id = (current_setting('deskilo.gp.s1')::jsonb ->> 'member_id')::uuid
                     and l.actor_member_id = (select id from public.members where workspace_id = pg_temp.ws() and user_id = pg_temp.u('a1'))),
  'the seller is logged as the one who wrote the guest''s personal data');
-- a stranger who knows the request id learns nothing from a replay
select pg_temp.act_as(pg_temp.u('a3'));
select throws_ok($$ select pg_temp.sell('b1', 'hour', '{"first_name":"Gina","last_name":"Guest"}', pg_temp.at(0, 10), pg_temp.at(0, 12.5)) $$,
  '42501', null, 'a replay answers only someone who may sell here');
reset role;

-- 10-11. the same request again: the same sale, nothing twice
select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.gp.s1b', pg_temp.sell('b1', 'hour',
  '{"first_name":"Gina","last_name":"Guest","email":"gina@guest.test"}', pg_temp.at(0, 10), pg_temp.at(0, 12.5))::text, true);
reset role;
select is(current_setting('deskilo.gp.s1b')::jsonb ->> 'pass_id', current_setting('deskilo.gp.s1')::jsonb ->> 'pass_id',
  'a retry returns the same pass');
select is((select count(*)::int from public.invoices where workspace_id = pg_temp.ws()), 1, 'and issues no second invoice');

-- 12-14. a two-day pass for the same guest, paid at the desk
select pg_temp.act_as(pg_temp.u('a1'));
select set_config('deskilo.gp.s2', pg_temp.sell('b2', 'day',
  '{"first_name":"Gina","last_name":"Guest","email":"gina@guest.test"}', pg_temp.at(1, 9), pg_temp.at(1, 18), true, 2)::text, true);
reset role;
select ok((current_setting('deskilo.gp.s2')::jsonb ->> 'units')::int = 2
          and jsonb_array_length(current_setting('deskilo.gp.s2')::jsonb -> 'reservation_ids') = 2
          and (select bool_and(r.ends_at - r.starts_at = interval '9 hours') from public.reservations r
                where r.id in (select (x)::uuid from jsonb_array_elements_text(current_setting('deskilo.gp.s2')::jsonb -> 'reservation_ids') x)),
  'two days: two bookings of the same 09:00-18:00 window');
select ok(current_setting('deskilo.gp.s2')::jsonb ->> 'member_id' <> current_setting('deskilo.gp.s1')::jsonb ->> 'member_id'
          and (select count(*) from public.invoices where workspace_id = pg_temp.ws()) = 2,
  'a second pass of the same guest in the month is its own record and its own invoice');
select ok(exists (select 1 from public.events e
                   where e.id = (current_setting('deskilo.gp.s2')::jsonb ->> 'payment_event_id')::uuid
                     and e.type = 'payment' and e.status = 'pending'
                     and (e.payload ->> 'amount_cents')::int = 4800),
  'the payment taken at the desk is recorded, pending its decision like every payment');

-- 15-18. refusals
select pg_temp.act_as(pg_temp.u('a2'));
select throws_ok($$ select pg_temp.sell('b3', 'hour', '{"first_name":"X","last_name":"Y"}', pg_temp.at(3, 10), pg_temp.at(3, 11)) $$,
  '42501', null, 'a member without issueInvoices cannot sell a pass');
select pg_temp.act_as(pg_temp.u('a1'));
select throws_ok($$ select pg_temp.sell('b4', 'off', '{"first_name":"X","last_name":"Y"}', pg_temp.at(3, 10), pg_temp.at(3, 11)) $$,
  'P0001', 'unknown guest pass', 'an inactive pass is not sold');
select throws_ok($$ select pg_temp.sell('b5', 'hour', '{"email":"no-name@guest.test"}', pg_temp.at(3, 10), pg_temp.at(3, 11)) $$,
  'P0001', 'a guest needs a name', 'a guest without a name is refused');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"guestPasses":false}' where id = pg_temp.ws();
select pg_temp.act_as(pg_temp.u('a1'));
select throws_ok($$ select pg_temp.sell('b6', 'hour', '{"first_name":"X","last_name":"Y"}', pg_temp.at(3, 10), pg_temp.at(3, 11)) $$,
  'P0001', 'guest passes are off in this space', 'with the flag off nothing is sold');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"guestPasses":true}' where id = pg_temp.ws();

-- 19-20. who reads what
select pg_temp.act_as(pg_temp.u('a2'));
select is((select count(*)::int from public.guest_pass_offers where workspace_id = pg_temp.ws()), 3,
  'a member reads the space''s passes (its prices)');
select is((select count(*)::int from public.guest_passes where workspace_id = pg_temp.ws()), 0,
  'but not who bought them');
reset role;

select * from finish();
rollback;
