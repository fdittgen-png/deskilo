-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (one function patched at two asserted anchors; no table, no signature)
--
-- #4435 (G20, fourth of four files) -- how an item is traced is a choice every item offers: not traced (`none`, quantity only,
-- moved with its units), by batch (`lot`, with an expiry date where set: `expiry`) or by piece (`serial`, a tag per piece).
-- Until now the item save (`save_stock_item_v1`, 0836) refused `serial`, so a piece-tracked item could not be made by the
-- editor. It accepts it now when the feature `stockTags` is on (else DKG11 with the reason `tags_off`), and an item saved by
-- piece carries the tag mode `per_unit` that the pieces path (0887) asks for. The rule against changing the choice of an item
-- that has movements (DKG08) is unchanged.
-- restates 0836 (the item save), by anchored patch.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    perform public.refuse('DKG11', jsonb_build_object('field', p_what, 'reason', 'anchor_missing'), '0931: anchor not found exactly once');
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.save_stock_item_v1(uuid, uuid, integer, uuid, jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    E'  if v_tracking not in (''none'', ''lot'', ''expiry'') then\n    perform public.stock_config_refuse(''tracking'', ''tracking_unsupported'');\n  end if;\n',
    E'  if v_tracking not in (''none'', ''lot'', ''expiry'', ''serial'') then\n    perform public.stock_config_refuse(''tracking'', ''tracking_unsupported'');\n  end if;\n' ||
    E'  if v_tracking = ''serial'' and not public.feature_effective(p_workspace_id, ''stockTags'') then\n    perform public.stock_config_refuse(''tracking'', ''tags_off'');\n  end if;\n',
    'the tracking check');
  v_def := pg_temp.anchor_once(v_def,
    E'inventory_unit = v_inventory, tracking = v_tracking, shelf_life_days = v_shelf,\n',
    E'inventory_unit = v_inventory, tracking = v_tracking, shelf_life_days = v_shelf,\n         tag_mode = case when v_tracking = ''serial'' then ''per_unit'' else tag_mode end,\n',
    'the item update');
  execute v_def;
end
$patch$;

select public.set_deskilo_schema_version(931);
