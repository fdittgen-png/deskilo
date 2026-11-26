-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4479 -- an order line of a stocked item is in a unit the item can be converted from, and is refused when it is saved, not when the
-- goods arrive. Until now a business unit (a carton, a box) was accepted on any order line (0960: it is one of the business's units)
-- and the receipt then refused it (`unit_unmapped`, 0840) once the order was sent, paid for and delivered.
--   * `unit_is_convertible(workspace, item, unit)`: true for no unit, a unit that is the item's inventory unit, an item that is not
--     stocked (a service has no stock to convert into), and a unit with a defined one-step conversion (`unit_factor`, 0968).
--   * `save_purchase_order_v1` refuses a line whose unit is not (DKG11 `lines[n].unit`, reason `unit_unmapped`, the receipt's own).
-- Anchored patch of the live definition (0960 patched it), asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0971: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

create or replace function public.unit_is_convertible(p_workspace uuid, p_item uuid, p_unit text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select p_item is null
      or btrim(coalesce(p_unit, '')) = ''
      or not exists (select 1 from public.services s where s.id = p_item and s.workspace_id = p_workspace and s.stockable)
      or exists (select 1 from public.services s, public.unit_factor(p_workspace, s.id, btrim(p_unit), s.inventory_unit) f
                  where s.id = p_item and s.workspace_id = p_workspace and f.num is not null);
$fn$;
-- server-side only, like unit_factor: it takes any workspace id, so a client must never call it (it would tell what another business's items convert)
revoke execute on function public.unit_is_convertible(uuid, uuid, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.save_purchase_order_v1(uuid,uuid,int,jsonb)'::regprocedure) into v_def;
  if position('unit_is_convertible' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def,
      $o$    if not public.vat_percent_is_known(p_workspace_id, v_rate) then$o$,
      $n$    if not public.unit_is_convertible(p_workspace_id, v_item, e ->> 'unit') then
      perform public.stock_config_refuse(format('lines[%s].unit', n - 1), 'unit_unmapped');
    end if;
    if not public.vat_percent_is_known(p_workspace_id, v_rate) then$n$,
      'the rate check of save_purchase_order_v1');
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(971);
