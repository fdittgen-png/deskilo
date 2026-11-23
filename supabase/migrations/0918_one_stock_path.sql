-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (seven functions restated by anchored patches; no table, no grant, no stored value moves)
--
-- #4398 -- one stock path at command level. `stock_record` is the one writer of the ledger; from here only `stock_apply_lines`
-- calls it, so a rule added there (the pieces of G13, the lots, the variants, the places of a reason) holds for every movement.
-- A return, the decision of a count, the opening stock, the legacy count edit and the booking bridge become modes of it
-- ('return', 'count', 'open', 'bridge', 'legacy'); behaviour is unchanged except where this file says so. The modes that record what a
-- historical fact or the booking bridge hands them ('bridge', 'open', 'return') write exactly that (item, variant, lot, places, quantity):
-- no check against today's variants, lot tracking or active places, and no new choice of lots; 'legacy' (the count edit of an
-- item's own stock) only skips those checks. A correction, a return or a customer return never makes a piece from nothing:
-- the tag it names is one the business already knows (DKG26).
--   * a return line may name its pieces (`units`), so a piece tracked by its tag goes back to the supplier or comes back from the
--     customer with the goods: before, a return of such an item had no way to name them;
--   * a sale taken from several places by the booking bridge is several lines of one request (line n, part 1) instead of one line
--     with several parts.
--
-- restates 0847 0867 0870 0887 (stock_pieces_apply)
create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
create or replace function pg_temp.patch(p_fn regprocedure, p_olds text[], p_news text[])
returns void language plpgsql as $f$
declare
  v_def text := pg_get_functiondef(p_fn);
  k int;
begin
  for k in 1 .. array_length(p_olds, 1) loop
    if pg_temp.occurrences(v_def, p_olds[k]) <> 1 then
      raise exception '0918: anchor % not found exactly once in %', k, p_fn::text using errcode = 'P0001';
    end if;
    v_def := replace(v_def, p_olds[k], p_news[k]);
  end loop;
  execute v_def;
end
$f$;

select pg_temp.patch('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamp with time zone, jsonb, text)'::regprocedure,
  array[
    $o$    if not v_ok then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'reason_places');$o$,
    $o$  v_no := 0;
  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    select * into v_item from public.services$o$,
    $o$and workspace_id = p_workspace_id and stockable;$o$,
    $o$where id = (e ->> 'from')::uuid and workspace_id = p_workspace_id and active;$o$,
    $o$where id = (e ->> 'to')::uuid and workspace_id = p_workspace_id and active;$o$,
    $o$and x.active) then
      raise exception 'line %: not a variant of this item'$o$,
    $o$    if v_var is null and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then$o$,
    $o$    if v_item.tracking <> 'none' and v_lot is null then$o$,
    $o$    if v_lot is null and not v_fv then
      for t in select * from public.stock_take($o$],
  array[
    $n$    -- a return was checked against its source movement by stock_return_v1, whose places follow the movement it reverses
    if not v_ok and p_mode <> 'return' then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'reason_places');$n$,
    $n$  v_no := 0;
  for e in select value from jsonb_array_elements(p_lines) loop
    v_no := v_no + 1;
    -- a return keeps the number its line has in the return
    if p_mode = 'return' and coalesce(e ->> 'line_no', '') ~ '^[0-9]{1,6}$' then
      v_no := (e ->> 'line_no')::int;
    end if;
    select * into v_item from public.services$n$,
    $n$and workspace_id = p_workspace_id and (stockable or p_mode in ('bridge', 'open', 'return', 'legacy'));$n$,
    $n$where id = (e ->> 'from')::uuid and workspace_id = p_workspace_id and (active or p_mode in ('bridge', 'open', 'return', 'legacy'));$n$,
    $n$where id = (e ->> 'to')::uuid and workspace_id = p_workspace_id and (active or p_mode in ('bridge', 'open', 'return', 'legacy'));$n$,
    $n$and (x.active or p_mode in ('bridge', 'open', 'return', 'legacy'))) then
      raise exception 'line %: not a variant of this item'$n$,
    $n$    if v_var is null and not (p_mode in ('bridge', 'open', 'return', 'legacy')) and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then$n$,
    $n$    if v_item.tracking <> 'none' and v_lot is null and not (p_mode in ('bridge', 'open', 'return', 'legacy')) then$n$,
    $n$    if v_lot is null and not v_fv and p_mode not in ('bridge', 'open', 'return') then
      for t in select * from public.stock_take($n$]);

