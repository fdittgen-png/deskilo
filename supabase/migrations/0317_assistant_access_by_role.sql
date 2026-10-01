-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0317 (#1826) -- assistant access is delegated by the role matrix.
--
-- The three routines behind the workspace's assistant screen answered
-- `is_owner_of` alone, so an owner could not hand them to anyone the way
-- every other configuration area is handed over. They now ask
-- `has_permission(workspace, 'manageIntegrations')`: owners always hold
-- it, co-owners by default, and an owner grants it to admins in the role
-- matrix. No new permission, so the catalogue and its pins do not move.
--
-- Not changed, on purpose: database administrators and the operator steps
-- (identity authority, approved clients, the runtime switch) are not
-- workspace roles and never become one (0270).
--
-- Patched at asserted anchors: the hosted bodies are the latest text of
-- each routine, whatever file last wrote them.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_step record;
  v_def text;
  v_next text;
  v_count int;
begin
  for v_step in
    select * from (values
      ('mcp_policy_status', 'p_workspace_id uuid',
       $a$if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner configures MCP exposure';$a$,
       $b$if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'only those who manage integrations configure MCP exposure';$b$),
      ('save_mcp_policy',
       'p_workspace_id uuid, p_expected_revision integer, p_mutation_id uuid, p_enabled boolean, p_operations text[], p_target_ceiling text, p_allowed_clients text[], p_optional_fields text[]',
       $a$if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner configures MCP exposure';$a$,
       $b$if not public.has_permission(p_workspace_id, 'manageIntegrations') then
    raise exception 'only those who manage integrations configure MCP exposure';$b$),
      ('mcp_usage_summary_workspace', 'p_workspace_id uuid',
       $a$p_workspace_id is null or not public.is_owner_of(p_workspace_id)$a$,
       $b$p_workspace_id is null or not public.has_permission(p_workspace_id, 'manageIntegrations')$b$)
    ) as t(fn, args, old_text, new_text)
  loop
    select pg_get_functiondef(p.oid) into v_def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = v_step.fn
       and pg_get_function_identity_arguments(p.oid) = v_step.args;
    if v_def is null then
      raise exception '0317: % not found', v_step.fn;
    end if;
    v_next := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_next is null then
      raise exception '0317: anchor missing in %', v_step.fn;
    end if;
    select count(*) into v_count from regexp_matches(v_next, 'manageIntegrations', 'g');
    if v_count <> 1 then
      raise exception '0317: % carries the permission % times, expected once', v_step.fn, v_count;
    end if;
    if position('is_owner_of' in v_next) > 0 then
      raise exception '0317: % still asks is_owner_of', v_step.fn;
    end if;
    execute v_next;
  end loop;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(317);
