-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0437 (#2566) — a flag nobody has chosen resolves as a new workspace
-- would store it.
--
-- feature_raw (0227) answered a key absent from the stored flags with the
-- registry row's `default`, whatever its tier. A new workspace is written
-- `core and defaultOn` for every key (platform features are "asked for,
-- never assumed", #1063), so a platform flag added after a workspace was
-- created and registered with `default: true` switched itself on in that
-- workspace. An absent key now resolves to `default and core`, the same
-- predicate as the client's `unchosenFeatureIsOn`: a core flag follows its
-- default, a platform flag is off. A stored boolean still wins, and an
-- unknown key is still off. feature_effective_in / feature_effective call
-- this function, so every server gate follows.

create or replace function public.feature_raw(p_flags jsonb, p_key text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case
    when jsonb_typeof(coalesce(p_flags, '{}'::jsonb) -> p_key) = 'boolean'
      then (p_flags -> p_key)::boolean
    else coalesce((public.feature_registry() -> p_key ->> 'default')::boolean
                  and (public.feature_registry() -> p_key ->> 'core')::boolean, false)
  end;
$$;

revoke execute on function public.feature_raw(jsonb, text) from public, anon;
grant execute on function public.feature_raw(jsonb, text) to authenticated;

select public.set_deskilo_schema_version(437);
