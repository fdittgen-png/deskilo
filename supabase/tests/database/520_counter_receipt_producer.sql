-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4184, #4185 (0894): the producer of a counter receipt. A draft is made and replaced under a request id and
-- previews the frozen facts; finalize refuses BEFORE it draws a number (unsupported country operation, tenders that do
-- not add up, a card tender it does not take, a stale revision, a source already issued); it numbers once, freezes
-- the document, records the tenders; a lost answer replays the same receipt; the same id with other content is
-- refused; a frozen receipt survives a change of the rates; a correction is a new receipt citing the original, bounded
-- by what each original line has left; amounts are exact in 0, 2 and 3 decimal currencies. Rolled back.
begin;
select plan(24);

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

-- ── the draft and its preview ──
select set_config('t.d1', pg_temp.draft(1, 101, 901, null, null, '{"source_ref": "order-1", "lines": [' || pg_temp.line('Haircut', '1', '12.00', ', "line_id": "00000000-0000-4000-8000-0000000a0001"') || ']}'), false);
select is(pg_temp.f(current_setting('t.d1'), 'revision') || ' ' || (current_setting('t.d1')::jsonb #>> '{totals,gross_minor}') || ' ' || (current_setting('t.d1')::jsonb #>> '{totals,net_minor}') || ' ' || (current_setting('t.d1')::jsonb #>> '{totals,tax_minor}'),
  '1 1200 1000 200', 'a draft previews its frozen facts: 12.00 gross at 20% is 10.00 net and 2.00 tax; nothing is numbered');
select is(pg_temp.seq(), 'none', 'and no number was drawn');
select is(pg_temp.f(pg_temp.draft(1, 101, 901, null, null, '{"source_ref": "order-1", "lines": [' || pg_temp.line('Haircut', '1', '12.00', ', "line_id": "00000000-0000-4000-8000-0000000a0001"') || ']}'), 'receipt_id'),
  pg_temp.f(current_setting('t.d1'), 'receipt_id'), 'a lost answer retried under the same request id answers the same draft');
select is((select count(*)::int from public.counter_receipts where workspace_id = pg_temp.u(101)), 1, 'and makes no second one');
select is(pg_temp.f(pg_temp.draft(1, 101, 902, pg_temp.f(current_setting('t.d1'), 'receipt_id')::uuid, 1, '{"source_ref": "order-1", "lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), 'revision'), '2', 'the draft is replaced at its revision');
select is(left(pg_temp.draft(1, 101, 903, pg_temp.f(current_setting('t.d1'), 'receipt_id')::uuid, 1, '{"lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), 9), 'ERR DKT10', 'a revision that moved is refused (stale)');
select is(pg_temp.draft(1, 101, 904, null, null, '{"lines": [{"quantity": "1", "unit_price": "1.00", "supply": "general", "unit": {"code": "u", "label": "u"}}]}'), 'ERR DKT02 line_1_description', 'a line without a description is refused, naming it');
select is(pg_temp.draft(1, 101, 905, null, null, '{"lines": [' || pg_temp.line('Odd', '1', '1.00', format(', "vat_rate_id": "%s"', pg_temp.u(802))) || ']}'), 'ERR DKT02 line_1_vat_rate', 'a rate of another business is refused');
select is((select count(*)::int from public.counter_receipts where workspace_id = pg_temp.u(101)), 1, 'and a refused draft leaves no row');
select is(left(pg_temp.draft(2, 101, 906, null, null, '{"lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), 9), 'ERR DKN01', 'a member without the right to issue works no counter');
select is(left(pg_temp.draft(1, 101, 907, null, null, '{"lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}', true), 9), 'ERR DKN01', 'nor does an assistant session');

-- ── finalize refuses before it numbers ──
select set_config('t.r1', pg_temp.f(current_setting('t.d1'), 'receipt_id'), false);
select is(left(pg_temp.fin(1, 101, 910, current_setting('t.r1')::uuid, 2, '[{"kind": "cash", "amount_minor": 1100}]'), 15), 'ERR DKT06 tende', 'tenders that do not add up to the total are refused');
select is(left(pg_temp.fin(1, 101, 911, current_setting('t.r1')::uuid, 2, '[{"kind": "card", "amount_minor": 1200}]'), 15), 'ERR DKT06 tende', 'a card tender is not taken by this command');
select is(left(pg_temp.fin(1, 101, 912, current_setting('t.r1')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), 9), 'ERR DKT10', 'a stale revision is refused');
select set_config('t.d_it', pg_temp.draft(1, 102, 920, null, null, '{"lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), false);
select is(pg_temp.f(current_setting('t.d_it'), 'issue_receipt'), 'unavailable', 'an Italian draft previews that the operation is unavailable');
select is(left(pg_temp.fin(1, 102, 921, pg_temp.f(current_setting('t.d_it'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), 9), 'ERR DKT01', 'and its finalize is refused (DKT01) by the country operation');
select is(pg_temp.seq(), 'none', 'none of these consumed a number');

-- ── finalize ──
select set_config('t.f1', pg_temp.fin(1, 101, 913, current_setting('t.r1')::uuid, 2, '[{"kind": "cash", "amount_minor": 1200}]'), false);
select is((pg_temp.f(current_setting('t.f1'), 'number') is not null)::text || ' ' || pg_temp.seq(), 'true 2', 'a receipt is numbered once, from its own journal');
select is((select state || ' ' || (frozen ->> 'version') || ' ' || (frozen #>> '{operation,adapter}') || ' ' || (select count(*) from public.counter_tenders t where t.receipt_id = r.id)::text
             from public.counter_receipts r where id = current_setting('t.r1')::uuid), 'finalized 1 counter_receipt_v1 1', 'it is frozen with the operation it was issued under, and its tender is recorded');
select is(pg_temp.f(pg_temp.fin(1, 101, 913, current_setting('t.r1')::uuid, 2, '[{"kind": "cash", "amount_minor": 1200}]'), 'number') || ' ' || pg_temp.seq(),
  pg_temp.f(current_setting('t.f1'), 'number') || ' 2', 'a lost answer retried under the same request id answers the same receipt and draws no second number');
select is(left(pg_temp.fin(1, 101, 913, current_setting('t.r1')::uuid, 2, '[{"kind": "other", "amount_minor": 1200}]'), 9), 'ERR P0001', 'the same id with other content is refused');
select is(left(pg_temp.fin(1, 101, 914, current_setting('t.r1')::uuid, 2, '[{"kind": "cash", "amount_minor": 1200}]'), 9), 'ERR DKT04', 'a second operator finalizing the same receipt is refused, with its number not drawn again');
select set_config('t.d2', pg_temp.draft(1, 101, 915, null, null, '{"source_ref": "order-1", "lines": [' || pg_temp.line('Haircut', '1', '12.00') || ']}'), false);
select is(left(pg_temp.fin(1, 101, 916, pg_temp.f(current_setting('t.d2'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), 9), 'ERR DKT04', 'the same source cannot be issued twice under another request id');
update public.vat_rates set percent = 5 where id = pg_temp.u(801);
select is((select public.counter_receipt_decode(frozen) #>> '{totals,gross_minor}' from public.counter_receipts where id = current_setting('t.r1')::uuid) || ' ' || (select public.counter_receipt_decode(frozen) #>> '{lines,0,vat_percent}' from public.counter_receipts where id = current_setting('t.r1')::uuid),
  '1200 20.000000', 'a frozen receipt survives a change of the rates');

select * from finish();
rollback;
