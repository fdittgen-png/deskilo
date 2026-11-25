-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4164 A1 (0821): a billing customer with no account. As the real roles: the
-- owner creates and edits one under the new right; a finance reader reads but
-- does not write; a coworker, a stranger and a delegated token read nothing;
-- the customer-only row is outside the member reads, holds no login, booking,
-- badge or role; a billing edit changes only the fields it names (and refuses a
-- stale revision); the member who later joins is the same row. Rolled back.
begin;
select plan(53);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004164' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'billing' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 7) n;
-- 1 owner, 2 finance admin (reads), 3 coworker, 4 stranger, 5 admin holding the right
-- (in a second business), 6 the coworker who will be joined by the customer later, 7 owner of business 2
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, role_permissions)
values (pg_temp.u(101), 'Billing 4164', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"admin": ["viewFinances"], "member": ["makeReservations"]}'),
       (pg_temp.u(102), 'Billing 4164 two', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(7),
        '{"admin": ["manageBillingCustomers"], "member": ["makeReservations"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(205), pg_temp.u(102), pg_temp.u(5), false, true, 'active', '2026-01-01'),
       (pg_temp.u(207), pg_temp.u(102), pg_temp.u(7), true, true, 'active', '2026-01-01');
-- a seat to book, and a place to hold a favourite
insert into public.levels (id, workspace_id, name) values (pg_temp.u(301), pg_temp.u(101), 'Ground');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h) values (pg_temp.u(311), pg_temp.u(101), pg_temp.u(301), 'Room', 0, 0, 10, 10);
insert into public.desks (id, workspace_id, office_id, name, x, y, w, h) values (pg_temp.u(321), pg_temp.u(101), pg_temp.u(311), 'D', 0, 0, 2, 1);
insert into public.seats (id, workspace_id, desk_id, name, x, y) values (pg_temp.u(331), pg_temp.u(101), pg_temp.u(321), 'S', 0, 0);
update public.workspaces set booking_rules = coalesce(booking_rules, '{}'::jsonb)
  || '{"open_weekdays": [1,2,3,4,5,6,7], "work_start_minutes": 0, "work_end_minutes": 1440}'::jsonb where id = pg_temp.u(101);

-- as a user: the text of a scalar, or the refusal's state
create function pg_temp.q(n int, p_sql text, p_claims jsonb default '{}'::jsonb) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::jsonb || p_claims)::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(v, 'null');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.delegated(n int, p_sql text) returns text language sql as $$
  select pg_temp.q(n, p_sql, '{"client_id": "assistant"}'::jsonb);
$$;

