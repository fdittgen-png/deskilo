-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4184 (0891-0893, CS1): the counter's contract. The registry of country operations says supported only with an
-- adapter and never for Italy or for a case that declares a fiscal register; the readiness of a business is what
-- the registry says AND an implemented adapter (a registry row alone opens nothing); the gate refuses an
-- unsupported operation (DKL01) with its reason; a finalized receipt, its lines and a tender's amount are never
-- edited; a correction is a new receipt that cites the original; the same source finalizes once; the tables take
-- no direct write; the versioned reader refuses a version it does not know. Rolled back.
begin;
select plan(32);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.sqlstate_of(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'none'; exception when others then return sqlstate; end
$f$;
create or replace function pg_temp.detail_of(p_sql text) returns text language plpgsql as $f$
declare d text;
begin execute p_sql; return 'none'; exception when others then get stacked diagnostics d = pg_exception_detail; return sqlstate || coalesce(' ' || d, ''); end
$f$;
create or replace function pg_temp.ready(p_user int, p_ws int, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(case when p_user = 0 then null else pg_temp.u(p_user) end, format('select public.counter_readiness_v1(%L)::text', pg_temp.u(p_ws)), p_delegated)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'counter-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counter FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(102), 'Counter IT', 'IT', 'EUR', 'Europe/Rome', pg_temp.u(1), '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(103), 'Counter off', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true}', '{}'),
  (pg_temp.u(104), 'Counter other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(211), pg_temp.u(102), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(213), pg_temp.u(103), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(214), pg_temp.u(104), pg_temp.u(4), true, true, 'active');

-- ── the registry ──
select is((select count(*)::int from public.counter_country_operations), 32, 'the registry has 8 rows for each of the four countries');
select is((select string_agg(country_code, ',' order by country_code) from (select distinct country_code from public.counter_country_operations where outcome = 'supported') s), 'DE,ES,FR',
  'only FR, DE and ES have a supported operation: Italy has none');
select is((select count(*)::int from public.counter_country_operations where outcome = 'supported' and regime <> 'none'), 0, 'and none is supported under a declared fiscal register');
select is((select count(*)::int from public.counter_country_operations where outcome = 'supported' and (adapter is null or evidence = '')), 0, 'a supported row names its adapter and its evidence');
select is((select count(*)::int from public.counter_country_operations where confirmed), 0, 'no row claims a confirmation no tax professional gave');

-- ── readiness: the registry AND an implemented adapter ──
select is((pg_temp.ready(1, 101)::jsonb ->> 'ready') || ' ' || (pg_temp.ready(1, 101)::jsonb ->> 'fiscal_obligation'), 'false register_required',
  'a business that has not declared otherwise is not ready: a fiscal register is assumed');
select is((select count(*)::int from jsonb_array_elements(pg_temp.ready(1, 101)::jsonb -> 'operations') e where e ->> 'outcome' = 'unavailable'), 5, 'and every operation is unavailable, none refused silently');
insert into public.setting_values (scope, workspace_id, key, value) values
  ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb), ('workspace', pg_temp.u(102), 'counter.fiscal_obligation', '"none"'::jsonb);
select is((select e ->> 'registry_outcome' from jsonb_array_elements(pg_temp.ready(1, 101)::jsonb -> 'operations') e where e ->> 'operation' = 'issue_receipt'), 'supported',
  'declared as none, France reads a supported issue-receipt row');
select is((select e ->> 'outcome' from jsonb_array_elements(pg_temp.ready(1, 101)::jsonb -> 'operations') e where e ->> 'operation' = 'issue_receipt'),
  case when 'counter_receipt_v1' = any (public.counter_adapters()) then 'supported' else 'unavailable' end,
  'and it is open only while its adapter is implemented (a registry row alone opens nothing)');
select is((select e ->> 'outcome' || ' ' || (e ->> 'confirmed') from jsonb_array_elements(pg_temp.ready(1, 102)::jsonb -> 'operations') e where e ->> 'operation' = 'issue_receipt'), 'unavailable false',
  'Italy is unavailable even when declared as none, and the row says so unconfirmed');
select is(left(pg_temp.ready(2, 101), 9), 'ERR DKN01', 'a member without the right reads no readiness');
select is(left(pg_temp.ready(1, 101, true), 9), 'ERR DKN01', 'nor does an assistant session');
select is(left(pg_temp.ready(0, 101), 9), 'ERR DKN01', 'nor a caller with no session');
select is(left(pg_temp.ready(1, 103), 9), 'ERR DKG01', 'with the feature off the readiness is refused (DKG01)');
select is(left(pg_temp.ready(4, 101), 9), 'ERR DKN01', 'and another business reads nothing of this one');

-- ── the gate ──
select is(pg_temp.detail_of(format('select public.counter_require_operation(%L, %L)', pg_temp.u(102), 'issue_receipt')),
  'DKL01 {"reason": "unavailable", "country": "IT", "operation": "issue_receipt", "fiscal_obligation": "none"}', 'an unsupported operation is refused before anything is consumed (DKL01), with its country, case and reason');
select is(left(pg_temp.sqlstate_of(format('select public.counter_require_operation(%L, %L)', pg_temp.u(101), 'sign_fiscal')), 5), 'DKL01', 'a fiscal signing that no adapter does is refused as well');

-- ── the tables: no direct write, rights, frozen documents ──
select is(left(pg_temp.run_as(pg_temp.u(1), format($q$insert into public.counter_receipts (workspace_id, currency) values (%L, 'EUR') returning id::text$q$, pg_temp.u(101))), 9), 'ERR 42501', 'the owner cannot write a receipt directly: the tables have no write grant');
insert into public.counter_receipts (id, workspace_id, currency, source_ref) values (pg_temp.u(501), pg_temp.u(101), 'EUR', 'order-1');
insert into public.counter_receipt_lines (id, workspace_id, receipt_id, line_no, quantity, frozen, net_minor, tax_minor, gross_minor)
  values (pg_temp.u(601), pg_temp.u(101), pg_temp.u(501), 1, 1, '{"kind": "service"}', 1000, 200, 1200);
update public.counter_receipts set state = 'finalized', number = 'R-1', finalized_at = now(),
  frozen = '{"version": 1, "currency": "EUR", "lines": [], "totals": {"net_minor": "1000", "tax_minor": "200", "gross_minor": "1200"}}',
  operation_id = (select id from public.counter_country_operations where country_code = 'FR' and operation = 'issue_receipt' and regime = 'none'),
  total_minor = 1200, tax_minor = 200 where id = pg_temp.u(501);
select is(pg_temp.sqlstate_of($q$update public.counter_receipts set total_minor = 1 where id = '00000000-0000-4000-8000-000000000501'$q$), 'DKL03', 'a finalized receipt is never edited');
select is(pg_temp.sqlstate_of($q$delete from public.counter_receipts where id = '00000000-0000-4000-8000-000000000501'$q$), 'DKL03', 'nor deleted');
select is(pg_temp.sqlstate_of($q$update public.counter_receipt_lines set quantity = 2 where id = '00000000-0000-4000-8000-000000000601'$q$), 'DKL03', 'nor are its lines');
insert into public.counter_tenders (id, workspace_id, receipt_id, kind, amount_minor) values (pg_temp.u(701), pg_temp.u(101), pg_temp.u(501), 'cash', 1200);
select is(pg_temp.sqlstate_of($q$update public.counter_tenders set amount_minor = 1 where id = '00000000-0000-4000-8000-000000000701'$q$), 'DKL03', 'a tender''s amount is never edited');
select is(pg_temp.sqlstate_of($q$update public.counter_tenders set state = 'accepted', resolved_at = now() where id = '00000000-0000-4000-8000-000000000701'$q$), 'none', 'while its state goes forward');
select is(pg_temp.sqlstate_of(format($q$insert into public.counter_receipts (workspace_id, currency, source_ref, state, number, finalized_at, frozen, operation_id) values (%L, 'EUR', 'order-1', 'finalized', 'R-2', now(), '{}', (select id from public.counter_country_operations limit 1))$q$, pg_temp.u(101))), '23505',
  'the same source cannot finalize a second initial receipt');
select is(pg_temp.sqlstate_of(format($q$insert into public.counter_receipts (workspace_id, currency, kind) values (%L, 'EUR', 'correction')$q$, pg_temp.u(101))), '23514', 'a correction must cite its original');
select is(pg_temp.sqlstate_of(format($q$insert into public.counter_receipts (workspace_id, currency, kind, corrects_receipt_id) values (%L, 'EUR', 'correction', %L)$q$, pg_temp.u(101), pg_temp.u(501))), 'none', 'a correction is a new receipt that cites the original');
select is(pg_temp.sqlstate_of(format($q$insert into public.counter_receipts (workspace_id, currency, financial_subject_id) values (%L, 'EUR', %L)$q$, pg_temp.u(101), pg_temp.u(214))), '23503', 'a financial subject of another business is refused');

-- ── the versioned reader ──
select is(public.counter_receipt_decode('{"version": 1, "currency": "EUR", "lines": [], "totals": {}, "future_key": 1}'::jsonb) ? 'future_key', false, 'version 1 is read and a later writer''s added key is ignored');
select is(pg_temp.sqlstate_of($q$select public.counter_receipt_decode('{"version": 2, "currency": "EUR", "lines": [], "totals": {}}'::jsonb)$q$), 'DKL09', 'a version this reader does not know is refused, never guessed');
select is(pg_temp.sqlstate_of($q$select public.counter_receipt_decode('{"version": 1, "currency": "EUR"}'::jsonb)$q$), 'DKL09', 'and an incomplete version 1 is refused');

-- ── the cascade of a workspace's deletion is not an edit ──
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(106), 'Doomed', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}', '{}');
insert into public.counter_receipts (id, workspace_id, state, currency, number, schema_version, frozen, operation_id, finalized_at)
values (pg_temp.u(561), pg_temp.u(106), 'finalized', 'EUR', 'D-1', 1, '{"version": 1}', (select id from public.counter_country_operations where country_code = 'FR' and operation = 'issue_receipt' and regime = 'none'), now());
insert into public.counter_receipt_lines (workspace_id, receipt_id, line_no, quantity, frozen, net_minor, tax_minor, gross_minor) values (pg_temp.u(106), pg_temp.u(561), 1, 1, '{}', 1, 0, 1);
insert into public.counter_tenders (workspace_id, receipt_id, kind, amount_minor) values (pg_temp.u(106), pg_temp.u(561), 'cash', 1);
select is(pg_temp.sqlstate_of(format('delete from public.workspaces where id = %L', pg_temp.u(106))), 'none', 'deleting a business removes its finalized receipts, lines and tenders: the cascade is not an edit');
select is((select count(*)::int from public.counter_receipts where workspace_id = pg_temp.u(106)), 0, 'and nothing of them is left');

select * from finish();
rollback;
