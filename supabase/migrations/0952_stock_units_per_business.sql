-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (two foreign keys re-pointed and five functions patched at asserted anchors; no stored row moves: every business already
-- holds the six units its items use, from 0951)
--
-- #4442 (the stock side) -- a business's own units are the units of its stock. Until now the unit of an item (`services.
-- inventory_unit`) and of an item group (`item_groups.inventory_unit`) was bound by a foreign key to `stock_units` (0747),
-- the installation-wide list of six, and every conversion read that list. They now read `workspace_units` (0951), the
-- business's own, so a custom unit (a cable drum of 50 m) can be the unit an item is counted in, and a built-in behaves
-- exactly as it did.
--
--   * `services_inventory_unit_fkey` and `item_groups_inventory_unit_fkey` become composite keys on (workspace_id,
--     inventory_unit) -> `workspace_units(workspace_id, code)`: a unit is the business's own, never another's.
--   * `stock_to_inventory` and `stock_unit_factor` (the one conversion every caller uses; 0747, 0836, 0930), `save_stock_item_v1`
--     (0836), `item_apply_stored` and `item_group_check_value` (0883) read the units of the item's business. An item's own
--     packaging units (`item_units`: a box of 6) are unchanged; a packaging unit may not take the code of any unit of the business
--     (it was: of the six), as `registry_unit`.
--   * `stock_units` stays as it is and is no longer read: nothing is dropped.
--
-- patches 0747/0836/0930 (stock_to_inventory, stock_unit_factor), 0836 (save_stock_item_v1), 0883 (item_apply_stored,
-- item_group_check_value), each at an asserted anchor.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0952: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. the keys ─────────────────────────────────────────────────────────
-- Every business holds its built-ins (0951 seeded them and a trigger gives them to a business made since); said again, so a business
-- created between 0951 and this file is covered, and then checked: an item or a group that holds a unit its business does not have
-- would make the key fail, so it is refused here with the count instead. 0747's foreign key guarantees every code in use is one of the
-- six of `stock_units`, all of which 0951 seeds: the count is zero on any installation that applied the files in order.
select public.workspace_units_seed(w.id) from public.workspaces w;
do $orphans$
declare
  v_orphans integer;
begin
  select (select count(*) from public.services s
           where s.workspace_id is not null and s.inventory_unit is not null
             and not exists (select 1 from public.workspace_units u where u.workspace_id = s.workspace_id and u.code = s.inventory_unit))
       + (select count(*) from public.item_groups g
           where g.workspace_id is not null and g.inventory_unit is not null
             and not exists (select 1 from public.workspace_units u where u.workspace_id = g.workspace_id and u.code = g.inventory_unit))
    into v_orphans;
  if v_orphans > 0 then
    raise exception '0952: % items or groups hold a unit their business does not have', v_orphans using errcode = 'P0001';
  end if;
end
$orphans$;

alter table public.services drop constraint services_inventory_unit_fkey;
alter table public.services add constraint services_inventory_unit_fkey
  foreign key (workspace_id, inventory_unit) references public.workspace_units (workspace_id, code);
alter table public.item_groups drop constraint item_groups_inventory_unit_fkey;
alter table public.item_groups add constraint item_groups_inventory_unit_fkey
  foreign key (workspace_id, inventory_unit) references public.workspace_units (workspace_id, code);

-- ── 2. the conversions read the item's business ─────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_to_inventory(uuid, text, numeric)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def, E'  v_inventory text;\n', E'  v_inventory text;\n  v_ws uuid;\n', 'the declarations of stock_to_inventory');
  v_def := pg_temp.anchor_once(v_def, 'v_from public.stock_units;', 'v_from public.workspace_units;', 'v_from of stock_to_inventory');
  v_def := pg_temp.anchor_once(v_def, 'v_to public.stock_units;', 'v_to public.workspace_units;', 'v_to of stock_to_inventory');
  v_def := pg_temp.anchor_once(v_def, 'select inventory_unit into v_inventory from public.services where id = p_item_id;',
    'select inventory_unit, workspace_id into v_inventory, v_ws from public.services where id = p_item_id;', 'the item of stock_to_inventory');
  v_def := pg_temp.anchor_once(v_def, 'select * into v_from from public.stock_units where code = p_unit;',
    'select * into v_from from public.workspace_units where workspace_id = v_ws and code = p_unit;', 'the from unit of stock_to_inventory');
  v_def := pg_temp.anchor_once(v_def, 'select * into v_to from public.stock_units where code = v_inventory;',
    'select * into v_to from public.workspace_units where workspace_id = v_ws and code = v_inventory;', 'the to unit of stock_to_inventory');
  execute v_def;
end
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_unit_factor(uuid, text)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def, E'  v_inventory text;\n', E'  v_inventory text;\n  v_ws uuid;\n', 'the declarations of stock_unit_factor');
  v_def := pg_temp.anchor_once(v_def, 'v_from public.stock_units;', 'v_from public.workspace_units;', 'v_from of stock_unit_factor');
  v_def := pg_temp.anchor_once(v_def, 'v_to public.stock_units;', 'v_to public.workspace_units;', 'v_to of stock_unit_factor');
  v_def := pg_temp.anchor_once(v_def, 'select inventory_unit into v_inventory from public.services where id = p_item_id;',
    'select inventory_unit, workspace_id into v_inventory, v_ws from public.services where id = p_item_id;', 'the item of stock_unit_factor');
  v_def := pg_temp.anchor_once(v_def, 'select * into v_from from public.stock_units where code = p_unit;',
    'select * into v_from from public.workspace_units where workspace_id = v_ws and code = p_unit;', 'the from unit of stock_unit_factor');
  v_def := pg_temp.anchor_once(v_def, 'select * into v_to from public.stock_units where code = v_inventory;',
    'select * into v_to from public.workspace_units where workspace_id = v_ws and code = v_inventory;', 'the to unit of stock_unit_factor');
  execute v_def;
end
$patch$;

-- ── 3. saving an item reads the business's own units ────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.save_stock_item_v1(uuid, uuid, integer, uuid, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def, 'if not exists (select 1 from public.stock_units where code = v_inventory) then',
    'if not exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = v_inventory) then', 'the unit of an item');
  v_def := pg_temp.anchor_once(v_def, 'select dimension into v_dim_old from public.stock_units where code = v_item.inventory_unit;',
    'select dimension into v_dim_old from public.workspace_units where workspace_id = p_workspace_id and code = v_item.inventory_unit;', 'the old dimension');
  v_def := pg_temp.anchor_once(v_def, 'select dimension into v_dim_new from public.stock_units where code = v_inventory;',
    'select dimension into v_dim_new from public.workspace_units where workspace_id = p_workspace_id and code = v_inventory;', 'the new dimension');
  v_def := pg_temp.anchor_once(v_def, 'exists (select 1 from public.stock_units where code = v_unit)',
    'exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = v_unit)', 'the packaging unit that takes a registry code');
  execute v_def;
end
$patch$;

-- ── 4. the item groups read the business's own units ────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.item_apply_stored(uuid, text, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def, 'select dimension into v_dim_old from public.stock_units where code = s.inventory_unit;',
    'select dimension into v_dim_old from public.workspace_units where workspace_id = s.workspace_id and code = s.inventory_unit;', 'the old dimension of a stored value');
  v_def := pg_temp.anchor_once(v_def, 'select dimension into v_dim_new from public.stock_units where code = v_text;',
    'select dimension into v_dim_new from public.workspace_units where workspace_id = s.workspace_id and code = v_text;', 'the new dimension of a stored value');
  execute v_def;
end
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.item_group_check_value(uuid, text, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def, 'select 1 from public.stock_units u where u.code = p_value #>> ''{}''',
    'select 1 from public.workspace_units u where u.workspace_id = p_workspace_id and u.code = p_value #>> ''{}''', 'the unit of a group value');
  execute v_def;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(952);
