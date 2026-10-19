-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2365 / 0502-0504: closing a book period and the export log. Real roles;
-- every refusal is followed by a readback. Hand-written expectations: the
-- year 2025 is closed; an invoice issued 2025-06-15 cannot be voided, one
-- issued 2026-01-10 can; a payment dated 2025-03-01 cannot be matched.
begin;
select plan(31);
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
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
create function pg_temp.owner_err(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002365' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@bookperiods.test', '', now(), now(), now()
  from generate_series(1, 4) i;
-- 1 owner of A, 2 plain member of A, 3 admin of A without exportData, 4 owner of B.

select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Periods A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as(pg_temp.u(4));
select set_config('t.b', public.create_workspace('Periods B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at, customer_capacity) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 1, '2026-01-01', 'consumer'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, true, 'active', 1, '2026-01-01', 'consumer');

create function pg_temp.inv(p_no text, p_issued timestamptz) returns uuid language plpgsql as $$
declare v uuid;
begin
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, issued_at, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, parties)
  select current_setting('t.a')::uuid, m.id, m.id, p_no, p_issued, 'T', '[]'::jsonb, 12000, 'EUR', 'A', 'W', 'Owner', 'sig',
         '{"seller":{"country":"fr"},"buyer":{"country":"FR"}}'
    from public.members m where m.workspace_id = current_setting('t.a')::uuid and m.user_id = pg_temp.u(1)
  returning id into v;
  return v;
end;
$$;
create function pg_temp.void(p_id uuid) returns text language plpgsql as $$
begin
  update public.invoices set voided_at = now(), voided_by_name = 'Owner' where id = p_id;
  return '';
exception when others then
  return sqlerrm;
end;
$$;
create function pg_temp.match(p_invoice uuid, p_at timestamptz) returns text language plpgsql as $$
begin
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at)
  values (current_setting('t.a')::uuid, p_invoice, 12000, 'exact', p_at);
  return '';
exception when others then
  return sqlerrm;
end;
$$;

-- the claims name the owner of A while the fixtures are written as the table owner
select pg_temp.act_as(pg_temp.u(1));
reset role;
select set_config('t.old', pg_temp.inv('2025-A', timestamptz '2025-06-15 10:00+02')::text, true);
select set_config('t.new', pg_temp.inv('2026-A', timestamptz '2026-01-10 10:00+01')::text, true);
select set_config('t.old2', pg_temp.inv('2025-B', timestamptz '2025-03-01 10:00+01')::text, true);

select alike(pg_temp.as_err(pg_temp.u(1), format('select public.close_book_period_v1(%L, ''2025-01-01'', ''2025-12-31'')', current_setting('t.a'))),
  '%switched off%', '1 closing needs the flag');
update public.workspaces
   set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"invoicing": true, "accountingBook": true, "accountingPeriods": true}'
 where id = current_setting('t.a')::uuid;
select alike(pg_temp.as_err(pg_temp.u(3), format('select public.close_book_period_v1(%L, ''2025-01-01'', ''2025-12-31'')', current_setting('t.a'))),
  '%only an owner%', '2 an admin who is not an owner closes nothing');
select alike(pg_temp.as_err(pg_temp.u(1), format('select public.close_book_period_v1(%L, ''2025-12-31'', ''2025-01-01'')', current_setting('t.a'))),
  '%ends before it starts%', '3 a backwards period is refused');
select alike(pg_temp.as_err(pg_temp.u(1), format('select public.close_book_period_v1(%L, ''2025-01-01'', %L)', current_setting('t.a'), (current_date + 400)::text)),
  '%has not ended%', '4 a period that has not ended cannot be closed');
select is((select count(*)::int from public.book_periods), 0, '4b readback: nothing closed yet');

select set_config('t.p', pg_temp.as_json(pg_temp.u(1), format('select public.close_book_period_v1(%L, ''2025-01-01'', ''2025-12-31'')', current_setting('t.a')))::text, true);
select is(current_setting('t.p')::jsonb ->> 'reason', 'owner', '5 the owner closes 2025');
select alike(pg_temp.as_err(pg_temp.u(1), format('select public.close_book_period_v1(%L, ''2025-06-01'', ''2025-06-30'')', current_setting('t.a'))),
  '%already closed%', '6 an overlapping period is refused');

select alike(pg_temp.void(current_setting('t.old')::uuid), '%closed period%credit note%', '7 an invoice issued in the closed year cannot be voided');
select is((select voided_at is null from public.invoices where id = current_setting('t.old')::uuid), true, '7b readback: it is not voided');
select is(pg_temp.void(current_setting('t.new')::uuid), '', '8 an invoice of the open year can');
select alike(pg_temp.match(current_setting('t.old2')::uuid, timestamptz '2025-03-02 10:00+01'), '%closed period%', '9 a payment dated inside the closed year is not matched');
select is((select count(*)::int from public.invoice_matches), 0, '9b readback: no match left');
select is(pg_temp.match(current_setting('t.old2')::uuid, now()), '', '10 a payment dated today is');

