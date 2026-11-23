-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (new functions only; the commands write the tables of 0928 and move stock through the one stock path)
--
-- #4435 (G20, second of four files) -- make, move and unpack a handling unit.
--   * `stock_hu_make_v1` makes a unit at a place from loose stock there: the code, an optional label, a kind, the lines (item,
--     variant, lot, quantity; the pieces of an item tracked piece by piece). It claims stock, it writes no movement: the ledger
--     already holds the goods. A line can only claim what is loose at the place (the balance there minus what open units there
--     already hold); a piece must be in stock at that place and in no other unit.
--   * `stock_hu_move_v1` moves a unit, with the units nested in it, and its whole content in ONE request through the one stock
--     path (`stock_apply_lines`, reason transfer): every line keeps its own lot and pieces. The unit is locked first and its
--     revision compared: a second person moving the same unit is refused DKG27 with the unit's new place and revision.
--   * `stock_hu_unpack_v1` puts the content at the unit's place, loose, and retires the unit; nested units become top-level.
-- Refusals: DKG27 the unit changed (detail: unit_id, state, location_id, revision), DKG28 the content does not fit (detail:
-- reason, ...), DKG29 the code is taken (detail: code); the stock path's own DKG03/DKG25/DKG26 pass through.
-- Whoever manages the stock acts; an assistant is refused (as for every stock command).

create or replace function public.stock_hu_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
begin
  if not public.feature_effective(p_workspace_id, 'stockHandlingUnits') then
    perform public.refuse('DKG01', null, 'handling units are off in this business');
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_hu_actor(uuid) from public, anon, authenticated;

-- what of an item, variant and lot is loose at a place: the balance there minus what open units there hold
create or replace function public.stock_hu_loose(p_workspace_id uuid, p_item uuid, p_variant uuid, p_lot uuid, p_location uuid, p_except uuid default null)
returns numeric language sql stable security definer set search_path = public as $fn$
  select coalesce((select sum(b.quantity) from public.stock_balances b
                    where b.workspace_id = p_workspace_id and b.item_id = p_item and b.variant_id is not distinct from p_variant
                      and b.lot_id is not distinct from p_lot and b.location_id = p_location), 0)
       - coalesce((select sum(l.quantity) from public.stock_handling_unit_lines l
                     join public.stock_handling_units u on u.workspace_id = l.workspace_id and u.id = l.unit_id
                    where l.workspace_id = p_workspace_id and l.item_id = p_item and l.variant_id is not distinct from p_variant
                      and l.lot_id is not distinct from p_lot and u.location_id = p_location and u.state = 'open'
                      and u.id is distinct from p_except), 0)
$fn$;
revoke execute on function public.stock_hu_loose(uuid, uuid, uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.stock_hu_uuid(p_text text, p_what text)
returns uuid language plpgsql immutable set search_path = public as $fn$
begin
  if p_text is null or p_text = '' then return null; end if;
  if p_text !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'malformed', 'field', p_what), 'a handling unit line is malformed');
  end if;
  return p_text::uuid;
end;
$fn$;
revoke execute on function public.stock_hu_uuid(text, text) from public, anon, authenticated;

-- one content line put into a unit at its place: checked against what is loose there, the pieces claimed
create or replace function public.stock_hu_add_line(p_workspace_id uuid, p_unit uuid, p_location uuid, p_line jsonb)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_item public.services;
  v_var uuid := public.stock_hu_uuid(p_line ->> 'variant_id', 'variant_id');
  v_lot uuid := public.stock_hu_uuid(p_line ->> 'lot_id', 'lot_id');
  v_qty numeric;
  v_line uuid;
  v_units jsonb := p_line -> 'units';
  v_n int := 0;
  u record;
  pc public.stock_tagged_units;
