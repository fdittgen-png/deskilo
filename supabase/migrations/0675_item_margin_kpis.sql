-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0675 (#3294 step 4) -- items on purchase lines, and the figures they make
-- possible: what an item costs from each supplier, the margin each product
-- leaves when it is sold, and how each supplier's prices compare.
--
--   * `purchase_lines.service_id`: the catalogue item a line bought (a
--     service of the space, the consumables of #731 included), with its
--     quantity (refused at zero or below) and its unit, both captured by
--     the line writer already. A line without an item is as before. Lines of
--     a submitted document stay frozen: the item is captured on the draft.
--     A member's receipt that restocked a supply (#731) names its item in its
--     `supply` record by its id; the figures read that too. A supply named
--     only by its text is never matched to an item by name: it is counted
--     apart (`unresolved_lines`, or `ambiguous_lines` when several items
--     carry that name).
--   * `purchase.item_cost_method` (a workspace setting, default `average`):
--     what one unit costs when a sale is set against the purchases --
--     `average` weighs every approved purchase of the item dated up to the
--     end of the period, `last` takes the latest one dated by then.
--   * `kpi_item_margins(ws, from, to)`:
--       items.unit_prices    the item lines of the approved documents of the
--           months by item and supplier: units, cost (net plus the tax that
--           cannot be recovered, 0530's rule) and the unit price;
--       items.product_margin each item sold in the months (confirmed
--           consumptions, by their billing month): units, net revenue, the
--           unit cost by the method, the cost of those sales and the margin
--           left; an item never bought has no cost and is counted apart
--           (`uncosted`): the cost and margin are those of the costed items
--           (`partial`, `uncosted_items`), unknown when none is costed;
--       items.vendor_margin  how each supplier's prices compare: what the
--           items bought from it in the months cost above the lowest unit
--           price paid for the same item in the months (`premium_minor`).
--           A realised margin by supplier would need to know which purchase
--           a sale consumed; nothing records that, so `margin_minor` stays
--           unknown (`no_consumption_link`) instead of setting every unit
--           bought against the sale price.
--     Credit notes do not set a unit cost. A margin, never a profit: no other
--     cost is allocated here.
--   * `purchase_detail_v1` returns the item of each line.
--
-- Not here: delivery time and reliability need purchase orders and goods
-- receipts (#3294 step 5); stock is not valued (the shelf count of #731
-- stays a count).
--
-- Who reads: kpi_readable() -- viewAnalytics AND viewFinances -- with
-- `purchaseAnalytics` on, a signed-in person, not a delegated assistant.
-- Amounts travel as decimal STRINGS of minor units in the workspace currency
-- (a unit price rounded to the minor unit); another currency in scope leaves
-- every amount null (`currency_mix`), never summed; counts survive.

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

alter table public.purchase_lines
  add column if not exists service_id uuid references public.services(id) on delete set null;
alter table public.purchase_lines drop constraint if exists purchase_lines_item_quantity;
alter table public.purchase_lines
  add constraint purchase_lines_item_quantity check (service_id is null or quantity > 0);
create index if not exists purchase_lines_service on public.purchase_lines (service_id)
  where service_id is not null;

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
revoke execute on function public.purchase_write_lines(uuid, uuid, jsonb)
  from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.purchase_detail_v1(uuid,uuid)'::regprocedure) into v_def;
  -- Already naming the item (a re-run): nothing to patch.
  if position($a$'service_id', l.service_id$a$ in v_def) > 0 then return; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'unit', l.unit, 'gross_cents', l.gross_cents,$a$,
    $a$'unit', l.unit, 'service_id', l.service_id, 'gross_cents', l.gross_cents,$a$);
  if v_def is null then raise exception '0675: purchase_detail_v1 lines anchor missing'; end if;
  execute v_def;
end
$migration$;

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('purchase.item_cost_method', 'enum', '"average"'::jsonb, null, null, '', 'billing', array['workspace'], 'manageBilling', null, true, '["average","last"]'::jsonb, 'kpi_item_margins (#3294)', 'What one unit of an item costs when the analytics set its sales against its purchases: average weighs every approved purchase of the item up to the end of the period; last takes the latest purchase dated by then. It changes no document, only how the margin figures are read.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- The registry restated whole with the three figures (kpi_registry_sql_test
-- holds it equal to the Dart catalogue).
create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"operations.pending_actions_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"customers.payment_behaviour":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.dunning_load":{"version":1,"unit":"count","aggregation":"sum","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.credit_and_writeoff":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.concentration":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.category_spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.payment_punctuality":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"payable_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.billing_lag":{"version":1,"unit":"days","aggregation":"ratio_of_sums","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.revenue_by_kind":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.revenue_by_service":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.room_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"items.unit_prices":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"items.product_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"items.vendor_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.kpi_item_margins(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  -- A technical bound on the listed rows, not a business value.
  c_rows constant int := 20;
  v_currency text; v_tz text; v_now_month text;
  v_start date; v_cut date;
  v_method text; v_mixed boolean;
  v_lines jsonb; v_sales jsonb; v_cost jsonb;
  v_prices jsonb; v_products jsonb; v_vendors jsonb;
  v_unresolved int; v_ambiguous int;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'items.unit_prices')
     or not public.kpi_readable(p_workspace_id, 'items.product_margin') then
    raise exception 'not allowed to read the item figures of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'purchaseAnalytics') then
    raise exception 'the purchase figures are not enabled for this workspace'
      using errcode = '42501';
  end if;
  if p_from is null or p_to is null
     or p_from !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' or p_to !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     or p_from > p_to
     or to_date(p_to, 'YYYY-MM') > to_date(p_from, 'YYYY-MM') + interval '23 months' then
    raise exception 'the KPI months must be YYYY-MM, from <= to, at most 24 months'
      using errcode = '22023';
  end if;

  select w.currency_code, coalesce(nullif(w.timezone, ''), 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  if v_currency is null or btrim(v_currency) = '' then
    raise exception 'the workspace has no currency' using errcode = '22023';
  end if;
  v_currency := upper(v_currency);
  v_now_month := to_char(now() at time zone v_tz, 'YYYY-MM');
  v_start := to_date(p_from, 'YYYY-MM');
  v_cut := (to_date(p_to, 'YYYY-MM') + interval '1 month')::date - 1;
  v_method := coalesce(public.setting_value(p_workspace_id, 'purchase.item_cost_method') #>> '{}', 'average');
  if v_method not in ('average', 'last') then v_method := 'average'; end if;

  -- Every item line of an approved bill or receipt dated up to the end of
  -- the period: its item (the line's own, else the supply its receipt
  -- restocked), units, cost and supplier.
  with raw as (
    select l.id, l.created_datetime, d.supplier_id, upper(d.currency) as currency,
           coalesce(d.original_date, d.received_on) as dated,
           coalesce(l.service_id,
             (select s.id from public.services s
               where s.workspace_id = p_workspace_id
                 and s.id::text = l.supply ->> 'service_id')) as item,
           -- How many items carry the name of a supply that names no item:
           -- never a match, only counted.
           (select count(*) from public.services s
             where s.workspace_id = p_workspace_id
               and lower(btrim(s.name)) = lower(btrim(l.supply ->> 'name'))) as namesakes,
           case when l.service_id is null and (l.supply ->> 'quantity') ~ '^[0-9]+(\.[0-9]+)?$'
                then (l.supply ->> 'quantity')::numeric else l.quantity end as qty,
           case when l.net_cents is null then l.gross_cents
                when l.nonrecoverable_tax_cents is null then l.net_cents + l.tax_cents
                else l.net_cents + l.nonrecoverable_tax_cents end::bigint as cost
      from public.purchase_lines l
      join public.purchase_documents d on d.id = l.purchase_id and d.workspace_id = l.workspace_id
     where l.workspace_id = p_workspace_id and d.state = 'approved'
       and d.kind in ('bill', 'member_receipt')
       and coalesce(d.original_date, d.received_on) <= v_cut
       and (l.service_id is not null or l.supply is not null)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'item', r.item, 'supplier_id', r.supplier_id, 'currency', r.currency,
           'dated', r.dated, 'created', r.created_datetime, 'qty', r.qty, 'cost', r.cost,
           'in_range', r.dated >= v_start)) filter (where r.item is not null and r.qty > 0), '[]'::jsonb),
         count(*) filter (where r.item is null and r.dated >= v_start and r.namesakes <= 1),
         count(*) filter (where r.item is null and r.dated >= v_start and r.namesakes > 1)
    into v_lines, v_unresolved, v_ambiguous
    from raw r;

  -- What each item sold in the months: the confirmed consumptions, by their
  -- billing month, net of VAT.
  select coalesce(jsonb_agg(jsonb_build_object(
           'item', x.item, 'units', x.units, 'net', x.net)), '[]'::jsonb)
    into v_sales
    from (select (e.payload ->> 'service_id')::uuid as item,
                 sum(coalesce((e.payload ->> 'quantity')::numeric, 1)) as units,
                 sum(public.vat_split_net(le.amount_cents, coalesce(le.vat_percent, 0))) as net
            from public.events e
            join public.ledger_entries le on le.event_id = e.id and le.kind = 'charge'
           where e.workspace_id = p_workspace_id and e.type = 'service_charge'
             and e.status = 'confirmed' and le.period between p_from and p_to
             and (e.payload ->> 'service_id') ~ '^[0-9a-f-]{36}$'
           group by 1) x;

  v_mixed := exists (select 1 from jsonb_array_elements(v_lines) e
                      where e ->> 'currency' <> v_currency);

  -- What one unit of each item costs at the end of the period, by the method.
  with lines as (
    select * from jsonb_to_recordset(v_lines) x(
      item uuid, supplier_id uuid, currency text, dated date, created timestamptz,
      qty numeric, cost bigint, in_range boolean)
  )
  select coalesce(jsonb_object_agg(c.item, c.unit_cost), '{}'::jsonb)
    into v_cost
    from (select l.item,
                 case when v_method = 'last'
                      then (array_agg(l.cost / l.qty order by l.dated desc, l.created desc))[1]
                      else sum(l.cost) / nullif(sum(l.qty), 0) end as unit_cost
            from lines l group by 1) c;

  with lines as (
    select * from jsonb_to_recordset(v_lines) x(
      item uuid, supplier_id uuid, currency text, dated date, created timestamptz,
      qty numeric, cost bigint, in_range boolean)
  ), pairs as (
    select l.item, l.supplier_id, sum(l.qty) as units, sum(l.cost) as cost,
           row_number() over (order by sum(l.cost) desc, l.item, l.supplier_id) as rank
      from lines l where l.in_range group by 1, 2
  )
  select jsonb_build_object(
           'items', (select count(distinct item) from pairs),
           'lines', (select count(*) from lines where in_range),
           'unresolved_lines', v_unresolved,
           'ambiguous_lines', v_ambiguous,
           'cost_minor', case when v_mixed then null else (select coalesce(sum(cost), 0) from pairs)::text end,
           'rows', coalesce((select jsonb_agg(jsonb_build_object(
                     'item_id', p.item, 'item', s.name, 'supplier_id', p.supplier_id,
                     'supplier', sp.name, 'units', p.units,
                     'cost_minor', case when v_mixed then null else p.cost::text end,
                     'unit_price_minor', case when v_mixed then null else round(p.cost / p.units)::text end)
                   order by p.rank)
                   from pairs p
                   join public.services s on s.id = p.item
                   left join public.suppliers sp on sp.id = p.supplier_id
                  where p.rank <= c_rows), '[]'::jsonb))
    into v_prices;

  with sales as (
    select * from jsonb_to_recordset(v_sales) x(item uuid, units numeric, net bigint)
  ), costed as (
    select s.item, s.units, s.net, (v_cost ->> s.item::text)::numeric as unit_cost
      from sales s
  ), rows as (
    select c.*, case when c.unit_cost is null then null else round(c.units * c.unit_cost)::bigint end as cogs,
           row_number() over (order by c.net desc, c.item) as rank
      from costed c
  )
  select jsonb_build_object(
           'method', v_method,
           'items', count(*),
           'uncosted', count(*) filter (where unit_cost is null),
           'revenue_minor', case when v_mixed then null else coalesce(sum(net), 0)::text end,
           -- The cost and margin of the costed items only, with their
           -- revenue beside them; none costed: unknown, never 0.
           'costed_revenue_minor', case when v_mixed or (count(*) > 0 and count(cogs) = 0) then null
                                        else coalesce(sum(net) filter (where cogs is not null), 0)::text end,
           'cost_minor', case when v_mixed or (count(*) > 0 and count(cogs) = 0) then null
                              else coalesce(sum(cogs) filter (where cogs is not null), 0)::text end,
           'margin_minor', case when v_mixed or (count(*) > 0 and count(cogs) = 0) then null
                                else coalesce(sum(net - cogs) filter (where cogs is not null), 0)::text end,
           'rows', coalesce(jsonb_agg(jsonb_build_object(
                     'item_id', r.item, 'item', sv.name, 'units', r.units,
                     'revenue_minor', case when v_mixed then null else r.net::text end,
                     'unit_cost_minor', case when v_mixed or r.unit_cost is null then null
                                             else round(r.unit_cost)::text end,
                     'cost_minor', case when v_mixed then null else r.cogs::text end,
                     'margin_minor', case when v_mixed or r.cogs is null then null
                                          else (r.net - r.cogs)::text end)
                   order by r.rank) filter (where r.rank <= c_rows), '[]'::jsonb))
    into v_products
    from rows r join public.services sv on sv.id = r.item;

  -- Each supplier against the lowest unit price paid for the same item in
  -- the months: what its units cost above that price.
  with lines as (
    select * from jsonb_to_recordset(v_lines) x(
      item uuid, supplier_id uuid, currency text, dated date, created timestamptz,
      qty numeric, cost bigint, in_range boolean)
  ), bought as (
    select l.supplier_id, l.item, sum(l.qty) as units, sum(l.cost) as cost,
           sum(l.cost) / sum(l.qty) as unit_price
      from lines l
     where l.in_range and l.supplier_id is not null
     group by 1, 2
  ), priced as (
    select b.*, min(b.unit_price) over (partition by b.item) as lowest,
           count(*) over (partition by b.item) as offers
      from bought b
  ), per_supplier as (
    select p.supplier_id, count(*) as items,
           count(*) filter (where p.offers > 1) as compared,
           sum(p.units) as units, sum(p.cost) as cost,
           round(sum((p.unit_price - p.lowest) * p.units))::bigint as premium
      from priced p group by 1
  )
  select jsonb_build_object(
           'suppliers', count(*),
           'margin_minor', null,
           'premium_minor', case when v_mixed then null else coalesce(sum(premium), 0)::text end,
           'rows', coalesce(jsonb_agg(jsonb_build_object(
                     'supplier_id', p.supplier_id, 'supplier', sp.name,
                     'items', p.items, 'compared_items', p.compared, 'units', p.units,
                     'cost_minor', case when v_mixed then null else p.cost::text end,
                     'premium_minor', case when v_mixed then null else p.premium::text end)
                   order by p.premium desc, sp.name, p.supplier_id), '[]'::jsonb))
    into v_vendors
    from per_supplier p join public.suppliers sp on sp.id = p.supplier_id;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  -- The supplier margin is never known (see above); the products' margin
  -- leaves the uncosted items out.
  v_reasons := v_reasons || 'no_consumption_link'::text;
  if (v_products ->> 'uncosted')::int > 0 then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'uncosted_items'::text;
  end if;
  if v_unresolved + v_ambiguous > 0 then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'unresolved_items'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'items.margins', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz, 'cutoff', v_cut,
    'currency', v_currency,
    'cost_method', v_method,
    'unit_prices', v_prices,
    'products', v_products,
    'vendors', v_vendors,
    'quality', to_jsonb(array(select distinct q from unnest(v_quality) q order by q)),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_item_margins(uuid, text, text) from public, anon;
grant execute on function public.kpi_item_margins(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(675);
