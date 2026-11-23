-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4185 (0895): a refund follows a finalized correction, is made by someone who may issue and record outgoing payments,
-- never exceeds what the correction credits (counting the refunds already made), replays under its request id, and is
-- never edited. The correction credits; it does not refund. Rolled back.
begin;
select plan(9);

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
  (pg_temp.u(101), 'Counter FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
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




select set_config('t.r', pg_temp.newdraft(1101, 'r-1'), false);
select set_config('t.f', pg_temp.fin(1, 101, 1102, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), false);
select set_config('t.line', (select id::text from public.counter_receipt_lines where receipt_id = current_setting('t.r')::uuid and line_no = 1), false);
select set_config('t.c', pg_temp.corr(1, 101, 1103, current_setting('t.r')::uuid, format('{"lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))), false);
select set_config('t.cid', pg_temp.f(current_setting('t.c'), 'receipt_id'), false);
select is((select count(*)::int from public.counter_refunds), 0, 'a correction refunds nothing by itself');
select is(left(pg_temp.refund(1, 1104, current_setting('t.cid')::uuid, '[{"kind": "cash", "amount_minor": 1300}]'), 9), 'ERR DKL08', 'a refund beyond what the correction credits is refused');
select is(pg_temp.f(pg_temp.refund(1, 1105, current_setting('t.cid')::uuid, '[{"kind": "cash", "amount_minor": 500}]'), 'left_minor'), '700', 'part of it is refunded, with what is left');
select is(pg_temp.f(pg_temp.refund(1, 1105, current_setting('t.cid')::uuid, '[{"kind": "cash", "amount_minor": 500}]'), 'replayed'), 'true', 'a lost answer retried under the same id answers the same and refunds nothing twice');
select is(pg_temp.refund(1, 1106, current_setting('t.cid')::uuid, '[{"kind": "cash", "amount_minor": 800}]'), 'ERR DKL08 {"left": "700", "reason": "refund_beyond"}', 'the next refund is bounded by what is left');
select is(pg_temp.f(pg_temp.refund(1, 1107, current_setting('t.cid')::uuid, '[{"kind": "cash", "amount_minor": 700}]'), 'left_minor'), '0', 'the rest is refunded');
select is(left(pg_temp.refund(1, 1108, current_setting('t.r')::uuid, '[{"kind": "cash", "amount_minor": 1}]'), 9), 'ERR DKL04', 'only a correction is refunded, never the sale itself');
select is(pg_temp.run_as(pg_temp.u(1), 'update public.counter_refunds set amount_minor = 1'), 'ERR 42501 ' , 'a refund is not edited (no write grant)');
select is(left(pg_temp.refund(2, 1109, current_setting('t.cid')::uuid, '[{"kind": "cash", "amount_minor": 1}]'), 9), 'ERR DKN01', 'a member without the right to issue refunds nothing');

select * from finish();
rollback;
