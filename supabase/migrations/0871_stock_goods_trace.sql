-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (three read functions and their helpers; no stored value moves)
--
-- #4173 (G6, checkpoint A: the server) -- trace goods to documents and payments, with an honest
-- operational value.
--
--   * stock_goods_trace_v1  FROM a movement (or the movements that put a lot away): its physical
--     facts, the lot and its cost state, then what is RECORDED about it -- the receipt line, the
--     order, the supplier bills linked to that order, each bill's obligation(s), and the settlement
--     allocations and payments of those obligations. A relation that is not recorded is not
--     inferred: nothing is matched on a name, a date or an amount.
--   * stock_document_goods_v1  FROM an order, a bill or a supplier payment to the exact goods
--     movements that were put away against it, a keyset page at a time.
--   * stock_valuation_v1  the operational value of what is on hand at a cutoff: the known-cost total
--     AND the quantities whose cost is unknown, the cutoff, when it was calculated and what it
--     counted. A mixed known/unknown selection is never presented as a complete total.
--
-- Rights. Every layer is read under ITS OWN domain's right, on the server: the goods (viewStock or
-- manageStock, stockManagement on), the order and the receipt (managePurchases or viewFinances,
-- purchaseOrders on), the bill and its obligation (the same, purchases on), the payment and its
-- allocation (viewFinances or recordOutgoingPayments, purchases on), the cost of goods
-- (managePurchases or viewFinances). A layer the caller may not read is answered
-- `{"state": "unavailable"}` whether or not it exists: an unavailable financial source is not
-- unpaid, and the answer never tells a reader whether a target exists. A delegated assistant session
-- reads nothing here (DKN01). Quantities travel as text, never as a JSON number. Cardinalities are
-- kept: one order lists its bills, one bill its obligations, one obligation its allocations and
-- reversals; none is flattened into one field on the movement.
--
-- Nothing here writes: opening a trace performs no receiving, issuing, settling or returning.

-- A reader of the goods; a delegated session reads nothing.
create or replace function public.stock_trace_reader(p_workspace_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  perform public.stock_reader(p_workspace_id);
end;
$fn$;
revoke execute on function public.stock_trace_reader(uuid) from public, anon, authenticated;

-- The right of each linked domain, with its feature on.
create or replace function public.stock_trace_may(p_workspace_id uuid, p_layer text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case p_layer
    when 'order' then (public.has_permission(p_workspace_id, 'managePurchases')
                       or public.has_permission(p_workspace_id, 'viewFinances'))
                      and public.feature_effective(p_workspace_id, 'purchaseOrders')
    when 'bill' then (public.has_permission(p_workspace_id, 'managePurchases')
                      or public.has_permission(p_workspace_id, 'viewFinances'))
                     and public.feature_effective(p_workspace_id, 'purchases')
    when 'payment' then (public.has_permission(p_workspace_id, 'viewFinances')
                         or public.has_permission(p_workspace_id, 'recordOutgoingPayments'))
                        and public.feature_effective(p_workspace_id, 'purchases')
    else false
  end;
$fn$;
revoke execute on function public.stock_trace_may(uuid, text) from public, anon, authenticated;

-- The settlement of one obligation: its allocations and reversals, each with its payment.
create or replace function public.stock_trace_settlement(p_workspace_id uuid, p_obligation_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
           'allocation_id', a.id, 'kind', a.kind, 'amount_cents', a.amount_cents,
           'original_allocation_id', a.original_allocation_id,
           'payment_id', a.payment_id, 'payment_state', p.state, 'method', p.method,
           'reported_paid_on', p.reported_paid_on, 'currency', p.currency)
           order by a.created_datetime, a.id), '[]'::jsonb)
    from public.purchase_settlement_allocations a
    join public.outgoing_payments p on p.workspace_id = a.workspace_id and p.id = a.payment_id
   where a.workspace_id = p_workspace_id and a.obligation_id = p_obligation_id;
$fn$;
revoke execute on function public.stock_trace_settlement(uuid, uuid) from public, anon, authenticated;

