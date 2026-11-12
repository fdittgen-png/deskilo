-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3809 (0738, part of #3657): a room charge's description is frozen as facts
-- (the room and the day as they were) beside its fallback text; a rename
-- later changes nothing; its reversal carries the cancelled facts; the line
-- builder and the issuer's annex carry them into the signed invoice, and a
-- line without facts is exactly what it was. The fixture is 240's. Rolled back.
begin;
select plan(9);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
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
grant execute on all functions in schema pg_temp to authenticated, anon;
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
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003809' || lpad(n::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.paris(p text) returns timestamptz language sql as $$ select (p::timestamp) at time zone 'Europe/Paris'; $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.mem(n int) returns uuid language sql as $$
  select id from public.members where user_id = pg_temp.u(n) and workspace_id = current_setting('t.a')::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
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
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.open_amount(p_reservation uuid) returns int language sql as $$
  select amount_cents from public.reservation_charges where reservation_id = p_reservation and reversed_at is null $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@roomfee.test', '', now(), now(), now()
  from generate_series(1, 4) i;
-- 1 owner, 2 Ada, 3 Bruno, 4 Carol.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Line facts', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
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
 ('00000000-0000-4000-8000-0000380900a1', current_setting('t.a')::uuid, '1', 'Landlord SA');
insert into public.levels (id, workspace_id, name) values
 ('00000000-0000-4000-8000-0000380900b1', current_setting('t.a')::uuid, 'Own floor'),
 ('00000000-0000-4000-8000-0000380900b2', current_setting('t.a')::uuid, 'Rented floor');
insert into public.offices (id, workspace_id, level_id, name, bookable_as_whole, x, y, w, h) values
 ('00000000-0000-4000-8000-0000380900c1', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000380900b1', 'Own room', true, 0, 0, 10, 10),
 ('00000000-0000-4000-8000-0000380900c2', current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000380900b2', 'Rented room', true, 0, 0, 10, 10);

select pg_temp.as_json(pg_temp.u(1), format('select public.set_level_kind_v1(%L, %L, ''external'')', current_setting('t.a'), '00000000-0000-4000-8000-0000380900b2'));
select pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_room_rental_v1(%L, %L, %L, ''2027-03-01'', ''2027-08-31'', ''fixed_per_period'', 40000, ''month'', ''active'', null, 0, true)',
  current_setting('t.a'), '00000000-0000-4000-8000-0000380900c2', '00000000-0000-4000-8000-0000380900a1'));
select set_config('t.r', (select id::text from public.room_rentals limit 1), true);
select pg_temp.as_json(pg_temp.u(1), format('select public.set_room_rental_fees_v1(%L, %L, %L)', current_setting('t.a'), current_setting('t.r'),
  jsonb_build_array(jsonb_build_object('unit', 'half_day', 'fee_cents', 1500))::text));

select set_config('t.b1', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000380900c2', '2027-04-12 08:00', '2027-04-12 12:00')::text, true);
select set_config('t.facts', (select le.text_facts::text from public.reservation_charges c
                                join public.ledger_entries le on le.id = c.ledger_charge_id
                               where c.reservation_id = current_setting('t.b1')::uuid), true);

select is(current_setting('t.facts')::jsonb,
  '{"kind": "room_day", "version": 1, "values": {"room": "Rented room", "day": "2027-04-12"}}'::jsonb,
  'the charge states the room and the day as facts');
select is((select le.description from public.reservation_charges c join public.ledger_entries le on le.id = c.ledger_charge_id
            where c.reservation_id = current_setting('t.b1')::uuid),
  'Rented room · 2027-04-12', 'and keeps its text as the fallback');

update public.offices set name = 'Renamed room' where id = '00000000-0000-4000-8000-0000380900c2';
select is((select le.text_facts from public.reservation_charges c join public.ledger_entries le on le.id = c.ledger_charge_id
            where c.reservation_id = current_setting('t.b1')::uuid),
  current_setting('t.facts')::jsonb, 'a rename later changes nothing: the facts are frozen');

-- A booking grown to a whole day is quoted again: its first charge is reversed.
select set_config('t.b2', pg_temp.book(pg_temp.mem(2), '00000000-0000-4000-8000-0000380900c2', '2027-04-14 08:00', '2027-04-14 12:00')::text, true);
select set_config('t.facts2', (select le.text_facts::text from public.reservation_charges c
                                 join public.ledger_entries le on le.id = c.ledger_charge_id
                                where c.reservation_id = current_setting('t.b2')::uuid), true);
update public.reservations set ends_at = pg_temp.paris('2027-04-14 18:00')
 where id = current_setting('t.b2')::uuid;
select is((select le.text_facts from public.reservation_charges c join public.ledger_entries le on le.id = c.ledger_reversal_id
            where c.reservation_id = current_setting('t.b2')::uuid and c.reversed_at is not null),
  jsonb_build_object('kind', 'cancelled', 'version', 1, 'values', jsonb_build_object('of', current_setting('t.facts2')::jsonb)),
  'its reversal states the cancelled charge''s facts');

select throws_ok($$insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, text_facts)
                   values (current_setting('t.a')::uuid, pg_temp.mem(2), 'charge', 'service', 100, 'x', '2027-04', '{"kind": 1}')$$,
  '23514', null, 'facts without a kind, a version and values are refused');

insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
values (current_setting('t.a')::uuid, pg_temp.mem(2), 'charge', 'service', 700, 'Coffee beans', '2027-04', '2027-04-20');

create temporary table t_lines on commit drop as
  select x from jsonb_array_elements(public.invoice_lines_for(pg_temp.mem(2), '2027-04')) x;
select is((select x -> 'text' from t_lines where x ->> 'label' = 'Rented room · 2027-04-12'),
  current_setting('t.facts')::jsonb, 'the line carries the facts beside its fallback label');
select ok((select not (x ? 'text') from t_lines where x ->> 'label' = 'Coffee beans'),
  'a line without facts is exactly what it was: no text key');

-- What an invoice needs to be issued: the seller's and the buyer's address.
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"invoicing": true, "numberSequences": true}',
       street = '1 rue du Pilote', city = 'Pézenas', postal_code = '34120'
 where id = current_setting('t.a')::uuid;
update public.profiles set first_name = 'Synthetic', last_name = 'Client', country_code = 'FR',
       street = '2 rue du Test', city = 'Pézenas', postal_code = '34120'
 where id = pg_temp.u(2);
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.inv', public.create_invoice(current_setting('t.a')::uuid, pg_temp.mem(2), '2027-04', p_detailed => true)::text, true);
reset role;
select is((select x -> 'text' from public.invoices i, jsonb_array_elements(i.lines) x
            where i.id = current_setting('t.inv')::uuid and x ->> 'label' = 'Rented room · 2027-04-12'),
  current_setting('t.facts')::jsonb, 'the issued, signed line holds the facts');
select is((select e -> 'text' from public.invoices i, jsonb_array_elements(i.details -> 'ledger') e
            where i.id = current_setting('t.inv')::uuid and e ->> 'description' = 'Rented room · 2027-04-12'),
  current_setting('t.facts')::jsonb, 'and so does its annex');

select * from finish();
rollback;
