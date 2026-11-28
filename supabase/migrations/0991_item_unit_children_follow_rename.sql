-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (two foreign keys restated with ON UPDATE CASCADE; tag rows on a unit name no unit of their item has are re-pointed)
--
-- #4499 -- what names an item's unit follows the unit when it is renamed. 0961, as amended, gives a barcode
-- (`item_codes.unit`) and a supplier's article (`supplier_item_mappings.purchase_unit`) keys that follow the rename,
-- and moves a tag bound to the unit (`stock_tags.unit_code`) with it. An installation that applied 0961 before the
-- amendment has the old keys: they are restated here, so a fresh install and an upgraded one are the same.
--
-- Such an installation applied 0961 without a barcode or an article on a typed name (or it would have stopped there),
-- but a tag on one was renamed past: the unit became a code and the tag kept the name. A tag that names no unit of its
-- item is moved to the item's unit whose business unit carries that name as its label (what 0961 made of it); one
-- with no such unit is left as it is and counted in the notice below, and the app reads it as unreadable, never as
-- one piece (#4499, StockCodeResolution).

alter table public.item_codes drop constraint if exists item_codes_item_id_unit_fkey;
alter table public.item_codes add constraint item_codes_item_id_unit_fkey
  foreign key (item_id, unit) references public.item_units (item_id, unit) on update cascade on delete cascade;
alter table public.supplier_item_mappings drop constraint if exists supplier_item_mappings_item_id_purchase_unit_fkey;
alter table public.supplier_item_mappings add constraint supplier_item_mappings_item_id_purchase_unit_fkey
  foreign key (item_id, purchase_unit) references public.item_units (item_id, unit) on update cascade;

do $tags$
declare
  v_moved integer;
  v_left integer;
begin
  update public.stock_tags t set unit_code = m.unit
    from (select distinct on (i.item_id, w.label) i.item_id, w.label, i.unit
            from public.item_units i
            join public.workspace_units w on w.workspace_id = i.workspace_id and w.code = i.unit
           order by i.item_id, w.label, i.unit) m
   where t.owner_kind = 'unit' and t.item_id = m.item_id and m.label = btrim(t.unit_code)
     and not exists (select 1 from public.item_units x where x.item_id = t.item_id and x.unit = t.unit_code);
  get diagnostics v_moved = row_count;
  select count(*) into v_left from public.stock_tags t
   where t.owner_kind = 'unit' and t.state = 'active'
     and not exists (select 1 from public.item_units x where x.item_id = t.item_id and x.unit = t.unit_code);
  raise notice '0991: % unit tags moved to their item''s unit, % still on a unit their item does not have', v_moved, v_left;
end
$tags$;

select public.set_deskilo_schema_version(991);
