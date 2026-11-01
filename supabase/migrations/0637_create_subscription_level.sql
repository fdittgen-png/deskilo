-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3132 (decided in #3012), slice 1 -- one subscription level is added by a
-- command of its own, so an assistant can propose it (the next slice) under
-- the same right the app asks: manageBilling.
--
-- The app writes the whole `workspaces.subscription_levels` document through
-- the delegated update policy (0361) when the billing screen saves. This
-- command does what the screen's "add level" field does -- a percentage that is
-- one of the presets is enabled, any other joins the owner's extra levels --
-- and writes the same column. It runs as its owner, so the column guard
-- (`workspaces_delegated_columns`) does not stand in for the right: the
-- command re-checks manageBilling itself, before it reads anything.
--
-- The bounds of a level are the template field registry's own
-- (workspace.subscription_levels.extra_levels min/max), the presets are the
-- column's default document: neither is written again here.
--
-- Refusals (the errcode is the contract):
--   42501  no right (not signed in, not a member, a member without
--          manageBilling, another workspace's manager, no such workspace)
--   55000  the money functionality is switched off in this space (the screen
--          that hosts the field, /billing, requires the moneyTab feature)
--   22023  a percentage outside the registry's bounds, or none
--   23505  the level is already offered
--   XX000  the registry has no bounds, or the column no preset levels: never
--          read as 'any percentage is allowed'

create or replace function public.create_subscription_level(p_workspace_id uuid, p_percent int)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_min int;
  v_max int;
  v_presets jsonb;
  v_levels jsonb;
  v_enabled jsonb;
  v_extra jsonb;
begin
  if auth.uid() is null or p_workspace_id is null
     or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'only whoever manages billing may add a subscription level' using errcode = '42501';
  end if;
  -- The billing screen sits behind the money functionality (route /billing).
  if not public.feature_effective(p_workspace_id, 'moneyTab') then
    raise exception 'money is switched off in this space' using errcode = '55000';
  end if;

  select (f->>'min')::int, (f->>'max')::int into v_min, v_max
    from jsonb_array_elements(public.template_field_registry()) f
   where f->>'id' = 'workspace.subscription_levels.extra_levels';
  if v_min is null or v_max is null then
    raise exception 'the bounds of a subscription level are not defined' using errcode = 'XX000';
  end if;
  if p_percent is null or p_percent < v_min or p_percent > v_max then
    raise exception 'a subscription level is a percentage from % to %', v_min, v_max using errcode = '22023';
  end if;

  select substring(pg_get_expr(d.adbin, d.adrelid) from '^''(.*)''::jsonb$')::jsonb -> 'enabled_presets'
    into v_presets
    from pg_attrdef d
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
   where d.adrelid = 'public.workspaces'::regclass and a.attname = 'subscription_levels';
  if v_presets is null then
    raise exception 'the preset levels are not defined' using errcode = 'XX000';
  end if;

  select subscription_levels into v_levels from public.workspaces where id = p_workspace_id for update;
  v_enabled := coalesce(v_levels -> 'enabled_presets', '[]'::jsonb);
  v_extra := coalesce(v_levels -> 'extra_levels', '[]'::jsonb);
  if v_enabled @> to_jsonb(p_percent) or v_extra @> to_jsonb(p_percent) then
    raise exception 'this subscription level is already offered' using errcode = '23505';
  end if;

  if v_presets @> to_jsonb(p_percent) then
    select jsonb_agg(x order by (x #>> '{}')::int) into v_enabled
      from jsonb_array_elements(v_enabled || to_jsonb(p_percent)) x;
  else
    select jsonb_agg(x order by (x #>> '{}')::int) into v_extra
      from jsonb_array_elements(v_extra || to_jsonb(p_percent)) x;
  end if;
  v_levels := coalesce(v_levels, '{}'::jsonb)
              || jsonb_build_object('enabled_presets', v_enabled, 'extra_levels', v_extra);

  update public.workspaces set subscription_levels = v_levels where id = p_workspace_id;
  return v_levels;
end;
$fn$;
revoke execute on function public.create_subscription_level(uuid, int) from public, anon;
grant execute on function public.create_subscription_level(uuid, int) to authenticated;

select public.set_deskilo_schema_version(637);
