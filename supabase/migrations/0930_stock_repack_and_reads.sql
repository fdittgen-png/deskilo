-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (new functions only)
--
-- #4435 (G20, third of four files) -- repack, and the reads of handling units.
--   * `stock_hu_repack_v1(workspace, request, sources, targets)`: the store takes content out of units (or loose stock) and makes
--     its own units from it (one pallet into 40 store boxes). Each source names a unit (or none for loose stock) and an item,
--     variant, lot and quantity (and the pieces of a piece-tracked line); each target is a new unit as `stock_hu_make_v1` takes it.
--     What goes out equals what goes in, per item, variant and lot, and the pieces taken out are the pieces put in: the on-hand
--     total never changes. A repack happens at ONE place (every source and target there): moving the new units is `stock_hu_move_v1`.
--     It writes no stock movement, since no balance moves; what it did is the append-only provenance `stock_repacks` and
--     `stock_repack_lines` (out of which unit, into which unit, the lot, the piece), so a lot followed through a repack is found
--     on both sides.
--   * `stock_hu_page_v1(workspace, place, state, limit, after)` lists the units, `stock_hu_v1(workspace, unit)` reads one with its
--     content, its pieces (and their tags) and the units nested in it, `stock_hu_lot_trace_v1(workspace, item, lot)` lists where
--     a lot is held in units and every repack that touched it. Whoever may see the stock reads; an assistant is refused.
-- Refusals as in 0929; DKG28 reasons added: one_place, conservation, not_in_unit.

