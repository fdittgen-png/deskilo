-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4499 -- the goods of archive_seed_0747.sql, carried to 0960 (the last schema before 0961 turns an item's typed unit
-- names into the business's units of measure), with the three rows that name an item's unit by its name: a barcode on
-- the unit, a supplier's article bought in it, and a live tag on it. The unit is a name no unit of the business has
-- ('Box of 6', not a code), so 0961 makes a unit of it and the item's unit holds the new code.
--
-- Applied by scripts/upgrade_equivalence_check.sh AFTER the archive is carried to 0960 and BEFORE 0961..latest run
-- over it; the check then reads that each of the three still names the item's unit, and that the unit is still 6
-- pieces. Fixed ids: the check reads them.
begin;

do $seed$
declare
  ws      uuid := '00000000-0000-4000-8000-0000000a0002';
  i_water uuid := '00000000-0000-4000-8000-0000000a0501';
  s_spring uuid := '00000000-0000-4000-8000-0000000a4499';
begin
  insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, default_purchase, default_sale)
  values (ws, i_water, 'Box of 6', 6, 1, false, false);
  -- a barcode printed on the box
  insert into public.item_codes (workspace_id, item_id, unit, code, kind)
  values (ws, i_water, 'Box of 6', 'WATER-BOX6', 'own');
  -- the supplier sells the water by the box
  insert into public.suppliers (id, workspace_id, supplier_number, name)
  values (s_spring, ws, 'S-4499', 'Spring Co');
  insert into public.supplier_item_mappings (workspace_id, supplier_id, item_id, article_ref, purchase_unit)
  values (ws, s_spring, i_water, 'SPR-6', 'Box of 6');
  -- a tag bound to the box
  insert into public.stock_tags (workspace_id, code, tag_kind, owner_kind, item_id, unit_code)
  values (ws, 'E28011606000020000004499', 'epc', 'unit', i_water, 'Box of 6');
end
$seed$;

commit;
