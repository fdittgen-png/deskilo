-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4373 (0937): the till keeps selling for cash offline and the sales are accepted at sync under the server's rules: cash only (the sale
-- is made by the ordinary commands with one cash tender), a session opened before the offline period and still open, a maximum duration, a
-- maximum count, a price within the tolerance, items still active, replay recorded once, gapless numbers (a gap is reported), another
-- business's session refused, an assistant refused, the feature off refused, the refused cash kept in the drawer figure. The two concurrent
-- devices are proven by scripts/stock_transfer_race.sh (section S).
begin;
select plan(30);

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

-- ── a cash sale is accepted, through the ordinary commands ──
select set_config('t.a', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale(1, 7101, 5, '1.20', 2000, 1880) || ']'), false);
select is(pg_temp.f(current_setting('t.a'), 'accepted') || ' ' || pg_temp.f(current_setting('t.a'), 'refused'), '1 0', 'a cash offline sale is accepted');
select is((select count(*)::int from public.counter_receipts r where r.till_session_id = current_setting('t.s')::uuid and r.state = 'finalized' and r.source_kind = 'offline_till'), 1, 'it is a finalized receipt of the session, numbered');
select is((select t.kind || ' ' || t.amount_minor from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id where r.source_kind = 'offline_till'), 'cash 120', 'with one cash tender of exactly its total');
select is(pg_temp.f(pg_temp.sexp(1, current_setting('t.s')::uuid), 'expected_minor'), '10120', 'the day''s drawer figure includes it: float 100.00 + 1.20');
-- ── replay: the same batch twice records each sale once ──
select is((pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(1, 7101, 5, '1.20', 2000, 1880) || ']')::jsonb #>> '{results,0,replayed}'), 'true', 'the same sale sent again answers its first result');
select is((select count(*)::int from public.counter_receipts where source_kind = 'offline_till') || ' ' || (select count(*)::int from public.counter_offline_sales), '1 1', 'and is recorded once');
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(1, 7101, 5, '1.50', 2000, 1880) || ']'), 9), 'ERR DKL16', 'the same request id with other content is refused');
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(1, 7199, 5, '1.20', 2000, 1880) || ']'), 9), 'ERR DKL16', 'a sequence number held by another request is refused');
-- ── a gap is reported, never filled ──
select set_config('t.g', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale(3, 7103, 10, '1.20', 120, 0) || ']'), false);
select is(pg_temp.f(current_setting('t.g'), 'gaps'), '[2]', 'a sequence number missing between recorded ones is reported');
select is(pg_temp.f(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(2, 7102, 8, '1.20', 120, 0) || ']'), 'gaps'), '[]', 'a late sale with the missing number fills it, and the gap is gone');
-- ── refusals are recorded and listed; the others go on ──
select set_config('t.r', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale(4, 7104, 200, '1.20', 120, 0) || ',' || pg_temp.osale(5, 7105, 12, '1.20', 100, 0) || ',' || pg_temp.osale(6, 7106, 13, '2.00', 200, 0)
  || ',' || pg_temp.osale(7, 7107, 14, '3.00', 300, 0, 902) || ',' || pg_temp.osale(8, 7108, 15, '1.30', 130, 0) || ']'), false);
select is((select string_agg(x ->> 'seq' || ':' || (x ->> 'state') || ':' || coalesce(x ->> 'reason', ''), ' ' order by (x ->> 'seq')::int) from jsonb_array_elements(pg_temp.f(current_setting('t.r'), 'results')::jsonb) x),
  '4:refused:too_long 5:refused:cash 6:refused:price 7:refused:item 8:accepted:', 'beyond the duration, short of cash, off the price, a retired item are refused with their reason; a price inside the tolerance is accepted');
select is((select count(*)::int from public.counter_receipts where source_kind = 'offline_till'), 4, 'only the accepted ones made a receipt (seq 1, 2, 3, 8)');
-- the cash of the refused sales is in the drawer
select is(pg_temp.f(pg_temp.sexp(1, current_setting('t.s')::uuid), 'offline_refused_cash_minor'), '720', 'the cash of the refused sales stays in the drawer figure: 1.20 + 1.00 + 2.00 + 3.00');
select is(pg_temp.f(pg_temp.sexp(1, current_setting('t.s')::uuid), 'expected_minor'), '11210', 'and in the expected cash: 100.00 + 3 x 1.20 + 1.30 + 7.20');
-- ── the review of 0937 (#4373): devices, the base quantity, a line without an item, the cash bound, who may send ──
-- two devices of one session both number from 1: neither is refused for the other's number (the price refuses both, and both are recorded)
select set_config('t.d', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale2(1, 7150, 30, '2.00', 200, 0, pg_temp.u(701)) || ',' || pg_temp.osale2(1, 7151, 31, '2.00', 200, 0, pg_temp.u(702))
  || ',' || pg_temp.osale2(3, 7152, 32, '2.00', 200, 0, pg_temp.u(701)) || ']'), false);
