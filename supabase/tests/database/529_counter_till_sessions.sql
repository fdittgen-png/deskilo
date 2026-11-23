-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4367 (0905-0907, CS5): a till is opened with its float (one open session per till, a lost answer recovers the same one), takes paid-in and paid-out entries with a reason from the business's list (a paid-out above the limit needs the right to record outgoing payments), the expected cash is derived and hidden from a blind count, the close records the counted amount, the difference and its reason, and a closed session is frozen. Rolled back.
begin;
select plan(34);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
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
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.sqlstate_of(p_sql text) returns text language plpgsql as $f$
begin execute p_sql; return 'none'; exception when others then return sqlstate; end
$f$;
create or replace function pg_temp.till(p_user int, p_req int, p_till uuid, p_name text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_till_save_v1(%L, %L, %L, %L, null, true)::text', pg_temp.u(101), pg_temp.u(p_req), p_till, p_name))
$f$;
create or replace function pg_temp.sopen(p_user int, p_req int, p_till uuid, p_float bigint, p_den text default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_session_open_v1(%L, %L, %L, %s, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_till, p_float, p_den))
$f$;
create or replace function pg_temp.entry(p_user int, p_req int, p_session uuid, p_kind text, p_amount bigint, p_reason text, p_doc uuid default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_cash_entry_v1(%L, %L, %L, %L, %s, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_session, p_kind, p_amount, p_reason, p_doc))
$f$;
create or replace function pg_temp.sexp(p_user int, p_session uuid, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_session_expected_v1(%L, %L)::text', pg_temp.u(101), p_session), p_delegated)
$f$;
create or replace function pg_temp.sclose(p_user int, p_req int, p_session uuid, p_counted bigint, p_reason text default null, p_banked bigint default 0, p_den text default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_session_close_v1(%L, %L, %L, %s, %L::jsonb, %L, %s)::text', pg_temp.u(101), pg_temp.u(p_req), p_session, p_counted, p_den, p_reason, p_banked))
$f$;
create or replace function pg_temp.dayclose(p_user int, p_req int, p_date date, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_day_close_v1(%L, %L, null, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_date), p_delegated)
$f$;
create or replace function pg_temp.draft(p_user int, p_req int, p_till uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    (p_body::jsonb || jsonb_build_object('till_id', p_till))::text))
$f$;
create or replace function pg_temp.fin(p_user int, p_req int, p_receipt uuid, p_rev int, p_tenders text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt, p_rev, p_tenders))
$f$;
create or replace function pg_temp.sale(p_user int, p_req int, p_till uuid, p_ref text, p_price text, p_cents bigint) returns text language sql as $f$
  select pg_temp.fin(p_user, p_req + 1, pg_temp.f(pg_temp.draft(p_user, p_req, p_till, format('{"source_ref": "%s", "lines": [{"description": "Item", "quantity": "1", "unit_price": "%s", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}}]}', p_ref, p_price)), 'receipt_id')::uuid, 1, format('[{"kind": "cash", "amount_minor": %s}]', p_cents))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ctill-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Till FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}',
   '{"member": ["issueInvoices"], "admin": ["issueInvoices", "viewFinances", "recordOutgoingPayments"], "co_owner": ["exportData"]}'),
  (pg_temp.u(105), 'Till other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(205), pg_temp.u(105), pg_temp.u(4), true, true, 'active');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, co_owner, status) values (pg_temp.u(206), pg_temp.u(101), pg_temp.u(5), false, false, 'active', 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
select set_config('t.till', pg_temp.f(pg_temp.till(1, 7001, null, 'Till 1'), 'till_id'), false);
select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, false);

