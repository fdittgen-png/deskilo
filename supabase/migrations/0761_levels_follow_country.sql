-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0761 (#3886) -- the server's setup levels follow the country, as the app's
-- currentSetupLevels and planSetupLevels do (#3300). A feature the
-- workspace's country does not offer (feature_available_in, 0486) never
-- holds a level back, and a plan neither switches it on nor off: its stored
-- switch is kept as it is. The setup status, the level list, the preview and
-- the apply of the assistant read the same levels as the app.
--
-- setup_current_levels takes the country beside the stored features; its
-- one-argument form (0555) is dropped once its three callers pass the
-- country.

-- Each process's level as the stored features say: the highest level whose
-- offered features, and those of every level below it, are all on.
create or replace function public.setup_current_levels(p_flags jsonb, p_country text)
returns jsonb language sql stable set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object('process', p->>'process', 'level',
    coalesce((select l->>'level'
                from jsonb_array_elements(p->'levels') with ordinality x(l, i)
               where not exists (
                 select 1
                   from jsonb_array_elements(p->'levels') with ordinality y(below, j)
                   cross join lateral jsonb_array_elements_text(below->'features') f
                  where j <= i and not public.feature_raw(p_flags, f)
                    and public.feature_available_in(p_country, f))
               order by i desc limit 1),
             p->'levels'->0->>'level')) order by pi), '[]'::jsonb)
    from jsonb_array_elements(public.setup_level_catalogue()->'processes') with ordinality q(p, pi);
$fn$;
revoke execute on function public.setup_current_levels(jsonb, text) from public, anon, authenticated;

