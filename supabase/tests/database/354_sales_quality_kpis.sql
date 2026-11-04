-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3294 / 0674: the sales figures, each proven from a hand-built March 2025
-- (Paris, EUR). Invoices of March (gross, VAT 20 % unless said):
--   i1 c2: subscription 120.00 (net 100.00), service Coffee 6.00 (5.00),
--          a payment credit -50.00 (not a sale)
--   i2 c3: overage 24.00 (20.00), package Ten half-days 120.00 (100.00),
--          service Coffee 12.00 (10.00)
--   i3 c3: a sales-tax line, service Printing 11.00 = net 10.00 + tax 1.00
--   e1 c2: a credit note of i1, subscription -12.00 (-10.00)
--   a voided invoice and an April one are left out.
-- Net 235.00, gross 281.00 over 7 lines of 4 invoices; by kind package
-- 100.00, subscription 90.00, service 25.00, overage 20.00; by service Ten
-- half-days 100.00, Coffee 15.00, Printing 10.00.
-- Rooms the space rents: Studio at 300.00 a month (one March occurrence;
-- a rejected one and April's are left out), three bookings charged 150.00
-- each and a fourth reversed: 450.00 - 300.00 = 150.00; Loft at 20.00 per
-- use, two bookings at 40.00: 80.00 - 40.00 = 40.00.
-- A plain member reads nothing; a dollar invoice leaves every amount unknown
-- while the counts stay; without externalRooms the rooms are null with
-- their reason; without the status flag nothing is read.
begin;
select plan(19);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000032943'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@sales.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000032943b1','Sales','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000032943a1','dev',
  '{"member":["viewAnalytics"]}',
  '{"moneyTab":true,"invoicing":true,"workspaceStatus":true,"levelBooking":true,"externalRooms":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000032943c1','00000000-0000-4000-8000-0000032943b1','00000000-0000-4000-8000-0000032943a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000032943c2','00000000-0000-4000-8000-0000032943b1','00000000-0000-4000-8000-0000032943a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000032943c3','00000000-0000-4000-8000-0000032943b1','00000000-0000-4000-8000-0000032943a3',false,false,'active');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000032943' || p)::uuid;
$$;
create function pg_temp.inv(p_id text, p_member text, p_lines jsonb, p_period text default '2025-03',
                            p_currency text default 'EUR', p_replaces text default null,
                            p_kind text default 'full', p_voided boolean default false)
returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at,
                               period, kind, replaces_invoice_id, voided_at, voided_by_name)
  values (pg_temp.u(p_id), pg_temp.u('b1'), pg_temp.u(p_member), pg_temp.u('c1'), 'S-' || p_id, 'T', p_lines,
          (select coalesce(sum((l ->> 'amount_cents')::int), 0) from jsonb_array_elements(p_lines) l),
          p_currency, 'Name ' || p_member, 'Sales', 'Owner', 'sig', (p_period || '-05 10:00+01')::timestamptz,
          p_period, p_kind, case when p_replaces is not null then pg_temp.u(p_replaces) end,
          case when p_voided then now() end, case when p_voided then 'Owner' else '' end);
$$;
create function pg_temp.line(p_kind text, p_cents int, p_label text default '', p_vat numeric default 20)
returns jsonb language sql as $$
  select jsonb_build_object('kind', p_kind, 'label', p_label, 'quantity', 1, 'amount_cents', p_cents,
                            'vat_percent', p_vat);
$$;
-- A booking charge of a rented room, with its ledger entry.
create function pg_temp.charge(p_rental text, p_cents int, p_period text default '2025-03',
                               p_reversed boolean default false) returns void language plpgsql as $$
declare v_le uuid; v_back uuid;
begin
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (pg_temp.u('b1'), pg_temp.u('c2'), 'charge', 'service', p_cents, 'room', p_period)
  returning id into v_le;
  if p_reversed then
    insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
    values (pg_temp.u('b1'), pg_temp.u('c2'), 'credit', 'adjustment', p_cents, 'Cancelled: room', p_period)
    returning id into v_back;
  end if;
  insert into public.reservation_charges (workspace_id, member_id, rental_id, rental_revision, unit, units,
                                          unit_fee_cents, amount_cents, vat_percent, period, description,
                                          ledger_charge_id, ledger_reversal_id, reversed_at)
  values (pg_temp.u('b1'), pg_temp.u('c2'), pg_temp.u(p_rental), 1, 'half_day', 1, p_cents, p_cents, 20,
          p_period, 'room', v_le, v_back, case when p_reversed then now() end);
end;
$$;
create function pg_temp.kpi(p_user text, p_from text default '2025-03', p_to text default '2025-03')
returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  select public.kpi_sales_quality(pg_temp.u('b1'), p_from, p_to) into v;
  return v;
end;
$$;
create function pg_temp.err(p_user text, p_from text default '2025-03', p_to text default '2025-03')
returns text language plpgsql as $$
begin
  perform pg_temp.kpi(p_user, p_from, p_to);
  return '';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.inv('d1', 'c2', jsonb_build_array(pg_temp.line('subscription', 12000, '100'),
  pg_temp.line('service', 600, 'Coffee'), pg_temp.line('payment', -5000, '', 0)));
