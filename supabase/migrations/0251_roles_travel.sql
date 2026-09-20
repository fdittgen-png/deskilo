-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0251 (#1505) — a workspace's own roles travel; who holds them does not.
--
-- The built-in role matrix already travels (`workspaces.role_permissions`
-- rides in the workspace configuration, `allowed` for publication with
-- the reason "the role matrix only; nothing assigns a role to a person").
-- A custom role is the same kind of thing — a definition with nobody in
-- it — so it travels on the same terms and for the same stated reason.
--
-- **The assignments stay behind.** A grant names a member, and members
-- do not travel: a role given to somebody in the development twin means
-- nothing in production, where that person may not exist. So the entity
-- names `workspace_roles` and never reaches `workspace_role_members`,
-- and a role that arrives holds NOBODY until an owner gives it to
-- somebody through `assign_workspace_role`, which needs `manageRoles`
-- and refuses the caller themselves.
--
-- That is the answer to the question #1505 posed: what makes this safe
-- is not a review step but the fact that an arriving role has no holders
-- and grants nothing until a person acts.
--
-- The import validates what `set_workspace_role` validates: the four
-- built-in keys are refused, and every permission is checked against
-- `role_permission_catalog()`, so a template cannot carry a role holding
-- something the product does not have.

create or replace function public.workspace_roles_export(p_workspace_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
      'key', r.key, 'permissions', to_jsonb(r.permissions),
      'names', r.names, 'sort_order', r.sort_order, 'active', r.active)
      order by r.sort_order, r.key), '[]'::jsonb)
    from public.workspace_roles r
   where r.workspace_id = p_workspace_id;
$fn$;

create or replace function public.workspace_roles_import(
  p_workspace_id uuid, p_roles jsonb, p_mode text
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  v_perm text;
begin
  if p_roles is null then return; end if;

  for e in select jsonb_array_elements(p_roles) loop
    if e->>'key' in ('owner', 'co_owner', 'admin', 'member') then
      raise exception 'the built-in roles are not redefined here';
    end if;
    for v_perm in select jsonb_array_elements_text(coalesce(e->'permissions', '[]'::jsonb)) loop
      if not (v_perm = any(public.role_permission_catalog())) then
        raise exception 'unknown permission %', v_perm;
      end if;
    end loop;

    insert into public.workspace_roles
      (workspace_id, key, permissions, names, sort_order, active)
    values (p_workspace_id, e->>'key',
            coalesce((select array_agg(value) from jsonb_array_elements_text(e->'permissions')),
                     '{}'::text[]),
            coalesce(e->'names', '{}'::jsonb),
            coalesce((e->>'sort_order')::int, 0),
            coalesce((e->>'active')::boolean, true))
    on conflict (workspace_id, key) do update
      set permissions = excluded.permissions, names = excluded.names,
          sort_order = excluded.sort_order, active = excluded.active;
  end loop;

  -- Mirror deactivates rather than deletes, for the same reason the
  -- editor never deletes a role: deleting takes its holders with it.
  if p_mode = 'mirror' then
    update public.workspace_roles r set active = false
     where r.workspace_id = p_workspace_id
       and not exists (select 1 from jsonb_array_elements(p_roles) e
                        where e.value->>'key' = r.key);
  end if;
end $fn$;

-- No grant to `authenticated`: the innards of the configuration
-- transfer, called from functions that check the caller.
revoke execute on function public.workspace_roles_export(uuid)
  from public, anon, authenticated;
revoke execute on function public.workspace_roles_import(uuid, jsonb, text)
  from public, anon, authenticated;

-- ── the entity, the export, the import and the publication rule ──────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  v_def := pg_get_functiondef('public.deployable_entities()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    jsonb_build_object('key', 'features'$a$,
    $a$    jsonb_build_object('key', 'workspace_roles', 'kind', 'configuration',
      'requires', '[]'::jsonb, 'merge_policy', 'keyed_update',
      'group', 'roles_access', 'workspace_keys', '[]'::jsonb,
      'tables', '["workspace_roles"]'::jsonb),
    jsonb_build_object('key', 'features'$a$);
  if v_patched is null then v_missing := v_missing || 'entities'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.entity_row_key(text, jsonb)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    when 'workspace_field_definitions' then p_row->>'key'$a$,
    $a$    when 'workspace_field_definitions' then p_row->>'key'
    when 'workspace_roles' then p_row->>'key'$a$);
  if v_patched is null then v_missing := v_missing || 'row_key'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.template_publication_rules()'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    'features', jsonb_build_object('allowed', true)$a$,
    $a$    'workspace_roles', jsonb_build_object('allowed', true,
      'reason', 'the definitions only; a role that arrives holds nobody until an owner gives it to somebody (#1505)'),
    'features', jsonb_build_object('allowed', true)$a$);
  if v_patched is null then v_missing := v_missing || 'publication'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.export_workspace_configuration(uuid)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$      'workspace_field_definitions',
        public.field_definitions_export(p_workspace_id),$a$,
    $a$      'workspace_field_definitions',
        public.field_definitions_export(p_workspace_id),
      'workspace_roles', public.workspace_roles_export(p_workspace_id),$a$);
  if v_patched is null then v_missing := v_missing || 'export'::text;
  else execute v_patched; end if;

  v_def := pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$  if v_t ? 'workspace_field_definitions' then$a$,
    $a$  if v_t ? 'workspace_roles' then
    perform public.workspace_roles_import(
      p_workspace_id, v_t->'workspace_roles', p_mode);
  end if;

  if v_t ? 'workspace_field_definitions' then$a$);
  if v_patched is null then v_missing := v_missing || 'import'::text;
  else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0251: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(251);
