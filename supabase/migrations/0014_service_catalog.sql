-- SPDX-License-Identifier: MIT
-- DesKilo consumable-service catalog (epic #121 task 3, issue #123,
-- ADR 0008). Owner-priced services (coffee, printing, meeting room, ...)
-- that members/admins add to the monthly bill (task 5 wires consumption).
-- Deactivate, never delete: future bill lines snapshot but also reference.

create table public.services (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  price_cents int not null default 0 check (price_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index services_workspace_idx on public.services (workspace_id);

alter table public.services enable row level security;
create policy services_select on public.services
  for select using (public.is_member_of(workspace_id));
create policy services_write on public.services
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));
