-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2567: a member's scheduled expense names the supplier it pays
-- (`set_expense_schedule_supplier`, migration 9999). The issue's proving
-- scenario end to end, with real roles (definer RPCs and RLS reads run as
-- `authenticated`), and a readback after every refusal:
--   P two inbox documents from the same VAT id resolve to one supplier; a
--     new schedule names it; archived, it is no longer named on a new
--     schedule while the schedule that names it, both documents and the
--     supplier itself stay readable; null clears.
--   R a member who may not read the suppliers, another member's schedule,
--     another workspace's supplier, an unknown schedule, the flag off, a
--     contract's schedule, an ended schedule.
-- Seeds are direct inserts as postgres (users, workspaces, members); the
-- workspaces switch on, explicitly, every flag the RPCs gate on and its
-- parent: scheduledExpenses (create_expense_schedule, 0227) under moneyTab,
-- supplyExpenses under services, einvoiceCustomerDelivery under invoicing.
begin;
select plan(28);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002567' || lpad((9000 + n)::text, 4, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.as_err(p_user uuid, p_sql text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.as_val(p_user uuid, p_sql text) returns text
language plpgsql as $$
declare v text;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.ingest(p_tag text, p_name text, p_vat text) returns text
language plpgsql as $$
begin
  return pg_temp.as_err(pg_temp.u(1), format(
    'select public.ingest_einvoice(%L, ''ubl'', %L, %L::jsonb)', current_setting('t.a')::uuid,
    '<Invoice>' || p_tag || '</Invoice>',
    jsonb_build_object('number', p_tag, 'issue_date', '2026-09-01', 'currency', 'EUR',
      'supplier_name', p_name, 'supplier_vat_id', p_vat,
      'net_cents', 1000, 'tax_cents', 200, 'gross_cents', 1200)::text));
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.schedule(p_user uuid, p_title text) returns uuid
language plpgsql as $$
declare v uuid;
begin
  perform pg_temp.act_as(p_user);
  v := public.create_expense_schedule(current_setting('t.a')::uuid, p_title, 5000,
         current_date, 'month', 1, null, null, '');
  reset role;
  return v;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.name_supplier(p_user uuid, p_schedule text, p_supplier text) returns text
language sql as $$
  select pg_temp.as_err(p_user, format('select public.set_expense_schedule_supplier(%L, %L)',
    current_setting('t.' || p_schedule), nullif(p_supplier, '')));
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.supplier_of_schedule(p_schedule text) returns text language sql as $$
  select coalesce(supplier_id::text, '') from public.expense_schedules
   where id = current_setting('t.' || p_schedule)::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@schedule-supplier.test', '', now(), now(), now()
  from generate_series(1, 3) i;

select set_config('t.a', '00000000-0000-4000-8000-0000256a9001', true);

select set_config('t.b', '00000000-0000-4000-8000-0000256a9002', true);

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, feature_flags)
values (current_setting('t.a')::uuid, 'Schedule supplier A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev',
        '{"moneyTab": true, "scheduledExpenses": true, "services": true, "supplyExpenses": true, "invoicing": true, "einvoiceCustomerDelivery": true}'::jsonb),
       (current_setting('t.b')::uuid, 'Schedule supplier B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), 'dev',
        '{"moneyTab": true, "scheduledExpenses": true, "services": true, "supplyExpenses": true, "invoicing": true, "einvoiceCustomerDelivery": true}'::jsonb);

insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values
 (current_setting('t.a')::uuid, pg_temp.u(1), true, true, 'active'),
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active'),
 (current_setting('t.b')::uuid, pg_temp.u(3), true, true, 'active');

select is(pg_temp.ingest('S-1', 'ACME Sarl', 'FR 12 345 678 901'), '', 'P1 the owner receives a first invoice');
select is(pg_temp.ingest('S-2', 'ACME S.A.R.L.', 'fr12.345.678.901'), '', 'P2 and a second from the same VAT id');
select is((select count(distinct supplier_id)::int from public.einvoice_inbox
            where workspace_id = current_setting('t.a')::uuid and supplier_id is not null), 1,
  'P3 both documents resolve to ONE supplier');
select set_config('t.acme', (select supplier_id::text from public.einvoice_inbox
  where workspace_id = current_setting('t.a')::uuid and invoice_number = 'S-1'), true);
select set_config('t.s1', pg_temp.schedule(pg_temp.u(1), 'Rent')::text, true);
select is(pg_temp.name_supplier(pg_temp.u(1), 's1', current_setting('t.acme')), '',
  'P4 golden: the owner names the supplier on a new schedule');
select is(pg_temp.supplier_of_schedule('s1'), current_setting('t.acme'), 'P5 the schedule pays it');
select set_config('t.s2', pg_temp.schedule(pg_temp.u(2), 'Phone')::text, true);
select is(pg_temp.name_supplier(pg_temp.u(2), 's2', current_setting('t.acme')), 'not allowed to name a supplier',
  'R1 a member who may not read the suppliers cannot name one');
