-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #4293 (G7, cut A): the places of a business form levels - site, zone, aisle, bay, shelf or bin -
-- and each has an address composed from its parents' codes (MAG1-SALES-A03-B02-S4).
--   * `stock_location_kinds.level`: site and the legacy warehouse 1, zone 2, aisle 3, bay 4,
--     shelf and bin 5; counter, kitchen, vehicle, machine and slot stay free-placed. The
--     warehouse is NOT rewritten to site (`stock_place(ws, 'warehouse')`, code MAIN, and the
--     transfer code look it up by that key): it is a legal level-1 root, equivalent to a site.
--   * a place of a level sits only under the level directly above it (`save_stock_location_v1`
--     refuses it, when the place is made or its kind or parent changes - a place made before the
--     levels stays editable).
--   * a code is unique among the places under one parent (it was unique per business, so every
--     existing code stays valid); the INTERNAL path is unique per business (`address_path`, the
--     codes joined by the unit separator chr(31), kept by a trigger for the place and everything
--     below it). The address a person reads joins the codes with the workspace setting
--     `stock.address_separator`; a code that itself holds that character is not refused, so the
--     displayed address is not guaranteed unique - the path is.
--   * the default warehouse (code MAIN, found by `stock_place(ws, 'warehouse')`) stays one per
--     business: a second warehouse cannot be called MAIN, whatever its parent.
--   * a site carries `receives_from_suppliers`; a place below it is `picking` or `reserve`.
-- The barcode of a place stays unique per business.

alter table public.stock_location_kinds add column level int check (level between 1 and 5);
update public.stock_location_kinds set level = case key
  when 'warehouse' then 1 when 'zone' then 2 when 'shelf' then 5 when 'bin' then 5 end;
insert into public.stock_location_kinds (key, virtual, sort_order, level) values
  ('site', false, 5, 1), ('aisle', false, 25, 3), ('bay', false, 27, 4)
on conflict (key) do nothing;

alter table public.stock_locations
  add column receives_from_suppliers boolean not null default true,
  add column pick_role text check (pick_role in ('picking', 'reserve')),
  add column address_path text;

-- the address of every place made so far
with recursive chain (id, path) as (
  select l.id, l.code::text from public.stock_locations l where l.parent_id is null
  union all
  select c.id, chain.path || chr(31) || c.code
    from public.stock_locations c join chain on c.parent_id = chain.id
)
update public.stock_locations l set address_path = chain.path from chain where chain.id = l.id;
alter table public.stock_locations alter column address_path set not null;

alter table public.stock_locations drop constraint stock_locations_workspace_id_code_key;
create unique index stock_locations_sibling_code on public.stock_locations
  (workspace_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), code);
create unique index stock_locations_address on public.stock_locations (workspace_id, address_path);
create unique index stock_locations_one_main_warehouse on public.stock_locations (workspace_id)
  where kind = 'warehouse' and code = 'MAIN';

-- The address of a place is its parent's address and its own code; when it changes, everything
-- below it follows (each child is touched, its own trigger recomposes it and passes it on).
create or replace function public.stock_locations_address() returns trigger
language plpgsql set search_path = public as $fn$
declare
  v_parent text;
begin
  if new.parent_id is null then
    new.address_path := new.code;
  else
    select p.address_path into v_parent from public.stock_locations p where p.id = new.parent_id;
    new.address_path := v_parent || chr(31) || new.code;
  end if;
  return new;
end
$fn$;
revoke execute on function public.stock_locations_address() from public, anon, authenticated;
drop trigger if exists stock_locations_address on public.stock_locations;
create trigger stock_locations_address before insert or update of code, parent_id on public.stock_locations
  for each row execute function public.stock_locations_address();

create or replace function public.stock_locations_address_follow() returns trigger
language plpgsql set search_path = public as $fn$
begin
  update public.stock_locations c set code = c.code where c.parent_id = new.id;
  return null;
end
$fn$;
revoke execute on function public.stock_locations_address_follow() from public, anon, authenticated;
drop trigger if exists stock_locations_address_follow on public.stock_locations;
create trigger stock_locations_address_follow after update on public.stock_locations
  for each row when (old.address_path is distinct from new.address_path)
  execute function public.stock_locations_address_follow();

-- ── the place save, patched with the levels (the live definition keeps what 0847 added) ──
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $levels$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.save_stock_location_v1(uuid, uuid, int, uuid, jsonb)'::regprocedure);
  v_next := v_def;
  v_next := pg_temp.anchor_replace(v_next,
    $o$  v_active boolean;
  v_walk uuid;$o$,
    $n$  v_active boolean;
  v_receives boolean;
  v_pick text;
  v_level int;
  v_plevel int;
  v_walk uuid;$n$);
  if v_next is null then raise exception '0855: anchor 1 of save_stock_location_v1 was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$  v_active := public.stock_config_bool(p_place, 'active', 'active', coalesce(v_old.active, true));
