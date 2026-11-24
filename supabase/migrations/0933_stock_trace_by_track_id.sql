-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new read; stock_trace_chain_v1 restated whole, its answer gains a key)
--
-- #4436 (G21, second of two files) -- the trace finds the sale from the track ID, and the track ID from the sale.
--
--   * `stock_trace_find_v1` takes a track ID as a person types or scans it -- a lot code as received, a lot's label
--     code, or a piece's tag -- and answers the lots and pieces it names, and the sales that took them: each counter
--     receipt line with its number, its day and the quantity it took. A receipt is named only to whom may read it (a
--     finance reader), otherwise its kind alone, as the chain does (0923). Pieces and tags only where the business uses
--     tags. At most 50 of each, and `truncated` says when there were more.
--   * `stock_trace_chain_v1` (0923), read backwards from a sold line, also answers the track IDs that line took
--     (`took.tracks`: the lot codes with their quantities, the pieces with their tags), the same facts the receipt froze.
--
--   Read by a member of the business who views or manages the stock; never by an assistant. Another business's code
--   answers nothing.

create or replace function public.stock_trace_find_v1(p_workspace_id uuid, p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_code text := btrim(coalesce(p_code, ''));
  v_tag text;
  v_tags boolean;
  v_finance boolean;
  v_lots uuid[];
  v_pieces uuid[];
  v_moves uuid[];
  v_sales jsonb;
  v_total int;
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
  if char_length(v_code) not between 1 and 64 then
    perform public.stock_config_refuse('code', 'malformed');
  end if;
  v_tags := public.feature_effective(p_workspace_id, 'stockTags');
  v_finance := public.has_permission(p_workspace_id, 'viewFinances');
  v_tag := public.stock_tag_normalize(v_code);

  select array_agg(l.id) into v_lots from public.stock_lots l
   where l.workspace_id = p_workspace_id and (lower(l.lot_code) = lower(v_code) or l.label_code = v_code);
  if v_tags and v_tag is not null then
    select array_agg(distinct t.piece_id) into v_pieces from public.stock_tags t
     where t.workspace_id = p_workspace_id and t.owner_kind = 'piece' and t.code = v_tag and t.piece_id is not null;
  end if;
  v_lots := coalesce(v_lots, array[]::uuid[]);
  v_pieces := coalesce(v_pieces, array[]::uuid[]);

  -- the sales: the movements to a customer of a counter receipt line that carried the lot or the piece
  select array_agg(m.id) into v_moves from public.stock_movements m
   where m.workspace_id = p_workspace_id and m.reason = 'sale' and m.counter_line_id is not null
     and (m.lot_id = any (v_lots)
          or m.id in (select mu.movement_id from public.stock_movement_units mu where mu.workspace_id = p_workspace_id and mu.unit_id = any (v_pieces)));
  v_moves := coalesce(v_moves, array[]::uuid[]);
  with sold as (
    select m.counter_line_id line_id, m.counter_receipt_id receipt_id, min(m.occurred_at) at, sum(m.quantity) qty,
           row_number() over (order by min(m.occurred_at) desc, m.counter_line_id) rn
      from public.stock_movements m where m.id = any (v_moves)
     group by m.counter_line_id, m.counter_receipt_id
  )
  select count(*)::int,
         coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'at', s.at, 'quantity', trim_scale(s.qty)::text,
           'document', case when v_finance then
               (select jsonb_build_object('kind', 'counter_receipt', 'id', c.id, 'label', c.number, 'line_id', s.line_id)
                  from public.counter_receipts c where c.id = s.receipt_id and c.workspace_id = p_workspace_id)
             else jsonb_build_object('kind', 'counter_receipt', 'state', 'unavailable') end)) order by s.rn) filter (where s.rn <= 50), '[]'::jsonb)
    into v_total, v_sales
    from sold s;

  return jsonb_build_object(
    'code', v_code,
    'lots', coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                         'id', l.id, 'item_id', l.item_id, 'item', s.name, 'variant_id', l.variant_id,
                         'code', nullif(l.lot_code, ''), 'label_code', l.label_code, 'expires_on', l.expires_on))
                       order by l.created_datetime, l.id)
                        from (select * from public.stock_lots x where x.id = any (v_lots) order by x.created_datetime, x.id limit 50) l
                        join public.services s on s.id = l.item_id), '[]'::jsonb),
    'pieces', case when v_tags then coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                         'id', u.id, 'item_id', u.item_id, 'item', s.name, 'lot_id', u.lot_id, 'state', u.state, 'tag', v_tag))
                       order by u.id)
                        from (select * from public.stock_tagged_units x where x.id = any (v_pieces) order by x.id limit 50) u
                        join public.services s on s.id = u.item_id), '[]'::jsonb) end,
    'sales', v_sales,
    'truncated', v_total > 50 or cardinality(v_lots) > 50 or cardinality(v_pieces) > 50);
end;
$$;
revoke execute on function public.stock_trace_find_v1(uuid, text) from public, anon;
grant execute on function public.stock_trace_find_v1(uuid, text) to authenticated;

-- restates 0923
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
                 'pieces', case when v_tags then coalesce((select jsonb_agg(l.unit_id order by l.unit_id) from public.stock_movement_units l where l.movement_id = any (v_ids)), '[]'::jsonb) end,
                 -- #4436: the track IDs the line took, the lot codes with their quantities and the pieces' tags
                 'tracks', public.stock_tracks_of(p_workspace_id, v_ids))) end,
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

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(933);
