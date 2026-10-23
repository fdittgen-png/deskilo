-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2869 (ADR 0047 §5, §6) — the setup guide's own "Later" and "Mark as
-- done". workspace_setup_status (0539) already reads a person's
-- acknowledgement of a step from readiness_acknowledgements: on a manual
-- step it means done, on any other optional step it means set aside for
-- later, and it never makes a verified step ready. What was missing is a
-- way to write one for a STEP: acknowledge_readiness_section (0307) only
-- knows the readiness sections.
--
--   * acknowledge_setup_step(workspace, step): manageConfiguration, never a
--     delegated assistant token. A required step the server verifies
--     cannot be set aside; a step with nothing left to do cannot either.
--   * clear_setup_step_acknowledgement(workspace, step): undo.

create or replace function public.acknowledge_setup_step(p_workspace_id uuid, p_step text)
returns public.readiness_acknowledgements language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_step jsonb;
  v public.readiness_acknowledgements;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace sets a step aside'
      using errcode = '42501';
  end if;
  select e into v_step from jsonb_array_elements(public.workspace_setup_status(p_workspace_id)->'steps') e
   where e->>'step' = p_step limit 1;
  if v_step is null then
    raise exception 'the setup guide has no step %', coalesce(p_step, '(none)')
      using errcode = '22023';
  end if;
  if coalesce((v_step->>'required')::boolean, false)
     and not coalesce((v_step->>'manual')::boolean, false) then
    raise exception 'a required step cannot be set aside for later: it has to be set up'
      using errcode = '22023';
  end if;
  if v_step->>'state' in ('ready', 'not_applicable', 'deferred') then
    raise exception 'this step has nothing left to set aside' using errcode = '22023';
  end if;
  insert into public.readiness_acknowledgements (workspace_id, user_id, section, material_revision)
  values (p_workspace_id, auth.uid(), p_step, md5(p_step || ':' || coalesce(v_step->>'state', '')))
  on conflict on constraint readiness_acknowledgements_key do update
    set material_revision = excluded.material_revision, acknowledged_at = now()
  returning * into v;
  return v;
end;
$fn$;
revoke execute on function public.acknowledge_setup_step(uuid, text) from public, anon;
grant execute on function public.acknowledge_setup_step(uuid, text) to authenticated;

create or replace function public.clear_setup_step_acknowledgement(p_workspace_id uuid, p_step text)
returns boolean language plpgsql volatile security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'manageConfiguration') then
    raise exception 'only someone who configures this workspace takes a step back'
      using errcode = '42501';
  end if;
  delete from public.readiness_acknowledgements
   where installation_id = public.installation_id() and workspace_id = p_workspace_id
     and user_id = auth.uid() and section = p_step;
  return found;
end;
$fn$;
revoke execute on function public.clear_setup_step_acknowledgement(uuid, text) from public, anon;
grant execute on function public.clear_setup_step_acknowledgement(uuid, text) to authenticated;

select public.set_deskilo_schema_version(545);
