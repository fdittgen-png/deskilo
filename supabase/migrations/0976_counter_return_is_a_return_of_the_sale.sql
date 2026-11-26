-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4492 (row 2) -- goods sold at the counter come back once, by whichever door, into the lot they left. There are two
-- doors: the stock door's return of the sale movement (`stock_return_v1`), bounded by what was reversed on that movement
-- before (`stock_reversals`); and the counter's own return, which follows a correction (`counter_goods_return_v1`). The
-- counter's return was bounded by its correction line only, wrote a `return_in` in no lot through the generic mode and
-- recorded no reversal. Neither door knew of the other: three mugs sold, two taken back at the counter, and the stock door
-- still took back three -- 12 on hand of 10 received; two teas of a lot at 3.00 sold and taken back left the lot at 8 and
-- two in no lot, the stock worth 24.00 instead of 30.00; an item tracked by lot could not come back at all (DKG06)
-- (measured by `585_counter_goods_come_back_once.sql`).
--
-- The counter's return is now a customer return of the sale's own movements, in the one record the bound reads, as the
-- void of an invoice is since 0975:
--   * a line of the correction credits a line of the sale; what comes back is taken from the movements that line made when
--     it was sold, in the order it made them, each into its own lot and variant, at that lot's frozen cost;
--   * the quantity is the line's, in the line's unit, and is weighed as the sale weighed it: the share of what the sold line
--     took out of stock (3 of 3 boxes sold as 18 pieces are 18 pieces, whatever a box is today);
--   * two bounds, both kept: no more than the correction credits (DKL08 `return_beyond`, as before, and still first), and
--     no more than is still out on those movements, whoever brought the rest back (DKL08 `already_back`, with what is left);
--   * it records one return (`stock_returns`, identity `md5('counter_return:' || request id)`) and one reversal per sale
--     movement (`stock_reversals`), so the stock door's bound and the read of what can still be reversed
--     (`stock_reversible_v1`) count it without being changed;
--   * it locks the items and then the sale movements in id order before it reads what is still out, as `stock_return_v1`
--     and the void do, so a return at the counter and one by the stock door cannot both read the same remainder.
-- Unchanged: who may do it, the request id that replays, the answer (`correction_id`, `movements`, `replayed`), the place
-- the goods go to (the one named, else MAIN), the link of each movement to the correction and its line, a returned deposit
-- (0973: refused here, it came back when it was rung up), and money: a return refunds nothing and credits nothing.
-- An app of the last release calls it with the same arguments and reads the same answer; where the goods were brought
-- back by the stock door before, it is now answered DKL08, the code it already words.
-- Returns made at the counter before this migration stay as they are: a `return_in` in no lot, in no reversal.
--
-- The body is the live one (the `effective-schema.sql` of Quality run 45834744067: 0897 with the one line 0973 patched in,
-- `or v_line.frozen ->> 'kind' = 'deposit_return'`, carried here).
-- restates 0897
create or replace function public.counter_goods_return_v1(p_workspace_id uuid, p_request_id uuid, p_correction_id uuid, p_lines jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_rec public.counter_receipts;
  e jsonb;
  w jsonb;
  s record;
  v_idx int := 0;
  v_line public.counter_receipt_lines;
  v_qty numeric;
  v_sold numeric;
  v_out numeric;
  v_need numeric;
  v_credit numeric;
  v_back numeric;
  v_left numeric;
  v_take numeric;
  v_to uuid;
  v_place public.stock_locations;
  v_asked jsonb := '[]'::jsonb;
  v_sales uuid[] := array[]::uuid[];
  v_seen uuid[] := array[]::uuid[];
  v_move jsonb := '[]'::jsonb;
  v_sources jsonb := '[]'::jsonb;
  v_no int := 0;
  v_return uuid;
  v_moved jsonb;
  v_result jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to take goods back into stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'goods are not sold here: the goods ledger is off' using errcode = 'DKL07', detail = 'goods_off';
  end if;
  if p_request_id is null or p_correction_id is null or coalesce(jsonb_typeof(p_lines), '') <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'a return is recorded with a request id, the correction and its lines' using errcode = '22023';
  end if;
  v_digest := md5(p_correction_id::text || '|' || p_lines::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_goods_return', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_rec from public.counter_receipts x where x.id = p_correction_id and x.workspace_id = p_workspace_id for update;
  if v_rec.id is null or v_rec.kind <> 'correction' or v_rec.state <> 'finalized' then
    raise exception 'a return follows a finalized correction' using errcode = 'DKL04';
  end if;
  perform public.counter_require_operation(p_workspace_id, 'correct_receipt');
  for e in select value from jsonb_array_elements(p_lines) loop
    v_idx := v_idx + 1;
    select * into v_line from public.counter_receipt_lines l
     where l.workspace_id = p_workspace_id and l.receipt_id = v_rec.id and l.id = nullif(e ->> 'corrects_line_id', '')::uuid;
    if v_line.id is null or v_line.id = any (v_seen) or (v_line.frozen ->> 'supply') <> 'goods' or v_line.item_id is null
       or v_line.frozen ->> 'kind' = 'deposit_return' then
      raise exception 'this is not a goods line of the correction' using errcode = 'DKL08', detail = jsonb_build_object('line', v_idx, 'reason', 'line_unknown')::text;
    end if;
    v_seen := v_seen || v_line.id;
    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      raise exception 'this quantity is not a quantity' using errcode = 'DKL08', detail = jsonb_build_object('line', v_idx, 'reason', 'quantity')::text;
    end if;
    v_qty := (e ->> 'quantity')::numeric;
    -- the line of the sale this line credits: its quantity, in its own unit, and what it took out of stock for it, in the
    -- item's; a quantity of the line is weighed by the two, as the sale weighed it
    select o.quantity into v_sold from public.counter_receipt_lines o
     where o.workspace_id = p_workspace_id and o.receipt_id = v_rec.corrects_receipt_id and o.id = v_line.corrects_line_id;
    select coalesce(sum(m.quantity), 0) into v_out from public.stock_movements m
     where m.workspace_id = p_workspace_id and m.counter_receipt_id = v_rec.corrects_receipt_id
       and m.counter_line_id = v_line.corrects_line_id and m.reason = 'sale';
    if coalesce(v_sold, 0) <= 0 then
      v_out := 0;
    end if;
    v_need := case when v_out > 0 then round(v_qty * v_out / v_sold, 6) else 0 end;
    v_credit := case when v_out > 0 then round(v_line.quantity * v_out / v_sold, 6) else 0 end;
    -- per line of the correction: the line's own id is in the movement's links
    select coalesce(sum(m.quantity), 0) into v_back from public.stock_movements m
     where m.workspace_id = p_workspace_id and m.counter_receipt_id = v_rec.id
       and m.counter_line_id = v_line.id and m.reason = 'return_in';
    if v_qty > v_line.quantity or v_need > v_credit - v_back then
      raise exception 'more is taken back than the correction credits' using errcode = 'DKL08',
        detail = jsonb_build_object('line', v_idx, 'reason', 'return_beyond', 'left', trim_scale(
          case when v_out > 0 then least(v_line.quantity, greatest(round((v_credit - v_back) * v_sold / v_out, 6), 0))
               else v_line.quantity end)::text)::text;
    end if;
    v_to := coalesce(nullif(e ->> 'to_location_id', '')::uuid,
                     (select l.id from public.stock_locations l where l.workspace_id = p_workspace_id and l.code = 'MAIN' limit 1));
    if v_to is null then
      raise exception 'no place to put the goods back' using errcode = 'DKL07', detail = 'to_place';
    end if;
    v_sales := v_sales || v_line.corrects_line_id;
    v_asked := v_asked || jsonb_build_array(jsonb_build_object('line', v_idx, 'line_id', v_line.id, 'sale_line_id', v_line.corrects_line_id,
      'to', v_to, 'need', v_need::text, 'sold', v_sold::text, 'out', v_out::text));
  end loop;
  -- the items, then the sale movements, each in id order: the order a return by the stock door takes them in. What is
  -- still out is read only now, the rows being locked
  perform 1 from public.services i
   where i.workspace_id = p_workspace_id
     and i.id in (select m.item_id from public.stock_movements m
                   where m.workspace_id = p_workspace_id and m.counter_receipt_id = v_rec.corrects_receipt_id
                     and m.counter_line_id = any (v_sales) and m.reason = 'sale')
   order by i.id for update;
  perform 1 from public.stock_movements m
   where m.workspace_id = p_workspace_id and m.counter_receipt_id = v_rec.corrects_receipt_id
     and m.counter_line_id = any (v_sales) and m.reason = 'sale'
   order by m.id for update;
  for w in select value from jsonb_array_elements(v_asked) loop
    v_idx := (w ->> 'line')::int;
    -- the place is a real one of this business: the answers the generic mode gave
    select * into v_place from public.stock_locations l
     where l.id = (w ->> 'to')::uuid and l.workspace_id = p_workspace_id and l.active;
    if v_place.id is null then
      raise exception 'line %: a move goes from one place of this business to another', v_idx using errcode = 'DKG05';
    end if;
    if public.stock_place_is_virtual(v_place.id) then
      perform public.stock_config_refuse(format('lines[%s]', v_idx - 1), 'reason_places');
    end if;
    v_need := (w ->> 'need')::numeric;
    v_sold := (w ->> 'sold')::numeric;
    v_out := (w ->> 'out')::numeric;
    v_left := v_need;
    -- the sale's movements in the order the sale made them, each for what is still out on it
    for s in
      select m.id, m.item_id, m.variant_id, m.lot_id, m.to_location_id,
             m.quantity - coalesce((select sum(r.quantity) from public.stock_reversals r
                                     where r.workspace_id = p_workspace_id and r.source_movement_id = m.id), 0) as still_out
        from public.stock_movements m
       where m.workspace_id = p_workspace_id and m.counter_receipt_id = v_rec.corrects_receipt_id
         and m.counter_line_id = (w ->> 'sale_line_id')::uuid and m.reason = 'sale'
       order by m.line_no, m.part, m.id
    loop
      continue when s.still_out <= 0 or v_left <= 0;
      v_take := least(s.still_out, v_left);
      v_left := v_left - v_take;
      v_no := v_no + 1;
      v_move := v_move || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'item_id', s.item_id, 'variant_id', s.variant_id, 'lot_id', s.lot_id, 'from', s.to_location_id, 'to', v_place.id,
        'quantity', trim_scale(v_take)::text, 'line_no', v_no, 'expired_ack', true, 'counter_line_id', w ->> 'line_id')));
      v_sources := v_sources || jsonb_build_array(jsonb_build_object('line_no', v_no, 'source', s.id,
        'quantity', trim_scale(v_take)::text, 'remaining', trim_scale(s.still_out - v_take)::text));
    end loop;
    if v_need <= 0 or v_left > 0 then
      raise exception 'these goods are not at the customer any more' using errcode = 'DKL08',
        detail = jsonb_build_object('line', v_idx, 'reason', 'already_back', 'left', trim_scale(
          case when v_out > 0 then round((v_need - v_left) * v_sold / v_out, 6) else 0 end)::text)::text;
    end if;
  end loop;
  perform set_config('deskilo.counter_links', 'on', true);
  v_moved := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_move, 'return_in', now(),
                                      jsonb_build_object('counter_receipt_id', v_rec.id), 'return');
  perform set_config('deskilo.counter_links', 'off', true);
  -- recorded as the return it is: one return, one reversal per sale movement, each naming the movement that brought it back
  v_return := md5('counter_return:' || p_request_id::text)::uuid;
  insert into public.stock_returns (workspace_id, return_id, kind, digest, request_id, actor_member_id, occurred_at, result)
  values (p_workspace_id, v_return, 'customer', v_digest, p_request_id, v_me, now(),
          jsonb_build_object('return_id', v_return, 'kind', 'customer', 'counter_receipt_id', v_rec.id, 'lines', (
            select jsonb_agg(jsonb_build_object(
                     'return_line_id', md5('counter_return_line:' || p_request_id::text || ':' || (x ->> 'source'))::uuid,
                     'movement_id', mv ->> 'id', 'source_movement_id', x ->> 'source', 'quantity', x ->> 'quantity',
                     'remaining', x ->> 'remaining')
                     order by (x ->> 'line_no')::int)
              from jsonb_array_elements(v_sources) x
              join jsonb_array_elements(v_moved) mv on (mv ->> 'line_no')::int = (x ->> 'line_no')::int)));
  insert into public.stock_reversals (workspace_id, return_id, return_line_id, kind, source_movement_id, movement_id, quantity)
  select p_workspace_id, v_return, md5('counter_return_line:' || p_request_id::text || ':' || (x ->> 'source'))::uuid, 'customer',
         (x ->> 'source')::uuid, (mv ->> 'id')::uuid, (x ->> 'quantity')::numeric
    from jsonb_array_elements(v_sources) x
    join jsonb_array_elements(v_moved) mv on (mv ->> 'line_no')::int = (x ->> 'line_no')::int;
  v_result := jsonb_build_object('correction_id', v_rec.id, 'movements', jsonb_array_length(v_moved), 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_goods_return', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_goods_return_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.counter_goods_return_v1(uuid, uuid, uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(976);
