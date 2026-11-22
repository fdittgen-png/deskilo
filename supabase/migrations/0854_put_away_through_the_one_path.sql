-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #4303 (of #4177): put-away goes through the one stock path.
--
-- The put-away of a delivery (0840) wrote its lots, balances and movements itself: it made a
-- lot per group of parts (with a cost that may be unknown, and the receipt line it came from),
-- then one movement per part. `stock_apply_lines` is the one function that writes stock; it
-- now expresses what put-away needed, and put-away calls it:
--   * a line may carry `receipt_line_id` (the link of that line's movement);
--   * a `new_lot` may say `cost_state` (`unknown`: no cost, never zero) and `cost_source`, the
--     `quantity_received` of the whole lot, and its code and expiry;
--   * parts of one lot share a `lot_group`: the first part makes the lot, the others reuse it;
--   * mode `put_away` (reason receipt, from the supplier place) may make lots like the generic
--     receipt may.
-- Put-away keeps what is its own: resolving and locking the receipt lines, the exact
-- conversion factors it freezes, the cost rules, and the frozen origin allocations. It writes
-- no lot, balance or movement row itself any more; the place rules and the reserved in-transit
-- place are the one path's as well as its own. The same parts give the same lots, balances,
-- allocations and movements as before (pgTAP 490 asserts it, unchanged).
-- Anchored patches of the live definitions; each anchor is asserted to occur once.

do $patch$
declare
  v_def text;
  v_old text;
  v_new text;
  v_i int;
  v_j int;
begin
  -- ── the one path ────────────────────────────────────────────────────────
  v_def := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
  for v_old, v_new in
    select * from (values
      -- two more locals
      ($a$  v_tv boolean;
begin$a$,
       $b$  v_tv boolean;
  v_groups jsonb := '{}'::jsonb;
  v_links jsonb;
begin$b$),
      -- the line's own link
      ($a$    v_tv := public.stock_place_is_virtual(v_to.id);$a$,
       $b$    v_tv := public.stock_place_is_virtual(v_to.id);
    -- what only put-away says about a line (its receipt line, its lot group, a lot's cost state and
    -- whole quantity) is never taken from a client's line: the generic door refuses it, and in
    -- put-away's own mode a receipt line must be one of this business's
    if p_mode <> 'put_away'
       and (e ? 'receipt_line_id' or e ? 'lot_group'
            or (jsonb_typeof(e -> 'new_lot') = 'object' and (e -> 'new_lot') ?| array['cost_state', 'cost_source', 'quantity_received'])) then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'malformed');
    end if;
    if p_mode = 'put_away' and nullif(e ->> 'receipt_line_id', '') is not null
       and not exists (select 1 from public.purchase_order_receipt_lines rl
                        where rl.id = (e ->> 'receipt_line_id')::uuid and rl.workspace_id = p_workspace_id) then
      perform public.stock_config_refuse(format('lines[%s]', v_no - 1), 'malformed');
    end if;
    v_links := p_links || case when nullif(e ->> 'receipt_line_id', '') is not null
                               then jsonb_build_object('receipt_line_id', e ->> 'receipt_line_id') else '{}'::jsonb end;$b$),
      -- a lot may be made by put-away, with an unknown cost
      ($a$      if p_mode <> 'generic' or p_reason <> 'receipt' or v_lot is not null or not v_fv
         or jsonb_typeof(e -> 'new_lot') <> 'object'
         or nullif(e -> 'new_lot' ->> 'total_cost_minor', '') is null then$a$,
       $b$      if p_mode not in ('generic', 'put_away') or p_reason <> 'receipt' or v_lot is not null or not v_fv
         or jsonb_typeof(e -> 'new_lot') <> 'object'
         or (nullif(e -> 'new_lot' ->> 'total_cost_minor', '') is null
             and coalesce(e -> 'new_lot' ->> 'cost_state', 'known') <> 'unknown') then$b$),
      ($a$      insert into public.stock_lots (workspace_id, item_id, variant_id, lot_code, expires_on, total_cost_minor,
                                     quantity_received, source_currency, source_rate, receipt_line_id)
      values (p_workspace_id, v_item.id, v_var, coalesce(e -> 'new_lot' ->> 'code', ''),
              nullif(e -> 'new_lot' ->> 'expires_on', '')::date,
              (e -> 'new_lot' ->> 'total_cost_minor')::bigint, v_qty,
              nullif(e -> 'new_lot' ->> 'source_currency', ''),
              nullif(e -> 'new_lot' ->> 'source_rate', '')::numeric,
              nullif(p_links ->> 'receipt_line_id', '')::uuid)
      returning id into v_lot;$a$,
       $b$      insert into public.stock_lots (workspace_id, item_id, variant_id, lot_code, expires_on, total_cost_minor,
                                     quantity_received, source_currency, source_rate, receipt_line_id,
                                     cost_state, cost_source)
      values (p_workspace_id, v_item.id, v_var, coalesce(e -> 'new_lot' ->> 'code', ''),
              nullif(e -> 'new_lot' ->> 'expires_on', '')::date,
              coalesce((e -> 'new_lot' ->> 'total_cost_minor')::bigint, 0),
              coalesce((e -> 'new_lot' ->> 'quantity_received')::numeric, v_qty),
              nullif(e -> 'new_lot' ->> 'source_currency', ''),
              nullif(e -> 'new_lot' ->> 'source_rate', '')::numeric,
              coalesce(nullif(e ->> 'receipt_line_id', '')::uuid, nullif(p_links ->> 'receipt_line_id', '')::uuid),
              coalesce(e -> 'new_lot' ->> 'cost_state', 'known'),
              nullif(e -> 'new_lot' ->> 'cost_source', ''))
      returning id into v_lot;
      if nullif(e ->> 'lot_group', '') is not null then
        v_groups := v_groups || jsonb_build_object(e ->> 'lot_group', v_lot::text);
      end if;$b$),
      -- the later parts of a group take its lot (checked like any lot named by a line)
      ($a$    v_lot := nullif(e ->> 'lot_id', '')::uuid;$a$,
       $b$    v_lot := nullif(e ->> 'lot_id', '')::uuid;
    if v_lot is null and nullif(e ->> 'lot_group', '') is not null and v_groups ? (e ->> 'lot_group') then
      v_lot := (v_groups ->> (e ->> 'lot_group'))::uuid;
    end if;$b$)
    ) t(o, n)
  loop
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '0854: an anchor of stock_apply_lines is not found exactly once: %', left(v_old, 80) using errcode = 'P0001';
    end if;
    v_def := replace(v_def, v_old, v_new);
  end loop;
  -- both stock_record calls of the function carry the line's own links
  if (length(v_def) - length(replace(v_def, 'v_no, v_part, p_links, v_var)', ''))) / length('v_no, v_part, p_links, v_var)') <> 1 then
    raise exception '0854: the part call of stock_record in stock_apply_lines is not found exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, 'v_no, v_part, p_links, v_var)', 'v_no, v_part, v_links, v_var)');
  if (length(v_def) - length(replace(v_def, 'v_no, 1, p_links, v_var)', ''))) / length('v_no, 1, p_links, v_var)') <> 1 then
    raise exception '0854: the lot call of stock_record in stock_apply_lines is not found exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, 'v_no, 1, p_links, v_var)', 'v_no, 1, v_links, v_var)');
  execute v_def;

  -- ── put-away: the lots and movements it wrote itself go to the one path ──
  v_def := pg_get_functiondef('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure);
  -- (a) the group's lot is no longer inserted here: it is described, for the one path to make
  v_i := position($a$    insert into public.stock_lots (workspace_id, item_id, variant_id, lot_code, expires_on, total_cost_minor,$a$ in v_def);
  v_j := position($a$    v_groups := v_groups || jsonb_build_object(g.key, (v_groups -> g.key) || jsonb_build_object('lot_id', v_lot));$a$ in v_def);
  if v_i = 0 or v_j = 0 or v_j < v_i then
    raise exception '0854: the lot insert of stock_put_away_apply is not found' using errcode = 'P0001';
  end if;
  v_j := v_j + length($a$    v_groups := v_groups || jsonb_build_object(g.key, (v_groups -> g.key) || jsonb_build_object('lot_id', v_lot));$a$);
  v_def := substr(v_def, 1, v_i - 1)
    || $b$    v_groups := v_groups || jsonb_build_object(g.key, (v_groups -> g.key) || jsonb_build_object('new_lot', jsonb_build_object(
      'code', coalesce(v_lot_meta ->> 'code', ''), 'expires_on', nullif(v_lot_meta ->> 'expires_on', ''),
      'cost_state', case when v_state = 'unknown' then 'unknown' else 'known' end, 'cost_source', v_src,
      'total_cost_minor', case when v_state = 'unknown' then null else v_total end,
      'source_currency', v_cur, 'source_rate', v_rate, 'quantity_received', v_gqty)));$b$
    || substr(v_def, v_j);
  -- (b) the parts are one call of the one path; the frozen allocations follow its answer
  v_i := position($a$  for p in select value from jsonb_array_elements(v_plan) loop
    v_lot := (v_groups -> (p ->> 'key') ->> 'lot_id')::uuid;$a$ in v_def);
  v_j := position($a$    insert into public.stock_receipt_allocations$a$ in v_def);
  if v_i = 0 or v_j = 0 or v_j < v_i then
    raise exception '0854: the movement loop of stock_put_away_apply is not found' using errcode = 'P0001';
  end if;
  v_def := substr(v_def, 1, v_i - 1)
    || $b$  for p in select value from jsonb_array_elements(v_plan) loop
    v_line := jsonb_build_object('item_id', p ->> 'item_id', 'quantity', (p ->> 'entered'), 'unit', p ->> 'unit',
      'from', v_from, 'to', p ->> 'location_id', 'variant_id', p ->> 'variant_id',
      'receipt_line_id', p ->> 'receipt_line_id', 'lot_group', p ->> 'key');
    if not (v_seen ? (p ->> 'key')) then
      v_line := v_line || jsonb_build_object('new_lot', v_groups -> (p ->> 'key') -> 'new_lot');
      v_seen := v_seen || jsonb_build_object(p ->> 'key', true);
    end if;
    v_lines := v_lines || jsonb_build_array(v_line);
  end loop;
  v_moved := public.stock_apply_lines(p_workspace_id, p_actor, p_command, v_lines, 'receipt', now(), '{}'::jsonb, 'put_away');

  for p in select value from jsonb_array_elements(v_plan) loop
    select m into v_m from jsonb_array_elements(v_moved) m where (m ->> 'line_no')::int = (p ->> 'i')::int limit 1;
    v_lot := (v_m ->> 'lot_id')::uuid;
    v_mv := (v_m ->> 'id')::uuid;
$b$
    || substr(v_def, v_j);
  -- (c) the locals the call needs
  v_old := $a$  v_first jsonb;
begin$a$;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception '0854: the declarations of stock_put_away_apply are not found exactly once' using errcode = 'P0001';
  end if;
  v_def := replace(v_def, v_old, $b$  v_first jsonb;
  v_line jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_seen jsonb := '{}'::jsonb;
  v_moved jsonb;
  v_m jsonb;
begin$b$);
  execute v_def;
end
$patch$;

select public.set_deskilo_schema_version(854);
