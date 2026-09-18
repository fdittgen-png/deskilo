-- SPDX-License-Identifier: 0BSD
-- risk: transforming
--
-- 0245 (#1329) — a feature change is written against the state it was
-- decided on.
--
-- `set_feature_flags` merges a delta into the row (0176, #963): a caller
-- holding an old copy of the row cannot put the other switches back. What
-- it could not say is whether the DECISION was still valid — a process
-- activation is previewed against the flags as read, and between the
-- preview and the confirmation another owner may have switched a
-- prerequisite off or a dependant on. The delta would still merge, and
-- apply a preview nobody approved.
--
-- So the function takes an optional third argument, `p_expected`: the
-- read-set of the preview, every key whose value the decision rested on,
-- with the value it was read as. Under the row lock — one operation, no
-- SELECT-then-UPDATE window — every expected key is compared with the
-- row through `feature_raw` (0227), which normalizes an absent key to the
-- registry default exactly as the client does. A difference raises
-- SQLSTATE DK409 naming the keys and writes nothing; the client then
-- refetches, recomputes and asks again. A null `p_expected` keeps the old
-- behaviour for every existing caller.
--
-- The two-argument overload is dropped rather than kept beside the new
-- one: PostgREST resolves a two-parameter call to the defaulted argument
-- and two overloads would be ambiguous. Every SQL caller passes named
-- parameters through the client; `supabase/tests/database/14_feature_gates.sql`
-- is the one in-repo SQL call and uses two positional arguments, which
-- the default satisfies.

drop function if exists public.set_feature_flags(uuid, jsonb);

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
  if p_expected is not null then
    if jsonb_typeof(p_expected) <> 'object' then
      raise exception 'expected feature flags must be an object';
    end if;
    for v_key, v_val in select * from jsonb_each(p_expected) loop
      if v_key !~ '^[A-Za-z][A-Za-z0-9]{0,63}$' then
        raise exception 'unknown feature key %', v_key;
      end if;
      if jsonb_typeof(v_val) <> 'boolean' then
        raise exception 'expected feature % must be true or false', v_key;
      end if;
    end loop;
  end if;

  -- The lock is the atomicity: the comparison and the merge happen on the
  -- same row version, and a concurrent writer waits here.
  select coalesce(feature_flags, '{}'::jsonb) into v_current
    from public.workspaces where id = p_workspace_id for update;
  if not found then
    raise exception 'unknown workspace';
  end if;

  if p_expected is not null then
    select coalesce(array_agg(e.key order by e.key), '{}'::text[]) into v_stale
      from jsonb_each(p_expected) e
     where public.feature_raw(v_current, e.key) is distinct from (e.value)::boolean;
    if cardinality(v_stale) > 0 then
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

select public.set_deskilo_schema_version(245);
