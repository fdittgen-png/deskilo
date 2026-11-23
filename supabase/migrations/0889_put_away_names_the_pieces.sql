-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (three functions patched at asserted anchors; nothing stored changes)
--
-- #4379 -- a delivery is put away piece by piece. G13 (0887) creates the pieces of an item tagged piece by piece
-- through the one stock path, `stock_pieces_apply`; the put-away of a delivery (`stock_put_away_apply`, 0840) records
-- its own movements and passed no units, so such an item could only be received by a generic move.
--
--   * An allocation of the put-away may carry `units`, one tag (or piece) per unit: for an item whose tag mode is
--     per unit, exactly the quantity allocated, in inventory units. They go to `stock_pieces_apply`, which makes one
--     piece per unit at the arrival place with its tag bound, in the same transaction as the movement (the put-away
--     already goes through `stock_apply_lines`, which calls it for every line that names units). The refusals are
--     those of G13 (DKG25 pieces not named, DKG26, DKG22, DKG23), now with the allocation and, for a tag, the unit
--     in the detail: {"allocation": 0, "unit": 2}.
--   * A per-batch (or untagged) item is unchanged: no units, and units on it are refused (units_not_tracked).
--   * The request id replays as it does: `put_away_receipt_v1` answers the recorded result for the same id, so the
--     same pieces, never a second set. The over-allocation and one-delivery-once rules are untouched.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- the number of times p_old occurs in p_def
create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
revoke execute on function pg_temp.occurrences(text, text) from public;

-- ── the pieces of a tagged item name the unit that failed ─────────────────
-- restates 0887
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'  v_new uuid;\n',
    E'  for u in select value from jsonb_array_elements(v_units) loop\n',
    E'or pc.location_id <> p_from or pc.state <> v_expect or v_pid = any (v_ids) then\n        raise exception \'a named piece is not where this movement takes it from\' using errcode = \'DKG26\';',
    E'if v_code is null or v_fk not in (\'supplier\', \'opening\', \'loss\') then\n        raise exception \'a named piece is not where this movement takes it from\' using errcode = \'DKG26\';',
    E'          using errcode = \'DKG22\';',
    E'v_code, v_grace using errcode = \'DKG23\';'];
  v_news text[] := array[
    E'  v_new uuid;\n  v_ix int := 0;\n',
    E'  for u in select value from jsonb_array_elements(v_units) loop\n    v_ix := v_ix + 1;\n',
    E'or pc.location_id <> p_from or pc.state <> v_expect or v_pid = any (v_ids) then\n        raise exception \'a named piece is not where this movement takes it from\' using errcode = \'DKG26\',\n          detail = jsonb_build_object(\'unit\', v_ix)::text;',
    E'if v_code is null or v_fk not in (\'supplier\', \'opening\', \'loss\') then\n        raise exception \'a named piece is not where this movement takes it from\' using errcode = \'DKG26\',\n          detail = jsonb_build_object(\'unit\', v_ix)::text;',
    E'          using errcode = \'DKG22\', detail = jsonb_build_object(\'unit\', v_ix)::text;',
    E'v_code, v_grace using errcode = \'DKG23\', detail = jsonb_build_object(\'unit\', v_ix, \'code\', v_code, \'days\', v_grace)::text;'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0889: anchor % not found exactly once in stock_pieces_apply', k using errcode = 'P0001';
    end if;
    v_next := pg_temp.anchor_replace(v_next, v_olds[k], v_news[k]);
    if v_next is null then raise exception '0889: stock_pieces_apply anchor % did not apply', k using errcode = 'P0001'; end if;
  end loop;
  execute v_next;
end
$patch$;

-- ── the one path says which line a refused piece was on ───────────────────
-- restates 0887
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
  v_old text := E'    perform public.stock_pieces_apply(p_workspace_id, v_item.id, v_var, v_lot, e, v_from.id, v_to.id, p_reason, v_qty);\n';
  v_next text;
begin
  if pg_temp.occurrences(v_def, v_old) <> 1 then
    raise exception '0889: the pieces call of stock_apply_lines is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := replace(v_def, v_old,
    E'    declare\n      v_sqlstate text;\n      v_msg text;\n      v_detail text;\n    begin\n' ||
    E'      perform public.stock_pieces_apply(p_workspace_id, v_item.id, v_var, v_lot, e, v_from.id, v_to.id, p_reason, v_qty);\n' ||
    E'    exception when others then\n' ||
    E'      get stacked diagnostics v_sqlstate = returned_sqlstate, v_msg = message_text, v_detail = pg_exception_detail;\n' ||
    E'      if v_sqlstate in (\'DKG22\', \'DKG23\', \'DKG25\', \'DKG26\') then\n' ||
    E'        raise exception \'%\', v_msg using errcode = v_sqlstate,\n' ||
    E'          detail = (coalesce(nullif(v_detail, \'\')::jsonb, \'{}\'::jsonb) || jsonb_build_object(\'line\', v_no))::text;\n' ||
    E'      end if;\n' ||
    E'      raise;\n' ||
    E'    end;\n');
  execute v_next;
end
$patch$;

-- ── the put-away hands the units of an allocation to the one path ─────────
-- restates 0854
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'\'unit_price_cents\', v_ol.unit_price_cents));',
    E'\'receipt_line_id\', p ->> \'receipt_line_id\', \'lot_group\', p ->> \'key\');\n',
    E'  v_moved := public.stock_apply_lines(p_workspace_id, p_actor, p_command, v_lines, \'receipt\', now(), \'{}\'::jsonb, \'put_away\');\n'];
  v_news text[] := array[
    E'\'unit_price_cents\', v_ol.unit_price_cents, \'units\', e -> \'units\'));',
    E'\'receipt_line_id\', p ->> \'receipt_line_id\', \'lot_group\', p ->> \'key\');\n' ||
    E'    if p ? \'units\' and jsonb_typeof(p -> \'units\') <> \'null\' then\n' ||
    E'      v_line := v_line || jsonb_build_object(\'units\', p -> \'units\');\n' ||
    E'    end if;\n',
    E'  declare\n    v_sqlstate text;\n    v_msg text;\n    v_detail text;\n  begin\n' ||
    E'    v_moved := public.stock_apply_lines(p_workspace_id, p_actor, p_command, v_lines, \'receipt\', now(), \'{}\'::jsonb, \'put_away\');\n' ||
    E'  exception when others then\n' ||
    E'    get stacked diagnostics v_sqlstate = returned_sqlstate, v_msg = message_text, v_detail = pg_exception_detail;\n' ||
    E'    if v_sqlstate in (\'DKG22\', \'DKG23\', \'DKG25\', \'DKG26\') then\n' ||
    E'      raise exception \'%\', v_msg using errcode = v_sqlstate,\n' ||
    E'        detail = (coalesce(nullif(v_detail, \'\')::jsonb, \'{}\'::jsonb)\n' ||
    E'                  || jsonb_build_object(\'allocation\', coalesce((nullif(v_detail, \'\')::jsonb ->> \'line\')::int, 1) - 1))::text;\n' ||
    E'    end if;\n' ||
    E'    raise;\n' ||
    E'  end;\n'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0889: anchor % not found exactly once in stock_put_away_apply', k using errcode = 'P0001';
    end if;
    v_next := pg_temp.anchor_replace(v_next, v_olds[k], v_news[k]);
    if v_next is null then raise exception '0889: stock_put_away_apply anchor % did not apply', k using errcode = 'P0001'; end if;
  end loop;
  execute v_next;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(889);
