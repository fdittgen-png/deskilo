-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4373 (0936, 0937): the registry, the settings, the guard and the reads of the offline sales: the till keeps selling for cash offline and the sales are accepted at sync under the server's rules: cash only (the sale
-- is made by the ordinary commands with one cash tender), a session opened before the offline period and still open, a maximum duration, a
-- maximum count, a price within the tolerance, items still active, replay recorded once, gapless numbers (a gap is reported), another
-- business's session refused, an assistant refused, the feature off refused, the refused cash kept in the drawer figure. The two concurrent
-- devices are proven by scripts/stock_transfer_race.sh (section S).
begin;
select plan(8);

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
create or replace function pg_temp.sync(p_user int, p_session uuid, p_since timestamptz, p_sales text, p_delegated boolean default false, p_ws int default 101) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_offline_sync_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(p_ws), p_session, p_since, p_sales), p_delegated)
$f$;
-- one offline sale of a service item: seq, request, minutes after the start, price, cash given, change
create or replace function pg_temp.osale(p_seq int, p_req int, p_min int, p_price text, p_given bigint, p_change bigint, p_item int default 901) returns text language sql as $f$
  select jsonb_build_object('seq', p_seq, 'request_id', pg_temp.u(p_req), 'occurred_at', (current_setting('t.since')::timestamptz + make_interval(mins => p_min)),
    'cash_given_minor', p_given, 'change_minor', p_change,
    'body', jsonb_build_object('lines', jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', '1', 'unit_price', p_price))))::text
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'coff-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Offline FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterOfflineCash": true}',
   '{"member": ["issueInvoices"], "admin": ["issueInvoices", "viewFinances", "recordOutgoingPayments"]}'),
  (pg_temp.u(105), 'Offline other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true, "counterOfflineCash": true}', '{}'),
  (pg_temp.u(106), 'Offline off', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(205), pg_temp.u(105), pg_temp.u(4), true, true, 'active'),
  (pg_temp.u(206), pg_temp.u(106), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.services (id, workspace_id, name, price_cents, active) values
  (pg_temp.u(901), pg_temp.u(101), 'Baguette', 120, true),
  (pg_temp.u(902), pg_temp.u(101), 'Retired', 300, false);
insert into public.setting_values (scope, workspace_id, key, value) values
  ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb),
  ('workspace', pg_temp.u(101), 'counter.offline_max_sales', '6'::jsonb),
  ('workspace', pg_temp.u(101), 'counter.offline_max_minutes', '120'::jsonb),
  ('workspace', pg_temp.u(101), 'counter.offline_price_tolerance_percent', '10'::jsonb);
select set_config('t.till', pg_temp.f(pg_temp.till(1, 7001, null, 'Till 1'), 'till_id'), false);
select set_config('t.s', pg_temp.f(pg_temp.sopen(1, 7002, current_setting('t.till')::uuid, 10000), 'session_id'), false);
-- the offline period started 300 minutes ago, the session was opened an hour before
select set_config('t.since', (now() - interval '300 minutes')::text, false);
update public.counter_till_sessions set opened_at = now() - interval '6 hours' where id = current_setting('t.s')::uuid;

-- ── the settings are registered with their defaults and limits ──
select is((select string_agg(key || '=' || default_value::text || ' ' || min_value || '..' || max_value, '; ' order by key) from public.setting_definitions where key like 'counter.offline_%'),
  'counter.offline_max_minutes=240 1..2880; counter.offline_max_sales=200 1..1000; counter.offline_price_tolerance_percent=0 0..100', 'the three settings exist with their defaults and bounds');
select is((public.feature_registry() -> 'counterOfflineCash')::text, '{"core": false, "parent": "counterTillSessions", "default": false}', 'the feature sits under the till sessions and is off by default');
select is(public.feature_effective(pg_temp.u(106), 'counterOfflineCash'), false, 'and is off in a business that did not ask for it');
-- ── one received sale, then the guard and the reads ──
select set_config('t.a', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale(1, 7101, 5, '1.20', 120, 0) || ',' || pg_temp.osale(2, 7102, 6, '9.99', 999, 0) || ']'), false);
select is(pg_temp.f(current_setting('t.a'), 'accepted') || ' ' || pg_temp.f(current_setting('t.a'), 'refused'), '1 1', 'one accepted, one refused for its price (tolerance 10 percent)');
select is(pg_temp.sqlstate_of(format('update public.counter_offline_sales set reason = %L where till_session_id = %L', 'x', current_setting('t.s'))), 'DKL03', 'a received offline sale is never edited');
select is(pg_temp.sqlstate_of(format('delete from public.counter_offline_sales where till_session_id = %L', current_setting('t.s'))), 'DKL03', 'nor deleted');
select is(pg_temp.run_as(pg_temp.u(2), format('select count(*)::text from public.counter_offline_sales where workspace_id = %L', pg_temp.u(101))), '0', 'a counter person without the finances right reads no row of the table');
select is(pg_temp.run_as(pg_temp.u(3), format('select count(*)::text from public.counter_offline_sales where workspace_id = %L', pg_temp.u(101))), '2', 'the finances read every received sale, refused ones included');

select * from finish();
rollback;
