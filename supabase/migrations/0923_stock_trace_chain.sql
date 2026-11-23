-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new read; a foreign key on 0922's link table)
--
-- #4432 (G18, second of three files) -- a lot or a piece is traced from the order to the sale through every movement,
-- forwards and backwards, in one read. `stock_goods_trace_v1` (0865) answers the purchase side of one movement; this
-- answers the whole chain of one subject:
--
--   * a lot: every movement of the lot, in order;
--   * a piece: every movement that carried it (0922; its history starts with 0922), and its lot;
--   * a movement: its lot's chain (or, for a movement without a lot, the movement and the pieces it carried);
--   * a sold line of a counter receipt (backwards): the movements of that line, and the lots and pieces they took.
--
--   Each step names its place from and to, its quantity, and the document that caused it: the delivery (order
--   reference, supplier, day received), the counter receipt (its number) or the invoice (its number). The origin of
--   a lot (the order line it was received from) is answered beside the steps. At most `p_limit` steps (1..500), and
--   `truncated` says when there were more.
--
--   Read by a member of the business who views or manages the stock; never by an assistant. A document is named
--   only to whom may read it (the order to a buyer or finance reader, a receipt or invoice to a finance reader),
--   otherwise its kind alone; pieces and tags only where the business uses tags. Another business's id
--   answers nothing (the same refusal as an unknown id).

create or replace function public.stock_trace_step(p_workspace_id uuid, m public.stock_movements)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'movement_id', m.id,
    'at', m.occurred_at,
    'reason', m.reason,
    'item_id', m.item_id,
    'variant_id', m.variant_id,
    'lot_id', m.lot_id,
    'quantity', m.quantity,
    'entered', case when m.entered_unit is not null then jsonb_build_object('unit', m.entered_unit, 'quantity', m.entered_quantity) end,
    'from', (select jsonb_build_object('id', z.id, 'code', z.code, 'kind', z.kind) from public.stock_locations z where z.id = m.from_location_id),
    'to', (select jsonb_build_object('id', z.id, 'code', z.code, 'kind', z.kind) from public.stock_locations z where z.id = m.to_location_id),
    'pieces', case when public.feature_effective(p_workspace_id, 'stockTags')
                   then (select count(*) from public.stock_movement_units l where l.movement_id = m.id) end,
    -- a document is named only to whom may read it (as stock_trace_purchase, 0865); otherwise its kind alone
    'document', coalesce(
      case when m.receipt_line_id is not null and not public.stock_trace_may(p_workspace_id, 'order')
           then jsonb_build_object('kind', 'delivery', 'state', 'unavailable') end,
      case when (m.counter_receipt_id is not null or m.invoice_id is not null) and not public.has_permission(p_workspace_id, 'viewFinances')
           then jsonb_build_object('kind', case when m.counter_receipt_id is not null then 'counter_receipt' else 'invoice' end, 'state', 'unavailable') end,
      (select jsonb_build_object('kind', 'delivery', 'id', r.id, 'order_id', o.id,
                                 'label', coalesce(nullif(o.reference, ''), o.year || '-' || lpad(o.number::text, 4, '0')),
                                 'supplier', s.name, 'received_on', r.received_on)
         from public.purchase_order_receipt_lines rl
         join public.purchase_order_receipts r on r.id = rl.receipt_id
         join public.purchase_orders o on o.id = r.order_id
         left join public.suppliers s on s.id = o.supplier_id
        where rl.id = m.receipt_line_id and rl.workspace_id = p_workspace_id),
      (select jsonb_build_object('kind', 'counter_receipt', 'id', c.id, 'label', c.number, 'line_id', m.counter_line_id)
         from public.counter_receipts c where c.id = m.counter_receipt_id and c.workspace_id = p_workspace_id),
      (select jsonb_build_object('kind', 'invoice', 'id', i.id, 'label', i.number)
         from public.invoices i where i.id = m.invoice_id and i.workspace_id = p_workspace_id),
      case when m.event_id is not null then jsonb_build_object('kind', 'event', 'id', m.event_id) end)
  ));
$$;
revoke execute on function public.stock_trace_step(uuid, public.stock_movements) from public, anon, authenticated;

