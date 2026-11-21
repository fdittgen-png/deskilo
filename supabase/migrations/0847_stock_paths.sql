-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (a business gains the marker of its first stock activation, a place kind and
--  two tables; the legacy sale bridge no longer clips and the generic move
--  validates its reason; every existing movement, balance and amount is unchanged)
--
-- #4170 (A) -- one authoritative stock path: transfers, take-out and loss, and
-- a legacy bridge that tells the truth.
--
--   * LIFECYCLE. `workspaces.stock_initialized_at` is set once, at the FIRST
--     activation of stockManagement, when the old shelf count is imported
--     exactly once. Switching the feature off keeps every quantity and
--     movement; switching it on again resumes the ledger and reconciles
--     nothing from a rounded counter. Once initialized, `services.stock` is a
--     read-only mirror: a client write of it is refused (DKG13), the ledger's
--     own mirror update is not.
--   * THE LEGACY BRIDGE (apply_stock_on_confirm). A confirmed sale takes from
--     MAIN and the places inside it, exactly, never clipped: when they hold
--     less, the confirmation is refused with the named code (DKG03) and what is
--     there. The same setting as the ledger's (`stock.allow_negative`, off by
--     default) may let an untracked item go below zero; a lot never does.
--   * ONE PATH. `stock_apply_lines` is the single internal function that turns
--     lines into movements: it locks every item of the request in id order
--     before anything else (two opposing multi-item requests cannot deadlock),
--     checks the reason against the places (a receipt comes from a supplier, a
--     transfer is between real places of one site, a sale or a return needs its
--     commercial source, consumption and loss go to the loss place...), flags an
--     expired lot, and answers each part. `stock_move_v1` keeps its signature
--     and calls it; the typed commands call it too.
--   * TYPED COMMANDS (manageStock, a native session, the ledger on):
--     stock_transfer_v1 (one step, within a site), stock_transfer_load_v1 and
--     stock_transfer_receive_v1 (two steps between sites, through the business's
--     in-transit place, received in part: what is not received stays in transit
--     and is visible), stock_consume_v1 and stock_loss_v1 (stockTakeOut on),
--     stock_fefo_proposal_v1 (a read: the lots to take, soonest expiry first)
--     and stock_command_outcome_v1 (what a command answered, read again after a
--     lost response, with no second effect).
--   * A SITE is, until #4293 gives it its own level, the root ancestor of a
--     place (a place with no parent): the contract page says so.

-- ── the marker, the kind, the system place ──────────────────────────────
alter table public.workspaces add column stock_initialized_at timestamptz;
update public.workspaces w set stock_initialized_at = now()
 where exists (select 1 from public.stock_locations l where l.workspace_id = w.id);

insert into public.stock_location_kinds (key, virtual, sort_order) values ('in_transit', false, 140)
on conflict (key) do nothing;
-- the business's one in-transit place: the system's, never a second one
create unique index stock_locations_one_transit on public.stock_locations (workspace_id) where kind = 'in_transit';

