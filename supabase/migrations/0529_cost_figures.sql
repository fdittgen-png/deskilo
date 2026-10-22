-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0529 (#2582 C2) -- the cost side of the analytics page, from the purchase
-- lines themselves, in the months [from, to] by the document's date (the
-- only date a purchase line knows; no accrual is invented):
--
--   purchases.operating_costs      the lines classified `operating` of the
--       approved supplier bills and member receipts, net plus the tax that
--       cannot be recovered; a supplier's credit note subtracts. Stock not
--       yet consumed, prepayments, deposits, equipment and the payments
--       themselves are not costs. A line whose recoverable share is not
--       qualified counts at its gross and says so (`tax_unqualified`): a
--       guessed deduction never lowers a cost. Lines nobody classified are
--       left out and counted (`unresolved_lines`).
--   assets.acquisitions            the equipment whose treatment was decided
--       `capitalise`, at the same cost; a capital addition, never a cost or
--       a depreciation. Unavailable while the equipment register is off.
--   finance.recorded_contribution  the invoiced sales of the months, net of
--       their tax (credit notes subtract), less the operating costs: named
--       "invoiced less recorded operating costs", never a profit.
--
-- Same reader rules as 0527: viewAnalytics AND viewFinances with the
-- `purchaseAnalytics` flag on, a signed-in person, not a delegated
-- assistant; decimal strings of minor units in the workspace currency, and
-- another currency in scope is `currency_mix`, never summed.

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
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
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_costs_summary(uuid, text, text) from public, anon;
grant execute on function public.kpi_costs_summary(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(529);
