-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4367 (0905-0909): the shop's Saturday: a float counted by denomination, twenty cash sales, a paid-out linked to a purchase, a count that is 0.50 short with its reason, an amount to the bank, and the day closed with a report that agrees with the receipts. Rolled back.
begin;
select plan(19);

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
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ctill-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Till FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}',
   '{"member": ["issueInvoices"], "admin": ["issueInvoices", "viewFinances", "recordOutgoingPayments"]}'),
  (pg_temp.u(105), 'Till other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(205), pg_temp.u(105), pg_temp.u(4), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
select set_config('t.till', pg_temp.f(pg_temp.till(1, 7001, null, 'Till 1'), 'till_id'), false);
select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, false);

-- ── the shop's Saturday: open with 150.00, 20 sales, a paid-out of 12.40 for milk, counted 1 012.35 against 1 012.85 ──
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.count_by_denomination', 'true'::jsonb);
select is(pg_temp.sopen(1, 7301, current_setting('t.till')::uuid, 15000, '{"5000": 2, "1000": 4}'), 'ERR DKL13 {"reason": "denominations"}', 'counted by denomination, a float that does not add up is refused');
select set_config('t.s', pg_temp.f(pg_temp.sopen(1, 7302, current_setting('t.till')::uuid, 15000, '{"5000": 2, "1000": 4, "500": 2}'), 'session_id'), false);
select is((select float_minor::text from public.counter_till_sessions where id = current_setting('t.s')::uuid), '15000', 'it opens with 150.00 counted by denomination');
select set_config('t.n', (select count(*)::text from (select pg_temp.sale(1, 7400 + 2 * g, current_setting('t.till')::uuid, 'sat-' || g, case when g = 20 then '44.00' else '43.75' end, case when g = 20 then 4400 else 4375 end) from generate_series(1, 20) g) x), false);
select is(current_setting('t.n'), '20', 'twenty sales are made');
insert into public.purchase_documents (id, workspace_id, kind, currency, submitter_member_id, payer_kind) values (pg_temp.u(901), pg_temp.u(101), 'bill', 'EUR', pg_temp.u(201), 'workspace');
select is(pg_temp.f(pg_temp.entry(3, 7499, pg_temp.f(current_setting('t.s'), 'session_id')::uuid, 'paid_out', 1240, 'expense', pg_temp.u(901)), 'amount_minor'), '1240', 'a paid-out of 12.40 for milk is linked to a purchase');
select is(pg_temp.f(pg_temp.sexp(3, current_setting('t.s')::uuid), 'expected_minor'), '101285', 'the expected cash is 1 012.85');
select is(pg_temp.sclose(1, 7500, current_setting('t.s')::uuid, 101235, 'coin dropped', 90000, '{"10000": 10, "1000": 1}'), 'ERR DKL13 {"reason": "denominations"}', 'a count by denomination that does not add up is refused');
select set_config('t.c', pg_temp.sclose(1, 7501, current_setting('t.s')::uuid, 101235, 'coin dropped', 90000, '{"10000": 10, "1000": 1, "100": 2, "10": 3, "5": 1}'), false);
select is(pg_temp.f(current_setting('t.c'), 'difference_minor') || ' ' || pg_temp.f(current_setting('t.c'), 'banked_minor'), '-50 90000', 'closed with 1 012.35: minus 0.50, "coin dropped", 900.00 to the bank');
select set_config('t.dc', pg_temp.dayclose(3, 7502, current_setting('t.today')::date), false);
select is((current_setting('t.dc')::jsonb #>> '{report,sales_total_minor}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,receipts,count}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,paid_out_minor}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,differences_minor}'), '87525 20 1240 -50', 'the day is closed and its report agrees with the receipts: 875.25 in 20 sales, 12.40 paid out, minus 0.50');
select is((select sum(total_minor)::text from public.counter_receipts where state = 'finalized' and kind = 'sale'), '87525', 'the receipts themselves add up to the same');

select * from finish();
rollback;