create or replace function public.stock_hu_repack_v1(p_workspace_id uuid, p_request_id uuid, p_sources jsonb, p_targets jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_repack uuid;
  v_place uuid;
  v_loc uuid;
  s jsonb;
  t jsonb;
  l jsonb;
  u record;
  v_unit public.stock_handling_units;
  v_line public.stock_handling_unit_lines;
  v_item uuid;
  v_var uuid;
  v_lot uuid;
  v_qty numeric;
  v_new uuid;
  v_new_ids uuid[] := array[]::uuid[];
  v_touched uuid[] := array[]::uuid[];
  v_out_pieces uuid[] := array[]::uuid[];
  v_in_pieces uuid[] := array[]::uuid[];
  v_pid uuid;
  v_serial boolean;
  v_diff record;
begin
  perform public.stock_hu_require(p_workspace_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_sources), '') <> 'array' or coalesce(jsonb_typeof(p_targets), '') <> 'array'
     or jsonb_array_length(p_sources) not between 1 and 200 or jsonb_array_length(p_targets) not between 1 and 200 then
    perform public.refuse('DKG07', null, 'a repack has a request id, 1 to 200 sources and 1 to 200 targets');
  end if;
  v_digest := md5('hu_repack|' || p_sources::text || '|' || p_targets::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_hu_repack', v_digest);
  if v_done is not null then return v_done; end if;
  -- the items of every line, then the source units, each locked in id order so that opposing repacks cannot deadlock
  perform public.stock_hu_lock_items(p_workspace_id, p_sources || (select coalesce(jsonb_agg(tl.value), '[]'::jsonb) from jsonb_array_elements(p_targets) tg,
    jsonb_array_elements(case when jsonb_typeof(tg.value -> 'lines') = 'array' then tg.value -> 'lines' else '[]'::jsonb end) tl));
  perform 1 from public.stock_handling_units
   where workspace_id = p_workspace_id
     and id in (select public.stock_hu_uuid(x ->> 'unit_id', 'unit_id') from jsonb_array_elements(p_sources) x where nullif(x ->> 'unit_id', '') is not null)
   order by id for update;
  insert into public.stock_repacks (workspace_id, request_id, made_by) values (p_workspace_id, p_request_id, v_me) returning id into v_repack;

  for s in select value from jsonb_array_elements(p_sources) loop
    v_item := public.stock_hu_uuid(s ->> 'item_id', 'item_id');
    v_var := public.stock_hu_uuid(s ->> 'variant_id', 'variant_id');
    v_lot := public.stock_hu_uuid(s ->> 'lot_id', 'lot_id');
    if coalesce(s ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (s ->> 'quantity')::numeric <= 0 then
      perform public.refuse('DKG28', jsonb_build_object('reason', 'quantity', 'item_id', v_item), 'a quantity is a positive number');
    end if;
    v_qty := (s ->> 'quantity')::numeric;
    v_serial := exists (select 1 from public.services where id = v_item and workspace_id = p_workspace_id and tracking = 'serial');
    if nullif(s ->> 'unit_id', '') is not null then
      v_unit := public.stock_hu_lock(p_workspace_id, public.stock_hu_uuid(s ->> 'unit_id', 'unit_id'),
        case when s ? 'revision' then (s ->> 'revision')::int end);
      v_loc := v_unit.location_id;
      select * into v_line from public.stock_handling_unit_lines
       where unit_id = v_unit.id and item_id = v_item and variant_id is not distinct from v_var and lot_id is not distinct from v_lot for update;
      if v_line.id is null or v_line.quantity < v_qty then
        perform public.refuse('DKG28', jsonb_build_object('reason', 'not_in_unit', 'unit_id', v_unit.id, 'item_id', v_item,
          'have', coalesce(v_line.quantity, 0), 'asked', v_qty), 'the unit does not hold that much of it');
      end if;
      if v_serial then
        if coalesce(jsonb_typeof(s -> 'units'), '') <> 'array' or jsonb_array_length(s -> 'units') <> v_qty then
          perform public.refuse('DKG28', jsonb_build_object('reason', 'pieces', 'item_id', v_item), 'a piece-tracked line names its pieces');
        end if;
        for u in select value from jsonb_array_elements(s -> 'units') loop
          v_pid := public.stock_hu_uuid(u.value ->> 'piece_id', 'piece_id');
          delete from public.stock_handling_unit_pieces where piece_id = v_pid and unit_line_id = v_line.id;
          if not found then
            perform public.refuse('DKG28', jsonb_build_object('reason', 'not_in_unit', 'unit_id', v_unit.id, 'piece_id', v_pid), 'the piece is not in this unit');
          end if;
          v_out_pieces := v_out_pieces || v_pid;
          insert into public.stock_repack_lines (workspace_id, repack_id, direction, unit_id, item_id, variant_id, lot_id, quantity, piece_id)
          values (p_workspace_id, v_repack, 'out', v_unit.id, v_item, v_var, v_lot, 1, v_pid);
        end loop;
      else
        insert into public.stock_repack_lines (workspace_id, repack_id, direction, unit_id, item_id, variant_id, lot_id, quantity)
        values (p_workspace_id, v_repack, 'out', v_unit.id, v_item, v_var, v_lot, v_qty);
      end if;
      if v_line.quantity = v_qty then
        delete from public.stock_handling_unit_lines where id = v_line.id;
      else
        update public.stock_handling_unit_lines set quantity = quantity - v_qty where id = v_line.id;
      end if;
      v_touched := v_touched || v_unit.id;
    else
      v_loc := public.stock_hu_uuid(s ->> 'location_id', 'location_id');
      if v_serial then
        if coalesce(jsonb_typeof(s -> 'units'), '') <> 'array' or jsonb_array_length(s -> 'units') <> v_qty then
          perform public.refuse('DKG28', jsonb_build_object('reason', 'pieces', 'item_id', v_item), 'a piece-tracked line names its pieces');
        end if;
        for u in select value from jsonb_array_elements(s -> 'units') loop
          v_pid := public.stock_hu_uuid(u.value ->> 'piece_id', 'piece_id');
          v_out_pieces := v_out_pieces || v_pid;
          insert into public.stock_repack_lines (workspace_id, repack_id, direction, item_id, variant_id, lot_id, quantity, piece_id)
          values (p_workspace_id, v_repack, 'out', v_item, v_var, v_lot, 1, v_pid);
        end loop;
      else
        if v_qty > public.stock_hu_loose(p_workspace_id, v_item, v_var, v_lot, v_loc) then
          perform public.refuse('DKG03', jsonb_build_object('item_id', v_item, 'location_id', v_loc,
            'have', public.stock_hu_loose(p_workspace_id, v_item, v_var, v_lot, v_loc), 'asked', v_qty), 'not that much loose here');
        end if;
        insert into public.stock_repack_lines (workspace_id, repack_id, direction, item_id, variant_id, lot_id, quantity)
        values (p_workspace_id, v_repack, 'out', v_item, v_var, v_lot, v_qty);
      end if;
    end if;
    if v_place is null then v_place := v_loc;
    elsif v_place <> v_loc then
      perform public.refuse('DKG28', jsonb_build_object('reason', 'one_place', 'location_id', v_loc), 'a repack happens at one place');
    end if;
  end loop;

  -- what the sources held is now loose: the targets claim it again
  for t in select value from jsonb_array_elements(p_targets) loop
    if public.stock_hu_uuid(t ->> 'location_id', 'location_id') is distinct from v_place then
      perform public.refuse('DKG28', jsonb_build_object('reason', 'one_place', 'location_id', t ->> 'location_id'), 'a repack happens at one place');
    end if;
    begin
      insert into public.stock_handling_units (workspace_id, code, label_code, kind, location_id)
      values (p_workspace_id, btrim(coalesce(t ->> 'code', '')), nullif(btrim(coalesce(t ->> 'label_code', '')), ''),
              coalesce(nullif(t ->> 'kind', ''), 'box'), v_place)
      returning id into v_new;
    exception
      when unique_violation then
        perform public.refuse('DKG29', jsonb_build_object('code', t ->> 'code'), 'this unit code is taken');
      when check_violation then
        perform public.refuse('DKG28', jsonb_build_object('reason', 'unit'), 'a unit needs a code and a known kind');
    end;
    v_new_ids := v_new_ids || v_new;
    if coalesce(jsonb_typeof(t -> 'lines'), '') <> 'array' or jsonb_array_length(t -> 'lines') not between 1 and 200 then
      perform public.refuse('DKG07', null, 'a unit has 1 to 200 lines');
    end if;
    for l in select value from jsonb_array_elements(t -> 'lines') loop
      perform public.stock_hu_add_line(p_workspace_id, v_new, v_place, l);
      v_item := public.stock_hu_uuid(l ->> 'item_id', 'item_id');
      v_var := public.stock_hu_uuid(l ->> 'variant_id', 'variant_id');
      v_lot := public.stock_hu_uuid(l ->> 'lot_id', 'lot_id');
      if l ? 'units' then
        for u in select value from jsonb_array_elements(l -> 'units') loop
          v_pid := public.stock_hu_uuid(u.value ->> 'piece_id', 'piece_id');
          v_in_pieces := v_in_pieces || v_pid;
          insert into public.stock_repack_lines (workspace_id, repack_id, direction, unit_id, item_id, variant_id, lot_id, quantity, piece_id)
          values (p_workspace_id, v_repack, 'in', v_new, v_item, v_var, v_lot, 1, v_pid);
        end loop;
      else
        insert into public.stock_repack_lines (workspace_id, repack_id, direction, unit_id, item_id, variant_id, lot_id, quantity)
        values (p_workspace_id, v_repack, 'in', v_new, v_item, v_var, v_lot, (l ->> 'quantity')::numeric);
      end if;
    end loop;
  end loop;

  -- what went out equals what came in, per item, variant and lot, and the pieces are the same pieces
  select x.item_id, x.variant_id, x.lot_id, x.q_out, x.q_in into v_diff from (
    select item_id, variant_id, lot_id,
           coalesce(sum(quantity) filter (where direction = 'out'), 0) as q_out,
           coalesce(sum(quantity) filter (where direction = 'in'), 0) as q_in
      from public.stock_repack_lines where workspace_id = p_workspace_id and repack_id = v_repack group by 1, 2, 3) x
   where x.q_out <> x.q_in limit 1;
  if v_diff.item_id is not null
     or (select array_agg(p order by p) from unnest(v_out_pieces) p) is distinct from (select array_agg(p order by p) from unnest(v_in_pieces) p) then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'conservation', 'item_id', v_diff.item_id, 'out', v_diff.q_out, 'in', v_diff.q_in),
      'a repack puts in exactly what it took out');
  end if;
  update public.stock_handling_units set revision = revision + 1,
         state = case when exists (select 1 from public.stock_handling_unit_lines x where x.unit_id = stock_handling_units.id) then state else 'unpacked' end
   where workspace_id = p_workspace_id and id = any (v_touched);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_hu_repack', v_digest,
    jsonb_build_object('request_id', p_request_id, 'repack_id', v_repack,
      'units', (select coalesce(jsonb_agg(public.stock_hu_json(p_workspace_id, i) order by i), '[]'::jsonb) from unnest(v_new_ids) i)));
