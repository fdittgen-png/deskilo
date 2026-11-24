-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new function; no table, no existing function and no stored row moves)
--
-- #4402 -- a NEW item from the Stock page is one command with one request id. The sheet made the service
-- (`create_service_v1`), then its stock settings (`save_stock_item_v1`), then its home place (`set_stock_home_v1`):
-- three writes, three request ids, three resume flags on the screen. A sheet closed after the first left a service
-- that was no item, with no stock settings and no home. `create_stock_item_v1` does the three in one transaction:
-- a refusal of any step (a VAT rate of another business, a unit the registry does not know, a home that is not a
-- place an item can be kept at) leaves nothing, and the same request id with the same content answers the item it
-- first made and makes nothing (the request store of the stock and purchase commands, 0948). The member needs both
-- rights the three steps need: `manageServices` (a service is made) and `manageStock` (its stock settings); an
-- assistant is refused. Each step keeps its own checks; its request id is derived from the command's, so a step is
-- never answered from another command's record.
--
-- p_item: {name, price_cents, vat_rate_id, inventory_unit, barcode, home_location_id}; name and inventory_unit are
-- needed (an empty name is the service command's refusal), the others may be absent. The answer: {item_id, revision} (the stock revision the settings left).

-- audience: all row readers
create or replace function public.create_stock_item_v1(p_workspace_id uuid, p_request_id uuid, p_item jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_allowed constant text[] := array['name', 'price_cents', 'vat_rate_id', 'inventory_unit', 'barcode', 'home_location_id'];
  v_key text;
  v_name text;
  v_unit text;
  v_barcode text;
  v_home uuid;
  v_digest text;
  v_done jsonb;
  v_item uuid;
  v_saved jsonb;
begin
  perform public.command_actor(p_workspace_id, 'manageServices', null, 'not allowed to create an item');
  perform public.command_actor(p_workspace_id, 'manageStock', null, 'not allowed to create an item');
  if p_request_id is null or coalesce(jsonb_typeof(p_item), '') <> 'object' then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  for v_key in select jsonb_object_keys(p_item) loop
    if not (v_key = any (v_allowed)) then
      perform public.stock_config_refuse(v_key, 'malformed');
    end if;
  end loop;
  v_name := btrim(coalesce(p_item ->> 'name', ''));
  v_unit := nullif(btrim(coalesce(p_item ->> 'inventory_unit', '')), '');
  if v_unit is null then
    perform public.stock_config_refuse('inventory_unit', 'unit_unknown');
  end if;
  v_barcode := nullif(btrim(coalesce(p_item ->> 'barcode', '')), '');
  v_home := public.stock_config_uuid(p_item, 'home_location_id', 'home_location_id');

  v_digest := md5('stock_item_create|' || p_item::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'stock_item_create', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;

  -- 1. the service, by the command that owns it
  v_item := (public.create_service_v1(
    p_workspace_id,
    md5(p_request_id::text || ':service')::uuid,
    jsonb_strip_nulls(jsonb_build_object(
      'name', v_name,
      'price_cents', coalesce((p_item ->> 'price_cents')::int, 0),
      'vat_rate_id', nullif(p_item ->> 'vat_rate_id', '')))
  ) ->> 'id')::uuid;

  -- 2. its stock settings: kept in stock, bought and sold, in its unit, with its barcode
  v_saved := public.save_stock_item_v1(
    p_workspace_id,
    v_item,
    (select s.stock_revision from public.services s where s.id = v_item),
    md5(p_request_id::text || ':settings')::uuid,
    jsonb_build_object(
      'stockable', true, 'purchasable', true, 'sellable', true,
      'inventory_unit', v_unit, 'tracking', 'none', 'shelf_life_days', null,
      'units', '[]'::jsonb,
      'codes', case when v_barcode is null then '[]'::jsonb
                    else jsonb_build_array(jsonb_build_object('code', v_barcode, 'kind', 'own')) end));

  -- 3. its home place, when one is chosen
  if v_home is not null then
    perform public.set_stock_home_v1(p_workspace_id, v_item, null, v_home, md5(p_request_id::text || ':home')::uuid);
  end if;

  return public.request_finish(p_workspace_id, p_request_id, 'stock_item_create', v_digest,
    jsonb_build_object('item_id', v_item, 'revision', (v_saved ->> 'revision')::int, 'replayed', false));
end;
$fn$;
revoke execute on function public.create_stock_item_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.create_stock_item_v1(uuid, uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(955);