begin
  select * into v_item from public.services
   where id = public.stock_hu_uuid(p_line ->> 'item_id', 'item_id') and workspace_id = p_workspace_id and stockable;
  if v_item.id is null then
    perform public.refuse('DKG04', null, 'not a stock item of this business');
  end if;
  if coalesce(p_line ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (p_line ->> 'quantity')::numeric <= 0 then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'quantity', 'item_id', v_item.id), 'a quantity is a positive number');
  end if;
  v_qty := (p_line ->> 'quantity')::numeric;
  if v_item.tracking in ('lot', 'expiry') and v_lot is null then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'lot_required', 'item_id', v_item.id), 'a unit holds a lot of a lot-tracked item');
  end if;
  if v_item.tracking = 'serial' then
    if v_units is null or jsonb_typeof(v_units) <> 'array' or jsonb_array_length(v_units) <> v_qty then
      perform public.refuse('DKG28', jsonb_build_object('reason', 'pieces', 'item_id', v_item.id), 'a piece-tracked line names its pieces');
    end if;
  elsif v_units is not null then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'pieces', 'item_id', v_item.id), 'only a piece-tracked line names pieces');
  elsif v_qty > public.stock_hu_loose(p_workspace_id, v_item.id, v_var, v_lot, p_location, p_unit) then
    perform public.refuse('DKG03', jsonb_build_object('item_id', v_item.id, 'location_id', p_location,
      'have', public.stock_hu_loose(p_workspace_id, v_item.id, v_var, v_lot, p_location, p_unit), 'asked', v_qty), 'not that much loose here');
  end if;
  select id into v_line from public.stock_handling_unit_lines
   where unit_id = p_unit and item_id = v_item.id and variant_id is not distinct from v_var and lot_id is not distinct from v_lot for update;
  if v_line is null then
    insert into public.stock_handling_unit_lines (workspace_id, unit_id, item_id, variant_id, lot_id, quantity)
    values (p_workspace_id, p_unit, v_item.id, v_var, v_lot, v_qty) returning id into v_line;
  else
    update public.stock_handling_unit_lines set quantity = quantity + v_qty where id = v_line;
  end if;
  if v_item.tracking = 'serial' then
    for u in select value from jsonb_array_elements(v_units) loop
      select * into pc from public.stock_tagged_units
       where id = public.stock_hu_uuid(u.value ->> 'piece_id', 'piece_id') and workspace_id = p_workspace_id for update;
      if pc.id is null or pc.item_id <> v_item.id or pc.variant_id is distinct from v_var or pc.lot_id is distinct from v_lot
         or pc.state <> 'in_stock' or pc.location_id <> p_location
         or exists (select 1 from public.stock_handling_unit_pieces x where x.piece_id = pc.id) then
        perform public.refuse('DKG28', jsonb_build_object('reason', 'piece_not_here', 'piece_id', u.value ->> 'piece_id', 'location_id', p_location),
          'a piece is not in stock here, or is in another unit');
      end if;
      insert into public.stock_handling_unit_pieces (workspace_id, unit_line_id, piece_id) values (p_workspace_id, v_line, pc.id);
      v_n := v_n + 1;
    end loop;
  end if;
end;
$fn$;
revoke execute on function public.stock_hu_add_line(uuid, uuid, uuid, jsonb) from public, anon, authenticated;

