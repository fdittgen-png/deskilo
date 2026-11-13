-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0747 (#3824, stock S1 of epic #3823) -- the goods ledger: where goods are,
-- in which unit, from which lot, and every movement between two places,
-- behind one move command.
--
--   * Three registries: `stock_units` (the dimensional units and their fixed
--     factors: g, kg, ml, cl, l, piece), `stock_location_kinds` (warehouse,
--     zone, shelf, bin, counter, kitchen, vehicle, machine, slot, and the
--     virtual supplier, customer, loss, opening) and `stock_reasons`.
--   * A catalogue row is an item: `services` gains purchasable, stockable,
--     sellable, its inventory unit, its tracking and its shelf life.
--     `item_units` lists its other units with an exact factor (two whole
--     numbers, never a rounded decimal); `item_codes` binds a code to one
--     unit of one item, unique within a business. `stock_to_inventory` is
--     the one conversion every caller uses; a unit the item does not list
--     is refused (DKG02).
--   * `stock_locations` (a tree), `stock_lots` (the total cost in minor
--     units of the business's currency and the quantity received, so the
--     unit cost is derived), `stock_movements` (append-only: DKG08) and
--     `stock_balances` (per item, lot and place, kept by the movement's own
--     insert; below zero only when the business allows it, DKG03).
--   * `stock_move_v1` (manageStock, while `stockManagement` is on): one
--     request id, one answer. `stock_on_hand_v1`, `stock_movement_trace_v1`
--     and `stock_value_at_v1` (viewStock or manageStock) read it.
--   * The shelf count of 0135: while the feature is off, nothing changes.
--     Switched on, the business gets its four virtual places and "MAIN",
--     and each counted item an opening movement; `services.stock` then
--     mirrors the sum, `apply_stock_on_confirm` writes movements, and an
--     edit of the count is an adjustment to or from the loss place.
--   * The permissions viewStock, manageStock and approveStockAdjustments;
--     the setting stock.allow_negative; the data export carries the ledger.

-- ── the registries ──────────────────────────────────────────────────────
create table public.stock_units (
  code text primary key check (code ~ '^[a-z_]{1,20}$'),
  dimension text not null check (dimension in ('mass', 'volume', 'count')),
  -- the factor to the dimension's base unit (g, ml, piece), as a fraction
  factor_num bigint not null check (factor_num > 0),
  factor_den bigint not null check (factor_den > 0),
  sort_order int not null
);
select public.ensure_system_columns('stock_units');
insert into public.stock_units (code, dimension, factor_num, factor_den, sort_order) values
  ('piece', 'count', 1, 1, 10),
  ('g', 'mass', 1, 1, 20), ('kg', 'mass', 1000, 1, 30),
  ('ml', 'volume', 1, 1, 40), ('cl', 'volume', 10, 1, 50), ('l', 'volume', 1000, 1, 60);

create table public.stock_location_kinds (
  key text primary key check (key ~ '^[a-z_]{1,20}$'),
  virtual boolean not null,
  sort_order int not null
);
select public.ensure_system_columns('stock_location_kinds');
insert into public.stock_location_kinds (key, virtual, sort_order) values
  ('warehouse', false, 10), ('zone', false, 20), ('shelf', false, 30), ('bin', false, 40),
  ('counter', false, 50), ('kitchen', false, 60), ('vehicle', false, 70),
  ('machine', false, 80), ('slot', false, 90),
  ('supplier', true, 100), ('customer', true, 110), ('loss', true, 120), ('opening', true, 130);

create table public.stock_reasons (
  key text primary key check (key ~ '^[a-z_]{1,20}$'),
  sort_order int not null
);
select public.ensure_system_columns('stock_reasons');
insert into public.stock_reasons (key, sort_order) values
  ('receipt', 10), ('transfer', 20), ('sale', 30), ('consumption', 40), ('loss', 50),
  ('adjustment', 60), ('return_in', 70), ('return_out', 80), ('opening', 90);

alter table public.stock_units enable row level security;
alter table public.stock_location_kinds enable row level security;
alter table public.stock_reasons enable row level security;
revoke all on public.stock_units, public.stock_location_kinds, public.stock_reasons
  from public, anon, authenticated;
grant select on public.stock_units, public.stock_location_kinds, public.stock_reasons to authenticated;
create policy stock_units_read on public.stock_units for select to authenticated using (true);
create policy stock_location_kinds_read on public.stock_location_kinds for select to authenticated using (true);
create policy stock_reasons_read on public.stock_reasons for select to authenticated using (true);
create policy mcp_delegated_deny on public.stock_units as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_location_kinds as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_reasons as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the item ────────────────────────────────────────────────────────────
alter table public.services
  add column purchasable boolean not null default false,
  add column stockable boolean not null default false,
  add column sellable boolean not null default true,
  add column inventory_unit text not null default 'piece' references public.stock_units (code),
  add column tracking text not null default 'none'
    check (tracking in ('none', 'lot', 'expiry', 'serial')),
  add column shelf_life_days int check (shelf_life_days is null or shelf_life_days between 1 and 36500);
alter table public.services add constraint services_workspace_id_id unique (workspace_id, id);
comment on column public.services.stockable is
  '#3824: the item is kept in stock. A row with a shelf count (0135) is one.';
-- what had a shelf count was bought and kept on a shelf
update public.services set stockable = true, purchasable = true where stock is not null;

create table public.item_units (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  unit text not null check (char_length(btrim(unit)) between 1 and 30),
  -- one of this unit is factor_num / factor_den of the item's inventory unit
  factor_num bigint not null check (factor_num > 0),
  factor_den bigint not null check (factor_den > 0),
  default_purchase boolean not null default false,
  default_sale boolean not null default false,
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  unique (item_id, unit)
);
select public.ensure_system_columns('item_units');
create unique index item_units_one_purchase on public.item_units (item_id) where default_purchase;
create unique index item_units_one_sale on public.item_units (item_id) where default_sale;

create table public.item_codes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  -- null: the item's inventory unit; else one of its item_units
  unit text,
  code text not null check (code ~ '^[0-9A-Za-z._/-]{1,64}$'),
  kind text not null check (kind in ('gtin', 'own')),
  check (kind <> 'gtin' or code ~ '^[0-9]{8,14}$'),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (item_id, unit) references public.item_units (item_id, unit) on delete cascade,
  unique (workspace_id, code)
);
select public.ensure_system_columns('item_codes');

