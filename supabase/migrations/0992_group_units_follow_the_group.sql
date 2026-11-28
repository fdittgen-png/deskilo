-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4479 -- an item group's units follow the group. The group's sale unit, its factor to the inventory unit and its price (0980), and its
-- purchase unit and factor (0883), were PROPOSALS: stored with the group, read by no item. They are now inherited like the till category
-- or the minimum age: an item without a value of its own reads the group's current one (its sub-group's first, then its group's), a
-- change of the group reaches every such item the moment it is saved and never an item that keeps its own, and an item sets its own or
-- goes back to the group's with `item_override_save_v1` (modes `set` and `inherit`), which also records it in the history.
--   * `services` gets the seven nullable columns under the parameters' own names (the generic resolution reads an item's column of the
--     parameter's name): null = inherits. The same bounds as the group's own columns.
--   * `item_group_param_kind` names the seven `item`, not `proposal`.
-- Nothing is written into an existing item: nothing was ever copied into one, so no value has to be kept as an override.
--   * `unit_factor` (the one conversion rule) and `item_unit_price` read the unit an item is in force with: a unit its group sells or buys it in
--     converts to the inventory unit by the group's factor, and the sale unit's price is the group's price, unless the item lists the unit itself.
--     So an order line or an invoice line in the group's unit is accepted and priced, as one in a unit the item lists.
-- The functions that resolve, preview, save and override read the kind and the column name and are untouched.