select is(pg_temp.supplier_of_schedule('s2'), '', 'R1 readback: nothing named');
select is(pg_temp.name_supplier(pg_temp.u(2), 's2', ''), '', 'R2 but may leave it without one');
select is(pg_temp.name_supplier(pg_temp.u(2), 's1', ''), 'not allowed',
  'R3 another member''s schedule is not theirs to change');
select is(pg_temp.supplier_of_schedule('s1'), current_setting('t.acme'), 'R3 readback: unchanged');
select set_config('t.other', pg_temp.as_val(pg_temp.u(3), format(
  'select public.save_supplier(%L, null, %L, %L, %L, %L, %L, %L, %L, %L, %L)',
  current_setting('t.b'), 'ACME Sarl', 'FR12345678901', 'vat', '', '', '', 'FR', '', '')), true);
select ok(current_setting('t.other') ~ '^[0-9a-f-]{36}$', 'R4 fixture: the same supplier exists in B');
select is(pg_temp.name_supplier(pg_temp.u(1), 's1', current_setting('t.other')), 'unknown supplier',
  'R4 another workspace''s supplier is never named');
select is(pg_temp.supplier_of_schedule('s1'), current_setting('t.acme'), 'R4 readback: unchanged');
select is(pg_temp.as_err(pg_temp.u(1), 'select public.set_expense_schedule_supplier(gen_random_uuid(), null)'),
  'unknown schedule', 'R5 an unknown schedule');
update public.workspaces set feature_flags = feature_flags || '{"supplyExpenses": false}'
 where id = current_setting('t.a')::uuid;
select is(pg_temp.name_supplier(pg_temp.u(1), 's1', ''), 'suppliers are switched off in this space',
  'R6 the suppliers switched off');
select is(pg_temp.supplier_of_schedule('s1'), current_setting('t.acme'), 'R6 readback: unchanged');
update public.workspaces set feature_flags = feature_flags || '{"supplyExpenses": true}'
 where id = current_setting('t.a')::uuid;
with x as (insert into public.expense_schedules
   (workspace_id, member_id, title, amount_cents, starts_on, unit, status, origin, contract_id)
 select current_setting('t.a')::uuid, m.id, 'Lease', 90000, current_date, 'month', 'active',
        'workspace_contract', gen_random_uuid()
   from public.members m where m.workspace_id = current_setting('t.a')::uuid and m.user_id = pg_temp.u(1)
 returning id)
select set_config('t.c1', (select id::text from x), true);
select is(pg_temp.name_supplier(pg_temp.u(1), 'c1', current_setting('t.acme')),
  'a contract''s schedule takes its supplier from its contract', 'R7 a contract''s schedule');
select is(pg_temp.supplier_of_schedule('c1'), '', 'R7 readback: unchanged');
select is(pg_temp.as_err(pg_temp.u(1), format('select public.set_supplier_status(%L, %L)',
  current_setting('t.acme'), 'archived')), '', 'P6 the owner archives the supplier');
select set_config('t.s3', pg_temp.schedule(pg_temp.u(1), 'Cleaning')::text, true);
select is(pg_temp.name_supplier(pg_temp.u(1), 's3', current_setting('t.acme')), 'an archived supplier cannot be named',
  'P7 an archived supplier is no longer named on a new schedule');
select is(pg_temp.supplier_of_schedule('s3'), '', 'P7 readback: nothing named');
select is(pg_temp.supplier_of_schedule('s1'), current_setting('t.acme'),
  'P8 the schedule that names it keeps it');
select is(pg_temp.as_val(pg_temp.u(1), format(
  'select count(*)::text from public.einvoice_inbox where workspace_id = %L and supplier_id = %L',
  current_setting('t.a'), current_setting('t.acme'))), '2',
  'P9 both documents stay readable and linked, as the owner reads them');
select is(pg_temp.as_val(pg_temp.u(1), format(
  'select status from public.suppliers where id = %L', current_setting('t.acme'))), 'archived',
  'P10 the archived supplier itself stays readable');
select is(pg_temp.name_supplier(pg_temp.u(1), 's1', ''), '', 'P11 null clears the supplier');
select is(pg_temp.supplier_of_schedule('s1'), '', 'P11 readback: cleared');
select is(pg_temp.as_err(pg_temp.u(1), format('select public.cancel_expense_schedule(%L)', current_setting('t.s3'))), '',
  'R8 fixture: the owner ends a schedule');
select is(pg_temp.name_supplier(pg_temp.u(1), 's3', ''), 'this schedule no longer runs',
  'R8 an ended schedule is not changed');

select * from finish();
rollback;
