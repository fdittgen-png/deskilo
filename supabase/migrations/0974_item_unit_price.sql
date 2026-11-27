-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4479 -- an item is sold in any of its units, at THAT unit's price. A unit of an item may carry a price of its own (a carton of 12 at 11,00
-- where twelve pieces would be 12,00); without one its price is the item's price times what one of it makes of the inventory unit, rounded once.
--   * `item_units.price_cents`: the price of ONE of that unit, in the minor units of the item's price (which is VAT-inclusive); null = derived.
--   * `item_unit_price(workspace, item, unit)`: THE one answer. The inventory unit (or no unit) is the item's price; a unit with a price of its
--     own is that price; else the item's price times the unit's factor to the inventory unit (`unit_factor`, 0968, one step), rounded half up
--     once; no defined conversion is DKG02 naming the units (never read as one).
--   * `save_stock_item_v1` stores the price of each unit sent and refuses one that is not a whole number of minor units between 0 and
--     2,000,000,000 (DKG11 `units[n].price_cents`, `price_invalid`).
-- Anchored patch of the live `save_stock_item_v1` (0836, patched by 0837, 0883, 0931, 0952, 0955 and 0961), each anchor asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0974: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- audience: all row readers (the price of a unit is as readable as the unit itself)
alter table public.item_units
  add column price_cents bigint check (price_cents is null or price_cents between 0 and 2000000000);

create or replace function public.item_unit_price(p_workspace_id uuid, p_item_id uuid, p_unit text)
returns bigint language plpgsql stable security definer set search_path = public as $fn$
declare
  v_price bigint;
  v_inventory text;
  v_own bigint;
  v_num bigint;
  v_den bigint;
begin
  select s.price_cents, s.inventory_unit into v_price, v_inventory
    from public.services s where s.id = p_item_id and s.workspace_id = p_workspace_id;
  if v_inventory is null then
    raise exception 'unknown item' using errcode = 'DKG04';
  end if;
  if btrim(coalesce(p_unit, '')) = '' or p_unit = v_inventory then
    return v_price;
  end if;
  select i.price_cents into v_own from public.item_units i where i.item_id = p_item_id and i.unit = p_unit;
  if v_own is not null then
    return v_own;
  end if;
  select f.num, f.den into v_num, v_den from public.unit_factor(p_workspace_id, p_item_id, p_unit, v_inventory) f;
  if v_num is null then
    raise exception 'no conversion from % to % is defined for this item', p_unit, v_inventory using errcode = 'DKG02';
  end if;
  return round(v_price::numeric * v_num / v_den)::bigint;
end;
$fn$;
revoke execute on function public.item_unit_price(uuid, uuid, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.save_stock_item_v1(uuid,uuid,integer,uuid,jsonb)'::regprocedure) into v_def;
  if position('price_cents' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def,
      E'    if public.stock_config_bool(e, ''default_purchase'', format(''units[%s].default_purchase'', i - 1), false) then v_buys := v_buys + 1; end if;',
      E'    if nullif(e ->> ''price_cents'', '''') is not null\n' ||
      E'       and ((e ->> ''price_cents'') !~ ''^[0-9]{1,10}$'' or (e ->> ''price_cents'')::bigint > 2000000000) then\n' ||
      E'      perform public.stock_config_refuse(format(''units[%s].price_cents'', i - 1), ''price_invalid'');\n' ||
      E'    end if;\n' ||
      E'    if public.stock_config_bool(e, ''default_purchase'', format(''units[%s].default_purchase'', i - 1), false) then v_buys := v_buys + 1; end if;',
      'the unit checks');
    v_def := pg_temp.anchor_once(v_def,
      'insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, default_purchase, default_sale)',
      'insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den, default_purchase, default_sale, price_cents)',
      'the unit insert columns');
    v_def := pg_temp.anchor_once(v_def,
      E'coalesce((e ->> ''default_purchase'')::boolean, false), coalesce((e ->> ''default_sale'')::boolean, false))\n    on conflict',
      E'coalesce((e ->> ''default_purchase'')::boolean, false), coalesce((e ->> ''default_sale'')::boolean, false),\n            nullif(e ->> ''price_cents'', '''')::bigint)\n    on conflict',
      'the unit insert values');
    v_def := pg_temp.anchor_once(v_def,
      'default_purchase = excluded.default_purchase, default_sale = excluded.default_sale;',
      'default_purchase = excluded.default_purchase, default_sale = excluded.default_sale, price_cents = excluded.price_cents;',
      'the unit upsert');
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(974);
