-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #4303 (0854): put-away goes through the one stock path. The put-away of a delivery makes
-- no lot and writes no movement itself: it describes its lots and parts and calls
-- stock_apply_lines, and the only function that inserts a lot is the one path. What a
-- put-away gives (lots with their cost state, balances, allocations, movements) is asserted
-- by 490, unchanged. Rolled back.
begin;
select plan(18);

create or replace function pg_temp.def(p_fn regprocedure) returns text language sql stable as $f$
  select regexp_replace(pg_get_functiondef(p_fn), '\s+', ' ', 'g')
$f$;

select ok(pg_temp.def('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure) like '%public.stock_apply_lines(%',
  'put-away calls the one path');
select ok(pg_temp.def('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure) not like '%insert into public.stock_lots%',
  'put-away makes no lot itself');
select ok(pg_temp.def('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure) not like '%stock_record(%',
  'put-away records no movement itself');
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f' and pg_get_functiondef(p.oid) ilike '%insert into public.stock_lots%'),
  array['stock_apply_lines'], 'the one path is the only function that inserts a lot');
select ok(pg_temp.def('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure) like '%''put_away''%',
  'the one path knows the put-away mode');
select ok(pg_temp.def('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure) like '%cost_state%'
          and pg_temp.def('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure) like '%lot_group%',
  'and makes a lot with a cost state, shared by the parts of one group');
-- the generic door keeps refusing what it refused: a new lot there needs its cost
select is(has_function_privilege('authenticated', 'public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)', 'execute'), false,
  'the one path is not callable by a client');


-- What only put-away says about a line is never taken from a client's line (the generic door).
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-00000000049' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'oneway-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
  ('00000000-0000-4000-8000-000000000a01', 'One way A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000000491', '{"stockManagement": true, "stockTakeOut": true}'),
  ('00000000-0000-4000-8000-000000000a02', 'One way B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000000492',
   '{"services": true, "stockManagement": true, "stockReceiving": true, "purchases": true, "purchaseOrders": true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  ('00000000-0000-4000-8000-000000000b01', '00000000-0000-4000-8000-000000000a01', '00000000-0000-4000-8000-000000000491', true, true, 'active'),
  ('00000000-0000-4000-8000-000000000b02', '00000000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000492', true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  ('00000000-0000-4000-8000-000000000c01', '00000000-0000-4000-8000-000000000a01', 'Water', 100, true, 'piece', 'none', true);
create or replace function pg_temp.generic(p_extra text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-000000000491", "role": "authenticated", "aal": "aal2"}', true);
  set local role authenticated;
  begin
    execute format($q$select public.stock_move_v1(%L, gen_random_uuid(), %L::jsonb, 'receipt')::text$q$, '00000000-0000-4000-8000-000000000a01',
      format('[{"item_id": "00000000-0000-4000-8000-000000000c01", "quantity": "1", "from": "%s", "to": "%s"%s}]',
        (select id from public.stock_locations where workspace_id = '00000000-0000-4000-8000-000000000a01' and kind = 'supplier'),
        (select id from public.stock_locations where workspace_id = '00000000-0000-4000-8000-000000000a01' and kind = 'warehouse'), p_extra)) into v;
  exception when others then get stacked diagnostics d = pg_exception_detail; v := 'ERR ' || sqlstate || coalesce(' ' || d, ''); end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end $f$;
-- the same keys through the typed commands (one-step transfer, take-out)
create or replace function pg_temp.typed(p_fn text, p_extra text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-000000000491", "role": "authenticated", "aal": "aal2"}', true);
  set local role authenticated;
  begin
    execute format($q$select public.%s(%L, gen_random_uuid(), %L::jsonb)::text$q$, p_fn, '00000000-0000-4000-8000-000000000a01',
      format('[{"item_id": "00000000-0000-4000-8000-000000000c01", "quantity": "1", "from": "%s", "to": "%s"%s}]',
        (select id from public.stock_locations where workspace_id = '00000000-0000-4000-8000-000000000a01' and kind = 'warehouse'),
        (select id from public.stock_locations where workspace_id = '00000000-0000-4000-8000-000000000a01' and code = 'SHELF-1'), p_extra)) into v;
  exception when others then get stacked diagnostics d = pg_exception_detail; v := 'ERR ' || sqlstate || coalesce(' ' || d, ''); end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end $f$;
insert into public.stock_locations (workspace_id, kind, code, name, parent_id)
select '00000000-0000-4000-8000-000000000a01', 'shelf', 'SHELF-1', 'Shelf 1', id from public.stock_locations
 where workspace_id = '00000000-0000-4000-8000-000000000a01' and kind = 'warehouse';
-- business B: a delivery recorded, its receipt line is B's
insert into public.suppliers (id, workspace_id, supplier_number, name) values
  ('00000000-0000-4000-8000-000000000e01', '00000000-0000-4000-8000-000000000a02', 'S-1', 'Other Co');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  ('00000000-0000-4000-8000-000000000c02', '00000000-0000-4000-8000-000000000a02', 'Foreign', 100, true, 'piece', 'none', true);
insert into public.purchase_orders (id, workspace_id, year, number, supplier_id, state, currency, created_by_member_id) values
  ('00000000-0000-4000-8000-000000000f01', '00000000-0000-4000-8000-000000000a02', 2026, 1, '00000000-0000-4000-8000-000000000e01', 'draft', 'EUR', '00000000-0000-4000-8000-000000000b02');
insert into public.purchase_order_lines (workspace_id, order_id, line_no, service_id, description, quantity, unit, unit_price_cents) values
  ('00000000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000f01', 1, '00000000-0000-4000-8000-000000000c02', '', 2, 'piece', 100);
update public.purchase_orders set state = 'sent', sent_at = now(), sent_via = 'print' where id = '00000000-0000-4000-8000-000000000f01';
create or replace function pg_temp.record_b() returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', '{"sub": "00000000-0000-4000-8000-000000000492", "role": "authenticated", "aal": "aal2"}', true);
  set local role authenticated;
  begin
    execute format($q$select public.record_purchase_order_receipt_v1(%L, %L, %s, current_date, '[{"line_no": 1, "quantity": 2}]'::jsonb, '', gen_random_uuid())::text$q$,
      '00000000-0000-4000-8000-000000000a02', '00000000-0000-4000-8000-000000000f01',
      (select revision from public.purchase_orders where id = '00000000-0000-4000-8000-000000000f01')) into v;
  exception when others then get stacked diagnostics d = pg_exception_detail; v := 'ERR ' || sqlstate || coalesce(' ' || d, ''); end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end $f$;
select set_config('t.b', pg_temp.record_b(), false);
create or replace function pg_temp.put_away_mode(p_line uuid) returns text language plpgsql as $f$
declare d text;
begin
  perform public.stock_apply_lines('00000000-0000-4000-8000-000000000a01', '00000000-0000-4000-8000-000000000b01', gen_random_uuid(),
    format('[{"item_id": "00000000-0000-4000-8000-000000000c01", "quantity": "1", "from": "%s", "to": "%s", "receipt_line_id": "%s", "new_lot": {"code": "X", "cost_state": "unknown"}}]',
      (select id from public.stock_locations where workspace_id = '00000000-0000-4000-8000-000000000a01' and kind = 'supplier'),
      (select id from public.stock_locations where workspace_id = '00000000-0000-4000-8000-000000000a01' and kind = 'warehouse'), p_line)::jsonb,
    'receipt', now(), '{}'::jsonb, 'put_away');
  return 'ok';
exception when others then get stacked diagnostics d = pg_exception_detail; return sqlstate || coalesce(' ' || d, '');
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;
select is(left(current_setting('t.b'), 2), '{"', 'fixture: business B recorded a delivery: ' || left(current_setting('t.b'), 80));
select is(pg_temp.put_away_mode((select id from public.purchase_order_receipt_lines where workspace_id = '00000000-0000-4000-8000-000000000a02' limit 1)),
  'DKG11 {"field": "lines[0]", "reason": "malformed"}', 'put-away mode with another business''s receipt line is refused');
select is(pg_temp.generic(', "new_lot": {"code": "L", "total_cost_minor": 100, "cost_source": "entered"}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'a client sets no cost source (generic)');
select is(pg_temp.generic(', "new_lot": {"code": "L", "total_cost_minor": 100, "quantity_received": 99}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'nor the whole quantity of a lot (generic)');
select is(pg_temp.typed('stock_transfer_v1', ', "new_lot": {"code": "L", "cost_source": "entered"}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'a cost source through a one-step transfer');
select is(pg_temp.typed('stock_transfer_v1', ', "new_lot": {"code": "L", "quantity_received": 9}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'a lot quantity through a one-step transfer');
select is(pg_temp.typed('stock_consume_v1', ', "new_lot": {"code": "L", "cost_source": "entered"}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'a cost source through a take-out');
select is(pg_temp.typed('stock_consume_v1', ', "new_lot": {"code": "L", "quantity_received": 9}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'a lot quantity through a take-out');
select is(pg_temp.generic(', "receipt_line_id": "00000000-0000-4000-8000-000000000d01"'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}',
  'a client line cannot name a receipt line (of any business)');
select is(pg_temp.generic(', "lot_group": "g"'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}', 'nor a lot group');
select is(pg_temp.generic(', "new_lot": {"code": "L", "total_cost_minor": 100, "cost_state": "unknown"}'), 'ERR DKG11 {"field": "lines[0]", "reason": "malformed"}',
  'nor a lot with a cost state of its own');

select * from finish();
rollback;