end;
$fn$;
revoke execute on function public.stock_hu_repack_v1(uuid, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.stock_hu_repack_v1(uuid, uuid, jsonb, jsonb) to authenticated;

-- ── the reads ────────────────────────────────────────────────────────────
create or replace function public.stock_hu_page_v1(
  p_workspace_id uuid, p_location_id uuid default null, p_state text default 'open', p_limit int default 50, p_after jsonb default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_code text;
  v_id uuid;
  v_rows jsonb;
  v_n int;
  v_last jsonb;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  if not public.feature_effective(p_workspace_id, 'stockHandlingUnits') then
    return jsonb_build_object('rows', '[]'::jsonb, 'complete', true, 'next', null);
  end if;
  if p_state is null or p_state not in ('open', 'unpacked', 'retired') then
    raise exception 'invalid state' using errcode = 'DKG09';
  end if;
  if p_after is not null then
    begin
      if p_after ->> 'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_code := p_after ->> 'code';
      v_id := (p_after ->> 'id')::uuid;
      if v_code is null or v_id is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when invalid_text_representation then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  select coalesce(jsonb_agg(r.j order by r.code, r.id), '[]'::jsonb), count(*) into v_rows, v_n from (
    select u.code, u.id, public.stock_hu_json(p_workspace_id, u.id)
             || jsonb_build_object('location_code', lo.code, 'lines', (select count(*) from public.stock_handling_unit_lines x where x.unit_id = u.id)) as j
      from public.stock_handling_units u
      join public.stock_locations lo on lo.workspace_id = u.workspace_id and lo.id = u.location_id
     where u.workspace_id = p_workspace_id and u.state = p_state
       and (p_location_id is null or u.location_id = p_location_id)
       and (v_code is null or (u.code, u.id) > (v_code, v_id))
     order by u.code, u.id limit p_limit + 1) r;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next',
      jsonb_build_object('version', 1, 'code', v_last ->> 'code', 'id', v_last ->> 'id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_hu_page_v1(uuid, uuid, text, int, jsonb) from public, anon;
grant execute on function public.stock_hu_page_v1(uuid, uuid, text, int, jsonb) to authenticated;

create or replace function public.stock_hu_v1(p_workspace_id uuid, p_unit_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_unit jsonb;
begin
  perform public.stock_page_reader(p_workspace_id, 1);
  if not public.feature_effective(p_workspace_id, 'stockHandlingUnits') then
    return jsonb_build_object('unit', null, 'lines', '[]'::jsonb, 'children', '[]'::jsonb);
  end if;
  v_unit := public.stock_hu_json(p_workspace_id, p_unit_id);
  if v_unit is null then
    return jsonb_build_object('unit', null, 'lines', '[]'::jsonb, 'children', '[]'::jsonb);
  end if;
  return jsonb_build_object('unit', v_unit,
    'location_code', (select lo.code from public.stock_locations lo where lo.id = (v_unit ->> 'location_id')::uuid),
    'lines', (select coalesce(jsonb_agg(jsonb_build_object('item_id', l.item_id, 'item_name', s.name, 'variant_id', l.variant_id,
        'lot_id', l.lot_id, 'lot_code', lt.lot_code, 'expires_on', lt.expires_on, 'quantity', l.quantity, 'unit', s.inventory_unit,
        'pieces', (select coalesce(jsonb_agg(jsonb_build_object('piece_id', p.piece_id,
            'tag', (select g.code from public.stock_tags g where g.workspace_id = p_workspace_id and g.piece_id = p.piece_id and g.state = 'active'
                     order by g.created_datetime, g.id limit 1)) order by p.piece_id), '[]'::jsonb)
                     from public.stock_handling_unit_pieces p where p.unit_line_id = l.id)) order by s.name, l.id), '[]'::jsonb)
        from public.stock_handling_unit_lines l
        join public.services s on s.workspace_id = l.workspace_id and s.id = l.item_id
        left join public.stock_lots lt on lt.workspace_id = l.workspace_id and lt.id = l.lot_id
       where l.workspace_id = p_workspace_id and l.unit_id = p_unit_id),
    'children', (select coalesce(jsonb_agg(public.stock_hu_json(p_workspace_id, c.id) order by c.code), '[]'::jsonb)
                   from public.stock_handling_units c where c.workspace_id = p_workspace_id and c.parent_unit_id = p_unit_id and c.state = 'open'));
end;
$fn$;
revoke execute on function public.stock_hu_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_hu_v1(uuid, uuid) to authenticated;

-- where a lot is held in units, and every repack that touched it
create or replace function public.stock_hu_lot_trace_v1(p_workspace_id uuid, p_item_id uuid, p_lot_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.stock_page_reader(p_workspace_id, 1);
  if not public.feature_effective(p_workspace_id, 'stockHandlingUnits') then
    return jsonb_build_object('held', '[]'::jsonb, 'repacks', '[]'::jsonb);
  end if;
  return jsonb_build_object(
    'held', (select coalesce(jsonb_agg(jsonb_build_object('unit_id', u.id, 'code', u.code, 'location_id', u.location_id, 'quantity', l.quantity) order by u.code), '[]'::jsonb)
               from public.stock_handling_unit_lines l join public.stock_handling_units u on u.workspace_id = l.workspace_id and u.id = l.unit_id
              where l.workspace_id = p_workspace_id and l.item_id = p_item_id and l.lot_id is not distinct from p_lot_id and u.state = 'open'),
    'repacks', (select coalesce(jsonb_agg(jsonb_build_object('repack_id', r.id, 'made_at', r.made_at, 'direction', x.direction,
                   'unit_id', x.unit_id, 'code', u.code, 'quantity', x.quantity, 'piece_id', x.piece_id) order by r.made_at, x.direction desc, u.code), '[]'::jsonb)
                  from public.stock_repack_lines x
                  join public.stock_repacks r on r.workspace_id = x.workspace_id and r.id = x.repack_id
                  left join public.stock_handling_units u on u.workspace_id = x.workspace_id and u.id = x.unit_id
                 where x.workspace_id = p_workspace_id and x.item_id = p_item_id and x.lot_id is not distinct from p_lot_id));
end;
$fn$;
revoke execute on function public.stock_hu_lot_trace_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.stock_hu_lot_trace_v1(uuid, uuid, uuid) to authenticated;

-- ── exported with the business's records ─────────────────────────────────
-- restates 0922
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
    -- #4362 the tags bound to items, places and pieces, and the named pieces
    'stock_tags', 'stock_tagged_units', 'stock_movement_units',
    'stock_handling_units', 'stock_handling_unit_lines', 'stock_handling_unit_pieces', 'stock_movement_handling_units',
    'stock_repacks', 'stock_repack_lines',
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders', 'counter_refunds',
    -- #4367 the tills, their sessions, the cash entries and the day closes
    'counter_tills', 'counter_till_sessions', 'counter_cash_entries', 'counter_day_closes',
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
    'stock_reorder_points', 'item_groups', 'item_group_history',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
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
    -- the sessions, their entries and the day closes carry the expected cash and the differences: the finances' to export
    if v_table in ('counter_till_sessions', 'counter_cash_entries', 'counter_day_closes') and not public.has_permission(p_workspace_id, 'viewFinances') then
      continue;
    end if;
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

select public.set_deskilo_schema_version(930);