-- The supplier bills linked to an order, with their obligations (and, when the caller may read
-- payments, the settlement). Bounded: at most 50 bills; `truncated` says more exist.
create or replace function public.stock_trace_bills(p_workspace_id uuid, p_order_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_pay boolean := public.stock_trace_may(p_workspace_id, 'payment');
  v_items jsonb;
  v_n int;
begin
  if not public.stock_trace_may(p_workspace_id, 'bill') then
    return jsonb_build_object('state', 'unavailable', 'items', '[]'::jsonb);
  end if;
  select count(*) into v_n from public.purchase_documents d
   where d.workspace_id = p_workspace_id and d.purchase_order_id = p_order_id;
  if v_n = 0 then
    return jsonb_build_object('state', 'not_linked', 'items', '[]'::jsonb);
  end if;
  select coalesce(jsonb_agg(b.j order by b.ord, b.id), '[]'::jsonb) into v_items from (
    select d.id, d.created_datetime as ord, jsonb_build_object(
             'bill_id', d.id, 'kind', d.kind, 'state', d.state,
             'original_reference', d.original_reference, 'original_date', d.original_date,
             'due_on', d.due_on, 'currency', d.currency,
             'obligations', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'obligation_id', o.id, 'state', o.state, 'amount_cents', o.amount_cents,
                        'currency', o.currency, 'due_on', o.due_on,
                        'settlement', case when v_pay
                          then jsonb_build_object('state', 'listed',
                                 'items', public.stock_trace_settlement(p_workspace_id, o.id))
                          else jsonb_build_object('state', 'unavailable', 'items', '[]'::jsonb) end)
                        order by o.created_datetime, o.id)
                 from public.purchase_obligations o
                where o.workspace_id = p_workspace_id and o.purchase_id = d.id), '[]'::jsonb)) as j
      from public.purchase_documents d
     where d.workspace_id = p_workspace_id and d.purchase_order_id = p_order_id
     order by d.created_datetime, d.id
     limit 50) b;
  return jsonb_build_object('state', 'listed', 'items', v_items, 'truncated', v_n > 50);
end;
$fn$;
revoke execute on function public.stock_trace_bills(uuid, uuid) from public, anon, authenticated;

