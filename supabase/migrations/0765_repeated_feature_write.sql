-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0765 (#3890) -- a guarded feature write repeated after its answer was lost
-- answers the row, as a repeated settings save has since 0241. The first call
-- committed the switches and its answer never arrived; the second sends the
-- same switches with the read-set of the row as it was, finds it moved by its
-- own first call, and was refused as a conflict (DK409). Now, when the row
-- already holds every value the call writes, the call answers the row and
-- writes nothing. A read-set that moved for any other reason is still a
-- conflict.
--
-- set_feature_flags (0245), restated whole; its refusals carry their codes.
create or replace function public.set_feature_flags(
  p_workspace_id uuid,
  p_flags jsonb,
  p_expected jsonb default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_key text;
  v_val jsonb;
  v_flags jsonb;
  v_current jsonb;
  v_stale text[];
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only an owner changes the features' using errcode = 'DKN01';
  end if;
  if p_flags is null or jsonb_typeof(p_flags) <> 'object' then
    raise exception 'feature flags must be an object' using errcode = '22023';
  end if;
  for v_key, v_val in select * from jsonb_each(p_flags) loop
    if v_key !~ '^[A-Za-z][A-Za-z0-9]{0,63}$' then
      raise exception 'unknown feature key %', v_key using errcode = '22023';
    end if;
    if jsonb_typeof(v_val) <> 'boolean' then
      raise exception 'feature % must be true or false', v_key using errcode = '22023';
    end if;
  end loop;
  if p_expected is not null then
    if jsonb_typeof(p_expected) <> 'object' then
      raise exception 'expected feature flags must be an object' using errcode = '22023';
    end if;
    for v_key, v_val in select * from jsonb_each(p_expected) loop
      if v_key !~ '^[A-Za-z][A-Za-z0-9]{0,63}$' then
        raise exception 'unknown feature key %', v_key using errcode = '22023';
      end if;
      if jsonb_typeof(v_val) <> 'boolean' then
        raise exception 'expected feature % must be true or false', v_key using errcode = '22023';
      end if;
    end loop;
  end if;

  -- The lock is the atomicity: the comparison and the merge happen on the
  -- same row version, and a concurrent writer waits here.
  select coalesce(feature_flags, '{}'::jsonb) into v_current
    from public.workspaces where id = p_workspace_id for update;
  if not found then
    raise exception 'unknown workspace' using errcode = '22023';
  end if;

  if p_expected is not null then
    select coalesce(array_agg(e.key order by e.key), '{}'::text[]) into v_stale
      from jsonb_each(p_expected) e
     where public.feature_raw(v_current, e.key) is distinct from (e.value)::boolean;
    if cardinality(v_stale) > 0 then
      -- #3890 -- the same write again: the row already holds every value it
      -- writes, so its answer is the row, and nothing is written.
      if not exists (select 1 from jsonb_each(p_flags) f
                      where public.feature_raw(v_current, f.key) is distinct from (f.value)::boolean) then
        return v_current;
      end if;
      raise exception using
        errcode = 'DK409',
        message = format('the features changed since they were read: %s',
                         array_to_string(v_stale, ', '));
    end if;
  end if;

  update public.workspaces
     set feature_flags = v_current || p_flags
   where id = p_workspace_id
   returning feature_flags into v_flags;
  return v_flags;
end $$;

revoke execute on function public.set_feature_flags(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.set_feature_flags(uuid, jsonb, jsonb) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(765);
