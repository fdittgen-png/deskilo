-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two new read functions and one new refusal; no stored value moves)
--
-- #4161 (A1) -- bounded, keyset-paged reads of the stock ledger, for the
-- Stock screen. The released S1 reads (stock_on_hand_v1,
-- stock_movement_trace_v1) keep their signatures and answers; these are
-- additive.
--
-- The contract (docs/domain/contracts/stock_operations.md):
--   * a page holds at most p_limit rows (1..200, default 50); a request
--     outside that is refused (DKG09), never clamped;
--   * rows come with their continuation: `complete` is true when nothing
--     follows, else `next` is the cursor of the last row returned; the list
--     is never silently truncated;
--   * the order is a total order on immutable keys, so equal sort keys never
--     repeat or skip a row: on-hand rows by (item id, place id, lot id,
--     nulls first); movements newest first by (occurred_at, id);
--   * consistency: pages are NOT one snapshot. Each page reads the ledger as
--     it is when the page is read. A row that exists throughout appears
--     exactly once; a row added behind the cursor between two reads is not
--     seen by that walk; a quantity read twice may differ (it is the quantity
--     at that read). A cursor is only valid for the filters it was made with
--     and for version 1: another version or a malformed cursor is refused
--     (DKG09); a cursor is a position, the caller keeps its filters;
--   * quantities travel as TEXT of the stored numeric(18,6), never as a JSON
--     number: no float mantissa. Valuation is never invented: an unknown
--     unit cost is null;
--   * purchase cost is finance data: unit_cost, purchase_line_id and
--     receipt_line_id (and a lot's cost, source currency and rate) are
--     returned only to a caller holding viewFinances or managePurchases, and
--     are null otherwise -- null means "not shown", never zero. The released
--     stock_movement_trace_v1 is corrected the same way below, and
--     stock_value_at_v1, which IS the cost of the goods, refuses a reader who
--     may only see the stock (DKN01);
--   * the same columns cannot be read straight from the tables either (column
--     grants at the end of this file);
--   * the caller needs viewStock or manageStock in the business and
--     stockManagement on (DKN01/DKG01, as the S1 reads); a delegated
--     assistant session reads nothing (DKN01).

-- One more refusal: the page request itself is invalid.
create or replace function public.stock_page_reader(p_workspace_id uuid, p_limit int)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  perform public.stock_reader(p_workspace_id);
  if p_limit is null or p_limit < 1 or p_limit > 200 then
    raise exception 'invalid page size' using errcode = 'DKG09';
  end if;
end;
$fn$;
revoke execute on function public.stock_page_reader(uuid, int) from public, anon, authenticated;

-- Whether the caller may see what goods cost: finance data.
create or replace function public.stock_sees_cost(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.has_permission(p_workspace_id, 'viewFinances')
      or public.has_permission(p_workspace_id, 'managePurchases');
$fn$;
revoke execute on function public.stock_sees_cost(uuid) from public, anon, authenticated;

-- What is on hand at the real places, a page at a time.
create or replace function public.stock_on_hand_page_v1(
  p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null,
  p_limit int default 50, p_after jsonb default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_zero constant uuid := '00000000-0000-0000-0000-000000000000';
  v_item uuid; v_loc uuid; v_lot uuid;
  v_rows jsonb; v_n int; v_last jsonb;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_item := (p_after->>'item_id')::uuid;
      v_loc := (p_after->>'location_id')::uuid;
      v_lot := coalesce((p_after->>'lot_id')::uuid, v_zero);
      if v_item is null or v_loc is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when others then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with page as (
    select b.item_id, b.location_id, b.lot_id, b.quantity, s.name as item_name,
           s.inventory_unit as unit, l.code as location_code, l.name as location_name,
           t.lot_code
      from public.stock_balances b
      join public.services s on s.id = b.item_id
      join public.stock_locations l on l.id = b.location_id
      join public.stock_location_kinds k on k.key = l.kind
      left join public.stock_lots t on t.id = b.lot_id
     where b.workspace_id = p_workspace_id and not k.virtual and b.quantity <> 0
       and (p_item_id is null or b.item_id = p_item_id)
       and (p_location_id is null or b.location_id = p_location_id)
       and (p_after is null
            or (b.item_id, b.location_id, coalesce(b.lot_id, v_zero)) > (v_item, v_loc, v_lot))
     order by b.item_id, b.location_id, coalesce(b.lot_id, v_zero)
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'workspace_id', p_workspace_id, 'item_id', item_id, 'item_name', item_name,
           'lot_id', lot_id, 'lot_code', lot_code, 'location_id', location_id,
           'location_code', location_code, 'location_name', location_name,
           'quantity', quantity::text, 'unit', unit)
           order by item_id, location_id, coalesce(lot_id, v_zero)), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;                     -- drop the look-ahead row
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next', jsonb_build_object(
      'version', 1, 'item_id', v_last -> 'item_id', 'location_id', v_last -> 'location_id',
      'lot_id', v_last -> 'lot_id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_on_hand_page_v1(uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.stock_on_hand_page_v1(uuid, uuid, uuid, int, jsonb) to authenticated;

-- The movements, newest first, a page at a time. With p_movement_id the page
-- holds that one movement (or none): the address of a movement.
create or replace function public.stock_movements_page_v1(
  p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null,
  p_limit int default 50, p_after jsonb default null, p_movement_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_at timestamptz; v_id uuid;
  v_rows jsonb; v_n int; v_last jsonb; v_cost boolean;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  v_cost := public.stock_sees_cost(p_workspace_id);
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_at := (p_after->>'occurred_at')::timestamptz;
      v_id := (p_after->>'id')::uuid;
      if v_at is null or v_id is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when others then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with page as (
    select m.id, m.item_id, s.name as item_name, s.inventory_unit as unit, m.lot_id, t.lot_code,
           m.from_location_id, lf.code as from_code, m.to_location_id, lt.code as to_code,
           m.quantity, m.entered_quantity, m.entered_unit, m.occurred_at, m.reason, m.unit_cost,
           m.actor_member_id, m.receipt_line_id, m.purchase_line_id, m.event_id, m.invoice_id
      from public.stock_movements m
      join public.services s on s.id = m.item_id
      join public.stock_locations lf on lf.id = m.from_location_id
      join public.stock_locations lt on lt.id = m.to_location_id
      left join public.stock_lots t on t.id = m.lot_id
     where m.workspace_id = p_workspace_id
       and (p_movement_id is null or m.id = p_movement_id)
       and (p_item_id is null or m.item_id = p_item_id)
       and (p_location_id is null or p_location_id in (m.from_location_id, m.to_location_id))
       and (p_after is null or (m.occurred_at, m.id) < (v_at, v_id))
     order by m.occurred_at desc, m.id desc
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'workspace_id', p_workspace_id, 'id', id, 'item_id', item_id, 'item_name', item_name,
           'lot_id', lot_id, 'lot_code', lot_code,
           'from_location_id', from_location_id, 'from_location_code', from_code,
           'to_location_id', to_location_id, 'to_location_code', to_code,
           'quantity', quantity::text, 'unit', unit,
           'entered_quantity', entered_quantity::text, 'entered_unit', entered_unit,
           'occurred_at', occurred_at, 'reason', reason,
           'unit_cost', case when v_cost then unit_cost::text end, 'actor_member_id', actor_member_id,
           'receipt_line_id', case when v_cost then receipt_line_id end,
           'purchase_line_id', case when v_cost then purchase_line_id end,
           'event_id', event_id, 'invoice_id', invoice_id)
           order by occurred_at desc, id desc), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next', jsonb_build_object(
      'version', 1, 'occurred_at', v_last -> 'occurred_at', 'id', v_last -> 'id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_movements_page_v1(uuid, uuid, uuid, int, jsonb, uuid) from public, anon;
grant execute on function public.stock_movements_page_v1(uuid, uuid, uuid, int, jsonb, uuid) to authenticated;

-- The released trace answered the cost of the goods to anyone who may see
-- the stock. Same signature, same answer for a caller who may see costs; the
-- others get the same rows with the cost, its purchase causes and a lot's
-- source currency and rate left out (absent, never zero).
create or replace function public.stock_movement_trace_v1(p_workspace_id uuid, p_movement_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  m public.stock_movements;
  v_move_hide text[] := case when public.stock_sees_cost(p_workspace_id) then array[]::text[]
                             else array['unit_cost', 'receipt_line_id', 'purchase_line_id'] end;
  v_lot_hide text[] := case when public.stock_sees_cost(p_workspace_id) then array[]::text[]
                            else array['total_cost_minor', 'receipt_line_id', 'source_currency', 'source_rate'] end;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  perform public.stock_reader(p_workspace_id);
  select * into m from public.stock_movements where id = p_movement_id and workspace_id = p_workspace_id;
  if m.id is null then
    raise exception 'unknown movement' using errcode = 'DKG07';
  end if;
  return jsonb_build_object(
    'movement', to_jsonb(m) - public.system_column_names() - v_move_hide,
    'lot', (select to_jsonb(l) - public.system_column_names() - v_lot_hide from public.stock_lots l where l.id = m.lot_id),
    'lot_movements', case when m.lot_id is null then '[]'::jsonb else coalesce((
      select jsonb_agg(to_jsonb(x) - public.system_column_names() - v_move_hide order by x.occurred_at, x.line_no, x.part)
        from public.stock_movements x where x.lot_id = m.lot_id), '[]'::jsonb) end);
end;
$fn$;
revoke execute on function public.stock_movement_trace_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_movement_trace_v1(uuid, uuid) to authenticated;

-- The value on hand is the cost of the goods: finance data, as the trace's
-- cost. A reader who may only see the stock is refused (DKN01), not shown
-- nulls that look like an empty stock; a caller with finance rights gets the
-- same answer as before.
create or replace function public.stock_value_at_v1(p_workspace_id uuid, p_at timestamptz)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rows jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to see the stock' using errcode = 'DKN01';
  end if;
  perform public.stock_reader(p_workspace_id);
  if not public.stock_sees_cost(p_workspace_id) then
    raise exception 'not allowed to see what goods cost' using errcode = 'DKN01';
  end if;
  with q as (
    select m.item_id, m.lot_id,
           sum(case when not kt.virtual then m.quantity else 0 end)
         - sum(case when not kf.virtual then m.quantity else 0 end) as quantity
      from public.stock_movements m
      join public.stock_locations lf on lf.id = m.from_location_id
      join public.stock_location_kinds kf on kf.key = lf.kind
      join public.stock_locations lt on lt.id = m.to_location_id
      join public.stock_location_kinds kt on kt.key = lt.kind
     where m.workspace_id = p_workspace_id and m.occurred_at <= coalesce(p_at, now())
     group by m.item_id, m.lot_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'item_id', q.item_id, 'lot_id', q.lot_id, 'quantity', q.quantity,
           'unit_cost', l.total_cost_minor::numeric / l.quantity_received,
           'value_minor', round(q.quantity * l.total_cost_minor / l.quantity_received))
           order by q.item_id, q.lot_id), '[]'::jsonb)
    into v_rows
    from q left join public.stock_lots l on l.id = q.lot_id
   where q.quantity <> 0;
  return jsonb_build_object(
    'at', coalesce(p_at, now()),
    'items', v_rows,
    'total_minor', coalesce((select sum((r ->> 'value_minor')::numeric)
                               from jsonb_array_elements(v_rows) r
                              where r ->> 'value_minor' is not null), 0));
end;
$fn$;
revoke execute on function public.stock_value_at_v1(uuid, timestamptz) from public, anon;
grant execute on function public.stock_value_at_v1(uuid, timestamptz) to authenticated;

-- ── the cost columns are not readable straight from the tables ──────────
-- The RPCs above mask the cost for a reader who may only see the stock; a
-- table-wide select grant (0747) would let the same reader read the columns
-- through the REST API. Column-level select replaces it: the cost columns
-- (a movement's unit_cost and its purchase causes, a lot's cost, source
-- currency and rate and its receipt line) are left out for the signed-in
-- role. A holder of finance rights reads costs through the RPCs, which check
-- the permission; the definer functions and the workspace export read the
-- tables as their owner. A column added to either table later is NOT
-- selectable until a migration grants it.
revoke select on public.stock_movements, public.stock_lots from authenticated;
do $g$
declare
  v_table text;
  v_columns text;
begin
  foreach v_table in array array['stock_movements', 'stock_lots'] loop
    select string_agg(format('%I', c.column_name), ', ' order by c.ordinal_position)
      into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (case v_table
             when 'stock_movements' then array['unit_cost', 'receipt_line_id', 'purchase_line_id']
             else array['total_cost_minor', 'source_currency', 'source_rate', 'receipt_line_id'] end);
    execute format('grant select (%s) on public.%I to authenticated', v_columns, v_table);
  end loop;
end
$g$;

select public.set_deskilo_schema_version(833);
