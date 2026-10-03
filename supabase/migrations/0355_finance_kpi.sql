-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0355 (#1924) -- the first finance KPIs on the shared contract (#1918):
-- what was invoiced and what was collected over whole workspace months.
--
-- They are the treasurer's figures that workspace_status (0167) already
-- computes, read with the same predicates so the BI card and the money
-- report agree to the cent:
--
--   finance.invoiced   invoices of the months, non-void, settlements left
--                      out (they regroup invoices already counted),
--                      positive totals; credit notes are named beside it,
--                      never netted silently;
--   finance.collected  payments matched to invoices, by the month of the
--                      match on the workspace clock.
--
-- Neither is a profit: costs are not in it. Amounts travel as decimal
-- STRINGS of minor units, so no JSON number rounds them. The workspace
-- currency is the unit; a period holding another currency is refused as
-- unavailable (currency_mix) rather than summed, and a workspace without
-- a currency reads nothing. A period that has not ended is partial.
--
-- Who reads: kpi_readable() -- viewAnalytics AND viewFinances -- with the
-- workspaceStatus feature on, a signed-in person, not a delegated
-- assistant. The registry gains both ids (kpi_registry_sql_test).

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.kpi_finance_summary(
  p_workspace_id uuid,
  p_from text,
  p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_currency text; v_tz text; v_now_month text;
  v_invoiced bigint; v_credit_notes bigint; v_invoices int;
  v_collected bigint; v_matches int; v_last timestamptz;
  v_mixed boolean;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, 'finance.invoiced')
     or not public.kpi_readable(p_workspace_id, 'finance.collected') then
    raise exception 'not allowed to read the finance figures of this workspace'
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

  select w.currency_code, coalesce(w.timezone, 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  if v_currency is null or btrim(v_currency) = '' then
    raise exception 'the workspace has no currency' using errcode = '22023';
  end if;
  v_now_month := to_char(now() at time zone v_tz, 'YYYY-MM');

  select coalesce(sum(i.total_cents) filter (where i.total_cents > 0), 0),
         coalesce(-sum(i.total_cents) filter (where i.total_cents < 0), 0),
         count(*) filter (where i.total_cents > 0),
         bool_or(upper(coalesce(i.currency, v_currency)) <> upper(v_currency)),
         max(i.modified_datetime)
    into v_invoiced, v_credit_notes, v_invoices, v_mixed, v_last
    from public.invoices i
   where i.workspace_id = p_workspace_id and i.voided_at is null
     and i.kind <> 'settlement' and i.period between p_from and p_to;

  select coalesce(sum(mp.amount_cents), 0), count(*),
         coalesce(v_mixed, false)
           or coalesce(bool_or(upper(coalesce(i.currency, v_currency)) <> upper(v_currency)), false),
         greatest(v_last, max(mp.modified_datetime))
    into v_collected, v_matches, v_mixed, v_last
    from public.invoice_match_payments mp
    left join public.invoices i on i.id = mp.invoice_id
   where mp.workspace_id = p_workspace_id
     and to_char(mp.matched_at at time zone v_tz, 'YYYY-MM') between p_from and p_to;

  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if p_to >= v_now_month then
    v_quality := v_quality || 'partial'::text;
    v_reasons := v_reasons || 'period_not_over'::text;
  end if;

  return jsonb_build_object(
    'kpi', 'finance.summary', 'version', 1,
    'from', p_from, 'to', p_to, 'timezone', v_tz,
    'currency', upper(v_currency),
    'invoiced_minor', v_invoiced::text,
    'credit_notes_minor', v_credit_notes::text,
    'invoices', v_invoices,
    'collected_minor', v_collected::text,
    'matches', v_matches,
    'quality', to_jsonb(v_quality),
    'reasons', to_jsonb(v_reasons),
    'last_change_at', v_last,
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_finance_summary(uuid, text, text) from public, anon;
grant execute on function public.kpi_finance_summary(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(355);