-- audience: all row readers (an item's own unit is read with the item)
alter table public.services
  add column if not exists default_purchase_unit text check (char_length(btrim(default_purchase_unit)) between 1 and 30),
  add column if not exists default_purchase_factor_num bigint check (default_purchase_factor_num > 0),
  add column if not exists default_purchase_factor_den bigint check (default_purchase_factor_den > 0),
  add column if not exists default_sale_unit text check (char_length(btrim(default_sale_unit)) between 1 and 30),
  add column if not exists default_sale_factor_num bigint check (default_sale_factor_num > 0),
  add column if not exists default_sale_factor_den bigint check (default_sale_factor_den > 0),
  add column if not exists default_sale_price_cents bigint check (default_sale_price_cents between 0 and 2000000000);
alter table public.services
  add constraint services_default_purchase_factor_pair check ((default_purchase_factor_num is null) = (default_purchase_factor_den is null)),
  add constraint services_default_sale_factor_pair check ((default_sale_factor_num is null) = (default_sale_factor_den is null));

-- The units now decide the price a line is sold at and the unit it is bought in, so they are what an item costs or sells for: changing them
-- takes the same two rights as the VAT rate or the margin (manage services and see the finances), on a group and on an item. Before, as
-- proposals no item read, they were stored without that gate.
-- restates 0883
create or replace function public.item_group_param_finance(p_param text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_param in ('vat_rate_id', 'supply_class', 'price_rounding', 'target_margin_bps',
                     'default_purchase_unit', 'default_purchase_factor_num', 'default_purchase_factor_den',
                     'default_sale_unit', 'default_sale_factor_num', 'default_sale_factor_den', 'default_sale_price_cents');
$fn$;
revoke execute on function public.item_group_param_finance(text) from public, anon, authenticated;

-- restates 0883 (patched by 0980)
create or replace function public.item_group_param_kind(p_param text)
returns text language sql immutable set search_path = public as $fn$
  select case
    when p_param in ('tracking', 'shelf_life_days', 'inventory_unit', 'vat_rate_id', 'supply_class') then 'stored'
    when p_param in ('tag_mode', 'count_every_days', 'till_category', 'quick_key_colour', 'min_age', 'sold_by_weight',
                     'weight_basis', 'deposit_item_id', 'deposit_minor', 'label_template',
                     'default_purchase_unit', 'default_purchase_factor_num', 'default_purchase_factor_den',
                     'default_sale_unit', 'default_sale_factor_num', 'default_sale_factor_den',
                     'default_sale_price_cents') then 'item'
    when p_param in ('price_rounding', 'target_margin_bps', 'reorder_point_default', 'reorder_quantity_default',
                     'home_zone_id') then 'proposal'
    else null end;
$fn$;
revoke execute on function public.item_group_param_kind(text) from public, anon, authenticated;

-- ── what an item reads of its group's units, for the rules that convert and price ─────────────────────────────────────────────────
-- The values in force for an item: its own column, else its sub-group's, else its group's (the order `item_effective_core` reads them).
create or replace function public.item_group_unit_values(p_item_id uuid)
returns table (sale_unit text, sale_num bigint, sale_den bigint, sale_price bigint, purchase_unit text, purchase_num bigint, purchase_den bigint)
language sql stable security definer set search_path = public as $fn$
  select coalesce(s.default_sale_unit, n.default_sale_unit, q.default_sale_unit),
         coalesce(s.default_sale_factor_num, n.default_sale_factor_num, q.default_sale_factor_num),
         coalesce(s.default_sale_factor_den, n.default_sale_factor_den, q.default_sale_factor_den),
         coalesce(s.default_sale_price_cents, n.default_sale_price_cents, q.default_sale_price_cents),
         coalesce(s.default_purchase_unit, n.default_purchase_unit, q.default_purchase_unit),
         coalesce(s.default_purchase_factor_num, n.default_purchase_factor_num, q.default_purchase_factor_num),
         coalesce(s.default_purchase_factor_den, n.default_purchase_factor_den, q.default_purchase_factor_den)
    from public.services s
    left join public.item_groups n on n.id = s.group_id
    left join public.item_groups q on q.id = n.parent_id
   where s.id = p_item_id;
$fn$;
revoke execute on function public.item_group_unit_values(uuid) from public, anon, authenticated;

-- restates 0968: an item's own conversion first, then the sale or purchase unit it is in force with (its own, or its group's), then the
-- business's general one
create or replace function public.unit_factor(p_workspace_id uuid, p_item_id uuid, p_from text, p_to text)
returns table (num bigint, den bigint)
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inventory text;
  v_unit text;
  g record;
begin
  if p_from is null or p_to is null or p_from = p_to then
    return query select 1::bigint, 1::bigint;
    return;
  end if;
  if p_item_id is not null then
    select inventory_unit into v_inventory from public.services where id = p_item_id and workspace_id = p_workspace_id;
    if p_to = v_inventory then
      return query select i.factor_num, i.factor_den from public.item_units i where i.item_id = p_item_id and i.unit = p_from;
      if found then return; end if;
    elsif p_from = v_inventory then
      return query select i.factor_den, i.factor_num from public.item_units i where i.item_id = p_item_id and i.unit = p_to;
      if found then return; end if;
    end if;
    if v_inventory is not null and (p_to = v_inventory or p_from = v_inventory) then
      v_unit := case when p_to = v_inventory then p_from else p_to end;
      select * into g from public.item_group_unit_values(p_item_id);
      if g.sale_unit = v_unit and g.sale_num is not null then
        return query select case when p_to = v_inventory then g.sale_num else coalesce(g.sale_den, 1) end,
                            case when p_to = v_inventory then coalesce(g.sale_den, 1) else g.sale_num end;
        return;
      elsif g.purchase_unit = v_unit and g.purchase_num is not null then
        return query select case when p_to = v_inventory then g.purchase_num else coalesce(g.purchase_den, 1) end,
                            case when p_to = v_inventory then coalesce(g.purchase_den, 1) else g.purchase_num end;
        return;
      end if;
    end if;
  end if;
  return query select c.factor_num, c.factor_den from public.unit_conversions c
                where c.workspace_id = p_workspace_id and c.from_unit = p_from and c.to_unit = p_to;
  if found then return; end if;
  return query select c.factor_den, c.factor_num from public.unit_conversions c
                where c.workspace_id = p_workspace_id and c.from_unit = p_to and c.to_unit = p_from;
end;
$fn$;
revoke execute on function public.unit_factor(uuid, uuid, text, text) from public, anon, authenticated;

-- restates 0974: the price of the sale unit an item is in force with (its own, or its group's) comes before the derived one
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
  select g.sale_price into v_own from public.item_group_unit_values(p_item_id) g where g.sale_unit = p_unit;
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

notify pgrst, 'reload schema';
-- ── the house command fences the group's sale price like an item's own ─────
-- restates 0783: `default_sale_price_cents` is an amount of a carried table (pgTAP 434); kept when the house's currency is the
-- head's, 0 when it differs.
create or replace function public.organisation_house_fenced_amounts()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"services": ["price_cents", "default_sale_price_cents"],
           "packages": ["price_cents"],
           "validation_policies": ["min_amount_cents"],
           "closure_days": []}'::jsonb
$fn$;
revoke execute on function public.organisation_house_fenced_amounts() from public, anon;
grant execute on function public.organisation_house_fenced_amounts() to authenticated;

select public.set_deskilo_schema_version(992);
