-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (0981): a closed period of the books refuses what is dated inside it, at every door that takes a date.
-- A goods movement (the move, the transfer, the take-out) and a payment (its declaration, its approval after the
-- period closed, a payment to a supplier or a member) dated inside a closed period are refused with DKB08 and
-- leave nothing behind; the same dated in the open period, or with no date, is taken; reopening the period with
-- its reason lets the dated one through; the business's own today is never refused, even inside a period closed
-- today; what was dated there BEFORE the period closed stays as it is. Hand-written days: 2024 and 2025 are
-- closed years, the first quarter of 2026 is closed after a payment of 10 March was declared. Rolled back.
begin;
select plan(27);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

-- The answer to a statement run as a person: its value, or ERR, its code and its message.
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare
  v text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate || ' ' || sqlerrm;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

-- The code a statement written as the server is refused with.
create or replace function pg_temp.refusal(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'no refusal';
exception when others then
  return sqlstate;
end
$f$;

create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.on_hand() returns numeric language sql stable as $f$
  select coalesce(sum(b.quantity), 0) from public.stock_balances b
   where b.item_id = pg_temp.u(301) and b.location_id = pg_temp.loc('MAIN')
$f$;
create or replace function pg_temp.line(p_qty numeric, p_from text, p_to text) returns jsonb language sql stable as $f$
  select jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(301), 'quantity', p_qty,
           'from', pg_temp.loc(p_from), 'to', pg_temp.loc(p_to)))
