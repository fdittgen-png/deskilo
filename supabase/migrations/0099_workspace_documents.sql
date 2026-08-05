-- SPDX-License-Identifier: 0BSD
-- The workspace DOCUMENT LIBRARY (#500): statutes, user guides,
-- financial statements, meeting minutes… Federated by LINK to whatever
-- document system the workspace already uses — Google Drive, OneDrive,
-- SharePoint, Dropbox, Nextcloud, any https URL — the provider handles
-- its own authentication in the browser; the app never stores foreign
-- credentials. Visibility is ROLE-GATED server-side: min_role decides
-- who can even see a row (member < admin < owner).
create table public.workspace_documents (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  category text not null default 'other'
    check (category in
      ('statutes','guides','finance','minutes','other')),
  provider text not null default 'link'
    check (provider in
      ('gdrive','onedrive','sharepoint','dropbox','nextcloud','link')),
  url text not null
    check (url like 'https://%' and char_length(url) <= 500),
  min_role text not null default 'member'
    check (min_role in ('member','admin','owner')),
  created_at timestamptz not null default now()
);
create index workspace_documents_workspace_idx
  on public.workspace_documents (workspace_id);

alter table public.workspace_documents enable row level security;

-- Read: an active member sees a row when their role reaches min_role.
create policy workspace_documents_select on public.workspace_documents
  for select using (exists (
    select 1 from public.members m
    where m.workspace_id = workspace_documents.workspace_id
      and m.user_id = auth.uid() and m.status = 'active'
      and (workspace_documents.min_role = 'member'
           or (workspace_documents.min_role = 'admin'
               and (m.is_admin or m.is_owner))
           or (workspace_documents.min_role = 'owner' and m.is_owner))
  ));

-- Write: owners and admins curate the library.
create policy workspace_documents_write on public.workspace_documents
  for all using (exists (
    select 1 from public.members m
    where m.workspace_id = workspace_documents.workspace_id
      and m.user_id = auth.uid() and m.status = 'active'
      and (m.is_admin or m.is_owner)
  )) with check (exists (
    select 1 from public.members m
    where m.workspace_id = workspace_documents.workspace_id
      and m.user_id = auth.uid() and m.status = 'active'
      and (m.is_admin or m.is_owner)
  ));
