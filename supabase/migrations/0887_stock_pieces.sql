-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (functions and a deferred constraint trigger on the movements; stock_apply_lines is patched at one asserted
--  anchor)
--
-- #4362 (G13, fourth of four files) -- an item tagged piece by piece moves only with its pieces.
--
--   * An item whose tag mode is `per_unit` (and whose tracking is by piece) is moved by naming its pieces:
--     each line carries `units`, one entry per piece (`{"tag": "E280..."}` or `{"piece_id": ...}`), as many as
--     the quantity. A piece that arrives from outside (a receipt, an opening, goods found) is created, at the
--     place it arrives at, with its tag bound to it; a piece already known must be where the movement takes it
--     from. The piece changes place, and state, in the same transaction as the movement: in stock at a real
--     place or in transit, sold at the customer, returned at the supplier, written off at the loss.
--   * The count of pieces in stock at a place equals what the ledger holds there, per variant and lot. A
--     deferred constraint on the movements holds every path to it at commit (a count, a return or a
--     transfer that does not name its pieces is refused: "Name the pieces - this item is tracked piece by
--     piece"), and `stock_pieces_check_v1` shows the difference.

create or replace function public.stock_pieces_apply(
  p_workspace_id uuid, p_item_id uuid, p_variant uuid, p_lot uuid, p_line jsonb,
  p_from uuid, p_to uuid, p_reason text, p_qty numeric)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_mode text;
  v_units jsonb := p_line -> 'units';
  v_tracking text;
  v_n int;
  v_fk text;
  v_tk text;
  v_expect text;
  v_state text;
  u jsonb;
  v_code text;
  v_pid uuid;
  pc public.stock_tagged_units;
  v_ids uuid[] := array[]::uuid[];
  v_new uuid;
  v_grace int := coalesce((public.setting_value(p_workspace_id, 'stock.tag_rebind_grace_days') #>> '{}')::int, 30);
begin
  if not public.feature_effective(p_workspace_id, 'stockTags') then
    if v_units is not null then
      perform public.stock_config_refuse('units', 'units_not_tracked');
    end if;
    return;
  end if;
  v_mode := public.item_effective_core(p_item_id) #>> '{parameters,tag_mode,value}';
  if v_mode is distinct from 'per_unit' then
    if v_units is not null then
      perform public.stock_config_refuse('units', 'units_not_tracked');
    end if;
    return;
  end if;
  select tracking into v_tracking from public.services where id = p_item_id;
  if v_tracking <> 'serial' then
    perform public.stock_config_refuse('tag_mode', 'needs_serial');
  end if;
  if v_units is null or jsonb_typeof(v_units) <> 'array' or jsonb_array_length(v_units) = 0 then
    raise exception 'name the pieces: this item is tracked piece by piece' using errcode = 'DKG25';
  end if;
  v_n := jsonb_array_length(v_units);
  if p_qty <> v_n then
    raise exception 'name the pieces: % named for a quantity of %', v_n, p_qty using errcode = 'DKG25';
  end if;
  select kind into v_fk from public.stock_locations where id = p_from;
  select kind into v_tk from public.stock_locations where id = p_to;
  v_expect := case v_fk when 'customer' then 'sold' when 'supplier' then 'returned' when 'loss' then 'written_off' else 'in_stock' end;
  v_state := case v_tk when 'customer' then 'sold' when 'supplier' then 'returned' when 'loss' then 'written_off' else 'in_stock' end;
  for u in select value from jsonb_array_elements(v_units) loop
    v_code := public.stock_tag_normalize(u ->> 'tag');
    begin
      v_pid := nullif(u ->> 'piece_id', '')::uuid;
    exception when others then
      perform public.stock_config_refuse('units', 'malformed');
    end;
    if v_pid is null and v_code is not null then
      select t.piece_id into v_pid from public.stock_tags t
       where t.workspace_id = p_workspace_id and t.code = v_code and t.state = 'active' and t.owner_kind = 'piece';
    end if;
    if v_pid is not null then
      select * into pc from public.stock_tagged_units where id = v_pid and workspace_id = p_workspace_id for update;
      if pc.id is null or pc.item_id <> p_item_id or pc.variant_id is distinct from p_variant or pc.lot_id is distinct from p_lot
         or pc.location_id <> p_from or pc.state <> v_expect or v_pid = any (v_ids) then
        raise exception 'a named piece is not where this movement takes it from' using errcode = 'DKG26';
      end if;
      update public.stock_tagged_units set location_id = p_to, state = v_state where id = pc.id;
      v_ids := v_ids || pc.id;
    else
      -- a piece from outside: made at the place it arrives at, with an unbound tag
      if v_code is null or v_fk not in ('supplier', 'opening', 'loss') then
        raise exception 'a named piece is not where this movement takes it from' using errcode = 'DKG26';
      end if;
      if exists (select 1 from public.stock_tags t where t.workspace_id = p_workspace_id and t.code = v_code and t.state = 'active') then
        raise exception 'tag % is already on %', v_code,
          public.stock_tag_owner_text((select t from public.stock_tags t where t.workspace_id = p_workspace_id and t.code = v_code and t.state = 'active'))
          using errcode = 'DKG22';
      end if;
      if exists (select 1 from public.stock_tags t where t.workspace_id = p_workspace_id and t.code = v_code and t.state = 'retired'
                  and t.retired_at > now() - make_interval(days => v_grace)) then
        raise exception 'tag % was retired lately and may be bound again after % days', v_code, v_grace using errcode = 'DKG23';
      end if;
      insert into public.stock_tagged_units (workspace_id, item_id, variant_id, lot_id, location_id, state)
      values (p_workspace_id, p_item_id, p_variant, p_lot, p_to, v_state) returning id into v_new;
      insert into public.stock_tags (workspace_id, code, tag_kind, owner_kind, item_id, piece_id)
      values (p_workspace_id, v_code, public.stock_tag_kind(v_code), 'piece', p_item_id, v_new);
      v_ids := v_ids || v_new;
    end if;
  end loop;
end;
$fn$;
revoke execute on function public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric) from public, anon, authenticated;

-- The pieces in stock at a place, per variant and lot, against what the ledger holds there (real places only).
create or replace function public.stock_pieces_difference(p_workspace_id uuid, p_item_id uuid, p_place uuid)
returns table (variant_id uuid, lot_id uuid, ledger numeric, pieces bigint)
language sql stable security definer set search_path = public as $fn$
  with b as (select x.variant_id, x.lot_id, sum(x.quantity) q from public.stock_balances x
              where x.workspace_id = p_workspace_id and x.item_id = p_item_id and x.location_id = p_place group by 1, 2),
       u as (select y.variant_id, y.lot_id, count(*) c from public.stock_tagged_units y
              where y.workspace_id = p_workspace_id and y.item_id = p_item_id and y.location_id = p_place and y.state = 'in_stock' group by 1, 2),
       k as (select b.variant_id, b.lot_id from b union select u.variant_id, u.lot_id from u)
  select k.variant_id, k.lot_id, coalesce(b.q, 0), coalesce(u.c, 0)
    from k
    left join b on b.variant_id is not distinct from k.variant_id and b.lot_id is not distinct from k.lot_id
    left join u on u.variant_id is not distinct from k.variant_id and u.lot_id is not distinct from k.lot_id
   where coalesce(b.q, 0) <> coalesce(u.c, 0);
$fn$;
revoke execute on function public.stock_pieces_difference(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.stock_pieces_balanced()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_place uuid;
begin
  if not public.feature_effective(new.workspace_id, 'stockTags') then
    return null;
  end if;
  if (public.item_effective_core(new.item_id) #>> '{parameters,tag_mode,value}') is distinct from 'per_unit' then
    return null;
  end if;
  foreach v_place in array array[new.from_location_id, new.to_location_id] loop
    if public.stock_place_is_virtual(v_place) then
      continue;
    end if;
    if exists (select 1 from public.stock_pieces_difference(new.workspace_id, new.item_id, v_place)) then
      raise exception 'name the pieces: this item is tracked piece by piece' using errcode = 'DKG25';
    end if;
  end loop;
  return null;
end;
$fn$;
revoke execute on function public.stock_pieces_balanced() from public, anon, authenticated;
create constraint trigger stock_pieces_balanced after insert on public.stock_movements
  deferrable initially deferred for each row execute function public.stock_pieces_balanced();

-- what differs, for a person or the doctor: [{place, variant, lot, ledger, pieces}]
create or replace function public.stock_pieces_check_v1(p_workspace_id uuid, p_item_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  l record;
  d record;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read the stock' using errcode = 'DKN01';
  end if;
  for l in select x.id, x.code from public.stock_locations x
            where x.workspace_id = p_workspace_id and not public.stock_place_is_virtual(x.id) order by x.code loop
    for d in select * from public.stock_pieces_difference(p_workspace_id, p_item_id, l.id) loop
      v_out := v_out || jsonb_build_array(jsonb_build_object('place_id', l.id, 'place', l.code, 'variant_id', d.variant_id,
                 'lot_id', d.lot_id, 'ledger', d.ledger, 'pieces', d.pieces));
    end loop;
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.stock_pieces_check_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_pieces_check_v1(uuid, uuid) to authenticated;

-- ── the one stock path hands each line to the pieces ───────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- restates 0847
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
  v_next text;
begin
  if (length(v_def) - length(replace(v_def, E'  end loop;\n  return v_out;', ''))) / length(E'  end loop;\n  return v_out;') <> 1 then
    raise exception '0887: the end of stock_apply_lines is not found exactly once' using errcode = 'P0001';
  end if;
  v_next := replace(v_def, E'  end loop;\n  return v_out;',
    E'    perform public.stock_pieces_apply(p_workspace_id, v_item.id, v_var, v_lot, e, v_from.id, v_to.id, p_reason, v_qty);\n  end loop;\n  return v_out;');
  execute v_next;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(887);
