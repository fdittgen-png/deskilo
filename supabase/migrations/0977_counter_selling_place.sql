-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one column, one setting, new functions; counter_goods_parts and counter_item_lots_v1 gain a defaulted parameter, so a
-- call with the old arguments still answers; counter_receipt_finalize_v1 and counter_goods_return_v1 restated whole from
-- their live definitions)
--
-- #4492 (row 11, D1) -- the till sells from the selling place. Until now a counter sale took goods from the place whose
-- code is MAIN and from nowhere else: goods put on a shelf place were refused at the till. Now:
--
--   * A till has a SELLING PLACE: `counter_tills.selling_place_id`, set with the till (counter_till_save_v2). A till
--     that names none, and a counter without till sessions, sell from the place the business names by its code in the
--     setting `counter.selling_place` (default MAIN). `counter_selling_place(workspace, till)` is the one rule; the
--     sale, the lots the till offers, a returned deposit and goods taken back all read it.
--   * A sale draws from the selling place AND EVERY PLACE IN USE BELOW IT (stock_place_tree, as the invoice path's main
--     store already does): a lot-tracked item from the lot that expires first wherever it lies in that tree, never an
--     expired one; a named lot, an untracked item and named pieces from the places that hold them, the selling place
--     itself first. What the tree does not hold is asked of the selling place itself, so the stock path answers a
--     shortage exactly as before (refused, or below zero where the business allows it for an untracked item).
--     Over several places only what lies loose is planned: goods packed in a handling unit at one place never refuse
--     a sale another place can serve.
--     A place outside the tree -- a back store beside it -- is never sold from.
--   * A line that names its place (`from_location_id`) leaves from that place alone, as before.
--   * A returned deposit comes back to the selling place itself; goods taken back after a correction go to the selling
--     place of the till that sold them (was: MAIN), unless the line names a place.
--
-- A business that set nothing: the selling place is MAIN, as before. What changes for it is the tree: goods lying at
-- a place below MAIN are now sold from as well (they were refused, or MAIN went below zero), and of two lots the one
-- that expires first is drawn wherever it lies under MAIN. With nothing below MAIN a sale posts what it posted.
--
-- An app of the last release goes on working: it calls counter_till_save_v1 (which leaves a till's selling place as it
-- is) and counter_item_lots_v1 without a till (the lots at the business's selling place).

-- audience: all row readers
alter table public.counter_tills add column if not exists selling_place_id uuid;
alter table public.counter_tills drop constraint if exists counter_tills_selling_place_fk;
alter table public.counter_tills add constraint counter_tills_selling_place_fk
  foreign key (workspace_id, selling_place_id) references public.stock_locations (workspace_id, id);
comment on column public.counter_tills.selling_place_id is
  'The place this till sells from, with every place below it. Null: the business''s selling place (counter.selling_place, default MAIN).';

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('counter.selling_place', 'text', '"MAIN"'::jsonb, null, 40, 'place code', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'the till sells from the selling place (#4492)', 'The code of the place a till sells from when the till names none of its own, for example MAIN (the main store) or the code of the shop floor. A sale takes goods from this place and from every place below it, the first to expire first; a place outside it, such as a back store, is not sold from. A code that is no place of the business refuses a sale of goods until it is corrected.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the one rule: where a till sells from ────────────────────────────────────────────────────────────────────────────────
-- the till's own place when it names one; else the place the business names by its code (default MAIN). Null when the
-- code is no place of the business: the caller refuses, it never falls back to another place.
create or replace function public.counter_selling_place(p_workspace_id uuid, p_till_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_place uuid;
  v_code text;
begin
  if p_till_id is not null then
    select t.selling_place_id into v_place from public.counter_tills t
     where t.id = p_till_id and t.workspace_id = p_workspace_id;
    if v_place is not null then
      return v_place;
    end if;
  end if;
  v_code := coalesce(nullif(btrim(public.setting_value(p_workspace_id, 'counter.selling_place') #>> '{}'), ''), 'MAIN');
  select sl.id into v_place from public.stock_locations sl
   where sl.workspace_id = p_workspace_id and sl.code = v_code
   order by sl.created_datetime, sl.id limit 1;
  return v_place;
end
$fn$;
revoke execute on function public.counter_selling_place(uuid, uuid) from public, anon, authenticated;

-- a place a till may sell from: a place of the business that holds stock and is in use
create or replace function public.counter_selling_place_ok(p_workspace_id uuid, p_place_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.stock_locations sl
                  where sl.id = p_place_id and sl.workspace_id = p_workspace_id and sl.active
                    and sl.kind <> 'in_transit' and not public.stock_place_is_virtual(sl.id))
$fn$;
revoke execute on function public.counter_selling_place_ok(uuid, uuid) from public, anon, authenticated;

-- ── the till, saved with its selling place ───────────────────────────────────────────────────────────────────────────────
-- counter_till_save_v1 (0907) with one argument more; v1 stays for the apps that call it and leaves the selling place of
-- a till as it is. Here the place is part of what is saved: null puts the till back on the business's selling place.
create or replace function public.counter_till_save_v2(
  p_workspace_id uuid, p_request_id uuid, p_till_id uuid, p_name text, p_site_id uuid, p_active boolean, p_selling_place_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_till public.counter_tills;
  v_result jsonb;
begin
  v_me := public.counter_till_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageSites') then
    raise exception 'not allowed to manage the tills' using errcode = 'DKN01';
  end if;
  if p_request_id is null or char_length(btrim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'a till has a name' using errcode = '22023';
  end if;
  if p_site_id is not null and not exists (select 1 from public.sites s where s.id = p_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'not a site of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'site_unknown')::text;
  end if;
  -- the place a till already has is saved as it was read, whatever became of the place since; a new one is a place that
  -- holds stock and is in use
  if p_selling_place_id is not null
     and not exists (select 1 from public.counter_tills t
                      where t.id = p_till_id and t.workspace_id = p_workspace_id and t.selling_place_id = p_selling_place_id)
     and not public.counter_selling_place_ok(p_workspace_id, p_selling_place_id) then
    raise exception 'not a place this business can sell from' using errcode = 'DKL12',
      detail = jsonb_build_object('reason', 'selling_place_unknown')::text;
  end if;
  v_digest := md5(coalesce(p_till_id::text, '') || '|' || btrim(p_name) || '|' || coalesce(p_site_id::text, '') || '|' || coalesce(p_active, true)::text
                  || '|' || coalesce(p_selling_place_id::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_till_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  begin
  if p_till_id is null then
    insert into public.counter_tills (workspace_id, site_id, name, active, selling_place_id)
    values (p_workspace_id, p_site_id, btrim(p_name), coalesce(p_active, true), p_selling_place_id) returning * into v_till;
  else
    update public.counter_tills set name = btrim(p_name), site_id = p_site_id, active = coalesce(p_active, true), selling_place_id = p_selling_place_id
     where id = p_till_id and workspace_id = p_workspace_id returning * into v_till;
    if v_till.id is null then
      raise exception 'not a till of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'till_unknown')::text;
    end if;
    if not v_till.active and exists (select 1 from public.counter_till_sessions s where s.till_id = v_till.id and s.state = 'open') then
      raise exception 'a till with an open session is closed before it is switched off' using errcode = 'DKL12',
        detail = jsonb_build_object('reason', 'already_open', 'till_id', v_till.id)::text;
    end if;
  end if;
  exception when unique_violation then
    raise exception 'a till of this business already has this name' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'name_taken')::text;
  end;
  v_result := jsonb_build_object('till_id', v_till.id, 'name', v_till.name, 'active', v_till.active, 'site_id', v_till.site_id,
    'selling_place_id', v_till.selling_place_id, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_till_save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_till_save_v2(uuid, uuid, uuid, text, uuid, boolean, uuid) from public, anon;
grant execute on function public.counter_till_save_v2(uuid, uuid, uuid, text, uuid, boolean, uuid) to authenticated;

-- the places a till may be given, and the one the business sells from when a till names none; read by whoever manages
-- the tills, without the stock rights
create or replace function public.counter_selling_places_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_default uuid;
begin
  perform public.counter_till_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'manageSites') then
    raise exception 'not allowed to manage the tills' using errcode = 'DKN01';
  end if;
  v_default := public.counter_selling_place(p_workspace_id, null);
  return jsonb_build_object(
    'default_code', coalesce(nullif(btrim(public.setting_value(p_workspace_id, 'counter.selling_place') #>> '{}'), ''), 'MAIN'),
    'default_place_id', v_default,
    'places', coalesce((
      select jsonb_agg(jsonb_build_object('id', sl.id, 'code', sl.code, 'name', sl.name,
                                          'path', to_jsonb(string_to_array(sl.address_path, chr(31))))
                       order by sl.address_path, sl.id)
        from public.stock_locations sl
       where sl.workspace_id = p_workspace_id and public.counter_selling_place_ok(p_workspace_id, sl.id)), '[]'::jsonb));
end
$fn$;
revoke execute on function public.counter_selling_places_v1(uuid) from public, anon;
grant execute on function public.counter_selling_places_v1(uuid) to authenticated;

-- ── the parts a goods line leaves in, over the selling place and the places below it ─────────────────────────────────────
-- restates 0947 (counter_goods_parts, its live definition), with one parameter more: [p_below] plans over [p_from] and
-- every place in use below it, [p_from] itself first. Each part then names the place it leaves (`from`), and what the
-- sale already takes is kept per place and lot ("<place>:<lot>", "<place>:-" without a lot). Without [p_below], or with
-- nothing below [p_from], the answer is the one 0947 gave.
drop function if exists public.counter_goods_parts(uuid, uuid, uuid, uuid, text, text, jsonb, jsonb);
-- restates 0947
create or replace function public.counter_goods_parts(
  p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_from uuid, p_quantity text, p_unit text, p_input jsonb,
  p_taken jsonb default '{}'::jsonb, p_below boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_item public.services;
  v_units jsonb := p_input -> 'units';
  v_named boolean := nullif(p_input ->> 'lot_id', '') is not null;
  v_lot uuid;
  v_qty numeric;
  v_left numeric;
  v_take numeric;
  v_entered numeric;
  v_unit text;
  v_expired numeric;
  v_parts jsonb := '[]'::jsonb;
  v_today date := public.workspace_today(p_workspace_id);
  -- the places the line may leave from, [p_from] first
  v_places uuid[] := array[p_from];
  v_plan jsonb := '[]'::jsonb;
  b record;
begin
  select * into v_item from public.services where id = p_item_id and workspace_id = p_workspace_id;
  if p_below then
    v_places := array(select t.id from public.stock_place_tree(p_workspace_id, p_from) with ordinality t (id, depth, ord) order by t.ord);
    if cardinality(v_places) = 0 then
      v_places := array[p_from];
    end if;
  end if;
  -- as before: the line as it was named, for the stock path to check
  if v_item.id is null or (coalesce(jsonb_typeof(v_units), '') <> 'array' and (v_named or v_item.tracking = 'none'))
     or coalesce(p_quantity, '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' then
    v_lot := case when coalesce(p_input ->> 'lot_id', '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
                  then (p_input ->> 'lot_id')::uuid end;
    -- a named lot counts for the next line as what it takes, when its unit is one of the item's; over several places
    -- an untracked item is counted too
    if v_item.id is not null and (v_lot is not null or (cardinality(v_places) > 1 and not v_named))
       and coalesce(p_quantity, '') ~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' then
      begin
        v_qty := public.stock_to_inventory(p_item_id, p_unit, p_quantity::numeric);
      exception when sqlstate 'DKG02' then
        v_qty := null;
      end;
    end if;
    -- over several places: from the places that hold it loose (what is packed in a unit is not taken loose), [p_from]
    -- first, less what this sale already takes there
    if cardinality(v_places) > 1 and coalesce(v_qty, 0) > 0 then
      v_left := v_qty;
      for b in
        select pl.id as place,
               coalesce((select sum(greatest(public.stock_hu_loose(p_workspace_id, p_item_id, p_variant_id, s.lot_id, pl.id), 0))
                           from public.stock_balances s
                          where s.workspace_id = p_workspace_id and s.item_id = p_item_id
                            and s.variant_id is not distinct from p_variant_id and s.location_id = pl.id and s.quantity > 0
                            and (v_lot is null or s.lot_id = v_lot)), 0)
               - coalesce((p_taken ->> (pl.id::text || ':' || coalesce(v_lot::text, '-')))::numeric, 0) as quantity
          from unnest(v_places) with ordinality pl (id, ord)
         order by pl.ord
      loop
        exit when v_left <= 0;
        continue when b.quantity <= 0;
        v_take := least(b.quantity, v_left);
        v_left := v_left - v_take;
        v_plan := v_plan || jsonb_build_array(jsonb_build_object('from', b.place, 'take', v_take));
      end loop;
      -- what no place here holds is asked of [p_from] itself: the stock path answers a shortage as it always did
      if v_left > 0 then
        if v_plan #>> '{0,from}' = p_from::text then
          v_plan := jsonb_set(v_plan, '{0,take}', to_jsonb((v_plan #>> '{0,take}')::numeric + v_left));
        else
          v_plan := jsonb_build_array(jsonb_build_object('from', p_from, 'take', v_left)) || v_plan;
        end if;
      end if;
      for b in select (x.e ->> 'from')::uuid as place, (x.e ->> 'take')::numeric as take
                 from jsonb_array_elements(v_plan) with ordinality x (e, ord) order by x.ord loop
        -- the sale unit, as below: the whole line from one place is the line as entered
        if b.take = v_qty then
          v_entered := p_quantity::numeric;
          v_unit := p_unit;
        else
          v_entered := round(b.take / public.stock_to_inventory(p_item_id, p_unit, 1), 6);
          v_unit := p_unit;
          if v_entered <= 0 or public.stock_to_inventory(p_item_id, p_unit, v_entered) <> b.take then
            v_entered := b.take;
            v_unit := v_item.inventory_unit;
          end if;
        end if;
        v_parts := v_parts || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
          'quantity', trim_scale(v_entered)::text, 'unit', v_unit, 'lot_id', nullif(p_input ->> 'lot_id', ''),
          'from', b.place, 'taken', trim_scale(b.take)::text)));
      end loop;
      return v_parts;
    end if;
    return jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'quantity', p_quantity, 'unit', p_unit, 'lot_id', nullif(p_input ->> 'lot_id', ''), 'units', v_units,
      'taken', case when v_lot is not null then trim_scale(v_qty)::text end)));
  end if;
  v_qty := public.stock_to_inventory(p_item_id, p_unit, p_quantity::numeric);
  if jsonb_typeof(v_units) = 'array' then
    if jsonb_array_length(v_units) <> v_qty then
      raise exception 'name the pieces: % named for a quantity of %', jsonb_array_length(v_units), trim_scale(v_qty)
        using errcode = 'DKG25';
    end if;
    v_lot := case when coalesce(p_input ->> 'lot_id', '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
                  then (p_input ->> 'lot_id')::uuid end;
    -- each piece goes with its own lot (a lot the line names wins, and the stock path checks it) and, over several
    -- places, from the place it lies at when that is one of them
    select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'quantity', g.n::text, 'unit', v_item.inventory_unit, 'lot_id', g.lot, 'units', g.units, 'taken', g.n::text,
             'from', case when cardinality(v_places) > 1 then g.place end))
             order by g.first), '[]'::jsonb)
      into v_parts
      from (select p.lot, p.place, count(*) n, jsonb_agg(p.u order by p.ord) units, min(p.ord) first
              from (select x.u, x.ord, coalesce(v_lot, pc.lot_id) lot,
                           case when pc.location_id = any (v_places) then pc.location_id else p_from end place
                      from jsonb_array_elements(v_units) with ordinality x (u, ord)
                      left join lateral (
                        select q.lot_id, q.location_id from public.stock_tagged_units q
                         where q.workspace_id = p_workspace_id and q.id::text = lower(coalesce(x.u ->> 'piece_id', ''))
                        union all
                        select q.lot_id, q.location_id from public.stock_tags t join public.stock_tagged_units q on q.id = t.piece_id
                         where t.workspace_id = p_workspace_id and t.owner_kind = 'piece' and t.state = 'active'
                           and coalesce(x.u ->> 'piece_id', '') = ''
                           and t.code = public.stock_tag_normalize(x.u ->> 'tag')
                        limit 1) pc on true) p
             group by p.lot, p.place) g;
    return v_parts;
  end if;
  -- a lot-tracked item, no lot named: the lots on hand at these places less what this sale already takes, the first to
  -- expire first wherever it lies, [p_from] before the places below it
  v_left := v_qty;
  for b in
    select s.lot_id, s.location_id as place,
           -- over several places only what lies loose is planned: a unit packed at one of them never refuses a sale
           -- another place can serve; at one place alone the balance, as before
           case when cardinality(v_places) > 1
                then public.stock_hu_loose(p_workspace_id, p_item_id, p_variant_id, s.lot_id, s.location_id)
                else s.quantity end
           - coalesce((p_taken ->> (s.location_id::text || ':' || s.lot_id::text))::numeric, 0) quantity
      from public.stock_balances s
      join public.stock_lots l on l.id = s.lot_id
      join unnest(v_places) with ordinality pl (id, ord) on pl.id = s.location_id
     where s.workspace_id = p_workspace_id and s.item_id = p_item_id and s.variant_id is not distinct from p_variant_id
       and s.quantity > 0 and not public.stock_lot_expired(l.id, v_today)
     order by l.expires_on nulls last, l.created_datetime, l.id, pl.ord
  loop
    exit when v_left <= 0;
    continue when b.quantity <= 0;
    v_take := least(b.quantity, v_left);
    v_left := v_left - v_take;
    -- the sale unit: the whole line from one lot is the line as entered; a part is entered in the sale unit when it is
    -- an exact quantity of it, else in the inventory unit
    if v_take = v_qty then
      v_entered := p_quantity::numeric;
      v_unit := p_unit;
    else
      v_entered := round(v_take / public.stock_to_inventory(p_item_id, p_unit, 1), 6);
      v_unit := p_unit;
      if v_entered <= 0 or public.stock_to_inventory(p_item_id, p_unit, v_entered) <> v_take then
        v_entered := v_take;
        v_unit := v_item.inventory_unit;
      end if;
    end if;
    v_parts := v_parts || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'quantity', trim_scale(v_entered)::text, 'unit', v_unit, 'lot_id', b.lot_id, 'taken', trim_scale(v_take)::text,
      'from', case when cardinality(v_places) > 1 then b.place end)));
  end loop;
  if v_left > 0 then
    -- what is past its date here, less what this sale already takes of it (nothing: an expired lot is never planned)
    select coalesce(sum(s.quantity), 0) into v_expired
      from public.stock_balances s
      join public.stock_lots l on l.id = s.lot_id
     where s.workspace_id = p_workspace_id and s.item_id = p_item_id and s.variant_id is not distinct from p_variant_id
       and s.location_id = any (v_places) and s.quantity > 0 and public.stock_lot_expired(l.id, v_today);
    raise exception 'not that much on hand at this place' using errcode = 'DKG03',
      detail = jsonb_build_object('scope', 'lots', 'reason', case when v_expired > 0 then 'expired' else 'not_enough' end,
        'item_id', p_item_id, 'asked', trim_scale(v_qty)::text, 'held', trim_scale(v_qty - v_left)::text,
        'expired', trim_scale(v_expired)::text)::text;
  end if;
  return v_parts;
end;
$fn$;
revoke execute on function public.counter_goods_parts(uuid, uuid, uuid, uuid, text, text, jsonb, jsonb, boolean) from public, anon, authenticated;

-- ── finalize: the goods leave from the selling place of the receipt's till ───────────────────────────────────────────────
-- restates counter_receipt_finalize_v1 whole from its live definition (0947 as patched by 0973: the replay's body, digest
-- ef62bdcefa83 in the contract). Changed: the place a goods line leaves from and a returned deposit comes back to is the
-- selling place of the till of the receipt's session; a line that names no place is planned over that place and the
-- places below it, each part leaving from its own place.
-- restates 0947
create or replace function public.counter_receipt_finalize_v1(
  p_workspace_id uuid, p_request_id uuid, p_receipt_id uuid, p_expected_revision int, p_tenders jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_rec public.counter_receipts;
  v_op public.counter_country_operations;
  v_regime text;
  v_tp date;
  v_input jsonb := '[]'::jsonb;
  l public.counter_receipt_lines;
  v_calc jsonb;
  v_total bigint;
  v_tax bigint;
  v_net bigint;
  v_number text;
  v_frozen jsonb;
  v_breakdown jsonb;
  v_t jsonb;
  v_sum bigint := 0;
  v_part int := 0;
  v_amount bigint;
  v_kind text;
  v_other public.counter_receipts;
  v_result jsonb;
  r jsonb;
  v_no int := 0;
  v_named uuid[];
  v_tender public.counter_tenders;
  v_goods jsonb;
  v_back jsonb := '[]'::jsonb;
  v_main uuid;
  v_sess public.counter_till_sessions;
  v_gno int;
  v_line_id uuid;
  p jsonb;
  v_tracks jsonb := '[]'::jsonb;
  v_items uuid[];
  v_taken jsonb := '{}'::jsonb;
  v_key text;
  v_till uuid;
  v_below boolean;
  v_place uuid;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or p_receipt_id is null or coalesce(jsonb_typeof(p_tenders), '') <> 'array' then
    -- #4436: refused with the counter's code for a receipt that misses its essentials (was a bare 22023)
    perform public.refuse('DKL02', null, 'a receipt is finalized with a request id, its revision and its tenders');
  end if;
  v_digest := md5(p_receipt_id::text || '|' || coalesce(p_expected_revision::text, '') || '|' || p_tenders::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_finalize', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_rec from public.counter_receipts x where x.id = p_receipt_id and x.workspace_id = p_workspace_id for update;
  if v_rec.id is null or v_rec.state <> 'draft' or v_rec.kind <> 'sale' then
    raise exception 'this receipt is not an open draft' using errcode = 'DKL04';
  end if;
  if p_expected_revision is distinct from v_rec.revision then
    raise exception 'this receipt changed meanwhile' using errcode = 'DKL10';
  end if;
  -- the session of the sale, share-locked: a close (for update) waits for this transaction, and a session closed first refuses it
  if public.feature_effective(p_workspace_id, 'counterTillSessions') then
    select * into v_sess from public.counter_till_sessions s where s.id = v_rec.till_session_id for share;
    if v_sess.id is null or v_sess.state <> 'open' then
      raise exception 'open the till first' using errcode = 'DKL12',
        detail = jsonb_build_object('reason', case when v_sess.id is null then 'till_open_first' else 'closed' end, 'till_id', v_sess.till_id)::text;
    end if;
  end if;
  -- the country operation first: nothing is numbered and nothing is taken where it is not supported
  v_op := public.counter_require_operation(p_workspace_id, 'issue_receipt');
  if jsonb_array_length(p_tenders) > 0 then
    perform public.counter_require_operation(p_workspace_id, 'reconcile_tender');
  end if;
  if v_rec.financial_subject_id is null and coalesce(public.setting_value(p_workspace_id, 'counter.customerless_sales') #>> '{}', 'allowed') = 'refused' then
    raise exception 'this business names a customer on every sale' using errcode = 'DKL05';
  end if;
  if v_rec.source_ref <> '' then
    select * into v_other from public.counter_receipts o
     where o.workspace_id = p_workspace_id and o.source_kind = v_rec.source_kind and o.source_ref = v_rec.source_ref
       and o.state = 'finalized' and o.kind = 'sale';
    if v_other.id is not null then
      raise exception 'a receipt was already issued for this source' using errcode = 'DKL04',
        detail = jsonb_build_object('receipt_id', v_other.id, 'number', v_other.number)::text;
    end if;
  end if;
  v_tp := public.workspace_today(p_workspace_id);
  for l in select * from public.counter_receipt_lines x where x.receipt_id = v_rec.id order by x.line_no loop
    v_input := v_input || jsonb_build_array(l.frozen -> 'input');
  end loop;
  v_calc := public.counter_lines_of(p_workspace_id, v_input, v_rec.currency, v_rec.price_basis, v_tp);
  if jsonb_array_length(v_calc -> 'missing') > 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKL02',
      detail = (select string_agg(x, ',') from jsonb_array_elements_text(v_calc -> 'missing') x);
  end if;
  v_total := (v_calc #>> '{totals,gross_minor}')::bigint;
  v_tax := (v_calc #>> '{totals,tax_minor}')::bigint;
  v_net := (v_calc #>> '{totals,net_minor}')::bigint;
  if v_total <= 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKL02', detail = 'total_not_positive';
  end if;
  -- #4478: a returned deposit taxed where the sale is not can make the tax negative; never beyond the total either way
  if abs(v_tax) > v_total then
    raise exception 'receipt_essentials_missing' using errcode = 'DKL02', detail = 'tax_beyond_total';
  end if;
  -- the tenders: the cash and other ones named here, each of its own part, and the card ones already accepted on this
  -- receipt (named by id), adding to the total exactly; an authorization still open (requested or unknown) is never
  -- passed over, a refused one is not paid
  if exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id
                and (t.state in ('requested', 'unknown') or (t.state = 'accepted' and t.reconciliation = 'needed'))) then
    raise exception 'a card authorization of this sale is still open' using errcode = 'DKL06', detail = 'tender_open';
  end if;
  if jsonb_array_length(p_tenders) = 0 and not exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'accepted') then
    raise exception 'a sale is settled by its tenders' using errcode = 'DKL06', detail = 'tenders_missing';
  end if;
  v_named := array[]::uuid[];
  for v_t in select value from jsonb_array_elements(p_tenders) loop
    if v_t ? 'tender_id' then
      select * into v_tender from public.counter_tenders t
       where t.id = nullif(v_t ->> 'tender_id', '')::uuid and t.receipt_id = v_rec.id and t.workspace_id = p_workspace_id;
      if v_tender.id is null or v_tender.kind <> 'card' or v_tender.state <> 'accepted' or v_tender.reconciliation = 'needed' or v_tender.id = any (v_named) then
        raise exception 'this tender is not an accepted card tender of this sale' using errcode = 'DKL06', detail = 'tender_state';
      end if;
      v_named := v_named || v_tender.id;
      v_sum := v_sum + v_tender.amount_minor;
      continue;
    end if;
    v_kind := v_t ->> 'kind';
    if v_kind is null or v_kind not in ('cash', 'other') then
      raise exception 'this tender is not taken here' using errcode = 'DKL06', detail = 'tender_kind';
    end if;
    if coalesce(v_t ->> 'amount_minor', '') !~ '^[0-9]{1,12}$' or (v_t ->> 'amount_minor')::bigint <= 0 then
      raise exception 'this tender has no amount' using errcode = 'DKL06', detail = 'tender_amount';
    end if;
    v_sum := v_sum + (v_t ->> 'amount_minor')::bigint;
  end loop;
  -- an accepted card tender of this receipt that the caller did not name is still money taken: it counts
  v_sum := v_sum + coalesce((select sum(t.amount_minor) from public.counter_tenders t
                              where t.receipt_id = v_rec.id and t.state = 'accepted' and not (t.id = any (v_named))), 0);
  if v_sum <> v_total then
    raise exception 'the tenders do not add up to the total' using errcode = 'DKL06', detail = 'tender_sum';
  end if;
  -- everything is accepted: now the number
  v_number := public.next_document_number(p_workspace_id, 'receipt');
  select coalesce(jsonb_agg(jsonb_build_object('percent', g.pct, 'category', g.cat, 'gross_minor', g.gross::text,
                                               'net_minor', g.net::text, 'tax_minor', (g.gross - g.net)::text) order by g.pct desc, g.cat), '[]'::jsonb)
    into v_breakdown
    from (select (x #>> '{line,vat_percent}')::numeric pct, x #>> '{line,vat_category}' cat,
                 sum((x #>> '{line,commercial,amounts,gross_minor}')::bigint) gross,
                 sum((x #>> '{line,commercial,amounts,net_minor}')::bigint) net
            from jsonb_array_elements(v_calc -> 'lines') x group by 1, 2) g;
  v_regime := coalesce(public.setting_value(p_workspace_id, 'counter.fiscal_obligation') #>> '{}', 'register_required');
  v_frozen := jsonb_build_object(
    'version', 1, 'number', v_number, 'currency', v_rec.currency, 'price_basis', v_rec.price_basis,
    'issued_at', now(), 'tax_point', v_tp,
    'lines', (select jsonb_agg(x -> 'line') from jsonb_array_elements(v_calc -> 'lines') x),
    'totals', v_calc -> 'totals', 'tax_breakdown', v_breakdown,
    'source', jsonb_build_object('kind', v_rec.source_kind, 'ref', v_rec.source_ref),
    'financial_subject_id', v_rec.financial_subject_id,
    'operation', jsonb_build_object('country', v_op.country_code, 'operation', v_op.operation, 'regime', v_op.regime,
      'specification', v_op.specification, 'specification_version', v_op.specification_version,
      'effective_from', v_op.effective_from, 'adapter', v_op.adapter, 'confirmed', v_op.confirmed),
    'corrects', null);
  for r in select value from jsonb_array_elements(v_calc -> 'lines') loop
    v_no := v_no + 1;
    update public.counter_receipt_lines set frozen = (r -> 'line') || jsonb_build_object('input', r -> 'input'),
           net_minor = (r #>> '{line,commercial,amounts,net_minor}')::bigint, tax_minor = (r #>> '{line,commercial,amounts,tax_minor}')::bigint,
           gross_minor = (r #>> '{line,commercial,amounts,gross_minor}')::bigint, quantity = (r #>> '{line,commercial,quantity}')::numeric
     where receipt_id = v_rec.id and line_no = v_no;
  end loop;
  select coalesce(max(t.part), 0) into v_part from public.counter_tenders t where t.receipt_id = v_rec.id;
  for v_t in select value from jsonb_array_elements(p_tenders) loop
    if v_t ? 'tender_id' then continue; end if;
    v_part := v_part + 1;
    insert into public.counter_tenders (workspace_id, receipt_id, part, kind, amount_minor, state, request_id, resolved_at, recorded_by_member_id)
    values (p_workspace_id, v_rec.id, v_part, v_t ->> 'kind', (v_t ->> 'amount_minor')::bigint, 'accepted', p_request_id, now(), v_me);
  end loop;
  -- goods: the movements of each goods line through the one stock path, in this transaction and under this request id,
  -- linked to this receipt and to the line: a line that cannot leave (not enough, expired, a variant, a lot or the pieces
  -- to name) rolls the whole sale back, number included; issuing the receipt moves nothing else, and a replay answers
  -- without moving anything again. #4436: a lot-tracked line without a lot leaves from the lots on hand, one movement per lot.
  v_goods := '[]'::jsonb;
  v_gno := 0;
  -- the place this sale takes from is its till's: the session of the receipt names the till; a receipt without a
  -- session sells from the business's selling place
  select s.till_id into v_till from public.counter_till_sessions s where s.id = v_rec.till_session_id;
  -- the goods items are locked BEFORE their lots are planned, in id order as the stock path locks them (0847): a sale on
  -- another till waits here, then plans from what the first one left, and two tills never draw the same lot twice
  v_items := array(select distinct (x ->> 'item_id')::uuid from jsonb_array_elements(v_calc -> 'lines') x
                    where x #>> '{line,supply}' = 'goods'
                      and coalesce(x ->> 'item_id', '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  perform 1 from public.services where id = any (v_items) and workspace_id = p_workspace_id order by id for update;
  for r in select value from jsonb_array_elements(v_calc -> 'lines') loop
    v_gno := v_gno + 1;
    -- a returned deposit comes back into stock, from the customer to the selling place itself
    if r #>> '{line,supply}' = 'goods' and r #>> '{line,kind}' = 'deposit_return' then
      if not public.feature_effective(p_workspace_id, 'stockManagement') then
        raise exception 'goods are not sold here: the goods ledger is off' using errcode = 'DKL07', detail = 'goods_off';
      end if;
      v_main := coalesce(nullif(r #>> '{input,from_location_id}', '')::uuid, public.counter_selling_place(p_workspace_id, v_till));
      if v_main is null then
        raise exception 'no place to take the goods back to' using errcode = 'DKL07', detail = 'from_place';
      end if;
      select x.id into v_line_id from public.counter_receipt_lines x where x.receipt_id = v_rec.id and x.line_no = v_gno;
      v_back := v_back || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'item_id', r ->> 'item_id', 'quantity', r #>> '{line,commercial,quantity}', 'unit', r #>> '{line,commercial,unit,code}',
        'from', public.stock_place(p_workspace_id, 'customer'), 'to', v_main, 'counter_line_id', v_line_id)));
    elsif r #>> '{line,supply}' = 'goods' then
      if not public.feature_effective(p_workspace_id, 'stockManagement') then
        raise exception 'goods are not sold here: the goods ledger is off' using errcode = 'DKL07', detail = 'goods_off';
      end if;
      v_main := coalesce(nullif(r #>> '{input,from_location_id}', '')::uuid, public.counter_selling_place(p_workspace_id, v_till));
      if v_main is null then
        raise exception 'no place to take the goods from' using errcode = 'DKL07', detail = 'from_place';
      end if;
      select x.id into v_line_id from public.counter_receipt_lines x where x.receipt_id = v_rec.id and x.line_no = v_gno;
      -- a line that names its place leaves from that place alone; any other from the selling place and every place
      -- below it. What the earlier lines of this sale already take at each place is planned around, not drawn twice
      v_below := nullif(r #>> '{input,from_location_id}', '') is null;
      for p in select value from jsonb_array_elements(public.counter_goods_parts(p_workspace_id, (r ->> 'item_id')::uuid,
                 nullif(r #>> '{input,variant_id}', '')::uuid, v_main, r #>> '{line,commercial,quantity}',
                 r #>> '{line,commercial,unit,code}', r -> 'input', v_taken, v_below)) loop
        v_place := coalesce(nullif(p ->> 'from', '')::uuid, v_main);
        if p ? 'taken' then
          v_key := v_place::text || ':' || coalesce(p ->> 'lot_id', '-');
          v_taken := v_taken || jsonb_build_object(v_key, (coalesce((v_taken ->> v_key)::numeric, 0) + (p ->> 'taken')::numeric)::text);
        end if;
        v_goods := v_goods || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
          'item_id', r ->> 'item_id', 'variant_id', nullif(r #>> '{input,variant_id}', ''),
          'quantity', p ->> 'quantity', 'unit', p ->> 'unit',
          'from', v_place, 'to', public.stock_place(p_workspace_id, 'customer'), 'lot_id', p ->> 'lot_id',
          'units', p -> 'units', 'counter_line_id', v_line_id)));
      end loop;
    end if;
  end loop;
  -- #4478: under a request id of their own, derived from the sale's: a movement is keyed by its request and line
  if jsonb_array_length(v_back) > 0 then
    perform set_config('deskilo.counter_links', 'on', true);
    perform public.stock_apply_lines(p_workspace_id, v_me, md5(p_request_id::text || ':deposit_return')::uuid, v_back, 'return_in', now(),
                                     jsonb_build_object('counter_receipt_id', v_rec.id), 'generic');
    perform set_config('deskilo.counter_links', 'off', true);
  end if;
  if jsonb_array_length(v_goods) > 0 then
    perform set_config('deskilo.counter_links', 'on', true);
    perform public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_goods, 'sale', now(),
                                     jsonb_build_object('counter_receipt_id', v_rec.id), 'generic');
    perform set_config('deskilo.counter_links', 'off', true);
    -- #4436: what each goods line took, frozen with it while the receipt is still a draft
    for l in select * from public.counter_receipt_lines x where x.receipt_id = v_rec.id and x.frozen ->> 'supply' = 'goods'
                       and x.frozen ->> 'kind' is distinct from 'deposit_return' order by x.line_no loop
      update public.counter_receipt_lines x
         set frozen = x.frozen || jsonb_build_object('tracks', public.stock_tracks_of(p_workspace_id,
               array(select m.id from public.stock_movements m
                      where m.workspace_id = p_workspace_id and m.counter_line_id = l.id and m.reason = 'sale')))
       where x.id = l.id
       returning * into l;
      v_tracks := v_tracks || jsonb_build_array(jsonb_build_object('line_no', l.line_no, 'line_id', l.id, 'tracks', l.frozen -> 'tracks'));
    end loop;
    v_frozen := jsonb_set(v_frozen, '{lines}',
      (select jsonb_agg(x.frozen - 'input' order by x.line_no) from public.counter_receipt_lines x where x.receipt_id = v_rec.id));
  end if;
  update public.counter_receipts set state = 'finalized', number = v_number, frozen = v_frozen, total_minor = v_total, tax_minor = v_tax,
         operation_id = v_op.id, fiscal_assumption = v_regime, finalized_by_member_id = v_me, finalized_at = now()
   where id = v_rec.id;
  v_result := jsonb_build_object('receipt_id', v_rec.id, 'number', v_number, 'currency', v_rec.currency,
    'totals', v_calc -> 'totals', 'tenders', (select count(*) from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'accepted'),
    'lines', v_tracks, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_finalize', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_receipt_finalize_v1(uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.counter_receipt_finalize_v1(uuid, uuid, uuid, int, jsonb) to authenticated;

-- ── goods taken back: to the selling place of the till that sold them ────────────────────────────────────────────────────
-- restates counter_goods_return_v1 whole from its live definition (0897 as patched by 0973, digest fdc5b32c6744)
-- restates 0897
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
    -- per line of the correction: the line's own id is in the movement's links
    select coalesce(sum(m.entered_quantity), 0) into v_back from public.stock_movements m
     where m.workspace_id = p_workspace_id and m.counter_line_id = v_line.id and m.reason = 'return_in';
    if v_qty > v_line.quantity - v_back then
      raise exception 'more is taken back than the correction credits' using errcode = 'DKL08',
        detail = jsonb_build_object('line', v_idx, 'reason', 'return_beyond', 'left', trim_scale(v_line.quantity - v_back)::text)::text;
    end if;
    v_to := coalesce(nullif(e ->> 'to_location_id', '')::uuid,
                     public.counter_selling_place(p_workspace_id,
                       (select s.till_id from public.counter_receipts o
                          join public.counter_till_sessions s on s.id = o.till_session_id
                         where o.id = v_rec.corrects_receipt_id and o.workspace_id = p_workspace_id)));
    if v_to is null then
      raise exception 'no place to put the goods back' using errcode = 'DKL07', detail = 'to_place';
    end if;
    v_move := v_move || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'item_id', v_line.item_id, 'variant_id', v_line.variant_id, 'quantity', trim_scale(v_qty)::text,
      'unit', v_line.frozen #>> '{commercial,unit,code}', 'from', public.stock_place(p_workspace_id, 'customer'), 'to', v_to,
      'counter_line_id', v_line.id)));
  end loop;
  perform set_config('deskilo.counter_links', 'on', true);
  v_moved := public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_move, 'return_in', now(),
                                      jsonb_build_object('counter_receipt_id', v_rec.id), 'generic');
  perform set_config('deskilo.counter_links', 'off', true);
  v_result := jsonb_build_object('correction_id', v_rec.id, 'movements', jsonb_array_length(v_moved), 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_goods_return', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_goods_return_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.counter_goods_return_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- ── the lots a till may sell an item from: those of its selling place and the places below it ───────────────────────────
-- restates 0967 with one parameter more: the till. Without it, the lots at the business's selling place. A lot lying at
-- several of the places is listed once, with what they hold together.
drop function if exists public.counter_item_lots_v1(uuid, uuid);
-- restates 0967
create or replace function public.counter_item_lots_v1(p_workspace_id uuid, p_item_id uuid, p_till_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_unit text;
  v_place uuid;
  v_today date := public.workspace_today(p_workspace_id);
begin
  perform public.command_actor(p_workspace_id, 'issueInvoices', 'counterReceipts', 'not allowed to work the counter',
    'counter receipts are off in this business', 'DKG01');
  select s.inventory_unit into v_unit from public.services s
   where s.id = p_item_id and s.workspace_id = p_workspace_id and s.active;
  if v_unit is null then
    perform public.refuse('DKL02', '{"reason": "item"}'::jsonb, 'no such item for sale in this business');
  end if;
  if p_till_id is not null and not exists (select 1 from public.counter_tills t where t.id = p_till_id and t.workspace_id = p_workspace_id) then
    raise exception 'not a till of this business' using errcode = 'DKL12', detail = jsonb_build_object('reason', 'till_unknown')::text;
  end if;
  v_place := public.counter_selling_place(p_workspace_id, p_till_id);
  return jsonb_build_object('unit', v_unit, 'lots', coalesce((
    select jsonb_agg(jsonb_build_object(
             'lot_id', g.id,
             'code', g.code,
             'expires_on', g.expires_on,
             'expired', g.expires_on is not null and g.expires_on < v_today,
             'quantity', trim_scale(g.quantity)::text)
           order by g.expires_on nulls last, g.lot_code, g.id)
      from (select lot.id, lot.lot_code, lot.expires_on, coalesce(nullif(lot.lot_code, ''), lot.label_code, '') as code,
                   sum(b.quantity) as quantity
              from public.stock_balances b
              join public.stock_lots lot on lot.id = b.lot_id and lot.workspace_id = p_workspace_id
             where b.workspace_id = p_workspace_id and b.item_id = p_item_id and b.quantity > 0
               and b.location_id in (select t.id from public.stock_place_tree(p_workspace_id, v_place) t)
             group by lot.id, lot.lot_code, lot.expires_on, lot.label_code) g), '[]'::jsonb));
end
$fn$;
revoke execute on function public.counter_item_lots_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.counter_item_lots_v1(uuid, uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(977);
