-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0674 (#3294 step 3) -- the sales figures of the analytics page, on the
-- KPI contract (#1918), from the issued invoices' lines and the charges of
-- the rooms the space rents:
--
--   sales.revenue_by_kind     what the invoices of the months sold, by the
--       kind of line (subscriptions, extra half-days, accessories, levels,
--       offices, desks, services, packages, adjustments): net of VAT (a
--       line's own net when it carries one, a sales-tax line; else its gross
--       split at its own rate, vat_split_net; an explicit 0 is a rate, a
--       line without a readable one has no known net: counted in
--       `net_unknown_lines`, left out of the net sums, `net_unknown`), the
--       gross beside it, and by
--       month. Credits on an invoice (a payment, an expense reimbursement, a
--       settled invoice carried over) are not sales and stay out; a credit
--       note subtracts;
--   sales.revenue_by_service  the service and package lines by their
--       catalogue description, the largest first;
--   sales.room_margin         for each room the space rents (externalRooms),
--       the contribution it leaves: what its bookings were charged (the net
--       fees of the reservation charges not reversed, by their billing
--       month) minus the room's own cost -- the expected occurrences of its
--       rental's fixed cost falling due in the months, or its cost per use
--       times the uses. A margin, never a profit: no other cost is
--       allocated to the room here.
--
-- Not derivable yet: a product's margin needs items and quantities on
-- purchase lines and a cost price for services and supplements (#3294 step
-- 4); revenue by line kind is by the document's month, not by delivery.
--
-- Who reads: kpi_readable() -- viewAnalytics AND viewFinances -- with
-- `workspaceStatus` on, a signed-in person, not a delegated assistant;
-- the rooms only with `externalRooms` as well (otherwise null with the
-- reason `external_rooms_off`). Amounts travel as decimal STRINGS of minor
-- units in the workspace currency; another currency in scope leaves every
-- amount null (`currency_mix`), never summed; counts survive.

-- The registry restated whole with the three figures (kpi_registry_sql_test
-- holds it equal to the Dart catalogue).
create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"operations.pending_actions_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"customers.payment_behaviour":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.dunning_load":{"version":1,"unit":"count","aggregation":"sum","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.credit_and_writeoff":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.concentration":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.category_spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.payment_punctuality":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"payable_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.billing_lag":{"version":1,"unit":"days","aggregation":"ratio_of_sums","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.revenue_by_kind":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.revenue_by_service":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.room_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.kpi_sales_quality(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  -- A technical bound on the listed rows, not a business value.
  c_rows constant int := 10;
  v_currency text; v_tz text; v_now_month text;
  v_start date; v_cut date;
  v_rooms_on boolean; v_mixed boolean;
  v_lines jsonb; v_revenue jsonb; v_services jsonb; v_rooms jsonb;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'sales.revenue_by_kind')
     or not public.kpi_readable(p_workspace_id, 'sales.room_margin') then
    raise exception 'not allowed to read the sales figures of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'workspaceStatus') then
    raise exception 'the workspace status is not enabled for this workspace'
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
  v_rooms_on := public.feature_effective(p_workspace_id, 'externalRooms');

  -- Every sales line of the invoices of the months, net and gross.
  select coalesce(jsonb_agg(jsonb_build_object(
           'invoice_id', i.id, 'period', i.period,
           'currency', upper(coalesce(i.currency, v_currency)),
           'kind', coalesce(nullif(l ->> 'kind', ''), 'other'),
           'label', btrim(coalesce(l ->> 'label', '')),
           'gross', (l ->> 'amount_cents')::bigint,
           -- A line without its net is split by its own rate; an explicit 0
           -- is a rate, a missing or unreadable one leaves the net unknown.
           'net', coalesce((l ->> 'net_cents')::bigint,
                           case when (l ->> 'vat_percent') ~ '^[0-9]+(\.[0-9]+)?$'
                                then public.vat_split_net((l ->> 'amount_cents')::bigint,
                                                          (l ->> 'vat_percent')::numeric) end))), '[]'::jsonb)
    into v_lines
    from public.invoices i
    cross join lateral jsonb_array_elements(case when jsonb_typeof(i.lines) = 'array'
                                                 then i.lines else '[]'::jsonb end) l
   where i.workspace_id = p_workspace_id and i.voided_at is null
     and i.kind <> 'settlement' and i.period between p_from and p_to
     and coalesce(l ->> 'kind', '') not in ('payment', 'expense', 'settled_invoice');

  v_mixed := exists (
    select 1 from public.invoices i
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.kind <> 'settlement' and i.period between p_from and p_to
       and upper(coalesce(i.currency, v_currency)) <> v_currency);
  -- ... and the rooms' costs, which the margin reads.
  v_mixed := v_mixed or (v_rooms_on and exists (
    select 1 from public.room_rentals r
     where r.workspace_id = p_workspace_id and r.status <> 'draft'
       and upper(r.currency) <> v_currency));

  with lines as (
    select * from jsonb_to_recordset(v_lines) x(
      invoice_id uuid, period text, currency text, kind text, label text, gross bigint, net bigint)
  ), kinds as (
    select l.kind, count(*) as n, sum(l.net) as net, sum(l.gross) as gross
      from lines l group by 1
  ), months as (
    select l.period, sum(l.net) as net, sum(l.gross) as gross from lines l group by 1
  )
  select jsonb_build_object(
           'invoices', (select count(distinct invoice_id) from lines),
           'lines', (select count(*) from lines),
           'net_unknown_lines', (select count(*) from lines where net is null),
           'net_minor', case when v_mixed then null
                             when exists (select 1 from lines)
                                  and not exists (select 1 from lines where net is not null) then null
                             else (select coalesce(sum(net), 0) from lines)::text end,
           'gross_minor', case when v_mixed then null
                               else (select coalesce(sum(gross), 0) from lines)::text end,
           'kinds', coalesce((select jsonb_agg(jsonb_build_object(
                      'kind', k.kind, 'lines', k.n,
                      'net_minor', case when v_mixed then null else k.net::text end,
                      'gross_minor', case when v_mixed then null else k.gross::text end)
                    order by k.net desc nulls last, k.kind) from kinds k), '[]'::jsonb),
           'months', coalesce((select jsonb_agg(jsonb_build_object(
                       'month', m.period,
                       'net_minor', case when v_mixed then null else m.net::text end,
                       'gross_minor', case when v_mixed then null else m.gross::text end)
                     order by m.period) from months m), '[]'::jsonb))
    into v_revenue;

  with lines as (
    select * from jsonb_to_recordset(v_lines) x(
      invoice_id uuid, period text, currency text, kind text, label text, gross bigint, net bigint)
  ), services as (
    select l.label, l.kind, count(*) as n, sum(l.net) as net, sum(l.gross) as gross,
           row_number() over (order by sum(l.net) desc nulls last, l.label, l.kind) as rank
      from lines l where l.kind in ('service', 'package') group by 1, 2
  )
  select jsonb_build_object(
           'services', count(*),
           'net_minor', case when v_mixed or (count(*) > 0 and count(net) = 0) then null
                             else coalesce(sum(net), 0)::text end,
           'rows', coalesce(jsonb_agg(jsonb_build_object(
                     'rank', rank, 'name', label, 'kind', kind, 'lines', n,
                     'net_minor', case when v_mixed then null else net::text end,
                     'gross_minor', case when v_mixed then null else gross::text end)
                   order by rank) filter (where rank <= c_rows), '[]'::jsonb))
    into v_services
    from services;

  if v_rooms_on then
    with charged as (
      select c.rental_id, count(*) as uses, sum(c.amount_cents)::bigint as charges
        from public.reservation_charges c
       where c.workspace_id = p_workspace_id and c.reversed_at is null
         and c.period between p_from and p_to
       group by 1
    ), expected as (
      select s.contract_id as rental_id, sum(o.amount_cents)::bigint as cost
        from public.expense_schedules s
        join public.expense_occurrences o on o.schedule_id = s.id
       where s.workspace_id = p_workspace_id and s.origin = 'workspace_contract'
         and o.status <> 'rejected' and o.due_on between v_start and v_cut
       group by 1
    ), rooms as (
      select r.id, r.office_id, btrim(o.name) as name, r.cost_kind,
             coalesce(c.uses, 0) as uses, coalesce(c.charges, 0) as charges,
             case when r.cost_kind = 'per_use' then r.cost_cents * coalesce(c.uses, 0)
                  else coalesce(e.cost, 0) end as cost
        from public.room_rentals r
        join public.offices o on o.id = r.office_id
        left join charged c on c.rental_id = r.id
        left join expected e on e.rental_id = r.id
       where r.workspace_id = p_workspace_id
         and (c.rental_id is not null or e.rental_id is not null
              or (r.status = 'active' and r.available_from <= v_cut
                  and (r.available_until is null or r.available_until >= v_start)))
    )
    select jsonb_build_object(
             'rooms', count(*),
             'uses', coalesce(sum(uses), 0),
             'charges_minor', case when v_mixed then null else coalesce(sum(charges), 0)::text end,
             'cost_minor', case when v_mixed then null else coalesce(sum(cost), 0)::text end,
             'margin_minor', case when v_mixed then null else coalesce(sum(charges - cost), 0)::text end,
             'rows', coalesce(jsonb_agg(jsonb_build_object(
                       'office_id', office_id, 'name', name, 'cost_kind', cost_kind, 'uses', uses,
                       'charges_minor', case when v_mixed then null else charges::text end,
                       'cost_minor', case when v_mixed then null else cost::text end,
                       'margin_minor', case when v_mixed then null else (charges - cost)::text end)
                     order by charges - cost desc, name, office_id), '[]'::jsonb))
      into v_rooms
      from rooms;
  end if;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;
  if exists (select 1 from jsonb_array_elements(v_lines) e where e -> 'net' = 'null'::jsonb) then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'net_unknown'::text;
  end if;
  if not v_rooms_on then
    v_reasons := v_reasons || 'external_rooms_off'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'sales.quality', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz, 'cutoff', v_cut,
    'currency', v_currency,
    'revenue', v_revenue,
    'services', v_services,
    'rooms', v_rooms,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_sales_quality(uuid, text, text) from public, anon;
grant execute on function public.kpi_sales_quality(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(674);