-- the unit as the commands answer it
create or replace function public.stock_hu_json(p_workspace_id uuid, p_unit uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('id', u.id, 'code', u.code, 'label_code', u.label_code, 'kind', u.kind, 'state', u.state,
           'location_id', u.location_id, 'parent_unit_id', u.parent_unit_id, 'revision', u.revision)
    from public.stock_handling_units u where u.workspace_id = p_workspace_id and u.id = p_unit
$fn$;
revoke execute on function public.stock_hu_json(uuid, uuid) from public, anon, authenticated;

-- ── make ─────────────────────────────────────────────────────────────────
create or replace function public.stock_hu_make_v1(p_workspace_id uuid, p_request_id uuid, p_unit jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_hu_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_loc uuid;
  v_parent uuid;
  v_id uuid;
  v_kind text;
  e jsonb;
begin
  if p_request_id is null or coalesce(jsonb_typeof(p_unit), '') <> 'object'
     or coalesce(jsonb_typeof(p_unit -> 'lines'), '') <> 'array' or jsonb_array_length(p_unit -> 'lines') not between 1 and 200 then
    perform public.refuse('DKG07', null, 'a unit has a request id and 1 to 200 lines');
  end if;
  v_digest := md5('hu_make|' || p_unit::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_hu_make', v_digest);
  if v_done is not null then return v_done; end if;
  v_loc := public.stock_hu_uuid(p_unit ->> 'location_id', 'location_id');
  if not exists (select 1 from public.stock_locations where id = v_loc and workspace_id = p_workspace_id and active) then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'place'), 'a unit is at an active place of this business');
  end if;
  v_kind := coalesce(nullif(p_unit ->> 'kind', ''), 'other');
  v_parent := public.stock_hu_uuid(p_unit ->> 'parent_unit_id', 'parent_unit_id');
  if v_parent is not null and not exists (select 1 from public.stock_handling_units
       where id = v_parent and workspace_id = p_workspace_id and state = 'open' and parent_unit_id is null and location_id = v_loc) then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'parent'), 'a unit nests in an open top-level unit at the same place');
  end if;
  begin
    insert into public.stock_handling_units (workspace_id, code, label_code, kind, location_id, parent_unit_id, receipt_line_id)
    values (p_workspace_id, btrim(coalesce(p_unit ->> 'code', '')), nullif(btrim(coalesce(p_unit ->> 'label_code', '')), ''), v_kind, v_loc, v_parent,
            public.stock_hu_uuid(p_unit ->> 'receipt_line_id', 'receipt_line_id'))
    returning id into v_id;
  exception
    when unique_violation then
      perform public.refuse('DKG29', jsonb_build_object('code', p_unit ->> 'code'), 'this unit code is taken');
    when check_violation then
      perform public.refuse('DKG28', jsonb_build_object('reason', 'unit'), 'a unit needs a code and a known kind');
  end;
  for e in select value from jsonb_array_elements(p_unit -> 'lines') loop
    perform public.stock_hu_add_line(p_workspace_id, v_id, v_loc, e);
  end loop;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_hu_make', v_digest,
    jsonb_build_object('request_id', p_request_id, 'unit', public.stock_hu_json(p_workspace_id, v_id)));
end;
$fn$;
revoke execute on function public.stock_hu_make_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.stock_hu_make_v1(uuid, uuid, jsonb) to authenticated;

-- the unit the commands act on, locked, at the revision the caller saw
create or replace function public.stock_hu_lock(p_workspace_id uuid, p_unit uuid, p_revision int)
returns public.stock_handling_units language plpgsql security definer set search_path = public as $fn$
declare
  v_u public.stock_handling_units;
begin
  select * into v_u from public.stock_handling_units where id = p_unit and workspace_id = p_workspace_id for update;
  if v_u.id is null then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'unit_unknown', 'unit_id', p_unit), 'not a handling unit of this business');
  end if;
  if v_u.state <> 'open' or (p_revision is not null and v_u.revision <> p_revision) then
    perform public.refuse('DKG27', jsonb_build_object('unit_id', v_u.id, 'state', v_u.state, 'location_id', v_u.location_id,
      'revision', v_u.revision), 'the unit changed since it was read');
  end if;
  return v_u;
end;
$fn$;
revoke execute on function public.stock_hu_lock(uuid, uuid, int) from public, anon, authenticated;

-- ── move ─────────────────────────────────────────────────────────────────
create or replace function public.stock_hu_move_v1(p_workspace_id uuid, p_request_id uuid, p_unit_id uuid, p_to uuid, p_revision int)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_hu_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_u public.stock_handling_units;
  v_ids uuid[];
  v_lines jsonb := '[]'::jsonb;
  v_owner uuid[] := array[]::uuid[];
  r record;
  v_pieces jsonb;
  v_out jsonb;
  m jsonb;
