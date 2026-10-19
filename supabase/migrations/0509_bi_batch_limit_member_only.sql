-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0509 (#2578) -- the batch size limit of 0508 is read for a member of the
-- workspace only. A caller who is not one is answered by the registry default
-- (60), exactly as before 0508: the refusal of the whole batch for a foreign
-- or unauthorised caller keeps its text, and a stranger learns nothing about
-- the space's own setting.

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void language plpgsql as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0509: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;

-- The limit of a member's space; the registry default for anyone else. A
-- plain function, because a CASE with THEN cannot sit inside the IF of the
-- batch function.
create or replace function public.bi_batch_limit(p_workspace_id uuid)
returns int language sql stable security definer set search_path = public as $fn$
  select case when public.is_member_of(p_workspace_id)
              then coalesce((public.setting_value(p_workspace_id, 'bi.batch_max_requests') #>> '{}')::int, 60)
              else 60 end;
$fn$;
revoke execute on function public.bi_batch_limit(uuid) from public, anon;
grant execute on function public.bi_batch_limit(uuid) to authenticated;

select pg_temp.patch_function(
  'public.bi_query_batch_v1(uuid, jsonb)'::regprocedure,
  array[
    $a$     or jsonb_array_length(p_requests) not between 1
        and coalesce((public.setting_value(p_workspace_id, 'bi.batch_max_requests') #>> '{}')::int, 60) then
    raise exception 'a batch has between 1 and % requests',
      coalesce((public.setting_value(p_workspace_id, 'bi.batch_max_requests') #>> '{}')::int, 60)
      using errcode = '22023';$a$],
  array[
    $a$     or jsonb_array_length(p_requests) not between 1 and public.bi_batch_limit(p_workspace_id) then
    raise exception 'a batch has between 1 and % requests', public.bi_batch_limit(p_workspace_id)
      using errcode = '22023';$a$]);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(509);
