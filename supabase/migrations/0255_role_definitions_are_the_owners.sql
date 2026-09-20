-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0255 (#1560) — defining a role is the owner's, through every door.
--
-- `set_workspace_role` has always refused anybody but an owner: a role
-- IS a set of permissions, so whoever writes one writes authority.
-- The configuration import reached the same rows without that check.
--
-- How the gap opened, because it was nobody's single mistake. 0177
-- guarded the import with `is_owner_of`. 0186 relaxed it to
-- `manageConfiguration OR deploying_touches` so a deployment could pass
-- its own transfer. 0197 dropped the token half. 0206 widened it again
-- to the target environment's `deployToProd` / `deployToDev`. Each step
-- was right about configuration — hours, tariffs, closure days — and
-- none of them was about roles, because roles did not travel yet. 0251
-- made them travel, into a door whose guard had been rewritten four
-- times since it said `owner`.
--
-- What that adds up to: a member holding `manageConfiguration` — a
-- permission a custom role can itself grant — or simply an admin on a
-- development workspace, where `deployToDev` is an admin default, could
-- import a configuration naming a role they already hold and give it
-- any permission in the catalogue. `workspace_role_members` is left
-- intact by design, `member_custom_permissions` reads the role's
-- current permissions, and `has_permission_raw` ORs them in. The
-- caller's own authority, rewritten by the caller.
--
-- The rule, in one line: a configuration delegate may carry role
-- definitions that change nothing, and only an owner may change one.
--
-- Not "owner may import roles at all": an import that happens to carry
-- the roles it already has is the ordinary case — a full configuration
-- exported from the twin and imported back — and refusing it would push
-- people to strip the section by hand, which is how a guard teaches
-- somebody to work around it. What is refused is a CHANGE: a key that
-- is not there, permissions that differ, a name, an order, an active
-- flag, or a mirror that would deactivate a role the payload omits.
--
-- Deployments route through `import_workspace_configuration` too
-- (0186), so they inherit this: deploying a role definition onto the
-- production side now asks for an owner. That is the intended reading —
-- owners hold every deploy permission anyway, and a definition landing
-- on the prod is the same act as writing it there.

-- ── role definitions ────────────────────────────────────────────────

create or replace function public.workspace_roles_import(
  p_workspace_id uuid, p_roles jsonb, p_mode text
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  v_perm text;
  v_changes boolean := false;
  v_current public.workspace_roles%rowtype;
begin
  if p_roles is null then return; end if;

  -- First pass: validate, and decide whether anything would MOVE.
  -- Validation stays ahead of the authority check so a malformed
  -- payload reads as malformed rather than as a refusal.
  for e in select jsonb_array_elements(p_roles) loop
    if e->>'key' in ('owner', 'co_owner', 'admin', 'member') then
      raise exception 'the built-in roles are not redefined here';
    end if;
    for v_perm in select jsonb_array_elements_text(coalesce(e->'permissions', '[]'::jsonb)) loop
      if not (v_perm = any(public.role_permission_catalog())) then
        raise exception 'unknown permission %', v_perm;
      end if;
    end loop;

    select * into v_current from public.workspace_roles r
     where r.workspace_id = p_workspace_id and r.key = e->>'key';

    if not found then
      v_changes := true;
    elsif v_current.permissions is distinct from
            coalesce((select array_agg(value)
                        from jsonb_array_elements_text(e->'permissions')), '{}'::text[])
       or v_current.names is distinct from coalesce(e->'names', '{}'::jsonb)
       or v_current.sort_order is distinct from coalesce((e->>'sort_order')::int, 0)
       or v_current.active is distinct from coalesce((e->>'active')::boolean, true)
    then
      v_changes := true;
    end if;
  end loop;

  if p_mode = 'mirror' and exists (
       select 1 from public.workspace_roles r
        where r.workspace_id = p_workspace_id
          and r.active
          and not exists (select 1 from jsonb_array_elements(p_roles) e2
                           where e2.value->>'key' = r.key))
  then
    v_changes := true;
  end if;

  -- #1560 — the same authority `set_workspace_role` asks for, and the
  -- same sentence, so a refusal reads the same wherever it is met.
  if v_changes and (auth.uid() is null or not public.is_owner_of(p_workspace_id)) then
    raise exception 'only an owner defines the roles of a workspace';
  end if;

  if not v_changes then return; end if;

  for e in select jsonb_array_elements(p_roles) loop
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

revoke execute on function public.workspace_roles_import(uuid, jsonb, text)
  from public, anon, authenticated;

-- ── the built-in matrix, through the same door ──────────────────────
--
-- `set_role_permissions` asks for `manageRoles`; the import wrote
-- `workspaces.role_permissions` with no check at all. Same class, same
-- wrapper, and it was never filed — the matrix decides what an admin
-- may do, so rewriting it from a configuration file is the same act.
--
-- A function rather than a branch, because the write is one column of
-- one `update` inside a body four migrations have patched: raising from
-- inside the expression refuses the WHOLE import, which is what an
-- atomic refusal means.
create or replace function public.guarded_role_permissions(
  p_workspace_id uuid, p_incoming jsonb, p_current jsonb
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
begin
  if p_incoming is null then return p_current; end if;
  if p_incoming is distinct from p_current
     and (auth.uid() is null or not public.has_permission(p_workspace_id, 'manageRoles'))
  then
    raise exception 'only somebody who manages the roles changes what a role may do';
  end if;
  return p_incoming;
end $fn$;

revoke execute on function public.guarded_role_permissions(uuid, jsonb, jsonb)
  from public, anon;
grant execute on function public.guarded_role_permissions(uuid, jsonb, jsonb)
  to authenticated;

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
begin
  v_def := pg_get_functiondef(
    'public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    $a$    role_permissions = case when v_ws ? 'role_permissions' then v_ws->'role_permissions' else w.role_permissions end,$a$,
    $a$    role_permissions = case when v_ws ? 'role_permissions' then public.guarded_role_permissions(p_workspace_id, v_ws->'role_permissions', w.role_permissions) else w.role_permissions end,$a$);
  if v_patched is null then
    raise exception '0255: the role_permissions anchor did not match';
  end if;
  execute v_patched;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(255);