select pg_temp.patch('public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric)'::regprocedure,
  array[
    $o$v_fk not in ('supplier', 'opening', 'loss') then$o$],
  array[
    $n$v_fk not in ('supplier', 'opening', 'loss')
         or p_reason in ('return_out', 'return_in', 'correction') then$n$]);

select pg_temp.patch('public.stock_return_v1(uuid, uuid, uuid, text, jsonb, timestamp with time zone)'::regprocedure,
  array[
    $o$    v_mid := public.stock_record(p_workspace_id, v_src.item_id, v_src.lot_id, v_from, v_to, v_qty,
      v_unit, v_qty, v_at, v_reason, v_me, p_request_id, v_no, 1, v_links, v_src.variant_id);$o$],
  array[
    $n$    -- the one stock path: the movement is written by stock_apply_lines, which also holds the piece rule, so a piece named on
    -- the line comes back, or goes back, with the goods
    v_mid := (public.stock_apply_lines(p_workspace_id, v_me, p_request_id, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'item_id', v_src.item_id, 'lot_id', v_src.lot_id, 'variant_id', v_src.variant_id, 'from', v_from, 'to', v_to,
        'quantity', v_qty::text, 'line_no', v_no, 'expired_ack', true, 'units', e -> 'units'))),
      v_reason, v_at, v_links, 'return') -> 0 ->> 'id')::uuid;$n$]);

select pg_temp.patch('public.stock_count_decide_v1(uuid, uuid, uuid, text, text)'::regprocedure,
  array[
    $o$      if v_diff > 0 then
        v_mid := public.stock_record(p_workspace_id, v_c.item_id, v_c.lot_id, v_loss, v_c.location_id, v_diff, v_unit, v_diff,
                                     now(), 'adjustment', v_me.id, p_request_id, 1, 1, '{}'::jsonb, v_c.variant_id);
      elsif v_c.lot_id is not null then
        v_mid := public.stock_record(p_workspace_id, v_c.item_id, v_c.lot_id, v_c.location_id, v_loss, -v_diff, v_unit, -v_diff,
                                     now(), 'adjustment', v_me.id, p_request_id, 1, 1, '{}'::jsonb, v_c.variant_id);
      else
        -- an item counted as a whole gives back what it holds across its lots, oldest first
        for t in select * from public.stock_take(p_workspace_id, v_c.item_id, v_c.location_id, -v_diff, v_c.variant_id) loop
          v_part := v_part + 1;
          v_one := public.stock_record(p_workspace_id, v_c.item_id, t.lot_id, v_c.location_id, v_loss, t.quantity,
                                       v_unit, t.quantity, now(), 'adjustment', v_me.id, p_request_id, 1, v_part, '{}'::jsonb, v_c.variant_id);
          v_mid := coalesce(v_mid, v_one);
        end loop;
      end if;$o$],
  array[
    $n$      v_mid := (public.stock_apply_lines(p_workspace_id, v_me.id, p_request_id, jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
          'item_id', v_c.item_id, 'lot_id', v_c.lot_id, 'variant_id', v_c.variant_id, 'quantity', abs(v_diff)::text, 'expired_ack', true,
          'from', case when v_diff > 0 then v_loss else v_c.location_id end,
          'to', case when v_diff > 0 then v_c.location_id else v_loss end))),
        'adjustment', now(), '{}'::jsonb, 'count') -> 0 ->> 'id')::uuid;$n$]);

select pg_temp.patch('public.stock_open(uuid)'::regprocedure,
  array[
    $o$      perform public.stock_record(p_workspace_id, r.id, null, v_opening, v_main, r.counted,
        r.inventory_unit, r.counted, now(), 'opening', null, gen_random_uuid(), 1, 1, '{}'::jsonb);$o$],
  array[
    $n$      perform public.stock_apply_lines(p_workspace_id, null, gen_random_uuid(), jsonb_build_array(jsonb_build_object(
          'item_id', r.id, 'from', v_opening, 'to', v_main, 'quantity', r.counted::text)), 'opening', now(), '{}'::jsonb, 'open');$n$]);

