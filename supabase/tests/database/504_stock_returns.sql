-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4172 (0865-0867): bounded returns and corrections. A logical return and its lines have their own
-- stable identities, apart from the transport request: the same return sent again answers the recorded
-- result and writes nothing, other content under the same identity is refused; the sum reversed on a
-- movement never exceeds it, whatever the identities; a customer return re-enters the original item and
-- lot at its frozen cost; a supplier return leaves from where the goods are and reduces the on-hand
-- quantity once; a correction chains through the earlier correction's movement; another business's
-- movement, a wrong kind of source, a virtual place, a member without the right, an assistant and the
-- feature off are refused; no money is touched; a reversal is immutable. Rolled back.
begin;
select plan(39);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.place(p_kind text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
-- a move by the owner: request, item, quantity, from, to, reason, links
create or replace function pg_temp.mv(p_req int, p_item int, p_qty text, p_from uuid, p_to uuid, p_reason text, p_links text default '{}', p_lot text default null) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L, null, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_req),
    format('[{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s"%s}]', pg_temp.u(p_item), p_qty, p_from, p_to,
      coalesce(', "lot_id": "' || p_lot || '"', '')), p_reason, p_links))
$f$;
create or replace function pg_temp.mvid(p_req int) returns uuid language sql stable as $f$
  select id from public.stock_movements where request_id = pg_temp.u(p_req) order by line_no, part limit 1
$f$;
-- a return: user, request, return id, kind, lines
create or replace function pg_temp.ret(p_user int, p_req int, p_ret int, p_kind text, p_lines text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(p_ws), pg_temp.u(p_req),
    pg_temp.u(p_ret), p_kind, p_lines), p_delegated)
$f$;
create or replace function pg_temp.line(p_line int, p_src uuid, p_qty text, p_loc uuid default null) returns text language sql as $f$
  select format('{"return_line_id": "%s", "source_movement_id": "%s", "quantity": "%s"%s}', pg_temp.u(p_line), p_src, p_qty,
    coalesce(', "location": "' || p_loc || '"', ''))
$f$;
create or replace function pg_temp.onhand(p_item int, p_loc uuid) returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = p_loc
$f$;
create or replace function pg_temp.nlines(p text) returns int language sql immutable as $f$
  select case when p like '{%' then jsonb_array_length(p::jsonb -> 'lines') else -1 end
$f$;
create or replace function pg_temp.field(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then (p::jsonb -> 'lines' -> 0 ->> k) else p end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ret-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Returns A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "invoicing": true, "stockManagement": true, "stockLots": true, "stockTakeOut": true, "stockReturns": true}',
   '{"member": ["viewStock"], "clerk": ["manageStock"]}'),
  (pg_temp.u(102), 'Returns B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "invoicing": true, "stockManagement": true, "stockReturns": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 300, true, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Beans', 900, true, 'kg', 'lot', true),
  (pg_temp.u(304), pg_temp.u(102), 'Foreign', 100, true, 'piece', 'none', true);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'SHELF-A', 'Shelf A', pg_temp.loc('MAIN'));
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                             member_name, workspace_name, issuer_name, signature, period, kind)
values (pg_temp.u(601), pg_temp.u(101), pg_temp.u(201), pg_temp.u(201), 'R-1', 'Sale', '[]'::jsonb, 3000, 'EUR', 'M', 'W', 'M', 'sig', '2026-01', 'full');

-- 20 mugs received, 10 sold on the invoice
select pg_temp.mv(900, 301, '20', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'receipt');
select pg_temp.mv(901, 301, '10', pg_temp.loc('MAIN'), pg_temp.place('customer'), 'sale', format('{"invoice_id": "%s"}', pg_temp.u(601)));
select set_config('rt.sale', pg_temp.mvid(901)::text, false);
select set_config('rt.recv', pg_temp.mvid(900)::text, false);
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 10::numeric, 'fixture: 10 mugs left on hand after the sale');

-- ── a customer return, bounded by the sale ──
select is(pg_temp.nlines(pg_temp.ret(1, 910, 801, 'customer', '[' || pg_temp.line(701, current_setting('rt.sale')::uuid, '3', pg_temp.loc('MAIN')) || ']')), 1,
  'a return of 3 of the sale is recorded');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 13::numeric, 'the goods are back on hand');
select is(pg_temp.ret(1, 911, 801, 'customer', '[' || pg_temp.line(701, current_setting('rt.sale')::uuid, '3', pg_temp.loc('MAIN')) || ']'),
  pg_temp.ret(1, 910, 801, 'customer', '[' || pg_temp.line(701, current_setting('rt.sale')::uuid, '3', pg_temp.loc('MAIN')) || ']'),
  'the same logical return under a new request id answers the recorded result');
