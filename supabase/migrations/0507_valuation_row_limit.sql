-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0507 (#2576) -- the most rows one batch of the accountant's valuations may
-- carry is a setting of the space, not a number in the function.
--
--   assets.valuation_max_rows   100..5000 rows, workspace scope, default 2000
--       (what 0500 hard-coded). `stage_asset_valuations_v1` reads it; a file
--       over the limit is refused whole, never cut.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('assets.valuation_max_rows', 'int', '2000'::jsonb, 100, 5000, 'rows', 'billing', array['workspace'], 'manageBilling', null, true, null, 'stage_asset_valuations_v1 (0507)', 'The most rows one batch of the accountant''s valuations may carry, one row per asset. A larger file is split by the person who imports it; the file is refused as a whole, never cut.')
on conflict (key) do nothing;
-- END GENERATED SEED

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void language plpgsql as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0507: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

select pg_temp.patch_function(
  'public.stage_asset_valuations_v1(uuid, uuid, jsonb, jsonb)'::regprocedure,
  array[
    $a$  if jsonb_array_length(p_rows) not between 1 and 2000 then
    raise exception 'a batch has between 1 and 2000 rows';
  end if;$a$],
  array[
    $a$  if jsonb_array_length(p_rows) not between 1
       and coalesce((public.setting_value(p_workspace_id, 'assets.valuation_max_rows') #>> '{}')::int, 2000) then
    raise exception 'a batch has between 1 and % rows',
      coalesce((public.setting_value(p_workspace_id, 'assets.valuation_max_rows') #>> '{}')::int, 2000);
  end if;$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(507);
