-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (one function body is patched in place; no row and no table moves)
--
-- 0624 (#3074) -- importing a workspace file brings back the drawn room.
--
-- Schema v5 of the workspace XML carries `<decor kind x y w h turns/>` under a
-- level: the walls, doors, windows, pillars, tables, couches, WCs and kitchens
-- drawn on the plan (rows of plan_images with a kind and no photo). The import
-- replaces the whole plan -- deleting the levels cascades through the plan's
-- own rows, decor included -- so `import_floor_plan_v3` now inserts each
-- level's `decor` entries after its offices. Photos do not travel. The
-- table's own checks refuse an unknown kind, a turn outside 0..3 and a
-- degenerate rect; a malformed entry is refused by name before them.
--
-- An anchored patch: the hosted body and the replayed body wrap lines
-- differently, so every anchor goes through the whitespace-tolerant replace.

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

revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.import_floor_plan_v3(uuid,jsonb,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  v_amenity jsonb;$a$,
    $a$  v_amenity jsonb;
  v_decor jsonb;$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$    end loop;
  end loop;
end;$a$,
    $a$    end loop;

    -- v5 (#3074): the symbols drawn on the level.
    for v_decor in
      select value from jsonb_array_elements(coalesce(v_level->'decor', '[]'::jsonb))
    loop
      if jsonb_typeof(v_decor) <> 'object'
         or jsonb_typeof(v_decor->'kind') <> 'string'
         or jsonb_typeof(v_decor->'x') <> 'number'
         or jsonb_typeof(v_decor->'y') <> 'number'
         or jsonb_typeof(v_decor->'w') <> 'number'
         or jsonb_typeof(v_decor->'h') <> 'number'
         or jsonb_typeof(coalesce(v_decor->'quarter_turns', '0'::jsonb)) <> 'number' then
        raise exception 'malformed plan: bad decor';
      end if;
      insert into public.plan_images (workspace_id, level_id, x, y, w, h, kind, quarter_turns)
      values (p_workspace_id, v_level_id,
              (v_decor->>'x')::int, (v_decor->>'y')::int,
              (v_decor->>'w')::int, (v_decor->>'h')::int,
              v_decor->>'kind', coalesce((v_decor->>'quarter_turns')::smallint, 0));
    end loop;
  end loop;
end;$a$);
  if v_def is null
     or position('v_decor jsonb' in v_def) = 0
     or position('plan_images' in v_def) = 0 then
    raise exception '0624: import_floor_plan_v3 anchor missing';
  end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(624);