create or replace function public.stock_initialized(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((select w.stock_initialized_at is not null from public.workspaces w where w.id = p_workspace_id), false)
$fn$;
revoke execute on function public.stock_initialized(uuid) from public, anon, authenticated;

-- The business's one in-transit place: goods loaded for another site wait here,
-- counted, until they are received.
create or replace function public.stock_transit_place(p_workspace_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  n int;
begin
  select id into v_id from public.stock_locations where workspace_id = p_workspace_id and kind = 'in_transit';
  if v_id is null then
    -- the code is free to take: a place the business already called TRANSIT stays as it is
    for n in 0..20 loop
      insert into public.stock_locations (workspace_id, kind, code, name)
      values (p_workspace_id, 'in_transit', case when n = 0 then 'TRANSIT' else 'TRANSIT-' || n end, 'In transit')
      on conflict do nothing;
      select id into v_id from public.stock_locations where workspace_id = p_workspace_id and kind = 'in_transit';
      exit when v_id is not null;
    end loop;
    if v_id is null then
      raise exception 'the in-transit place of this business could not be made' using errcode = 'DKG05';
    end if;
  end if;
  return v_id;
end;
$fn$;
revoke execute on function public.stock_transit_place(uuid) from public, anon, authenticated;
select public.stock_transit_place(w.id) from public.workspaces w where w.stock_initialized_at is not null;

-- ── first activation imports the count once; later ones resume ─────────
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
    insert into public.stock_locations (workspace_id, kind, code, name)
    values (p_workspace_id, k, upper(k), '')
    on conflict do nothing;
  end loop;
  if public.stock_place(p_workspace_id, 'warehouse') is null then
    insert into public.stock_locations (workspace_id, kind, code)
    values (p_workspace_id, 'warehouse', 'MAIN')
    on conflict do nothing;
  end if;
  perform public.stock_transit_place(p_workspace_id);
  -- a later activation resumes the ledger as it is: nothing is reconciled
  -- from the rounded counter
  if public.stock_initialized(p_workspace_id) then return; end if;
  v_main := public.stock_place(p_workspace_id, 'warehouse');
  v_opening := public.stock_place(p_workspace_id, 'opening');
  for r in
    select s.id, s.inventory_unit, coalesce(s.stock, 0) as counted
      from public.services s
     where s.workspace_id = p_workspace_id and (s.stockable or s.stock is not null)
  loop
    update public.services set stockable = true where id = r.id and not stockable;
    if r.counted > 0 then
      perform public.stock_record(p_workspace_id, r.id, null, v_opening, v_main, r.counted,
        r.inventory_unit, r.counted, now(), 'opening', null, gen_random_uuid(), 1, 1, '{}'::jsonb);
    end if;
  end loop;
  update public.workspaces set stock_initialized_at = now() where id = p_workspace_id;
end;
$fn$;
revoke execute on function public.stock_open(uuid) from public, anon, authenticated;

-- ── the count while the ledger is initialized: a read-only mirror ──────
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

-- A tree of places, from [p_root] down, the place first then its children by code.
create or replace function public.stock_place_tree(p_workspace_id uuid, p_root uuid)
returns table (id uuid, depth int) language sql stable security definer set search_path = public as $fn$
  with recursive tree as (
    select l.id, l.code, 0 as depth from public.stock_locations l where l.id = p_root and l.workspace_id = p_workspace_id
    union all
    select c.id, c.code, tree.depth + 1 from public.stock_locations c join tree on c.parent_id = tree.id
     where c.workspace_id = p_workspace_id and c.active
  )
  select tree.id, tree.depth from tree order by tree.depth, tree.code
$fn$;
revoke execute on function public.stock_place_tree(uuid, uuid) from public, anon, authenticated;

-- The site of a place: its root ancestor (a place with no parent) until #4293
-- gives the site its own level.
create or replace function public.stock_site_of(p_location_id uuid)
returns uuid language sql stable security definer set search_path = public as $fn$
  with recursive up as (
    select l.id, l.parent_id from public.stock_locations l where l.id = p_location_id
    union all
    select p.id, p.parent_id from public.stock_locations p join up on p.id = up.parent_id
  )
  select up.id from up where up.parent_id is null limit 1
$fn$;
revoke execute on function public.stock_site_of(uuid) from public, anon, authenticated;

-- What a sale confirmed through the legacy bridge takes: from MAIN and the places
-- inside it, place by place, lots soonest-expiry first, exactly, NEVER a lot past
-- its date. Less than asked is refused (DKG03, naming what is there); only
-- expired stock left is refused as that (DKG15); an item with variants was already
-- refused by the confirmation itself (0837, DKG12: the sale must name its variant).
-- Only an untracked item, with the business's own setting on, may go below zero at MAIN.
create or replace function public.stock_take_in_tree(p_workspace_id uuid, p_item_id uuid, p_root uuid, p_quantity numeric)
returns table (location_id uuid, lot_id uuid, quantity numeric)
language plpgsql security definer set search_path = public as $fn$
declare
  v_left numeric := p_quantity;
  r record;
  b record;
  v_take numeric;
  v_tracked boolean;
  v_today date := (now() at time zone coalesce(
    (select nullif(w.timezone, '') from public.workspaces w where w.id = p_workspace_id), 'UTC'))::date;
  v_expired numeric;
begin
  for r in select * from public.stock_place_tree(p_workspace_id, p_root) loop
    exit when v_left <= 0;
    for b in
      select bal.lot_id as lot, bal.quantity as q
        from public.stock_balances bal left join public.stock_lots l on l.id = bal.lot_id
       where bal.workspace_id = p_workspace_id and bal.item_id = p_item_id and bal.location_id = r.id
         and bal.quantity > 0 and bal.variant_id is null
         and (l.id is null or l.expires_on is null or l.expires_on >= v_today)
       order by (bal.lot_id is not null), l.expires_on nulls last, l.created_datetime
    loop
      exit when v_left <= 0;
      v_take := least(b.q, v_left);
      location_id := r.id;
      lot_id := b.lot;
      quantity := v_take;
      return next;
      v_left := v_left - v_take;
    end loop;
  end loop;
  if v_left > 0 then
    select coalesce(sum(bal.quantity), 0) into v_expired
      from public.stock_balances bal join public.stock_lots l on l.id = bal.lot_id
     where bal.workspace_id = p_workspace_id and bal.item_id = p_item_id and bal.quantity > 0
       and bal.variant_id is null and l.expires_on < v_today
       and bal.location_id in (select t.id from public.stock_place_tree(p_workspace_id, p_root) t);
    if v_expired > 0 and v_expired >= v_left then
      raise exception 'what is left in the main store is past its date: % of % are there fit to sell', p_quantity - v_left, p_quantity
        using errcode = 'DKG15', detail = jsonb_build_object('scope', 'main_store', 'item_id', p_item_id,
                'held', (p_quantity - v_left)::text, 'asked', p_quantity::text)::text;
    end if;
    select (s.tracking <> 'none') into v_tracked from public.services s where s.id = p_item_id;
    if coalesce(v_tracked, false)
       or not coalesce((public.setting_value(p_workspace_id, 'stock.allow_negative') #>> '{}')::boolean, false) then
      raise exception 'not enough in the main store: % of % are there', p_quantity - v_left, p_quantity
        using errcode = 'DKG03', detail = jsonb_build_object('scope', 'main_store', 'item_id', p_item_id,
                'held', (p_quantity - v_left)::text, 'asked', p_quantity::text)::text;
    end if;
    location_id := p_root;
    lot_id := null;
    quantity := v_left;
    return next;
  end if;
end;
$fn$;
revoke execute on function public.stock_take_in_tree(uuid, uuid, uuid, numeric) from public, anon, authenticated;

do $patch$
declare
  v_def text;
  v_next text;
begin
  -- the legacy bridge: exact, from MAIN and what is inside it, never clipped
  v_def := pg_get_functiondef('public.apply_stock_on_confirm()'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$      -- what is there, as the count never went below zero
      select least(v_qty, coalesce(sum(b.quantity), 0)) into v_left from public.stock_balances b
       where b.item_id = v_service_id and b.location_id = v_main and b.quantity > 0
         and b.variant_id is null;
      if v_left > 0 then
        for t in select * from public.stock_take(new.workspace_id, v_service_id, v_main, v_left) loop
          v_part := v_part + 1;
          perform public.stock_record(new.workspace_id, v_service_id, t.lot_id, v_main,
            public.stock_place(new.workspace_id, 'customer'), t.quantity, v_unit, t.quantity, now(),
            'sale', new.actor_member_id, new.id, 1, v_part, jsonb_build_object('event_id', new.id));
        end loop;
      end if;$o$,
    $n$      -- exactly what the charge says, from MAIN and the places inside it: less
      -- there refuses the confirmation (DKG03, naming what is there), never clips.
      -- The item is locked first, as every stock command does (no deadlock with a return)
      perform 1 from public.services s where s.id = v_service_id for update;
      for t in select * from public.stock_take_in_tree(new.workspace_id, v_service_id, v_main, v_qty) loop
        v_part := v_part + 1;
        perform public.stock_record(new.workspace_id, v_service_id, t.lot_id, t.location_id,
          public.stock_place(new.workspace_id, 'customer'), t.quantity, v_unit, t.quantity, now(),
          'sale', new.actor_member_id, new.id, 1, v_part, jsonb_build_object('event_id', new.id));
      end loop;$n$);
  if v_next is null then raise exception '0847: the anchor of apply_stock_on_confirm was not found' using errcode = 'P0001'; end if;
  -- once the ledger exists the count is its mirror: with the feature off the bridge
  -- leaves the count (and the history) alone instead of writing it
  v_next := pg_temp.anchor_replace(v_next,
    $o$case when v_ledger then 0 else v_qty end$o$,
    $n$case when v_ledger or public.stock_initialized(new.workspace_id) then 0 else v_qty end$n$);
  if v_next is null then raise exception '0847: the anchor of the supply insert was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$set stock = coalesce(stock, 0) + v_qty,$o$,
    $n$set stock = case when public.stock_initialized(new.workspace_id) then stock else coalesce(stock, 0) + v_qty end,$n$);
  if v_next is null then raise exception '0847: the anchor of the supply count was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$set stock = greatest(0, stock - v_qty)$o$,
    $n$set stock = case when public.stock_initialized(new.workspace_id) then stock else greatest(0, stock - v_qty) end$n$);
  if v_next is null then raise exception '0847: the anchor of the charge count was not found' using errcode = 'P0001'; end if;
  execute v_next;

  -- once initialized, services.stock is a read-only mirror
  v_def := pg_get_functiondef('public.services_stock_ledger_before()'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$  if new.stock is not distinct from old.stock
     or coalesce(current_setting('deskilo.stock_count_edit', true), '') = 'on'
     or not public.feature_effective(new.workspace_id, 'stockManagement') then
    return new;
  end if;$o$,
    $n$  if new.stock is not distinct from old.stock
     or coalesce(current_setting('deskilo.stock_count_edit', true), '') = 'on' then
    return new;
  end if;
  -- the ledger keeps the stock: a count written from outside it is refused,
  -- whether the feature is on (use a stock command) or off (the history is kept)
  if public.stock_initialized(new.workspace_id) then
    -- the right is asked before the lifecycle: a person who may not move stock hears that
    perform public.stock_count_actor(new.workspace_id);
    raise exception 'the stock of this business is kept by its ledger: use a stock command, not the count'
      using errcode = 'DKG13';
  end if;
  if not public.feature_effective(new.workspace_id, 'stockManagement') then
    return new;
  end if;$n$);
  if v_next is null then raise exception '0847: the anchor of services_stock_ledger_before was not found' using errcode = 'P0001'; end if;
  -- a new item cannot bring a count either while the feature is off: no movement would carry it
  v_next := pg_temp.anchor_replace(v_next,
    $o$  if tg_op = 'INSERT' then return new; end if;$o$,
    $n$  if tg_op = 'INSERT' then
    if coalesce(new.stock, 0) <> 0 and public.stock_initialized(new.workspace_id)
       and not public.feature_effective(new.workspace_id, 'stockManagement')
       and coalesce(current_setting('deskilo.stock_count_edit', true), '') <> 'on' then
      raise exception 'the stock of this business is kept by its ledger: a new item has no count to write'
        using errcode = 'DKG13';
    end if;
    return new;
  end if;$n$);
  if v_next is null then raise exception '0847: the anchor of the insert of services_stock_ledger_before was not found' using errcode = 'P0001'; end if;
  execute v_next;

  -- the negative policy: only an untracked item at a place, never a lot
  v_def := pg_get_functiondef('public.stock_movements_apply()'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$if v_left < 0 and coalesce((public.setting_value(new.workspace_id, 'stock.allow_negative') #>> '{}')::boolean, false) = false then$o$,
    $n$if v_left < 0 and (coalesce((public.setting_value(new.workspace_id, 'stock.allow_negative') #>> '{}')::boolean, false) = false
                          or new.lot_id is not null
                          or exists (select 1 from public.services s where s.id = new.item_id and s.tracking <> 'none')) then$n$);
  if v_next is null then raise exception '0847: the anchor of stock_movements_apply was not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- ── a transfer between sites, in two steps ─────────────────────────────
create table public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  from_location_id uuid not null,
  to_location_id uuid not null,
  status text not null default 'loaded' check (status in ('loaded', 'partly_received', 'received')),
  request_id uuid not null,
  loaded_by uuid not null,
  revision int not null default 1,
  unique (workspace_id, id),
  foreign key (workspace_id, from_location_id) references public.stock_locations (workspace_id, id),
  foreign key (workspace_id, to_location_id) references public.stock_locations (workspace_id, id),
  foreign key (workspace_id, loaded_by) references public.members (workspace_id, id)
);
select public.ensure_system_columns('stock_transfers');
create index stock_transfers_open on public.stock_transfers (workspace_id) where status <> 'received';

create table public.stock_transfer_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  transfer_id uuid not null,
  item_id uuid not null,
  variant_id uuid,
  lot_id uuid,
  -- in the item's inventory unit
  loaded numeric(18, 6) not null check (loaded > 0),
  received numeric(18, 6) not null default 0 check (received >= 0 and received <= loaded),
  unique (workspace_id, id),
  foreign key (workspace_id, transfer_id) references public.stock_transfers (workspace_id, id) on delete cascade,
  foreign key (workspace_id, item_id) references public.services (workspace_id, id),
  foreign key (item_id, variant_id) references public.item_variants (item_id, id),
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id)
);
select public.ensure_system_columns('stock_transfer_lines');
create index stock_transfer_lines_transfer on public.stock_transfer_lines (transfer_id);

alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_lines enable row level security;
revoke all on public.stock_transfers, public.stock_transfer_lines from public, anon, authenticated;
grant select on public.stock_transfers, public.stock_transfer_lines to authenticated;
create policy stock_transfers_select on public.stock_transfers for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy stock_transfer_lines_select on public.stock_transfer_lines for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy mcp_delegated_deny on public.stock_transfers as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_transfer_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── who may run a stock command ─────────────────────────────────────────
create or replace function public.stock_ops_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to move stock' using errcode = 'DKN01';
  end if;
  select id into v_me from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to move stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'stock management is off' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_ops_actor(uuid) from public, anon, authenticated;

create or replace function public.stock_lot_expired(p_lot_id uuid, p_today date)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((select l.expires_on < p_today from public.stock_lots l where l.id = p_lot_id), false)
$fn$;
revoke execute on function public.stock_lot_expired(uuid, date) from public, anon, authenticated;

-- ── the one function that turns lines into movements ────────────────────
-- Lines: [{item_id, variant_id?, quantity, unit?, from, to, lot_id?, expired_ack?,
-- new_lot?}]. [p_mode] says which command called: generic, transfer_one,
-- transfer_load, transfer_receive, take_out. Every item of the request is locked
-- in id order first; the reason must fit the places; a lot past its date needs
-- an explicit acknowledgement (a loss needs none). Returns one entry per part.
create or replace function public.stock_apply_lines(
  p_workspace_id uuid, p_actor uuid, p_request_id uuid, p_lines jsonb, p_reason text,
  p_at timestamptz, p_links jsonb, p_mode text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  v_no int := 0;
  v_ids uuid[] := array[]::uuid[];
  v_item public.services;
  v_from public.stock_locations;
  v_to public.stock_locations;
  v_entered numeric;
  v_unit text;
  v_qty numeric;
  v_lot uuid;
  v_var uuid;
  v_part int;
  v_out jsonb := '[]'::jsonb;
  v_id uuid;
  t record;
  v_transit uuid := public.stock_transit_place(p_workspace_id);
  v_today date := (now() at time zone coalesce(
    (select nullif(w.timezone, '') from public.workspaces w where w.id = p_workspace_id), 'UTC'))::date;
  v_ack boolean;
  v_ok boolean;
  v_fv boolean;
  v_tv boolean;
begin
  -- taking goods out for use or as a loss is its own feature, by whichever door it comes
  if p_reason in ('consumption', 'loss') and not public.feature_effective(p_workspace_id, 'stockTakeOut') then
    raise exception 'taking goods out is off in this business' using errcode = 'DKG01';
  end if;
  -- every item locked first, in id order: opposing requests cannot deadlock
  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    if coalesce(e ->> 'item_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      raise exception 'line %: not a stock item of this business', v_no using errcode = 'DKG04';
    end if;
    v_ids := v_ids || (e ->> 'item_id')::uuid;
  end loop;
  perform 1 from public.services where id = any (v_ids) and workspace_id = p_workspace_id order by id for update;

  v_no := 0;
  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    select * into v_item from public.services
     where id = (e ->> 'item_id')::uuid and workspace_id = p_workspace_id and stockable;
    if v_item.id is null then
      raise exception 'line %: not a stock item of this business', v_no using errcode = 'DKG04';
    end if;
    if coalesce(e ->> 'from', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
       or coalesce(e ->> 'to', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      raise exception 'line %: a move goes from one place of this business to another', v_no using errcode = 'DKG05';
    end if;
    select * into v_from from public.stock_locations
     where id = (e ->> 'from')::uuid and workspace_id = p_workspace_id and active;
    select * into v_to from public.stock_locations
     where id = (e ->> 'to')::uuid and workspace_id = p_workspace_id and active;
    if v_from.id is null or v_to.id is null or v_from.id = v_to.id then
      raise exception 'line %: a move goes from one place of this business to another', v_no
        using errcode = 'DKG05';
    end if;
    v_fv := public.stock_place_is_virtual(v_from.id);
    v_tv := public.stock_place_is_virtual(v_to.id);

    -- the in-transit place belongs to the two-step transfer, and to nothing else
    if (v_from.id = v_transit or v_to.id = v_transit) and p_mode not in ('transfer_load', 'transfer_receive') then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'transit_is_system');
    end if;
    v_ok := case p_reason
      when 'receipt' then v_from.kind = 'supplier' and not v_tv
      when 'transfer' then not v_fv and not v_tv
      when 'consumption' then not v_fv and v_to.kind = 'loss'
      when 'loss' then not v_fv and v_to.kind = 'loss'
      when 'adjustment' then (v_from.kind = 'loss' and not v_tv) or (v_to.kind = 'loss' and not v_fv)
      when 'opening' then (v_from.kind = 'opening' and not v_tv) or (v_to.kind = 'opening' and not v_fv)
      when 'sale' then not v_fv and v_to.kind = 'customer' and (p_links ? 'event_id' or p_links ? 'invoice_id')
      when 'return_in' then v_from.kind = 'customer' and not v_tv and p_links ? 'invoice_id'
      when 'return_out' then not v_fv and v_to.kind = 'supplier' and (p_links ? 'receipt_line_id' or p_links ? 'purchase_line_id')
      else false end;
    if not v_ok then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'reason_places');
    end if;
    -- one step only within one site; between sites the goods go through transit
    if p_reason = 'transfer' and p_mode in ('generic', 'transfer_one')
       and public.stock_site_of(v_from.id) is distinct from public.stock_site_of(v_to.id) then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'transfer_needs_transit');
    end if;

    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      raise exception 'line %: a quantity above zero', v_no using errcode = 'DKG07';
    end if;
    v_entered := (e ->> 'quantity')::numeric;
    v_unit := coalesce(nullif(e ->> 'unit', ''), v_item.inventory_unit);
    v_qty := public.stock_to_inventory(v_item.id, v_unit, v_entered);

    if nullif(e ->> 'variant_id', '') is not null
       and (e ->> 'variant_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      raise exception 'line %: not a variant of this item', v_no using errcode = 'DKG04';
    end if;
    v_var := nullif(e ->> 'variant_id', '')::uuid;
    if v_var is not null and not exists (select 1 from public.item_variants x
         where x.id = v_var and x.workspace_id = p_workspace_id and x.item_id = v_item.id and x.active) then
      raise exception 'line %: not a variant of this item', v_no using errcode = 'DKG04';
    end if;
    if v_var is null and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then
      raise exception 'line %: this item has variants: name which one', v_no using errcode = 'DKG12';
    end if;
    if nullif(e ->> 'lot_id', '') is not null
       and (e ->> 'lot_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      raise exception 'line %: the lot is not of this item', v_no using errcode = 'DKG06';
    end if;
    v_lot := nullif(e ->> 'lot_id', '')::uuid;
    if v_lot is not null and not exists (select 1 from public.stock_lots
         where id = v_lot and workspace_id = p_workspace_id and item_id = v_item.id
         and variant_id is not distinct from v_var) then
      raise exception 'line %: the lot is not of this item', v_no using errcode = 'DKG06';
    end if;
    if e ? 'new_lot' then
      if p_mode <> 'generic' or p_reason <> 'receipt' or v_lot is not null or not v_fv
         or jsonb_typeof(e -> 'new_lot') <> 'object'
         or nullif(e -> 'new_lot' ->> 'total_cost_minor', '') is null then
        raise exception 'line %: a new lot arrives from outside, with its cost', v_no using errcode = 'DKG06';
      end if;
      insert into public.stock_lots (workspace_id, item_id, variant_id, lot_code, expires_on, total_cost_minor,
                                     quantity_received, source_currency, source_rate, receipt_line_id)
      values (p_workspace_id, v_item.id, v_var, coalesce(e -> 'new_lot' ->> 'code', ''),
              nullif(e -> 'new_lot' ->> 'expires_on', '')::date,
              (e -> 'new_lot' ->> 'total_cost_minor')::bigint, v_qty,
              nullif(e -> 'new_lot' ->> 'source_currency', ''),
              nullif(e -> 'new_lot' ->> 'source_rate', '')::numeric,
              nullif(p_links ->> 'receipt_line_id', '')::uuid)
      returning id into v_lot;
    end if;

    if v_item.tracking <> 'none' and v_lot is null then
      raise exception 'line %: this item is tracked by lot', v_no using errcode = 'DKG06';
    end if;
    v_ack := coalesce((e ->> 'expired_ack')::boolean, false);
    -- receiving what was loaded never asks again: it left the source with its own acknowledgement
    if v_lot is not null and not v_fv and p_reason <> 'loss' and not v_ack and p_mode <> 'transfer_receive'
       and public.stock_lot_expired(v_lot, v_today) then
      perform public.stock_config_refuse(format('lines[%s].lot_id', v_no - 1), 'lot_expired');
    end if;

    v_part := 0;
    if v_lot is null and not v_fv then
      for t in select * from public.stock_take(p_workspace_id, v_item.id, v_from.id, v_qty, v_var) loop
        v_part := v_part + 1;
        if t.lot_id is not null and p_reason <> 'loss' and not v_ack and p_mode <> 'transfer_receive'
           and public.stock_lot_expired(t.lot_id, v_today) then
          perform public.stock_config_refuse(format('lines[%s].lot_id', v_no - 1), 'lot_expired');
        end if;
        v_id := public.stock_record(p_workspace_id, v_item.id, t.lot_id, v_from.id, v_to.id, t.quantity,
          v_unit, v_entered, p_at, p_reason, p_actor, p_request_id, v_no, v_part, p_links, v_var);
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'line_no', v_no,
          'part', v_part, 'item_id', v_item.id, 'variant_id', v_var, 'lot_id', t.lot_id, 'quantity', t.quantity));
      end loop;
    else
      v_id := public.stock_record(p_workspace_id, v_item.id, v_lot, v_from.id, v_to.id, v_qty,
        v_unit, v_entered, p_at, p_reason, p_actor, p_request_id, v_no, 1, p_links, v_var);
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'line_no', v_no,
        'part', 1, 'item_id', v_item.id, 'variant_id', v_var, 'lot_id', v_lot, 'quantity', v_qty));
    end if;
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text) from public, anon, authenticated;

-- ── the generic move: its signature kept, its reason now checked ───────
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
  v_out jsonb;
begin
  -- a delegated (assistant) session never moves stock, as the typed commands refuse it
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to move stock' using errcode = 'DKN01';
  end if;
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
  v_digest := md5(p_reason || '|' || coalesce(p_occurred_at::text, '') || '|' || p_lines::text || '|' || v_links::text);
  v_done := null;
  perform pg_advisory_xact_lock(hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'stock_move' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result;
  end if;
  v_out := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, p_lines, p_reason, v_at, v_links, 'generic');
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'stock_move', v_digest,
          jsonb_build_object('request_id', p_request_id, 'movements', v_out))
  returning result into v_out;
  return v_out;
