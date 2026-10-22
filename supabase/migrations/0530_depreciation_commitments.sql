-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0530 (#2582 C2) -- book depreciation and the commitments still to be
-- billed, on the same cost summary (restated whole):
--
--   assets.book_depreciation       the depreciation of the confirmed book
--       values (#2576) whose periods tile the months exactly, complete and
--       in the workspace currency. A tax-only, partial, year-to-date or
--       overlapping set is unknown (`book_coverage_incomplete`), never 0.
--   finance.contribution_after_depreciation  invoiced less recorded
--       operating costs, less that depreciation: unknown while it is, so
--       the figure without depreciation is never shown under this name.
--   purchases.unbilled_commitments  what the leases and rented rooms (#2575)
--       still expect in the months: a generated occurrence less the bills
--       matched to it, one not generated yet projected from its schedule.
--       Overdue (due before today) and upcoming apart. Unavailable without
--       a lease or a rented room (`no_contracts`).
--
-- Depreciation creates no cash and a payment is no cost: neither figure
-- reads a payment.

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.kpi_costs_summary(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_currency text; v_tz text; v_now_month text;
  v_start date; v_cut date;
  v_costs bigint; v_unresolved int; v_unqualified int;
  v_assets bigint; v_assets_on boolean;
  v_sales bigint;
  v_mixed boolean;
  v_dep bigint; v_dep_known boolean := false;
  v_contracts_on boolean; v_today date;
  v_unbilled bigint; v_overdue bigint;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'purchases.operating_costs') then
    raise exception 'not allowed to read the cost figures of this workspace'
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
  v_now_month := to_char(now() at time zone v_tz, 'YYYY-MM');
  v_start := to_date(p_from, 'YYYY-MM');
  v_cut := (to_date(p_to, 'YYYY-MM') + interval '1 month')::date - 1;
  v_assets_on := public.feature_effective(p_workspace_id, 'assetRegister');

  -- One cost per line: the net plus what cannot be recovered; the gross when
  -- the recoverable share is not qualified; the gross of an untaxed line.
  with lines as (
    select l.id, l.recognition_kind, d.currency,
           case when d.kind = 'credit_note' then -1 else 1 end as sign,
           case when l.net_cents is null then l.gross_cents
                when l.nonrecoverable_tax_cents is null then l.net_cents + l.tax_cents
                else l.net_cents + l.nonrecoverable_tax_cents end as cost,
           l.net_cents is not null and l.tax_cents <> 0
             and l.nonrecoverable_tax_cents is null as unqualified
      from public.purchase_lines l
      join public.purchase_documents d on d.id = l.purchase_id and d.workspace_id = l.workspace_id
     where l.workspace_id = p_workspace_id and d.state = 'approved'
       and d.kind in ('bill', 'credit_note', 'member_receipt')
       and coalesce(d.original_date, d.received_on) between v_start and v_cut
  )
  select coalesce(sum(sign * cost) filter (where recognition_kind = 'operating'), 0),
         count(*) filter (where recognition_kind = 'unresolved'),
         count(*) filter (where recognition_kind = 'operating' and unqualified),
         coalesce(sum(sign * cost) filter (where recognition_kind = 'asset' and exists (
           select 1 from public.workspace_assets a
            where a.purchase_line_id = lines.id and a.decision = 'capitalise')), 0),
         coalesce(bool_or(upper(currency) <> upper(v_currency)
                          and recognition_kind in ('operating', 'asset')), false)
    into v_costs, v_unresolved, v_unqualified, v_assets, v_mixed
    from lines;

  -- The invoiced sales of the months, net of their tax (finance.invoiced's
  -- documents: non-void, settlements left out), credit notes subtracting.
  select coalesce(sum(case when jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0
                           then i.total_cents
                           else (select sum((e ->> 'net_cents')::bigint)
                                   from jsonb_array_elements(i.vat_totals) e) end), 0),
         v_mixed or coalesce(bool_or(upper(coalesce(i.currency, v_currency)) <> upper(v_currency)), false)
    into v_sales, v_mixed
    from public.invoices i
   where i.workspace_id = p_workspace_id and i.voided_at is null
     and i.kind <> 'settlement' and i.period between p_from and p_to;

  -- #2576: the book depreciation is known only when confirmed, complete,
  -- period-movement book batches in the workspace currency tile the months
  -- exactly, every row with its depreciation. A tax-only, partial,
  -- year-to-date or overlapping set is unknown, never 0.
  if v_assets_on then
    with b as (
      select vb.id, vb.period_from, vb.period_to, vb.movements, vb.complete_scope, vb.currency
        from public.asset_valuation_batches vb
       where vb.workspace_id = p_workspace_id and vb.basis = 'book' and vb.status = 'confirmed'
         and vb.period_from <= v_cut and vb.period_to >= v_start
    )
    select coalesce(count(*) > 0
             and bool_and(b.movements = 'period' and b.complete_scope
                          and upper(b.currency) = upper(v_currency)
                          and b.period_from >= v_start and b.period_to <= v_cut)
             and min(b.period_from) = v_start and max(b.period_to) = v_cut
             and sum(b.period_to - b.period_from + 1) = v_cut - v_start + 1
             and not exists (select 1 from b b1 join b b2 on b1.id < b2.id
                              and b1.period_from <= b2.period_to and b2.period_from <= b1.period_to)
             and not exists (select 1 from public.asset_valuation_rows vr
                              where vr.batch_id in (select b3.id from b b3)
                                and vr.depreciation_minor is null), false),
           (select coalesce(sum(vr.depreciation_minor), 0) from public.asset_valuation_rows vr
             where vr.batch_id in (select b4.id from b b4))
      into v_dep_known, v_dep
      from b;
  end if;

  -- #2575: what the contracts still expect in the months. An occurrence
  -- already generated counts what is left after the bills matched to it (an
  -- accepted variance is above the expectation, never below it); one not
  -- generated yet is projected from its schedule exactly as the sweep will
  -- generate it, so neither counts twice.
  v_contracts_on := public.feature_effective(p_workspace_id, 'premisesLease')
                 or public.feature_effective(p_workspace_id, 'externalRooms');
  v_today := (now() at time zone v_tz)::date;
  if v_contracts_on then
    with recursive projected as (
      select s.id, s.next_due as due_on, s.occurrences_done as done, s.every, s.unit,
             s.ends_on, s.repeat_count, s.amount_cents
        from public.expense_schedules s
       where s.workspace_id = p_workspace_id and s.origin = 'workspace_contract'
         and s.status = 'active' and s.next_due is not null
      union all
      select p.id, (p.due_on + (p.every || ' ' || p.unit)::interval)::date, p.done + 1, p.every, p.unit,
             p.ends_on, p.repeat_count, p.amount_cents
        from projected p
       where p.due_on <= v_cut
    ), expected as (
      select p.due_on, p.amount_cents::bigint as left_minor
        from projected p
       where p.due_on between v_start and v_cut
         and (p.ends_on is null or p.due_on <= p.ends_on)
         and (p.repeat_count is null or p.done < p.repeat_count)
      union all
      select o.due_on, greatest(o.amount_cents - coalesce((
               select sum(x.allocated_cents) from public.purchase_commitment_matches x
                where x.occurrence_id = o.id and x.kind in ('match', 'reversal')), 0), 0)
        from public.expense_occurrences o
        join public.expense_schedules sc on sc.id = o.schedule_id
       where sc.origin = 'workspace_contract' and o.workspace_id = p_workspace_id
         and o.status <> 'rejected' and o.due_on between v_start and v_cut
    )
    select coalesce(sum(left_minor), 0), coalesce(sum(left_minor) filter (where due_on < v_today), 0)
      into v_unbilled, v_overdue
      from expected;
  end if;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;
  if v_unqualified > 0 then
    v_reasons := v_reasons || 'tax_unqualified'::text;
  end if;
  if v_unresolved > 0 then
    v_reasons := v_reasons || 'unresolved_lines'::text;
  end if;
  if not v_assets_on then
    v_reasons := v_reasons || 'asset_register_off'::text;
  elsif not v_dep_known then
    v_reasons := v_reasons || 'book_coverage_incomplete'::text;
  end if;
  if not v_contracts_on then
    v_reasons := v_reasons || 'no_contracts'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'purchases.costs', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz,
    'currency', upper(v_currency),
    'operating_costs_minor', v_costs::text,
    'unresolved_lines', v_unresolved,
    'unqualified_lines', v_unqualified,
    'acquisitions_minor', case when v_assets_on then v_assets::text end,
    'net_sales_minor', v_sales::text,
    'contribution_minor', (v_sales - v_costs)::text,
    'book_depreciation_minor', case when v_dep_known then v_dep::text end,
    'after_depreciation_minor', case when v_dep_known then (v_sales - v_costs - v_dep)::text end,
    'unbilled_minor', case when v_contracts_on then v_unbilled::text end,
    'unbilled_overdue_minor', case when v_contracts_on then v_overdue::text end,
    'unbilled_upcoming_minor', case when v_contracts_on then (v_unbilled - v_overdue)::text end,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_costs_summary(uuid, text, text) from public, anon;
grant execute on function public.kpi_costs_summary(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(530);