$f$;
-- One goods command as the owner: the move with its reason, the transfer, the take-out.
create or replace function pg_temp.goods(p_fn text, p_request int, p_lines jsonb, p_at timestamptz default null) returns text language sql as $f$
  select left(pg_temp.run_as(pg_temp.u(1), case p_fn
    when 'move' then format('select public.stock_move_v1(%L, %L, %L::jsonb, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_request), p_lines, 'receipt', p_at)
    when 'transfer' then format('select public.stock_transfer_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_request), p_lines, p_at)
    else format('select public.stock_consume_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_request), p_lines, p_at) end), 9)
$f$;
-- A payment the member declares for themselves, dated or not.
create or replace function pg_temp.pay(p_on date, p_period text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(2), format('select public.record_payment(%L, %L, 2000, %L, %L, %L, %L)::text',
    pg_temp.u(101), pg_temp.u(202), 'transfer', 'bank_transfer', p_on, p_period))
$f$;
create or replace function pg_temp.close(p_from date, p_to date) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.close_book_period_v1(%L, %L, %L)::text', pg_temp.u(101), p_from, p_to))
$f$;
create or replace function pg_temp.reopen(p_period text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.reopen_book_period_v1(%L, %L, %L) ->> %L',
    pg_temp.u(101), p_period::jsonb ->> 'id', 'the accountant found an error', 'reopen_reason'))
$f$;
create or replace function pg_temp.out_payment(p_on date) returns text language sql as $f$
  select pg_temp.refusal(format(
    'insert into public.outgoing_payments (workspace_id, payee_kind, payee_member_id, currency, amount_cents, method,
                                           reported_paid_on, state, actor_member_id, request_id)
     values (%L, ''member'', %L, ''EUR'', 1500, ''bank_transfer'', %L, ''reported'', %L, gen_random_uuid())',
    pg_temp.u(101), pg_temp.u(202), p_on, pg_temp.u(201)))
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- A (101): owner 1 and member 2; goods and the books' periods are on.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'closed-period-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Closed periods', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"stockManagement": false, "invoicing": true, "accountingBook": true, "accountingPeriods": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Water', 100, true, 5, 'piece', 'none', true);
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": true, "stockTakeOut": true}' where id = pg_temp.u(101);
insert into public.stock_locations (workspace_id, kind, code, parent_id) values (pg_temp.u(101), 'shelf', 'SHELF-A', pg_temp.loc('MAIN'));

-- ── goods ──
select unalike(pg_temp.goods('move', 501, pg_temp.line(2, 'SUPPLIER', 'MAIN'), timestamptz '2025-06-15 10:00+02'), 'ERR%',
  'with no period closed, a receipt dated last year is taken');
select is(pg_temp.on_hand(), 7.000000::numeric, 'the 5 counted and the 2 received are on hand');
select is(pg_temp.close('2024-01-01', '2024-12-31')::jsonb ->> 'reason', 'owner', 'the owner closes 2024');
select set_config('t.y2025', pg_temp.close('2025-01-01', '2025-12-31'), false);
select is(current_setting('t.y2025')::jsonb ->> 'reason', 'owner', 'and 2025');

select is(pg_temp.goods('move', 502, pg_temp.line(3, 'SUPPLIER', 'MAIN'), timestamptz '2025-06-16 10:00+02'), 'ERR DKB08',
  'a receipt dated inside the closed year is refused');
select is(pg_temp.goods('transfer', 503, pg_temp.line(1, 'MAIN', 'SHELF-A'), timestamptz '2025-06-16 10:00+02'), 'ERR DKB08',
  'so is a transfer dated inside it');
select is(pg_temp.goods('consume', 504, pg_temp.line(1, 'MAIN', 'LOSS'), timestamptz '2024-12-31 23:00+01'), 'ERR DKB08',
  'and a take-out dated on the last evening of a closed year, by the business''s own day');
select is(pg_temp.on_hand()::text || ' ' || (select count(*)::text from public.stock_movements where workspace_id = pg_temp.u(101) and reason <> 'opening'),
  '7.000000 1', 'none of them moved anything: the receipt taken before the year closed stands alone');
select unalike(pg_temp.goods('move', 505, pg_temp.line(3, 'SUPPLIER', 'MAIN'), timestamptz '2026-02-01 10:00+01'), 'ERR%',
  'the same receipt dated in the open period is taken');
select unalike(pg_temp.goods('move', 506, pg_temp.line(1, 'SUPPLIER', 'MAIN')), 'ERR%', 'and so is one with no date');
select is(pg_temp.on_hand(), 11.000000::numeric, 'both are on hand');

-- ── a payment, declared ──
select is(left(pg_temp.pay('2025-03-01', '2025-03'), 9), 'ERR DKB08', 'a payment dated inside the closed year is not declared');
select is((select count(*)::int from public.events where workspace_id = pg_temp.u(101) and type = 'payment'), 0, 'and no declaration is left');
select set_config('t.march', pg_temp.pay('2026-03-10', '2026-03'), false);
select is((select status from public.events where id = current_setting('t.march')::uuid), 'pending', 'one dated in the open period is declared');
select unalike(pg_temp.pay(null, '2026-03'), 'ERR%', 'and so is one with no date');

-- ── a payment, approved after its period closed ──
select set_config('t.q1', pg_temp.close('2026-01-01', '2026-03-31'), false);
select is(current_setting('t.q1')::jsonb ->> 'reason', 'owner', 'the first quarter is closed while the declaration waits');
select is(left(pg_temp.run_as(pg_temp.u(1), format('select public.respond_to_event(%L, true)::text', current_setting('t.march'))), 9), 'ERR DKB08',
  'approving it now would book a payment inside the closed quarter: refused');
select is((select status from public.events where id = current_setting('t.march')::uuid) || ' '
          || (select count(*)::text from public.ledger_entries where event_id = current_setting('t.march')::uuid),
  'pending 0', 'the declaration still waits and nothing was booked');
select is(pg_temp.reopen(current_setting('t.q1')), 'the accountant found an error', 'the owner reopens the quarter, saying why');
select unalike(coalesce(pg_temp.run_as(pg_temp.u(1), format('select public.respond_to_event(%L, true)::text', current_setting('t.march'))), ''), 'ERR%',
  'and the approval goes through');
select is((select occurred_on::text from public.ledger_entries where event_id = current_setting('t.march')::uuid), '2026-03-10',
  'the payment is booked on its day');

-- ── a payment out (a supplier's, a member's reimbursement), written as the server ──
select is(pg_temp.out_payment('2024-06-01'), 'DKB08', 'a payment out dated inside a closed year is refused');
select is(pg_temp.out_payment('2026-02-01'), 'no refusal', 'one dated in the open period is recorded');

-- ── reopening, and the business's own today ──
select is(pg_temp.reopen(current_setting('t.y2025')), 'the accountant found an error', 'the owner reopens 2025');
select unalike(pg_temp.goods('move', 502, pg_temp.line(3, 'SUPPLIER', 'MAIN'), timestamptz '2025-06-16 10:00+02'), 'ERR%',
  'the receipt refused before is taken now, under the same request id');
select is(pg_temp.close(public.workspace_today(pg_temp.u(101)), public.workspace_today(pg_temp.u(101)))::jsonb ->> 'reason', 'owner',
  'a period that ends today can be closed today');
select is(public.book_period_closed(pg_temp.u(101), public.workspace_today(pg_temp.u(101)))::text
          || ' ' || (pg_temp.goods('move', 507, pg_temp.line(1, 'SUPPLIER', 'MAIN')) <> 'ERR DKB08')::text
          || ' ' || (left(pg_temp.pay(null, '2026-03'), 3) <> 'ERR')::text,
  'true true true', 'today is inside a closed period, and a movement and a payment of today are still taken');

select * from finish();
rollback;
