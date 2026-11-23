-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4367 (0909): the day close refuses a till still open (naming it), is made by someone who may see the finances, is numbered and immutable, its report totals agree with the receipts (by tax rate and tender, the range of numbers, the differences), a lost answer recovers the same close, a day closed once is closed, an assistant reads it with the right to see the finances and nothing else does. Rolled back.
begin;
select plan(21);

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
create or replace function pg_temp.corr(p_user int, p_req int, p_receipt uuid) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt,
    format('{"reason": "x", "lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', (select id from public.counter_receipt_lines where receipt_id = p_receipt and line_no = 1))))
$f$;
create or replace function pg_temp.refund(p_user int, p_req int, p_receipt uuid, p_till uuid, p_amount bigint) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt,
    format('[{"kind": "cash", "amount_minor": %s, "till_id": "%s"}]', p_amount, p_till)))
$f$;
create or replace function pg_temp.sitedayclose(p_user int, p_req int, p_site uuid, p_date date) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_day_close_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_site, p_date))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ctill-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Till FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}',
   '{"member": ["issueInvoices"], "admin": ["issueInvoices", "viewFinances", "recordOutgoingPayments"], "co_owner": ["viewFinances"]}'),
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

-- ── two sites close the same day, each with its own refund; the finances alone close ──
insert into public.sites (id, workspace_id, name, legal_id) values (pg_temp.u(701), pg_temp.u(101), 'Site A', 'A1'), (pg_temp.u(702), pg_temp.u(101), 'Site B', 'B1');
select set_config('t.ta', pg_temp.f(pg_temp.run_as(pg_temp.u(1), format('select public.counter_till_save_v1(%L, %L, null, %L, %L, true)::text', pg_temp.u(101), pg_temp.u(7301), 'TA', pg_temp.u(701))), 'till_id'), false);
select set_config('t.tb', pg_temp.f(pg_temp.run_as(pg_temp.u(1), format('select public.counter_till_save_v1(%L, %L, null, %L, %L, true)::text', pg_temp.u(101), pg_temp.u(7302), 'TB', pg_temp.u(702))), 'till_id'), false);
select set_config('t.sa', pg_temp.f(pg_temp.sopen(1, 7303, current_setting('t.ta')::uuid, 1000), 'session_id'), false);
select set_config('t.sb', pg_temp.f(pg_temp.sopen(1, 7304, current_setting('t.tb')::uuid, 1000), 'session_id'), false);
select set_config('t.ra', pg_temp.sale(1, 7305, current_setting('t.ta')::uuid, 'sa-1', '10.00', 1000), false);
select set_config('t.rb', pg_temp.sale(1, 7307, current_setting('t.tb')::uuid, 'sb-1', '20.00', 2000), false);
select set_config('t.ca', pg_temp.corr(1, 7309, pg_temp.f(current_setting('t.ra'), 'receipt_id')::uuid), false);
select set_config('t.cb', pg_temp.corr(1, 7310, pg_temp.f(current_setting('t.rb'), 'receipt_id')::uuid), false);
select set_config('t.fa', pg_temp.refund(1, 7311, pg_temp.f(current_setting('t.ca'), 'receipt_id')::uuid, current_setting('t.ta')::uuid, 400), false);
select set_config('t.fb', pg_temp.refund(1, 7312, pg_temp.f(current_setting('t.cb'), 'receipt_id')::uuid, current_setting('t.tb')::uuid, 700), false);
select set_config('t.xa', pg_temp.sclose(1, 7313, current_setting('t.sa')::uuid, 1600), false);
select set_config('t.xb', pg_temp.sclose(1, 7314, current_setting('t.sb')::uuid, 2300), false);
select set_config('t.da', pg_temp.sitedayclose(5, 7315, pg_temp.u(701), current_setting('t.today')::date), false);
select is(pg_temp.f(current_setting('t.da'), 'number') is not null, true, 'someone who sees the finances and does not work the counter closes the day of a site');
select is((current_setting('t.da')::jsonb #>> '{report,sales_total_minor}') || ' ' || (current_setting('t.da')::jsonb #>> '{report,refunds,cash}') || ' ' || (current_setting('t.da')::jsonb #>> '{report,corrections,count}'), '1000 400 1',
  'the report of site A counts its own sale, its own refund and its own correction');
select set_config('t.db', pg_temp.sitedayclose(3, 7316, pg_temp.u(702), current_setting('t.today')::date), false);
select is((current_setting('t.db')::jsonb #>> '{report,sales_total_minor}') || ' ' || (current_setting('t.db')::jsonb #>> '{report,refunds,cash}') || ' ' || (current_setting('t.db')::jsonb #>> '{report,corrections,count}'), '2000 700 1',
  'and the report of site B on the same day counts only its own: the refund of site A is not in it');
select is(pg_temp.sopen(1, 7317, current_setting('t.ta')::uuid, 100), 'ERR DKL15 {"reason": "day_closed", "till_id": "' || current_setting('t.ta') || '"}', 'a till of a site whose day is closed opens no session: it could never be part of that close');
select set_config('t.tc', pg_temp.f(pg_temp.till(1, 7318, null, 'TC'), 'till_id'), false);
select set_config('t.sc', pg_temp.f(pg_temp.sopen(1, 7319, current_setting('t.tc')::uuid, 500), 'session_id'), false);
select is(pg_temp.f(pg_temp.sclose(5, 7320, current_setting('t.sc')::uuid, 500), 'difference_minor'), '0', 'someone who sees the finances closes the session another person opened');

-- ── the day close ──
select set_config('t.till2', pg_temp.f(pg_temp.till(1, 7201, null, 'Till 2'), 'till_id'), false);
select set_config('t.s1', pg_temp.f(pg_temp.sopen(1, 7202, current_setting('t.till')::uuid, 10000), 'session_id'), false);
select set_config('t.s2', pg_temp.f(pg_temp.sopen(1, 7203, current_setting('t.till2')::uuid, 5000), 'session_id'), false);
select set_config('t.r1', pg_temp.sale(1, 7204, current_setting('t.till')::uuid, 'd-1', '12.00', 1200), false);
select set_config('t.r2', pg_temp.sale(1, 7206, current_setting('t.till2')::uuid, 'd-2', '30.00', 3000), false);
select set_config('t.c1', pg_temp.sclose(1, 7208, current_setting('t.s1')::uuid, 11200), false);
select is(pg_temp.dayclose(3, 7209, current_setting('t.today')::date), 'ERR DKL14 {"name": "Till 2", "reason": "till_open", "till_id": "' || current_setting('t.till2') || '"}', 'closing the day with a till still open is refused, with the till named');
select set_config('t.c2', pg_temp.sclose(1, 7210, current_setting('t.s2')::uuid, 8000), false);
select is(left(pg_temp.dayclose(2, 7211, current_setting('t.today')::date), 9), 'ERR DKN01', 'the day is closed by someone who may see the finances, not by the counter');
select set_config('t.dc', pg_temp.dayclose(3, 7212, current_setting('t.today')::date), false);
select is(pg_temp.f(current_setting('t.dc'), 'number') is not null, true, 'once every till is closed the day is closed and numbered');
select is((current_setting('t.dc')::jsonb #>> '{report,sales_total_minor}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,receipts,count}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,sales_by_tender,cash}'), '4200 2 4200', 'the report totals agree with the receipts: 12.00 + 30.00 in two sales, all cash');
select is((current_setting('t.dc')::jsonb #>> '{report,sales_by_rate,0,percent}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,sales_by_rate,0,gross_minor}') || ' ' || (current_setting('t.dc')::jsonb #>> '{report,sales_by_rate,0,tax_minor}'), '20.000000 4200 700', 'by tax rate: 42.00 at 20% holds 7.00 of tax');
select is(current_setting('t.dc')::jsonb #>> '{report,differences_minor}', '0', 'the differences of the sessions: none here');
select is((current_setting('t.dc')::jsonb #>> '{report,receipts,first}') = pg_temp.f(current_setting('t.r1'), 'number') and (current_setting('t.dc')::jsonb #>> '{report,receipts,last}') = pg_temp.f(current_setting('t.r2'), 'number'), true, 'and the range of receipt numbers runs from the first to the last');
select is(pg_temp.f(pg_temp.dayclose(3, 7212, current_setting('t.today')::date), 'replayed') || ' ' || (select count(*)::int from public.counter_day_closes), 'true 3', 'a lost answer recovers the same close (and the business has made three closes: two sites and then the rest)');
select is(pg_temp.dayclose(3, 7213, current_setting('t.today')::date), 'ERR DKL14 {"reason": "day_closed"}', 'a day closed once is closed');
select is(pg_temp.dayclose(3, 7214, (current_setting('t.today')::date - 1)), 'ERR DKL14 {"reason": "nothing_to_close"}', 'a day with no closed session has nothing to close');
select is((select count(*)::int from public.counter_till_sessions where day_close_id is not null and till_id in (current_setting('t.till')::uuid, current_setting('t.till2')::uuid, current_setting('t.tc')::uuid)), 3, 'closing the day stamps its sessions');
select is(pg_temp.sqlstate_of(format('update public.counter_day_closes set number = %L where id = %L', 'X', pg_temp.f(current_setting('t.dc'), 'day_close_id'))), 'DKL03', 'a day close is immutable');
select is(pg_temp.sqlstate_of(format('update public.counter_till_sessions set counted_minor = 1 where id = %L', current_setting('t.s1'))), 'DKL03', 'and so are its sessions');
select is(pg_temp.f(pg_temp.run_as(pg_temp.u(3), format('select public.counter_day_report_v1(%L, %L)::text', pg_temp.u(101), pg_temp.f(current_setting('t.dc'), 'day_close_id')), true), 'number'), pg_temp.f(current_setting('t.dc'), 'number'), 'an assistant session reads the report with the right to see the finances');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.counter_day_report_v1(%L, %L)::text', pg_temp.u(101), pg_temp.f(current_setting('t.dc'), 'day_close_id'))), 9), 'ERR DKN01', 'and nothing else reads it');
select is(left(pg_temp.run_as(pg_temp.u(4), format('select public.counter_day_report_v1(%L, %L)::text', pg_temp.u(101), pg_temp.f(current_setting('t.dc'), 'day_close_id'))), 9), 'ERR DKN01', 'a person of another business reads nothing');

select * from finish();
rollback;
