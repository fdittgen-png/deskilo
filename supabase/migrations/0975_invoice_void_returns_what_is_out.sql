-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4492 (row 2) -- goods sold on an invoice come back once, by whichever door. There are two: the stock door's return of
-- the sale movement (`stock_return_v1`: a customer return, or a correction), bounded by what was reversed on that movement
-- before (`stock_reversals`); and the void of the invoice (`void_invoice` -> `invoice_goods_return`), which returned every
-- sale of the invoice in full and recorded no reversal. Neither knew of the other: one jar brought back and the invoice
-- then voided returned five for four sold, and a voided invoice's sale could be returned again in full by the stock door
-- (measured by `584_invoice_goods_come_back_once.sql`).
--
-- The void is now a customer return like any other, in the one record the bound reads:
--   * it returns, for each sale of the invoice, what has not been reversed on it yet (nothing for a sale already
--     returned or corrected in full), with the pieces of it that are still at the customer;
--   * it records one return (`stock_returns`, identity `md5('invoice_return:' || invoice)`, the id its movements always
--     had as their request) and one reversal per sale (`stock_reversals`), so the stock door's bound, and the read of
--     what can still be reversed (`stock_reversible_v1`), count the void without being changed;
--   * it locks the items and then the sales in id order first, as `stock_return_v1` does, so a return and a void of the
--     same sale cannot both read the same remainder.
-- Nothing changes for an invoice no return was made on: the same movements, to the same places, under the same request.
-- An app of the last release calls `void_invoice` as before and reads the same answer.
create or replace function public.invoice_goods_return(p_workspace_id uuid, p_actor uuid, p_invoice_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_lines jsonb;
  v_sources jsonb;
  v_moved jsonb;
  v_tags boolean := public.feature_effective(p_workspace_id, 'stockTags');
  v_return uuid := md5('invoice_return:' || p_invoice_id::text)::uuid;
begin
  -- the items, then the sales, each in id order: the order a return by the stock door takes them in
  perform 1 from public.services s
   where s.workspace_id = p_workspace_id
     and s.id in (select x.item_id from public.stock_movements x
                   where x.workspace_id = p_workspace_id and x.invoice_id = p_invoice_id
                     and x.reason = 'sale' and x.invoice_line_id is not null)
   order by s.id for update;
  perform 1 from public.stock_movements x
   where x.workspace_id = p_workspace_id and x.invoice_id = p_invoice_id
     and x.reason = 'sale' and x.invoice_line_id is not null
   order by x.id for update;
  -- what is still out on each sale: its quantity less what was reversed on it
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'item_id', m.item_id, 'variant_id', m.variant_id, 'lot_id', m.lot_id,
           'from', m.to_location_id, 'to', m.from_location_id,
           'quantity', trim_scale(m.still_out)::text, 'line_no', m.rn, 'expired_ack', true,
           'invoice_line_id', m.invoice_line_id,
           'units', case when v_tags then (select jsonb_agg(jsonb_build_object('piece_id', mu.unit_id) order by mu.unit_id)
                                              from public.stock_movement_units mu
                                              join public.stock_tagged_units tu on tu.workspace_id = p_workspace_id and tu.id = mu.unit_id
                                             where mu.movement_id = m.id and tu.location_id = m.to_location_id) end))
           order by m.rn), '[]'::jsonb),
         coalesce(jsonb_agg(jsonb_build_object('line_no', m.rn, 'source', m.id, 'quantity', trim_scale(m.still_out)::text)
           order by m.rn), '[]'::jsonb)
    into v_lines, v_sources
    from (select y.*, row_number() over (order by y.request_id, y.line_no, y.part) rn
            from (select x.*, x.quantity - coalesce((select sum(r.quantity) from public.stock_reversals r
                                                       where r.workspace_id = p_workspace_id and r.source_movement_id = x.id), 0) as still_out
                    from public.stock_movements x
                   where x.workspace_id = p_workspace_id and x.invoice_id = p_invoice_id
                     and x.reason = 'sale' and x.invoice_line_id is not null) y
           where y.still_out > 0) m;
  if jsonb_array_length(v_lines) = 0 then
    return 0;
  end if;
  perform set_config('deskilo.invoice_links', 'on', true);
  v_moved := public.stock_apply_lines(p_workspace_id, p_actor, v_return,
    v_lines, 'return_in', now(), jsonb_build_object('invoice_id', p_invoice_id), 'return');
  perform set_config('deskilo.invoice_links', 'off', true);
  -- the void is recorded as the return it is: one return, one reversal per sale, each naming the movement that brought it back
  insert into public.stock_returns (workspace_id, return_id, kind, digest, request_id, actor_member_id, occurred_at, result)
  values (p_workspace_id, v_return, 'customer', md5('invoice_void:' || p_invoice_id::text), v_return, p_actor, now(),
          jsonb_build_object('return_id', v_return, 'kind', 'customer', 'invoice_id', p_invoice_id, 'lines', (
            select jsonb_agg(jsonb_build_object(
                     'return_line_id', md5('invoice_return_line:' || (s ->> 'source'))::uuid, 'movement_id', mv ->> 'id',
                     'source_movement_id', s ->> 'source', 'quantity', s ->> 'quantity', 'remaining', '0')
                     order by (s ->> 'line_no')::int)
              from jsonb_array_elements(v_sources) s
              join jsonb_array_elements(v_moved) mv on (mv ->> 'line_no')::int = (s ->> 'line_no')::int)));
  insert into public.stock_reversals (workspace_id, return_id, return_line_id, kind, source_movement_id, movement_id, quantity)
  select p_workspace_id, v_return, md5('invoice_return_line:' || (s ->> 'source'))::uuid, 'customer',
         (s ->> 'source')::uuid, (mv ->> 'id')::uuid, (s ->> 'quantity')::numeric
    from jsonb_array_elements(v_sources) s
    join jsonb_array_elements(v_moved) mv on (mv ->> 'line_no')::int = (s ->> 'line_no')::int;
  return jsonb_array_length(v_lines);
end
$fn$;
revoke execute on function public.invoice_goods_return(uuid, uuid, uuid) from public, anon, authenticated;

select public.set_deskilo_schema_version(975);