$o$,
    $n$  v_active := public.stock_config_bool(p_place, 'active', 'active', coalesce(v_old.active, true));
  v_receives := public.stock_config_bool(p_place, 'receives_from_suppliers', 'receives_from_suppliers',
                                         coalesce(v_old.receives_from_suppliers, true));
  v_pick := case when p_place ? 'pick_role' then nullif(btrim(coalesce(p_place ->> 'pick_role', '')), '')
                 else v_old.pick_role end;
  if v_pick is not null and v_pick not in ('picking', 'reserve') then
    perform public.stock_config_refuse('pick_role', 'pick_role_unknown');
  end if;
$n$);
  if v_next is null then raise exception '0855: anchor 2 of save_stock_location_v1 was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$  if exists (select 1 from public.stock_locations l where l.workspace_id = p_workspace_id and l.code = v_code
              and l.id is distinct from p_place_id) then
    perform public.stock_config_refuse('code', 'code_duplicate');
  end if;$o$,
    $n$  -- a code is unique among the places under the same parent (the address makes the whole unique)
  if exists (select 1 from public.stock_locations l where l.workspace_id = p_workspace_id and l.code = v_code
              and l.parent_id is not distinct from v_parent and l.id is distinct from p_place_id) then
    perform public.stock_config_refuse('code', 'code_duplicate');
  end if;$n$);
  if v_next is null then raise exception '0855: anchor 3 of save_stock_location_v1 was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$  if p_place_id is not null
     and p_place_id = public.stock_place(p_workspace_id, 'warehouse')$o$,
    $n$  -- the level rule (#4293): a place of a level sits only under the level directly above it, a
  -- site (or the legacy warehouse) at the root. Checked when a place is made or its kind or
  -- parent changes, so a place made before the levels stays editable.
  select k.level into v_level from public.stock_location_kinds k where k.key = v_kind;
  if v_level is not null
     and (p_place_id is null or v_kind is distinct from v_old.kind or v_parent is distinct from v_old.parent_id) then
    if v_parent is null then
      if v_level <> 1 then perform public.stock_config_refuse('parent_id', 'level_parent_missing'); end if;
    else
      select k.level into v_plevel from public.stock_locations l
        join public.stock_location_kinds k on k.key = l.kind where l.id = v_parent
       for share of l;
      -- (the parent is read under a share lock: a concurrent change of its kind holds it for
      -- update, so a child made meanwhile waits and reads the new kind)
      if v_plevel is distinct from v_level - 1 then
        perform public.stock_config_refuse('parent_id', 'level_parent_wrong');
      end if;
    end if;
  end if;
  if p_place_id is not null and v_kind is distinct from v_old.kind
     and exists (select 1 from public.stock_locations c join public.stock_location_kinds ck on ck.key = c.kind
                  where c.parent_id = p_place_id and ck.level is not null and ck.level is distinct from v_level + 1) then
    perform public.stock_config_refuse('kind', 'level_children_wrong');
  end if;
  -- only a site says whether it receives from suppliers, only a place below it is picking or reserve
  if v_level is distinct from 1 then v_receives := true; end if;
  if v_level = 1 then v_pick := null; end if;
  if p_place_id is not null
     and p_place_id = public.stock_place(p_workspace_id, 'warehouse')$n$);
  if v_next is null then raise exception '0855: anchor 4 of save_stock_location_v1 was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$insert into public.stock_locations (workspace_id, parent_id, kind, code, name, barcode, active)
    values (p_workspace_id, v_parent, v_kind, v_code, v_name, v_barcode, v_active)$o$,
    $n$insert into public.stock_locations (workspace_id, parent_id, kind, code, name, barcode, active,
                                        receives_from_suppliers, pick_role)
    values (p_workspace_id, v_parent, v_kind, v_code, v_name, v_barcode, v_active, v_receives, v_pick)$n$);
  if v_next is null then raise exception '0855: anchor 5 of save_stock_location_v1 was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$active = v_active, revision = revision + 1$o$,
    $n$active = v_active, receives_from_suppliers = v_receives, pick_role = v_pick,
           revision = revision + 1$n$);
  if v_next is null then raise exception '0855: anchor 6 of save_stock_location_v1 was not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$levels$;

-- ── the separator the person sees between the levels of an address ───────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.address_separator', 'enum', '"-"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["-",".","/",":"]'::jsonb, 'stock places (#4293)', 'The character shown between the levels of a place address (site, zone, aisle, bay, shelf): MAG1-SALES-A03-B02-S4 with a dash, MAG1.SALES.A03.B02.S4 with a dot. Only how an address is written changes; the places and their codes stay as they are.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(855);
