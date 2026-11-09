-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0699 (#3294 step 5) -- the vendor delivery figure of the analytics page, on
-- the KPI contract (#1918), from the purchase orders the space SENT in the
-- months and their goods receipts (0681, 0684):
--
--   vendors.delivery   each order sent in the months lands in exactly one
--       cohort: on time (received, its last receipt on or before the expected
--       date), late (received after it), unknown_expected (received, no
--       expected date), partial (some received, the rest awaited), overdue
--       (nothing received, the expected date passed) or open; the share of
--       the received orders that named a date and arrived by it; the days
--       from sending to the last receipt (median, 90th percentile) and from
--       the expected date to it (negative = early); by supplier.
--
-- It is one more key of `kpi_vendor_quality` (`delivery`): the function is
-- patched at three asserted anchors (a declaration, the answer's last key, the
-- computation before the quality flags), read by the same figures' authority
-- (kpi_readable + purchaseAnalytics). With `purchaseOrders` off the cohorts
-- are zero and the reason `purchase_orders_off` says so.

-- The registry restated whole with the figure (kpi_registry_sql_test holds it
-- equal to the Dart catalogue).
create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"operations.pending_actions_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"customers.payment_behaviour":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.dunning_load":{"version":1,"unit":"count","aggregation":"sum","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.credit_and_writeoff":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.concentration":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.category_spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.payment_punctuality":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"payable_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.billing_lag":{"version":1,"unit":"days","aggregation":"ratio_of_sums","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.delivery":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.revenue_by_kind":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.revenue_by_service":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"sales.room_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"items.unit_prices":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"items.product_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"items.vendor_margin":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb;
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

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
  v_step record;
begin
  select pg_get_functiondef('public.kpi_vendor_quality(uuid,text,text)'::regprocedure) into v_def;
  for v_step in
    select * from (values
      (1, 'declarations',
       $old$  v_docs jsonb; v_spend jsonb; v_categories jsonb; v_due jsonb; v_payment jsonb; v_lag jsonb;$old$,
       $new$  v_docs jsonb; v_spend jsonb; v_categories jsonb; v_due jsonb; v_payment jsonb; v_lag jsonb;
  v_delivery jsonb; v_today date;$new$),
      (2, 'the delivery figure, before the quality flags',
       $old$  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;$old$,
       $new$  -- ── delivery: the purchase orders sent in the months (0699) ─────────────
  v_today := (now() at time zone v_tz)::date;
  with ord as (
    select o.id, o.supplier_id, o.expected_on, o.state,
           (o.sent_at at time zone v_tz)::date as sent_on,
           (select max(r.received_on) from public.purchase_order_receipts r where r.order_id = o.id) as last_on
      from public.purchase_orders o
     where o.workspace_id = p_workspace_id and o.sent_at is not null and o.state <> 'cancelled'
       and (o.sent_at at time zone v_tz)::date between v_start and v_cut
  ), cls as (
    select o.*,
           case when o.state = 'received' and (o.expected_on is null or o.last_on is null) then 'unknown_expected'
                when o.state = 'received' and o.last_on <= o.expected_on then 'on_time'
                when o.state = 'received' then 'late'
                when o.state = 'partly_received' then 'partial'
                when o.expected_on is not null and o.expected_on < v_today then 'overdue'
                else 'open' end as cohort,
           case when o.state = 'received' and o.last_on is not null then o.last_on - o.sent_on end as lead_days,
           case when o.state = 'received' and o.expected_on is not null and o.last_on is not null
                then o.last_on - o.expected_on end as delay_days
      from ord o
  ), per_supplier as (
    select c.supplier_id, count(*) as orders,
           count(*) filter (where c.cohort = 'on_time') as on_time,
           count(*) filter (where c.cohort = 'late') as late,
           percentile_disc(0.5) within group (order by c.lead_days) filter (where c.lead_days is not null) as median_lead
      from cls c group by 1
  )
  select jsonb_build_object(
           'orders', (select count(*) from cls),
           'cohorts', (select jsonb_object_agg(k.cohort, coalesce(g.n, 0))
                         from unnest(array['on_time', 'late', 'unknown_expected', 'partial', 'overdue', 'open']) k(cohort)
                         left join (select cohort, count(*) as n from cls group by 1) g on g.cohort = k.cohort),
           'median_lead_days', (select percentile_disc(0.5) within group (order by c.lead_days) from cls c),
           'p90_lead_days', (select percentile_disc(0.9) within group (order by c.lead_days) from cls c),
           'median_delay_days', (select percentile_disc(0.5) within group (order by c.delay_days) from cls c),
           'p90_delay_days', (select percentile_disc(0.9) within group (order by c.delay_days) from cls c),
           'rows', coalesce((select jsonb_agg(jsonb_build_object(
                     'supplier_id', p.supplier_id, 'name', s.name, 'orders', p.orders,
                     'on_time', p.on_time, 'late', p.late, 'median_lead_days', p.median_lead)
                   order by p.orders desc, s.name, p.supplier_id)
                   from per_supplier p join public.suppliers s on s.id = p.supplier_id), '[]'::jsonb))
    into v_delivery;
  if not public.feature_effective(p_workspace_id, 'purchaseOrders') then
    v_reasons := v_reasons || 'purchase_orders_off'::text;
  end if;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;$new$),
      (3, 'the answer carries it',
       $old$    'billing_lag', v_lag,$old$,
       $new$    'billing_lag', v_lag,
    'delivery', v_delivery,$new$)
    ) as s(n, what, old_text, new_text) order by n
  loop
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '0699: kpi_vendor_quality anchor % (%) missing', v_step.n, v_step.what;
    end if;
  end loop;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(699);
