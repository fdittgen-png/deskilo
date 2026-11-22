-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4293 (G7, cut B): the product and place registry. An item, or one of its variants, names the
-- one place in its business where it belongs - its home address - so receiving, counting and
-- picking know where it goes.
--   * `services.home_location_id` and `item_variants.home_location_id`: a real place of the same
--     business (not virtual, not the in-transit place, in use). A home place is advice for
--     put-away, counting and picking, never a balance: stock may sit elsewhere, and changing it
--     moves nothing and rewrites no history. A variant without a home of its own has its
--     item's.
--   * `set_stock_home_v1`: one command to set or clear it, at `manageStock`, once per request;
--     the trigger asks the same of a direct write to either table.
--   * `stock_registry_page_v1`: the registry, one row per item (per variant when it has any) with
--     its barcode, unit, retail price, last known cost (only for whoever may see finances or
--     manage purchases; an unknown cost stays null, never 0), home address and on-hand
--     quantity; filtered by a place (and the places in it) or by "no home place".

alter table public.services add column home_location_id uuid;
alter table public.item_variants add column home_location_id uuid;
alter table public.services
  add constraint services_home_location_fkey foreign key (workspace_id, home_location_id)
  references public.stock_locations (workspace_id, id);
alter table public.item_variants
  add constraint item_variants_home_location_fkey foreign key (workspace_id, home_location_id)
  references public.stock_locations (workspace_id, id);

