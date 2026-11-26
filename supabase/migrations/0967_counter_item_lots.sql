-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4366 / #4436 -- the lots a till may sell an item from: the seller chooses one, or leaves the server to take the one
-- that expires first (0947). Read where the counter is worked (issueInvoices, counter receipts on), without the stock
-- rights a cashier does not hold.
--
--   counter_item_lots_v1   the lots of an item on hand at the place a counter sale takes from (the business's MAIN place,
--                          as the finalize takes it), each with its code (the supplier's lot code, else its label), its
--                          date and the quantity on hand in the item's inventory unit; the first to expire first. A lot
--                          past its date is listed and marked expired: the till does not offer it. An item of another
--                          business, or one that is not sold, is refused (DKL02 {"reason": "item"}).
-- The quantities are the inventory unit's: what the till sells is converted before it is compared (units per #4479).

create or replace function public.counter_item_lots_v1(p_workspace_id uuid, p_item_id uuid)
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
  select l.id into v_place from public.stock_locations l where l.workspace_id = p_workspace_id and l.code = 'MAIN';
  return jsonb_build_object('unit', v_unit, 'lots', coalesce((
    select jsonb_agg(jsonb_build_object(
             'lot_id', lot.id,
             'code', coalesce(nullif(lot.lot_code, ''), lot.label_code, ''),
             'expires_on', lot.expires_on,
             'expired', lot.expires_on is not null and lot.expires_on < v_today,
             'quantity', trim_scale(b.quantity)::text)
           order by lot.expires_on nulls last, lot.lot_code, lot.id)
      from public.stock_balances b
      join public.stock_lots lot on lot.id = b.lot_id and lot.workspace_id = p_workspace_id
     where b.workspace_id = p_workspace_id and b.item_id = p_item_id and b.location_id = v_place and b.quantity > 0), '[]'::jsonb));
end
$fn$;
revoke execute on function public.counter_item_lots_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_item_lots_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(967);