end;
$fn$;
revoke execute on function public.stock_move_v1(uuid, uuid, jsonb, text, timestamptz, jsonb) from public, anon;
grant execute on function public.stock_move_v1(uuid, uuid, jsonb, text, timestamptz, jsonb) to authenticated;

-- ── the typed commands ──────────────────────────────────────────────────
create or replace function public.stock_command_args(p_request_id uuid, p_lines jsonb)
returns void language plpgsql immutable set search_path = public as $fn$
begin
  if p_request_id is null or coalesce(jsonb_typeof(p_lines), '') <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 200 then
    raise exception 'a command has a request id and 1 to 200 lines' using errcode = 'DKG07';
  end if;
end;
$fn$;
revoke execute on function public.stock_command_args(uuid, jsonb) from public, anon, authenticated;

-- One step between two places of one site (replenishment: the site's total is unchanged).
create or replace function public.stock_transfer_v1(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_occurred_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_at timestamptz := coalesce(p_occurred_at, now());
begin
  perform public.stock_command_args(p_request_id, p_lines);
  if v_at > now() + interval '5 minutes' then raise exception 'a command is not in the future' using errcode = 'DKG07'; end if;
  v_digest := md5('transfer|' || coalesce(p_occurred_at::text, '') || '|' || p_lines::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_transfer', v_digest);
  if v_done is not null then return v_done; end if;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_transfer', v_digest,
    jsonb_build_object('request_id', p_request_id, 'movements',
      public.stock_apply_lines(p_workspace_id, v_me, p_request_id, p_lines, 'transfer', v_at, '{}'::jsonb, 'transfer_one')));
end;
$fn$;
revoke execute on function public.stock_transfer_v1(uuid, uuid, jsonb, timestamptz) from public, anon;
grant execute on function public.stock_transfer_v1(uuid, uuid, jsonb, timestamptz) to authenticated;

-- Taking goods out for use or as a loss: to the loss place, the feature stockTakeOut on.
create or replace function public.stock_take_out(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_reason text, p_occurred_at timestamptz
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_at timestamptz := coalesce(p_occurred_at, now());
  v_loss uuid := public.stock_place(p_workspace_id, 'loss');
  v_lines jsonb;
begin
  if not public.feature_effective(p_workspace_id, 'stockTakeOut') then
    raise exception 'taking goods out is off in this business' using errcode = 'DKG01';
  end if;
  perform public.stock_command_args(p_request_id, p_lines);
  if v_at > now() + interval '5 minutes' then raise exception 'a command is not in the future' using errcode = 'DKG07'; end if;
  v_digest := md5(p_reason || '|' || coalesce(p_occurred_at::text, '') || '|' || p_lines::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_' || p_reason, v_digest);
  if v_done is not null then return v_done; end if;
  select jsonb_agg(l || jsonb_build_object('to', v_loss)) into v_lines from jsonb_array_elements(p_lines) l;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_' || p_reason, v_digest,
    jsonb_build_object('request_id', p_request_id, 'movements',
      public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_lines, p_reason, v_at, '{}'::jsonb, 'take_out')));
end;
$fn$;
revoke execute on function public.stock_take_out(uuid, uuid, jsonb, text, timestamptz) from public, anon, authenticated;

create or replace function public.stock_consume_v1(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_occurred_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  perform public.stock_ops_actor(p_workspace_id);
  return public.stock_take_out(p_workspace_id, p_request_id, p_lines, 'consumption', p_occurred_at);
end;
$fn$;
revoke execute on function public.stock_consume_v1(uuid, uuid, jsonb, timestamptz) from public, anon;
grant execute on function public.stock_consume_v1(uuid, uuid, jsonb, timestamptz) to authenticated;

create or replace function public.stock_loss_v1(
  p_workspace_id uuid, p_request_id uuid, p_lines jsonb, p_occurred_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  perform public.stock_ops_actor(p_workspace_id);
  return public.stock_take_out(p_workspace_id, p_request_id, p_lines, 'loss', p_occurred_at);
end;
$fn$;
revoke execute on function public.stock_loss_v1(uuid, uuid, jsonb, timestamptz) from public, anon;
grant execute on function public.stock_loss_v1(uuid, uuid, jsonb, timestamptz) to authenticated;

-- Loading goods for another site: they leave the source place for the in-transit
-- place (still counted) and a transfer remembers each lot and quantity.
create or replace function public.stock_transfer_load_v1(
  p_workspace_id uuid, p_request_id uuid, p_to_location_id uuid, p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_transit uuid := public.stock_transit_place(p_workspace_id);
  v_lines jsonb;
  v_from uuid;
  v_moves jsonb;
  v_transfer uuid;
  v_out jsonb;
  e jsonb;
begin
  perform public.stock_command_args(p_request_id, p_lines);
  v_digest := md5(coalesce(p_to_location_id::text, '') || '|' || p_lines::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_transfer_load', v_digest);
  if v_done is not null then return v_done; end if;
  if p_to_location_id is null or not exists (select 1 from public.stock_locations l
       where l.id = p_to_location_id and l.workspace_id = p_workspace_id and l.active
         and not public.stock_place_is_virtual(l.id) and l.id <> v_transit) then
    perform public.stock_config_refuse('to_location_id', 'location_foreign');
  end if;
  -- one source place per transfer
  if (select count(distinct l ->> 'from') from jsonb_array_elements(p_lines) l) > 1 then
    perform public.stock_config_refuse('lines', 'one_source');
  end if;
  select nullif(p_lines -> 0 ->> 'from', '')::uuid into v_from;
  -- two steps are for goods that change site: inside one site a transfer is one step
  if public.stock_site_of(p_to_location_id) is not distinct from public.stock_site_of(v_from) then
    perform public.stock_config_refuse('to_location_id', 'same_site');
  end if;
  select jsonb_agg(l || jsonb_build_object('to', v_transit)) into v_lines from jsonb_array_elements(p_lines) l;
  v_moves := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_lines, 'transfer', now(), '{}'::jsonb, 'transfer_load');
  insert into public.stock_transfers (workspace_id, from_location_id, to_location_id, request_id, loaded_by)
  values (p_workspace_id, v_from, p_to_location_id, p_request_id, v_me)
  returning id into v_transfer;
  insert into public.stock_transfer_lines (workspace_id, transfer_id, item_id, variant_id, lot_id, loaded)
  select p_workspace_id, v_transfer, (m ->> 'item_id')::uuid, nullif(m ->> 'variant_id', '')::uuid,
         nullif(m ->> 'lot_id', '')::uuid, sum((m ->> 'quantity')::numeric)
    from jsonb_array_elements(v_moves) m
   group by 3, 4, 5;
  select jsonb_build_object('request_id', p_request_id, 'transfer_id', v_transfer, 'movements', v_moves,
           'lines', coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'item_id', x.item_id, 'variant_id', x.variant_id,
                      'lot_id', x.lot_id, 'loaded', x.loaded) order by x.id), '[]'::jsonb))
    into v_out from public.stock_transfer_lines x where x.transfer_id = v_transfer;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_transfer_load', v_digest, v_out);
end;
$fn$;
revoke execute on function public.stock_transfer_load_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.stock_transfer_load_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- Receiving what was loaded, all or in part, onto a place of the destination site.
-- p_lines: [{line_id, quantity, to?}]; what is not received stays in transit.
create or replace function public.stock_transfer_receive_v1(
  p_workspace_id uuid, p_request_id uuid, p_transfer_id uuid, p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_transit uuid := public.stock_transit_place(p_workspace_id);
  v_tr public.stock_transfers;
  e jsonb;
  i int := 0;
  v_line public.stock_transfer_lines;
  v_qty numeric;
  v_to uuid;
  v_lines jsonb := '[]'::jsonb;
  v_moves jsonb;
  v_open boolean;
  v_out jsonb;
begin
  perform public.stock_command_args(p_request_id, p_lines);
  v_digest := md5(coalesce(p_transfer_id::text, '') || '|' || p_lines::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_transfer_receive', v_digest);
  if v_done is not null then return v_done; end if;
  select * into v_tr from public.stock_transfers where id = p_transfer_id and workspace_id = p_workspace_id for update;
  if v_tr.id is null then perform public.stock_config_refuse('transfer', 'transfer_unknown'); end if;
  for e in select value from jsonb_array_elements(p_lines) loop
    i := i + 1;
    if coalesce(e ->> 'line_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      perform public.stock_config_refuse(format('lines[%s].line_id', i - 1), 'transfer_unknown');
    end if;
    select * into v_line from public.stock_transfer_lines
     where id = (e ->> 'line_id')::uuid and transfer_id = v_tr.id for update;
    if v_line.id is null then
      perform public.stock_config_refuse(format('lines[%s].line_id', i - 1), 'transfer_unknown');
    end if;
    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      perform public.stock_config_refuse(format('lines[%s].quantity', i - 1), 'quantity_invalid');
    end if;
    v_qty := (e ->> 'quantity')::numeric;
    if v_qty > v_line.loaded - v_line.received then
      perform public.stock_config_refuse(format('lines[%s].quantity', i - 1), 'receive_over');
    end if;
    v_to := case when coalesce(e ->> 'to', '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
                 then (e ->> 'to')::uuid else v_tr.to_location_id end;
    -- a real place of the destination's own site
    if not exists (select 1 from public.stock_locations l
         where l.id = v_to and l.workspace_id = p_workspace_id and l.active
           and not public.stock_place_is_virtual(l.id) and l.id <> v_transit)
       or public.stock_site_of(v_to) is distinct from public.stock_site_of(v_tr.to_location_id) then
      perform public.stock_config_refuse(format('lines[%s].to', i - 1), 'wrong_site');
    end if;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'item_id', v_line.item_id, 'variant_id', v_line.variant_id, 'lot_id', v_line.lot_id,
      'quantity', v_qty::text, 'from', v_transit, 'to', v_to));
    update public.stock_transfer_lines set received = received + v_qty where id = v_line.id;
  end loop;
  v_moves := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_lines, 'transfer', now(), '{}'::jsonb, 'transfer_receive');
  select exists (select 1 from public.stock_transfer_lines x where x.transfer_id = v_tr.id and x.received < x.loaded) into v_open;
  update public.stock_transfers
     set status = case when v_open then 'partly_received' else 'received' end, revision = revision + 1
   where id = v_tr.id;
  v_out := jsonb_build_object('request_id', p_request_id, 'transfer_id', v_tr.id,
    'status', case when v_open then 'partly_received' else 'received' end, 'movements', v_moves);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_transfer_receive', v_digest, v_out);
end;
$fn$;
revoke execute on function public.stock_transfer_receive_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.stock_transfer_receive_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- The lots to take for a quantity, soonest expiry first, for the operator to confirm.
create or replace function public.stock_fefo_proposal_v1(
  p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_location_id uuid, p_quantity numeric
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_today date := (now() at time zone coalesce(
    (select nullif(w.timezone, '') from public.workspaces w where w.id = p_workspace_id), 'UTC'))::date;
  v_left numeric := p_quantity;
  v_lots jsonb := '[]'::jsonb;
  r record;
  v_take numeric;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  perform public.stock_reader(p_workspace_id);
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'a quantity above zero' using errcode = 'DKG07';
  end if;
  for r in
    select b.lot_id, l.lot_code, l.expires_on, b.quantity
      from public.stock_balances b left join public.stock_lots l on l.id = b.lot_id
     where b.workspace_id = p_workspace_id and b.item_id = p_item_id and b.location_id = p_location_id
       and b.variant_id is not distinct from p_variant_id and b.quantity > 0
     order by (b.lot_id is not null), l.expires_on nulls last, l.created_datetime
  loop
    exit when v_left <= 0;
    v_take := least(r.quantity, v_left);
    v_lots := v_lots || jsonb_build_array(jsonb_build_object(
      'lot_id', r.lot_id, 'lot_code', r.lot_code, 'expires_on', r.expires_on,
      'expired', coalesce(r.expires_on < v_today, false), 'available', r.quantity, 'take', v_take));
    v_left := v_left - v_take;
  end loop;
  return jsonb_build_object('lots', v_lots, 'short', greatest(v_left, 0));
end;
$fn$;
revoke execute on function public.stock_fefo_proposal_v1(uuid, uuid, uuid, uuid, numeric) from public, anon;
grant execute on function public.stock_fefo_proposal_v1(uuid, uuid, uuid, uuid, numeric) to authenticated;

-- What a stock command answered, read again after a lost response: no second effect.
create or replace function public.stock_command_outcome_v1(p_workspace_id uuid, p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v public.purchase_requests;
begin
  perform public.stock_ops_actor(p_workspace_id);
  -- only the stock commands of this family, and only the caller's own request
  select * into v from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id
     and operation in ('stock_transfer', 'stock_transfer_load', 'stock_transfer_receive', 'stock_consumption', 'stock_loss')
     and created_by_user = auth.uid();
  if v.id is null then return null; end if;
  -- the feature and right the command itself asks for
  if v.operation in ('stock_consumption', 'stock_loss') and not public.feature_effective(p_workspace_id, 'stockTakeOut') then
    raise exception 'taking goods out is off in this business' using errcode = 'DKG01';
  end if;
  return jsonb_build_object('operation', v.operation, 'result', v.result);
end;
$fn$;
revoke execute on function public.stock_command_outcome_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_command_outcome_v1(uuid, uuid) to authenticated;


-- ── the workspace export carries the transfers (#2860): 0840's function restated ──
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
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
    'stock_balances',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines'];
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


-- ── the in-transit place is the system's: no second one, no edit, no put-away into it ──
do $transit$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.save_stock_location_v1(uuid, uuid, int, uuid, jsonb)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$    if exists (select 1 from public.stock_location_kinds k where k.key = v_old.kind and k.virtual) then
      perform public.stock_config_refuse('place', 'location_virtual');$o$,
    $n$    if v_old.kind = 'in_transit' or exists (select 1 from public.stock_location_kinds k where k.key = v_old.kind and k.virtual) then
      perform public.stock_config_refuse('place', 'location_virtual');$n$);
  if v_next is null then raise exception '0847: the anchor of save_stock_location_v1 (place) was not found' using errcode = 'P0001'; end if;
  -- no place is made inside the in-transit place: it would become that place's site
  v_next := pg_temp.anchor_replace(v_next,
    $o$    if exists (select 1 from public.stock_locations l join public.stock_location_kinds k on k.key = l.kind
                where l.id = v_parent and k.virtual) then$o$,
    $n$    if exists (select 1 from public.stock_locations l join public.stock_location_kinds k on k.key = l.kind
                where l.id = v_parent and (k.virtual or l.kind = 'in_transit')) then$n$);
  if v_next is null then raise exception '0847: the anchor of save_stock_location_v1 (parent) was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$  if exists (select 1 from public.stock_location_kinds k where k.key = v_kind and k.virtual) then
    perform public.stock_config_refuse('kind', 'location_virtual');$o$,
    $n$  if v_kind = 'in_transit' or exists (select 1 from public.stock_location_kinds k where k.key = v_kind and k.virtual) then
    perform public.stock_config_refuse('kind', 'location_virtual');$n$);
  if v_next is null then raise exception '0847: the anchor of save_stock_location_v1 (kind) was not found' using errcode = 'P0001'; end if;
  execute v_next;

  v_def := pg_get_functiondef('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$l.active and not public.stock_place_is_virtual(l.id)) then$o$,
    $n$l.active and not public.stock_place_is_virtual(l.id) and l.kind <> 'in_transit') then$n$);
  if v_next is null then raise exception '0847: the anchor of stock_put_away_apply was not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$transit$;


-- ── a configuration file's counts are ignored once the ledger exists ──
-- The import wrote services.stock from the file; the count is now the ledger's mirror
-- (DKG13), so the file's count would refuse the whole import. The ledger is the truth.
do $import$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.import_workspace_configuration(uuid, jsonb, text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$active, stock, vat_rate_id)$o$,
    $n$active, stock, stockable, vat_rate_id)$n$);
  if v_next is null then raise exception '0847: the anchor of import_workspace_configuration (columns) was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$(v_row->>'stock')::int, public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate'));$o$,
    $n$case when public.stock_initialized(p_workspace_id) then null else (v_row->>'stock')::int end,
                (v_row->>'stock') is not null,
                public.vat_rate_id_by_label(p_workspace_id, v_row->>'vat_rate'));$n$);
  if v_next is null then raise exception '0847: the anchor of import_workspace_configuration (insert) was not found' using errcode = 'P0001'; end if;
  v_next := pg_temp.anchor_replace(v_next,
    $o$stock = (v_row->>'stock')::int,$o$,
    $n$stock = case when public.stock_initialized(p_workspace_id) then stock else (v_row->>'stock')::int end,
               stockable = stockable or (v_row->>'stock') is not null,$n$);
  if v_next is null then raise exception '0847: the anchor of import_workspace_configuration (update) was not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$import$;

select public.set_deskilo_schema_version(847);