select is((select count(*)::int from public.stock_reversals where source_movement_id = current_setting('rt.sale')::uuid), 1, 'and writes nothing');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 13::numeric, 'and the stock does not change');
select is(pg_temp.ret(1, 912, 801, 'customer', '[' || pg_temp.line(701, current_setting('rt.sale')::uuid, '4', pg_temp.loc('MAIN')) || ']'), 'ERR DKG16',
  'a changed quantity under the finalized identity is refused');
select is(pg_temp.ret(1, 913, 802, 'customer', '[' || pg_temp.line(701, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG16',
  'a line id belongs to one return only');
select is(pg_temp.nlines(pg_temp.ret(1, 914, 802, 'customer', '[' || pg_temp.line(702, current_setting('rt.sale')::uuid, '7', pg_temp.loc('MAIN')) || ']')), 1,
  'a distinct return of the remaining 7 is recorded');
select is(pg_temp.ret(1, 915, 803, 'customer', '[' || pg_temp.line(703, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG17',
  'any quantity beyond the sale is refused');
select is((select sum(quantity) from public.stock_reversals where source_movement_id = current_setting('rt.sale')::uuid), 10::numeric, 'exactly the sale was returned');

-- ── the original lot and its frozen cost ──
select pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_move_v1(%L, %L, %L::jsonb, 'receipt')::text$q$, pg_temp.u(101), pg_temp.u(905),
  format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s", "new_lot": {"code": "L1", "total_cost_minor": 5000}}]', pg_temp.u(302), pg_temp.place('supplier'), pg_temp.loc('MAIN'))));
select set_config('rt.lot', (select lot_id::text from public.stock_movements where request_id = pg_temp.u(905) limit 1), false);
select pg_temp.mv(906, 302, '4', pg_temp.loc('MAIN'), pg_temp.place('customer'), 'sale', format('{"invoice_id": "%s"}', pg_temp.u(601)), current_setting('rt.lot'));
select set_config('rt.sale2', pg_temp.mvid(906)::text, false);
select is(pg_temp.nlines(pg_temp.ret(1, 960, 860, 'customer', '[' || pg_temp.line(760, current_setting('rt.sale2')::uuid, '2', pg_temp.loc('MAIN')) || ']')), 1,
  'a return of a lot-tracked sale is recorded');
select is((select lot_id::text || '/' || unit_cost::numeric(18,2)::text from public.stock_movements m join public.stock_reversals r on r.movement_id = m.id where r.return_line_id = pg_temp.u(760)),
  current_setting('rt.lot') || '/500.00', 'it re-enters the original lot at that lot''s frozen unit cost');
select is((select count(*)::int from public.stock_lots where item_id = pg_temp.u(302)), 1, 'no new lot is made, and the sale row keeps its own cost');

-- ── the places and the sources it accepts ──
select is(pg_temp.ret(1, 916, 804, 'customer', '[' || pg_temp.line(704, current_setting('rt.recv')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG18',
  'a customer return follows a sale, not a receipt');
select is(pg_temp.ret(1, 917, 805, 'supplier', '[' || pg_temp.line(705, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG18',
  'a supplier return follows a receipt, not a sale');
select is(pg_temp.ret(1, 918, 806, 'customer', '[' || pg_temp.line(706, current_setting('rt.sale')::uuid, '1', pg_temp.place('loss')) || ']'), 'ERR DKG05',
  'the goods do not come back to a virtual place');

-- ── a supplier return leaves from where the goods are, once ──
select is(pg_temp.nlines(pg_temp.ret(1, 920, 810, 'supplier', '[' || pg_temp.line(710, current_setting('rt.recv')::uuid, '4', pg_temp.loc('MAIN')) || ']')), 1,
  'a supplier return of 4 of the receipt is recorded');
select is(pg_temp.onhand(301, pg_temp.loc('MAIN')), 16::numeric, 'the on-hand quantity falls by 4, once');
select is(pg_temp.ret(1, 921, 811, 'supplier', '[' || pg_temp.line(711, current_setting('rt.recv')::uuid, '17', pg_temp.loc('MAIN')) || ']'), 'ERR DKG17',
  'more than the receipt still holds is refused');
select is((select count(*)::int from public.outgoing_payments where workspace_id = pg_temp.u(101)), 0, 'no payment, refund or credit is made by a return');
select is(pg_temp.nlines(pg_temp.ret(1, 922, 812, 'supplier', '[' || pg_temp.line(712, current_setting('rt.recv')::uuid, '16', pg_temp.loc('MAIN')) || ']')), 1,
  'the remaining 16 of the receipt can be returned, and not one more');
select is(pg_temp.ret(1, 923, 813, 'supplier', '[' || pg_temp.line(713, current_setting('rt.recv')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG17',
  'the receipt is fully returned');

-- ── a correction chains ──
select pg_temp.mv(902, 301, '10', pg_temp.place('supplier'), pg_temp.loc('MAIN'), 'receipt');
select set_config('rt.recv2', pg_temp.mvid(902)::text, false);
select is(pg_temp.field(pg_temp.ret(1, 931, 821, 'correction', '[' || pg_temp.line(721, current_setting('rt.recv2')::uuid, '2') || ']'), 'remaining'), '8.000000',
  'a correction of the receipt (goods back to the supplier) leaves 8 of it');
select set_config('rt.corr', (select movement_id::text from public.stock_reversals where return_line_id = pg_temp.u(721)), false);
select is((select reason from public.stock_movements where id = current_setting('rt.corr')::uuid), 'correction', 'it is a movement with the reason correction');
select is(pg_temp.nlines(pg_temp.ret(1, 932, 822, 'correction', '[' || pg_temp.line(722, current_setting('rt.corr')::uuid, '2') || ']')), 1,
  'a correction of a correction is allowed, its source being the earlier correction');
select is(pg_temp.ret(1, 933, 823, 'correction', '[' || pg_temp.line(723, current_setting('rt.corr')::uuid, '1') || ']'), 'ERR DKG17',
  'and bounded by it');
select is((select source_movement_id from public.stock_reversals where return_line_id = pg_temp.u(722)), current_setting('rt.corr')::uuid,
  'the chain is explicit: the correction names the correction');

-- ── review fixes: the take-out's own feature, the clock, a missing kind, a date before the source ──
select pg_temp.mv(970, 301, '1', pg_temp.loc('MAIN'), pg_temp.place('loss'), 'loss');
select set_config('rt.loss', pg_temp.mvid(970)::text, false);
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": false}' where id = pg_temp.u(101);
select is(pg_temp.ret(1, 971, 870, 'correction', '[' || pg_temp.line(770, current_setting('rt.loss')::uuid, '1') || ']'), 'ERR DKG01',
  'with taking goods out off, a loss is not reversed by a correction either');
update public.workspaces set feature_flags = feature_flags || '{"stockTakeOut": true}' where id = pg_temp.u(101);
select is(pg_temp.nlines(pg_temp.ret(1, 972, 870, 'correction', '[' || pg_temp.line(770, current_setting('rt.loss')::uuid, '1') || ']')), 1,
  'with it on, the correction is made');
select is(pg_temp.ret(1, 973, 871, null, '[' || pg_temp.line(771, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG07',
  'a return with no kind is refused as malformed');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_return_v1(%L, %L, %L, 'correction', %L::jsonb, %L)::text$q$, pg_temp.u(101), pg_temp.u(974), pg_temp.u(872),
  '[' || pg_temp.line(772, current_setting('rt.recv2')::uuid, '1') || ']', (now() - interval '10 years')::text)), 'ERR DKG07',
  'a reversal dated before the movement it reverses is refused');
select set_config('TimeZone', 'UTC', true);
select set_config('rt.tz1', pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_return_v1(%L, %L, %L, 'correction', %L::jsonb, '2026-06-01 10:00:00+00')::text$q$, pg_temp.u(101), pg_temp.u(975), pg_temp.u(873),
  '[' || pg_temp.line(773, current_setting('rt.recv2')::uuid, '1') || ']')), false);
select set_config('TimeZone', 'Asia/Tokyo', true);
select is(pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_return_v1(%L, %L, %L, 'correction', %L::jsonb, '2026-06-01 10:00:00+00')::text$q$, pg_temp.u(101), pg_temp.u(976), pg_temp.u(873),
  '[' || pg_temp.line(773, current_setting('rt.recv2')::uuid, '1') || ']')), current_setting('rt.tz1'),
  'the same replay under another time zone is the same return, not a changed one');

-- ── the rights, the business and the feature ──
select is(pg_temp.ret(2, 940, 830, 'customer', '[' || pg_temp.line(730, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKN01',
  'a member who only views the stock cannot return');
select is(pg_temp.ret(1, 941, 831, 'customer', '[' || pg_temp.line(731, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']', 101, true), 'ERR DKN01',
  'an assistant''s delegated session cannot');
select is(pg_temp.ret(4, 942, 832, 'customer', '[' || pg_temp.line(732, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN', 101)) || ']', 102), 'ERR DKG04',
  'another business''s movement is not a source');
select is(pg_temp.run_as(pg_temp.u(2), format($q$select public.stock_reversible_v1(%L, array[%L]::uuid[]) -> 0 ->> 'remaining'$q$, pg_temp.u(101), current_setting('rt.sale'))), '0.000000',
  'a member who views the stock reads what remains: nothing of the sale');
select throws_ok(format($q$update public.stock_reversals set quantity = 1 where return_line_id = %L$q$, pg_temp.u(701)), 'DKG08', null, 'a reversal is immutable');
update public.workspaces set feature_flags = feature_flags || '{"stockReturns": false}' where id = pg_temp.u(101);
select is(pg_temp.ret(1, 950, 840, 'customer', '[' || pg_temp.line(740, current_setting('rt.sale')::uuid, '1', pg_temp.loc('MAIN')) || ']'), 'ERR DKG01',
  'with the feature off no return is made');

select * from finish();
rollback;