select is((select string_agg(x ->> 'seq' || ':' || (x ->> 'reason'), ' ' order by (x ->> 'request_id')) from jsonb_array_elements(pg_temp.f(current_setting('t.d'), 'results')::jsonb) x),
  '1:price 1:price 3:price', 'two devices of one session may both send their number 1');
select is(pg_temp.f(current_setting('t.d'), 'gaps'), '[2]', 'the gaps are those of each device sending: 2 is missing on the first, nothing on the second');
-- a base quantity written 1.0 is checked as 1 (it used to skip the price check)
select is((pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(1, 7160, 33, '0.01', 1, 0, pg_temp.u(703), '1.0') || ']')::jsonb #>> '{results,0,reason}'),
  'price', 'a price far off the item''s is refused whatever way the base quantity is written (1.0)');
-- a line without an item is refused as item, not skipped
select is((pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(2, 7161, 34, '1.20', 120, 0, pg_temp.u(703), null, null) || ']')::jsonb #>> '{results,0,reason}'),
  'item', 'a line with no item is refused as item');
-- the cash taken is bounded by what the lines price to
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(3, 7162, 35, '1.20', 500000, 0, pg_temp.u(703)) || ']'), 9),
  'ERR DKL02', 'cash far beyond what the lines price to is refused as a whole, so a refused sale cannot inflate the drawer');
-- whoever works the till may send into the open session, as they sell online in it
select is(pg_temp.f(pg_temp.sync(2, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale2(3, 7163, 36, '2.00', 200, 0, pg_temp.u(703)) || ']'), 'refused'), '1',
  'a counter person who did not open the session sends into it, as they sell in it');
-- the count limit
select set_config('t.m', pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz,
  '[' || pg_temp.osale(9, 7109, 20, '1.20', 120, 0) || ',' || pg_temp.osale(10, 7110, 21, '1.20', 120, 0) || ',' || pg_temp.osale(11, 7111, 22, '1.20', 120, 0) || ']'), false);
select is((select string_agg(coalesce(x ->> 'reason', x ->> 'state'), ' ' order by (x ->> 'seq')::int) from jsonb_array_elements(pg_temp.f(current_setting('t.m'), 'results')::jsonb) x),
  'accepted accepted too_many', 'beyond the maximum number of offline sales (6) the sale is refused');
-- ── a card is not an offline tender ──
select is((select count(*)::int from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id where r.source_kind = 'offline_till' and t.kind <> 'cash'), 0, 'no offline sale carries any tender but cash (the command takes no other)');
-- ── the list ──
select is((select count(*)::int from jsonb_array_elements(pg_temp.f(pg_temp.run_as(pg_temp.u(3), format('select public.counter_offline_list_v1(%L, %L)::text', pg_temp.u(101), current_setting('t.s'))), 'gaps')::jsonb) g where g ->> 'device_id' = '00000000-0000-0000-0000-000000000000'), 0, 'the finances read the list of the session: no number is missing on the first device');
select is(pg_temp.run_as(pg_temp.u(3), format('select ((public.counter_offline_list_v1(%L, %L) -> ''sales'' -> 0) ->> ''fiscal'')', pg_temp.u(101), current_setting('t.s'))), 'not_signed', 'every offline receipt is listed as not signed');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.counter_offline_list_v1(%L, %L)::text', pg_temp.u(101), current_setting('t.s'))), 9), 'ERR DKN01', 'a counter person who did not open the session does not read the list');
-- ── who may send ──
select is(left(pg_temp.sync(4, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(30, 7130, 5, '1.20', 120, 0) || ']'), 9), 'ERR DKN01', 'someone of another business is refused');
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(30, 7130, 5, '1.20', 120, 0) || ']', true), 9), 'ERR DKN01', 'an assistant session is refused');
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(30, 7130, 5, '1.20', 120, 0) || ']', false, 106), 9), 'ERR DKG01', 'with the feature off it is refused');
select is((select count(*)::int from public.counter_offline_sales where seq = 30), 0, 'a refused call records nothing');
-- ── a session closed before the sync refuses its sales ──
select set_config('t.cl', pg_temp.sclose(1, 7140, current_setting('t.s')::uuid, 0, 'x'), false);
select is(left(pg_temp.sync(1, current_setting('t.s')::uuid, current_setting('t.since')::timestamptz, '[' || pg_temp.osale(40, 7141, 5, '1.20', 120, 0) || ']'), 9)
          || ' ' || (select count(*) from public.counter_offline_sales where seq = 40)::text,
  'ERR DKL12 0', 'a session closed meanwhile takes no new sale, not even a refused one: its counted cash never moves');

select * from finish();
rollback;
