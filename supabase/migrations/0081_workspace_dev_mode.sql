-- SPDX-License-Identifier: 0BSD
-- Workspace-wide developer mode (#419, owner directive): "the developer
-- mode is applicable on the entire workspace for all users; it can be
-- set by the owner or admins." Until now it was a device-local prefs
-- toggle any user could flip for themselves.
--
-- A column on the workspace row (published by 0080, so realtime pushes
-- a flip to every device live) plus an is_admin_of-gated setter — the
-- workspaces_update RLS stays owner-only, so admins go through the RPC.

alter table public.workspaces
  add column if not exists dev_mode boolean not null default false;

create or replace function public.set_dev_mode(
  p_workspace_id uuid,
  p_enabled boolean
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin_of(p_workspace_id) then
    raise exception 'not an admin of this workspace';
  end if;
  update public.workspaces set dev_mode = p_enabled
    where id = p_workspace_id;
end;
$$;

revoke execute on function public.set_dev_mode(uuid, boolean) from public, anon;
grant execute on function public.set_dev_mode(uuid, boolean) to authenticated;
