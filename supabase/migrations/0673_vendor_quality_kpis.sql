-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0673 (#3294 step 2) -- the purchase and vendor figures of the analytics
-- page, on the KPI contract (#1918), from the approved purchase documents,
-- their lines, the supplier payables and the payments recorded against them:
--
--   vendors.spend                what the approved documents of the months
--       cost, by supplier: the net plus the tax that cannot be recovered (the
--       gross when the recoverable share is not qualified, 0530's rule); a
--       credit note subtracts; the five largest suppliers' share beside it;
--   vendors.category_spend       the same cost by the document's category;
--   vendors.payment_punctuality  the supplier payables falling due in the
--       months, each in one cohort (on time, late, settled without a payment
--       date, partly paid, open, on hold, no due date), by count and amount;
--       the delay of a settled payable is the day its last payment was
--       REPORTED paid (the bank's value date when the payment carries one)
--       minus its due date; median, 90th percentile, amount-weighted mean;
--   vendors.billing_lag          the days from the date a supplier put on a
--       bill to the day it reached the space, over the bills of the months
--       that carry both, by supplier.
--
-- Delivery time and reliability need purchase orders and receipts (#3294
-- step 5); unit prices and margins by vendor need items on purchase lines
-- (step 4): neither is computed here.
--
-- Who reads: kpi_readable() -- viewAnalytics AND viewFinances -- with
-- `purchaseAnalytics` on, a signed-in person, not a delegated assistant.
-- Suppliers are businesses the space records under its finance rights, so
-- their names travel with the figures. Amounts travel as decimal STRINGS of
-- minor units in the workspace currency; another currency in scope leaves
-- every amount null (`currency_mix`), never summed; counts and days survive.

-- The registry restated whole with the four figures (kpi_registry_sql_test
-- holds it equal to the Dart catalogue).
create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"operations.pending_actions_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"customers.payment_behaviour":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.dunning_load":{"version":1,"unit":"count","aggregation":"sum","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.credit_and_writeoff":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.concentration":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.category_spend":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.payment_punctuality":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"payable_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"vendors.billing_lag":{"version":1,"unit":"days","aggregation":"ratio_of_sums","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.kpi_vendor_quality(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  -- How many of the largest suppliers the share counts: part of the
  -- figure's definition (vendors.spend), not a setting.
  c_top constant int := 5;
  -- A technical bound on the listed rows, not a business value.
  c_rows constant int := 10;
  v_currency text; v_tz text; v_now_month text;
  v_start date; v_cut date;
  v_mixed boolean;
  v_docs jsonb; v_spend jsonb; v_categories jsonb; v_due jsonb; v_payment jsonb; v_lag jsonb;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'vendors.spend')
     or not public.kpi_readable(p_workspace_id, 'vendors.payment_punctuality') then
    raise exception 'not allowed to read the vendor figures of this workspace'
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

  -- What each approved document of the months cost, signed (a credit note
  -- subtracts), with its supplier and category.
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id, 'supplier_id', d.supplier_id,
           'category', coalesce(nullif(btrim(d.category), ''), ''), 'kind', d.kind,
           'currency', upper(d.currency),
           'cost', (case when d.kind = 'credit_note' then -1 else 1 end) * coalesce((
             select sum(case when l.net_cents is null then l.gross_cents
                             when l.nonrecoverable_tax_cents is null then l.net_cents + l.tax_cents
                             else l.net_cents + l.nonrecoverable_tax_cents end)
               from public.purchase_lines l where l.purchase_id = d.id), 0)::bigint,
           'original_date', d.original_date, 'received_on', d.received_on)), '[]'::jsonb)
    into v_docs
    from public.purchase_documents d
   where d.workspace_id = p_workspace_id and d.state = 'approved'
     and d.kind in ('bill', 'credit_note', 'member_receipt')
     and coalesce(d.original_date, d.received_on) between v_start and v_cut;

  -- The supplier payables falling due in the months, and the ones without
  -- a due date on a document of the months; each in exactly one cohort.
  with base as (
    select o.id, o.creditor_supplier_id as supplier_id, o.amount_cents::bigint as total,
           upper(o.currency) as currency, o.due_on, o.state,
           coalesce((select sum(a.amount_cents) from public.purchase_settlement_allocations a
                      where a.obligation_id = o.id), 0)::bigint as settled_cents,
           (select max(coalesce(p.value_date, p.reported_paid_on))
              from public.purchase_settlement_allocations a
              join public.outgoing_payments p on p.workspace_id = a.workspace_id and p.id = a.payment_id
             where a.obligation_id = o.id and a.kind = 'payment'
               and p.state in ('reported', 'reconciled')
               and not exists (select 1 from public.purchase_settlement_allocations r
                                where r.original_allocation_id = a.id)) as pay_date
      from public.purchase_obligations o
      join public.purchase_documents d on d.id = o.purchase_id
     where o.workspace_id = p_workspace_id and o.creditor_kind = 'supplier'
       and o.state <> 'cancelled' and d.state = 'approved'
       and ((o.due_on between v_start and v_cut)
            or (o.due_on is null
                and coalesce(d.original_date, d.received_on) between v_start and v_cut))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'supplier_id', b.supplier_id, 'total', b.total, 'currency', b.currency,
           'cohort', case when b.due_on is null then 'unknown_due'
              when b.settled_cents >= b.total and b.pay_date is null then 'undated'
              when b.settled_cents >= b.total and b.pay_date <= b.due_on then 'on_time'
              when b.settled_cents >= b.total then 'late'
              when b.state = 'held' then 'held'
              when b.settled_cents > 0 then 'partial'
              else 'open' end,
           'days', case when b.settled_cents >= b.total and b.due_on is not null
                         and b.pay_date is not null
                        then b.pay_date - b.due_on end)), '[]'::jsonb)
    into v_due
    from base b;

  v_mixed := exists (select 1 from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs where currency <> v_currency)
          or exists (select 1 from jsonb_array_elements(v_due) e where e ->> 'currency' <> v_currency);

  -- The cost by supplier, the largest first; a document without a supplier
  -- (a member's receipt) is the unassigned rest.
  with by_supplier as (
    select d.supplier_id, sum(d.cost) as cost, count(*) as docs
      from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as d where d.supplier_id is not null group by 1
  ), ranked as (
    select b.*, s.name, row_number() over (order by b.cost desc, b.supplier_id) as rank
      from by_supplier b join public.suppliers s on s.id = b.supplier_id
  )
  select jsonb_build_object(
           'documents', (select count(*) from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs where kind <> 'credit_note'),
           'credit_notes', (select count(*) from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs where kind = 'credit_note'),
           'cost_minor', case when v_mixed then null
                              else (select coalesce(sum(cost), 0) from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs)::text end,
           'credited_minor', case when v_mixed then null
                                  else (select coalesce(-sum(cost), 0) from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs
                                         where kind = 'credit_note')::text end,
           'unassigned_minor', case when v_mixed then null
                                    else (select coalesce(sum(cost), 0) from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs
                                           where supplier_id is null)::text end,
           'top_count', c_top,
           'suppliers', (select count(*) from ranked),
           'top_cost_minor', case when v_mixed then null
                                  else (select coalesce(sum(cost), 0) from ranked
                                         where rank <= c_top)::text end,
           'rows', coalesce((select jsonb_agg(jsonb_build_object(
                     'rank', r.rank, 'supplier_id', r.supplier_id, 'name', r.name,
                     'documents', r.docs,
                     'cost_minor', case when v_mixed then null else r.cost::text end)
                   order by r.rank) from ranked r where r.rank <= c_rows), '[]'::jsonb),
           'months', coalesce((select jsonb_agg(jsonb_build_object(
                       'month', m.month,
                       'cost_minor', case when v_mixed then null else m.cost::text end)
                     order by m.month)
                     from (select to_char(coalesce(original_date, received_on), 'YYYY-MM') as month,
                                  sum(cost) as cost
                             from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as docs group by 1) m), '[]'::jsonb))
    into v_spend;

  select jsonb_build_object(
           'categories', count(*),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
                     'category', c.category,
                     'documents', c.docs,
                     'cost_minor', case when v_mixed then null else c.cost::text end)
                   order by c.rank) filter (where c.rank <= c_rows), '[]'::jsonb))
    into v_categories
    from (select d.category, sum(d.cost) as cost, count(*) as docs,
                 row_number() over (order by sum(d.cost) desc, d.category) as rank
            from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as d group by 1) c;

  with due as (
    select * from jsonb_to_recordset(v_due) d(
      supplier_id uuid, total bigint, currency text, cohort text, days int)
  ), cohorts as (
    select d.cohort, count(*) as n, sum(d.total) as amount from due d group by 1
  ), settled as (
    select d.days, d.total from due d where d.days is not null
  ), per_supplier as (
    select d.supplier_id, count(*) as due,
           count(*) filter (where d.cohort = 'on_time') as on_time,
           count(*) filter (where d.cohort = 'late') as late,
           percentile_disc(0.5) within group (order by d.days)
             filter (where d.days is not null) as median_days
      from due d group by 1
  )
  select jsonb_build_object(
           'cohorts', (
             select jsonb_object_agg(k.cohort, jsonb_build_object(
                      'count', coalesce(g.n, 0),
                      'minor', case when v_mixed then null else coalesce(g.amount, 0)::text end))
               from unnest(array['on_time', 'late', 'undated', 'partial', 'open', 'held',
                                 'unknown_due']) k(cohort)
               left join cohorts g on g.cohort = k.cohort),
           'median_days', (select percentile_disc(0.5) within group (order by s.days) from settled s),
           'p90_days', (select percentile_disc(0.9) within group (order by s.days) from settled s),
           'weighted_days', case when v_mixed then null else (
             select round(sum(s.days * s.total)::numeric / nullif(sum(s.total), 0), 1)
               from settled s) end,
           'rows', coalesce((select jsonb_agg(jsonb_build_object(
                     'supplier_id', p.supplier_id, 'name', s.name, 'due', p.due,
                     'on_time', p.on_time, 'late', p.late, 'median_days', p.median_days)
                   order by p.due desc, s.name, p.supplier_id)
                   from per_supplier p join public.suppliers s on s.id = p.supplier_id), '[]'::jsonb))
    into v_payment;

  -- The bills of the months that carry both the supplier's date and the
  -- day they reached the space.
  with lag as (
    select d.supplier_id, d.received_on - d.original_date as days
      from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as d
     where d.kind = 'bill' and d.original_date is not null and d.received_on is not null
  ), per_supplier as (
    select l.supplier_id, count(*) as docs, sum(l.days) as days,
           percentile_disc(0.5) within group (order by l.days) as median_days
      from lag l where l.supplier_id is not null group by 1
  )
  select jsonb_build_object(
           'documents', (select count(*) from lag),
           'undated', (select count(*) from (select * from jsonb_to_recordset(v_docs) x(id uuid, supplier_id uuid, category text, kind text, currency text, cost bigint, original_date date, received_on date)) as d
                        where d.kind = 'bill' and (d.original_date is null or d.received_on is null)),
           'lag_days', (select coalesce(sum(days), 0) from lag),
           'median_days', (select percentile_disc(0.5) within group (order by days) from lag),
           'p90_days', (select percentile_disc(0.9) within group (order by days) from lag),
           'rows', coalesce((select jsonb_agg(jsonb_build_object(
                     'supplier_id', p.supplier_id, 'name', s.name, 'documents', p.docs,
                     'lag_days', p.days, 'median_days', p.median_days)
                   order by p.docs desc, s.name, p.supplier_id)
                   from per_supplier p join public.suppliers s on s.id = p.supplier_id), '[]'::jsonb))
    into v_lag;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'vendors.quality', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz, 'cutoff', v_cut,
    'currency', v_currency,
    'spend', v_spend,
    'categories', v_categories,
    'payment', v_payment,
    'billing_lag', v_lag,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_vendor_quality(uuid, text, text) from public, anon;
grant execute on function public.kpi_vendor_quality(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(673);