select pg_temp.patch('public.services_stock_ledger_after()'::regprocedure,
  array[
    $o$    perform public.stock_record(new.workspace_id, new.id, null,
      public.stock_place(new.workspace_id, 'opening'), public.stock_place(new.workspace_id, 'warehouse'),
      new.stock, new.inventory_unit, new.stock, now(), 'opening', public.stock_count_actor(new.workspace_id),
      gen_random_uuid(), 1, 1, '{}'::jsonb);$o$],
  array[
    $n$    perform public.stock_apply_lines(new.workspace_id, public.stock_count_actor(new.workspace_id), gen_random_uuid(), jsonb_build_array(jsonb_build_object(
        'item_id', new.id, 'from', public.stock_place(new.workspace_id, 'opening'), 'to', public.stock_place(new.workspace_id, 'warehouse'),
        'quantity', new.stock::text)), 'opening', now(), '{}'::jsonb, 'open');$n$]);

select pg_temp.patch('public.services_stock_ledger_before()'::regprocedure,
  array[
    $o$  if v_diff > 0 then
    perform public.stock_record(new.workspace_id, new.id, null, v_loss, v_main, v_diff,
      new.inventory_unit, v_diff, now(), 'adjustment', v_actor, v_req, 1, 1, '{}'::jsonb);
  elsif v_diff < 0 then
    for t in select * from public.stock_take(new.workspace_id, new.id, v_main, -v_diff) loop
      v_part := v_part + 1;
      perform public.stock_record(new.workspace_id, new.id, t.lot_id, v_main, v_loss, t.quantity,
        new.inventory_unit, t.quantity, now(), 'adjustment', v_actor, v_req, 1, v_part, '{}'::jsonb);
    end loop;
  end if;$o$],
  array[
    $n$  if v_diff <> 0 then
    perform public.stock_apply_lines(new.workspace_id, v_actor, v_req, jsonb_build_array(jsonb_build_object(
        'item_id', new.id, 'from', case when v_diff > 0 then v_loss else v_main end, 'to', case when v_diff > 0 then v_main else v_loss end,
        'quantity', abs(v_diff)::text, 'expired_ack', true)), 'adjustment', now(), '{}'::jsonb, 'legacy');
  end if;$n$]);

select pg_temp.patch('public.apply_stock_on_confirm()'::regprocedure,
  array[
    $o$      perform public.stock_record(new.workspace_id, v_service_id, null,
        public.stock_place(new.workspace_id, 'supplier'), public.stock_place(new.workspace_id, 'warehouse'),
        v_qty, v_unit, v_qty, now(), 'receipt', new.actor_member_id, new.id, 1, 1,
        jsonb_build_object('event_id', new.id));$o$,
    $o$      for t in select * from public.stock_take_in_tree(new.workspace_id, v_service_id, v_main, v_qty) loop
        v_part := v_part + 1;
        perform public.stock_record(new.workspace_id, v_service_id, t.lot_id, t.location_id,
          public.stock_place(new.workspace_id, 'customer'), t.quantity, v_unit, t.quantity, now(),
          'sale', new.actor_member_id, new.id, 1, v_part, jsonb_build_object('event_id', new.id));
      end loop;$o$],
  array[
    $n$      perform public.stock_apply_lines(new.workspace_id, new.actor_member_id, new.id, jsonb_build_array(jsonb_build_object(
          'item_id', v_service_id, 'from', public.stock_place(new.workspace_id, 'supplier'), 'to', public.stock_place(new.workspace_id, 'warehouse'),
          'quantity', v_qty::text)), 'receipt', now(), jsonb_build_object('event_id', new.id), 'bridge');$n$,
    $n$      perform public.stock_apply_lines(new.workspace_id, new.actor_member_id, new.id, coalesce((
          select jsonb_agg(jsonb_build_object('item_id', v_service_id, 'lot_id', x.lot_id, 'from', x.location_id,
                                              'to', public.stock_place(new.workspace_id, 'customer'), 'quantity', x.quantity::text, 'expired_ack', true))
            from public.stock_take_in_tree(new.workspace_id, v_service_id, v_main, v_qty) x), '[]'::jsonb),
        'sale', now(), jsonb_build_object('event_id', new.id), 'bridge');$n$]);

select public.set_deskilo_schema_version(918);
