-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3829 (0749) -- a sold guest pass revoked: its bookings not started yet
-- are cancelled, the one already started stays, the pass is marked revoked
-- with who did it; the same request id answers the same again and changes
-- nothing; another request is refused (DKD01); a member without
-- issueInvoices and a delegated assistant are refused (DKN01); no money
-- moves. Rolled back.
begin;
select plan(9);

create or replace function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003829' || p)::uuid
$$;
create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.rv.ws')::uuid
$$;
-- A statement's answer as a person: its value, or its code.
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare
  v text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.revoke(p_user text, p_req text, p_delegated boolean default false)
returns text language sql as $$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.revoke_guest_pass(%L, %L, %L)::text',
    pg_temp.ws(), current_setting('deskilo.rv.pass'), pg_temp.u(p_req)), p_delegated)
$$;
create or replace function pg_temp.states() returns text language sql as $$
  select string_agg(r.status, ' ' order by r.starts_at)
    from public.reservations r, public.guest_passes p
   where p.id = current_setting('deskilo.rv.pass')::uuid and r.id = any (p.reservation_ids)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@revoke-pass.test', '', now(), now(), now()
  from unnest(array['a1', 'a2']) s;
-- a1 owner, a2 a member without issueInvoices.
with w as (
  insert into public.workspaces(name, country_code, currency_code, timezone, created_by, street, city,
                                postal_code, vat_regime, vat_id, feature_flags, booking_rules)
  values ('Revoked passes', 'FR', 'EUR', 'Europe/Paris', pg_temp.u('a1'), '1 rue du Pass', 'Pézenas', '34120',
          'vat_registered', 'FR12345678901', '{"invoicing":true,"guestPasses":true}',
          '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"flexible","work_start_minutes":0,"work_end_minutes":1440,"min_duration_minutes":1}')
  returning id)
select set_config('deskilo.rv.ws', (select id from w)::text, true);
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
select set_config('deskilo.rv.seat', pg_temp.seat()::text, true);

-- The owner sells a three-day pass from three days ahead, 9:00 to 17:00.
select set_config('deskilo.rv.pass', pg_temp.run_as(pg_temp.u('a1'), format(
  $q$select public.sell_guest_pass(%L, public.save_guest_pass_offer(%L, null, 'Day pass', 'day', 2400, null, true),
       '{"first_name": "Gale", "last_name": "Guest"}'::jsonb, %L,
       ((current_date + 3)::timestamp + interval '9 hours') at time zone 'Europe/Paris',
       ((current_date + 3)::timestamp + interval '17 hours') at time zone 'Europe/Paris',
       %L, false, '', 3) ->> 'pass_id'$q$,
  pg_temp.ws(), pg_temp.ws(), current_setting('deskilo.rv.seat'), pg_temp.u('b1'))), true);
-- Its first day has begun: that booking started an hour ago.
update public.reservations
   set starts_at = now() - interval '1 hour', ends_at = now() + interval '7 hours'
 where id = (select reservation_ids[1] from public.guest_passes where id = current_setting('deskilo.rv.pass')::uuid);
select set_config('deskilo.rv.money', (select count(*) || ' ' || coalesce(sum(amount_cents), 0)
  from public.ledger_entries where workspace_id = pg_temp.ws())::text, true);

select is(pg_temp.states(), 'reserved reserved reserved', 'the pass sold three bookings');

-- Refusals first: nothing changes.
select is(pg_temp.revoke('a2', 'c0') || ' ' || pg_temp.states(), 'ERR DKN01 reserved reserved reserved',
  'a member without issueInvoices cannot revoke a pass');
select is(pg_temp.revoke('a1', 'c0', true) || ' ' || pg_temp.states(), 'ERR DKN01 reserved reserved reserved',
  'a delegated assistant cannot revoke a pass');

-- The owner revokes it.
select set_config('deskilo.rv.r1', pg_temp.revoke('a1', 'c1'), true);
select is(pg_temp.states(), 'reserved cancelled cancelled',
  'the bookings not started are cancelled; the one already started stays');
select ok((select revoked_at is not null and revoked_by = pg_temp.u('a1')
                  and cardinality(revoked_reservation_ids) = 2
             from public.guest_passes where id = current_setting('deskilo.rv.pass')::uuid),
  'the pass is marked revoked, with who revoked it and the bookings it cancelled');
select is((select count(*) from public.events e, public.guest_passes p
            where p.id = current_setting('deskilo.rv.pass')::uuid
              and e.reservation_id = any (p.revoked_reservation_ids)
              and e.type = 'reservation' and e.action = 'cancelled'
              and e.actor_member_id = (select id from public.members where user_id = pg_temp.u('a1')))::int,
  2, 'the feed names who cancelled the bookings');

-- A retry, and another request.
select is((pg_temp.revoke('a1', 'c1')::jsonb - 'replayed')::text,
          (current_setting('deskilo.rv.r1')::jsonb - 'replayed')::text,
  'the same request id answers the same again');
select is(pg_temp.revoke('a1', 'c2') || ' ' || pg_temp.states(), 'ERR DKD01 reserved cancelled cancelled',
  'a pass already revoked by another request is refused, and nothing changes');

-- No money moves.
select is((select count(*) || ' ' || coalesce(sum(amount_cents), 0)
             from public.ledger_entries where workspace_id = pg_temp.ws())::text,
          current_setting('deskilo.rv.money'), 'the revocation moves no money: the invoice is corrected on its page');

select * from finish();
rollback;
