-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0341 (#2085) -- who may give a workspace's own role, and the record of it.
--
-- `assign_workspace_role` (0247) asked one question: does the caller hold
-- manageRoles? That let anybody holding it hand a teammate a role that
-- carries more than they hold themselves -- manageRoles included, which
-- is the permission to do it again. The owner decided (#2085):
--
--   * a person who is not the owner gives (or takes back) only a role
--     whose permissions they hold themselves;
--   * a role that carries manageRoles is the owner's to give;
--   * a role is given to an active member who is not a kiosk, and a role
--     that was put aside is not given at all (it can still be taken back);
--   * the owner -- `is_owner_of`, so an active co-owner too -- is not
--     limited, as before;
--   * nobody gives a role to themselves, as before.
--
-- Every grant and every take-back is now recorded as an applied
-- `role_change` event, so the workspace's activity says who gave which
-- role to whom and when. The grant row already carried who wrote it
-- (`created_by_user`, 0183); a take-back deletes that row, so without the
-- event it left no trace at all. The payload names the role
-- (`role_key`, `role_id`, and its `role_names` as they read that day)
-- and the direction (`assign`), and has no `make_admin`, which is how
-- the app tells it apart from the Administrator role's quorum request.
--
-- Whole-function rewrite: the body is the 0247 text with the new checks
-- and the record. Signature, SECURITY DEFINER, search_path and grants are
-- unchanged.

create or replace function public.assign_workspace_role(
  p_member_id uuid, p_role_id uuid, p_assign boolean default true
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_subject public.members;
  v_role public.workspace_roles;
  v_actor uuid;
  v_perm text;
begin
  select * into v_subject from public.members m where m.id = p_member_id;
  if v_subject.id is null then raise exception 'unknown member'; end if;
  select * into v_role from public.workspace_roles r where r.id = p_role_id;
  if v_role.id is null or v_role.workspace_id <> v_subject.workspace_id then
    raise exception 'that role belongs to another workspace';
  end if;
  if auth.uid() is null
     or not public.has_permission(v_subject.workspace_id, 'manageRoles') then
    raise exception 'only someone who manages the roles may assign one';
  end if;
  if v_subject.user_id = auth.uid() then
    raise exception 'a role is never assigned to yourself';
  end if;
  if not public.feature_effective(v_subject.workspace_id, 'customRoles') then
    raise exception 'custom roles are off in this workspace';
  end if;

  -- #2085 -- the owner gives anything; anybody else only what they hold,
  -- and never the power to give roles.
  if not public.is_owner_of(v_subject.workspace_id) then
    if 'manageRoles' = any(v_role.permissions) then
      raise exception 'only an owner gives a role that manages roles';
    end if;
    foreach v_perm in array v_role.permissions loop
      if not public.has_permission(v_subject.workspace_id, v_perm) then
        raise exception 'a role is given only by someone who holds what it gives';
      end if;
    end loop;
  end if;

  if p_assign then
    if v_subject.is_kiosk or v_subject.status <> 'active' then
      raise exception 'this member cannot hold a role';
    end if;
    if not v_role.active then
      raise exception 'that role was put aside';
    end if;
  end if;

  select m.id into v_actor from public.members m
   where m.workspace_id = v_subject.workspace_id and m.user_id = auth.uid()
     and m.status = 'active';

  if p_assign then
    insert into public.workspace_role_members (workspace_id, role_id, member_id)
    values (v_subject.workspace_id, p_role_id, p_member_id)
    on conflict (role_id, member_id) do nothing;
  else
    delete from public.workspace_role_members
     where role_id = p_role_id and member_id = p_member_id;
  end if;

  -- Only a change is recorded: giving a role somebody already holds, or
  -- taking back one they do not, writes nothing.
  if found then
    perform public.record_applied_event(
      v_subject.workspace_id, 'role_change', v_actor, v_subject.id,
      jsonb_build_object('role_key', v_role.key, 'role_id', v_role.id,
                         'role_names', v_role.names, 'assign', p_assign));
  end if;
end $fn$;

revoke execute on function public.assign_workspace_role(uuid, uuid, boolean)
  from public, anon;
grant execute on function public.assign_workspace_role(uuid, uuid, boolean)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(341);