select alike(pg_temp.as_err(pg_temp.u(1), format('select public.reopen_book_period_v1(%L, %L, '' '')', current_setting('t.a'), current_setting('t.p')::jsonb ->> 'id')),
  '%say why%', '11 reopening needs a reason');
select alike(pg_temp.as_err(pg_temp.u(3), format('select public.reopen_book_period_v1(%L, %L, ''x'')', current_setting('t.a'), current_setting('t.p')::jsonb ->> 'id')),
  '%only an owner%', '12 only an owner reopens');

-- exports are logged
select alike(pg_temp.as_err(pg_temp.u(2), format('select public.record_book_export_v1(%L, ''fec'', ''2025-01-01'', ''2025-12-31'', %L, 100, 10, 2)', current_setting('t.a'), repeat('a', 64))),
  '%may not export%', '13 a plain member logs no export');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.record_book_export_v1(%L, ''fec'', ''2025-01-01'', ''2025-12-31'', %L, 100, 10, 2)', current_setting('t.a'), repeat('a', 64))) ->> 'closed_period',
  'true', '14 an export of the closed year is logged as of a closed period');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.record_book_export_v1(%L, ''fec'', ''2025-01-01'', ''2025-12-31'', %L, 100, 10, 2)', current_setting('t.a'), repeat('a', 64))) ->> 'closed_period',
  'true', '14b exported again: logged again, same sha256');
select is((select count(distinct sha256)::int from public.book_exports), 1, '14c readback: two rows, one sha256');
select is(pg_temp.as_json(pg_temp.u(1), format('select public.record_book_export_v1(%L, ''datev'', ''2025-07-01'', ''2026-06-30'', %L, 5, 1, 1)', current_setting('t.a'), repeat('b', 64))) ->> 'closed_period',
  'false', '15 an export reaching the open year is not');
select alike(pg_temp.as_err(pg_temp.u(1), format('select public.record_book_export_v1(%L, ''fec'', ''2025-01-01'', ''2025-12-31'', ''xyz'', 1, 1, 1)', current_setting('t.a'))),
  '%sha256%', '16 a malformed digest is refused');

-- a space that keeps no periods logs nothing and is not refused
update public.workspaces set feature_flags = feature_flags || '{"accountingPeriods": false}' where id = current_setting('t.a')::uuid;
select is(pg_temp.as_json(pg_temp.u(1), format('select public.record_book_export_v1(%L, ''fec'', ''2025-01-01'', ''2025-12-31'', %L, 100, 10, 2)', current_setting('t.a'), repeat('c', 64))) ->> 'logged',
  'false', '16b with the flag off an export is simply not logged');
update public.workspaces set feature_flags = feature_flags || '{"accountingPeriods": true}' where id = current_setting('t.a')::uuid;

-- reopening
select is(pg_temp.as_json(pg_temp.u(1), format('select public.reopen_book_period_v1(%L, %L, ''the accountant found an error'')', current_setting('t.a'), current_setting('t.p')::jsonb ->> 'id')) ->> 'reopen_reason',
  'the accountant found an error', '17 the owner reopens with a reason');
select is(pg_temp.void(current_setting('t.old')::uuid), '', '18 the invoice can be voided once reopened');

-- a filed VAT return closes its period
insert into public.vat_declarations (workspace_id, period_start, period_end, status, lines, total_net_cents, total_vat_cents)
values (current_setting('t.a')::uuid, '2026-01-01', '2026-03-31', 'draft', '[]', 0, 0);
select set_config('deskilo.vat_return_writer', 'file:' || (select id from public.vat_declarations where workspace_id = current_setting('t.a')::uuid), true);
update public.vat_declarations set status = 'filed', number = 'VAT-1', submitted_at = now(), submitted_channel = 'manual', submitted_receipt = 'R-1'
 where workspace_id = current_setting('t.a')::uuid;
select is((select reason from public.book_periods where period_from = '2026-01-01' and reopened_at is null), 'vat_filed',
  '19 filing the VAT return closes its quarter');
select alike(pg_temp.void(pg_temp.inv('2026-B', timestamptz '2026-02-01 10:00+01')), '%closed period%', '20 and an invoice of that quarter is no longer voided');

-- reading
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.book_periods_v1(%L)', current_setting('t.a'))) -> 'periods'), 2, '21 the owner reads both periods');
select is(jsonb_array_length(pg_temp.as_json(pg_temp.u(1), format('select public.book_periods_v1(%L)', current_setting('t.a'))) -> 'exports'), 3, '22 and the three logged exports');
select alike(pg_temp.as_json(pg_temp.u(2), format('select public.book_periods_v1(%L)', current_setting('t.a')))::text, '%may not read%', '23 a plain member reads neither');
select alike(pg_temp.as_json(pg_temp.u(4), format('select public.book_periods_v1(%L)', current_setting('t.a')))::text, '%not an active member%', '24 nor does a foreign owner');
select pg_temp.act_as(pg_temp.u(2));
select is((select count(*)::int from public.book_periods) + (select count(*)::int from public.book_exports), 0, '25 the tables are closed to a plain member');
reset role;

select * from finish();
rollback;
