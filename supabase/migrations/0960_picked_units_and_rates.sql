-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4471 -- a unit and a VAT rate are picked from the master data, never typed. The server says no to a unit that is not one of
-- the business's units of measure (or, for a line of an item, one the item declares itself: its item units, its mapping's
-- purchase unit, its inventory unit) and to a VAT rate that is not one of its active rates.
--   * `unit_is_pickable` / `vat_percent_is_known`: the one answer, read by every command below.
--   * the purchase order's save (`save_purchase_order_v1`): every line is checked when the order is saved, so a line already
--     stored with a free value is untouched until the order is edited (a receipt moving the received quantity never trips
--     it), and the replenishment draft, which fills a line from the item's own purchase unit, stays valid.
--   * the bill lines of an item (`purchase_write_lines`) and a direct engagement (`service_fulfilment_direct_scope`).
-- A refusal is the stock configuration's own (DKG11, the field and the reason in the detail, `unit_unknown` and
-- `vat_rate_unknown`), or the engagement's (DKF06, detail `unit`). The three commands are patched at an asserted anchor.

-- A unit is '' (none), a unit of the business's units of measure, or, with an item, one the item declares.
create or replace function public.unit_is_pickable(p_workspace uuid, p_unit text, p_item uuid default null)
returns boolean language sql stable security definer set search_path = public as $fn$
  select btrim(coalesce(p_unit, '')) = ''
      or exists (select 1 from public.workspace_units u where u.workspace_id = p_workspace and u.code = btrim(p_unit))
      or (p_item is not null and (
            exists (select 1 from public.item_units i
                     where i.workspace_id = p_workspace and i.item_id = p_item and i.unit = btrim(p_unit))
         or exists (select 1 from public.supplier_item_mappings m
                     where m.workspace_id = p_workspace and m.item_id = p_item and m.purchase_unit = btrim(p_unit))
         or exists (select 1 from public.services s
                     where s.id = p_item and s.workspace_id = p_workspace and s.inventory_unit = btrim(p_unit))));
$fn$;
revoke execute on function public.unit_is_pickable(uuid, text, uuid) from public, anon, authenticated;

-- A VAT rate is none (null), or the percent of an active rate of the business.
create or replace function public.vat_percent_is_known(p_workspace uuid, p_percent numeric)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_percent is null
      or exists (select 1 from public.vat_rates r where r.workspace_id = p_workspace and r.active and r.percent = p_percent);
$fn$;
revoke execute on function public.vat_percent_is_known(uuid, numeric) from public, anon, authenticated;

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

do $migration$
declare
  v_def text;
begin
  -- the order's lines: the unit and the rate, once the rate of the line is read
  select pg_get_functiondef('public.save_purchase_order_v1(uuid,uuid,int,jsonb)'::regprocedure) into v_def;
  if position('unit_is_pickable' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $o$    v_rate := nullif(e ->> 'vat_rate_percent', '')::numeric;$o$,
      $n$    v_rate := nullif(e ->> 'vat_rate_percent', '')::numeric;
    if not public.unit_is_pickable(p_workspace_id, e ->> 'unit', v_item) then
      perform public.stock_config_refuse(format('lines[%s].unit', n - 1), 'unit_unknown');
    end if;
    if not public.vat_percent_is_known(p_workspace_id, v_rate) then
      perform public.stock_config_refuse(format('lines[%s].vat_rate_percent', n - 1), 'vat_rate_unknown');
    end if;$n$);
    if v_def is null then raise exception '0960: save_purchase_order_v1 anchor missing' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- the bill lines of an item: the unit of a line that names an item
  select pg_get_functiondef('public.purchase_write_lines(uuid,uuid,jsonb)'::regprocedure) into v_def;
  if position('unit_is_pickable' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $o$    if v_site is not null and not exists ($o$,
      $n$    if v_item is not null and not public.unit_is_pickable(p_workspace_id, e ->> 'unit', v_item) then
      perform public.stock_config_refuse(format('lines[%s].unit', n - 1), 'unit_unknown');
    end if;
    if v_site is not null and not exists ($n$);
    if v_def is null then raise exception '0960: purchase_write_lines anchor missing' using errcode = 'P0001'; end if;
    execute v_def;
  end if;

  -- a direct engagement: the unit, once the item is known
  select pg_get_functiondef('public.service_fulfilment_direct_scope(uuid,jsonb)'::regprocedure) into v_def;
  if position('unit_is_pickable' in v_def) = 0 then
    v_def := pg_temp.anchor_replace(v_def,
      $o$  if v_variant is not null and (v_item is null or not exists ($o$,
      $n$  if not public.unit_is_pickable(p_workspace, v_unit, v_item) then
    raise exception 'the unit is not one of the business''s units' using errcode = 'DKF06', detail = 'unit';
  end if;
  if v_variant is not null and (v_item is null or not exists ($n$);
    if v_def is null then raise exception '0960: service_fulfilment_direct_scope anchor missing' using errcode = 'P0001'; end if;
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(960);
