-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4185 (0895): a card tender is a durable state machine (requested, accepted, refused, unknown): a request replays, a
-- tender beyond the total is refused, an open authorization blocks the finalize, a refused one is not paid, an unknown
-- one allows no new request, an authorization accepted after the draft moved needs an explicit reconciliation; a
-- refund follows a correction, needs the right to record outgoing payments and never exceeds what the correction credits.
-- Rolled back.
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
create or replace function pg_temp.draft(p_user int, p_ws int, p_req int, p_receipt uuid, p_rev int, p_body text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_draft_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt, p_rev, p_body), p_delegated)
$f$;
create or replace function pg_temp.fin(p_user int, p_ws int, p_req int, p_receipt uuid, p_rev int, p_tenders text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt, p_rev, p_tenders))
$f$;
create or replace function pg_temp.corr(p_user int, p_ws int, p_req int, p_orig uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_orig, p_body))
$f$;
create or replace function pg_temp.line(p_desc text, p_qty text, p_price text, p_extra text default '') returns text language sql as $f$
  select format('{"description": "%s", "quantity": "%s", "unit_price": "%s", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}%s}', p_desc, p_qty, p_price, p_extra)
$f$;
create or replace function pg_temp.seq() returns text language sql stable as $f$
  select coalesce((select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), 'none')
