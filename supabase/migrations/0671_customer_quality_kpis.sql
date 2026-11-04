-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0671 (#3294 step 1) -- the customer figures of the analytics page, on the
-- KPI contract (#1918), from the invoices, their maturities, matches,
-- reminders and holds:
--
--   customers.payment_behaviour    the invoices falling due in the months,
--       each in one cohort (on time, late, settled without a payment date,
--       partly paid, open, on hold, written off, no due date), by count and
--       gross amount; the delay of a settled invoice is the day its last
--       payment was REPORTED paid (the reconciled bank line's value date,
--       else the ledger's date) minus its due date, never the match's date;
--       median, 90th percentile and the amount-weighted mean;
--   customers.dunning_load         the reminders of those invoices by level,
--       and how many reminded invoices were paid after their first
--       reminder (a sequence in time, not a cause); only with `dunning`;
--   customers.credit_and_writeoff  by the invoice's month: the credit notes
--       and the written-off remainders (total - paid), net of VAT (the
--       remainder in proportion to its invoice's net);
--   customers.concentration        the share of the net invoiced in the
--       months that the five largest customers make, and apart, the share
--       of what is owed now that the five largest debtors owe (whenever
--       they were invoiced: two populations, two rankings).
--
-- A source a settlement regrouped (0148) follows the settlement's payment
-- and hold: regrouping is not paying. Net is read from the frozen VAT
-- breakdown only; an invoice without one is left out of the net figures,
-- counted, and said (`net_not_proven`).
--
-- Who reads: kpi_readable() -- viewAnalytics AND viewFinances -- with
-- `workspaceStatus` on, a signed-in person, not a delegated assistant. The
-- customers' names travel only to a reader holding viewPersonalData; the
-- others get ranks and no member ids. Amounts travel as decimal STRINGS of
-- minor units in the workspace currency; another currency in scope leaves
-- every amount null (`currency_mix`), never summed; counts survive.

-- The registry restated whole with the four figures (kpi_registry_sql_test
-- holds it equal to the Dart catalogue).
create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"operations.pending_actions_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"customers.payment_behaviour":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.dunning_load":{"version":1,"unit":"count","aggregation":"sum","date_basis":"invoice_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.credit_and_writeoff":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"customers.concentration":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

-- The net of an invoice from its frozen VAT breakdown; null when it has
-- none: a missing snapshot does not prove that gross equals net.
create or replace function public.kpi_invoice_net(p_vat_totals jsonb)
returns bigint
language sql immutable set search_path = public as $fn$
  select case when jsonb_typeof(p_vat_totals) = 'array' and jsonb_array_length(p_vat_totals) > 0
              then (select sum((t ->> 'net_cents')::bigint) from jsonb_array_elements(p_vat_totals) t)
         end;
$fn$;
revoke execute on function public.kpi_invoice_net(jsonb) from public, anon, authenticated;

create or replace function public.kpi_customer_quality(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  -- How many of the largest customers the concentration counts: part of
  -- the figure's definition (customers.concentration), not a setting.
  c_top constant int := 5;
  -- A technical bound on the listed customers, not a business value.
  c_rows constant int := 10;
  v_currency text; v_tz text; v_now_month text;
  v_start date; v_cut date;
  v_names boolean; v_dunning boolean; v_mixed boolean;
  v_due jsonb; v_payment jsonb; v_dunning_out jsonb; v_credit jsonb; v_top jsonb;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'customers.payment_behaviour')
     or not public.kpi_readable(p_workspace_id, 'customers.concentration') then
    raise exception 'not allowed to read the customer figures of this workspace'
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
  v_names := public.has_permission(p_workspace_id, 'viewPersonalData');
  v_dunning := public.feature_effective(p_workspace_id, 'dunning');

  -- The invoices falling due in the months, and the ones without a due
  -- date issued in them; each lands in exactly one cohort. A source a
  -- settlement regrouped (0148) is owed through that settlement: it takes
  -- the settlement's match, hold, credits and payment date (e), never
  -- "paid" from being regrouped; the settlement itself is not counted
  -- apart, so nothing is counted twice.
  with base as (
    select i.id, i.member_id, i.total_cents::bigint as total,
           upper(coalesce(i.currency, v_currency)) as currency,
           e.total_cents::bigint as e_total, mt.due_on,
           m.status as m_status, m.resolution, m.writeoff_at,
           coalesce(m.paid_cents, 0)::bigint as paid,
           (select coalesce(sum(-c.total_cents), 0)::bigint from public.invoices c
             where c.replaces_invoice_id = e.id and c.total_cents < 0
               and c.voided_at is null and c.currency = e.currency) as credits,
           exists (select 1 from public.invoice_dunning_holds h
                    where h.invoice_id = e.id and h.released_at is null) as held,
           (select max(coalesce(bl.value_date, le.occurred_on,
                                (le.created_at at time zone v_tz)::date))
              from (select p.payment_ledger_id from public.invoice_match_payments p
                     where p.invoice_id = e.id
                    union
                    select m.payment_ledger_id where m.payment_ledger_id is not null) pay
              join public.ledger_entries le on le.id = pay.payment_ledger_id
              left join lateral (
                select max(l.value_date) as value_date from public.bank_statement_lines l
                 where l.workspace_id = p_workspace_id
                   and l.payment_ledger_id = pay.payment_ledger_id) bl on true) as pay_date
      from public.invoices i
      join public.invoices e on e.id = coalesce(i.settled_by_invoice_id, i.id)
      left join public.invoice_maturities mt on mt.invoice_id = i.id
      left join public.invoice_matches m on m.invoice_id = e.id
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.kind <> 'settlement' and i.total_cents > 0
       and ((mt.due_on between v_start and v_cut)
            or (mt.due_on is null and i.period between p_from and p_to))
  ), classed as (
    select b.*,
           b.m_status = 'confirmed' and b.writeoff_at is not null as written_off,
           b.credits >= b.e_total
             or (b.m_status = 'confirmed'
                 and (b.resolution in ('exact', 'over_forced', 'over_credit_note', 'refunded')
                      or b.paid + b.credits >= b.e_total)) as settled
      from base b
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'invoice_id', c.id, 'total', c.total, 'currency', c.currency, 'due_on', c.due_on,
           'cohort', case when c.due_on is null then 'unknown_due'
              when c.written_off then 'written_off'
              when c.settled and c.pay_date is null then 'undated'
              when c.settled and c.pay_date <= c.due_on then 'on_time'
              when c.settled then 'late'
              when c.held then 'held'
              when c.m_status = 'confirmed' and c.paid > 0 then 'partial'
              else 'open' end,
           'pay_date', c.pay_date,
           'days', case when c.settled and not c.written_off and c.pay_date is not null
                        then c.pay_date - c.due_on end)), '[]'::jsonb)
    into v_due
    from classed c;

  -- Every invoice of the months, whatever it is for, in one currency.
  select coalesce(bool_or(upper(coalesce(i.currency, v_currency)) <> v_currency), false)
    into v_mixed
    from public.invoices i
   where i.workspace_id = p_workspace_id and i.voided_at is null
     and i.kind <> 'settlement' and i.period between p_from and p_to;
  v_mixed := v_mixed or exists (
    select 1 from jsonb_array_elements(v_due) e where e ->> 'currency' <> v_currency);
  -- ... and what is owed now, which the concentration reads (a
  -- settlement is what is owed for its sources).
  v_mixed := v_mixed or exists (
    select 1 from public.invoices i
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.total_cents > 0
       and upper(coalesce(i.currency, v_currency)) <> v_currency
       and (i.issued_at at time zone v_tz)::date <= v_cut
       and (public.invoice_dunning_state_core(i.id, now()) ->> 'collectible_cents')::bigint > 0);

  with due as (
    select * from jsonb_to_recordset(v_due) d(
      invoice_id uuid, total bigint, currency text, due_on date,
      cohort text, pay_date date, days int)
  ), cohorts as (
    select d.cohort, count(*) as n, sum(d.total) as amount from due d group by 1
  ), settled as (
    select d.days, d.total from due d where d.days is not null
  )
  select jsonb_build_object(
           'cohorts', (
             select jsonb_object_agg(k.cohort, jsonb_build_object(
                      'count', coalesce(g.n, 0),
                      'minor', case when v_mixed then null else coalesce(g.amount, 0)::text end))
               from unnest(array['on_time', 'late', 'undated', 'partial', 'open', 'held',
                                 'written_off', 'unknown_due']) k(cohort)
               left join cohorts g on g.cohort = k.cohort),
           'median_days', (select percentile_disc(0.5) within group (order by s.days) from settled s),
           'p90_days', (select percentile_disc(0.9) within group (order by s.days) from settled s),
           'weighted_days', case when v_mixed then null else (
             select round(sum(s.days * s.total)::numeric / nullif(sum(s.total), 0), 1)
               from settled s) end)
    into v_payment;

  if v_dunning then
    with due as (
      select * from jsonb_to_recordset(v_due) d(
        invoice_id uuid, due_on date, cohort text, pay_date date)
    ), sent as (
      select d.invoice_id, d.cohort, d.pay_date, coalesce(r.level, 0) as level,
             (r.sent_at at time zone v_tz)::date as sent_on
        from due d join public.invoice_reminders r on r.invoice_id = d.invoice_id
    ), reminded as (
      select s.invoice_id, s.cohort, s.pay_date, min(s.sent_on) as first_on
        from sent s group by 1, 2, 3
    )
    select jsonb_build_object(
             'due_invoices', (select count(*) from due d where d.due_on is not null),
             'reminded_invoices', (select count(*) from reminded),
             'reminders', (select count(*) from sent),
             'by_level', coalesce((
               select jsonb_object_agg(lv.level::text, lv.n)
                 from (select s.level, count(*) as n from sent s group by 1) lv), '{}'::jsonb),
             'paid_after_reminder', (select count(*) from reminded r
                                      where r.cohort in ('on_time', 'late')
                                        and r.pay_date > r.first_on))
      into v_dunning_out;
  end if;

  -- Credit notes and written-off remainders, by the invoice's month, net.
  with docs as (
    select i.period,
           i.total_cents::bigint as total,
           public.kpi_invoice_net(i.vat_totals) as net,
           m.status as m_status, m.writeoff_at, coalesce(m.paid_cents, 0)::bigint as paid
      from public.invoices i
      left join public.invoice_matches m on m.invoice_id = i.id
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.kind <> 'settlement' and i.period between p_from and p_to
  ), counted as (
    select d.*,
           d.total < 0 as is_note,
           d.total > 0 and d.m_status = 'confirmed' and d.writeoff_at is not null as is_off
      from docs d
  ), months as (
    select d.period,
           count(*) filter (where d.is_note) as notes,
           coalesce(-sum(d.net) filter (where d.is_note), 0) as credited,
           count(*) filter (where d.is_off) as offs,
           coalesce(sum(round((d.total - d.paid)::numeric * d.net / d.total)::bigint)
                      filter (where d.is_off and d.paid < d.total), 0) as written,
           count(*) filter (where (d.is_note or (d.is_off and d.paid < d.total))
                              and d.net is null) as unknown
      from counted d group by 1
  )
  select jsonb_build_object(
           'net_unknown', coalesce(sum(unknown), 0),
           'credit_notes', coalesce(sum(notes), 0),
           'credited_minor', case when v_mixed then null else coalesce(sum(credited), 0)::text end,
           'write_offs', coalesce(sum(offs), 0),
           'written_off_minor', case when v_mixed then null else coalesce(sum(written), 0)::text end,
           'months', coalesce(jsonb_agg(jsonb_build_object(
                       'month', period,
                       'credited_minor', case when v_mixed then null else credited::text end,
                       'written_off_minor', case when v_mixed then null else written::text end)
                     order by period) filter (where notes > 0 or offs > 0), '[]'::jsonb))
    into v_credit
    from months;

  -- Two populations, ranked apart: the customers by what they were
  -- invoiced net in the months (credit notes deducted; an invoice whose net
  -- is not proven is left out and counted), and the debtors by what they
  -- owe now on everything issued by the cut-off, whenever it was invoiced
  -- (a settlement owes for its sources). The largest customers by sales are
  -- not the largest debtors, so each share has its own top.
  with net as (
    select i.member_id, sum(public.kpi_invoice_net(i.vat_totals)) as net,
           count(*) filter (where public.kpi_invoice_net(i.vat_totals) is null) as unknown
      from public.invoices i
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.kind <> 'settlement' and i.period between p_from and p_to
     group by 1
  ), owed as (
    select i.member_id, sum((s.state ->> 'collectible_cents')::bigint) as open
      from public.invoices i
      cross join lateral public.invoice_dunning_state_core(i.id, now()) s(state)
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.total_cents > 0
       and (i.issued_at at time zone v_tz)::date <= v_cut
     group by 1
  ), names as (
    select distinct on (i.member_id) i.member_id, i.member_name as name
      from public.invoices i
     where i.workspace_id = p_workspace_id
     order by i.member_id, i.issued_at desc
  ), sales as (
    select n.member_id, n.net, row_number() over (order by n.net desc, n.member_id) as rank
      from net n where n.net > 0
  ), debtors as (
    select o.member_id, o.open, row_number() over (order by o.open desc, o.member_id) as rank
      from owed o where o.open > 0
  )
  select jsonb_build_object(
           'top_count', c_top,
           'net_unknown', (select coalesce(sum(unknown), 0) from net),
           'customers', (select count(*) from sales),
           'net_minor', case when v_mixed then null
                             else (select coalesce(sum(net), 0) from sales)::text end,
           'top_net_minor', case when v_mixed then null
                                 else (select coalesce(sum(net), 0) from sales
                                        where rank <= c_top)::text end,
           'debtors', (select count(*) from debtors),
           'open_minor', case when v_mixed then null
                              else (select coalesce(sum(open), 0) from debtors)::text end,
           'top_open_minor', case when v_mixed then null
                                  else (select coalesce(sum(open), 0) from debtors
                                         where rank <= c_top)::text end,
           'rows', (select coalesce(jsonb_agg(jsonb_build_object(
                      'rank', x.rank,
                      'name', case when v_names then nm.name end,
                      'minor', case when v_mixed then null else x.net::text end)
                    order by x.rank), '[]'::jsonb)
                      from sales x left join names nm on nm.member_id = x.member_id
                     where x.rank <= c_rows),
           'debtor_rows', (select coalesce(jsonb_agg(jsonb_build_object(
                             'rank', x.rank,
                             'name', case when v_names then nm.name end,
                             'minor', case when v_mixed then null else x.open::text end)
                           order by x.rank), '[]'::jsonb)
                             from debtors x left join names nm on nm.member_id = x.member_id
                            where x.rank <= c_rows))
    into v_top;

  if (v_credit ->> 'net_unknown')::int > 0 or (v_top ->> 'net_unknown')::int > 0 then
    v_reasons := v_reasons || 'net_not_proven'::text;
  end if;
  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;
  if not v_dunning then
    v_reasons := v_reasons || 'dunning_off'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'customers.quality', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz, 'cutoff', v_cut,
    'currency', v_currency,
    'names_visible', v_names,
    'payment', v_payment,
    'dunning', v_dunning_out,
    'credit', v_credit,
    'concentration', v_top,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_customer_quality(uuid, text, text) from public, anon;
grant execute on function public.kpi_customer_quality(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(671);
