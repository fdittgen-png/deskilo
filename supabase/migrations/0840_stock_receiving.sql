-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (a lot gains the state of its cost, and the receipt tables become insert-only;
--  every existing lot is known-cost and every existing amount is unchanged)
--
-- #4171 (A) -- receive deliveries into stock exactly once, and keep their
-- origin.
--
-- A delivery of a purchase order (0684) is recorded independently of stock and
-- stays valid as it is. When the business asks for `stockReceiving`, the lines
-- of a delivery are PUT AWAY into explicit places and new lots, once:
--
--   * `stock_receipt_allocations`: insert-only, one row per put-away part. It
--     freezes the receipt line, the item, the variant, the entered unit and
--     quantity (in the order line's unit), the exact factor, the inventory
--     quantity (rounded once), the lot, the place, the movement and a snapshot
--     of the order, supplier and line text, so a later edit of a mapping, a
--     unit or a catalogue name cannot reinterpret it. The receipt line is
--     locked first: two requests cannot together put away more than arrived.
--   * `put_away_receipt_v1` puts away (more of) a recorded delivery;
--     `record_receipt_and_put_away_v1` records the delivery with 0684's own
--     function, UNCHANGED, and puts it away in the same transaction (a failure
--     of either half writes neither). Both answer a repeated request id with
--     the same ids. The client never names a lot of a supplier delivery: each
--     put-away group makes a new lot.
--   * COST is never guessed. A lot has `cost_state` ('known' | 'unknown') and
--     `cost_source` ('entered' | 'order_price'): a lot with no cost
--     assertion is UNKNOWN (never zero); a known zero stays zero. Movements of
--     an unknown lot have no unit cost and the value on hand leaves such rows
--     out of its total and counts them.
--   * receipts and their lines are insert-only and an order that has a
--     receipt cannot be deleted: corrections are appended. A business's own
--     deletion still removes everything.
--
-- The effective contract and the policy manifest follow from the database
-- preview; the refusals are DKG11 (field and reason) as the configuration's.

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

-- ── the state of a lot's cost ───────────────────────────────────────────
alter table public.stock_lots
  add column cost_state text not null default 'known' check (cost_state in ('known', 'unknown')),
  add column cost_source text check (cost_source is null or cost_source in ('entered', 'order_price'));
alter table public.stock_lots
  add constraint stock_lots_unknown_cost_is_bare
  check (cost_state <> 'unknown' or (total_cost_minor = 0 and source_currency is null and cost_source is null));

-- A movement of an unknown-cost lot has no unit cost, and the value on hand
-- leaves such a lot out and says how many rows it left out.
do $patch$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamptz, text, uuid, uuid, int, int, jsonb, uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$from public.stock_lots where id = p_lot_id;$o$,
    $n$from public.stock_lots where id = p_lot_id and cost_state = 'known';$n$);
  if v_next is null then raise exception '0840: the anchor of stock_record was not found' using errcode = 'P0001'; end if;
  execute v_next;

  v_def := pg_get_functiondef('public.stock_value_at_v1(uuid, timestamptz)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$'unit_cost', l.total_cost_minor::numeric / l.quantity_received,
           'value_minor', round(q.quantity * l.total_cost_minor / l.quantity_received))$o$,
    $n$'unit_cost', case when l.cost_state = 'known' then l.total_cost_minor::numeric / l.quantity_received end,
           'cost_state', l.cost_state,
           'value_minor', case when l.cost_state = 'known' then round(q.quantity * l.total_cost_minor / l.quantity_received) end)$n$);
  if v_next is null then raise exception '0840: the anchor of stock_value_at_v1 (rows) was not found' using errcode = 'P0001'; end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def,
    $o$'items', v_rows,$o$,
    $n$'items', v_rows,
    'rows_without_cost', (select count(*) from jsonb_array_elements(v_rows) r where r ->> 'value_minor' is null),$n$);
  if v_next is null then raise exception '0840: the anchor of stock_value_at_v1 (total) was not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- ── what was put away: insert-only ──────────────────────────────────────