select pg_temp.inv('d2', 'c3', jsonb_build_array(pg_temp.line('overage', 2400),
  pg_temp.line('package', 12000, 'Ten half-days'), pg_temp.line('service', 1200, 'Coffee')));
select pg_temp.inv('d3', 'c3', jsonb_build_array(jsonb_build_object('kind', 'service', 'label', 'Printing',
  'quantity', 1, 'amount_cents', 1100, 'net_cents', 1000, 'tax_cents', 100, 'vat_percent', 0)),
  '2025-03', 'EUR', null, 'usage');
select pg_temp.inv('e1', 'c2', jsonb_build_array(pg_temp.line('subscription', -1200, '100')), '2025-03', 'EUR', 'd1', 'usage');
select pg_temp.inv('d4', 'c2', jsonb_build_array(pg_temp.line('subscription', 9999, '100')),
  '2025-03', 'EUR', null, 'subscription', true);
select pg_temp.inv('d5', 'c2', jsonb_build_array(pg_temp.line('subscription', 5000, '100')), '2025-04');

insert into public.levels (id, workspace_id, name, kind) values (pg_temp.u('11'), pg_temp.u('b1'), 'Rented', 'external');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h) values
 (pg_temp.u('0a'), pg_temp.u('b1'), pg_temp.u('11'), 'Studio', 0, 0, 10, 10),
 (pg_temp.u('0b'), pg_temp.u('b1'), pg_temp.u('11'), 'Loft', 20, 0, 10, 10);
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values
 (pg_temp.u('f1'), pg_temp.u('b1'), '1', 'Landlord', 'active');
insert into public.room_rentals (id, workspace_id, office_id, supplier_id, available_from, cost_kind, cost_cents,
                                 period, currency, status) values
 (pg_temp.u('1a'), pg_temp.u('b1'), pg_temp.u('0a'), pg_temp.u('f1'), '2025-01-01', 'fixed_per_period', 30000,
  'month', 'EUR', 'active'),
 (pg_temp.u('1b'), pg_temp.u('b1'), pg_temp.u('0b'), pg_temp.u('f1'), '2025-01-01', 'per_use', 2000,
  'month', 'EUR', 'active');
insert into public.expense_occurrences (schedule_id, workspace_id, member_id, due_on, amount_cents, status)
select s.id, pg_temp.u('b1'), pg_temp.u('c1'), d.due, d.cents, d.status
  from public.expense_schedules s,
       (values ('2025-03-01'::date, 30000, 'added'), ('2025-03-15'::date, 99999, 'rejected'),
               ('2025-04-01'::date, 30000, 'added')) d(due, cents, status)
 where s.contract_id = pg_temp.u('1a') and s.origin = 'workspace_contract';
select pg_temp.charge('1a', 15000);
select pg_temp.charge('1a', 15000);
select pg_temp.charge('1a', 15000);
select pg_temp.charge('1a', 15000, '2025-03', true);
select pg_temp.charge('1a', 15000, '2025-04');
select pg_temp.charge('1b', 4000);
select pg_temp.charge('1b', 4000);

set local role authenticated;
select set_config('t.owner', pg_temp.kpi('a1')::text, true);

select is((current_setting('t.owner')::jsonb -> 'revenue' ->> 'net_minor', current_setting('t.owner')::jsonb -> 'revenue' ->> 'gross_minor'),
  ('23500'::text, '28100'::text), 'what March sold: net of VAT, the gross beside it, the credit note subtracted');
select is((current_setting('t.owner')::jsonb -> 'revenue' ->> 'lines', current_setting('t.owner')::jsonb -> 'revenue' ->> 'invoices'),
  ('7'::text, '4'::text), 'seven sales lines of four invoices: the payment credit, the voided and the April invoice are left out');
select is(current_setting('t.owner')::jsonb -> 'revenue' -> 'kinds',
  '[{"kind":"package","lines":1,"net_minor":"10000","gross_minor":"12000"},
    {"kind":"subscription","lines":2,"net_minor":"9000","gross_minor":"10800"},
    {"kind":"service","lines":3,"net_minor":"2500","gross_minor":"2900"},
    {"kind":"overage","lines":1,"net_minor":"2000","gross_minor":"2400"}]'::jsonb,
  'by kind of line, the largest first; a sales-tax line by its own net');
select is(current_setting('t.owner')::jsonb -> 'revenue' -> 'months',
  '[{"month":"2025-03","net_minor":"23500","gross_minor":"28100"}]'::jsonb, 'by the invoice''s month');
select is(current_setting('t.owner')::jsonb -> 'services' -> 'rows',
  '[{"rank":1,"name":"Ten half-days","kind":"package","lines":1,"net_minor":"10000","gross_minor":"12000"},
    {"rank":2,"name":"Coffee","kind":"service","lines":2,"net_minor":"1500","gross_minor":"1800"},
    {"rank":3,"name":"Printing","kind":"service","lines":1,"net_minor":"1000","gross_minor":"1100"}]'::jsonb,
  'the services and packages by their description, the largest first');