-- as the owner of the database: the state a statement is refused with
create function pg_temp.err(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'no error';
exception when others then
  return sqlstate;
end $f$;

-- ── the catalog and the policy ──
select ok('manageBillingCustomers' = any (public.role_permission_catalog()), 'the right is in the permission catalog');
select is(cardinality(public.role_permission_catalog()), 42, 'and the catalog holds forty-two rights');
select ok((select qual from pg_policies where tablename = 'members' and policyname = 'members_select') like '%customer%',
  'members_select leaves a customer-only row to those who read the billing customers');

-- ── creating ──
create temp table made as
  select pg_temp.q(1, format($s$select public.billing_customer_create_v1(%L, %L::jsonb, 'business')::text$s$,
    pg_temp.u(101), '{"company": "Atelier Lumi", "street": "1 rue du Port", "postal_code": "34120", "city": "Pezenas", "country_code": "fr", "vat_id": "FR12345678901", "email": "compta@lumi.test", "ignored": "x"}')) as id;
select ok((select id from made) ~ '^[0-9a-f-]{36}$', 'the owner creates a billing customer');
select is((select status || '|' || coalesce(user_id::text, 'no login') || '|' || customer_capacity
             from public.members where id = (select id::uuid from made)),
  'customer|no login|business', 'it is a customer-only subject with no login and its stated capacity');
select ok((select member_number <> '' from public.members where id = (select id::uuid from made)), 'it has a customer number');
select is((select revision || '|' || company || '|' || country_code || '|' || vat_id from public.billing_parties where member_id = (select id::uuid from made)),
  '1|Atelier Lumi|FR|FR12345678901', 'its billing identity is stored, the country upper-cased, an unnamed field ignored');
select is(pg_temp.q(2, format($s$select public.billing_customer_create_v1(%L, '{"company": "No"}'::jsonb)::text$s$, pg_temp.u(101))),
  'ERR DKN01', 'a finance reader may not create one');
select is(pg_temp.q(1, format($s$select public.billing_customer_create_v1(%L, '{"street": "only"}'::jsonb)::text$s$, pg_temp.u(101))),
  'ERR DKU03', 'a customer needs a name or a company');
select is(pg_temp.delegated(1, format($s$select public.billing_customer_create_v1(%L, '{"company": "Bot"}'::jsonb)::text$s$, pg_temp.u(101))),
  'ERR DKU02', 'a delegated assistant may not create one');
select is(pg_temp.q(5, format($s$select (public.billing_customer_create_v1(%L, '{"company": "Admin made"}'::jsonb) is not null)::text$s$, pg_temp.u(102))),
  'true', 'an admin whose role holds the right creates one in their business');

-- ── reading ──
select is(pg_temp.q(2, format($s$select jsonb_array_length(public.billing_customers_v1(%L))::text$s$, pg_temp.u(101))),
  '1', 'a finance reader lists the billing customers');
select is(pg_temp.q(3, format($s$select jsonb_array_length(public.billing_customers_v1(%L))::text$s$, pg_temp.u(101))),
  'ERR DKN01', 'a coworker may not list them');
select is(pg_temp.q(4, format($s$select jsonb_array_length(public.billing_customers_v1(%L))::text$s$, pg_temp.u(101))),
  'ERR DKN01', 'a stranger may not list them');
select is(pg_temp.q(3, $s$select count(*)::text from public.members where status = 'customer'$s$), '0',
  'a coworker reads no customer-only row from members');
select is(pg_temp.q(3, $s$select count(*)::text from public.billing_parties$s$), '0', 'nor a billing identity');
select is(pg_temp.q(4, $s$select count(*)::text from public.members where status = 'customer'$s$), '0', 'nor does a stranger');
select is(pg_temp.q(2, $s$select count(*)::text from public.members where status = 'customer'$s$), '1',
  'a finance reader reads the customer-only row it bills');
select is(pg_temp.delegated(1, $s$select count(*)::text from public.billing_parties$s$), '0',
  'a delegated token reads no billing identity, whatever its human holds');
select is(pg_temp.q(3, format($s$select count(*)::text from public.members where workspace_id = %L$s$, pg_temp.u(101))), '3',
  'a coworker still reads the members: three, no customer among them');

-- ── the customer holds no login, booking, badge or role ──
select is(pg_temp.err(format($s$update public.members set user_id = %L where id = %L$s$, pg_temp.u(4), (select id from made))) <> 'no error', true,
  'a customer-only row cannot be given a login by an update');
select is(pg_temp.err(format($s$insert into public.members (workspace_id, user_id, status) values (%L, %L, 'customer')$s$, pg_temp.u(101), pg_temp.u(4))),
  '23514', 'nor be created with one: the check refuses it');
select is(pg_temp.err(format($s$insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at, status)
   values (%L, %L, %L, now() + interval '2 days', now() + interval '2 days 1 hour', 'reserved')$s$,
   pg_temp.u(101), (select id from made), pg_temp.u(331))), 'DKU01',
  'negative control: a booking cannot be made for a customer-only subject');