-- ── places, lots, movements, balances ──────────────────────────────────
create table public.stock_locations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  parent_id uuid,
  kind text not null references public.stock_location_kinds (key),
  code text not null check (code ~ '^[0-9A-Za-z._/-]{1,40}$'),
  name text not null default '' check (char_length(name) <= 120),
  barcode text check (barcode is null or barcode ~ '^[0-9A-Za-z._/-]{1,64}$'),
  active boolean not null default true,
  unique (workspace_id, id),
  unique (workspace_id, code),
  foreign key (workspace_id, parent_id) references public.stock_locations (workspace_id, id)
);
select public.ensure_system_columns('stock_locations');
create unique index stock_locations_barcode on public.stock_locations (workspace_id, barcode)
  where barcode is not null;
-- one place of each virtual kind per business (the kinds the registry marks virtual)
create unique index stock_locations_one_virtual on public.stock_locations (workspace_id, kind)
  where kind in ('supplier', 'customer', 'loss', 'opening');

create table public.stock_lots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  lot_code text not null default '' check (char_length(lot_code) <= 64),
  expires_on date,
  -- in minor units of the business's own currency; the unit cost is
  -- total_cost_minor / quantity_received, so rounding loses nothing
  total_cost_minor bigint not null check (total_cost_minor >= 0),
  quantity_received numeric(18, 6) not null check (quantity_received > 0),
  source_currency text check (source_currency is null or source_currency ~ '^[A-Z]{3}$'),
  source_rate numeric check (source_rate is null or source_rate > 0),
  check ((source_currency is null) = (source_rate is null)),
  receipt_line_id uuid references public.purchase_order_receipt_lines (id) on delete set null,
  label_code text check (label_code is null or label_code ~ '^[0-9A-Za-z._/-]{1,64}$'),
  unique (workspace_id, id),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_lots');
create unique index stock_lots_label on public.stock_lots (workspace_id, label_code)
  where label_code is not null;
create index stock_lots_item on public.stock_lots (item_id);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  lot_id uuid,
  from_location_id uuid not null,
  to_location_id uuid not null,
  check (from_location_id <> to_location_id),
  -- in the item's inventory unit
  quantity numeric(18, 6) not null check (quantity > 0),
  -- what the person entered: "2" "carton"
  entered_unit text not null,
  entered_quantity numeric(18, 6) not null check (entered_quantity > 0),
  occurred_at timestamptz not null,
  reason text not null references public.stock_reasons (key),
  -- minor units of the business's currency per inventory unit, frozen
  unit_cost numeric,
  actor_member_id uuid,
  request_id uuid not null,
  line_no int not null check (line_no between 1 and 200),
  part int not null default 1 check (part >= 1),
  -- what caused it; history names its cause and outlives it
  receipt_line_id uuid,
  purchase_line_id uuid,
  event_id uuid,
  invoice_id uuid,
  unique (workspace_id, request_id, line_no, part),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade,
  foreign key (workspace_id, from_location_id) references public.stock_locations (workspace_id, id) on delete cascade,
  foreign key (workspace_id, to_location_id) references public.stock_locations (workspace_id, id) on delete cascade,
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('stock_movements');
create index stock_movements_item on public.stock_movements (workspace_id, item_id, occurred_at);
create index stock_movements_lot on public.stock_movements (lot_id) where lot_id is not null;