create or replace function public.stock_trace_chain_v1(
  p_workspace_id uuid,
  p_lot_id uuid default null,
  p_piece_id uuid default null,
  p_movement_id uuid default null,
  p_counter_line_id uuid default null,
  p_limit int default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 200), 1), 500);
  v_lot uuid := p_lot_id;
  v_piece public.stock_tagged_units;
  v_move public.stock_movements;
  v_ids uuid[];
  v_steps jsonb;
  v_total int;
  v_subject text;
  v_tags boolean;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read the trace' using errcode = 'DKN01';
  end if;
  if not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read the trace' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'the stock is not used here' using errcode = 'DKG01';
  end if;
  if num_nonnulls(p_lot_id, p_piece_id, p_movement_id, p_counter_line_id) <> 1 then
    perform public.stock_config_refuse('subject', 'one_subject');
  end if;
  v_tags := public.feature_effective(p_workspace_id, 'stockTags');
  if p_piece_id is not null and not v_tags then
    raise exception 'the tags are not used here' using errcode = 'DKG01';
  end if;

  if p_piece_id is not null then
    select * into v_piece from public.stock_tagged_units where id = p_piece_id and workspace_id = p_workspace_id;
    if v_piece.id is null then perform public.stock_config_refuse('piece_id', 'unknown'); end if;
    v_subject := 'piece';
    v_lot := v_piece.lot_id;
    select array_agg(l.movement_id) into v_ids from public.stock_movement_units l where l.unit_id = v_piece.id;
  elsif p_movement_id is not null then
    select * into v_move from public.stock_movements where id = p_movement_id and workspace_id = p_workspace_id;
    if v_move.id is null then perform public.stock_config_refuse('movement_id', 'unknown'); end if;
    v_subject := 'movement';
    v_lot := v_move.lot_id;
    if v_lot is null then v_ids := array[v_move.id]; end if;
  elsif p_counter_line_id is not null then
    v_subject := 'sale_line';
    select array_agg(m.id) into v_ids from public.stock_movements m
     where m.workspace_id = p_workspace_id and m.counter_line_id = p_counter_line_id;
    if v_ids is null then perform public.stock_config_refuse('counter_line_id', 'unknown'); end if;
  else
    v_subject := 'lot';
    if not exists (select 1 from public.stock_lots where id = p_lot_id and workspace_id = p_workspace_id) then
      perform public.stock_config_refuse('lot_id', 'unknown');
    end if;
  end if;

  -- the steps: a piece's own movements; else the lot's; else the movements named
  with chosen as (
    select m.id, row_number() over (order by m.occurred_at, m.created_datetime, m.line_no, m.part) rn
      from public.stock_movements m
     where m.workspace_id = p_workspace_id
       and case when v_subject in ('piece', 'sale_line') or (v_subject = 'movement' and v_lot is null) then m.id = any (coalesce(v_ids, array[]::uuid[]))
                else m.lot_id = v_lot end
  )
  select count(*)::int,
         coalesce(jsonb_agg(public.stock_trace_step(p_workspace_id, m) order by c.rn) filter (where c.rn <= v_limit), '[]'::jsonb)
    into v_total, v_steps
    from chosen c join public.stock_movements m on m.id = c.id;

  return jsonb_strip_nulls(jsonb_build_object(
    'subject', v_subject,
    'lot', (select jsonb_build_object('id', l.id, 'item_id', l.item_id, 'variant_id', l.variant_id, 'code', l.lot_code,
                                      'label_code', l.label_code, 'expires_on', l.expires_on)
              from public.stock_lots l where l.id = v_lot and l.workspace_id = p_workspace_id),
    'piece', case when v_piece.id is not null and v_tags then jsonb_build_object(
               'id', v_piece.id, 'state', v_piece.state,
               'place', (select jsonb_build_object('id', z.id, 'code', z.code, 'kind', z.kind) from public.stock_locations z where z.id = v_piece.location_id),
               'tag', (select t.code from public.stock_tags t where t.piece_id = v_piece.id and t.state = 'active' order by t.code limit 1)) end,
    -- backwards from a sale: the lots and pieces the line took
    'took', case when v_subject = 'sale_line' then (
               select jsonb_build_object(
                 'lots', coalesce((select jsonb_agg(distinct m.lot_id) from public.stock_movements m where m.id = any (v_ids) and m.lot_id is not null), '[]'::jsonb),
                 'pieces', case when v_tags then coalesce((select jsonb_agg(l.unit_id order by l.unit_id) from public.stock_movement_units l where l.movement_id = any (v_ids)), '[]'::jsonb) end)) end,
    -- where the lot came in: its delivery when it was received against an order, else its first arrival
    'origin', (select public.stock_trace_step(p_workspace_id, m) from public.stock_movements m
                join public.stock_locations z on z.id = m.from_location_id
                where v_lot is not null and m.workspace_id = p_workspace_id and m.lot_id = v_lot
                  and (m.receipt_line_id is not null or z.kind in ('supplier', 'opening'))
                order by (m.receipt_line_id is null), m.occurred_at, m.created_datetime, m.line_no, m.part limit 1),
    'steps', v_steps,
    'truncated', v_total > v_limit
  ));
end;
$$;
revoke execute on function public.stock_trace_chain_v1(uuid, uuid, uuid, uuid, uuid, int) from public, anon;
grant execute on function public.stock_trace_chain_v1(uuid, uuid, uuid, uuid, uuid, int) to authenticated;

-- ── 0922's review: a link names a movement that exists ──────────────────
alter table public.stock_movement_units
  add constraint stock_movement_units_movement_fkey foreign key (movement_id) references public.stock_movements (id);
comment on function public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric) is
  'A wrapper kept for compatibility (0922). The pieces are moved by stock_pieces_move: a patch of the piece rule targets that function, never this one.';

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(923);