create table public.stock_receipt_allocations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null references public.purchase_order_receipts (id),
  receipt_line_id uuid not null references public.purchase_order_receipt_lines (id),
  order_line_id uuid not null references public.purchase_order_lines (id),
  item_id uuid not null,
  variant_id uuid,
  -- in the unit of the order line, as the receipt line counts it
  entered_unit text not null,
  entered_quantity numeric(18, 6) not null check (entered_quantity > 0),
  factor_num bigint not null check (factor_num > 0),
  factor_den bigint not null check (factor_den > 0),
  -- in the item's inventory unit, rounded once
  inventory_quantity numeric(18, 6) not null check (inventory_quantity > 0),
  lot_id uuid not null,
  location_id uuid not null,
  movement_id uuid not null unique references public.stock_movements (id),
  command_request_id uuid not null,
  part int not null check (part >= 1),
  -- what the order said when the goods were put away
  order_reference text not null default '',
  supplier_name text not null default '',
  line_text text not null default '',
  unique (command_request_id, part),
  unique (workspace_id, id),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id),
  foreign key (item_id, variant_id) references public.item_variants (item_id, id),
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id),
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id)
);
select public.ensure_system_columns('stock_receipt_allocations');
create index stock_receipt_allocations_line on public.stock_receipt_allocations (receipt_line_id);
create index stock_receipt_allocations_receipt on public.stock_receipt_allocations (receipt_id);

alter table public.stock_receipt_allocations enable row level security;
revoke all on public.stock_receipt_allocations from public, anon, authenticated;
grant select on public.stock_receipt_allocations to authenticated;
create policy stock_receipt_allocations_select on public.stock_receipt_allocations for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock', 'managePurchases']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy mcp_delegated_deny on public.stock_receipt_allocations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- History is appended, never edited or removed while the business exists.
create or replace function public.keep_receiving_history()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    raise exception 'a delivery and what was put away are kept: append a correction instead'
      using errcode = 'DKG08';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$fn$;
revoke execute on function public.keep_receiving_history() from public, anon, authenticated;
create trigger stock_receipt_allocations_keep before update or delete on public.stock_receipt_allocations
  for each row execute function public.keep_receiving_history();
create trigger purchase_order_receipts_keep before update or delete on public.purchase_order_receipts
  for each row execute function public.keep_receiving_history();
create trigger purchase_order_receipt_lines_keep before update or delete on public.purchase_order_receipt_lines
  for each row execute function public.keep_receiving_history();

-- An order that has received goods is not deleted (its receipts would go with it).
create or replace function public.purchase_orders_keep_receipts()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if exists (select 1 from public.purchase_order_receipts r where r.order_id = old.id)
     and exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    raise exception 'an order that received goods is kept: cancel it instead'
      using errcode = 'DKG08';
  end if;
  return old;
end;
$fn$;
revoke execute on function public.purchase_orders_keep_receipts() from public, anon, authenticated;
create trigger purchase_orders_keep_receipts before delete on public.purchase_orders
  for each row execute function public.purchase_orders_keep_receipts();