begin
  if p_request_id is null or p_to is null then
    perform public.refuse('DKG07', null, 'a move has a request id and a place');
  end if;
  v_digest := md5('hu_move|' || p_unit_id::text || '|' || p_to::text || '|' || coalesce(p_revision::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_hu_move', v_digest);
  if v_done is not null then return v_done; end if;
  v_u := public.stock_hu_lock(p_workspace_id, p_unit_id, p_revision);
  if v_u.parent_unit_id is not null then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'nested', 'parent_unit_id', v_u.parent_unit_id), 'a nested unit moves with its parent');
  end if;
  if not exists (select 1 from public.stock_locations where id = p_to and workspace_id = p_workspace_id and active) then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'place'), 'a unit goes to an active place of this business');
  end if;
  if p_to = v_u.location_id then
    perform public.refuse('DKG28', jsonb_build_object('reason', 'same_place', 'location_id', p_to), 'the unit is already there');
  end if;
  select array_agg(id order by id) into v_ids from (
    select v_u.id as id union all
    select c.id from public.stock_handling_units c
     where c.workspace_id = p_workspace_id and c.parent_unit_id = v_u.id and c.state = 'open') x;
  perform 1 from public.stock_handling_units where id = any (v_ids) order by id for update;
  for r in
    select l.*, un.id as uid, un.location_id as loc
      from public.stock_handling_unit_lines l
      join public.stock_handling_units un on un.workspace_id = l.workspace_id and un.id = l.unit_id
     where l.workspace_id = p_workspace_id and un.id = any (v_ids)
     order by un.id, l.item_id, l.id
  loop
    select coalesce(jsonb_agg(jsonb_build_object('piece_id', p.piece_id) order by p.piece_id), null) into v_pieces
      from public.stock_handling_unit_pieces p where p.unit_line_id = r.id;
    v_lines := v_lines || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'item_id', r.item_id, 'variant_id', r.variant_id, 'lot_id', r.lot_id, 'from', r.loc, 'to', p_to,
      'quantity', r.quantity, 'units', v_pieces)));
    v_owner := v_owner || r.uid;
  end loop;
  if jsonb_array_length(v_lines) > 0 then
    v_out := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_lines, 'transfer', now(), '{}'::jsonb, 'generic');
    for m in select value from jsonb_array_elements(v_out) loop
      insert into public.stock_movement_handling_units (workspace_id, movement_id, unit_id)
      values (p_workspace_id, (m ->> 'id')::uuid, v_owner[(m ->> 'line_no')::int])
      on conflict do nothing;
    end loop;
  else
    v_out := '[]'::jsonb;
  end if;
  update public.stock_handling_units set location_id = p_to, revision = revision + 1 where id = any (v_ids) and workspace_id = p_workspace_id;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_hu_move', v_digest,
    jsonb_build_object('request_id', p_request_id, 'movements', v_out, 'unit', public.stock_hu_json(p_workspace_id, v_u.id)));
end;
$fn$;
revoke execute on function public.stock_hu_move_v1(uuid, uuid, uuid, uuid, int) from public, anon;
grant execute on function public.stock_hu_move_v1(uuid, uuid, uuid, uuid, int) to authenticated;

-- ── unpack ───────────────────────────────────────────────────────────────
create or replace function public.stock_hu_unpack_v1(p_workspace_id uuid, p_request_id uuid, p_unit_id uuid, p_revision int)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_hu_actor(p_workspace_id);
  v_digest text;
  v_done jsonb;
  v_u public.stock_handling_units;
begin
  if p_request_id is null then
    perform public.refuse('DKG07', null, 'an unpack has a request id');
  end if;
  v_digest := md5('hu_unpack|' || p_unit_id::text || '|' || coalesce(p_revision::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_hu_unpack', v_digest);
  if v_done is not null then return v_done; end if;
  v_u := public.stock_hu_lock(p_workspace_id, p_unit_id, p_revision);
  update public.stock_handling_units set parent_unit_id = null, revision = revision + 1
   where workspace_id = p_workspace_id and parent_unit_id = v_u.id;
  delete from public.stock_handling_unit_lines where workspace_id = p_workspace_id and unit_id = v_u.id;
  update public.stock_handling_units set state = 'unpacked', revision = revision + 1 where id = v_u.id;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_hu_unpack', v_digest,
    jsonb_build_object('request_id', p_request_id, 'unit', public.stock_hu_json(p_workspace_id, v_u.id)));
end;
$fn$;
revoke execute on function public.stock_hu_unpack_v1(uuid, uuid, uuid, int) from public, anon;
grant execute on function public.stock_hu_unpack_v1(uuid, uuid, uuid, int) to authenticated;

select public.set_deskilo_schema_version(929);