-- What choosing levels changes (0555), restated whole: the levels are read
-- with the country, and a feature the country does not offer is neither
-- switched on nor off.
create or replace function public.setup_levels_plan(p_workspace_id uuid, p_args jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_cat jsonb := public.setup_level_catalogue();
  v_flags jsonb;
  v_country text;
  v_current jsonb;
  v_chosen jsonb;
  v_preset jsonb;
  v_changes jsonb := '[]'::jsonb;
  v_gaps jsonb := '[]'::jsonb;
  v_on text[] := '{}';
  v_off text[] := '{}';
  v_switch_on text[];
  v_switch_off text[];
  v_process text;
  v_changed boolean;
  v_rank int;
  p jsonb;
  l jsonb;
  i int;
begin
  perform public.mcp_setup_arguments(p_args, public.setup_level_arguments());
  select coalesce(feature_flags, '{}'::jsonb), country_code into v_flags, v_country
    from public.workspaces where id = p_workspace_id;
  if not found then
    raise exception 'unknown workspace' using errcode = '22023';
  end if;
  select coalesce(jsonb_object_agg(e->>'process', e->>'level'), '{}'::jsonb) into v_current
    from jsonb_array_elements(public.setup_current_levels(v_flags, v_country)) e;
  v_chosen := v_current;
  if p_args ? 'preset' then
    select pr->'levels' into v_preset from jsonb_array_elements(v_cat->'presets') pr
     where pr->>'preset' = p_args->>'preset';
    if v_preset is null then
      raise exception 'unknown preset %', p_args->>'preset' using errcode = '22023';
    end if;
    select v_chosen || coalesce(jsonb_object_agg(e->>'process', e->>'level'), '{}'::jsonb) into v_chosen
      from jsonb_array_elements(v_preset) e;
  end if;
  for p in select x from jsonb_array_elements(v_cat->'processes') x loop
    v_process := p->>'process';
    if p_args ? v_process then
      if public.setup_level_rank(v_process, p_args->>v_process) < 0 then
        raise exception 'unknown level % of %', p_args->>v_process, v_process using errcode = '22023';
      end if;
      v_chosen := v_chosen || jsonb_build_object(v_process, p_args->>v_process);
    end if;
  end loop;
  for p in select x from jsonb_array_elements(v_cat->'processes') x loop
    v_process := p->>'process';
    v_rank := public.setup_level_rank(v_process, v_chosen->>v_process);
    v_changed := v_chosen->>v_process is distinct from v_current->>v_process;
    if v_changed then
      v_changes := v_changes || jsonb_build_array(jsonb_build_object(
        'process', v_process, 'from', v_current->>v_process, 'to', v_chosen->>v_process));
    end if;
    for l, i in select y.l, (y.o - 1)::int from jsonb_array_elements(p->'levels') with ordinality y(l, o) loop
      -- a level carries the needs of the levels below it: their features are on too
      if i <= v_rank then
        v_gaps := v_gaps || coalesce((
          select jsonb_agg(jsonb_build_object('process', v_process, 'level', l->>'level', 'needs', n))
            from jsonb_array_elements(l->'needs') n
           where public.setup_level_rank(n->>'process', v_chosen->>(n->>'process'))
                 < public.setup_level_rank(n->>'process', n->>'level')), '[]'::jsonb);
      end if;
      if v_changed then
        if i <= v_rank then
          v_on := v_on || array(select jsonb_array_elements_text(l->'features'));
        else
          v_off := v_off || array(select jsonb_array_elements_text(l->'features'));
        end if;
      end if;
    end loop;
  end loop;
  v_switch_on := array(select f from unnest(v_on) with ordinality u(f, o)
                        where not public.feature_raw(v_flags, f) and public.feature_available_in(v_country, f)
                        group by f order by min(o));
  v_switch_off := array(select f from unnest(v_off) with ordinality u(f, o)
                         where public.feature_raw(v_flags, f) and public.feature_available_in(v_country, f)
                         group by f order by min(o));
  return jsonb_build_object(
    'current', public.setup_current_levels(v_flags, v_country),
    'changes', v_changes,
    'switch_on', to_jsonb(v_switch_on),
    'switch_off', to_jsonb(v_switch_off),
    'gaps', v_gaps,
    'ready_to_apply', jsonb_array_length(v_gaps) = 0 and cardinality(v_switch_on) + cardinality(v_switch_off) > 0,
    -- off wins over on, as in the app's delta
    'flags', coalesce((select jsonb_object_agg(f, true) from unnest(v_switch_on) f), '{}'::jsonb)
             || coalesce((select jsonb_object_agg(f, false) from unnest(v_switch_off) f), '{}'::jsonb),
    'expected', coalesce((select jsonb_object_agg(f, public.feature_raw(v_flags, f))
                            from unnest(v_switch_on || v_switch_off) f), '{}'::jsonb),
    'revision', md5(v_flags::text));
end;
$fn$;
revoke execute on function public.setup_levels_plan(uuid, jsonb) from public, anon, authenticated;

-- The setup status, the level list and the apply (0555), restated whole:
-- they read the levels with the workspace's country.
create or replace function public.mcp_op_get_setup_status(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_refusal jsonb := public.mcp_setup_refusal(c.workspace_id, p_args, array['workspace_id']);
  v_status jsonb;
  v_steps jsonb;
  v_next_milestone text;
  v_next_rank bigint;
  v_next_step text;
begin
  if v_refusal is not null then return v_refusal; end if;
  v_status := public.workspace_setup_status(c.workspace_id);
  -- The first milestone this space has chosen and not reached (the app's
  -- SetupStatus.nextMilestone).
  select m->>'milestone', o into v_next_milestone, v_next_rank
    from jsonb_array_elements(v_status->'milestones') with ordinality x(m, o)
   where (m->>'applies')::boolean and not (m->>'reached')::boolean
   order by o limit 1;
  -- What an assistant may do with each step: a step with a credential only
  -- in the app; a step only the person can tell is done marked done; an
  -- optional one set aside; anything else done by the person on its screen.
  select coalesce(jsonb_agg(s || jsonb_build_object('assistant', case
           when public.setup_step_holds_secret(s->>'step') then 'in_app_only'
           when s->>'state' in ('ready', 'not_applicable', 'deferred') then 'none'
           when (s->>'manual')::boolean then 'mark_done'
           when not (s->>'required')::boolean then 'set_aside'
           else 'in_app' end) order by i), '[]'::jsonb)
    into v_steps
    from jsonb_array_elements(v_status->'steps') with ordinality x(s, i);
  -- The one next action (the app's SetupStatus.nextStep): what the next
  -- milestone needs, else what a later one needs, else an optional step.
  select s->>'step' into v_next_step
    from jsonb_array_elements(v_status->'steps') with ordinality x(s, i)
   where s->>'state' = 'needs_configuration'
   order by case
              when (s->>'required')::boolean and v_next_rank is not null
                   and (select o from jsonb_array_elements(v_status->'milestones') with ordinality y(m, o)
                         where m->>'milestone' = s->>'milestone') <= v_next_rank then 0
              when (s->>'required')::boolean then 1
              else 2 end, i
   limit 1;
  return public.mcp_outcome('completed', jsonb_build_object(
    'steps', v_steps,
    'milestones', v_status->'milestones',
    'next_milestone', v_next_milestone,
    'next_step', v_next_step,
    'levels', public.setup_current_levels(
      (select coalesce(feature_flags, '{}'::jsonb) from public.workspaces where id = c.workspace_id),
      (select country_code from public.workspaces where id = c.workspace_id))));
end;
$fn$;
revoke execute on function public.mcp_op_get_setup_status(public.mcp_call_context, jsonb) from public, anon, authenticated;

create or replace function public.mcp_op_list_setup_levels(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_refusal jsonb := public.mcp_setup_refusal(c.workspace_id, p_args, array['workspace_id']);
begin
  if v_refusal is not null then return v_refusal; end if;
  return public.mcp_outcome('completed', public.setup_level_catalogue() || jsonb_build_object(
    'current', public.setup_current_levels(
      (select coalesce(feature_flags, '{}'::jsonb) from public.workspaces where id = c.workspace_id),
      (select country_code from public.workspaces where id = c.workspace_id))));
end;
$fn$;
revoke execute on function public.mcp_op_list_setup_levels(public.mcp_call_context, jsonb) from public, anon, authenticated;

create or replace function public.mcp_op_apply_setup_levels(c public.mcp_call_context, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_refusal jsonb := public.mcp_setup_refusal(c.workspace_id, p_args, public.setup_level_arguments());
  v jsonb;
begin
  if v_refusal is not null then return v_refusal; end if;
  v := public.setup_levels_plan(c.workspace_id, p_args);
  if jsonb_array_length(v->'gaps') > 0 then
    return public.mcp_outcome('validation_error', null, 'invalid_arguments');
  end if;
  if v->'flags' = '{}'::jsonb then
    return public.mcp_outcome('completed', jsonb_build_object('unchanged', true, 'changes', '[]'::jsonb,
      'levels', v->'current'));
  end if;
  begin
    perform public.set_feature_flags(c.workspace_id, v->'flags', v->'expected');
  exception when sqlstate 'DK409' then
    return public.mcp_outcome('conflict', null, 'confirmation_stale');
  end;
  return public.mcp_outcome('completed', jsonb_build_object('changes', v->'changes',
    'switch_on', v->'switch_on', 'switch_off', v->'switch_off',
    'levels', public.setup_current_levels(
      (select coalesce(feature_flags, '{}'::jsonb) from public.workspaces where id = c.workspace_id),
      (select country_code from public.workspaces where id = c.workspace_id))));
end;
$fn$;
revoke execute on function public.mcp_op_apply_setup_levels(public.mcp_call_context, jsonb) from public, anon, authenticated;

drop function if exists public.setup_current_levels(jsonb);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(761);