select is(pg_temp.err(format($s$insert into public.resource_favorites (workspace_id, member_id, kind, resource_id)
   values (%L, %L, 'seat', %L)$s$, pg_temp.u(101), (select id from made), pg_temp.u(331))), 'DKU01',
  'nor a favourite, nor any other seat of the community');
select is(pg_temp.q(1, format($s$select public.admin_create_reservation_for(%L, %L, %L, now() + interval '3 days', now() + interval '3 days 1 hour')::text$s$,
    pg_temp.u(101), (select id from made), pg_temp.u(331))) like 'ERR%', true,
  'negative control: not even the owner books for a customer-only subject through the booking command');
select is((select count(*) from public.reservations where member_id = (select id::uuid from made)), 0::bigint,
  'and no booking exists for it');
select is(pg_temp.err(format($s$update public.members set is_admin = true where id = %L$s$, (select id from made))), 'DKU01',
  'a customer-only subject is given no role');
select is(pg_temp.err(format($s$update public.members set max_active_reservations = 5, is_kiosk = true where id = %L$s$, (select id from made))), 'DKU01',
  'nor a booking limit or a door');
select is(pg_temp.err(format($s$update public.members set status = 'customer' where id = %L$s$, pg_temp.u(203))), 'DKU01',
  'and a member is not turned into a customer by an update');
select is((select count(*) from pg_trigger t where t.tgname = 'customer_subject_refused' and not t.tgisinternal), 14::bigint,
  'the fourteen grant tables carry the refusal');

-- ── editing ──
select is(pg_temp.q(1, format($s$select (public.billing_party_save_v1(%L, %L, '{"city": "Beziers"}'::jsonb, 1))->>'revision'$s$, pg_temp.u(101), (select id from made))),
  '2', 'an edit names the fields it changes and bumps the revision');
select is((select city || '|' || company || '|' || street || '|' || vat_id from public.billing_parties where member_id = (select id::uuid from made)),
  'Beziers|Atelier Lumi|1 rue du Port|FR12345678901', 'the other fields were not written');
select is(pg_temp.q(1, format($s$select public.billing_party_save_v1(%L, %L, '{"city": "Old"}'::jsonb, 1)::text$s$, pg_temp.u(101), (select id from made))),
  'ERR DKU05', 'a stale revision is refused');
select is(pg_temp.q(2, format($s$select public.billing_party_save_v1(%L, %L, '{"city": "Nope"}'::jsonb, 2)::text$s$, pg_temp.u(101), (select id from made))),
  'ERR DKN01', 'a finance reader may not edit');
select is(pg_temp.q(1, format($s$select public.billing_party_save_v1(%L, %L, '{"city": "Wrong"}'::jsonb, null)::text$s$, pg_temp.u(101), pg_temp.u(205))),
  'ERR DKU04', 'a subject of another business is refused');

-- an existing member is not a billing customer: the billing edit acts on none, answers
-- as an unknown id does, and writes nothing
create temp table before_member as select md5(to_jsonb(m)::text) h from public.members m where id = pg_temp.u(203);
select is(pg_temp.q(1, format($s$select public.billing_party_save_v1(%L, %L, '{"company": "Coworker Co"}'::jsonb, 0)::text$s$, pg_temp.u(101), pg_temp.u(203))),
  'ERR DKU04', 'the billing edit acts on a customer only: a member answers as an unknown id');
select is(pg_temp.q(1, format($s$select public.billing_party_save_v1(%L, %L, '{"company": "Coworker Co"}'::jsonb, 0)::text$s$, pg_temp.u(101), pg_temp.u(203))),
  pg_temp.q(1, format($s$select public.billing_party_save_v1(%L, %L, '{"company": "Coworker Co"}'::jsonb, 0)::text$s$, pg_temp.u(101), pg_temp.u(999))),
  'exactly as an id that does not exist');
select is((select count(*) from public.billing_parties where member_id = pg_temp.u(203)), 0::bigint, 'nothing was written for the member');
select is((select md5(to_jsonb(m)::text) from public.members m where id = pg_temp.u(203)),
  (select h from before_member), 'and its member row is untouched');

