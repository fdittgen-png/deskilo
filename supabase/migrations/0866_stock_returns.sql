-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (a reason, a unique index on the movements, two tables and two functions; the workspace export
--  function is restated whole)
--
-- #4172 (G5, checkpoint A, first server file): bounded returns and corrections.
--
--   * A RETURN is a logical physical event with a stable `return_id`, and each of its lines has a
--     stable `return_line_id`, both apart from the transport `request_id`. Sending the same logical
--     return again, with the same request id or a new one, answers the recorded result and writes
--     nothing; the same return id with other content is refused (DKG16). A line id belongs to one
--     return only.
--   * Every line reverses ONE movement (`source_movement_id`) for a quantity, and the sum of what was
--     ever reversed on a movement never exceeds its quantity: the source row is locked while the
--     previous reversals are summed, so two returns of different identities cannot together return
--     more than there was (DKG17). The source row and its frozen cost are never touched.
--   * A customer return (`customer`) re-enters the original item, variant and lot, from the customer
--     place of a sale to a real place chosen. A supplier return (`supplier`) leaves from the real place
--     where the goods are now, to the supplier place of the receipt it reverses, in that receipt's
--     lot: the receipt is not subtracted a second time, the on-hand quantity is (DKG03 when it is not
--     there). A correction (`correction`) is a movement back: from the place the source went to, to the
--     place it came from; a correction of a correction chains through the earlier correction's
--     movement; the opening, a transfer's movements and a business's other movements are not
--     corrected here, and reversing an adjustment needs the right to approve adjustments.
--   * Money is not touched: no payment, refund, credit or posting is made, and a payment reversal does
--     not return goods. The reversal says which movement and which sale or delivery it follows.
--   * The reader `stock_reversible_v1` says, for movements, how much each can still be reversed and
--     what was already.

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

-- ── the reason of a correction ─────────────────────────────────────────
insert into public.stock_reasons (key, sort_order) values ('correction', 100) on conflict (key) do nothing;

-- the reversals reference a movement of their own business
create unique index if not exists stock_movements_workspace_id on public.stock_movements (workspace_id, id);

