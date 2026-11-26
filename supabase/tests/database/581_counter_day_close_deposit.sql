-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4478 (0973): the day close with a returned deposit. Bread at 5.5 % sold with two deposits at 20 % brought back, in a
-- session closed as counted: the day's 20 % group holds only the returned deposits and is below zero on its own, the
-- day's sales are the bread less the deposits, and the returned deposits are their own figure. Rolled back.
begin;
select plan(3);

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
create or replace function pg_temp.refund_other(p_user int, p_req int, p_receipt uuid, p_amount bigint) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt,
    format('[{"kind": "other", "amount_minor": %s}]', p_amount)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dday-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Deposit day FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "counterTillSessions": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values
  (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard'),
  (pg_temp.u(802), pg_temp.u(101), 'Reduced', 5.5, 'S', false, 'reduced');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, stockable, vat_rate_id) values
  (pg_temp.u(301), pg_temp.u(101), 'Bottle deposit', 25, true, 'piece', false, pg_temp.u(801)),
  (pg_temp.u(303), pg_temp.u(101), 'Bread', 200, true, 'piece', false, pg_temp.u(802));
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, stockable, deposit_item_id) values
  (pg_temp.u(302), pg_temp.u(101), 'Water', 100, true, 'piece', false, pg_temp.u(301));

select set_config('t.till', pg_temp.f(pg_temp.till(1, 7001, null, 'Till 1'), 'till_id'), false);
select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, false);
select set_config('t.s', pg_temp.f(pg_temp.sopen(1, 7002, current_setting('t.till')::uuid, 1000), 'session_id'), false);
select set_config('t.d', pg_temp.draft(1, 7003, current_setting('t.till')::uuid,
  format('{"lines": [{"item_id": "%s", "quantity": "1"}, {"item_id": "%s", "quantity": "2", "returned": true}]}', pg_temp.u(303), pg_temp.u(301))), false);
select set_config('t.r', pg_temp.fin(1, 7004, pg_temp.f(current_setting('t.d'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 150}]'), false);
select set_config('t.x', pg_temp.sclose(1, 7005, current_setting('t.s')::uuid, 1150), false);
select set_config('t.day', pg_temp.dayclose(1, 7006, current_setting('t.today')::date), false);

select is((select string_agg(trim_scale((g ->> 'percent')::numeric)::text || '=' || (g ->> 'gross_minor'), ' ' order by (g ->> 'percent')::numeric)
             from jsonb_array_elements(case when current_setting('t.day') like '{%' then current_setting('t.day')::jsonb #> '{report,sales_by_rate}' end) g),
          '5.5=200 20=-50', 'the 20 % group holds only the returned deposits, below zero on its own');
select is(case when current_setting('t.day') like '{%' then current_setting('t.day')::jsonb #>> '{report,sales_total_minor}' else current_setting('t.day') end, '150',
          'the day''s sales are the bread less the deposits');
select is(case when current_setting('t.day') like '{%' then current_setting('t.day')::jsonb #>> '{report,deposits_returned_minor}' else current_setting('t.day') end, '50',
          'and the returned deposits are their own figure');

select * from finish();
rollback;
