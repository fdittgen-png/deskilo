-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one function)
--
-- #4185 (S4) -- the physical return of goods is its own act. A correction (0894) is a credit document and a refund
-- (0895) is money given back; neither moves goods. `counter_goods_return_v1` takes returned goods back into stock through
-- the one stock path, as `return_in`, linked to the CORRECTION receipt, by someone who may manage the stock (and work the
-- counter), never beyond what that correction's goods line credits (counting what was already taken back), under a
-- request id that replays. A return does not refund and does not credit.

-- audience: all row readers
create or replace function public.counter_goods_return_v1(p_workspace_id uuid, p_request_id uuid, p_correction_id uuid, p_lines jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_rec public.counter_receipts;
  e jsonb;
  v_idx int := 0;
  v_line public.counter_receipt_lines;
  v_qty numeric;
  v_back numeric;
  v_to uuid;
  v_move jsonb := '[]'::jsonb;
  v_seen uuid[] := array[]::uuid[];
  v_moved jsonb;
  v_result jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to take goods back into stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'goods are not sold here: the goods ledger is off' using errcode = 'DKT07', detail = 'goods_off';
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
    raise exception 'a return follows a finalized correction' using errcode = 'DKT04';
  end if;
  perform public.counter_require_operation(p_workspace_id, 'correct_receipt');
  for e in select value from jsonb_array_elements(p_lines) loop
    v_idx := v_idx + 1;
    select * into v_line from public.counter_receipt_lines l
     where l.workspace_id = p_workspace_id and l.receipt_id = v_rec.id and l.id = nullif(e ->> 'corrects_line_id', '')::uuid;
    if v_line.id is null or v_line.id = any (v_seen) or (v_line.frozen ->> 'supply') <> 'goods' or v_line.item_id is null then
      raise exception 'this is not a goods line of the correction' using errcode = 'DKT08', detail = jsonb_build_object('line', v_idx, 'reason', 'line_unknown')::text;
    end if;
    v_seen := v_seen || v_line.id;
    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      raise exception 'this quantity is not a quantity' using errcode = 'DKT08', detail = jsonb_build_object('line', v_idx, 'reason', 'quantity')::text;
    end if;
    v_qty := (e ->> 'quantity')::numeric;
    select coalesce(sum(m.entered_quantity), 0) into v_back from public.stock_movements m
     where m.workspace_id = p_workspace_id and m.counter_receipt_id = v_rec.id and m.reason = 'return_in'
       and m.item_id = v_line.item_id and m.variant_id is not distinct from v_line.variant_id;
    if v_qty > v_line.quantity - v_back then
      raise exception 'more is taken back than the correction credits' using errcode = 'DKT08',
        detail = jsonb_build_object('line', v_idx, 'reason', 'return_beyond', 'left', trim_scale(v_line.quantity - v_back)::text)::text;
    end if;
    v_to := coalesce(nullif(e ->> 'to_location_id', '')::uuid,
                     (select l.id from public.stock_locations l where l.workspace_id = p_workspace_id and l.code = 'MAIN' limit 1));
    if v_to is null then
      raise exception 'no place to put the goods back' using errcode = 'DKT07', detail = 'to_place';
    end if;
    v_move := v_move || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'item_id', v_line.item_id, 'variant_id', v_line.variant_id, 'quantity', trim_scale(v_qty)::text,
      'unit', v_line.frozen #>> '{commercial,unit,code}', 'from', public.stock_place(p_workspace_id, 'customer'), 'to', v_to)));
  end loop;
  v_moved := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_move, 'return_in', now(),
                                      jsonb_build_object('counter_receipt_id', v_rec.id), 'generic');
  v_result := jsonb_build_object('correction_id', v_rec.id, 'movements', jsonb_array_length(v_moved), 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_goods_return', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_goods_return_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.counter_goods_return_v1(uuid, uuid, uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(897);
