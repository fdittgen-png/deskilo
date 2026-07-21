-- SPDX-License-Identifier: 0BSD
-- DesKilo RLS (Epic #2, issue #24). Applied to the hosted reference project
-- on 2026-07-07 as migration "rls_core_tables".
--
-- Writes to workspaces/members happen via SECURITY DEFINER RPCs except
-- owner-managed member updates. No insert policies on purpose: default-deny.
alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.members enable row level security;

-- profiles: self + people who share a workspace with you
create policy profiles_select on public.profiles
  for select using (id = auth.uid() or public.shares_workspace_with(id));
create policy profiles_update on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- workspaces: members read; owners update/delete
create policy workspaces_select on public.workspaces
  for select using (public.is_member_of(id));
create policy workspaces_update on public.workspaces
  for update using (public.is_owner_of(id)) with check (public.is_owner_of(id));
create policy workspaces_delete on public.workspaces
  for delete using (public.is_owner_of(id));

-- members: co-members read; owners manage (last-owner trigger still guards)
create policy members_select on public.members
  for select using (public.is_member_of(workspace_id));
create policy members_update_owner on public.members
  for update using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));
create policy members_delete_owner on public.members
  for delete using (public.is_owner_of(workspace_id));
