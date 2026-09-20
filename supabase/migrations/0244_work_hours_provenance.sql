-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0244 (#1307 S4) — a workspace value says where it came from, and can go
-- back: opening hours as the representative setting.
--
-- A template (#1276) can deliver the working day. Once delivered, nothing on
-- the Availability screen said so, and there was no way back to the
-- product's own hours or to the template's short of retyping five numbers.
--
-- `work_hours_provenance(workspace)` answers, for the five work-hour keys
-- of `booking_rules`:
--
--   * `default`   — none of the keys is set: the product's defaults apply;
--   * `template`  — the keys equal what the latest template application
--                   that carried `booking_rules` delivers (named, with its
--                   values, so the client can reset to them);
--   * `workspace` — anything else: someone set them here.
--
-- `reset_work_hours(workspace)` removes the five keys, which is exactly
-- "the product default" — `WorkHours.fromRules` and the server read an
-- absent key as its default. Resetting to the template writes the named
-- values through the existing keyed `set_booking_rule`, so there is one
-- write path and one permission (`workspaceSettings`).

create or replace function public.work_hours_provenance(p_workspace_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_keys constant text[] := array['work_start_minutes', 'half_boundary_minutes',
    'work_end_minutes', 'half_day_hours', 'full_day_hours'];
  v_rules jsonb;
  v_current jsonb;
  v_tpl_rules jsonb;
  v_name text;
  v_key text;
  v_version int;
begin
  if auth.uid() is null or not public.is_member_of(p_workspace_id) then
    raise exception 'not a member of this workspace';
  end if;
  select coalesce(booking_rules, '{}'::jsonb) into v_rules
    from public.workspaces where id = p_workspace_id;
  select coalesce(jsonb_object_agg(k, v_rules->k), '{}'::jsonb) into v_current
    from unnest(v_keys) k where v_rules ? k;

  select t.name, a.template_key, a.template_version,
         (select coalesce(jsonb_object_agg(k, t.configuration->'workspace'->'booking_rules'->k), '{}'::jsonb)
            from unnest(v_keys) k
           where coalesce(t.configuration->'workspace'->'booking_rules', '{}'::jsonb) ? k)
    into v_name, v_key, v_version, v_tpl_rules
    from public.workspace_template_applications a
    join public.workspace_templates t on t.id = a.template_id
   where a.workspace_id = p_workspace_id
     and 'booking_rules' = any (a.entities)
   order by a.applied_at desc
   limit 1;
  if v_tpl_rules = '{}'::jsonb then
    v_tpl_rules := null;
  end if;

  return jsonb_build_object(
    'state', case
      when v_tpl_rules is not null and v_current = v_tpl_rules then 'template'
      when v_current = '{}'::jsonb then 'default'
      else 'workspace' end,
    'template', case when v_tpl_rules is null then null else jsonb_build_object(
      'name', v_name, 'key', v_key, 'version', v_version, 'values', v_tpl_rules) end);
end $$;

revoke execute on function public.work_hours_provenance(uuid) from public, anon;
grant execute on function public.work_hours_provenance(uuid) to authenticated;

create or replace function public.reset_work_hours(p_workspace_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rules jsonb;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only workspace settings managers may change the booking rules';
  end if;
  update public.workspaces
     set booking_rules = coalesce(booking_rules, '{}'::jsonb)
       - array['work_start_minutes', 'half_boundary_minutes', 'work_end_minutes',
               'half_day_hours', 'full_day_hours']
   where id = p_workspace_id
  returning booking_rules into v_rules;
  if v_rules is null then
    raise exception 'unknown workspace';
  end if;
  return v_rules;
end $$;

revoke execute on function public.reset_work_hours(uuid) from public, anon;
grant execute on function public.reset_work_hours(uuid) to authenticated;

select public.set_deskilo_schema_version(244);
