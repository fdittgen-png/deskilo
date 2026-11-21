-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (new columns with defaults, a new refusal family, new commands; a movement
--  now also freezes the factor it was entered with, for the rows from here on)
--
-- #4169 (A1) -- the stock configuration an operator edits from the app, not
-- from SQL: an item's stock metadata with its package units and codes, and the
-- business's places.
--
-- The contract (docs/domain/contracts/stock_operations.md):
--   * each save names the revision it read (`stock_revision` of the item,
--     `revision` of a place) and a request id: a stale revision changes
--     nothing (DKG10); the same request id with the same body answers what it
--     answered, with another body it refuses; the revision moves by one;
--   * a refusal of the content (DKG11) names the field and the reason in its
--     detail as JSON, so the screen shows it under that field;
--   * who: manageStock in the business, the feature on; viewStock only reads;
--     a manager of prices holds nothing here; a delegated assistant session
--     writes nothing; another business is none of it;
--   * an item's inventory unit and tracking stay as the first movement wrote
--     them (the 0747 guard, DKG08); a package unit's factor may change, and
--     only the movements from then on use it: every movement now freezes the
--     factor it was entered with, so an old quantity is never reinterpreted;
--   * a place is deactivated, never deleted; a place with history cannot be
--     deleted at all; the virtual places are the server's;
--   * the item is the service (`services`): nothing here edits a service's
--     name or price.

-- ── revisions and the frozen factor ─────────────────────────────────────
alter table public.services add column if not exists stock_revision int not null default 1;
alter table public.stock_locations add column if not exists revision int not null default 1;
alter table public.stock_movements
  add column if not exists entered_factor_num bigint,
  add column if not exists entered_factor_den bigint;
comment on column public.stock_movements.entered_factor_num is
  '#4169: the factor of the entered unit to the inventory unit, frozen with the movement (null before it was kept)';

-- A unit's factor to the item's inventory unit as a fraction: 1/1 for the
-- inventory unit itself, the item's own package factor, or the registry's
-- ratio for a unit of the same dimension; null where there is none.
create or replace function public.stock_unit_factor(p_item_id uuid, p_unit text)
returns table (num bigint, den bigint) language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inventory text;
  v_from public.stock_units;
  v_to public.stock_units;
begin
  select inventory_unit into v_inventory from public.services where id = p_item_id;
  if p_unit is null or p_unit = v_inventory then
    return query select 1::bigint, 1::bigint;
    return;
  end if;
  return query select u.factor_num, u.factor_den from public.item_units u
                where u.item_id = p_item_id and u.unit = p_unit;
  if found then return; end if;
  select * into v_from from public.stock_units where code = p_unit;
  select * into v_to from public.stock_units where code = v_inventory;
  if v_from.code is not null and v_to.code is not null and v_from.dimension = v_to.dimension then
    return query select v_from.factor_num * v_to.factor_den, v_from.factor_den * v_to.factor_num;
  end if;
end;
$fn$;
revoke execute on function public.stock_unit_factor(uuid, text) from public, anon, authenticated;

-- 0747's stock_record, restated whole with the two frozen columns.
create or replace function public.stock_record(
  p_workspace_id uuid, p_item_id uuid, p_lot_id uuid, p_from uuid, p_to uuid,
  p_quantity numeric, p_entered_unit text, p_entered_quantity numeric,
  p_occurred_at timestamptz, p_reason text, p_actor uuid, p_request_id uuid,
  p_line_no int, p_part int, p_links jsonb
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_cost numeric;
  v_num bigint;
  v_den bigint;
begin
  if p_lot_id is not null then
    select total_cost_minor::numeric / quantity_received into v_cost
      from public.stock_lots where id = p_lot_id;
  end if;
  select f.num, f.den into v_num, v_den from public.stock_unit_factor(p_item_id, p_entered_unit) f;
  insert into public.stock_movements
    (workspace_id, item_id, lot_id, from_location_id, to_location_id, quantity,
     entered_unit, entered_quantity, occurred_at, reason, unit_cost, actor_member_id,
     request_id, line_no, part, receipt_line_id, purchase_line_id, event_id, invoice_id,
     entered_factor_num, entered_factor_den)
  values
    (p_workspace_id, p_item_id, p_lot_id, p_from, p_to, p_quantity,
     p_entered_unit, p_entered_quantity, p_occurred_at, p_reason, v_cost, p_actor,
     p_request_id, p_line_no, p_part,
     nullif(p_links ->> 'receipt_line_id', '')::uuid, nullif(p_links ->> 'purchase_line_id', '')::uuid,
     nullif(p_links ->> 'event_id', '')::uuid, nullif(p_links ->> 'invoice_id', '')::uuid,
     v_num, v_den)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamptz, text, uuid, uuid, int, int, jsonb)
  from public, anon, authenticated;