select is((current_setting('t.owner')::jsonb -> 'rooms' ->> 'charges_minor', current_setting('t.owner')::jsonb -> 'rooms' ->> 'cost_minor',
           current_setting('t.owner')::jsonb -> 'rooms' ->> 'margin_minor', current_setting('t.owner')::jsonb -> 'rooms' ->> 'uses'),
  ('53000'::text, '34000'::text, '19000'::text, '5'::text),
  'the rented rooms: charged, their own cost, the margin left, the uses');
select is(current_setting('t.owner')::jsonb -> 'rooms' -> 'rows',
  jsonb_build_array(
    jsonb_build_object('office_id', pg_temp.u('0a'), 'name', 'Studio', 'cost_kind', 'fixed_per_period', 'uses', 3,
                       'charges_minor', '45000', 'cost_minor', '30000', 'margin_minor', '15000'),
    jsonb_build_object('office_id', pg_temp.u('0b'), 'name', 'Loft', 'cost_kind', 'per_use', 'uses', 2,
                       'charges_minor', '8000', 'cost_minor', '4000', 'margin_minor', '4000')),
  'per room: a fixed rent by its March occurrence (the rejected one left out), a cost per use times the uses; a reversed booking is not charged');
select is(current_setting('t.owner')::jsonb -> 'quality', '[]'::jsonb, 'a past month in one currency is whole');
select is(pg_temp.err('a2'), '42501', 'a plain member reads no sales figure');
select is(pg_temp.err('a1', '2025-03', '2027-03'), '22023', 'more than 24 months is refused');
select is(pg_temp.err('a1', '2025-04', '2025-03'), '22023', 'a period that ends before it starts is refused');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"externalRooms": false}' where id = pg_temp.u('b1');
set local role authenticated;
select set_config('t.norooms', pg_temp.kpi('a1')::text, true);
select is(current_setting('t.norooms')::jsonb -> 'rooms', 'null'::jsonb, 'without externalRooms there is no room margin');
select ok(current_setting('t.norooms')::jsonb -> 'reasons' ? 'external_rooms_off', '... and the answer says why');
select is(current_setting('t.norooms')::jsonb -> 'revenue' ->> 'net_minor', '23500', '... while the revenue stays');

-- A rate of 0 is a rate; a line without a readable one has no known net.
reset role;
select pg_temp.inv('f2', 'c2', jsonb_build_array(pg_temp.line('service', 500, 'Exempt', 0),
  jsonb_build_object('kind', 'service', 'label', 'Bare', 'quantity', 1, 'amount_cents', 1200),
  jsonb_build_object('kind', 'service', 'label', 'Odd', 'quantity', 1, 'amount_cents', 300, 'vat_percent', 'n/a')),
  '2025-02', 'EUR', null, 'usage');
select pg_temp.inv('f3', 'c2', jsonb_build_array(
  jsonb_build_object('kind', 'service', 'label', 'Bare', 'quantity', 1, 'amount_cents', 800)), '2025-01', 'EUR', null, 'usage');
set local role authenticated;
select is((select jsonb_build_array(k -> 'revenue' ->> 'net_minor', k -> 'revenue' ->> 'gross_minor',
                                    k -> 'revenue' ->> 'net_unknown_lines', k -> 'quality', k -> 'reasons' ? 'net_unknown')
             from pg_temp.kpi('a1', '2025-02', '2025-02') k),
  jsonb_build_array('500', '2000', '2', '["partial"]'::jsonb, true),
  'an explicit 0 % is net; a missing or unreadable rate leaves its net unknown, counted and said, never gross as net');
select is((select jsonb_build_array(k -> 'revenue' -> 'net_minor', k -> 'services' -> 'net_minor', k -> 'revenue' ->> 'gross_minor')
             from pg_temp.kpi('a1', '2025-01', '2025-01') k),
  jsonb_build_array(null, null, '800'), 'no line with a known net: the net is unknown, not 0');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"externalRooms": true}' where id = pg_temp.u('b1');
select pg_temp.inv('d9', 'c3', jsonb_build_array(pg_temp.line('subscription', 700, '100')), '2025-03', 'USD', null, 'subscription');
set local role authenticated;
select set_config('t.mixed', pg_temp.kpi('a1')::text, true);
select ok(current_setting('t.mixed')::jsonb -> 'reasons' ? 'currency_mix'
          and current_setting('t.mixed')::jsonb -> 'revenue' ->> 'net_minor' is null
          and current_setting('t.mixed')::jsonb -> 'rooms' ->> 'margin_minor' is null,
  'a dollar invoice leaves every amount unknown, never summed');
select is((current_setting('t.mixed')::jsonb -> 'revenue' ->> 'lines', current_setting('t.mixed')::jsonb -> 'rooms' ->> 'uses'),
  ('8'::text, '5'::text), '... while the counts stay');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"workspaceStatus": false}' where id = pg_temp.u('b1');
set local role authenticated;
select is(pg_temp.err('a1'), '42501', 'with the status flag off, nothing is read');

select * from finish();
rollback;
