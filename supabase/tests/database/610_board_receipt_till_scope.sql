-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4517 (1002): a board's command acts only on its own till's receipts. The board functions take the lease's till: a
-- new draft goes to that till's open session; a revision or a finalization of a receipt of another till of the
-- business is answered as an unknown receipt, and changes nothing; the board's own receipts are revised and
-- finalized as before. Rolled back.
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
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bscope-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
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

create or replace function pg_temp.bdraft(p_till uuid, p_req int, p_receipt uuid, p_rev int, p_price text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.counter_board_receipt_draft_v1(%L, %L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), p_till, pg_temp.u(p_req), p_receipt, p_rev,
    format('[{"description": "Item", "quantity": "1", "unit_price": "%s", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}}]', p_price)))
$f$;
create or replace function pg_temp.bfin(p_till uuid, p_req int, p_receipt uuid, p_rev int, p_cents bigint) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.counter_board_receipt_finalize_v1(%L, %L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), p_till, pg_temp.u(p_req), p_receipt, p_rev,
    format('[{"kind": "cash", "amount_minor": %s}]', p_cents)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('t.a', pg_temp.f(pg_temp.till(1, 61001, null, 'Till A'), 'till_id'), false);
select set_config('t.b', pg_temp.f(pg_temp.till(1, 61002, null, 'Till B'), 'till_id'), false);
select pg_temp.sopen(1, 61003, current_setting('t.a')::uuid, 0);
select pg_temp.sopen(1, 61004, current_setting('t.b')::uuid, 0);
-- a draft of till B, made at till B
select set_config('t.rb', pg_temp.f(pg_temp.draft(1, 61010, current_setting('t.b')::uuid, '{"lines": [{"description": "Item", "quantity": "1", "unit_price": "3.00", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}}]}'), 'receipt_id'), false);

select is(left(pg_temp.bdraft(current_setting('t.a')::uuid, 61020, current_setting('t.rb')::uuid, 1, '9.00'), 9), 'ERR DKL04',
  'a board of till A does not revise a draft of till B');
select is((select till_session_id = (select id from public.counter_till_sessions where till_id = current_setting('t.b')::uuid and state = 'open')
             and revision = 1 from public.counter_receipts where id = current_setting('t.rb')::uuid), true,
  'which stays in till B''s session, unchanged');
select is(left(pg_temp.bfin(current_setting('t.a')::uuid, 61021, current_setting('t.rb')::uuid, 1, 300), 9), 'ERR DKL04',
  'nor finalizes it');
select is((select state from public.counter_receipts where id = current_setting('t.rb')::uuid), 'draft', 'which stays a draft');
select is(left(pg_temp.bfin(current_setting('t.a')::uuid, 61022, pg_temp.u(999), 1, 300), 9), 'ERR DKL04', 'as an unknown receipt is answered');
-- the board's own till
select set_config('t.ra', pg_temp.f(pg_temp.bdraft(current_setting('t.a')::uuid, 61030, null, null, '4.00'), 'receipt_id'), false);
select is((select s.till_id::text from public.counter_receipts r join public.counter_till_sessions s on s.id = r.till_session_id
            where r.id = current_setting('t.ra')::uuid), current_setting('t.a'), 'a board''s new draft goes to its own till''s session');
select is(pg_temp.f(pg_temp.bdraft(current_setting('t.a')::uuid, 61031, current_setting('t.ra')::uuid, 1, '5.00'), 'revision'), '2',
  'and is revised there');
select ok(pg_temp.f(pg_temp.bfin(current_setting('t.a')::uuid, 61032, current_setting('t.ra')::uuid, 2, 500), 'number') is not null,
  'and finalized there');

select * from finish();
rollback;
