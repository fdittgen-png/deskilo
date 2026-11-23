-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4379 (0889): a delivery is put away piece by piece. An allocation of a put-away carries one tag per unit for an
-- item tagged per unit: exactly the quantity allocated; each tag becomes one piece at the arrival place with the tag
-- bound, in the transaction of the movement. A lost answer replays the same pieces. A missing, a repeated or an
-- already-bound tag is refused with the allocation (and the unit) in the detail. A per-batch item needs no units and
-- refuses them. The over-allocation rule holds. Rolled back.
begin;
select plan(14);

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
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.putaway(p_req int, p_allocs text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.put_away_receipt_v1(%L, %L, %L, %L::jsonb)::text',
    pg_temp.u(101), current_setting('t.receipt')::uuid, pg_temp.u(p_req), p_allocs))
$f$;
create or replace function pg_temp.alloc(p_line int, p_qty int, p_units text default null) returns text language sql as $f$
  select format('{"line_no": %s, "quantity": %s, "location_id": "%s"%s}', p_line, p_qty, pg_temp.loc('MAIN'),
                case when p_units is null then '' else ', "units": ' || p_units end)
$f$;
create or replace function pg_temp.tags(p_from int, p_n int) returns text language sql as $f$
  select '[' || string_agg(format('{"tag": "E28068940000401561D68C%s"}', lpad(to_hex(g), 2, '0')), ', ') || ']' from generate_series(p_from, p_from + p_n - 1) g
$f$;
create or replace function pg_temp.pieces() returns bigint language sql stable as $f$
  select count(*) from public.stock_tagged_units where workspace_id = pg_temp.u(101) and state = 'in_stock'
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'putaway-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Pieces put away', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true, "stockTags": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name) values (pg_temp.u(401), pg_temp.u(101), 'S-1', 'Phone Co');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(301), pg_temp.u(101), 'Phones', 9000, true, null, 'piece', 'serial', true, 'per_unit'),
  (pg_temp.u(302), pg_temp.u(101), 'Cables', 300, true, null, 'piece', 'none', true, 'per_batch');
insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, created_by_member_id)
values (pg_temp.u(501), pg_temp.u(101), 2026, 1, pg_temp.u(401), 'draft', 'EUR', pg_temp.u(201));
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents) values
  (pg_temp.u(101), pg_temp.u(501), 1, pg_temp.u(301), '', 12, 'piece', 5000),
  (pg_temp.u(101), pg_temp.u(501), 2, pg_temp.u(302), '', 5, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where id = pg_temp.u(501);
select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, false);
select pg_temp.run_as(pg_temp.u(1), format($q$select public.record_purchase_order_receipt_v1(%L, %L, %s, current_setting('t.today')::date,
  '[{"line_no": 1, "quantity": 12}, {"line_no": 2, "quantity": 5}]'::jsonb, '', %L)::text$q$,
  pg_temp.u(101), pg_temp.u(501), (select revision from public.purchase_orders where id = pg_temp.u(501)), pg_temp.u(702)));
select set_config('t.receipt', (select id::text from public.purchase_order_receipts where order_id = pg_temp.u(501)), false);
select pg_temp.run_as(pg_temp.u(1), format('select public.stock_tag_bind_v1(%L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(703),
  format('{"code": "E28068940000401561D68CF0", "owner": {"kind": "place", "location_id": "%s"}}', pg_temp.loc('MAIN'))));

-- ── refusals first: nothing is made by a put-away that is refused ──
select is(left(pg_temp.putaway(710, '[' || pg_temp.alloc(1, 3) || ']'), 9), 'ERR DKG25', 'a per-unit item put away with no units is refused (the pieces must be named)');
select is(pg_temp.putaway(711, '[' || pg_temp.alloc(1, 3, pg_temp.tags(1, 2)) || ']'), 'ERR DKG25 {"line": 1, "allocation": 0}', 'two tags for three units are refused, naming the allocation');
select is(pg_temp.putaway(712, '[' || pg_temp.alloc(1, 3, '[{"tag": "E28068940000401561D68C01"}, {"tag": "E28068940000401561D68C02"}, {"tag": "E28068940000401561D68C01"}]') || ']'),
  'ERR DKG26 {"line": 1, "unit": 3, "allocation": 0}', 'a tag repeated in the allocation is refused at its unit (the piece is already named)');
select is(pg_temp.putaway(713, '[' || pg_temp.alloc(1, 1, '[{"tag": "E28068940000401561D68CF0"}]') || ']'),
  'ERR DKG22 {"line": 1, "unit": 1, "allocation": 0}', 'a tag already bound elsewhere in the business is refused at its unit');
select is(left(pg_temp.putaway(714, '[' || pg_temp.alloc(2, 1, pg_temp.tags(20, 1)) || ']'), 9), 'ERR DKG11', 'a per-batch item refuses units');
select is(pg_temp.pieces(), 0::bigint, 'and no piece was made by any of them');

-- ── the put-away that names its pieces ──
select is(pg_temp.putaway(720, '[' || pg_temp.alloc(1, 3, pg_temp.tags(1, 3)) || ']') like '{%', true, 'three phones are put away with three tags');
select is(pg_temp.pieces() || ' ' || (select count(*) from public.stock_tags where workspace_id = pg_temp.u(101) and owner_kind = 'piece' and state = 'active'),
  '3 3', 'each tag is one piece in stock, with the tag bound to it');
select is(pg_temp.putaway(720, '[' || pg_temp.alloc(1, 3, pg_temp.tags(1, 3)) || ']')::jsonb ->> 'replayed', 'true', 'a lost answer retried under the same request id answers the same');
select is(pg_temp.pieces(), 3::bigint, 'and creates no second set of pieces');
select is(pg_temp.putaway(721, '[' || pg_temp.alloc(2, 5) || ']') like '{%', true, 'a per-batch item is put away with no units, as before');
select is(left(pg_temp.putaway(722, '[' || pg_temp.alloc(1, 10, pg_temp.tags(30, 10)) || ']'), 9), 'ERR DKG11', 'more than was delivered is still refused (over-allocated)');
select is(pg_temp.putaway(723, '[' || pg_temp.alloc(1, 9, pg_temp.tags(40, 9)) || ']') like '{%', true, 'the nine left are put away with nine tags');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.stock_pieces_check_v1(%L, %L)::text', pg_temp.u(101), pg_temp.u(301))), '[]', 'the pieces equal what the ledger holds');

select * from finish();
rollback;
