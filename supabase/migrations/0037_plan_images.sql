-- SPDX-License-Identifier: MIT
-- Resizable illustration images placed on a level's plan — photos of
-- the real space (a plant, a couch, a whiteboard) positioned and sized
-- over the grid, distinct from the whole-level background (0036).
-- Applied to the hosted reference project on 2026-07-19.
--
-- Each image is a grid rect + a storage object in the floor-plans bucket
-- at `<workspace_id>/img/<image_id>`; the 0036 storage RLS already gates
-- it (workspace = first path segment).

create table public.plan_images (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  level_id uuid not null references public.levels(id) on delete cascade,
  x int not null,
  y int not null,
  w int not null check (w > 0),
  h int not null check (h > 0),
  storage_path text not null,
  created_at timestamptz not null default now()
);
create index plan_images_level_idx on public.plan_images (level_id);

alter table public.plan_images enable row level security;

-- members see the images; owners manage them (same shape as the rest of
-- the floor plan, 0002/0003).
create policy plan_images_select on public.plan_images
  for select using (public.is_member_of(workspace_id));
create policy plan_images_write on public.plan_images
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));