-- ── who may receive into stock ──────────────────────────────────────────
-- A buyer who also manages the stock, with the purchases, the orders, the
-- ledger and the receiving all asked for; never a delegated assistant session.
create or replace function public.stock_receiving_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to receive into stock' using errcode = 'DKN01';
  end if;
  select id into v_me from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me is null or not (public.has_permission(p_workspace_id, 'managePurchases')
                          and public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to receive into stock' using errcode = 'DKN01';
  end if;
  if not (public.feature_effective(p_workspace_id, 'purchases')
          and public.feature_effective(p_workspace_id, 'purchaseOrders')
          and public.feature_effective(p_workspace_id, 'stockManagement')
          and public.feature_effective(p_workspace_id, 'stockReceiving')) then
    raise exception 'receiving into stock is off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_receiving_actor(uuid) from public, anon, authenticated;

-- ── put away what a delivery brought ────────────────────────────────────
-- p_allocations: [{receipt_line_id | line_no, quantity, location_id,
-- variant_id?, group?, lot?: {code, expires_on}, cost?: {state: known |
-- unknown | order_price, total_cost_minor?, source_currency?, source_rate?}}].
-- `quantity` is in the unit of the order line. Allocations that share a line,
-- a variant and a group make ONE new lot (its cost and label are the first
-- member's); every command makes its own new lots. Returns what it wrote.
create or replace function public.stock_put_away_apply(
  p_workspace_id uuid, p_actor uuid, p_command uuid, p_receipt_id uuid, p_allocations jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_receipt public.purchase_order_receipts;
  v_order public.purchase_orders;
  v_supplier text;
  v_currency text;
  e jsonb;
  i int := 0;
  v_rl public.purchase_order_receipt_lines;
  v_ol public.purchase_order_lines;
  v_item public.services;
  v_unit text;
  v_entered numeric;
  v_inv numeric;
  v_fac record;
  v_var uuid;
  v_loc uuid;
  v_lot_meta jsonb;
  v_cost jsonb;
  v_group text;
  v_key text;
  v_plan jsonb := '[]'::jsonb;
  v_ids uuid[] := array[]::uuid[];
  v_running jsonb := '{}'::jsonb;
  v_have numeric;
  v_expires date;
  v_state text;
  v_total bigint;
  v_cur text;
  v_rate numeric;
  v_src text;
  v_groups jsonb := '{}'::jsonb;
  g record;
  v_lot uuid;
  p jsonb;
  v_mv uuid;
  v_out jsonb := '[]'::jsonb;
  v_aid uuid;
  v_from uuid := public.stock_place(p_workspace_id, 'supplier');
  v_wscur text;
  v_gqty numeric;
  v_gentered numeric;
  v_first jsonb;
begin
  if coalesce(jsonb_typeof(p_allocations), '') <> 'array' or jsonb_array_length(p_allocations) not between 1 and 200 then
    perform public.stock_config_refuse('allocations', 'malformed');
  end if;
  select * into v_receipt from public.purchase_order_receipts where id = p_receipt_id and workspace_id = p_workspace_id;
  if v_receipt.id is null then perform public.stock_config_refuse('receipt', 'receipt_unknown'); end if;
  select * into v_order from public.purchase_orders where id = v_receipt.order_id;
  select coalesce(s.name, '') into v_supplier from public.suppliers s where s.id = v_order.supplier_id;
  select currency_code into v_wscur from public.workspaces where id = p_workspace_id;

  -- the receipt lines this command touches, locked in one order
  for e in select value from jsonb_array_elements(p_allocations) loop
    i := i + 1;
    select rl.id into v_rl.id from public.purchase_order_receipt_lines rl
      join public.purchase_order_lines ol on ol.id = rl.order_line_id
     where rl.receipt_id = p_receipt_id and rl.workspace_id = p_workspace_id
       and ((e ? 'receipt_line_id' and rl.id = nullif(e ->> 'receipt_line_id', '')::uuid)
         or (e ? 'line_no' and ol.line_no = nullif(e ->> 'line_no', '')::int));
    if v_rl.id is null then
      perform public.stock_config_refuse(format('allocations[%s].line', i - 1), 'line_unknown');
    end if;
    v_ids := v_ids || v_rl.id;
  end loop;
  perform 1 from public.purchase_order_receipt_lines where id = any (v_ids) order by id for update;

  i := 0;
  for e in select value from jsonb_array_elements(p_allocations) loop
    i := i + 1;
    select rl.* into v_rl from public.purchase_order_receipt_lines rl
      join public.purchase_order_lines ol on ol.id = rl.order_line_id
     where rl.receipt_id = p_receipt_id
       and ((e ? 'receipt_line_id' and rl.id = nullif(e ->> 'receipt_line_id', '')::uuid)
         or (e ? 'line_no' and ol.line_no = nullif(e ->> 'line_no', '')::int));
    select * into v_ol from public.purchase_order_lines where id = v_rl.order_line_id;
    select * into v_item from public.services
     where id = v_ol.service_id and workspace_id = p_workspace_id and stockable;
    if v_item.id is null then
      perform public.stock_config_refuse(format('allocations[%s].line', i - 1), 'item_not_stocked');
    end if;
    v_unit := coalesce(nullif(v_ol.unit, ''), v_item.inventory_unit);
    begin
      perform public.stock_to_inventory(v_item.id, v_unit, 1);
      select * into v_fac from public.stock_unit_factor(v_item.id, v_unit);
      if v_fac.num is null then raise exception 'no factor' using errcode = 'DKG05'; end if;
    exception when others then
      perform public.stock_config_refuse(format('allocations[%s].line', i - 1), 'unit_unmapped');
    end;
    v_entered := nullif(e ->> 'quantity', '')::numeric;
    if v_entered is null or v_entered <= 0 or round(v_entered, 6) <> v_entered then
      perform public.stock_config_refuse(format('allocations[%s].quantity', i - 1), 'quantity_invalid');
    end if;
    v_have := coalesce((select sum(a.entered_quantity) from public.stock_receipt_allocations a
                         where a.receipt_line_id = v_rl.id), 0)
              + coalesce((v_running ->> v_rl.id::text)::numeric, 0);
    if v_have + v_entered > v_rl.quantity then
      perform public.stock_config_refuse(format('allocations[%s].quantity', i - 1), 'over_allocated');
    end if;
    v_running := v_running || jsonb_build_object(v_rl.id::text, coalesce((v_running ->> v_rl.id::text)::numeric, 0) + v_entered);
    v_inv := round(public.stock_to_inventory(v_item.id, v_unit, v_entered), 6);
    if v_inv <= 0 then
      perform public.stock_config_refuse(format('allocations[%s].quantity', i - 1), 'quantity_invalid');
    end if;

    v_var := nullif(e ->> 'variant_id', '')::uuid;
    if v_var is not null and not exists (select 1 from public.item_variants x
         where x.id = v_var and x.item_id = v_item.id and x.workspace_id = p_workspace_id and x.active) then
      perform public.stock_config_refuse(format('allocations[%s].variant_id', i - 1), 'variant_unknown');
    end if;
    if v_var is null and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then
      perform public.stock_config_refuse(format('allocations[%s].variant_id', i - 1), 'variant_required');
    end if;
    v_loc := nullif(e ->> 'location_id', '')::uuid;
    if v_loc is null or not exists (select 1 from public.stock_locations l
         where l.id = v_loc and l.workspace_id = p_workspace_id and l.active and not public.stock_place_is_virtual(l.id)) then
      perform public.stock_config_refuse(format('allocations[%s].location_id', i - 1), 'location_foreign');
    end if;

    v_group := coalesce(nullif(e ->> 'group', ''), '1');
    v_key := v_rl.id::text || '|' || coalesce(v_var::text, '') || '|' || v_group;
    v_lot_meta := coalesce(e -> 'lot', '{}'::jsonb);
    v_cost := coalesce(e -> 'cost', '{"state": "unknown"}'::jsonb);
    if v_groups ? v_key then
      -- later members of a group may repeat the first's lot and cost, or omit them
      v_first := v_groups -> v_key;
      if (e ? 'lot' and v_lot_meta is distinct from v_first -> 'lot')
         or (e ? 'cost' and v_cost is distinct from v_first -> 'cost') then
        perform public.stock_config_refuse(format('allocations[%s].group', i - 1), 'lot_group_conflict');
      end if;
    else
      if v_item.tracking in ('lot', 'expiry') and btrim(coalesce(v_lot_meta ->> 'code', '')) = '' then
        perform public.stock_config_refuse(format('allocations[%s].lot.code', i - 1), 'lot_code_required');
      end if;
      if char_length(coalesce(v_lot_meta ->> 'code', '')) > 64 then
        perform public.stock_config_refuse(format('allocations[%s].lot.code', i - 1), 'lot_code_required');
      end if;
      if v_item.tracking = 'expiry' and nullif(v_lot_meta ->> 'expires_on', '') is null then
        perform public.stock_config_refuse(format('allocations[%s].lot.expires_on', i - 1), 'expiry_required');
      end if;
      if nullif(v_lot_meta ->> 'expires_on', '') is not null then
        begin
          v_expires := (v_lot_meta ->> 'expires_on')::date;
        exception when others then
          perform public.stock_config_refuse(format('allocations[%s].lot.expires_on', i - 1), 'expiry_malformed');
        end;
      end if;
      v_state := coalesce(v_cost ->> 'state', 'unknown');
      if v_state not in ('unknown', 'known', 'order_price') then
        perform public.stock_config_refuse(format('allocations[%s].cost', i - 1), 'cost_invalid');
      end if;
      if v_state = 'known' then
        if nullif(v_cost ->> 'total_cost_minor', '') is null
           or (v_cost ->> 'total_cost_minor') !~ '^[0-9]{1,15}$' then
          perform public.stock_config_refuse(format('allocations[%s].cost', i - 1), 'cost_invalid');
        end if;
        if (nullif(v_cost ->> 'source_currency', '') is null) <> (nullif(v_cost ->> 'source_rate', '') is null)
           or (v_cost ->> 'source_currency') !~ '^([A-Z]{3})?$'
           or (nullif(v_cost ->> 'source_rate', '') is not null and (v_cost ->> 'source_rate')::numeric <= 0) then
          perform public.stock_config_refuse(format('allocations[%s].cost', i - 1), 'cost_invalid');
        end if;
      end if;
      if v_state = 'order_price' and v_order.currency <> v_wscur
         and nullif(v_cost ->> 'source_rate', '') is null then
        perform public.stock_config_refuse(format('allocations[%s].cost', i - 1), 'cost_rate_missing');
      end if;
      v_groups := v_groups || jsonb_build_object(v_key, jsonb_build_object('lot', v_lot_meta, 'cost', v_cost));
    end if;

    v_plan := v_plan || jsonb_build_array(jsonb_build_object(
      'i', i, 'key', v_key, 'receipt_line_id', v_rl.id, 'order_line_id', v_ol.id, 'item_id', v_item.id,
      'variant_id', v_var, 'unit', v_unit, 'entered', v_entered, 'inv', v_inv, 'num', v_fac.num, 'den', v_fac.den,
      'location_id', v_loc, 'line_text', coalesce(nullif(v_ol.description, ''), v_item.name),
      'unit_price_cents', v_ol.unit_price_cents));
  end loop;

  -- one new lot per group: its quantity and (for the order price) its cost
  -- follow from every member of the group
  for g in select k as key from jsonb_object_keys(v_groups) k loop
    select sum((x ->> 'inv')::numeric), sum((x ->> 'entered')::numeric)
      into v_gqty, v_gentered
      from jsonb_array_elements(v_plan) x where x ->> 'key' = g.key;
    v_cost := v_groups -> g.key -> 'cost';
    v_lot_meta := v_groups -> g.key -> 'lot';
    v_state := coalesce(v_cost ->> 'state', 'unknown');
    if v_state = 'known' then
      v_total := (v_cost ->> 'total_cost_minor')::bigint;
      v_cur := nullif(v_cost ->> 'source_currency', '');
      v_rate := nullif(v_cost ->> 'source_rate', '')::numeric;
      v_src := 'entered';
    elsif v_state = 'order_price' then
      v_rate := case when v_order.currency <> v_wscur then (v_cost ->> 'source_rate')::numeric end;
      v_total := round((select min((x ->> 'unit_price_cents')::numeric) from jsonb_array_elements(v_plan) x where x ->> 'key' = g.key)
                       * v_gentered * coalesce(v_rate, 1));
      v_cur := case when v_order.currency <> v_wscur then v_order.currency end;
      v_src := 'order_price';
    else
      v_total := 0; v_cur := null; v_rate := null; v_src := null;
    end if;
    insert into public.stock_lots (workspace_id, item_id, variant_id, lot_code, expires_on, total_cost_minor,
                                   quantity_received, source_currency, source_rate, receipt_line_id,
                                   cost_state, cost_source)
    select p_workspace_id, (x ->> 'item_id')::uuid, nullif(x ->> 'variant_id', '')::uuid,
           coalesce(v_lot_meta ->> 'code', ''), nullif(v_lot_meta ->> 'expires_on', '')::date, v_total, v_gqty,
           v_cur, v_rate, (x ->> 'receipt_line_id')::uuid,
           case when v_state = 'unknown' then 'unknown' else 'known' end, v_src
      from (select x from jsonb_array_elements(v_plan) x where x ->> 'key' = g.key limit 1) f(x)
    returning id into v_lot;
    v_groups := v_groups || jsonb_build_object(g.key, (v_groups -> g.key) || jsonb_build_object('lot_id', v_lot));
  end loop;

  for p in select value from jsonb_array_elements(v_plan) loop
    v_lot := (v_groups -> (p ->> 'key') ->> 'lot_id')::uuid;
    v_mv := public.stock_record(p_workspace_id, (p ->> 'item_id')::uuid, v_lot, v_from,
      (p ->> 'location_id')::uuid, (p ->> 'inv')::numeric, p ->> 'unit', (p ->> 'entered')::numeric, now(),
      'receipt', p_actor, p_command, (p ->> 'i')::int, 1,
      jsonb_build_object('receipt_line_id', p ->> 'receipt_line_id'), nullif(p ->> 'variant_id', '')::uuid);
    insert into public.stock_receipt_allocations
      (workspace_id, receipt_id, receipt_line_id, order_line_id, item_id, variant_id, entered_unit, entered_quantity,
       factor_num, factor_den, inventory_quantity, lot_id, location_id, movement_id, command_request_id, part,
       order_reference, supplier_name, line_text)
    values (p_workspace_id, p_receipt_id, (p ->> 'receipt_line_id')::uuid, (p ->> 'order_line_id')::uuid,
            (p ->> 'item_id')::uuid, nullif(p ->> 'variant_id', '')::uuid, p ->> 'unit', (p ->> 'entered')::numeric,
            (p ->> 'num')::bigint, (p ->> 'den')::bigint, (p ->> 'inv')::numeric, v_lot,
            (p ->> 'location_id')::uuid, v_mv, p_command, (p ->> 'i')::int,
            coalesce(v_order.reference, ''), v_supplier, p ->> 'line_text')
    returning id into v_aid;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'id', v_aid, 'part', (p ->> 'i')::int, 'receipt_line_id', p ->> 'receipt_line_id', 'item_id', p ->> 'item_id',
      'variant_id', p ->> 'variant_id', 'lot_id', v_lot, 'location_id', p ->> 'location_id',
      'movement_id', v_mv, 'entered_quantity', (p ->> 'entered')::numeric, 'inventory_quantity', (p ->> 'inv')::numeric));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb) from public, anon, authenticated;