-- What is recorded about the purchase side of one movement.
create or replace function public.stock_trace_purchase(
  p_workspace_id uuid, p_movement_id uuid, p_receipt_line_id uuid
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  a public.stock_receipt_allocations;
  v_line uuid;
  v_receipt public.purchase_order_receipts;
  v_order public.purchase_orders;
begin
  if not public.stock_trace_may(p_workspace_id, 'order') then
    return jsonb_build_object('state', 'unavailable');
  end if;
  select * into a from public.stock_receipt_allocations
   where workspace_id = p_workspace_id and movement_id = p_movement_id;
  v_line := coalesce(a.receipt_line_id, p_receipt_line_id);
  if v_line is null then
    return jsonb_build_object('state', 'not_linked');
  end if;
  select r.* into v_receipt from public.purchase_order_receipt_lines l
    join public.purchase_order_receipts r on r.id = l.receipt_id and r.workspace_id = l.workspace_id
   where l.id = v_line and l.workspace_id = p_workspace_id;
  if v_receipt.id is null then
    return jsonb_build_object('state', 'not_linked');
  end if;
  select * into v_order from public.purchase_orders
   where id = v_receipt.order_id and workspace_id = p_workspace_id;
  return jsonb_build_object(
    'state', 'linked',
    'receipt', jsonb_build_object('receipt_id', v_receipt.id, 'received_on', v_receipt.received_on,
                                  'receipt_line_id', v_line),
    -- what the order said when the goods were put away is kept with the allocation
    'order', jsonb_build_object(
      'order_id', v_order.id, 'reference', coalesce(nullif(a.order_reference, ''), v_order.reference),
      'state', v_order.state, 'currency', v_order.currency,
      'supplier_name', coalesce(nullif(a.supplier_name, ''),
        (select s.name from public.suppliers s where s.id = v_order.supplier_id and s.workspace_id = p_workspace_id), '')),
    'bills', public.stock_trace_bills(p_workspace_id, v_order.id));
end;
$fn$;
revoke execute on function public.stock_trace_purchase(uuid, uuid, uuid) from public, anon, authenticated;

-- One movement, with its lot and what is recorded about its purchase.
create or replace function public.stock_trace_one(p_workspace_id uuid, p_movement_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  m public.stock_movements;
  l public.stock_lots;
  v_cost boolean := public.stock_sees_cost(p_workspace_id);
begin
  select * into m from public.stock_movements where id = p_movement_id and workspace_id = p_workspace_id;
  if m.id is null then
    raise exception 'unknown movement' using errcode = 'DKG07';
  end if;
  select * into l from public.stock_lots where id = m.lot_id and workspace_id = p_workspace_id;
  return jsonb_build_object(
    'movement', jsonb_build_object(
      'movement_id', m.id, 'item_id', m.item_id, 'variant_id', m.variant_id, 'lot_id', m.lot_id,
      'from_location_id', m.from_location_id, 'to_location_id', m.to_location_id,
      'quantity', m.quantity::text, 'entered_unit', m.entered_unit,
      'entered_quantity', m.entered_quantity::text, 'occurred_at', m.occurred_at,
      'reason', m.reason, 'request_id', m.request_id),
    'lot', case when l.id is null then null else jsonb_build_object(
      'lot_id', l.id, 'lot_code', l.lot_code, 'expires_on', l.expires_on,
      'quantity_received', l.quantity_received::text,
      -- the cost of goods is finance data: not shown is `unavailable`, never zero
      'cost', case
        when not v_cost then jsonb_build_object('state', 'unavailable')
        when l.cost_state = 'unknown' then jsonb_build_object('state', 'unknown')
        else jsonb_build_object('state', 'known', 'total_cost_minor', l.total_cost_minor,
               'source_currency', l.source_currency, 'source_rate', l.source_rate::text) end) end,
    'purchase', public.stock_trace_purchase(p_workspace_id, m.id, m.receipt_line_id));
end;
$fn$;
revoke execute on function public.stock_trace_one(uuid, uuid) from public, anon, authenticated;

-- FROM a movement, or from a lot (the movements that put it away): the traces, at most 20.
create or replace function public.stock_goods_trace_v1(
  p_workspace_id uuid, p_movement_id uuid default null, p_lot_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ids uuid[];
begin
  perform public.stock_trace_reader(p_workspace_id);
  if (p_movement_id is null) = (p_lot_id is null) then
    raise exception 'name a movement or a lot' using errcode = 'DKG09';
  end if;
  if p_movement_id is not null then
    v_ids := array[p_movement_id];
  else
    if not exists (select 1 from public.stock_lots where id = p_lot_id and workspace_id = p_workspace_id) then
      raise exception 'unknown lot' using errcode = 'DKG07';
    end if;
    -- a lot not put away through a receipt names the movements that carry it
    select array_agg(id) into v_ids from (
      select x.id from public.stock_movements x
       where x.workspace_id = p_workspace_id and x.lot_id = p_lot_id
         and (x.receipt_line_id is not null
              or exists (select 1 from public.stock_receipt_allocations a where a.movement_id = x.id)
              or x.reason in ('receipt', 'opening'))
       order by x.occurred_at, x.id limit 20) q;
  end if;
  return jsonb_build_object(
    'traces', coalesce((select jsonb_agg(public.stock_trace_one(p_workspace_id, id) order by ord)
                          from unnest(v_ids) with ordinality t(id, ord)), '[]'::jsonb),
    'coverage', 'recorded relations only: nothing is matched on a name, a date or an amount');
end;
$fn$;
revoke execute on function public.stock_goods_trace_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.stock_goods_trace_v1(uuid, uuid, uuid) to authenticated;

-- FROM a document to the goods put away against it, a keyset page at a time.
create or replace function public.stock_document_goods_v1(
  p_workspace_id uuid, p_kind text, p_id uuid, p_limit int default 50, p_after jsonb default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_order_ids uuid[];
  v_layer text;
  v_known boolean;
  v_at timestamptz; v_after_id uuid;
  v_rows jsonb; v_n int;
begin
  perform public.stock_trace_reader(p_workspace_id);
  if p_limit is null or p_limit < 1 or p_limit > 200 then
    raise exception 'invalid page size' using errcode = 'DKG09';
  end if;
  v_layer := case p_kind when 'order' then 'order' when 'bill' then 'bill' when 'payment' then 'payment' end;
  if v_layer is null then
    raise exception 'unknown document kind' using errcode = 'DKG09';
  end if;
  -- the document's own right first: without it the answer is the same whether or not it exists
  if not public.stock_trace_may(p_workspace_id, v_layer) then
    return jsonb_build_object('state', 'unavailable', 'goods', '[]'::jsonb, 'more', false);
  end if;
  if p_after is not null then
    begin
      v_at := (p_after ->> 'at')::timestamptz; v_after_id := (p_after ->> 'id')::uuid;
    exception when others then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  if p_kind = 'order' then
    select array_agg(id) into v_order_ids from public.purchase_orders
     where id = p_id and workspace_id = p_workspace_id;
    v_known := v_order_ids is not null;
  elsif p_kind = 'bill' then
    select coalesce(array_agg(d.purchase_order_id) filter (where d.purchase_order_id is not null), '{}')
      into v_order_ids
      from public.purchase_documents d where d.id = p_id and d.workspace_id = p_workspace_id;
    v_known := exists (select 1 from public.purchase_documents d where d.id = p_id and d.workspace_id = p_workspace_id);
  else
    v_known := exists (select 1 from public.outgoing_payments p where p.id = p_id and p.workspace_id = p_workspace_id);
    select coalesce(array_agg(distinct d.purchase_order_id) filter (where d.purchase_order_id is not null), '{}')
      into v_order_ids
      from public.purchase_settlement_allocations a
      join public.purchase_obligations o on o.id = a.obligation_id and o.workspace_id = a.workspace_id
      join public.purchase_documents d on d.id = o.purchase_id and d.workspace_id = o.workspace_id
     where a.workspace_id = p_workspace_id and a.payment_id = p_id;
  end if;
  if not v_known then
    raise exception 'unknown document' using errcode = 'DKG07';
  end if;
  if coalesce(array_length(v_order_ids, 1), 0) = 0 then
    -- a bill or payment that no recorded order link reaches: not linked, which is not "no goods"
    return jsonb_build_object('state', 'not_linked', 'goods', '[]'::jsonb, 'more', false);
  end if;
  select coalesce(jsonb_agg(q.j order by q.occurred_at, q.mid), '[]'::jsonb), count(*)
    into v_rows, v_n
    from (
      select m.occurred_at, m.id as mid, jsonb_build_object(
               'movement_id', m.id, 'item_id', m.item_id, 'variant_id', m.variant_id, 'lot_id', m.lot_id,
               'to_location_id', m.to_location_id, 'quantity', m.quantity::text,
               'entered_unit', m.entered_unit, 'entered_quantity', m.entered_quantity::text,
               'occurred_at', m.occurred_at, 'reason', m.reason,
               'receipt_id', a.receipt_id, 'order_id', r.order_id) as j
        from public.stock_receipt_allocations a
        join public.purchase_order_receipts r on r.id = a.receipt_id and r.workspace_id = a.workspace_id
        join public.stock_movements m on m.id = a.movement_id and m.workspace_id = a.workspace_id
       where a.workspace_id = p_workspace_id and r.order_id = any (v_order_ids)
         and (v_at is null or (m.occurred_at, m.id) > (v_at, v_after_id))
       order by m.occurred_at, m.id
       limit p_limit + 1) q;
  -- one more than asked tells whether anything follows
  return jsonb_build_object(
    'state', 'listed',
    'goods', (select coalesce(jsonb_agg(e), '[]'::jsonb) from (
                select e from jsonb_array_elements(v_rows) with ordinality t(e, o) where o <= p_limit order by o) z),
    'more', v_n > p_limit,
    'next', case when v_n > p_limit then jsonb_build_object(
              'at', (v_rows -> (p_limit - 1)) ->> 'occurred_at', 'id', (v_rows -> (p_limit - 1)) ->> 'movement_id') end);
end;
$fn$;
revoke execute on function public.stock_document_goods_v1(uuid, text, uuid, int, jsonb) from public, anon;
grant execute on function public.stock_document_goods_v1(uuid, text, uuid, int, jsonb) to authenticated;

-- The operational value on hand at a cutoff: a qualified calculation from the recorded movements
-- and lot costs, NOT a posted stock-book balance. Known-cost value is totalled; goods whose cost
-- is unknown (a lot with no cost, or no lot at all) are listed by quantity and stay outside the
-- total, and `complete` says whether any such goods exist. Amounts are minor units of the
-- business's currency; a lot received in another currency was converted at the rate recorded with
-- it, which is shown, never at today's.
create or replace function public.stock_valuation_v1(p_workspace_id uuid, p_at timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_at timestamptz := coalesce(p_at, now());
  v_currency text;
  v_lines jsonb; v_uncosted jsonb;
  v_known numeric; v_counted int; v_recorded timestamptz;
begin
  perform public.stock_trace_reader(p_workspace_id);
  if not public.stock_sees_cost(p_workspace_id) then
    raise exception 'not allowed to see what goods cost' using errcode = 'DKN01';
  end if;
  select w.currency_code into v_currency from public.workspaces w where w.id = p_workspace_id;
  select count(*), max(m.created_datetime) into v_counted, v_recorded
    from public.stock_movements m where m.workspace_id = p_workspace_id and m.occurred_at <= v_at;
  with q as (
    select m.item_id, m.variant_id, m.lot_id,
           sum(case when not kt.virtual then m.quantity else 0 end)
         - sum(case when not kf.virtual then m.quantity else 0 end) as quantity
      from public.stock_movements m
      join public.stock_locations lf on lf.id = m.from_location_id
      join public.stock_location_kinds kf on kf.key = lf.kind
      join public.stock_locations lt on lt.id = m.to_location_id
      join public.stock_location_kinds kt on kt.key = lt.kind
     where m.workspace_id = p_workspace_id and m.occurred_at <= v_at
     group by m.item_id, m.variant_id, m.lot_id
  ), j as (
    select q.*, l.cost_state, l.total_cost_minor, l.quantity_received, l.source_currency, l.source_rate
      from q left join public.stock_lots l on l.id = q.lot_id and l.workspace_id = p_workspace_id
     where q.quantity <> 0
  )
  select
    coalesce((select sum(round(x.quantity * x.total_cost_minor / x.quantity_received))
                from j x where x.cost_state = 'known'), 0),
    coalesce((select jsonb_agg(jsonb_build_object(
                'item_id', x.item_id, 'variant_id', x.variant_id, 'lot_id', x.lot_id,
                'quantity', x.quantity::text, 'cost_state', 'known',
                'unit_cost_minor', (x.total_cost_minor::numeric / x.quantity_received)::text,
                'value_minor', round(x.quantity * x.total_cost_minor / x.quantity_received),
                'source_currency', x.source_currency, 'source_rate', x.source_rate::text)
                order by x.item_id, x.variant_id nulls first, x.lot_id)
                from j x where x.cost_state = 'known'), '[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object(
                'item_id', u.item_id, 'variant_id', u.variant_id, 'quantity', u.quantity::text,
                'reason', u.reason) order by u.item_id, u.variant_id nulls first, u.reason)
                from (select x.item_id, x.variant_id, sum(x.quantity) as quantity,
                             case when x.lot_id is null then 'no_lot' else 'cost_unknown' end as reason
                        from j x
                       where x.lot_id is null or x.cost_state = 'unknown'
                       group by x.item_id, x.variant_id,
                                case when x.lot_id is null then 'no_lot' else 'cost_unknown' end) u), '[]'::jsonb)
    into v_known, v_lines, v_uncosted;
  return jsonb_build_object(
    'basis', 'operational: recorded movements at recorded lot costs; not a posted stock-book balance',
    'cutoff', v_at,
    'calculated_at', clock_timestamp(),
    'currency', v_currency,
    'movements_counted', v_counted,
    'last_recorded_at', v_recorded,
    'known_total_minor', v_known,
    'lines', v_lines,
    'uncosted', v_uncosted,
    'complete', jsonb_array_length(v_uncosted) = 0,
    'coverage', 'movements dated up to the cutoff, as recorded when this was calculated; a later-recorded earlier-dated movement changes a later calculation');
end;
$fn$;
revoke execute on function public.stock_valuation_v1(uuid, timestamptz) from public, anon;
grant execute on function public.stock_valuation_v1(uuid, timestamptz) to authenticated;

select public.set_deskilo_schema_version(871);