-- no login, by any path: an invitation bound to it, an owner's update
select is(pg_temp.err(format($s$insert into public.invitations (workspace_id, created_by, member_id) values (%L, %L, %L)$s$,
    pg_temp.u(101), pg_temp.u(1), (select id from made))), 'DKU01',
  'an invitation cannot be bound to a customer: it would give the row a login');
select is(pg_temp.err(format($s$update public.members set user_id = %L, status = 'pending' where id = %L$s$, pg_temp.u(4), (select id from made))), 'DKU01',
  'a claim that sets a login and a status in one statement is refused');
select is(pg_temp.err(format($s$update public.members set user_id = %L where id = %L$s$, pg_temp.u(4), (select id from made))), 'DKU01',
  'and so is an owner setting a login');
select is(pg_temp.err(format($s$update public.members set managed_name = 'X' where id = %L$s$, (select id from made))), 'DKU01',
  'a customer has no managed profile to edit');
select is(pg_temp.err(format($s$insert into public.managed_identities (member_id, workspace_id, identity) values (%L, %L, '{}'::jsonb)$s$,
    (select id from made), pg_temp.u(101))), 'DKU01', 'nor a managed identity row');

-- the right alone: a customer yes; an existing member, a capacity, no
select is(pg_temp.q(5, format($s$select (public.billing_party_save_v1(%L, (select member_id from public.billing_parties where workspace_id = %L limit 1), '{"city": "Lyon"}'::jsonb, null))->>'revision'$s$, pg_temp.u(102), pg_temp.u(102))),
  '2', 'the right alone edits a billing customer');
select is(pg_temp.q(5, format($s$select public.billing_party_save_v1(%L, %L, '{"company": "Owner Co"}'::jsonb, null)::text$s$, pg_temp.u(102), pg_temp.u(207))),
  'ERR DKU04', 'but not a member: it answers as an unknown id');
select is(pg_temp.q(5, format($s$select public.billing_customer_create_v1(%L, '{"company": "Cap Co"}'::jsonb, 'business')::text$s$, pg_temp.u(102))),
  'ERR DKN01', 'nor a capacity: that needs the right to issue invoices');
select is(pg_temp.q(5, format($s$select public.billing_party_save_v1(%L, (select member_id from public.billing_parties where workspace_id = %L limit 1), '{"city": "Nice"}'::jsonb, null, 'consumer')::text$s$, pg_temp.u(102), pg_temp.u(102))),
  'ERR DKN01', 'on an edit either');
-- ── the engine's internal functions ──
select is((select public.billing_party_buyer(pg_temp.u(101), (select id::uuid from made)) ->> 'display_name'), 'Atelier Lumi',
  'the buyer is a profile-shaped object named by its company');
select is(public.billing_party_buyer(pg_temp.u(101), pg_temp.u(201)), null, 'a member with no billing identity has none');
select ok(not has_function_privilege('authenticated', 'public.billing_party_buyer(uuid, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.billing_customer_ok(uuid, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.reject_customer_subject()', 'execute'),
  'no client calls the engine''s internal functions');

-- ── joining later is the same row ──
select is(pg_temp.err(format($s$update public.members set status = 'paused' where id = %L$s$, (select id from made))), 'DKU01',
  'a customer does not change status by a side road: a pause, an exit or a status command is refused');
select set_config('deskilo.customer_handover', 'on', true);
update public.members set status = 'active' where id = (select id::uuid from made);
select set_config('deskilo.customer_handover', '', true);
select is((select status || '|' || company from public.members m join public.billing_parties b on b.member_id = m.id where m.id = (select id::uuid from made)),
  'active|Atelier Lumi', 'a customer who later becomes a member is the same row, its billing identity kept');

select * from finish();
rollback;
