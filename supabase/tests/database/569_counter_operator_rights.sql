-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4185: who may finish a counter sale. Two operators finalizing the same draft: the first numbers it, the second is
-- refused (DKL04) without a second number or tender; an operator finalizing at a revision another operator moved is
-- refused (DKL10) and succeeds at the current one. A member who holds only the roster and stock rights works no counter
-- (draft, finalize, correct, tender, refund: DKN01) and cannot give itself a financial right (its own membership and the
-- business's role rights stay as they were). Rolled back.
begin;
select plan(17);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
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
create or replace function pg_temp.draft(p_user int, p_req int, p_receipt uuid, p_rev int, p_desc text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_draft_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_req), p_receipt, p_rev,
    format('{"lines": [{"description": "%s", "quantity": "1", "unit_price": "12.00", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}}]}', p_desc)))
$f$;
create or replace function pg_temp.fin(p_user int, p_req int, p_receipt uuid, p_rev int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(101), pg_temp.u(p_req), p_receipt, p_rev, '[{"kind": "cash", "amount_minor": 1200}]'))
$f$;
create or replace function pg_temp.numbered(p text) returns text language sql immutable as $f$
  select case when p like '{%' then ((p::jsonb ->> 'number') is not null)::text else p end
$f$;
create or replace function pg_temp.seq() returns text language sql stable as $f$
  select coalesce((select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), 'none')
$f$;
create or replace function pg_temp.holds(p_user int, p_permission text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.has_permission(%L, %L)::text', pg_temp.u(101), p_permission))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- 1 and 3 are two operators (admins); 2 holds only the roster and stock rights a member is given here.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'coperator-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counter rights', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true}',
   '{"admin": ["issueInvoices", "viewFinances", "recordOutgoingPayments", "manageServices"], "member": ["viewStock", "manageStock", "countStock", "approveStockAdjustments", "manageReservations", "viewDirectory", "viewCalendar"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value)
values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);

-- ── two operators finalize the same draft ──
select set_config('t.r1', pg_temp.f(pg_temp.draft(1, 901, null, null, 'Haircut'), 'receipt_id'), false);
select set_config('t.f1', pg_temp.fin(3, 911, current_setting('t.r1')::uuid, 1), false);
select is(pg_temp.numbered(current_setting('t.f1')) || ' ' || pg_temp.seq(), 'true 2',
  'the first operator to finalize numbers the sale');
select is(left(pg_temp.fin(1, 912, current_setting('t.r1')::uuid, 1), 9), 'ERR DKL04', 'the second operator finalizing the same draft is refused');
select is(pg_temp.seq(), '2', 'and no second number is drawn');
select is((select count(*)::int from public.counter_tenders where receipt_id = current_setting('t.r1')::uuid), 1, 'nor a second tender recorded');
select is((select state from public.counter_receipts where id = current_setting('t.r1')::uuid), 'finalized', 'the sale stays the first operator''s');

-- ── one operator moves the draft, the other finalizes the revision it saw ──
select set_config('t.r2', pg_temp.f(pg_temp.draft(1, 902, null, null, 'Colour'), 'receipt_id'), false);
select is(pg_temp.f(pg_temp.draft(3, 903, current_setting('t.r2')::uuid, 1, 'Colour and cut'), 'revision'), '2', 'the second operator replaces the draft');
select is(left(pg_temp.fin(1, 913, current_setting('t.r2')::uuid, 1), 9), 'ERR DKL10', 'the first operator''s finalize at the old revision is refused');
select is(pg_temp.seq(), '2', 'without drawing a number');
select set_config('t.f2', pg_temp.fin(1, 914, current_setting('t.r2')::uuid, 2), false);
select is(pg_temp.numbered(current_setting('t.f2')) || ' ' || pg_temp.seq(), 'true 3',
  'at the revision it now sees, it finalizes');

-- ── a member with only roster and stock rights works no counter ──
select set_config('t.r3', pg_temp.f(pg_temp.draft(1, 904, null, null, 'Shave'), 'receipt_id'), false);
select is(left(pg_temp.draft(2, 905, null, null, 'Shave'), 9), 'ERR DKN01', 'it cannot start a sale');
select is(left(pg_temp.fin(2, 915, current_setting('t.r3')::uuid, 1), 9), 'ERR DKN01', 'nor finalize another operator''s draft');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.counter_tender_request_v1(%L, %L, %L, %L, %L)::text',
  pg_temp.u(101), pg_temp.u(916), current_setting('t.r3'), 'card', 1200)), 9), 'ERR DKN01', 'nor ask a card terminal for the amount');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text',
  pg_temp.u(101), pg_temp.u(917), current_setting('t.r1'), '{"reason": "wrong", "lines": []}')), 9), 'ERR DKN01', 'nor correct a finalized sale');
select is(left(pg_temp.run_as(pg_temp.u(2), format('select public.counter_refund_v1(%L, %L, %L, %L::jsonb)::text',
  pg_temp.u(101), pg_temp.u(918), current_setting('t.r1'), '[{"kind": "other", "amount_minor": 100}]')), 9), 'ERR DKN01', 'nor pay a refund');
select is(pg_temp.seq(), '3', 'and none of it drew a number');

-- ── nor can it give itself a financial right ──
select pg_temp.run_as(pg_temp.u(2), format('update public.members set is_admin = true where id = %L', pg_temp.u(202)));
select pg_temp.run_as(pg_temp.u(2), format($q$update public.workspaces set role_permissions = role_permissions || '{"member": ["issueInvoices", "recordOutgoingPayments", "viewFinances"]}' where id = %L$q$, pg_temp.u(101)));
select is((select is_admin::text || ' ' || (role_permissions -> 'member' ? 'issueInvoices')::text from public.members m join public.workspaces w on w.id = m.workspace_id where m.id = pg_temp.u(202)),
  'false false', 'its own membership and the business''s role rights stay as they were');
select is(pg_temp.holds(2, 'issueInvoices') || ' ' || pg_temp.holds(2, 'recordOutgoingPayments') || ' ' || pg_temp.holds(2, 'viewFinances'), 'false false false',
  'so it still holds no financial right');

select * from finish();
rollback;
