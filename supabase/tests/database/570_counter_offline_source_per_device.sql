-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4451 (0957): two devices of one till session both ring offline sale 1 and both become receipts. The receipt source of a
-- device-named offline sale is (session, device, seq); a caller naming no device (or the all-zero legacy one) keeps `<session>:<seq>`
-- and one shared lane. Replay, a held sequence number, changed content, another business's session and the cash figure are
-- proven beside the positive case. The concurrent form of two devices at sequence 1 is scripts/stock_transfer_race.sh (section S).
begin;
select plan(16);

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
-- the same with a device, a base quantity and an item that may be left out (#4373 review of 0937)
create or replace function pg_temp.osale2(p_seq int, p_req int, p_min int, p_price text, p_given bigint, p_change bigint, p_dev uuid default null, p_base text default null, p_item uuid default pg_temp.u(901)) returns text language sql as $f$
  select (jsonb_build_object('seq', p_seq, 'request_id', pg_temp.u(p_req), 'occurred_at', (current_setting('t.since')::timestamptz + make_interval(mins => p_min)),
    'cash_given_minor', p_given, 'change_minor', p_change,
    'body', jsonb_build_object('lines', jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('item_id', p_item, 'quantity', '1', 'unit_price', p_price, 'base_quantity', p_base)))))
    || case when p_dev is null then '{}'::jsonb else jsonb_build_object('device_id', p_dev) end)::text
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

select set_config('t.dev_a', pg_temp.u(9001)::text, false);
select set_config('t.dev_b', pg_temp.u(9002)::text, false);
-- ── two devices, one sequence number: both are accepted, each a receipt of its own ──
select set_config('t.ra', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale2(1, 7101, 5, '1.20', 2000, 1880, current_setting('t.dev_a')::uuid) || ']'), false);
select set_config('t.rb', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale2(1, 7102, 6, '1.20', 2000, 1880, current_setting('t.dev_b')::uuid) || ']'), false);
select is(pg_temp.f(current_setting('t.ra'), 'accepted') || ' ' || pg_temp.f(current_setting('t.ra'), 'refused'), '1 0', 'device A sale 1 is accepted');
select is(pg_temp.f(current_setting('t.rb'), 'accepted') || ' ' || pg_temp.f(current_setting('t.rb'), 'refused'), '1 0', 'device B sale 1 is accepted too, not refused as a second source');
select is((select count(distinct r.id)::int || ' ' || count(distinct r.number)::int || ' ' || count(distinct r.source_ref)::int
             from public.counter_receipts r where r.till_session_id = current_setting('t.s')::uuid and r.source_kind = 'offline_till'), '2 2 2', 'two receipts with their own numbers and their own sources');
select is((select count(*)::int from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
            where r.till_session_id = current_setting('t.s')::uuid and r.source_kind = 'offline_till' and t.kind = 'cash'), 2, 'and exactly two cash tenders');
select is(pg_temp.f(pg_temp.sexp(1, current_setting('t.s')::uuid), 'expected_minor'), '10240', 'the drawer figure holds both: float 100.00 + 1.20 + 1.20');
select is((select string_agg(r.source_ref, ' ' order by r.source_ref) from public.counter_receipts r where r.till_session_id = current_setting('t.s')::uuid and r.source_kind = 'offline_till'),
  (select string_agg(x, ' ' order by x) from (select current_setting('t.s') || ':' || current_setting('t.dev_a') || ':1' x union all select current_setting('t.s') || ':' || current_setting('t.dev_b') || ':1') q),
  'the source of a device-named sale is session, device and number');
-- ── replay: each sale, singly and as a batch, answers its first result and records nothing more ──
select is(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7101, 5, '1.20', 2000, 1880, current_setting('t.dev_a')::uuid) || ']')::jsonb #>> '{results,0,replayed}', 'true', 'device A sent again replays its receipt');
select is(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7102, 6, '1.20', 2000, 1880, current_setting('t.dev_b')::uuid) || ']')::jsonb #>> '{results,0,replayed}', 'true', 'device B sent again replays its receipt');
select is((pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale2(1, 7101, 5, '1.20', 2000, 1880, current_setting('t.dev_a')::uuid) || ',' || pg_temp.osale2(1, 7102, 6, '1.20', 2000, 1880, current_setting('t.dev_b')::uuid) || ']')::jsonb #>> '{results}')::jsonb @> '[{"replayed": true}, {"replayed": true}]', true, 'both together replay as a batch');
select is((select count(*)::int from public.counter_receipts where source_kind = 'offline_till' and till_session_id = current_setting('t.s')::uuid) || ' ' || (select count(*)::int from public.counter_offline_sales where till_session_id = current_setting('t.s')::uuid), '2 2', 'nothing was recorded twice');
-- ── a held number and changed content are still refused, per device ──
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7110, 7, '1.20', 2000, 1880, current_setting('t.dev_a')::uuid) || ']'), 9), 'ERR DKL16', 'the number device A holds is refused to another request of A');
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7101, 5, '1.50', 2000, 1880, current_setting('t.dev_a')::uuid) || ']'), 9), 'ERR DKL16', 'the same request with changed content is refused');
-- ── the legacy caller: no device and the all-zero device are one lane, in the old form ──
select set_config('t.rl', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7120, 8, '1.20', 2000, 1880) || ']'), false);
select is(pg_temp.f(current_setting('t.rl'), 'accepted'), '1', 'a caller naming no device is accepted');
select is((select r.source_ref from public.counter_receipts r join public.counter_offline_sales o on o.receipt_id = r.id where o.request_id = pg_temp.u(7120)), current_setting('t.s') || ':1', 'with the source of before: session and number');
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7121, 9, '1.20', 2000, 1880, '00000000-0000-0000-0000-000000000000'::uuid) || ']'), 9), 'ERR DKL16', 'the all-zero device is that same lane: its sale 1 is held');
-- ── isolation ──
select is(left(pg_temp.sync(4, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(2, 7130, 10, '1.20', 2000, 1880, current_setting('t.dev_a')::uuid) || ']', false, 105), 3), 'ERR', 'another business cannot send into this session');
select * from finish();
rollback;