-- A place with history is never deleted (the movements name it).
create or replace function public.stock_locations_keep_history()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if exists (select 1 from public.stock_movements m
              where old.id in (m.from_location_id, m.to_location_id))
     and exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    raise exception 'this place has stock movements, which are kept: deactivate it instead'
      using errcode = 'DKG08';
  end if;
  return old;
end;
$fn$;
revoke execute on function public.stock_locations_keep_history() from public, anon, authenticated;
drop trigger if exists stock_locations_keep_history on public.stock_locations;
create trigger stock_locations_keep_history before delete on public.stock_locations
  for each row execute function public.stock_locations_keep_history();

-- ── shared guards ───────────────────────────────────────────────────────
-- The member who writes the configuration: manageStock, the feature on, not a
-- delegated assistant session.
create or replace function public.stock_config_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to configure the stock' using errcode = 'DKN01';
  end if;
  select id into v_me from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to configure the stock' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'stock management is off' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_config_actor(uuid) from public, anon, authenticated;

-- A refusal of the content: the field and the reason, as JSON, for the screen.
create or replace function public.stock_config_refuse(p_field text, p_reason text)
returns void language plpgsql immutable set search_path = public as $fn$
begin
  raise exception 'the stock configuration is not valid: % (%)', p_field, p_reason
    using errcode = 'DKG11', detail = jsonb_build_object('field', p_field, 'reason', p_reason)::text;
end;
$fn$;
revoke execute on function public.stock_config_refuse(text, text) from public, anon, authenticated;

-- A value of the request read as a boolean, an integer or a uuid: a value
-- that is not one is a refusal of that field (DKG11, malformed), never a raw
-- cast error. Absent or null answers [p_default].
create or replace function public.stock_config_bool(p_obj jsonb, p_key text, p_field text, p_default boolean)
returns boolean language plpgsql immutable set search_path = public as $fn$
begin
  if not (p_obj ? p_key) or p_obj -> p_key = 'null'::jsonb then return p_default; end if;
  return (p_obj ->> p_key)::boolean;
exception when others then
  perform public.stock_config_refuse(p_field, 'malformed');
  return null;
end;
$fn$;
revoke execute on function public.stock_config_bool(jsonb, text, text, boolean) from public, anon, authenticated;

create or replace function public.stock_config_int(p_obj jsonb, p_key text, p_field text)
returns int language plpgsql immutable set search_path = public as $fn$
begin
  if not (p_obj ? p_key) or p_obj -> p_key = 'null'::jsonb or p_obj ->> p_key = '' then return null; end if;
  return (p_obj ->> p_key)::int;
exception when others then
  perform public.stock_config_refuse(p_field, 'malformed');
  return null;
end;
$fn$;
revoke execute on function public.stock_config_int(jsonb, text, text) from public, anon, authenticated;

create or replace function public.stock_config_uuid(p_obj jsonb, p_key text, p_field text)
returns uuid language plpgsql immutable set search_path = public as $fn$
begin
  if not (p_obj ? p_key) or p_obj -> p_key = 'null'::jsonb or p_obj ->> p_key = '' then return null; end if;
  return (p_obj ->> p_key)::uuid;
exception when others then
  perform public.stock_config_refuse(p_field, 'malformed');
  return null;
end;
$fn$;
revoke execute on function public.stock_config_uuid(jsonb, text, text) from public, anon, authenticated;

-- The check digit of a GTIN (8, 12, 13 or 14 digits).
create or replace function public.stock_gtin_valid(p_code text)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  v_n int := char_length(p_code);
  v_sum int := 0;
  i int;
begin
  if p_code !~ '^[0-9]+$' or v_n not in (8, 12, 13, 14) then return false; end if;
  for i in 1 .. v_n - 1 loop
    v_sum := v_sum + substr(p_code, v_n - i, 1)::int * case when i % 2 = 1 then 3 else 1 end;
  end loop;
  return (10 - v_sum % 10) % 10 = substr(p_code, v_n, 1)::int;
