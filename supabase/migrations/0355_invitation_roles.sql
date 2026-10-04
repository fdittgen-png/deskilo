-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0359 (#2085) -- an invitation can carry roles.
--
-- The third place a role is given: at invitation time. Whoever invites
-- someone can say which of the workspace's own roles the person holds
-- when they arrive, so a treasurer does not join as a plain member and
-- wait for somebody to remember.
--
--   * `invitations.role_keys` names the roles; `roles_applied_at` says
--     when they were given. `set_invitation_roles` writes the keys on an
--     invitation the caller created and nobody redeemed yet, checking each
--     role the way `assign_workspace_role` would for a member: the
--     workspace's own active roles only (the Administrator keeps its own
--     invitation, `is_admin`), `customRoles` effective, manageRoles held,
--     and -- unless the inviter is the owner -- only roles whose
--     permissions the inviter holds, never one that carries manageRoles.
--   * The roles are given when the person becomes an ACTIVE member of
--     the workspace through that invitation -- at once, or when the
--     validators approve the membership. A trigger on `members` does it,
--     so `join_workspace` is not touched. It asks the same questions
--     again on that day, of the inviter's membership: an inviter who has
--     left, or lost the right to give a role, gives nothing; a role put
--     aside since is skipped.
--   * Each role given is recorded as an applied `role_change` event, with
--     the inviter as the actor and `invitation: true` in the payload, and
--     the invitation is marked so nothing is given twice.
--
-- Nobody gives a role to themselves: an invitation is redeemed by
-- someone else, and the trigger refuses a redeemer who is the inviter.

alter table public.invitations
  add column if not exists role_keys text[] not null default '{}',
  add column if not exists roles_applied_at timestamptz;

-- May the member [p_giver] give [p_role]? The rules of
-- `assign_workspace_role`, asked of a member row rather than the caller,
-- so they hold on the day the invitation is redeemed.
create or replace function public.member_may_give_role(
  p_giver uuid, p_role public.workspace_roles
) returns boolean
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_giver public.members;
  v_perm text;
begin
  select * into v_giver from public.members where id = p_giver;
  if v_giver.id is null or v_giver.status <> 'active'
     or v_giver.workspace_id <> p_role.workspace_id then
    return false;
  end if;
  if p_role.builtin or not p_role.active then return false; end if;
  if not public.feature_effective(p_role.workspace_id, 'customRoles') then
    return false;
  end if;
  if not public.member_has_permission(p_giver, 'manageRoles') then
    return false;
  end if;
  if v_giver.is_owner or v_giver.co_owner = 'active' then return true; end if;
  if 'manageRoles' = any(p_role.permissions) then return false; end if;
  foreach v_perm in array p_role.permissions loop
    if not public.member_has_permission(p_giver, v_perm) then
      return false;
    end if;
  end loop;
  return true;
end $fn$;

revoke execute on function public.member_may_give_role(uuid, public.workspace_roles)
  from public, anon, authenticated;

create or replace function public.set_invitation_roles(
  p_workspace_id uuid, p_code text, p_role_keys text[]
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invitations;
  v_me uuid;
  v_key text;
  v_role public.workspace_roles;
  v_keys text[] := coalesce(p_role_keys, '{}'::text[]);
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_inv from public.invitations
   where workspace_id = p_workspace_id and code = upper(btrim(p_code));
  if v_inv.id is null or v_inv.created_by is distinct from auth.uid() then
    raise exception 'only the person who created an invitation sets its roles';
  end if;
  if v_inv.redeemed_at is not null then
    raise exception 'that invitation was already used';
  end if;
  if v_inv.is_admin or v_inv.member_id is not null then
    raise exception 'this invitation carries no roles';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  foreach v_key in array v_keys loop
    select * into v_role from public.workspace_roles r
     where r.workspace_id = p_workspace_id and r.key = v_key;
    if v_role.id is null then
      raise exception 'unknown role %', v_key;
    end if;
    if not public.member_may_give_role(v_me, v_role) then
      raise exception 'the role % is not yours to give', v_key;
    end if;
  end loop;
  update public.invitations
     set role_keys = (select coalesce(array_agg(distinct k order by k), '{}'::text[])
                        from unnest(v_keys) k)
   where id = v_inv.id;
end $fn$;

revoke execute on function public.set_invitation_roles(uuid, text, text[])
  from public, anon;
grant execute on function public.set_invitation_roles(uuid, text, text[])
  to authenticated;

-- The roles arrive with the membership.
create or replace function public.members_invitation_roles()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invitations;
  v_giver uuid;
  v_key text;
  v_role public.workspace_roles;
begin
  if new.status <> 'active' or new.user_id is null then return null; end if;
  for v_inv in
    select * from public.invitations i
     where i.workspace_id = new.workspace_id
       and i.redeemed_by = new.user_id
       and i.roles_applied_at is null
       and cardinality(i.role_keys) > 0
     for update
  loop
    if v_inv.created_by is distinct from new.user_id then
      select m.id into v_giver from public.members m
       where m.workspace_id = new.workspace_id
         and m.user_id = v_inv.created_by;
      foreach v_key in array v_inv.role_keys loop
        select * into v_role from public.workspace_roles r
         where r.workspace_id = new.workspace_id and r.key = v_key;
        if v_role.id is null or not public.member_may_give_role(v_giver, v_role) then
          continue;
        end if;
        insert into public.workspace_role_members (workspace_id, role_id, member_id)
        values (new.workspace_id, v_role.id, new.id)
        on conflict (role_id, member_id) do nothing;
        if found then
          perform public.record_applied_event(
            new.workspace_id, 'role_change', v_giver, new.id,
            jsonb_build_object('role_key', v_role.key, 'role_id', v_role.id,
                               'role_names', v_role.names, 'assign', true,
                               'invitation', true));
        end if;
      end loop;
    end if;
    update public.invitations set roles_applied_at = now() where id = v_inv.id;
  end loop;
  return null;
end $fn$;

revoke execute on function public.members_invitation_roles()
  from public, anon, authenticated;

drop trigger if exists members_invitation_roles on public.members;
create trigger members_invitation_roles
  after insert or update of status, user_id on public.members
  for each row execute function public.members_invitation_roles();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(355);
