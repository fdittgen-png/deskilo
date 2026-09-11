-- SPDX-License-Identifier: 0BSD
-- 0198 — #1089: a held matrix change carries the DELTA, not a snapshot.
--
-- 0195 gave the role matrix a single-permission writer, which fixes the
-- immediate path. The held path is worse and was still open.
--
-- `request_matrix_change` captures the client's WHOLE permission list as
-- `payload.after`. When a validation policy holds the change, that list
-- sits in the event until a validator confirms it — and
-- `apply_validated_decision_0181` then writes it verbatim:
--
--     when 'matrix_change' then
--       select array_agg(x) into v_perms from jsonb_array_elements_text(new.payload->'after') x;
--       update public.workspaces set role_permissions = jsonb_set(..., v_perms) ...
--
-- So the window in which a concurrent change can be erased is not
-- milliseconds, it is however long the validator takes to answer. Two
-- requests held at once, confirmed in either order, and the second wipes
-- the first — including a permission an owner removed in between,
-- silently restored by a decision about something else entirely.
--
-- The event now records what was ASKED — this permission, on or off —
-- and the applier applies that to the list as it stands at the moment of
-- confirmation. A decision about `exportData` can no longer be a
-- decision about every other permission as a side effect.

-- ── asking for one permission ──────────────────────────────────────
create or replace function public.request_matrix_permission(
  p_workspace_id uuid, p_role text, p_permission text, p_enabled boolean
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_actor public.members; v_id uuid; v_payload jsonb; v_before jsonb;
begin
  v_actor := public.my_active_member(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageRoles') then
    raise exception 'only role managers may edit permissions';
  end if;
  if p_role not in ('co_owner','admin','member') then
    raise exception 'unknown role';
  end if;
  if not (p_permission = any(public.role_permission_catalog())) then
    raise exception 'unknown permission %', p_permission;
  end if;

  select role_permissions -> p_role into v_before
    from public.workspaces where id = p_workspace_id;

  -- `before` is kept for the reader of the trail, never for the write.
  v_payload := jsonb_build_object(
    'role', p_role,
    'permission', p_permission,
    'enabled', p_enabled,
    'before', coalesce(v_before, 'null'::jsonb));

  if public.validation_requires(p_workspace_id, 'matrix_change', 0) then
    insert into public.events (workspace_id, type, action, actor_member_id,
                               subject_member_id, payload, status)
    values (p_workspace_id, 'matrix_change', 'submitted', v_actor.id,
            v_actor.id, v_payload, 'pending')
    returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;

  perform public.set_role_permission(p_workspace_id, p_role, p_permission, p_enabled);
  perform public.record_applied_event(p_workspace_id, 'matrix_change',
                                      v_actor.id, v_actor.id, v_payload);
  return jsonb_build_object('pending', false);
end $fn$;
revoke execute on function public.request_matrix_permission(uuid, text, text, boolean)
  from public, anon;

-- ── applying one, on the list as it stands ─────────────────────────
-- Events created BEFORE this migration carry `after` and no
-- `permission`; they keep the old behaviour, because rewriting the
-- meaning of a decision somebody has already been asked to make would be
-- worse than the race it came from. New events carry the delta.
do $patch$
declare v_def text; v_new text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='apply_validated_decision_0181';
  if v_def is null then raise exception '0198: apply_validated_decision_0181 not found'; end if;

  v_old := '    when ''matrix_change'' then';
  if position(v_old in v_def) = 0 then
    raise exception '0198: matrix_change branch anchor missing';
  end if;

  v_new := replace(v_def,
    E'    when ''matrix_change'' then\n      select array_agg(x) into v_perms from jsonb_array_elements_text(new.payload->''after'') x;\n      update public.workspaces set role_permissions = jsonb_set(coalesce(role_permissions, ''{}''::jsonb), array[new.payload->>''role''], coalesce(to_jsonb(v_perms), ''[]''::jsonb)) where id = new.workspace_id;',
    E'    when ''matrix_change'' then\n'
 || E'      if new.payload ? ''permission'' then\n'
 || E'        perform public.set_role_permission(new.workspace_id, new.payload->>''role'',\n'
 || E'                  new.payload->>''permission'', (new.payload->>''enabled'')::boolean);\n'
 || E'      else\n'
 || E'        select array_agg(x) into v_perms from jsonb_array_elements_text(new.payload->''after'') x;\n'
 || E'        update public.workspaces set role_permissions = jsonb_set(coalesce(role_permissions, ''{}''::jsonb), array[new.payload->>''role''], coalesce(to_jsonb(v_perms), ''[]''::jsonb)) where id = new.workspace_id;\n'
 || E'      end if;');

  -- An anchor proves where to cut, never that the cut happened (0195).
  if v_new = v_def then
    raise exception '0198: the matrix_change branch was not replaced';
  end if;
  if position('set_role_permission(' in v_new) = 0 then
    raise exception '0198: the delta branch was not installed';
  end if;

  execute v_new;
end
$patch$;