create table public.stock_balances (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  lot_id uuid,
  location_id uuid not null,
  quantity numeric(18, 6) not null default 0,
  unique nulls not distinct (item_id, lot_id, location_id),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade,
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_balances');
create index stock_balances_location on public.stock_balances (workspace_id, location_id);

-- Read by whoever sees or moves the stock, while the feature is on; written
-- only by the functions below.
alter table public.item_units enable row level security;
alter table public.item_codes enable row level security;
alter table public.stock_locations enable row level security;
alter table public.stock_lots enable row level security;
alter table public.stock_movements enable row level security;
alter table public.stock_balances enable row level security;
revoke all on public.item_units, public.item_codes, public.stock_locations, public.stock_lots,
  public.stock_movements, public.stock_balances from public, anon, authenticated;
grant select on public.item_units, public.item_codes, public.stock_locations, public.stock_lots,
  public.stock_movements, public.stock_balances to authenticated;
create policy item_units_select on public.item_units for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy item_codes_select on public.item_codes for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy stock_locations_select on public.stock_locations for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy stock_lots_select on public.stock_lots for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy stock_movements_select on public.stock_movements for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy stock_balances_select on public.stock_balances for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy mcp_delegated_deny on public.item_units as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.item_codes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_locations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_lots as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_movements as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_balances as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── a movement is history ───────────────────────────────────────────────
-- Never edited; deleted only with its business (or its item, place or lot
-- while the business itself goes).
create or replace function public.stock_movements_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'a stock movement is never edited or deleted: a correction is a movement back'
    using errcode = 'DKG08';
end;
$fn$;
revoke execute on function public.stock_movements_append_only() from public, anon, authenticated;
create trigger stock_movements_append_only before update or delete on public.stock_movements
  for each row execute function public.stock_movements_append_only();

-- ── the conversion ──────────────────────────────────────────────────────
-- p_quantity of p_unit, in the item's inventory unit: the inventory unit
-- itself, a unit the item lists (its exact factor), or a unit of the same
-- dimension (the fixed table). Anything else is refused.
create or replace function public.stock_to_inventory(p_item_id uuid, p_unit text, p_quantity numeric)
returns numeric language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inventory text;
  v_num bigint;
  v_den bigint;
  v_from public.stock_units;
  v_to public.stock_units;
begin
  select inventory_unit into v_inventory from public.services where id = p_item_id;
  if v_inventory is null then
    raise exception 'unknown item' using errcode = 'DKG04';
  end if;
  if p_unit is null or p_unit = v_inventory then
    return p_quantity;
  end if;
  select factor_num, factor_den into v_num, v_den
    from public.item_units where item_id = p_item_id and unit = p_unit;
  if v_num is not null then
    return p_quantity * v_num / v_den;
  end if;
  select * into v_from from public.stock_units where code = p_unit;
  select * into v_to from public.stock_units where code = v_inventory;
  if v_from.code is not null and v_to.code is not null and v_from.dimension = v_to.dimension then
    return p_quantity * v_from.factor_num * v_to.factor_den / (v_from.factor_den * v_to.factor_num);
  end if;
  raise exception 'the item does not list the unit %', p_unit using errcode = 'DKG02';
end;
$fn$;
revoke execute on function public.stock_to_inventory(uuid, text, numeric) from public, anon, authenticated;

-- ── one movement, and what it moves ─────────────────────────────────────
create or replace function public.stock_place(p_workspace_id uuid, p_kind text)
returns uuid language sql stable security definer set search_path = public as $fn$
  select id from public.stock_locations
   where workspace_id = p_workspace_id
     and kind = p_kind
     and (p_kind <> 'warehouse' or code = 'MAIN')
   order by created_datetime
   limit 1;
$fn$;
revoke execute on function public.stock_place(uuid, text) from public, anon, authenticated;

create or replace function public.stock_place_is_virtual(p_location_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select k.virtual from public.stock_locations l join public.stock_location_kinds k on k.key = l.kind
   where l.id = p_location_id;
$fn$;
revoke execute on function public.stock_place_is_virtual(uuid) from public, anon, authenticated;

-- What leaves p_location_id of p_item_id: the lot-less goods first, then the
-- lots that expire first, then the oldest. A shortfall stays lot-less, and
-- the balance check decides whether it may go below zero.
create or replace function public.stock_take(p_workspace_id uuid, p_item_id uuid, p_location_id uuid, p_quantity numeric)
returns table (lot_id uuid, quantity numeric) language plpgsql stable security definer set search_path = public as $fn$
declare
  v_left numeric := p_quantity;
  r record;
begin
  for r in
    select b.lot_id as lot, b.quantity as q
      from public.stock_balances b left join public.stock_lots l on l.id = b.lot_id
     where b.workspace_id = p_workspace_id and b.item_id = p_item_id
       and b.location_id = p_location_id and b.quantity > 0
     order by (b.lot_id is not null), l.expires_on nulls last, l.created_datetime
  loop
    exit when v_left <= 0;
    lot_id := r.lot;
    quantity := least(r.q, v_left);
    v_left := v_left - quantity;
    return next;
  end loop;
  if v_left > 0 then
    lot_id := null;
    quantity := v_left;
    return next;
  end if;
end;
$fn$;
revoke execute on function public.stock_take(uuid, uuid, uuid, numeric) from public, anon, authenticated;

-- The balances follow the movement in the same transaction; a real place
-- does not go below zero unless the business allows it; the shelf count
-- mirrors the sum over the real places.
create or replace function public.stock_movements_apply()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_left numeric;
begin
  insert into public.stock_balances (workspace_id, item_id, lot_id, location_id, quantity)
  values (new.workspace_id, new.item_id, new.lot_id, new.from_location_id, -new.quantity),
         (new.workspace_id, new.item_id, new.lot_id, new.to_location_id, new.quantity)
  on conflict (item_id, lot_id, location_id)
  do update set quantity = public.stock_balances.quantity + excluded.quantity;

  if not public.stock_place_is_virtual(new.from_location_id) then
    select b.quantity into v_left from public.stock_balances b
     where b.item_id = new.item_id and b.lot_id is not distinct from new.lot_id
       and b.location_id = new.from_location_id;
    if v_left < 0 and coalesce((public.setting_value(new.workspace_id, 'stock.allow_negative') #>> '{}')::boolean, false) = false then
      raise exception 'not that much on hand at this place' using errcode = 'DKG03';
    end if;
  end if;

  if coalesce(current_setting('deskilo.stock_count_edit', true), '') <> 'on' then
    -- the mirror is not an edit of the count
    perform set_config('deskilo.stock_count_edit', 'on', true);
    update public.services s
       set stock = greatest(0, floor(coalesce((
             select sum(b.quantity) from public.stock_balances b
               join public.stock_locations l on l.id = b.location_id
               join public.stock_location_kinds k on k.key = l.kind
              where b.item_id = new.item_id and not k.virtual), 0)))::int
     where s.id = new.item_id;
    perform set_config('deskilo.stock_count_edit', '', true);
  end if;
  return null;
end;
$fn$;
revoke execute on function public.stock_movements_apply() from public, anon, authenticated;
create trigger stock_movements_apply after insert on public.stock_movements
  for each row execute function public.stock_movements_apply();

-- One movement, written by the functions below and nowhere else.
create or replace function public.stock_record(
  p_workspace_id uuid, p_item_id uuid, p_lot_id uuid, p_from uuid, p_to uuid,
  p_quantity numeric, p_entered_unit text, p_entered_quantity numeric,
  p_occurred_at timestamptz, p_reason text, p_actor uuid, p_request_id uuid,
  p_line_no int, p_part int, p_links jsonb
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_cost numeric;
begin
  if p_lot_id is not null then
    select total_cost_minor::numeric / quantity_received into v_cost
      from public.stock_lots where id = p_lot_id;
  end if;
  insert into public.stock_movements
    (workspace_id, item_id, lot_id, from_location_id, to_location_id, quantity,
     entered_unit, entered_quantity, occurred_at, reason, unit_cost, actor_member_id,
     request_id, line_no, part, receipt_line_id, purchase_line_id, event_id, invoice_id)
  values
    (p_workspace_id, p_item_id, p_lot_id, p_from, p_to, p_quantity,
     p_entered_unit, p_entered_quantity, p_occurred_at, p_reason, v_cost, p_actor,
     p_request_id, p_line_no, p_part,
     nullif(p_links ->> 'receipt_line_id', '')::uuid, nullif(p_links ->> 'purchase_line_id', '')::uuid,
     nullif(p_links ->> 'event_id', '')::uuid, nullif(p_links ->> 'invoice_id', '')::uuid)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamptz, text, uuid, uuid, int, int, jsonb)
  from public, anon, authenticated;

-- ── the feature switched on ─────────────────────────────────────────────
-- The four virtual places and MAIN; each item with a shelf count gets the
-- opening movement that makes the ledger say what the shelf says. Run again
-- after the feature was off a while, it opens only the difference.
create or replace function public.stock_open(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  k text;
  r record;
  v_main uuid;
  v_opening uuid;
  v_diff numeric;
begin
  foreach k in array array['supplier', 'customer', 'loss', 'opening'] loop
    insert into public.stock_locations (workspace_id, kind, code)
    values (p_workspace_id, k, upper(k))
    on conflict do nothing;
  end loop;
  if public.stock_place(p_workspace_id, 'warehouse') is null then
    insert into public.stock_locations (workspace_id, kind, code)
    values (p_workspace_id, 'warehouse', 'MAIN')
    on conflict do nothing;
  end if;
  v_main := public.stock_place(p_workspace_id, 'warehouse');
  v_opening := public.stock_place(p_workspace_id, 'opening');
  for r in
    select s.id, s.inventory_unit, coalesce(s.stock, 0) as counted,
           coalesce((select sum(b.quantity) from public.stock_balances b
                       join public.stock_locations l on l.id = b.location_id
                       join public.stock_location_kinds kk on kk.key = l.kind
                      where b.item_id = s.id and not kk.virtual), 0) as ledger
      from public.services s
     where s.workspace_id = p_workspace_id and (s.stockable or s.stock is not null)
  loop
    update public.services set stockable = true where id = r.id and not stockable;
    v_diff := r.counted - floor(r.ledger);
    if v_diff > 0 then
      perform public.stock_record(p_workspace_id, r.id, null, v_opening, v_main, v_diff,
        r.inventory_unit, v_diff, now(), 'opening', null, gen_random_uuid(), 1, 1, '{}'::jsonb);
    elsif v_diff < 0 then
      perform public.stock_record(p_workspace_id, r.id, null, v_main, v_opening, -v_diff,
        r.inventory_unit, -v_diff, now(), 'opening', null, gen_random_uuid(), 1, 1, '{}'::jsonb);
    end if;
  end loop;
end;
$fn$;
revoke execute on function public.stock_open(uuid) from public, anon, authenticated;

create or replace function public.workspaces_stock_open()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if public.feature_effective(new.id, 'stockManagement')
     and (tg_op = 'INSERT'
          or not (public.feature_effective_in(old.feature_flags, 'stockManagement')
                  and public.feature_available_in(old.country_code, 'stockManagement'))) then
    perform public.stock_open(new.id);
  end if;
  return null;
end;
$fn$;
revoke execute on function public.workspaces_stock_open() from public, anon, authenticated;
create trigger workspaces_stock_open after insert or update of feature_flags, country_code
  on public.workspaces for each row execute function public.workspaces_stock_open();

-- ── the shelf count, while the ledger is on ─────────────────────────────
-- A row with a count is kept in stock. A new row's count is its opening; an
-- edited count is an adjustment to or from the loss place, so the count
-- keeps mirroring the ledger.
create or replace function public.services_stock_ledger_before()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_diff numeric;
  v_main uuid;
  v_loss uuid;
  v_req uuid := gen_random_uuid();
  v_part int := 0;
  t record;
begin
  if new.stock is not null then new.stockable := true; end if;
  if tg_op = 'INSERT' then return new; end if;
  if new.stock is not distinct from old.stock
     or coalesce(current_setting('deskilo.stock_count_edit', true), '') = 'on'
     or not public.feature_effective(new.workspace_id, 'stockManagement') then
    return new;
  end if;
  v_diff := coalesce(new.stock, 0) - coalesce(old.stock, 0);
  v_main := public.stock_place(new.workspace_id, 'warehouse');
  v_loss := public.stock_place(new.workspace_id, 'loss');
  perform set_config('deskilo.stock_count_edit', 'on', true);
  if v_diff > 0 then
    perform public.stock_record(new.workspace_id, new.id, null, v_loss, v_main, v_diff,
      new.inventory_unit, v_diff, now(), 'adjustment', null, v_req, 1, 1, '{}'::jsonb);
  elsif v_diff < 0 then
    for t in select * from public.stock_take(new.workspace_id, new.id, v_main, -v_diff) loop
      v_part := v_part + 1;
      perform public.stock_record(new.workspace_id, new.id, t.lot_id, v_main, v_loss, t.quantity,
        new.inventory_unit, t.quantity, now(), 'adjustment', null, v_req, 1, v_part, '{}'::jsonb);
    end loop;
  end if;
  perform set_config('deskilo.stock_count_edit', '', true);
  return new;
end;
$fn$;
revoke execute on function public.services_stock_ledger_before() from public, anon, authenticated;
create trigger services_stock_ledger_before before insert or update of stock on public.services
  for each row execute function public.services_stock_ledger_before();

create or replace function public.services_stock_ledger_after()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if new.stock is not null and new.stock > 0
     and public.feature_effective(new.workspace_id, 'stockManagement') then
    perform public.stock_record(new.workspace_id, new.id, null,
      public.stock_place(new.workspace_id, 'opening'), public.stock_place(new.workspace_id, 'warehouse'),
      new.stock, new.inventory_unit, new.stock, now(), 'opening', null, gen_random_uuid(), 1, 1, '{}'::jsonb);
  end if;
  return null;
end;
$fn$;
revoke execute on function public.services_stock_ledger_after() from public, anon, authenticated;
create trigger services_stock_ledger_after after insert on public.services
  for each row execute function public.services_stock_ledger_after();

-- An item with movements is history too: it is deactivated, not deleted.
create or replace function public.services_keep_stock_history()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if exists (select 1 from public.stock_movements m where m.item_id = old.id)
     and exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    raise exception 'this item has stock movements, which are kept: deactivate it instead'
      using errcode = 'DKG08';
  end if;
  return old;
end;
$fn$;
revoke execute on function public.services_keep_stock_history() from public, anon, authenticated;
create trigger services_keep_stock_history before delete on public.services
  for each row execute function public.services_keep_stock_history();

-- 0135, restated whole: while the ledger is off, exactly as before; while
-- it is on, a confirmed supply is a receipt into MAIN and a confirmed
-- charge a sale out of MAIN (what is there, as the count never went below
-- zero), each linked to its event.
create or replace function public.apply_stock_on_confirm()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_supply jsonb;
  v_service_id uuid;
  v_qty int;
  v_ledger boolean;
  v_unit text;
  v_main uuid;
  v_part int := 0;
  v_left numeric;
  t record;
begin
  if new.status <> 'confirmed' or old.status = 'confirmed' then return new; end if;
  v_ledger := public.feature_effective(new.workspace_id, 'stockManagement');
  if new.type = 'expense' and new.payload ? 'supply' then
    v_supply := new.payload -> 'supply';
    v_qty := coalesce((v_supply ->> 'quantity')::int, 0);
    v_service_id := nullif(v_supply ->> 'service_id', '')::uuid;
    if v_service_id is null then
      select id into v_service_id from public.services
        where workspace_id = new.workspace_id
          and lower(name) = lower(v_supply ->> 'name')
        limit 1;
    end if;
    if v_service_id is null then
      insert into public.services (workspace_id, name, price_cents, active, stock, purchasable, stockable)
      values (new.workspace_id, v_supply ->> 'name',
              coalesce((v_supply ->> 'unit_price_cents')::int, 0), true,
              case when v_ledger then 0 else v_qty end, true, true)
      returning id into v_service_id;
    elsif v_ledger then
      update public.services
         set active = true, purchasable = true, stockable = true,
             price_cents = coalesce((v_supply ->> 'unit_price_cents')::int, price_cents)
       where id = v_service_id;
    else
      update public.services
         set stock = coalesce(stock, 0) + v_qty,
             active = true,
             price_cents = coalesce((v_supply ->> 'unit_price_cents')::int, price_cents)
       where id = v_service_id;
    end if;
    if v_ledger and v_qty > 0 then
      select inventory_unit into v_unit from public.services where id = v_service_id;
      perform public.stock_record(new.workspace_id, v_service_id, null,
        public.stock_place(new.workspace_id, 'supplier'), public.stock_place(new.workspace_id, 'warehouse'),
        v_qty, v_unit, v_qty, now(), 'receipt', new.actor_member_id, new.id, 1, 1,
        jsonb_build_object('event_id', new.id));
    end if;
    update public.events
       set payload = payload || jsonb_build_object('supply',
             v_supply || jsonb_build_object('service_id', v_service_id))
     where id = new.id;
  elsif new.type = 'service_charge' then
    v_service_id := nullif(new.payload ->> 'service_id', '')::uuid;
    v_qty := coalesce((new.payload ->> 'quantity')::int, 0);
    if v_ledger and exists (select 1 from public.services s where s.id = v_service_id and s.stockable) then
      select inventory_unit into v_unit from public.services where id = v_service_id;
      v_main := public.stock_place(new.workspace_id, 'warehouse');
      -- what is there, as the count never went below zero
      select least(v_qty, coalesce(sum(b.quantity), 0)) into v_left from public.stock_balances b
       where b.item_id = v_service_id and b.location_id = v_main and b.quantity > 0;
      if v_left > 0 then
        for t in select * from public.stock_take(new.workspace_id, v_service_id, v_main, v_left) loop
          v_part := v_part + 1;
          perform public.stock_record(new.workspace_id, v_service_id, t.lot_id, v_main,
            public.stock_place(new.workspace_id, 'customer'), t.quantity, v_unit, t.quantity, now(),
            'sale', new.actor_member_id, new.id, 1, v_part, jsonb_build_object('event_id', new.id));
        end loop;
      end if;
    elsif not v_ledger then
      update public.services
         set stock = greatest(0, stock - v_qty)
       where id = v_service_id
         and stock is not null;
    end if;
  end if;
  return new;
end;
$fn$;

revoke execute on function public.apply_stock_on_confirm() from public, anon;

-- ── the move command ────────────────────────────────────────────────────
-- Lines: [{item_id, quantity, unit?, from, to, lot_id?, new_lot?: {code,
-- expires_on, total_cost_minor, source_currency, source_rate}}], 1 to 200.
-- Links: {receipt_line_id, purchase_line_id, event_id, invoice_id}, each of
-- this business. A request id answers the same twice and refuses another
-- request (DKG07).
create or replace function public.stock_move_v1(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_reason text,
  p_occurred_at timestamptz default null, p_links jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done public.purchase_requests;
  v_at timestamptz := coalesce(p_occurred_at, now());
  v_links jsonb := coalesce(p_links, '{}'::jsonb);
  e jsonb;
  v_no int := 0;
  v_item public.services;
  v_from public.stock_locations;
  v_to public.stock_locations;
  v_entered numeric;
  v_unit text;
  v_qty numeric;
  v_lot uuid;
  v_part int;
  v_out jsonb := '[]'::jsonb;
  v_id uuid;
  t record;
begin
  select id into v_me from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to move stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'stock management is off' using errcode = 'DKG01';
  end if;
  if p_request_id is null
     or not exists (select 1 from public.stock_reasons where key = p_reason)
     or coalesce(jsonb_typeof(p_lines), '') <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 200
     or jsonb_typeof(v_links) <> 'object'
     or v_at > now() + interval '5 minutes' then
    raise exception 'a move has a request id, a known reason, a past time and 1 to 200 lines'
      using errcode = 'DKG07';
  end if;
  if (v_links ? 'receipt_line_id' and not exists (select 1 from public.purchase_order_receipt_lines x
        where x.id = nullif(v_links ->> 'receipt_line_id', '')::uuid and x.workspace_id = p_workspace_id))
     or (v_links ? 'purchase_line_id' and not exists (select 1 from public.purchase_lines x
        where x.id = nullif(v_links ->> 'purchase_line_id', '')::uuid and x.workspace_id = p_workspace_id))
     or (v_links ? 'event_id' and not exists (select 1 from public.events x
        where x.id = nullif(v_links ->> 'event_id', '')::uuid and x.workspace_id = p_workspace_id))
     or (v_links ? 'invoice_id' and not exists (select 1 from public.invoices x
        where x.id = nullif(v_links ->> 'invoice_id', '')::uuid and x.workspace_id = p_workspace_id)) then
    raise exception 'a link names a record of another business or none' using errcode = 'DKG07';
  end if;

  v_digest := md5(p_reason || '|' || coalesce(p_occurred_at::text, '') || '|' || p_lines::text
                  || '|' || v_links::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'stock_move' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result;
  end if;

  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    select * into v_item from public.services
     where id = nullif(e ->> 'item_id', '')::uuid and workspace_id = p_workspace_id and stockable;
    if v_item.id is null then
      raise exception 'line %: not a stock item of this business', v_no using errcode = 'DKG04';
    end if;
    select * into v_from from public.stock_locations
     where id = nullif(e ->> 'from', '')::uuid and workspace_id = p_workspace_id and active;
    select * into v_to from public.stock_locations
     where id = nullif(e ->> 'to', '')::uuid and workspace_id = p_workspace_id and active;
    if v_from.id is null or v_to.id is null or v_from.id = v_to.id then
      raise exception 'line %: a move goes from one place of this business to another', v_no
        using errcode = 'DKG05';
    end if;
    v_entered := nullif(e ->> 'quantity', '')::numeric;
    if v_entered is null or v_entered <= 0 then
      raise exception 'line %: a quantity above zero', v_no using errcode = 'DKG07';
    end if;
    v_unit := coalesce(nullif(e ->> 'unit', ''), v_item.inventory_unit);
    v_qty := public.stock_to_inventory(v_item.id, v_unit, v_entered);

    v_lot := nullif(e ->> 'lot_id', '')::uuid;
    if v_lot is not null and not exists (select 1 from public.stock_lots
         where id = v_lot and workspace_id = p_workspace_id and item_id = v_item.id) then
      raise exception 'line %: the lot is not of this item', v_no using errcode = 'DKG06';
    end if;
    if e ? 'new_lot' then
      if v_lot is not null or not public.stock_place_is_virtual(v_from.id)
         or jsonb_typeof(e -> 'new_lot') <> 'object'
         or nullif(e -> 'new_lot' ->> 'total_cost_minor', '') is null then
        raise exception 'line %: a new lot arrives from outside, with its cost', v_no using errcode = 'DKG06';
      end if;
      insert into public.stock_lots (workspace_id, item_id, lot_code, expires_on, total_cost_minor,
                                     quantity_received, source_currency, source_rate, receipt_line_id)
      values (p_workspace_id, v_item.id, coalesce(e -> 'new_lot' ->> 'code', ''),
              nullif(e -> 'new_lot' ->> 'expires_on', '')::date,
              (e -> 'new_lot' ->> 'total_cost_minor')::bigint, v_qty,
              nullif(e -> 'new_lot' ->> 'source_currency', ''),
              nullif(e -> 'new_lot' ->> 'source_rate', '')::numeric,
              nullif(v_links ->> 'receipt_line_id', '')::uuid)
      returning id into v_lot;
    end if;

    if v_item.tracking <> 'none' and v_lot is null then
      raise exception 'line %: this item is tracked by lot', v_no using errcode = 'DKG06';
    end if;

    v_part := 0;
    if v_lot is null and not public.stock_place_is_virtual(v_from.id) then
      for t in select * from public.stock_take(p_workspace_id, v_item.id, v_from.id, v_qty) loop
        v_part := v_part + 1;
        v_id := public.stock_record(p_workspace_id, v_item.id, t.lot_id, v_from.id, v_to.id, t.quantity,
          v_unit, v_entered, v_at, p_reason, v_me, p_request_id, v_no, v_part, v_links);
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'line_no', v_no,
          'part', v_part, 'item_id', v_item.id, 'lot_id', t.lot_id, 'quantity', t.quantity));
      end loop;
    else
      v_id := public.stock_record(p_workspace_id, v_item.id, v_lot, v_from.id, v_to.id, v_qty,
        v_unit, v_entered, v_at, p_reason, v_me, p_request_id, v_no, 1, v_links);
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'line_no', v_no,
        'part', 1, 'item_id', v_item.id, 'lot_id', v_lot, 'quantity', v_qty));
    end if;
  end loop;

  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'stock_move', v_digest,
          jsonb_build_object('request_id', p_request_id, 'movements', v_out))
  returning result into v_out;
  return v_out;
end;
$fn$;
revoke execute on function public.stock_move_v1(uuid, uuid, jsonb, text, timestamptz, jsonb) from public, anon;
grant execute on function public.stock_move_v1(uuid, uuid, jsonb, text, timestamptz, jsonb) to authenticated;

-- ── reading the ledger ─────────────────────────────────────────────────
create or replace function public.stock_reader(p_workspace_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if not exists (select 1 from public.members m where m.workspace_id = p_workspace_id
                   and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock')
             or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'stock management is off' using errcode = 'DKG01';
  end if;
end;
$fn$;
revoke execute on function public.stock_reader(uuid) from public, anon, authenticated;

-- What is on hand at the real places, by item, lot and place.
create or replace function public.stock_on_hand_v1(
  p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.stock_reader(p_workspace_id);
  return coalesce((
    select jsonb_agg(jsonb_build_object('item_id', b.item_id, 'lot_id', b.lot_id,
             'location_id', b.location_id, 'quantity', b.quantity, 'unit', s.inventory_unit)
             order by s.name, l.code, b.lot_id)
      from public.stock_balances b
      join public.services s on s.id = b.item_id
      join public.stock_locations l on l.id = b.location_id
      join public.stock_location_kinds k on k.key = l.kind
     where b.workspace_id = p_workspace_id and not k.virtual and b.quantity <> 0
       and (p_item_id is null or b.item_id = p_item_id)
       and (p_location_id is null or b.location_id = p_location_id)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.stock_on_hand_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.stock_on_hand_v1(uuid, uuid, uuid) to authenticated;

-- A movement with what caused it, its lot, and every movement of that lot:
-- where each unit of it went.
create or replace function public.stock_movement_trace_v1(p_workspace_id uuid, p_movement_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  m public.stock_movements;
begin
  perform public.stock_reader(p_workspace_id);
  select * into m from public.stock_movements where id = p_movement_id and workspace_id = p_workspace_id;
  if m.id is null then
    raise exception 'unknown movement' using errcode = 'DKG07';
  end if;
  return jsonb_build_object(
    'movement', to_jsonb(m) - public.system_column_names(),
    'lot', (select to_jsonb(l) - public.system_column_names() from public.stock_lots l where l.id = m.lot_id),
    'lot_movements', case when m.lot_id is null then '[]'::jsonb else coalesce((
      select jsonb_agg(to_jsonb(x) - public.system_column_names() order by x.occurred_at, x.line_no, x.part)
        from public.stock_movements x where x.lot_id = m.lot_id), '[]'::jsonb) end);
end;
$fn$;
revoke execute on function public.stock_movement_trace_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_movement_trace_v1(uuid, uuid) to authenticated;

-- The value on hand at a moment: the movements up to it, per item and lot,
-- at the lot's cost, in minor units of the business's currency. Goods
-- without a lot have no cost yet: their value is null, outside the total.
create or replace function public.stock_value_at_v1(p_workspace_id uuid, p_at timestamptz)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rows jsonb;
begin
  perform public.stock_reader(p_workspace_id);
  with q as (
    select m.item_id, m.lot_id,
           sum(case when not kt.virtual then m.quantity else 0 end)
         - sum(case when not kf.virtual then m.quantity else 0 end) as quantity
      from public.stock_movements m
      join public.stock_locations lf on lf.id = m.from_location_id
      join public.stock_location_kinds kf on kf.key = lf.kind
      join public.stock_locations lt on lt.id = m.to_location_id
      join public.stock_location_kinds kt on kt.key = lt.kind
     where m.workspace_id = p_workspace_id and m.occurred_at <= coalesce(p_at, now())
     group by m.item_id, m.lot_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'item_id', q.item_id, 'lot_id', q.lot_id, 'quantity', q.quantity,
           'unit_cost', l.total_cost_minor::numeric / l.quantity_received,
           'value_minor', round(q.quantity * l.total_cost_minor / l.quantity_received))
           order by q.item_id, q.lot_id), '[]'::jsonb)
    into v_rows
    from q left join public.stock_lots l on l.id = q.lot_id
   where q.quantity <> 0;
  return jsonb_build_object(
    'at', coalesce(p_at, now()),
    'items', v_rows,
    'total_minor', coalesce((select sum((r ->> 'value_minor')::numeric)
                               from jsonb_array_elements(v_rows) r
                              where r ->> 'value_minor' is not null), 0));
end;
$fn$;
revoke execute on function public.stock_value_at_v1(uuid, timestamptz) from public, anon;
grant execute on function public.stock_value_at_v1(uuid, timestamptz) to authenticated;

-- ── permissions ────────────────────────────────────────────────────────
-- Not admin defaults: an owner and a co-owner hold them; a role gives them.
create or replace function public.role_permission_catalog()
returns text[] language sql immutable as $$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd','viewAnalytics',
    'useMessages','makeReservations','viewCalendar','viewDirectory',
    'viewMyMoney','viewDocuments','managePurchases','recordOutgoingPayments',
    'manageLease','managePrivacy','viewStock','manageStock','approveStockAdjustments'];
$$;
revoke execute on function public.role_permission_catalog() from public, anon;

-- ── whether stock may go below zero ────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.allow_negative', 'bool', 'false'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'stock_move_v1 (#3824)', 'Whether a move may leave less than nothing at a place. Off: the move is refused with its code and nothing moves. On: it is recorded and the place shows a negative quantity until goods arrive. The shelf count of a catalogue item never shows less than zero.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the data export carries the ledger ─────────────────────────────────
-- Restated whole from 0685 with the six stock tables; a refusal carries
-- DKN01 (#3821).
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'plans', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(747);
