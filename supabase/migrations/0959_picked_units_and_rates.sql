-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4471 -- a unit and a VAT rate are picked from the master data, never typed. The server says no to a unit that is not one of
-- the business's units of measure (or, for a line of an item, one the item declares itself: its item units, its mapping's
-- purchase unit, its inventory unit) and to a VAT rate that is not one of its active rates.
--   * `unit_is_pickable` / `vat_percent_is_known`: the one answer, read by every command below.
--   * the purchase order's save (`save_purchase_order_v1`, restates 0681 whole): every line is checked when the order is
--     saved, so a line already stored with a free value is untouched until the order is edited (a receipt moving the received
--     quantity never trips it), and the replenishment draft, which fills a line from the item's own purchase unit, stays valid.
--   * the bill lines of an item (`purchase_write_lines`, restates 0675 whole) and a direct engagement
--     (`service_fulfilment_direct_scope`, restates 0852 whole).
-- A refusal is the stock configuration's own (DKG11, the field and the reason in the detail, `unit_unknown` and
-- `vat_rate_unknown`), or the engagement's (DKF06, detail `unit`).

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

-- restates 0681 (save_purchase_order_v1)
create or replace function public.save_purchase_order_v1(
  p_workspace_id uuid, p_request_id uuid, p_expected_revision int, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_order public.purchase_orders;
  v_id uuid := nullif(p_payload ->> 'order_id', '')::uuid;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_currency text;
  v_tz text;
  v_year int;
  v_number int;
  v_email text := btrim(coalesce(p_payload ->> 'recipient_email', ''));
  e jsonb;
  n int := 0;
  v_item uuid;
  v_desc text;
  v_qty numeric;
  v_price bigint;
  v_rate numeric;
begin
  v_me := public.purchase_order_actor(p_workspace_id);
  if p_request_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'an order and a request id are required' using errcode = '22023';
  end if;
  v_digest := md5(p_payload::text || coalesce(p_expected_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'order_save', v_digest);
  if v_done is not null then return v_done; end if;

  if v_supplier is null or not exists (
       select 1 from public.suppliers s
        where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'an order goes to an active supplier of the space' using errcode = '22023';
  end if;
  select upper(w.currency_code), coalesce(nullif(w.timezone, ''), 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  v_currency := upper(coalesce(nullif(btrim(p_payload ->> 'currency'), ''), v_currency));
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'unknown currency' using errcode = '22023';
  end if;
  if v_email <> '' and (v_email !~ '^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$' or v_email ~ '[\r\n]') then
    raise exception 'the address the order is e-mailed to is not an e-mail address' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_payload -> 'lines'), '') <> 'array'
     or jsonb_array_length(p_payload -> 'lines') not between 1 and 200 then
    raise exception 'an order has between 1 and 200 lines' using errcode = '22023';
  end if;

  if v_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then
      raise exception 'a new order has no revision yet' using errcode = '40001';
    end if;
    v_year := extract(year from (now() at time zone v_tz))::int;
    insert into public.purchase_order_counters (workspace_id, year, last_number)
    values (p_workspace_id, v_year, 1)
    on conflict (workspace_id, year) do update
      set last_number = public.purchase_order_counters.last_number + 1
    returning last_number into v_number;
    insert into public.purchase_orders
      (workspace_id, year, number, supplier_id, currency, expected_on, note, recipient_email,
       created_by_member_id)
    values (p_workspace_id, v_year, v_number, v_supplier, v_currency,
            nullif(p_payload ->> 'expected_on', '')::date,
            left(coalesce(p_payload ->> 'note', ''), 1000), v_email, v_me)
    returning * into v_order;
  else
    select * into v_order from public.purchase_orders
     where id = v_id and workspace_id = p_workspace_id for update;
    if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
    if v_order.state <> 'draft' then
      raise exception 'only a draft purchase order is edited' using errcode = '22023';
    end if;
    if v_order.revision <> coalesce(p_expected_revision, -1) then
      raise exception 'stale revision' using errcode = '40001';
    end if;
    perform public.purchase_order_no_send_in_flight(v_order.id);
    update public.purchase_orders set
        revision = revision + 1, supplier_id = v_supplier, currency = v_currency,
        expected_on = nullif(p_payload ->> 'expected_on', '')::date,
        note = left(coalesce(p_payload ->> 'note', ''), 1000), recipient_email = v_email
      where id = v_order.id
      returning * into v_order;
    delete from public.purchase_order_lines where order_id = v_order.id;
  end if;

  for e in select value from jsonb_array_elements(p_payload -> 'lines') loop
    n := n + 1;
    v_item := nullif(e ->> 'service_id', '')::uuid;
    if v_item is not null and not exists (
         select 1 from public.services s where s.id = v_item and s.workspace_id = p_workspace_id) then
      raise exception 'unknown item' using errcode = '22023';
    end if;
    v_desc := btrim(coalesce(e ->> 'description', ''));
    if v_desc = '' and v_item is not null then
      select s.name into v_desc from public.services s where s.id = v_item;
    end if;
    if v_desc = '' then
      raise exception 'a line names an item or describes what is ordered' using errcode = '22023';
    end if;
    v_qty := nullif(e ->> 'quantity', '')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception 'a line is ordered in a quantity above zero' using errcode = '22023';
    end if;
    v_price := nullif(e ->> 'unit_price_cents', '')::bigint;
    if v_price is null or v_price < 0 then
      raise exception 'a line has a unit price' using errcode = '22023';
    end if;
    v_rate := nullif(e ->> 'vat_rate_percent', '')::numeric;
    -- #4471 -- the unit and the rate are the master data's: the business's units (or the item's own), its VAT rates.
    if not public.unit_is_pickable(p_workspace_id, e ->> 'unit', v_item) then
      perform public.stock_config_refuse(format('lines[%s].unit', n - 1), 'unit_unknown');
    end if;
    if not public.vat_percent_is_known(p_workspace_id, v_rate) then
      perform public.stock_config_refuse(format('lines[%s].vat_rate_percent', n - 1), 'vat_rate_unknown');
    end if;
    insert into public.purchase_order_lines
      (workspace_id, order_id, line_no, service_id, description, quantity, unit,
       unit_price_cents, vat_rate_percent)
    values (p_workspace_id, v_order.id, n, v_item, left(v_desc, 500), v_qty,
            left(btrim(coalesce(e ->> 'unit', '')), 20), v_price, v_rate);
  end loop;

  return public.purchase_request_end(p_workspace_id, p_request_id, 'order_save', v_digest,
                                     public.purchase_order_json(v_order.id));
end;
$fn$;
revoke execute on function public.save_purchase_order_v1(uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.save_purchase_order_v1(uuid, uuid, int, jsonb) to authenticated;

-- restates 0675 (purchase_write_lines)
create or replace function public.purchase_write_lines(
  p_workspace_id uuid, p_purchase_id uuid, p_lines jsonb
) returns void language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  n int := 0;
  v_gross bigint;
  v_net bigint;
  v_tax bigint;
  v_rec bigint;
  v_kind text;
  v_site uuid;
  v_rkind text;
  v_rid uuid;
  v_found boolean;
  v_rsite uuid;
  v_item uuid;
  v_qty numeric;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 200 then
    raise exception 'a purchase has between 1 and 200 lines';
  end if;
  delete from public.purchase_lines where purchase_id = p_purchase_id;
  for e in select value from jsonb_array_elements(p_lines) loop
    n := n + 1;
    v_gross := (e ->> 'gross_cents')::bigint;
    if v_gross is null or v_gross < 0 then raise exception 'a line needs a gross amount'; end if;
    v_net := nullif(e ->> 'net_cents', '')::bigint;
    v_tax := nullif(e ->> 'tax_cents', '')::bigint;
    if (v_net is null) <> (v_tax is null) then
      raise exception 'net and tax are given together or not at all';
    end if;
    if v_net is not null and v_net + v_tax <> v_gross then
      raise exception 'net plus tax is not the gross amount';
    end if;
    v_rec := nullif(e ->> 'recoverable_tax_cents', '')::bigint;
    if v_rec is not null and (v_tax is null or v_rec < 0 or v_rec > v_tax) then
      raise exception 'the recoverable tax lies between 0 and the tax';
    end if;
    v_kind := coalesce(nullif(e ->> 'recognition_kind', ''), 'unresolved');
    -- Where the cost belongs: the space's own site and resource, never
    -- another space's; a resource alone names its site.
    v_site := nullif(e ->> 'cost_site_id', '')::uuid;
    v_rkind := nullif(e ->> 'resource_kind', '');
    v_rid := nullif(e ->> 'resource_id', '')::uuid;
    if (v_rkind is null) <> (v_rid is null) then
      raise exception 'a resource is named by its kind and its id';
    end if;
    if v_rkind is not null then
      if v_rkind not in ('level', 'office', 'desk', 'seat') then
        raise exception 'unknown resource kind';
      end if;
      v_found := false;
      v_rsite := null;
      select r.found, r.site_id into v_found, v_rsite
        from public.purchase_resource_site(p_workspace_id, v_rkind, v_rid) r;
      if not coalesce(v_found, false) then raise exception 'unknown resource'; end if;
      if v_site is not null and v_rsite is not null and v_site <> v_rsite then
        raise exception 'the resource lies on another site';
      end if;
      v_site := coalesce(v_site, v_rsite);
    end if;
    -- #3294 step 4 -- the item the line bought: a catalogue entry of this
    -- space, with how many of it; an item without a quantity is refused.
    v_item := nullif(e ->> 'service_id', '')::uuid;
    v_qty := coalesce(nullif(e ->> 'quantity', '')::numeric, 1);
    if v_item is not null then
      if not exists (select 1 from public.services s
                      where s.id = v_item and s.workspace_id = p_workspace_id) then
        raise exception 'unknown item';
      end if;
      if nullif(e ->> 'quantity', '') is null or v_qty <= 0 then
        raise exception 'an item is bought in a quantity above zero';
      end if;
      -- #4471 -- the unit of an item's line is a unit of the master data, or one the item declares itself.
      if not public.unit_is_pickable(p_workspace_id, e ->> 'unit', v_item) then
        perform public.stock_config_refuse(format('lines[%s].unit', n - 1), 'unit_unknown');
      end if;
    end if;
    if v_site is not null and not exists (
         select 1 from public.sites s where s.id = v_site and s.workspace_id = p_workspace_id) then
      raise exception 'unknown site';
    end if;
    insert into public.purchase_lines
      (workspace_id, purchase_id, line_no, description, quantity, unit, gross_cents,
       net_cents, tax_cents, tax_rate_percent, recoverable_tax_cents,
       nonrecoverable_tax_cents, tax_component_keys, supply, recognition_kind,
       cost_site_id, resource_kind, resource_id, service_id)
    values
      (p_workspace_id, p_purchase_id, n, left(coalesce(e ->> 'description', ''), 500),
       v_qty, left(coalesce(e ->> 'unit', ''), 20),
       v_gross, v_net, v_tax, nullif(e ->> 'tax_rate_percent', '')::numeric, v_rec,
       case when v_rec is null then null else v_tax - v_rec end,
       coalesce(array(select jsonb_array_elements_text(e -> 'tax_component_keys')), '{}'),
       e -> 'supply', v_kind, v_site, v_rkind, v_rid, v_item);
  end loop;
end;
$fn$;

revoke execute on function public.purchase_write_lines(uuid, uuid, jsonb)
  from public, anon, authenticated;

-- restates 0852 (service_fulfilment_direct_scope)
create or replace function public.service_fulfilment_direct_scope(p_workspace uuid, p_scope jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_subject uuid; v_item uuid; v_variant uuid;
  v_desc text; v_qty numeric; v_unit text;
begin
  if p_scope is null or jsonb_typeof(p_scope) <> 'object' then
    raise exception 'the scope of the engagement is missing' using errcode = 'DKF06', detail = 'scope';
  end if;
  begin v_subject := (p_scope ->> 'subject_id')::uuid; exception when others then v_subject := null; end;
  if v_subject is null or not public.billing_customer_ok(p_workspace, v_subject) then
    raise exception 'the customer is unknown' using errcode = 'DKF01', detail = 'subject';
  end if;
  v_desc := btrim(coalesce(p_scope ->> 'description', ''));
  if v_desc = '' or char_length(v_desc) > 200 then
    raise exception 'the description is needed' using errcode = 'DKF06', detail = 'description';
  end if;
  begin v_qty := (p_scope ->> 'quantity')::numeric; exception when others then v_qty := null; end;
  if v_qty is null or v_qty <= 0 or v_qty > 1000000 then
    raise exception 'the quantity is out of range' using errcode = 'DKF06', detail = 'quantity';
  end if;
  v_unit := btrim(coalesce(p_scope ->> 'unit', ''));
  if char_length(v_unit) > 40 then
    raise exception 'the unit is too long' using errcode = 'DKF06', detail = 'unit';
  end if;
  begin v_item := nullif(p_scope ->> 'item_id', '')::uuid; exception when others then
    raise exception 'unknown item' using errcode = 'DKF01', detail = 'item'; end;
  begin v_variant := nullif(p_scope ->> 'variant_id', '')::uuid; exception when others then
    raise exception 'unknown variant' using errcode = 'DKF01', detail = 'variant'; end;
  if v_item is not null and not exists (
       select 1 from public.services s where s.id = v_item and s.workspace_id = p_workspace) then
    raise exception 'unknown item' using errcode = 'DKF01', detail = 'item';
  end if;
  -- #4471 -- the unit is one of the master data, or one the item declares itself.
  if not public.unit_is_pickable(p_workspace, v_unit, v_item) then
    raise exception 'the unit is not one of the business''s units' using errcode = 'DKF06', detail = 'unit';
  end if;
  if v_variant is not null and (v_item is null or not exists (
       select 1 from public.item_variants v
        where v.id = v_variant and v.item_id = v_item and v.workspace_id = p_workspace)) then
    raise exception 'unknown variant' using errcode = 'DKF01', detail = 'variant';
  end if;
  return jsonb_build_object('subject_id', v_subject, 'item_id', v_item, 'variant_id', v_variant,
    'scope', jsonb_build_object('description', v_desc, 'quantity', trim_scale(v_qty)::text, 'unit', v_unit,
      'item', (select s.name from public.services s where s.id = v_item),
      'variant', (select v.canonical from public.item_variants v where v.id = v_variant)));
end
$fn$;
revoke execute on function public.service_fulfilment_direct_scope(uuid, jsonb) from public, anon, authenticated;

select public.set_deskilo_schema_version(959);