-- ── the returns and what each line reversed ────────────────────────────
create table public.stock_returns (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  return_id uuid not null,
  kind text not null check (kind in ('customer', 'supplier', 'correction')),
  digest text not null,
  request_id uuid not null,
  actor_member_id uuid,
  occurred_at timestamptz not null,
  result jsonb not null,
  unique (workspace_id, return_id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('stock_returns');

create table public.stock_reversals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  return_id uuid not null,
  return_line_id uuid not null,
  kind text not null check (kind in ('customer', 'supplier', 'correction')),
  source_movement_id uuid not null,
  movement_id uuid not null,
  quantity numeric(18, 6) not null check (quantity > 0),
  note text not null default '' check (char_length(note) <= 300),
  unique (workspace_id, return_line_id),
  unique (movement_id),
  foreign key (workspace_id, return_id) references public.stock_returns (workspace_id, return_id) on delete cascade,
  foreign key (workspace_id, source_movement_id) references public.stock_movements (workspace_id, id) on delete cascade,
  foreign key (workspace_id, movement_id) references public.stock_movements (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_reversals');
create index stock_reversals_source on public.stock_reversals (workspace_id, source_movement_id);

-- immutable: a wrong return is corrected by a movement back, never edited; deleted only with its business
create or replace function public.stock_returns_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'a return is never edited or deleted: a mistake is a correction' using errcode = 'DKG08';
end;
$fn$;
revoke execute on function public.stock_returns_append_only() from public, anon, authenticated;
create trigger stock_returns_append_only before update or delete on public.stock_returns
  for each row execute function public.stock_returns_append_only();
create trigger stock_reversals_append_only before update or delete on public.stock_reversals
  for each row execute function public.stock_returns_append_only();

alter table public.stock_returns enable row level security;
alter table public.stock_reversals enable row level security;
revoke all on public.stock_returns, public.stock_reversals from public, anon, authenticated;
grant select on public.stock_returns, public.stock_reversals to authenticated;
create policy stock_returns_select on public.stock_returns for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockReturns'));
create policy stock_reversals_select on public.stock_reversals for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockReturns'));
create policy mcp_delegated_deny on public.stock_returns as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_reversals as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the workspace export carries them (#2860): 0856's function restated ──
-- restates 0856
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
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
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

-- The reason of the movement a chain of corrections started from: a correction of a correction of a loss
-- is still the reversal of a loss.
create or replace function public.stock_correction_root_reason(p_workspace_id uuid, p_movement_id uuid)
returns text language sql stable security definer set search_path = public as $fn$
  with recursive chain(id, reason, depth) as (
    select m.id, m.reason, 0 from public.stock_movements m where m.id = p_movement_id and m.workspace_id = p_workspace_id
    union all
    select s.id, s.reason, c.depth + 1
      from chain c
      join public.stock_reversals r on r.movement_id = c.id and r.workspace_id = p_workspace_id
      join public.stock_movements s on s.id = r.source_movement_id
     where c.reason = 'correction' and c.depth < 100)
  select reason from chain order by depth desc limit 1
$fn$;
revoke execute on function public.stock_correction_root_reason(uuid, uuid) from public, anon, authenticated;

-- ── the command ────────────────────────────────────────────────────────
-- Lines: [{return_line_id, source_movement_id, quantity, location?, note?}] with [location] the real
-- place the goods go back to (customer) or leave from (supplier); a correction names none. [quantity]
-- is in the item's inventory unit. Lock order: the items (id order), then the source movements (id
-- order), then what the movements touch, as every stock command.
create or replace function public.stock_return_v1(
  p_workspace_id uuid, p_request_id uuid, p_return_id uuid, p_kind text, p_lines jsonb,
  p_occurred_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_at timestamptz := coalesce(p_occurred_at, now());
  e jsonb;
  v_no int := 0;
  v_digest text;
  v_done jsonb;
  v_first public.stock_returns;
  v_sources uuid[] := array[]::uuid[];
  v_lines uuid[] := array[]::uuid[];
  v_items uuid[];
  v_src public.stock_movements;
  v_unit text;
  v_qty numeric;
  v_prior numeric;
  v_loc public.stock_locations;
  v_line uuid;
  v_from uuid;
  v_to uuid;
  v_reason text;
  v_root text;
  v_links jsonb;
  v_mid uuid;
  v_transit uuid := public.stock_transit_place(p_workspace_id);
  v_out jsonb := '[]'::jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if not public.feature_effective(p_workspace_id, 'stockReturns') then
    raise exception 'returns are off in this business' using errcode = 'DKG01';
  end if;
  perform public.stock_command_args(p_request_id, p_lines);
  if p_return_id is null or p_kind is null or p_kind not in ('customer', 'supplier', 'correction') then
    raise exception 'a return has an identity and a kind: customer, supplier or correction' using errcode = 'DKG07';
  end if;
  if v_at > now() + interval '5 minutes' then raise exception 'a command is not in the future' using errcode = 'DKG07'; end if;

  -- every line is well formed before anything is read or locked
  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    if coalesce(e ->> 'return_line_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
       or coalesce(e ->> 'source_movement_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      raise exception 'line %: a line names its own id and the movement it reverses', v_no using errcode = 'DKG07';
    end if;
    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      raise exception 'line %: a quantity above zero', v_no using errcode = 'DKG07';
    end if;
    if p_kind <> 'correction' and coalesce(e ->> 'location', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      raise exception 'line %: a return names the place the goods go to or leave from', v_no using errcode = 'DKG05';
    end if;
    if char_length(coalesce(e ->> 'note', '')) > 300 then
      raise exception 'line %: a note is at most 300 characters', v_no using errcode = 'DKG07';
    end if;
    if (e ->> 'return_line_id')::uuid = any (v_lines) then
      raise exception 'line %: a line id is used once in a return', v_no using errcode = 'DKG07';
    end if;
    v_lines := v_lines || (e ->> 'return_line_id')::uuid;
    v_sources := v_sources || (e ->> 'source_movement_id')::uuid;
  end loop;

  -- the same transport request answers what it answered; the same logical return answers what it recorded
  v_digest := md5(jsonb_build_array(p_kind, p_return_id, extract(epoch from p_occurred_at), (
    select jsonb_agg(l order by l ->> 'return_line_id') from jsonb_array_elements(p_lines) l))::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_return', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtextextended('stock_return:' || p_workspace_id::text || ':' || p_return_id::text, 0));
  select * into v_first from public.stock_returns where workspace_id = p_workspace_id and return_id = p_return_id;
  if v_first.id is not null then
    if v_first.digest <> v_digest then
      raise exception 'this return was already recorded with other content' using errcode = 'DKG16';
    end if;
    return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_return', v_digest, v_first.result);
  end if;
  if exists (select 1 from public.stock_reversals r where r.workspace_id = p_workspace_id and r.return_line_id = any (v_lines)) then
    raise exception 'a line id belongs to one return only' using errcode = 'DKG16';
  end if;

  -- the items, then the source movements, each in id order
  select array_agg(distinct m.item_id order by m.item_id) into v_items
    from public.stock_movements m where m.workspace_id = p_workspace_id and m.id = any (v_sources);
  if v_items is null or (select count(*) from public.stock_movements m
                          where m.workspace_id = p_workspace_id and m.id = any (v_sources))
                        <> (select count(distinct x) from unnest(v_sources) x) then
    raise exception 'a line names a movement of another business or none' using errcode = 'DKG04';
  end if;
  perform 1 from public.services where id = any (v_items) and workspace_id = p_workspace_id order by id for update;
  perform 1 from public.stock_movements where workspace_id = p_workspace_id and id = any (v_sources) order by id for update;

  v_no := 0;
  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    select * into v_src from public.stock_movements
     where id = (e ->> 'source_movement_id')::uuid and workspace_id = p_workspace_id;
    v_qty := (e ->> 'quantity')::numeric;
    v_line := (e ->> 'return_line_id')::uuid;
    if v_at < v_src.occurred_at then
      raise exception 'line %: a reversal is not dated before the movement it reverses', v_no using errcode = 'DKG07';
    end if;
    select inventory_unit into v_unit from public.services where id = v_src.item_id;
    -- what was reversed on this movement before, the source row being locked
    select coalesce(sum(r.quantity), 0) into v_prior from public.stock_reversals r
     where r.workspace_id = p_workspace_id and r.source_movement_id = v_src.id;
    -- and what an earlier line of this very return takes from the same movement
    v_prior := v_prior + coalesce((select sum((x ->> 'quantity')::numeric) from jsonb_array_elements(v_rows) x
                                    where x ->> 'source' = v_src.id::text), 0);
    v_links := jsonb_strip_nulls(jsonb_build_object('invoice_id', v_src.invoice_id, 'event_id', v_src.event_id,
      'receipt_line_id', v_src.receipt_line_id, 'purchase_line_id', v_src.purchase_line_id));

    if p_kind = 'customer' then
      if v_src.reason <> 'sale' or not exists (select 1 from public.stock_locations l
           where l.id = v_src.to_location_id and l.kind = 'customer') then
        raise exception 'line %: a customer return follows a sale', v_no using errcode = 'DKG18';
      end if;
      select * into v_loc from public.stock_locations
       where id = (e ->> 'location')::uuid and workspace_id = p_workspace_id and active;
      if v_loc.id is null or public.stock_place_is_virtual(v_loc.id) or v_loc.id = v_transit then
        raise exception 'line %: the goods come back to a real place of this business', v_no using errcode = 'DKG05';
      end if;
      v_from := v_src.to_location_id; v_to := v_loc.id; v_reason := 'return_in';
    elsif p_kind = 'supplier' then
      if v_src.reason <> 'receipt' then
        raise exception 'line %: a supplier return follows a receipt', v_no using errcode = 'DKG18';
      end if;
      select * into v_loc from public.stock_locations
       where id = (e ->> 'location')::uuid and workspace_id = p_workspace_id and active;
      if v_loc.id is null or public.stock_place_is_virtual(v_loc.id) or v_loc.id = v_transit then
        raise exception 'line %: the goods leave from a real place of this business', v_no using errcode = 'DKG05';
      end if;
      v_from := v_loc.id; v_to := v_src.from_location_id; v_reason := 'return_out';
    else
      if v_src.reason = 'opening'
         or v_src.from_location_id = v_transit or v_src.to_location_id = v_transit then
        raise exception 'line %: this movement is not corrected here', v_no using errcode = 'DKG18';
      end if;
      -- what the chain of corrections started from decides, not the last link: reversing a take-out is
      -- taking goods back in (the take-out's own feature stays the condition), reversing an adjustment is
      -- approving one
      v_root := public.stock_correction_root_reason(p_workspace_id, v_src.id);
      if v_root in ('consumption', 'loss') and not public.feature_effective(p_workspace_id, 'stockTakeOut') then
        raise exception 'line %: taking goods out is off in this business, and so is reversing it', v_no using errcode = 'DKG01';
      end if;
      if v_root = 'adjustment' and not public.has_permission(p_workspace_id, 'approveStockAdjustments') then
        raise exception 'line %: reversing an adjustment is approving one', v_no using errcode = 'DKN01';
      end if;
      v_from := v_src.to_location_id; v_to := v_src.from_location_id; v_reason := 'correction';
    end if;

    -- the kind and the places are right: now the bound, the source row being locked
    if v_qty > v_src.quantity - v_prior then
      raise exception 'line %: only % can still be reversed on this movement', v_no, (v_src.quantity - v_prior)::text
        using errcode = 'DKG17';
    end if;
    v_mid := public.stock_record(p_workspace_id, v_src.item_id, v_src.lot_id, v_from, v_to, v_qty,
      v_unit, v_qty, v_at, v_reason, v_me, p_request_id, v_no, 1, v_links, v_src.variant_id);
    v_rows := v_rows || jsonb_build_array(jsonb_build_object('line', v_line, 'source', v_src.id, 'movement', v_mid,
      'quantity', v_qty, 'note', coalesce(e ->> 'note', '')));
    v_out := v_out || jsonb_build_array(jsonb_build_object('return_line_id', v_line, 'movement_id', v_mid,
      'source_movement_id', v_src.id, 'quantity', v_qty::text, 'remaining', (v_src.quantity - v_prior - v_qty)::text));
  end loop;

  v_result := jsonb_build_object('return_id', p_return_id, 'kind', p_kind, 'lines', v_out);
  insert into public.stock_returns (workspace_id, return_id, kind, digest, request_id, actor_member_id, occurred_at, result)
  values (p_workspace_id, p_return_id, p_kind, v_digest, p_request_id, v_me, v_at, v_result);
  insert into public.stock_reversals (workspace_id, return_id, return_line_id, kind, source_movement_id, movement_id, quantity, note)
  select p_workspace_id, p_return_id, (x ->> 'line')::uuid, p_kind, (x ->> 'source')::uuid, (x ->> 'movement')::uuid,
         (x ->> 'quantity')::numeric, x ->> 'note'
    from jsonb_array_elements(v_rows) x;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_return', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_return_v1(uuid, uuid, uuid, text, jsonb, timestamptz) from public, anon;
grant execute on function public.stock_return_v1(uuid, uuid, uuid, text, jsonb, timestamptz) to authenticated;

-- ── what can still be reversed ─────────────────────────────────────────
-- For each movement named: its quantity, what was reversed, what remains, and the reversals.
create or replace function public.stock_reversible_v1(p_workspace_id uuid, p_movement_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock'))
     or not public.is_member_of(p_workspace_id) then
    raise exception 'not allowed to read the stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockReturns') then
    raise exception 'returns are off in this business' using errcode = 'DKG01';
  end if;
  if cardinality(coalesce(p_movement_ids, array[]::uuid[])) > 200 then
    raise exception 'at most 200 movements at once' using errcode = 'DKG07';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'movement_id', m.id, 'item_id', m.item_id, 'variant_id', m.variant_id, 'lot_id', m.lot_id,
      'reason', m.reason, 'quantity', m.quantity::text,
      'reversed', coalesce(r.total, 0)::text, 'remaining', (m.quantity - coalesce(r.total, 0))::text,
      'reversals', coalesce(r.list, '[]'::jsonb)) order by m.id)
      from public.stock_movements m
      left join lateral (
        select sum(x.quantity) as total,
               jsonb_agg(jsonb_build_object('return_id', x.return_id, 'return_line_id', x.return_line_id,
                 'kind', x.kind, 'quantity', x.quantity::text, 'movement_id', x.movement_id) order by x.created_datetime, x.id) as list
          from public.stock_reversals x where x.workspace_id = m.workspace_id and x.source_movement_id = m.id) r on true
     where m.workspace_id = p_workspace_id and m.id = any (p_movement_ids)
  ), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.stock_reversible_v1(uuid, uuid[]) from public, anon;
grant execute on function public.stock_reversible_v1(uuid, uuid[]) to authenticated;

select public.set_deskilo_schema_version(866);
