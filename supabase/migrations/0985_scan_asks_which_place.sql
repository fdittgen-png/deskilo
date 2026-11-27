-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4495 (audit STK-01), second slice -- a scanned code that two places carry is not resolved to the first of them. Place codes are unique
-- only among the places of one parent (0855): "SHOP" can be Site A / Shop and Site B / Shop. `stock_resolve_code_v1` (0886) took whichever row
-- the lookup returned first; now, when a bare code matches more than one place in use, it answers the places and the app asks which one.
--   * the answer keeps `kind` = `place` and `matched_by` = `place_code`, carries no `place`, and lists `places`: each with its id, code,
--     name, kind and full path (`Site B › Shop`); an assistant session (delegated) is given names and paths, never ids, as for one place.
--   * a barcode still names one place (it is unique per business), a code that exactly one place carries is answered as before, and a tag
--     bound to a place is unchanged.
-- Anchored patch of the live `stock_resolve_code_v1`, each anchor asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0985: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.stock_resolve_code_v1(uuid,text)'::regprocedure) into v_def;
  if position('v_places' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, $o$  v_known boolean := false;$o$, $n$  v_known boolean := false;
  v_places jsonb;$n$, 'the declarations');
    v_def := pg_temp.anchor_once(v_def,
      $o$  select * into l from public.stock_locations where workspace_id = p_workspace_id and code = v_code and active and not public.stock_place_is_virtual(id);$o$,
      $n$  -- a code several places carry is not one of them: the places are answered and the app asks which
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'code', p.code, 'name', p.name, 'kind', p.kind,
                                               'path', replace(p.address_path, chr(31), ' › ')) order by p.address_path), '[]'::jsonb)
    into v_places
    from public.stock_locations p
   where p.workspace_id = p_workspace_id and p.code = v_code and p.active and not public.stock_place_is_virtual(p.id);
  if jsonb_array_length(v_places) > 1 then
    return jsonb_build_object('kind', 'place', 'matched_by', 'place_code', 'code', v_code,
      'places', case when v_names then (select jsonb_agg(pl - 'id') from jsonb_array_elements(v_places) pl) else v_places end);
  end if;
  select * into l from public.stock_locations where workspace_id = p_workspace_id and code = v_code and active and not public.stock_place_is_virtual(id);$n$,
      'the place by code');
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(985);
