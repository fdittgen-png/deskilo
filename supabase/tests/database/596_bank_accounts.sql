-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4496 (0986): a bank account is one record of the business, and a statement is imported into it. Two overlapping
-- files of one account import each common movement once, whether the second came in under its name or its IBAN; a
-- movement without the bank's own id that looks like one already imported is held for review, not imported again. A
-- statement with no account picked, with an account no account carries, of another account, or in another currency
-- is refused. A statement imported under a name no account carries is listed, and taken on when an account is known
-- by that name. Only who imports the statements writes the accounts; each name an account is known by is its own.
-- Rolled back.
begin;
select plan(22);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.err(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
-- a movement as the app sends it
create or replace function pg_temp.mv(p_day int, p_cents int, p_tx text, p_ref text default '') returns jsonb language sql as $f$
  select jsonb_build_object('booking_date', format('2026-10-%s', lpad(p_day::text, 2, '0')), 'value_date', format('2026-10-%s', lpad(p_day::text, 2, '0')),
    'amount_cents', p_cents, 'currency', 'EUR', 'transaction_id', p_tx, 'counterparty_name', 'Payer',
    'counterparty_iban', '', 'reference', p_ref, 'end_to_end_id', '', 'remittance', 'rent')
$f$;
create or replace function pg_temp.stmt(p_account text, p_sha text, p_currency text default 'EUR') returns jsonb language sql as $f$
  select jsonb_build_object('format', 'csv', 'account', p_account, 'currency', p_currency, 'statement_ref', '',
    'source_sha256', repeat(p_sha, 64), 'file_name', 'bank.csv')
$f$;
create or replace function pg_temp.v2(p_user int, p_account uuid, p_stmt jsonb, p_lines jsonb) returns text language sql as $f$
  select pg_temp.err(pg_temp.u(p_user), format('select public.import_bank_statement_v2(%L, %L, %L, %L)::text',
    pg_temp.u(101), p_account, p_stmt, p_lines))
$f$;
create or replace function pg_temp.v1(p_user int, p_stmt jsonb, p_lines jsonb) returns text language sql as $f$
  select pg_temp.err(pg_temp.u(p_user), format('select public.import_bank_statement_v1(%L, %L, %L)::text',
    pg_temp.u(101), p_stmt, p_lines))
$f$;
create or replace function pg_temp.save(p_user int, p_id uuid, p_name text, p_iban text, p_aliases text[], p_currency text default 'EUR')
returns text language sql as $f$
  select pg_temp.err(pg_temp.u(p_user), format('select public.save_bank_account_v1(%L, %L, %L, %L, %L, %L, %L, null)::text',
    pg_temp.u(101), p_id, p_name, p_iban, '{}'::text[], p_aliases, p_currency))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tbankacc-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  (pg_temp.u(101), 'Bank accounts FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"moneyTab": true, "invoicing": true, "bankImport": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');

-- who writes the accounts
select is(pg_temp.save(2, null, 'Operating', '', '{}'), 'ERR 42501', 'a member who imports no statements makes no account');
select is(pg_temp.save(3, null, 'Operating', '', '{}'), 'ERR 42501', 'nor a stranger');
select set_config('t.op', pg_temp.save(1, null, 'OPERATING', 'FR76 3000 6000 0112 3456 7890 189', '{}'), false);
select ok(current_setting('t.op')::jsonb ? 'id', 'the owner makes the account, its IBAN given in groups of four');
select is((select iban from public.bank_accounts where id = (current_setting('t.op')::jsonb ->> 'id')::uuid),
  'FR7630006000011234567890189', 'and the IBAN is kept without its spaces');
select is(pg_temp.save(1, null, 'Savings', '', array['operating']), 'ERR DKL02 {"name": "OPERATING", "reason": "taken"}',
  'a name another account is known by is refused');
select is(pg_temp.save(1, null, 'Broken', 'FR76 xx', '{}'), 'ERR DKL02 {"reason": "iban"}', 'so is a value that is no IBAN');

-- two overlapping files of the account, one under its name and one under its IBAN
select is(pg_temp.v2(1, (current_setting('t.op')::jsonb ->> 'id')::uuid, pg_temp.stmt('OPERATING', 'a'),
  jsonb_build_array(pg_temp.mv(1, 10000, 'T1'), pg_temp.mv(2, 20000, 'T2')))::jsonb ->> 'created', '2', 'the first file imports its two movements');
select set_config('t.b', pg_temp.v1(1, pg_temp.stmt('FR76 3000 6000 0112 3456 7890 189', 'b'),
  jsonb_build_array(pg_temp.mv(2, 20000, 'T2'), pg_temp.mv(3, 30000, 'T3'))), false);
select is(current_setting('t.b')::jsonb ->> 'known', '1', 'the second, under the IBAN, knows the common movement');
select is(current_setting('t.b')::jsonb ->> 'created', '1', 'and imports only the new one');
select is((select count(*)::int from public.bank_statement_lines where transaction_id = 'T2'), 1, 'the common movement is there once');
select is((select count(distinct bank_account_id)::int from public.bank_statements where workspace_id = pg_temp.u(101)), 1,
  'both files are of the one account');

-- movements without the bank's own id: a second copy is held for review, not imported again
select is(pg_temp.v2(1, (current_setting('t.op')::jsonb ->> 'id')::uuid, pg_temp.stmt('', 'c'),
  jsonb_build_array(pg_temp.mv(5, 5000, '', 'RF18539007547034')))::jsonb ->> 'created', '1', 'a file without bank ids imports its movement');
select is(pg_temp.v1(1, pg_temp.stmt('operating', 'd'), jsonb_build_array(pg_temp.mv(5, 5000, '', 'RF18539007547034')))::jsonb ->> 'review', '1',
  'the same movement under the account''s name in lower case is held for review, as a copy of the first');

-- refusals, each with its reason
select is(pg_temp.v2(1, null, pg_temp.stmt('', 'e'), jsonb_build_array(pg_temp.mv(6, 100, 'T6'))), 'ERR DKB03 {"reason": "bank_account"}',
  'a statement with no account picked is refused');
select is(pg_temp.v1(1, pg_temp.stmt('SAVINGS', 'f'), jsonb_build_array(pg_temp.mv(6, 100, 'T6'))), 'ERR DKB03 {"reason": "bank_account"}',
  'so is one under a name no account carries');
select is(pg_temp.v2(1, (current_setting('t.op')::jsonb ->> 'id')::uuid, pg_temp.stmt('DE89370400440532013000', '6'), jsonb_build_array(pg_temp.mv(6, 100, 'T6'))),
  'ERR DKB03 {"name": "DE89370400440532013000", "reason": "other_account"}', 'and a file of another account');
select is(pg_temp.v2(1, (current_setting('t.op')::jsonb ->> 'id')::uuid, pg_temp.stmt('', '3', 'CHF'),
  jsonb_build_array(pg_temp.mv(6, 100, 'T6') || '{"currency": "CHF"}')), 'ERR DKB03 {"reason": "currency"}', 'and one in another currency');
select is(pg_temp.v2(2, (current_setting('t.op')::jsonb ->> 'id')::uuid, pg_temp.stmt('', '7'), jsonb_build_array(pg_temp.mv(6, 100, 'T6'))), 'ERR 42501',
  'a member who imports nothing imports nothing');

-- a statement under a name no account carries (an import from before the accounts) is listed, then taken on
insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
values (pg_temp.u(101), 'csv', 'OLD BANK', 'EUR', repeat('9', 64), '2026-09-01', '2026-09-30');
insert into public.bank_statement_lines (workspace_id, statement_id, account, position, booking_date, value_date, amount_cents,
  currency, transaction_id, line_hash)
select pg_temp.u(101), s.id, 'OLD BANK', 1, '2026-09-10', '2026-09-10', 4200, 'EUR', 'OLD-1', repeat('8', 64)
  from public.bank_statements s where s.source_sha256 = repeat('9', 64);
select is(pg_temp.err(pg_temp.u(1), format('select public.bank_import_names_unattached_v1(%L)::text', pg_temp.u(101)))::jsonb -> 0 ->> 'name',
  'OLD BANK', 'the name no account carries is listed for the owner');
select is(pg_temp.save(1, (current_setting('t.op')::jsonb ->> 'id')::uuid, 'OPERATING', 'FR7630006000011234567890189', array['Old bank'])::jsonb ->> 'attached',
  '1', 'once the account is known by it, its statement is taken on');
select is((select l.bank_account_id from public.bank_statement_lines l where l.transaction_id = 'OLD-1'), (current_setting('t.op')::jsonb ->> 'id')::uuid,
  'with its movements');
select is(pg_temp.v1(1, pg_temp.stmt('OPERATING', '4'), jsonb_build_array(pg_temp.mv(10, 4200, 'OLD-1')))::jsonb ->> 'known', '1',
  'and a later file of the account knows its movements');

select * from finish();
rollback;
