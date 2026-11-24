-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one function patched at two asserted anchors; no table, no signature)
--
-- #4364 (G15) -- a contender is told where the piece went. Two moves of the same tagged piece race: the loser's line
-- used to meet the quantity check first ("not that much on hand", DKG03) and never reached the piece check, so its
-- refusal did not name the piece's new place. The sequential case did (DKG26 with the place). Now, when the quantity
-- check refuses a line that names units, the pieces are checked before that refusal is told: a piece that is no
-- longer there is answered DKG26 with its place, as in the sequential case; when every piece is still there the
-- quantity refusal stands. The check moves nothing: the command is refused whole, as before.
--
--   * the quantity part of a line (the lots taken and the movements written) runs in a block whose handler catches DKG03;
--   * for a line with `units`, the handler asks `stock_pieces_move` (which refuses DKG22/23/25/26 with their detail,
--     the line added as the stock path adds it); whatever it answers, the command is refused and nothing is kept.
--   * restates 0887 (the stock path), as patched by 0889, 0917 and 0922.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0925: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    E'    v_part := 0;\n    if v_lot is null and not v_fv and p_mode not in (''bridge'', ''open'', ''return'') then\n',
    E'    begin -- #4364: the quantity part of the line; a DKG03 here asks the pieces first (handler below)\n' ||
    E'    v_part := 0;\n    if v_lot is null and not v_fv and p_mode not in (''bridge'', ''open'', ''return'') then\n',
    'the start of the quantity part');
  v_def := pg_temp.anchor_once(v_def,
    E'        ''part'', 1, ''item_id'', v_item.id, ''variant_id'', v_var, ''lot_id'', v_lot, ''quantity'', v_qty));\n    end if;\n    declare\n      v_sqlstate text;\n',
    E'        ''part'', 1, ''item_id'', v_item.id, ''variant_id'', v_var, ''lot_id'', v_lot, ''quantity'', v_qty));\n    end if;\n' ||
    E'    exception when sqlstate ''DKG03'' then\n' ||
    E'      -- not that much on hand: a piece that is no longer there is answered first, with its place\n' ||
    E'      if jsonb_typeof(e -> ''units'') = ''array'' then\n' ||
    E'        declare\n' ||
    E'          v_s text;\n' ||
    E'          v_m text;\n' ||
    E'          v_d text;\n' ||
    E'        begin\n' ||
    E'          perform public.stock_pieces_move(p_workspace_id, v_item.id, v_var, v_lot, e, v_from.id, v_to.id, p_reason, v_qty);\n' ||
    E'        exception when others then\n' ||
    E'          get stacked diagnostics v_s = returned_sqlstate, v_m = message_text, v_d = pg_exception_detail;\n' ||
    E'          if v_s in (''DKG22'', ''DKG23'', ''DKG25'', ''DKG26'') then\n' ||
    E'            raise exception ''%'', v_m using errcode = v_s,\n' ||
    E'              detail = (coalesce(nullif(v_d, '''')::jsonb, ''{}''::jsonb) || jsonb_build_object(''line'', v_no))::text;\n' ||
    E'          end if;\n' ||
    E'          raise;\n' ||
    E'        end;\n' ||
    E'      end if;\n' ||
    E'      raise;\n' ||
    E'    end;\n' ||
    E'    declare\n      v_sqlstate text;\n',
    'the end of the quantity part');
  execute v_def;
end
$patch$;

select public.set_deskilo_schema_version(925);