create or replace function public.stock_home_check() returns trigger
language plpgsql set search_path = public as $fn$
begin
  if (tg_op = 'INSERT' and new.home_location_id is not null)
     or (tg_op = 'UPDATE' and new.home_location_id is distinct from old.home_location_id) then
    -- Whoever writes the home place, by this command or straight to the table, may manage the
    -- stock (a call with no signed-in person is the system's own: a migration, an import).
    if auth.uid() is not null and not public.has_permission(new.workspace_id, 'manageStock') then
      raise exception 'not allowed to configure the stock' using errcode = 'DKN01';
    end if;
    -- The place is read under a share lock: a concurrent deactivation of it (an update of its
    -- row) waits for this write, and a write that comes after sees it deactivated.
    if new.home_location_id is not null then
      perform 1 from public.stock_locations l
        join public.stock_location_kinds k on k.key = l.kind
       where l.id = new.home_location_id and l.workspace_id = new.workspace_id
         and l.active and not k.virtual and l.kind <> 'in_transit'
         for share of l;
      if not found then
        raise exception 'not a place an item can be kept at' using errcode = 'DKG11',
          detail = jsonb_build_object('field', 'home_location_id', 'reason', 'home_invalid')::text;
      end if;
    end if;
  end if;
  return new;
end
$fn$;
revoke execute on function public.stock_home_check() from public, anon, authenticated;
create trigger stock_home_check before insert or update of home_location_id on public.services
  for each row execute function public.stock_home_check();
create trigger stock_home_check before insert or update of home_location_id on public.item_variants
  for each row execute function public.stock_home_check();

-- ── set or clear the home place of an item or one of its variants ─────────
create or replace function public.set_stock_home_v1(
  p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_location_id uuid, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done public.purchase_requests;
  v_result jsonb;
begin
  perform public.stock_config_actor(p_workspace_id);
  if p_request_id is null or p_item_id is null then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('stock_home_set|' || p_item_id::text || '|' || coalesce(p_variant_id::text, '') || '|'
                  || coalesce(p_location_id::text, ''));
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'stock_home_set' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;
  if not exists (select 1 from public.services s
                  where s.id = p_item_id and s.workspace_id = p_workspace_id and s.stockable) then
    raise exception 'not an item of this business' using errcode = 'DKG04';
  end if;
  if p_variant_id is null then
    update public.services set home_location_id = p_location_id
     where id = p_item_id and workspace_id = p_workspace_id;
  else
    if not exists (select 1 from public.item_variants v
                    where v.id = p_variant_id and v.item_id = p_item_id and v.workspace_id = p_workspace_id) then
      raise exception 'not a variant of this item' using errcode = 'DKG04';
    end if;
    update public.item_variants set home_location_id = p_location_id
     where id = p_variant_id and workspace_id = p_workspace_id;
  end if;
  v_result := jsonb_build_object('item_id', p_item_id, 'variant_id', p_variant_id,
                                 'home_location_id', p_location_id, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'stock_home_set', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.set_stock_home_v1(uuid, uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.set_stock_home_v1(uuid, uuid, uuid, uuid, uuid) to authenticated;

-- ── the registry: bounded pages, never the whole catalogue ────────────────
create or replace function public.stock_registry_page_v1(
  p_workspace_id uuid, p_location_id uuid default null, p_no_home boolean default false,
  p_limit int default 50, p_after jsonb default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_zero constant uuid := '00000000-0000-0000-0000-000000000000';
  v_name text; v_item uuid; v_var uuid;
  v_cost boolean;
  v_rows jsonb; v_n int; v_last jsonb;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  v_cost := public.stock_sees_cost(p_workspace_id);
  if p_location_id is not null and not exists (
       select 1 from public.stock_locations l where l.id = p_location_id and l.workspace_id = p_workspace_id) then
    raise exception 'not a place of this business' using errcode = 'DKG05';
  end if;
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_name := p_after->>'name';
      v_item := (p_after->>'item_id')::uuid;
      v_var := coalesce((p_after->>'variant_id')::uuid, v_zero);
      if v_name is null or v_item is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when others then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with base as (
    select s.id as item_id, v.id as variant_id, s.name as item_name, s.inventory_unit as unit,
           coalesce(v.price_cents, s.price_cents) as price_cents,
           coalesce(v.home_location_id, s.home_location_id) as home_id
      from public.services s
      left join public.item_variants v on v.item_id = s.id and v.active
     where s.workspace_id = p_workspace_id and s.stockable
  ), page as (
    select b.*, h.address_path as home_path, h.code as home_code,
           (select c.code from public.item_codes c
             where c.item_id = b.item_id and (c.variant_id = b.variant_id or c.variant_id is null)
             order by (c.variant_id is null), (c.kind <> 'gtin'), c.created_datetime limit 1) as barcode,
           (select (l.total_cost_minor::numeric / l.quantity_received)::text from public.stock_lots l
             where v_cost and l.item_id = b.item_id and l.variant_id is not distinct from b.variant_id
               and l.cost_state = 'known' and l.quantity_received > 0
             order by l.created_datetime desc limit 1) as cost,
           (select coalesce(sum(bal.quantity), 0)::text from public.stock_balances bal
              join public.stock_locations bl on bl.id = bal.location_id
              join public.stock_location_kinds bk on bk.key = bl.kind
             where bal.item_id = b.item_id and bal.variant_id is not distinct from b.variant_id
               and not bk.virtual) as on_hand
      from base b
      left join public.stock_locations h on h.id = b.home_id
     where (not p_no_home or b.home_id is null)
       and (p_location_id is null or b.home_id in (select t.id from public.stock_place_tree(p_workspace_id, p_location_id) t))
       and (p_after is null or (b.item_name, b.item_id, coalesce(b.variant_id, v_zero)) > (v_name, v_item, v_var))
     order by b.item_name, b.item_id, coalesce(b.variant_id, v_zero)
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'item_id', item_id, 'item_name', item_name,
           'variant_id', variant_id, 'variant_label', public.stock_variant_label(variant_id),
           'barcode', barcode, 'unit', unit, 'price_cents', price_cents,
           'cost', cost, 'cost_visible', v_cost,
           'home_location_id', home_id, 'home_code', home_code, 'home_address_path', home_path,
           'on_hand', on_hand)
           order by item_name, item_id, coalesce(variant_id, v_zero)), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;                     -- drop the look-ahead row
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next', jsonb_build_object(
      'version', 1, 'name', v_last -> 'item_name', 'item_id', v_last -> 'item_id',
      'variant_id', v_last -> 'variant_id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_registry_page_v1(uuid, uuid, boolean, int, jsonb) from public, anon;
grant execute on function public.stock_registry_page_v1(uuid, uuid, boolean, int, jsonb) to authenticated;

select public.set_deskilo_schema_version(860);
