-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4185 (0894): a correction is a NEW receipt that cites the original and its lines, never an edit of it; the quantity
-- of each line is bounded by what the original line still has left (counting the corrections already made); the
-- original's frozen document is unchanged afterwards; only a finalized sale is corrected; a correction is not corrected;
-- it needs the operation supported. Rolled back.
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


select set_config('t.d', pg_temp.draft(1, 101, 961, null, null, '{"source_ref": "o-1", "lines": [' || pg_temp.line('Haircut', '2', '12.00') || ']}'), false);
select set_config('t.r', pg_temp.f(current_setting('t.d'), 'receipt_id'), false);
select set_config('t.f', pg_temp.fin(1, 101, 962, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 2400}]'), false);
select set_config('t.line', (select id::text from public.counter_receipt_lines where receipt_id = current_setting('t.r')::uuid and line_no = 1), false);
select set_config('t.before', (select md5(frozen::text) from public.counter_receipts where id = current_setting('t.r')::uuid), false);
select set_config('t.c1', pg_temp.corr(1, 101, 963, current_setting('t.r')::uuid, format('{"reason": "one cut was not done", "lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))), false);
select is(current_setting('t.c1')::jsonb #>> '{totals,gross_minor}', '1200', 'a correction of one of two cuts is for 12.00');
select is((select kind || ' ' || (corrects_receipt_id = current_setting('t.r')::uuid)::text || ' ' || state from public.counter_receipts where id = pg_temp.f(current_setting('t.c1'), 'receipt_id')::uuid), 'correction true finalized', 'it is a new finalized receipt that cites the original');
select is(pg_temp.f(current_setting('t.c1'), 'number') <> pg_temp.f(current_setting('t.f'), 'number'), true, 'with a number of its own');
select is((select md5(frozen::text) from public.counter_receipts where id = current_setting('t.r')::uuid), current_setting('t.before'), 'the original''s frozen document is unchanged');
select is(pg_temp.f(pg_temp.corr(1, 101, 963, current_setting('t.r')::uuid, format('{"reason": "one cut was not done", "lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))), 'number'), pg_temp.f(current_setting('t.c1'), 'number'), 'a lost answer retried under the same request id answers the same correction');
select is((select count(*)::int from public.counter_receipts where corrects_receipt_id = current_setting('t.r')::uuid), 1, 'and makes no second one');
select is(pg_temp.corr(1, 101, 964, current_setting('t.r')::uuid, format('{"lines": [{"corrects_line_id": "%s", "quantity": "2"}]}', current_setting('t.line'))), 'ERR DKT08 {"left": "1", "line": 1, "reason": "beyond_original"}', 'correcting more than the line has left is refused, saying what is left');
select is(pg_temp.corr(1, 101, 965, current_setting('t.r')::uuid, format('{"lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))) like '{%', true, 'the remaining one is corrected');
select is(left(pg_temp.corr(1, 101, 966, current_setting('t.r')::uuid, format('{"lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))), 12), 'ERR DKT08 {"', 'and the line is then fully corrected');
select is(left(pg_temp.corr(1, 101, 967, pg_temp.f(current_setting('t.c1'), 'receipt_id')::uuid, '{"lines": []}'), 9), 'ERR DKT04', 'a correction is not corrected');
select is(pg_temp.corr(1, 101, 968, current_setting('t.r')::uuid, '{"lines": [{"corrects_line_id": "00000000-0000-4000-8000-0000000000ff", "quantity": "1"}]}'), 'ERR DKT08 {"line": 1, "reason": "line_unknown"}', 'a line that is not the original''s is refused');
select is(left(pg_temp.corr(2, 101, 969, current_setting('t.r')::uuid, format('{"lines": [{"corrects_line_id": "%s", "quantity": "1"}]}', current_setting('t.line'))), 9), 'ERR DKN01', 'a member without the right to issue corrects nothing');
select set_config('t.d_it', pg_temp.draft(1, 102, 970, null, null, '{"lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), false);
select is((select count(*)::int from public.counter_receipts where workspace_id = pg_temp.u(102) and state = 'finalized'), 0, 'an unsupported country has no finalized receipt to correct');

select * from finish();
rollback;
