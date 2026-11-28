-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4520 -- an item can show its stock on hand at the till. It is one more till setting of an item, as its till category
-- and its key colour are: set on its group (and so on each item of the group) or on the item itself, which overrides.
--   * `services.till_shows_stock`, `item_groups.till_shows_stock` (boolean; empty: inherited, then off).
--   * the catalogue of parameters (`item_group_param_kind`, `item_group_params`) names it an item setting; the group save
--     (`item_group_save_core`) stores it; an item's override goes through `item_override_save_v1` as any other.
--   * `counter_till_stock_v1(workspace, till)`: for whoever may sell, where showing the stock at the till is on
--     (counterStockOnKeys), the quantity on hand of each item that shows its stock, in its stock unit, over the
--     business's places that hold stock (not the virtual ones). Never another item, a lot or a place. A quantity is
--     information: the till sells at 0 as before.
-- Anchored patches of the live definitions (0883, patched by 0952, 0961, 0980 and 0992), each anchor asserted once.
-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
-- END FEATURE REGISTRY ROWS

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '1006: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- audience: all row readers (an item's till setting is as readable as its till category)
alter table public.services add column till_shows_stock boolean;
-- audience: all row readers (a group's till setting is as readable as its till category)
alter table public.item_groups add column till_shows_stock boolean;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.item_group_param_kind(text)'::regprocedure) into v_def;
  if position('till_shows_stock' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'''default_sale_price_cents'') then ''item''',
      E'''default_sale_price_cents'', ''till_shows_stock'') then ''item''', 'the item settings');
    execute v_def;
  end if;

  select pg_get_functiondef('public.item_group_params()'::regprocedure) into v_def;
  if position('till_shows_stock' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'''weight_basis'', ''deposit_item_id'', ''deposit_minor'', ''label_template'',',
      E'''weight_basis'', ''deposit_item_id'', ''deposit_minor'', ''label_template'', ''till_shows_stock'',', 'the parameters');
    execute v_def;
  end if;

  select pg_get_functiondef('public.item_group_save_core(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,boolean)'::regprocedure) into v_def;
  if position('till_shows_stock' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'        default_sale_price_cents)\n      values (',
      E'        default_sale_price_cents, till_shows_stock)\n      values (', 'the insert columns');
    v_def := pg_temp.anchor_once(v_def, E'        v_new.default_sale_price_cents);',
      E'        v_new.default_sale_price_cents, v_new.till_shows_stock);', 'the insert values');
    v_def := pg_temp.anchor_once(v_def, E'default_sale_price_cents = v_new.default_sale_price_cents\n       where id = v_new.id;',
      E'default_sale_price_cents = v_new.default_sale_price_cents,\n        till_shows_stock = v_new.till_shows_stock\n       where id = v_new.id;', 'the update');
    execute v_def;
  end if;
end
$migration$;

-- Whether [s] shows its stock at the till: its own setting, else its subgroup's, else its group's; off when none says.
create or replace function public.item_till_shows_stock(s public.services)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select coalesce(s.till_shows_stock, n.till_shows_stock, q.till_shows_stock, false)
    from (select 1) one
    left join public.item_groups n on n.id = s.group_id
    left join public.item_groups q on q.id = n.parent_id
$fn$;
revoke execute on function public.item_till_shows_stock(public.services) from public, anon, authenticated;

create or replace function public.counter_till_stock_v1(p_workspace_id uuid, p_till_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
begin
  perform public.command_actor(p_workspace_id, 'issueInvoices', 'counterStockOnKeys',
    'only who sells in this business reads the stock at the till', 'the stock is not shown at the till in this business');
  if p_till_id is not null and not exists (select 1 from public.counter_tills t where t.workspace_id = p_workspace_id and t.id = p_till_id) then
    perform public.refuse('DKL02', '{"reason": "till"}'::jsonb, 'no such till in this business');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('item_id', s.id, 'quantity', coalesce(b.quantity, 0), 'unit', s.inventory_unit) order by s.id)
      from public.services s
      left join lateral (
        select sum(x.quantity) as quantity
          from public.stock_balances x
          join public.stock_locations l on l.id = x.location_id
          join public.stock_location_kinds k on k.key = l.kind
         where x.workspace_id = s.workspace_id and x.item_id = s.id and not k.virtual) b on true
     where s.workspace_id = p_workspace_id and s.active and s.stockable and public.item_till_shows_stock(s)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.counter_till_stock_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_till_stock_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(1006);
