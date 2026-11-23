-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4367 (0908): with the sessions on a sale needs an open session on its till; the expected cash counts its cash tenders and cash refunds; a card whose outcome is unknown at the close is listed as unresolved, not as cash; a sale cannot be finalized into a closed session. Rolled back.
begin;
select plan(13);

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

-- ── a sale needs an open session on its till ──
select is(pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(7101),
  '{"lines": [{"description": "Item", "quantity": "1", "unit_price": "12.00", "supply": "general", "unit": {"code": "unit", "label": "unit"}}]}')),
  'ERR DKL12 {"reason": "till_open_first", "till_id": null}', 'a sale without a till is refused: open the till first');
select is(left(pg_temp.draft(1, 7102, current_setting('t.till')::uuid, '{"lines": [{"description": "Item", "quantity": "1", "unit_price": "12.00", "supply": "general", "unit": {"code": "unit", "label": "unit"}}]}'), 9), 'ERR DKL12', 'nor on a till that is not open');
select set_config('t.s', pg_temp.f(pg_temp.sopen(1, 7103, current_setting('t.till')::uuid, 10000), 'session_id'), false);
select set_config('t.r1', pg_temp.sale(1, 7104, current_setting('t.till')::uuid, 'a-1', '12.00', 1200), false);
select is(pg_temp.f(current_setting('t.r1'), 'number') is not null, true, 'with the till open the sale is made');
select is((select till_session_id = current_setting('t.s')::uuid from public.counter_receipts where id = pg_temp.f(current_setting('t.r1'), 'receipt_id')::uuid), true, 'and belongs to the session');
select is(pg_temp.f(pg_temp.sexp(1, current_setting('t.s')::uuid), 'expected_minor'), '11200', 'the expected cash is the float plus the cash tenders of the session');
select set_config('t.d2', pg_temp.draft(1, 7106, current_setting('t.till')::uuid, '{"source_ref": "a-2", "lines": [{"description": "Item", "quantity": "1", "unit_price": "5.00", "supply": "general", "unit": {"code": "unit", "label": "unit"}}]}'), false);
select set_config('t.correction', pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(7107), pg_temp.f(current_setting('t.r1'), 'receipt_id')::uuid,
  format('{"reason": "x", "lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', (select id from public.counter_receipt_lines where receipt_id = pg_temp.f(current_setting('t.r1'), 'receipt_id')::uuid and line_no = 1)))), false);
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(7108), pg_temp.f(current_setting('t.correction'), 'receipt_id')::uuid, '[{"kind": "cash", "amount_minor": 1200}]')), 9), 'ERR DKL12', 'a cash refund comes out of a drawer: it names a till that is open');
select is(pg_temp.f(pg_temp.run_as(pg_temp.u(1), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(7109), pg_temp.f(current_setting('t.correction'), 'receipt_id')::uuid,
  format('[{"kind": "cash", "amount_minor": 500, "till_id": "%s"}]', current_setting('t.till')))), 'left_minor'), '700', 'a cash refund with its till is recorded against the session');
select is(pg_temp.f(pg_temp.sexp(1, current_setting('t.s')::uuid), 'expected_minor'), '10700', 'and lowers its expected cash: 100.00 + 12.00 - 5.00');
-- a card whose outcome is unknown at the close is listed, not counted as cash
select set_config('t.d3', pg_temp.draft(1, 7110, current_setting('t.till')::uuid, '{"source_ref": "a-3", "lines": [{"description": "Item", "quantity": "1", "unit_price": "20.00", "supply": "general", "unit": {"code": "unit", "label": "unit"}}]}'), false);
select set_config('t.tc', pg_temp.run_as(pg_temp.u(1), format('select public.counter_tender_request_v1(%L, %L, %L, %L, 2000)::text', pg_temp.u(101), pg_temp.u(7111), pg_temp.f(current_setting('t.d3'), 'receipt_id')::uuid, 'card')), false);
select is(pg_temp.f(pg_temp.run_as(pg_temp.u(1), format('select public.counter_tender_resolve_v1(%L, %L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(7112), pg_temp.f(current_setting('t.tc'), 'tender_id')::uuid, 'unknown', 'p')), 'state'), 'unknown', 'a card authorization times out');
select set_config('t.cl', pg_temp.sclose(1, 7113, current_setting('t.s')::uuid, 10700), false);
select is(pg_temp.f(current_setting('t.cl'), 'unresolved_card_minor') || ' ' || pg_temp.f(current_setting('t.cl'), 'difference_minor'), '2000 0', 'at the close it is listed as unresolved (20.00) and is not in the cash: no difference');
-- the sale finalized after the close
select is(left(pg_temp.draft(1, 7114, current_setting('t.till')::uuid, '{"lines": [{"description": "Item", "quantity": "1", "unit_price": "1.00", "supply": "general", "unit": {"code": "unit", "label": "unit"}}]}'), 9), 'ERR DKL12', 'a new sale on the closed till is refused');
select is(left(pg_temp.fin(1, 7116, pg_temp.f(current_setting('t.d2'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 500}]'), 9), 'ERR DKL12', 'and a draft made before the close cannot be finalized into the closed session (DKL12 closed)');
select is((select count(*)::int from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id where r.till_session_id = current_setting('t.s')::uuid and t.state = 'accepted' and t.kind = 'cash'), 1, 'only the sale that committed before the close is in the session');

select * from finish();
rollback;
