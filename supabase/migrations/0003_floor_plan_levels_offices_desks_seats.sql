-- SPDX-License-Identifier: MIT
-- DesKilo floor-plan schema (Epic #3, issue #31). Applied to the hosted
-- reference project on 2026-07-07 as "floor_plan_levels_offices_desks_seats".
-- Grid-cell geometry per ADR 0005; workspace_id denormalized for cheap RLS.

create table public.levels (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index levels_workspace_idx on public.levels (workspace_id);

create table public.offices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  level_id uuid not null references public.levels(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  color int not null default 0,
  bookable_as_whole boolean not null default false,
  x int not null check (x >= 0),
  y int not null check (y >= 0),
  w int not null check (w > 0),
  h int not null check (h > 0),
  created_at timestamptz not null default now()
);
create index offices_level_idx on public.offices (level_id);
create index offices_workspace_idx on public.offices (workspace_id);

create table public.desks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  office_id uuid not null references public.offices(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 80),
  x int not null check (x >= 0),
  y int not null check (y >= 0),
  w int not null check (w > 0),
  h int not null check (h > 0),
  created_at timestamptz not null default now()
);
create index desks_office_idx on public.desks (office_id);
create index desks_workspace_idx on public.desks (workspace_id);

-- seat: THE bookable unit (spec §3). Footprint is always 6 cells along the
-- sitting edge × 4 cells deep; orientation n/e/s/w = where the sitter faces,
-- so n/s footprints are 6w×4h and e/w footprints are 4w×6h.
create table public.seats (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  desk_id uuid not null references public.desks(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 80),
  x int not null check (x >= 0),
  y int not null check (y >= 0),
  orientation text not null default 'n' check (orientation in ('n','e','s','w')),
  chair text not null default '',
  amenities text[] not null default '{}',
  blocked_from timestamptz,
  blocked_to timestamptz,
  created_at timestamptz not null default now()
);
create index seats_desk_idx on public.seats (desk_id);
create index seats_workspace_idx on public.seats (workspace_id);

alter table public.levels enable row level security;
alter table public.offices enable row level security;
alter table public.desks enable row level security;
alter table public.seats enable row level security;

create policy levels_select on public.levels
  for select using (public.is_member_of(workspace_id));
create policy levels_write on public.levels
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

create policy offices_select on public.offices
  for select using (public.is_member_of(workspace_id));
create policy offices_write on public.offices
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

create policy desks_select on public.desks
  for select using (public.is_member_of(workspace_id));
create policy desks_write on public.desks
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

create policy seats_select on public.seats
  for select using (public.is_member_of(workspace_id));
create policy seats_write on public.seats
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));
