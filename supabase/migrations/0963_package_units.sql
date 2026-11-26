-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4479 -- a packaging unit (a carton, a box, a roll) converts only through an item's own factor, never by ratio. 0961 made each typed
-- packaging name a `count` unit of factor 1/1; `stock_to_inventory`'s same-dimension step then read 1 carton = 1 piece for any item
-- that does not list "carton" in its `item_units`, where before 0961 that was refused. So:
--   * `workspace_units.dimension` takes a seventh value, `package`: a dimension that has no ratio to anything.
--   * the units 0961 made (a unit that is the business's own, 1/1, no UN/ECE code, used as a packaging name by an item, a group or a
--     mapping, and never as an inventory unit) move to `package`; the guard that keeps a used unit's dimension is set aside for
--     this one statement, and only for them.
--   * `stock_to_inventory`, `stock_unit_factor` (0952, patched at an asserted anchor) and `workspace_unit_convert` (0951) skip the
--     `package` dimension: a packaging unit converts through the item's factor, else the unit is refused as before.
--   * `workspace_unit_save_v1` (0951) lets a business make a unit of that dimension.
-- Each patch is skipped when it was already made, and refused when its anchor is not found exactly once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0963: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. the dimension that has no ratio ──────────────────────────────────
alter table public.workspace_units drop constraint if exists workspace_units_dimension_check;
alter table public.workspace_units add constraint workspace_units_dimension_check
  check (dimension in ('count', 'mass', 'volume', 'length', 'area', 'time', 'package'));

-- ── 2. the units 0961 made from packaging names ─────────────────────────
alter table public.workspace_units disable trigger workspace_units_rules;
update public.workspace_units u set dimension = 'package'
 where not u.built_in and u.dimension = 'count' and u.factor_num = 1 and u.factor_den = 1 and u.un_ece_code is null
   and not exists (select 1 from public.services s where s.workspace_id = u.workspace_id and s.inventory_unit = u.code)
   and not exists (select 1 from public.item_groups g where g.workspace_id = u.workspace_id and g.inventory_unit = u.code)
   and (exists (select 1 from public.item_units i where i.workspace_id = u.workspace_id and i.unit = u.code)
        or exists (select 1 from public.item_groups g where g.workspace_id = u.workspace_id and g.default_purchase_unit = u.code)
        or exists (select 1 from public.supplier_item_mappings m where m.workspace_id = u.workspace_id and m.purchase_unit = u.code));
alter table public.workspace_units enable trigger workspace_units_rules;

-- ── 3. nothing converts a package by ratio ──────────────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_to_inventory(uuid, text, numeric)'::regprocedure);
begin
  if position($a$v_from.dimension <> 'package'$a$ in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, 'and v_from.dimension = v_to.dimension then',
      $n$and v_from.dimension = v_to.dimension and v_from.dimension <> 'package' then$n$, 'the same-dimension step of stock_to_inventory');
    execute v_def;
  end if;
end
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_unit_factor(uuid, text)'::regprocedure);
begin
  if position($a$v_from.dimension <> 'package'$a$ in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, 'and v_from.dimension = v_to.dimension then',
      $n$and v_from.dimension = v_to.dimension and v_from.dimension <> 'package' then$n$, 'the same-dimension step of stock_unit_factor');
    execute v_def;
  end if;
end
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.workspace_unit_convert(uuid, text, text, text)'::regprocedure);
begin
  if position($a$'package'$a$ in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, 'if v_from.dimension <> v_to.dimension then',
      $n$if v_from.dimension <> v_to.dimension or v_from.dimension = 'package' then$n$, 'the dimension check of workspace_unit_convert');
    execute v_def;
  end if;
end
$patch$;

-- ── 4. a business may make a unit of that dimension ─────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.workspace_unit_save_v1(uuid, uuid, jsonb)'::regprocedure);
begin
  if position($a$'time', 'package'$a$ in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, $o$v_dim not in ('count', 'mass', 'volume', 'length', 'area', 'time')$o$,
      $n$v_dim not in ('count', 'mass', 'volume', 'length', 'area', 'time', 'package')$n$, 'the dimensions of workspace_unit_save_v1');
    execute v_def;
  end if;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(963);