$f$;
create or replace function pg_temp.treq(p_user int, p_req int, p_receipt uuid, p_amount bigint) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_tender_request_v1(%L, %L, %L, %L, %s)::text', pg_temp.u(101), pg_temp.u(p_req), p_receipt, 'card', p_amount))
$f$;
create or replace function pg_temp.tres(p_user int, p_req int, p_tender uuid, p_outcome text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_tender_resolve_v1(%L, %L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_tender, p_outcome, 'prov-' || p_req))
$f$;
create or replace function pg_temp.trec(p_user int, p_req int, p_tender uuid) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_tender_reconcile_v1(%L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_tender))
$f$;
create or replace function pg_temp.refund(p_user int, p_req int, p_correction uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req), p_correction, p_body))
$f$;
create or replace function pg_temp.newdraft(p_req int, p_ref text) returns text language sql as $f$
  select pg_temp.f(pg_temp.draft(1, 101, p_req, null, null, '{"source_ref": "' || p_ref || '", "lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), 'receipt_id')
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cproducer-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counter FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{"member": ["issueInvoices"]}'),
  (pg_temp.u(102), 'Counter IT', 'IT', 'EUR', 'Europe/Rome', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(103), 'Counter JP', 'FR', 'JPY', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(104), 'Counter KW', 'FR', 'KWD', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
select pg_temp.u(200 + w), pg_temp.u(100 + w), pg_temp.u(1), true, true, 'active' from generate_series(1, 4) w;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
select pg_temp.u(800 + w), pg_temp.u(100 + w), 'Standard', 20, 'S', true, 'standard' from generate_series(1, 4) w;
insert into public.setting_values (scope, workspace_id, key, value)
select 'workspace', pg_temp.u(100 + w), 'counter.fiscal_obligation', '"none"'::jsonb from generate_series(1, 4) w;



-- ── a card tender, step by step ──
select set_config('t.a', pg_temp.newdraft(971, 'c-1'), false);
select set_config('t.t1', pg_temp.treq(1, 972, current_setting('t.a')::uuid, 1200), false);
select is(pg_temp.f(current_setting('t.t1'), 'state') || ' ' || pg_temp.f(current_setting('t.t1'), 'provider_key'), 'requested dk-' || pg_temp.u(972)::text, 'an authorization asked is recorded, with a provider key that is the request id');
select is(pg_temp.f(pg_temp.treq(1, 972, current_setting('t.a')::uuid, 1200), 'tender_id'), pg_temp.f(current_setting('t.t1'), 'tender_id'), 'a lost answer retried under the same id answers the same tender');
select is(left(pg_temp.treq(1, 973, current_setting('t.a')::uuid, 1), 15), 'ERR DKL06 tende', 'a second tender beyond the total is refused');
select is(left(pg_temp.fin(1, 101, 974, current_setting('t.a')::uuid, 1, '[]'), 15), 'ERR DKL06 tende', 'an authorization still open blocks the finalize');
select is(pg_temp.f(pg_temp.tres(1, 975, pg_temp.f(current_setting('t.t1'), 'tender_id')::uuid, 'accepted'), 'state'), 'accepted', 'the answer accepted settles it');
select is(left(pg_temp.tres(1, 976, pg_temp.f(current_setting('t.t1'), 'tender_id')::uuid, 'refused'), 9), 'ERR DKL11', 'a settled authorization is not answered again');
select is(pg_temp.f(pg_temp.fin(1, 101, 977, current_setting('t.a')::uuid, 1, format('[{"tender_id": "%s"}]', pg_temp.f(current_setting('t.t1'), 'tender_id'))), 'number') is not null, true, 'the sale is finalized with the accepted card tender named by its id');
select is((select string_agg(kind || ':' || state, ',') from public.counter_tenders where receipt_id = current_setting('t.a')::uuid), 'card:accepted', 'and the tender is kept, accepted');

-- refused is not paid; unknown allows no new request
select set_config('t.b', pg_temp.newdraft(981, 'c-2'), false);
select set_config('t.t2', pg_temp.treq(1, 982, current_setting('t.b')::uuid, 1200), false);
select is(pg_temp.f(pg_temp.tres(1, 983, pg_temp.f(current_setting('t.t2'), 'tender_id')::uuid, 'refused'), 'state'), 'refused', 'a declined authorization is refused');
select is(pg_temp.f(pg_temp.fin(1, 101, 984, current_setting('t.b')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), 'number') is not null, true, 'and is not paid: the sale is settled in cash');
select set_config('t.c', pg_temp.newdraft(991, 'c-3'), false);
select set_config('t.t3', pg_temp.treq(1, 992, current_setting('t.c')::uuid, 1200), false);
select is(pg_temp.f(pg_temp.tres(1, 993, pg_temp.f(current_setting('t.t3'), 'tender_id')::uuid, 'unknown'), 'state'), 'unknown', 'a timeout leaves the authorization unknown');
select is(left(pg_temp.treq(1, 994, current_setting('t.c')::uuid, 1200), 9), 'ERR DKL11', 'no new request is made while one is unknown');
select is(left(pg_temp.fin(1, 101, 995, current_setting('t.c')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), 15), 'ERR DKL06 tende', 'and the sale is not finalized over it');
select is(pg_temp.f(pg_temp.tres(1, 996, pg_temp.f(current_setting('t.t3'), 'tender_id')::uuid, 'accepted'), 'state'), 'accepted', 'the provider''s own answer settles it');

-- accepted after the offer moved: an explicit reconciliation
select set_config('t.d', pg_temp.newdraft(1001, 'c-4'), false);
select set_config('t.t4', pg_temp.treq(1, 1002, current_setting('t.d')::uuid, 1200), false);
select is(pg_temp.f(pg_temp.draft(1, 101, 1003, current_setting('t.d')::uuid, 1, '{"source_ref": "c-4", "lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), 'revision'), '2', 'the draft is replaced while the authorization is out');
select is(pg_temp.f(pg_temp.tres(1, 1004, pg_temp.f(current_setting('t.t4'), 'tender_id')::uuid, 'accepted'), 'reconciliation'), 'needed', 'accepted after the offer moved: it waits for an explicit reconciliation');
select is(left(pg_temp.fin(1, 101, 1005, current_setting('t.d')::uuid, 2, '[]'), 15), 'ERR DKL06 tende', 'the sale cannot be finalized until it is reconciled');
select is(pg_temp.f(pg_temp.trec(1, 1006, pg_temp.f(current_setting('t.t4'), 'tender_id')::uuid), 'reconciliation'), 'done', 'a person who may see the finances reconciles it');
select is(pg_temp.f(pg_temp.fin(1, 101, 1007, current_setting('t.d')::uuid, 2, '[]'), 'number') is not null, true, 'and the sale is then finalized with it');

-- ── an unknown authorization is not settled on a cashier's word ──
select set_config('t.e', pg_temp.newdraft(1011, 'c-5'), false);
select set_config('t.t5', pg_temp.treq(2, 1012, current_setting('t.e')::uuid, 1200), false);
select is(pg_temp.f(pg_temp.tres(2, 1013, pg_temp.f(current_setting('t.t5'), 'tender_id')::uuid, 'unknown'), 'state'), 'unknown', 'a cashier records that the answer did not come');
select is(left(pg_temp.tres(2, 1014, pg_temp.f(current_setting('t.t5'), 'tender_id')::uuid, 'accepted'), 9), 'ERR DKN01', 'but settling it takes someone who may see the finances');

select * from finish();
rollback;