-- ── open, one open session per till, entries, the derived expected cash, blind, close ──
select set_config('t.s', pg_temp.sopen(2, 7002, current_setting('t.till')::uuid, 15000), false);
select is(pg_temp.f(current_setting('t.s'), 'float_minor'), '15000', 'a session is opened with its float');
select is(pg_temp.f(pg_temp.sopen(2, 7002, current_setting('t.till')::uuid, 15000), 'replayed'), 'true', 'a lost answer retried under the same id answers the same session');
select is(pg_temp.sopen(2, 7003, current_setting('t.till')::uuid, 100), 'ERR DKL12 {"reason": "already_open", "till_id": "' || current_setting('t.till') || '", "session_id": "' || pg_temp.f(current_setting('t.s'), 'session_id') || '"}', 'a second open of the same till is refused, naming the session: one open session per till');
select is(pg_temp.f(pg_temp.entry(2, 7004, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_in', 500, 'change'), 'amount_minor'), '500', 'a paid-in is recorded with a reason of the list');
select is(pg_temp.entry(2, 7005, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_out', 100, 'whim'), 'ERR DKL13 {"reason": "reason_unknown"}', 'a reason that is not on the list is refused');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.paid_out_limit_minor', '1000'::jsonb);
select is(pg_temp.entry(2, 7006, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_out', 1240, 'expense'), 'ERR DKL13 {"reason": "above_limit", "limit_minor": "1000"}', 'a paid-out above the limit needs someone who may record outgoing payments');
select is(pg_temp.f(pg_temp.entry(3, 7007, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_out', 1240, 'expense'), 'amount_minor'), '1240', 'and is recorded by one who may');
select is((select count(*)::int from public.counter_cash_entries where approved_by_member_id = pg_temp.u(203)), 1, 'with the approver named');
select is(pg_temp.entry(2, 7008, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_out', 100, 'expense', pg_temp.u(999)), 'ERR DKL13 {"reason": "purchase_unknown"}', 'a paid-out linked to a purchase document that is not the business''s is refused');
select is(left(pg_temp.sexp(2, pg_temp.f(current_setting('t.s'), 'session_id')::uuid), 9), 'ERR DKN01', 'while the session is open the counter does not see the expected cash (blind count)');
select is(pg_temp.f(pg_temp.sexp(3, pg_temp.f(current_setting('t.s'), 'session_id')::uuid), 'expected_minor'), '14260', 'someone who may see the finances does: 150.00 + 5.00 - 12.40, derived, never typed');
select is(pg_temp.sclose(1, 7009, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 14000), 'ERR DKL13 {"reason": "difference_reason", "difference_minor": "-260"}', 'a difference is not closed without its reason');
select set_config('t.c', pg_temp.sclose(1, 7010, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 14000, 'coin dropped', 10000), false);
select is(pg_temp.f(current_setting('t.c'), 'difference_minor') || ' ' || pg_temp.f(current_setting('t.c'), 'expected_minor'), '-260 14260', 'the close records the counted amount, the expected, the difference and its reason');
select is(pg_temp.f(pg_temp.sclose(1, 7010, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 14000, 'coin dropped', 10000), 'replayed'), 'true', 'a lost answer at the close recovers the same session');
select is(pg_temp.sqlstate_of(format('update public.counter_till_sessions set counted_minor = 1 where id = %L', pg_temp.f(current_setting('t.s'), 'session_id'))), 'DKL03', 'a closed session is never edited');
select is(left(pg_temp.sclose(2, 7013, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 1), 9), 'ERR DKL12', 'a session already closed is not closed again');
select is(pg_temp.entry(2, 7011, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_in', 100, 'change'), 'ERR DKL12 {"reason": "closed"}', 'and takes no more entries: a correction goes to the next session');
select is(left(pg_temp.sopen(4, 7012, current_setting('t.till')::uuid, 100), 9), 'ERR DKN01', 'a person of another business opens nothing here');
select is((select count(*)::int from public.counter_tills where workspace_id = pg_temp.u(105)), 0, 'and another business has no till of this one');

-- ── the raw errors, the other business, the assistant, and who reads what ──
select is(pg_temp.till(1, 7020, null, 'Till 1'), 'ERR DKL12 {"reason": "name_taken"}', 'a second till with the same name is a refusal of the counter, not a raw database error');
select is(left(pg_temp.entry(1, 7021, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, null, 100, 'change'), 9), 'ERR 22023', 'an entry without a kind is refused at the guard');
select set_config('t.till5', pg_temp.f(pg_temp.run_as(pg_temp.u(4), format('select public.counter_till_save_v1(%L, %L, null, %L, null, true)::text', pg_temp.u(105), pg_temp.u(7022), 'Other')), 'till_id'), false);
select set_config('t.s5', pg_temp.f(pg_temp.run_as(pg_temp.u(4), format('select public.counter_session_open_v1(%L, %L, %L, 100, null::jsonb)::text', pg_temp.u(105), pg_temp.u(7023), current_setting('t.till5'))), 'session_id'), false);
select is(pg_temp.entry(1, 7024, current_setting('t.s5')::uuid, 'paid_in', 100, 'change'), 'ERR DKL12 {"reason": "session_unknown"}', 'a session of another business takes no entry from this one');
select is(pg_temp.sclose(1, 7025, current_setting('t.s5')::uuid, 100), 'ERR DKL12 {"reason": "session_unknown"}', 'and is not closed from this one');
select is(concat_ws(',',
  left(pg_temp.run_as(pg_temp.u(1), format('select public.counter_till_save_v1(%L, %L, null, %L, null, true)::text', pg_temp.u(101), pg_temp.u(7026), 'Assistant till'), true), 9),
  left(pg_temp.run_as(pg_temp.u(1), format('select public.counter_session_open_v1(%L, %L, %L, 100, null::jsonb)::text', pg_temp.u(101), pg_temp.u(7027), current_setting('t.till')), true), 9),
  left(pg_temp.run_as(pg_temp.u(1), format('select public.counter_cash_entry_v1(%L, %L, %L, %L, 100, %L, null)::text', pg_temp.u(101), pg_temp.u(7028), pg_temp.f(current_setting('t.s'), 'session_id'), 'paid_in', 'change'), true), 9),
  left(pg_temp.run_as(pg_temp.u(1), format('select public.counter_session_close_v1(%L, %L, %L, 1, null::jsonb, null, 0)::text', pg_temp.u(101), pg_temp.u(7029), pg_temp.f(current_setting('t.s'), 'session_id')), true), 9)),
  'ERR DKN01,ERR DKN01,ERR DKN01,ERR DKN01', 'an assistant session saves no till, opens no session, records no entry and closes nothing');
select set_config('t.s2', pg_temp.f(pg_temp.sopen(2, 7030, current_setting('t.till')::uuid, 5000), 'session_id'), false);
select is(pg_temp.run_as(pg_temp.u(2), 'select count(*)::text from public.counter_till_sessions') || ' ' || pg_temp.run_as(pg_temp.u(2), 'select count(*)::text from public.counter_cash_entries'), '1 0',
  'the counter reads its own open session only: the closed session, with its expected cash and difference, and the entries of it are not its to read');
select is(pg_temp.run_as(pg_temp.u(3), 'select count(*)::text from public.counter_till_sessions'), '2', 'the finances read every session');
select is(pg_temp.run_as(pg_temp.u(3), 'select count(*)::text from public.counter_cash_entries'), '2', 'and every entry');
select is(left(pg_temp.sexp(2, pg_temp.f(current_setting('t.s'), 'session_id')::uuid), 9), 'ERR DKN01', 'the counter does not read the expected cash of a closed session either, nor of one it did not open');

-- the blind count: the refusal of a difference carries no figure for the counter; an entry goes into the opener's session; names; the export
select is(pg_temp.sclose(2, 7040, pg_temp.f(current_setting('t.s2'), 'session_id')::uuid, 1), 'ERR DKL13 {"reason": "difference_reason"}', 'a close that lacks its reason is refused without saying how far off the count was: the figure is the expected cash seen through the counted one');
select set_config('t.tb', pg_temp.f(pg_temp.till(1, 7041, null, 'Till B'), 'till_id'), false);
select set_config('t.sb', pg_temp.f(pg_temp.sopen(1, 7042, current_setting('t.tb')::uuid, 100), 'session_id'), false);
select is(left(pg_temp.entry(2, 7043, current_setting('t.sb')::uuid, 'paid_in', 100, 'change'), 9), 'ERR DKN01', 'an entry does not go into the session of another cashier');
select is(pg_temp.f(pg_temp.entry(3, 7044, current_setting('t.sb')::uuid, 'paid_in', 100, 'change'), 'amount_minor'), '100', 'unless it is made by someone who may see the finances');
select is(pg_temp.till(1, 7045, null, '  till b '), 'ERR DKL12 {"reason": "name_taken"}', 'a till name is unique whatever its case and its spaces');
select is(pg_temp.run_as(pg_temp.u(5), $q$select (select string_agg(e ->> 'table', ',' order by e ->> 'table') from jsonb_array_elements(public.export_workspace_records('$q$ || pg_temp.u(101) || $q$')) e where e ->> 'table' like 'counter_%')$q$),
  'counter_receipt_lines,counter_receipts,counter_refunds,counter_tenders,counter_tills', 'an export without the right to see the finances leaves out the sessions, their entries and the day closes');
select is((select count(*)::int from jsonb_array_elements((select pg_temp.run_as(pg_temp.u(1), format('select public.export_workspace_records(%L)::text', pg_temp.u(101)))::jsonb)) e where e ->> 'table' in ('counter_till_sessions', 'counter_cash_entries', 'counter_day_closes')), 3, 'and with that right it carries them');

select * from finish();
rollback;
