-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4492 row 6 -- the goods the archive of `archive_seed.sql` holds once the
-- schema stands at migration 0747, the first with a goods ledger (units,
-- places, lots, movements, balances). The populated upgrade proved invoices,
-- postings and payments; it held no stock row, so nothing said what the
-- seventy later stock migrations do to a business that already moved goods:
-- 0837 (variants: the balances' key is rebuilt), 0855 (places), 0951 to 0974
-- (units per business, item units from the master data, packages,
-- conversions, a unit's own price).
--
-- Written the way a business wrote it at 0747: through the move command of
-- that schema, as the owner. Three items, one per case the unit migrations
-- touch:
--
--   * Water, counted in pieces, bought by the carton of 12 (a unit of the
--     item): a shelf count of 5 that opens the ledger, 2 cartons received,
--     10 pieces to a shelf, 3 sold from it.
--   * Wine, kept in litres, sold by the glass of 1/5 litre (a fraction of
--     the inventory unit): 2 litres and 50 centilitres received, 3 glasses
--     sold.
--   * Juice, tracked by lot: two lots at two costs, 5 sold of the first.
--
-- Applied by `scripts/populated_upgrade_check.sh` in its third case
-- (STOCK_AT=0747), AFTER the 0226 archive has been carried to 0747 and BEFORE
-- migrations 0748..latest run over it. Every column here exists at 0747.
-- Fixed ids and fixed instants: the snapshot is keyed by them.
begin;

do $seed$
declare
  ws        uuid := '00000000-0000-4000-8000-0000000a0002';
  u_owner   uuid := '00000000-0000-4000-8000-0000000a0001';
  i_water   uuid := '00000000-0000-4000-8000-0000000a0501';
  i_wine    uuid := '00000000-0000-4000-8000-0000000a0502';
  i_juice   uuid := '00000000-0000-4000-8000-0000000a0503';
  l_main uuid; l_shelf uuid; l_supplier uuid; l_customer uuid;
  v_lot_a uuid;
  v_claims text := jsonb_build_object('sub', u_owner, 'role', 'authenticated')::text;
begin
  insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
    (i_water, ws, 'Water', 100, true, 5, 'piece', 'none', true),
    (i_wine, ws, 'Wine', 500, true, null, 'l', 'none', true),
    (i_juice, ws, 'Juice', 300, true, null, 'piece', 'lot', true);
  insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, default_purchase, default_sale) values
    (ws, i_water, 'carton', 12, 1, true, false),
    (ws, i_wine, 'glass', 1, 5, false, true);

  -- The feature is switched on: the business's places, and the shelf count
  -- of Water becomes the opening of its ledger.
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"stockManagement": true}'::jsonb
   where id = ws;
  select id into strict l_main from public.stock_locations where workspace_id = ws and code = 'MAIN';
  select id into strict l_supplier from public.stock_locations where workspace_id = ws and code = 'SUPPLIER';
  select id into strict l_customer from public.stock_locations where workspace_id = ws and code = 'CUSTOMER';
  insert into public.stock_locations (workspace_id, kind, code, parent_id)
  values (ws, 'shelf', 'SHELF-A', l_main) returning id into l_shelf;

  perform set_config('request.jwt.claims', v_claims, true);
  set local role authenticated;
  -- Water: 2 cartons of 12 in, 10 pieces to the shelf, 3 sold from it.
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0601', jsonb_build_array(jsonb_build_object(
    'item_id', i_water, 'quantity', 2, 'from', l_supplier, 'to', l_main, 'unit', 'carton')),
    'receipt', '2026-01-05 09:00:00+00');
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0602', jsonb_build_array(jsonb_build_object(
    'item_id', i_water, 'quantity', 10, 'from', l_main, 'to', l_shelf)),
    'transfer', '2026-01-06 09:00:00+00');
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0603', jsonb_build_array(jsonb_build_object(
    'item_id', i_water, 'quantity', 3, 'from', l_shelf, 'to', l_customer)),
    'sale', '2026-01-07 09:00:00+00');
  -- Wine: 2 litres in, 3 glasses of a fifth of a litre out, 50 centilitres in.
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0604', jsonb_build_array(jsonb_build_object(
    'item_id', i_wine, 'quantity', 2, 'from', l_supplier, 'to', l_main, 'unit', 'l')),
    'receipt', '2026-01-08 09:00:00+00');
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0605', jsonb_build_array(jsonb_build_object(
    'item_id', i_wine, 'quantity', 3, 'from', l_main, 'to', l_customer, 'unit', 'glass')),
    'sale', '2026-01-09 09:00:00+00');
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0606', jsonb_build_array(jsonb_build_object(
    'item_id', i_wine, 'quantity', 50, 'from', l_supplier, 'to', l_main, 'unit', 'cl')),
    'receipt', '2026-01-10 09:00:00+00');
  -- Juice: two lots at two costs.
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0607', jsonb_build_array(jsonb_build_object(
    'item_id', i_juice, 'quantity', 10, 'from', l_supplier, 'to', l_main,
    'new_lot', jsonb_build_object('code', 'A', 'total_cost_minor', 1000))),
    'receipt', '2026-01-11 09:00:00+00');
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0608', jsonb_build_array(jsonb_build_object(
    'item_id', i_juice, 'quantity', 10, 'from', l_supplier, 'to', l_main,
    'new_lot', jsonb_build_object('code', 'B', 'total_cost_minor', 1500))),
    'receipt', '2026-02-11 09:00:00+00');
  reset role;
  select id into strict v_lot_a from public.stock_lots where workspace_id = ws and item_id = i_juice and lot_code = 'A';
  perform set_config('request.jwt.claims', v_claims, true);
  set local role authenticated;
  perform public.stock_move_v1(ws, '00000000-0000-4000-8000-0000000a0609', jsonb_build_array(jsonb_build_object(
    'item_id', i_juice, 'quantity', 5, 'from', l_main, 'to', l_customer, 'lot_id', v_lot_a)),
    'sale', '2026-02-12 09:00:00+00');
  reset role;
  perform set_config('request.jwt.claims', '', true);
end
$seed$;

commit;
