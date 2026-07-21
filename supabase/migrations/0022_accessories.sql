-- SPDX-License-Identifier: 0BSD
-- DesKilo accessory catalog + seat assignment (epic #163, issue #166).
-- NOT YET applied to the hosted reference project — the orchestrator
-- applies it after review.
-- Owner/admin-priced seat accessories (monitor, standing desk, ...) that
-- replace the hard-coded seat amenity chips. supplement_cents is the
-- per-half-day supplement (0.5 day = the billing unit), summed per
-- accessory on a seat; whether it is invoiced is a later feature toggle
-- (#170). Deactivate, never delete (mirrors the services catalog, 0014).

create table public.accessories (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  supplement_cents int not null default 0 check (supplement_cents >= 0),
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (workspace_id, name)
);
create index accessories_workspace_idx on public.accessories (workspace_id);

-- Which accessories sit on which seat. workspace_id denormalized for
-- cheap RLS (same pattern as 0003); the trigger below derives it from the
-- seat, so clients cannot spoof it.
create table public.seat_accessories (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  seat_id uuid not null references public.seats(id) on delete cascade,
  accessory_id uuid not null references public.accessories(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (seat_id, accessory_id)
);
create index seat_accessories_workspace_idx on public.seat_accessories (workspace_id);
create index seat_accessories_accessory_idx on public.seat_accessories (accessory_id);

-- Cross-table workspace guard: a join row must link a seat and an
-- accessory of the SAME workspace. Overwrites new.workspace_id from the
-- seat (before-trigger changes are what RLS WITH CHECK sees).
create or replace function public.seat_accessories_same_workspace()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_seat_ws uuid;
  v_accessory_ws uuid;
begin
  select workspace_id into v_seat_ws
    from public.seats where id = new.seat_id;
  select workspace_id into v_accessory_ws
    from public.accessories where id = new.accessory_id;
  if v_seat_ws is null or v_accessory_ws is null
     or v_seat_ws <> v_accessory_ws then
    raise exception 'seat and accessory must belong to the same workspace';
  end if;
  new.workspace_id := v_seat_ws;
  return new;
end;
$$;
revoke execute on function public.seat_accessories_same_workspace() from public, anon, authenticated;

create trigger seat_accessories_same_workspace
before insert or update on public.seat_accessories
for each row execute function public.seat_accessories_same_workspace();

-- RLS: members read; owner + admins write (maintainer decision on #163 —
-- is_admin_of includes owners).
alter table public.accessories enable row level security;
create policy accessories_select on public.accessories
  for select using (public.is_member_of(workspace_id));
create policy accessories_write on public.accessories
  for all using (public.is_admin_of(workspace_id))
  with check (public.is_admin_of(workspace_id));

alter table public.seat_accessories enable row level security;
create policy seat_accessories_select on public.seat_accessories
  for select using (public.is_member_of(workspace_id));
create policy seat_accessories_write on public.seat_accessories
  for all using (public.is_admin_of(workspace_id))
  with check (public.is_admin_of(workspace_id));

-- ---------------------------------------------------------------------
-- Data migration: seed each workspace's catalog from the amenity keys its
-- seats already use, then materialize the seat↔accessory join rows.
-- Known keys get the English display name the editor showed (kSeatAmenities
-- fallbacks — pinned in Dart by AccessorySeed and its test); unknown keys
-- keep the raw key. seats.amenities stays untouched (removal is a later
-- chore; #168 flips the editor to the catalog).
-- ---------------------------------------------------------------------

insert into public.accessories (workspace_id, name)
select distinct
  s.workspace_id,
  case a.key
    when 'monitor' then 'Monitor'
    when 'standing_desk' then 'Standing desk'
    when 'window' then 'Window seat'
    when 'dock' then 'Docking station'
    when 'ergonomic' then 'Ergonomic chair'
    else a.key
  end
from public.seats s
cross join lateral unnest(s.amenities) as a(key)
where char_length(a.key) between 1 and 80
on conflict (workspace_id, name) do nothing;

insert into public.seat_accessories (workspace_id, seat_id, accessory_id)
select s.workspace_id, s.id, acc.id
from public.seats s
cross join lateral unnest(s.amenities) as a(key)
join public.accessories acc
  on acc.workspace_id = s.workspace_id
 and acc.name = case a.key
   when 'monitor' then 'Monitor'
   when 'standing_desk' then 'Standing desk'
   when 'window' then 'Window seat'
   when 'dock' then 'Docking station'
   when 'ergonomic' then 'Ergonomic chair'
   else a.key
 end
on conflict (seat_id, accessory_id) do nothing;