end;
$fn$;
revoke execute on function public.stock_gtin_valid(text) from public, anon, authenticated;

-- ── an item's stock metadata, its package units and its codes ───────────
-- p_item: {stockable, purchasable, sellable, inventory_unit, tracking,
--          shelf_life_days, units: [{unit, factor_num, factor_den,
--          default_purchase, default_sale}], codes: [{code, kind, unit}]}.
-- The units and the codes sent are the complete lists the item will have.
create or replace function public.save_stock_item_v1(
  p_workspace_id uuid, p_item_id uuid, p_expected_revision int, p_request_id uuid, p_item jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done public.purchase_requests;
  v_item public.services;
  v_inventory text;
  v_tracking text;
  v_shelf int;
  v_stockable boolean;
  v_units jsonb := coalesce(p_item -> 'units', '[]'::jsonb);
  v_codes jsonb := coalesce(p_item -> 'codes', '[]'::jsonb);
  v_units_given boolean := p_item ? 'units';
  v_codes_given boolean := p_item ? 'codes';
  e jsonb;
  i int := 0;
  v_unit text;
  v_num bigint;
  v_den bigint;
  v_kind text;
  v_code text;
  v_seen text[] := array[]::text[];
  v_resulting text[];
  v_codes_seen text[] := array[]::text[];
  v_buys int := 0;
  v_sells int := 0;
  v_dim_old text;
  v_dim_new text;
  v_result jsonb;
  v_kept_codes jsonb;
begin
  v_me := public.stock_config_actor(p_workspace_id);
  if p_request_id is null or p_expected_revision is null
     or coalesce(jsonb_typeof(p_item), '') <> 'object'
     or jsonb_typeof(v_units) <> 'array' or jsonb_typeof(v_codes) <> 'array'
     or jsonb_array_length(v_units) > 50 or jsonb_array_length(v_codes) > 50 then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('stock_item_save|' || p_item_id::text || '|' || p_expected_revision::text || '|' || p_item::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'stock_item_save' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;

  select * into v_item from public.services
   where id = p_item_id and workspace_id = p_workspace_id for update;
  if v_item.id is null then
    raise exception 'not an item of this business' using errcode = 'DKG04';
  end if;
  if v_item.stock_revision <> p_expected_revision then
    raise exception 'the stock configuration of this item changed since it was read' using errcode = 'DKG10';
  end if;

  v_stockable := public.stock_config_bool(p_item, 'stockable', 'stockable', v_item.stockable);
  v_inventory := coalesce(nullif(p_item ->> 'inventory_unit', ''), v_item.inventory_unit);
  v_tracking := coalesce(nullif(p_item ->> 'tracking', ''), v_item.tracking);
  v_shelf := case when p_item ? 'shelf_life_days' then public.stock_config_int(p_item, 'shelf_life_days', 'shelf_life_days')
                  else v_item.shelf_life_days end;
  if (v_inventory is distinct from v_item.inventory_unit or v_tracking is distinct from v_item.tracking)
     and exists (select 1 from public.stock_movements m where m.item_id = v_item.id) then
    raise exception 'this item has stock movements: its unit and tracking stay as they were written'
      using errcode = 'DKG08';
  end if;
  if not exists (select 1 from public.stock_units where code = v_inventory) then
    perform public.stock_config_refuse('inventory_unit', 'unit_unknown');
  end if;
  if v_tracking not in ('none', 'lot', 'expiry') then
    perform public.stock_config_refuse('tracking', 'tracking_unsupported');
  end if;
  if v_shelf is not null and v_shelf not between 1 and 36500 then
    perform public.stock_config_refuse('shelf_life_days', 'out_of_range');
  end if;
  if not v_stockable and v_item.stockable
     and exists (select 1 from public.stock_balances b where b.item_id = v_item.id and b.quantity <> 0) then
    perform public.stock_config_refuse('stockable', 'stock_on_hand');
  end if;
  if v_inventory <> v_item.inventory_unit
     and (case when v_units_given then jsonb_array_length(v_units) > 0
               else exists (select 1 from public.item_units u where u.item_id = p_item_id) end) then
    select dimension into v_dim_old from public.stock_units where code = v_item.inventory_unit;
    select dimension into v_dim_new from public.stock_units where code = v_inventory;
    if v_dim_old is distinct from v_dim_new then
      perform public.stock_config_refuse('inventory_unit', 'dimension_mismatch');
    end if;
  end if;

  for e in select value from jsonb_array_elements(v_units) loop
    i := i + 1;
    v_unit := btrim(coalesce(e ->> 'unit', ''));
    if char_length(v_unit) not between 1 and 30 then
      perform public.stock_config_refuse(format('units[%s].unit', i - 1), 'unit_unknown');
    end if;
    if v_unit = v_inventory or exists (select 1 from public.stock_units where code = v_unit) then
      perform public.stock_config_refuse(format('units[%s].unit', i - 1), 'registry_unit');
    end if;
    if v_unit = any (v_seen) then
      perform public.stock_config_refuse(format('units[%s].unit', i - 1), 'unit_duplicate');
    end if;
    v_seen := v_seen || v_unit;
    begin
      v_num := (e ->> 'factor_num')::bigint;
    exception when others then
      perform public.stock_config_refuse(format('units[%s].factor_num', i - 1), 'factor_invalid');
    end;
    begin
      v_den := (e ->> 'factor_den')::bigint;
    exception when others then
      perform public.stock_config_refuse(format('units[%s].factor_den', i - 1), 'factor_invalid');
    end;
    if v_num is null or v_num <= 0 or v_num > 1000000000 then
      perform public.stock_config_refuse(format('units[%s].factor_num', i - 1), 'factor_invalid');
    end if;
    if v_den is null or v_den <= 0 or v_den > 1000000000 then
      perform public.stock_config_refuse(format('units[%s].factor_den', i - 1), 'factor_invalid');
    end if;
    if public.stock_config_bool(e, 'default_purchase', format('units[%s].default_purchase', i - 1), false) then v_buys := v_buys + 1; end if;
    if public.stock_config_bool(e, 'default_sale', format('units[%s].default_sale', i - 1), false) then v_sells := v_sells + 1; end if;
  end loop;
  if v_buys > 1 then perform public.stock_config_refuse('units', 'default_purchase_twice'); end if;
  if v_sells > 1 then perform public.stock_config_refuse('units', 'default_sale_twice'); end if;

  -- the units the item will have: the request's, or what it has now
  v_resulting := case when v_units_given then v_seen
                      else coalesce((select array_agg(u.unit) from public.item_units u where u.item_id = p_item_id), array[]::text[]) end;

  i := 0;
  for e in select value from jsonb_array_elements(v_codes) loop
    i := i + 1;
    v_code := btrim(coalesce(e ->> 'code', ''));
    v_kind := coalesce(e ->> 'kind', '');
    v_unit := nullif(btrim(coalesce(e ->> 'unit', '')), '');
    if v_kind not in ('gtin', 'own') then
      perform public.stock_config_refuse(format('codes[%s].kind', i - 1), 'kind_unknown');
    end if;
    if v_code !~ '^[0-9A-Za-z._/-]{1,64}$' then
      perform public.stock_config_refuse(format('codes[%s].code', i - 1), 'code_malformed');
    end if;
    if v_kind = 'gtin' then
      if v_code !~ '^[0-9]+$' or char_length(v_code) not in (8, 12, 13, 14) then
        perform public.stock_config_refuse(format('codes[%s].code', i - 1), 'gtin_length');
      end if;
      if not public.stock_gtin_valid(v_code) then
        perform public.stock_config_refuse(format('codes[%s].code', i - 1), 'gtin_check');
      end if;
    end if;
    if v_unit is not null and not (v_unit = any (v_resulting)) then
      perform public.stock_config_refuse(format('codes[%s].unit', i - 1), 'unit_unknown');
    end if;
    if v_code = any (v_codes_seen)
       or exists (select 1 from public.item_codes c
                   where c.workspace_id = p_workspace_id and c.code = v_code and c.item_id <> p_item_id) then
      perform public.stock_config_refuse(format('codes[%s].code', i - 1), 'code_duplicate');
    end if;
    v_codes_seen := v_codes_seen || v_code;
  end loop;

  -- a code the request does not mention keeps its unit: that unit stays
  if v_units_given and not v_codes_given and exists (select 1 from public.item_codes c
       where c.item_id = p_item_id and c.unit is not null and not (c.unit = any (v_seen))) then
    perform public.stock_config_refuse('units', 'code_unit_removed');
  end if;

  -- Everything is valid: the first movement's unit and tracking guard (DKG08)
  -- still decides the inventory unit and the tracking of an item in use.
  select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'kind', c.kind, 'unit', c.unit)), '[]'::jsonb)
    into v_kept_codes from public.item_codes c where c.item_id = p_item_id;
  update public.services
     set stockable = v_stockable,
         purchasable = public.stock_config_bool(p_item, 'purchasable', 'purchasable', purchasable),
         sellable = public.stock_config_bool(p_item, 'sellable', 'sellable', sellable),
         inventory_unit = v_inventory, tracking = v_tracking, shelf_life_days = v_shelf,
         stock_revision = stock_revision + 1
   where id = p_item_id;
  if v_units_given or v_codes_given then
    delete from public.item_codes where item_id = p_item_id and (v_codes_given or v_units_given);
  end if;
  if v_units_given then delete from public.item_units where item_id = p_item_id; end if;
  for e in select value from jsonb_array_elements(case when v_units_given then v_units else '[]'::jsonb end) loop
    insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, default_purchase, default_sale)
    values (p_workspace_id, p_item_id, btrim(e ->> 'unit'), (e ->> 'factor_num')::bigint, (e ->> 'factor_den')::bigint,
            coalesce((e ->> 'default_purchase')::boolean, false), coalesce((e ->> 'default_sale')::boolean, false));
  end loop;
  -- an item's codes are rewritten with its units (a code may name a unit): when
  -- only the units are sent, the codes already kept are put back
  for e in select value from jsonb_array_elements(case when v_codes_given then v_codes else v_kept_codes end) loop
    insert into public.item_codes (workspace_id, item_id, unit, code, kind)
    values (p_workspace_id, p_item_id, nullif(btrim(coalesce(e ->> 'unit', '')), ''), btrim(e ->> 'code'), e ->> 'kind');
  end loop;

  v_result := jsonb_build_object('item_id', p_item_id, 'revision', p_expected_revision + 1, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'stock_item_save', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.save_stock_item_v1(uuid, uuid, int, uuid, jsonb) from public, anon;
grant execute on function public.save_stock_item_v1(uuid, uuid, int, uuid, jsonb) to authenticated;

-- ── a place ─────────────────────────────────────────────────────────────
-- p_place: {kind, code, name, barcode, parent_id, active}. p_place_id null
-- creates (p_expected_revision null); else the place and the revision read.
create or replace function public.save_stock_location_v1(
  p_workspace_id uuid, p_place_id uuid, p_expected_revision int, p_request_id uuid, p_place jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done public.purchase_requests;
  v_old public.stock_locations;
  v_kind text;
  v_code text;
  v_name text;
  v_barcode text;
  v_parent uuid;
  v_active boolean;
  v_walk uuid;
  v_hops int := 0;
  v_id uuid;
  v_rev int;
  v_result jsonb;
begin
  perform public.stock_config_actor(p_workspace_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_place), '') <> 'object'
     or (p_place_id is null) <> (p_expected_revision is null) then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('stock_location_save|' || coalesce(p_place_id::text, '') || '|'
                  || coalesce(p_expected_revision::text, '') || '|' || p_place::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'stock_location_save' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;

  if p_place_id is not null then
    select * into v_old from public.stock_locations
     where id = p_place_id and workspace_id = p_workspace_id for update;
    if v_old.id is null then
      raise exception 'not a place of this business' using errcode = 'DKG05';
    end if;
    if exists (select 1 from public.stock_location_kinds k where k.key = v_old.kind and k.virtual) then
      perform public.stock_config_refuse('place', 'location_virtual');
    end if;
    if v_old.revision <> p_expected_revision then
      raise exception 'this place changed since it was read' using errcode = 'DKG10';
    end if;
  end if;

  v_kind := coalesce(nullif(p_place ->> 'kind', ''), v_old.kind);
  v_code := btrim(coalesce(p_place ->> 'code', v_old.code, ''));
  v_name := coalesce(p_place ->> 'name', v_old.name, '');
  v_barcode := case when p_place ? 'barcode' then nullif(btrim(coalesce(p_place ->> 'barcode', '')), '')
                    else v_old.barcode end;
  v_parent := case when p_place ? 'parent_id' then public.stock_config_uuid(p_place, 'parent_id', 'parent_id')
                   else v_old.parent_id end;
  v_active := public.stock_config_bool(p_place, 'active', 'active', coalesce(v_old.active, true));

  if v_kind is null or not exists (select 1 from public.stock_location_kinds k where k.key = v_kind) then
    perform public.stock_config_refuse('kind', 'kind_unknown');
  end if;
  if exists (select 1 from public.stock_location_kinds k where k.key = v_kind and k.virtual) then
    perform public.stock_config_refuse('kind', 'location_virtual');
  end if;
  if v_code !~ '^[0-9A-Za-z._/-]{1,40}$' then
    perform public.stock_config_refuse('code', 'code_malformed');
  end if;
  if char_length(v_name) > 120 then perform public.stock_config_refuse('name', 'too_long'); end if;
  if v_barcode is not null and v_barcode !~ '^[0-9A-Za-z._/-]{1,64}$' then
    perform public.stock_config_refuse('barcode', 'code_malformed');
  end if;
  if exists (select 1 from public.stock_locations l where l.workspace_id = p_workspace_id and l.code = v_code
              and l.id is distinct from p_place_id) then
    perform public.stock_config_refuse('code', 'code_duplicate');
  end if;
  if v_barcode is not null and exists (select 1 from public.stock_locations l
       where l.workspace_id = p_workspace_id and l.barcode = v_barcode and l.id is distinct from p_place_id) then
    perform public.stock_config_refuse('barcode', 'code_duplicate');
  end if;

  if v_parent is not null then
    if v_parent = p_place_id then perform public.stock_config_refuse('parent_id', 'location_cycle'); end if;
    if not exists (select 1 from public.stock_locations l where l.id = v_parent and l.workspace_id = p_workspace_id) then
      perform public.stock_config_refuse('parent_id', 'location_parent_foreign');
    end if;
    if exists (select 1 from public.stock_locations l join public.stock_location_kinds k on k.key = l.kind
                where l.id = v_parent and k.virtual) then
      perform public.stock_config_refuse('parent_id', 'location_virtual');
    end if;
    if v_active and not exists (select 1 from public.stock_locations l where l.id = v_parent and l.active) then
      perform public.stock_config_refuse('parent_id', 'parent_inactive');
    end if;
    v_walk := v_parent;
    while v_walk is not null and v_hops < 1000 loop
      if v_walk = p_place_id then perform public.stock_config_refuse('parent_id', 'location_cycle'); end if;
      select parent_id into v_walk from public.stock_locations where id = v_walk;
      v_hops := v_hops + 1;
    end loop;
  end if;

  if p_place_id is not null
     and p_place_id = public.stock_place(p_workspace_id, 'warehouse')
     and (not v_active or v_kind <> v_old.kind) then
    perform public.stock_config_refuse('active', 'location_default');
  end if;

  if p_place_id is not null and v_old.active and not v_active then
    if exists (select 1 from public.stock_balances b where b.location_id = p_place_id and b.quantity <> 0) then
      perform public.stock_config_refuse('active', 'location_occupied');
    end if;
    if exists (select 1 from public.stock_locations c where c.parent_id = p_place_id and c.active) then
      perform public.stock_config_refuse('active', 'location_has_children');
    end if;
  end if;
  if p_place_id is null then
    insert into public.stock_locations (workspace_id, parent_id, kind, code, name, barcode, active)
    values (p_workspace_id, v_parent, v_kind, v_code, v_name, v_barcode, v_active)
    returning id, revision into v_id, v_rev;
  else
    update public.stock_locations
       set parent_id = v_parent, kind = v_kind, code = v_code, name = v_name, barcode = v_barcode,
           active = v_active, revision = revision + 1
     where id = p_place_id
    returning id, revision into v_id, v_rev;
  end if;
  v_result := jsonb_build_object('place_id', v_id, 'revision', v_rev, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'stock_location_save', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.save_stock_location_v1(uuid, uuid, int, uuid, jsonb) from public, anon;
grant execute on function public.save_stock_location_v1(uuid, uuid, int, uuid, jsonb) to authenticated;

select public.set_deskilo_schema_version(836);
