-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4479 -- a delivery is put away in any unit the item converts from, not only in the unit of its order line. An allocation may name a
-- `unit` (the carton the order was written in, or the pieces counted on the shelf); without one it is in the line's unit, as before.
--   * the unit must convert to the item's inventory unit (`stock_unit_factor`, 0968): else DKG11 `allocations[n].unit`, `unit_unmapped`.
--   * what was entered is frozen with its own unit and factor (`entered_unit`, `factor_num/den`, 0840) and recorded in inventory units.
--   * the over-allocation check and the cost stay in the unit of the ORDER LINE: an allocation of 36 pieces of a line of 3 cartons of 12
--     counts as 3 cartons against the line, and the order price (per carton) is applied to those 3.
-- Anchored patch of the live `stock_put_away_apply` (0840, patched by 0847, 0854 and 0889), each anchor asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0972: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.stock_put_away_apply(uuid,uuid,uuid,uuid,jsonb)'::regprocedure) into v_def;
  if position('v_eunit' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'  v_have numeric;\n',
      E'  v_have numeric;\n  v_eunit text;\n  v_el numeric;\n  v_lnum bigint;\n  v_lden bigint;\n', 'the declarations');
    -- the line's own factor is kept, then the entered unit's factor replaces it
    v_def := pg_temp.anchor_once(v_def,
      E'exception when others then\n      perform public.stock_config_refuse(format(''allocations[%s].line'', i - 1), ''unit_unmapped'');\n    end;',
      E'exception when others then\n      perform public.stock_config_refuse(format(''allocations[%s].line'', i - 1), ''unit_unmapped'');\n    end;\n' ||
      E'    v_lnum := v_fac.num;\n    v_lden := v_fac.den;\n' ||
      E'    v_eunit := coalesce(nullif(btrim(e ->> ''unit''), ''''), v_unit);\n' ||
      E'    if v_eunit <> v_unit then\n' ||
      E'      begin\n' ||
      E'        perform public.stock_to_inventory(v_item.id, v_eunit, 1);\n' ||
      E'        select * into v_fac from public.stock_unit_factor(v_item.id, v_eunit);\n' ||
      E'        if v_fac.num is null then raise exception ''no factor'' using errcode = ''DKG05''; end if;\n' ||
      E'      exception when others then\n' ||
      E'        perform public.stock_config_refuse(format(''allocations[%s].unit'', i - 1), ''unit_unmapped'');\n' ||
      E'      end;\n' ||
      E'    end if;',
      'the unit of the allocation');
    -- the allocations already made count in the unit of the order line
    v_def := pg_temp.anchor_once(v_def,
      'select sum(a.entered_quantity) from public.stock_receipt_allocations a',
      'select sum(case when a.entered_unit = v_unit then a.entered_quantity else a.entered_quantity * a.factor_num / a.factor_den * v_lden / v_lnum end) from public.stock_receipt_allocations a',
      'the allocations made');
    v_def := pg_temp.anchor_once(v_def, 'if v_have + v_entered > v_rl.quantity then',
      E'v_el := case when v_eunit = v_unit then v_entered else v_entered * v_fac.num / v_fac.den * v_lden / v_lnum end;\n' ||
      E'    if round(v_have + v_el, 6) > v_rl.quantity then', 'the over-allocation check');
    v_def := pg_temp.anchor_once(v_def, 'coalesce((v_running ->> v_rl.id::text)::numeric, 0) + v_entered);',
      'coalesce((v_running ->> v_rl.id::text)::numeric, 0) + v_el);', 'the running total');
    v_def := pg_temp.anchor_once(v_def, '''variant_id'', v_var, ''unit'', v_unit, ''entered'', v_entered,',
      '''variant_id'', v_var, ''unit'', v_eunit, ''entered'', v_entered, ''entered_line'', v_el,', 'the plan');
    v_def := pg_temp.anchor_once(v_def, 'sum((x ->> ''entered'')::numeric)', 'sum((x ->> ''entered_line'')::numeric)', 'the cost quantity');
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(972);
