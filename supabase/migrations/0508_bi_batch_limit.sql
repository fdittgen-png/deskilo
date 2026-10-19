-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0508 (#2578) -- how many figures one batched read may carry is a setting
-- of the space, not a number in the function.
--
--   bi.batch_max_requests   10..200 requests, workspace scope, default 60
--       (what 0505 hard-coded). `bi_query_batch_v1` reads it; a batch over the
--       limit is refused whole, never cut.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('bi.batch_max_requests', 'int', '60'::jsonb, 10, 200, 'requests', 'kpi', array['workspace'], 'manageBilling', null, true, null, 'bi_query_batch_v1 (0508)', 'The most figures one report page may ask for in a single read. A page that needs more is split into several reads; the batch is refused whole, never cut.')
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
      raise exception '0508: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

select pg_temp.patch_function(
  'public.bi_query_batch_v1(uuid, jsonb)'::regprocedure,
  array[
    $a$     or jsonb_array_length(p_requests) not between 1 and 60 then
    raise exception 'a batch has between 1 and 60 requests' using errcode = '22023';$a$],
  array[
    $a$     or jsonb_array_length(p_requests) not between 1
        and coalesce((public.setting_value(p_workspace_id, 'bi.batch_max_requests') #>> '{}')::int, 60) then
    raise exception 'a batch has between 1 and % requests',
      coalesce((public.setting_value(p_workspace_id, 'bi.batch_max_requests') #>> '{}')::int, 60)
      using errcode = '22023';$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(508);
