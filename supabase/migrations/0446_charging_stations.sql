-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0446 (#2631, checkpoint 4) -- a charging station: an EV parking slot has
-- one, and booking the slot books its charger.
--
-- `charging_stations` holds one station per EV slot (connector, power in
-- kW). The slot and its charger are one booking: the slot's exclusion
-- constraint is the charger's, so the charger is free exactly when the slot
-- is, and an EV slot cannot be booked while it has no charging station or
-- its station is out of service (`active` false). A station belongs to an
-- EV slot and to nothing else: a non-EV slot never references a charger,
-- and a slot with a station cannot stop being EV.
--
-- An optional usage fee rides the existing accessory-supplement path: a
-- station may name a priced accessory (`accessory_id`); it is attached to
-- the slot (`seat_accessories`), so the statement bills it as it bills any
-- accessory. No billing code is added.
--
-- Rows are read by the members of the workspace and written with
-- manageSites, like the layout (seat_accessories, 0216).

create table public.charging_stations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  seat_id uuid not null unique references public.seats(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 80),
  connector text not null check (connector in ('type2', 'ccs', 'chademo', 'tesla', 'schuko')),
  power_kw numeric(6, 1) not null check (power_kw > 0 and power_kw <= 1000),
  accessory_id uuid references public.accessories(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
select public.ensure_system_columns('charging_stations');
create index charging_stations_workspace_idx on public.charging_stations (workspace_id);

alter table public.charging_stations enable row level security;
revoke all on public.charging_stations from public, anon;
grant select, insert, update, delete on public.charging_stations to authenticated;
create policy charging_stations_select on public.charging_stations
  for select using (public.is_member_of(workspace_id));
create policy charging_stations_write on public.charging_stations
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));
create policy mcp_delegated_deny on public.charging_stations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- A station sits on an EV slot of its own workspace; its fee accessory is
-- one of that workspace's, and rides the slot as any accessory does.
create or replace function public.charging_stations_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_kind text;
  v_parking text;
begin
  select s.workspace_id, s.resource_kind, s.parking_kind into v_ws, v_kind, v_parking
    from public.seats s where s.id = new.seat_id;
  if v_ws is null then raise exception 'unknown slot'; end if;
  if v_kind <> 'parking' or v_parking <> 'ev' then
    raise exception 'a charging station belongs to an EV parking slot';
  end if;
  new.workspace_id := v_ws;
  if tg_op = 'INSERT' and not public.resource_kind_enabled(v_ws, 'parking') then
    raise exception 'the parking feature is off' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and new.seat_id is distinct from old.seat_id then
    raise exception 'a charging station stays on its slot';
  end if;
  if new.accessory_id is not null and not exists (
       select 1 from public.accessories a
        where a.id = new.accessory_id and a.workspace_id = v_ws) then
    raise exception 'the fee accessory belongs to another workspace';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.charging_stations_guard() from public, anon, authenticated;
create trigger charging_stations_guard
  before insert or update on public.charging_stations
  for each row execute function public.charging_stations_guard();

create or replace function public.charging_stations_fee()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.accessory_id is not null
     and (tg_op = 'DELETE' or new.accessory_id is distinct from old.accessory_id) then
    delete from public.seat_accessories
     where seat_id = old.seat_id and accessory_id = old.accessory_id;
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.accessory_id is not null then
    insert into public.seat_accessories (workspace_id, seat_id, accessory_id)
    values (new.workspace_id, new.seat_id, new.accessory_id)
    on conflict do nothing;
  end if;
  return null;
end;
$fn$;
revoke execute on function public.charging_stations_fee() from public, anon, authenticated;
create trigger charging_stations_fee
  after insert or update or delete on public.charging_stations
  for each row execute function public.charging_stations_fee();

-- A slot with a station stays EV.
create or replace function public.seats_resource_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_area text;
begin
  if tg_op = 'UPDATE' and new.resource_kind is distinct from old.resource_kind then
    raise exception 'the kind of a resource cannot change';
  end if;
  if new.resource_kind <> 'seat' then
    if tg_op = 'INSERT' and not public.resource_kind_enabled(new.workspace_id, new.resource_kind) then
      raise exception 'the % feature is off', public.resource_kind_feature(new.resource_kind)
        using errcode = '42501';
    end if;
    if new.resource_kind = 'room' and new.slot_minutes is null then
      new.slot_minutes := 60;
    elsif new.resource_kind = 'parking' and new.slot_minutes is null then
      new.slot_minutes := 1440;
    end if;
  end if;
  if tg_op = 'INSERT' or new.desk_id is distinct from old.desk_id then
    select o.area_kind into v_area from public.desks d
      join public.offices o on o.id = d.office_id where d.id = new.desk_id;
    if v_area is not null and (new.resource_kind = 'parking') <> (v_area = 'parking') then
      raise exception 'a parking slot sits in a parking area, and only there';
    end if;
  end if;
  if tg_op = 'UPDATE' and new.parking_kind is distinct from old.parking_kind
     and new.parking_kind is distinct from 'ev'
     and exists (select 1 from public.charging_stations c where c.seat_id = new.id) then
    raise exception 'a slot with a charging station stays an EV slot';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.seats_resource_guard() from public, anon, authenticated;

-- An EV slot is booked with its charger: it needs an active charging
-- station, and the slot's own conflict check is the charger's.
create or replace function public.reservations_resource_gate()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_kind text;
  v_parking text;
begin
  if new.seat_id is null then return new; end if;
  select s.resource_kind, s.parking_kind into v_kind, v_parking
    from public.seats s where s.id = new.seat_id;
  if v_kind is not null and v_kind <> 'seat'
     and not public.resource_kind_enabled(new.workspace_id, v_kind) then
    raise exception 'the % feature is off', public.resource_kind_feature(v_kind)
      using errcode = '42501';
  end if;
  if v_parking = 'ev' and not exists (
       select 1 from public.charging_stations c
        where c.seat_id = new.seat_id and c.active) then
    raise exception 'the charging station of this slot is not available';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.reservations_resource_gate() from public, anon, authenticated;

select public.set_deskilo_schema_version(446);