-- Put away (more of) a recorded delivery.
create or replace function public.put_away_receipt_v1(
  p_workspace_id uuid, p_receipt_id uuid, p_request_id uuid, p_allocations jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_out jsonb;
begin
  v_me := public.stock_receiving_actor(p_workspace_id);
  if p_request_id is null or p_receipt_id is null then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5(p_receipt_id::text || '|' || coalesce(p_allocations::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'receipt_put_away', v_digest);
  if v_done is not null then return v_done || jsonb_build_object('replayed', true); end if;
  v_out := public.stock_put_away_apply(p_workspace_id, v_me, p_request_id, p_receipt_id, p_allocations);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'receipt_put_away', v_digest,
    jsonb_build_object('receipt_id', p_receipt_id, 'allocations', v_out, 'replayed', false));
end;
$fn$;
revoke execute on function public.put_away_receipt_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.put_away_receipt_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- Record a delivery and put it away in one transaction: 0684's function, as it
-- is, under a request id derived from this one, then the put-away.
create or replace function public.record_receipt_and_put_away_v1(
  p_workspace_id uuid, p_order_id uuid, p_revision int, p_received_on date,
  p_lines jsonb, p_note text, p_request_id uuid, p_allocations jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_receipt jsonb;
  v_out jsonb;
begin
  v_me := public.stock_receiving_actor(p_workspace_id);
  if p_request_id is null then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5(p_order_id::text || '|' || coalesce(p_revision, 0)::text || '|' || coalesce(p_received_on::text, '')
                  || '|' || coalesce(p_lines::text, '') || '|' || coalesce(p_note, '') || '|' || coalesce(p_allocations::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'receipt_and_put_away', v_digest);
  if v_done is not null then return v_done || jsonb_build_object('replayed', true); end if;
  v_receipt := public.record_purchase_order_receipt_v1(p_workspace_id, p_order_id, p_revision, p_received_on,
    p_lines, p_note, md5(p_request_id::text || ':receipt')::uuid);
  v_out := public.stock_put_away_apply(p_workspace_id, v_me, p_request_id,
    (v_receipt ->> 'receipt_id')::uuid, p_allocations);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'receipt_and_put_away', v_digest,
    jsonb_build_object('receipt_id', v_receipt ->> 'receipt_id', 'order', v_receipt - 'receipt_id',
                       'allocations', v_out, 'replayed', false));
end;
$fn$;
revoke execute on function public.record_receipt_and_put_away_v1(uuid, uuid, int, date, jsonb, text, uuid, jsonb) from public, anon;
grant execute on function public.record_receipt_and_put_away_v1(uuid, uuid, int, date, jsonb, text, uuid, jsonb) to authenticated;

-- ── the workspace export carries what was put away (#2860): 0837's function restated ──
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
    'stock_receipt_allocations'];
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

select public.set_deskilo_schema_version(840);
