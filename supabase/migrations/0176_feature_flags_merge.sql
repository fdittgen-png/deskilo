-- SPDX-License-Identifier: 0BSD
-- 0176 — #963: a feature toggle writes ONE key, never a snapshot.
--
-- Three screens rewrote workspaces.feature_flags wholesale from their
-- own copy of the row (the Features screen, the NFC screen from the
-- EFFECTIVE set, the settings import from a file). Any copy older than
-- the row put the row back to what the copy remembered: the pilot
-- switched three features on and the third write turned the first two
-- off again. From here on the owner merges through this function; the
-- row keeps every key the write does not name.
create or replace function public.set_feature_flags(p_workspace_id uuid, p_flags jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_key text; v_val jsonb; v_flags jsonb;
begin
  if auth.uid() is null or not public.is_owner_of(p_workspace_id) then
    raise exception 'only an owner changes the features';
  end if;
  if p_flags is null or jsonb_typeof(p_flags) <> 'object' then
    raise exception 'feature flags must be an object';
  end if;
  for v_key, v_val in select * from jsonb_each(p_flags) loop
    if v_key !~ '^[A-Za-z][A-Za-z0-9]{0,63}$' then
      raise exception 'unknown feature key %', v_key;
    end if;
    if jsonb_typeof(v_val) <> 'boolean' then
      raise exception 'feature % must be true or false', v_key;
    end if;
  end loop;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb) || p_flags
   where id = p_workspace_id
   returning feature_flags into v_flags;
  return v_flags;
end $$;
revoke execute on function public.set_feature_flags(uuid, jsonb) from public, anon;
grant execute on function public.set_feature_flags(uuid, jsonb) to authenticated;
