-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- #4434 (G19): "where is it". One read answers, for an item or one of its lots, every place that holds it with the
-- quantity, variant and lot, now or as of a past date replayed from the movements; goods in transit say from which place
-- to which; what left to a customer, to a loss or came back is shown at its virtual place with the document that moved it;
-- the pieces of the item (with their tags) are listed with their place and state. The answer balances: the places add up to
-- what the item holds, now or at that date. Read-only; the flag `stockWhereIs` gates it.

create or replace function public.stock_where_is_v1(
  p_workspace_id uuid, p_item_id uuid, p_lot_id uuid default null, p_at timestamptz default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_item record;
  v_places jsonb; v_docs jsonb; v_transit jsonb; v_pieces jsonb; v_more boolean := false;
  v_real numeric;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  perform public.stock_reader(p_workspace_id);
  if p_at is not null and p_at > now() + interval '5 minutes' then
    raise exception 'a date to look at is not in the future' using errcode = 'DKG07';
  end if;
  select s.id, s.name, s.inventory_unit as unit into v_item
    from public.services s where s.id = p_item_id and s.workspace_id = p_workspace_id;
  if v_item.id is null then
    raise exception 'unknown item' using errcode = 'DKG04';
  end if;
  if p_lot_id is not null and not exists (
       select 1 from public.stock_lots t where t.id = p_lot_id and t.item_id = p_item_id and t.workspace_id = p_workspace_id) then
    raise exception 'unknown lot' using errcode = 'DKG04';
  end if;

  -- what each place holds: the balances now, the movements replayed at a past date
  select coalesce(jsonb_agg(jsonb_build_object(
           'location_id', h.location_id, 'location_code', l.code, 'location_name', l.name,
           'location_kind', l.kind, 'virtual', k.virtual,
           'variant_id', h.variant_id, 'variant_label', public.stock_variant_label(h.variant_id),
           'lot_id', h.lot_id, 'lot_code', t.lot_code, 'expires_on', t.expires_on,
           'quantity', h.quantity::text)
         order by k.virtual, l.code, coalesce(h.variant_id::text, ''), coalesce(h.lot_id::text, '')), '[]'::jsonb),
         coalesce(sum(h.quantity) filter (where not k.virtual), 0)
    into v_places, v_real
    from (
      select b.location_id, b.variant_id, b.lot_id, b.quantity
        from public.stock_balances b
       where p_at is null and b.workspace_id = p_workspace_id and b.item_id = p_item_id
         and (p_lot_id is null or b.lot_id = p_lot_id) and b.quantity <> 0
      union all
      select d.location_id, d.variant_id, d.lot_id, sum(d.q)
        from (
          select m.to_location_id as location_id, m.variant_id, m.lot_id, m.quantity as q
            from public.stock_movements m
           where p_at is not null and m.workspace_id = p_workspace_id and m.item_id = p_item_id
             and m.occurred_at <= p_at and (p_lot_id is null or m.lot_id = p_lot_id)
          union all
          select m.from_location_id, m.variant_id, m.lot_id, -m.quantity
            from public.stock_movements m
           where p_at is not null and m.workspace_id = p_workspace_id and m.item_id = p_item_id
             and m.occurred_at <= p_at and (p_lot_id is null or m.lot_id = p_lot_id)
        ) d
       group by d.location_id, d.variant_id, d.lot_id
      having sum(d.q) <> 0
    ) h
    join public.stock_locations l on l.id = h.location_id
    join public.stock_location_kinds k on k.key = l.kind
    left join public.stock_lots t on t.id = h.lot_id;

  -- goods loaded for another site and not yet received: from where, to where (now only: a transfer's lines do not keep
  -- their past states)
  if p_at is null then
    select coalesce(jsonb_agg(jsonb_build_object(
             'transfer_id', x.transfer_id, 'from_location_id', tr.from_location_id, 'from_location_code', lf.code,
             'to_location_id', tr.to_location_id, 'to_location_code', lt.code,
             'variant_id', x.variant_id, 'lot_id', x.lot_id, 'quantity', (x.loaded - x.received)::text)
           order by tr.created_datetime, x.id), '[]'::jsonb)
      into v_transit
      from public.stock_transfer_lines x
      join public.stock_transfers tr on tr.id = x.transfer_id
      join public.stock_locations lf on lf.id = tr.from_location_id
      join public.stock_locations lt on lt.id = tr.to_location_id
     where x.workspace_id = p_workspace_id and x.item_id = p_item_id
       and (p_lot_id is null or x.lot_id = p_lot_id)
       and tr.status <> 'received' and x.loaded > x.received;
  end if;

  -- what left to a customer or a loss, or came back, with the document: the last movements at the virtual places
  select coalesce(jsonb_agg(d.j order by d.occurred_at desc, d.id), '[]'::jsonb) into v_docs
    from (
      select m.id, m.occurred_at, jsonb_build_object(
               'movement_id', m.id, 'reason', m.reason, 'occurred_at', m.occurred_at,
               'from_location_code', lf.code, 'to_location_code', lt.code, 'quantity', m.quantity::text,
               'invoice_id', m.invoice_id, 'event_id', m.event_id,
               'receipt_line_id', m.receipt_line_id, 'purchase_line_id', m.purchase_line_id) as j
        from public.stock_movements m
        join public.stock_locations lf on lf.id = m.from_location_id
        join public.stock_locations lt on lt.id = m.to_location_id
       where m.workspace_id = p_workspace_id and m.item_id = p_item_id
         and (p_lot_id is null or m.lot_id = p_lot_id)
         and (p_at is null or m.occurred_at <= p_at)
         and (lt.kind in ('customer', 'loss') or lf.kind in ('customer', 'loss'))
       order by m.occurred_at desc, m.id
       limit 20) d;

  -- the pieces: their place and state now (a past date needs the movement-piece link)
  if p_at is null then
    select coalesce(jsonb_agg(jsonb_build_object(
             'piece_id', u.id, 'state', u.state, 'location_id', u.location_id, 'location_code', l.code,
             'variant_id', u.variant_id, 'lot_id', u.lot_id,
             'tags', coalesce((select jsonb_agg(g.code order by g.code) from public.stock_tags g
                                where g.piece_id = u.id and g.state = 'active'), '[]'::jsonb))
           order by l.code, u.id), '[]'::jsonb), count(*) > 200
      into v_pieces, v_more
      from (select * from public.stock_tagged_units q
             where q.workspace_id = p_workspace_id and q.item_id = p_item_id
               and (p_lot_id is null or q.lot_id = p_lot_id) and q.state <> 'retired'
             order by q.location_id, q.id limit 201) u
      join public.stock_locations l on l.id = u.location_id;
    if v_more then v_pieces := v_pieces - 200; end if;
  end if;

  return jsonb_build_object(
    'item', jsonb_build_object('id', v_item.id, 'name', v_item.name, 'unit', v_item.unit),
    'lot_id', p_lot_id, 'as_of', p_at,
    'on_hand', v_real::text, 'places', v_places,
    'transit', v_transit, 'documents', v_docs,
    'pieces', v_pieces, 'pieces_more', v_more);
end;
$fn$;
revoke execute on function public.stock_where_is_v1(uuid, uuid, uuid, timestamptz) from public, anon;
grant execute on function public.stock_where_is_v1(uuid, uuid, uuid, timestamptz) to authenticated;

select public.set_deskilo_schema_version(926);
