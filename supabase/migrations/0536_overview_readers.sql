-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0536 (#2583) -- the overview's own figures, current state, read now:
--
--   people.active_memberships_current  the memberships whose status is
--       active, each role included (memberships, not distinct people).
--       viewAnalytics.
--   sales.overdue_receivables          what members still owe on issued
--       invoices past their proven due date, by the dunning rules
--       (`invoice_dunning_state_core`, 0331: credits, part payments and
--       write-offs taken off). An invoice whose due date is unknown, or on
--       hold, is counted apart and never in the amount. Another currency
--       in scope is `currency_mix`, never summed. viewAnalytics AND
--       viewFinances.
--
-- Both need the `workspaceOverview` flag, a signed-in person, not a
-- delegated assistant. A period that is not the current month gets today's
-- value with `not_recorded` / `current_state`: no history is kept.

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

-- The shared preamble: who may read, which months, the workspace's clock.
create or replace function public.kpi_overview_scope(
  p_workspace_id uuid, p_kpi text, p_from text, p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_currency text; v_tz text; v_now_month text;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.kpi_readable(p_workspace_id, p_kpi) then
    raise exception 'not allowed to read this figure of this workspace'
      using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'workspaceOverview') then
    raise exception 'the overview is not enabled for this workspace'
      using errcode = '42501';
  end if;
  if p_from is null or p_to is null
     or p_from !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' or p_to !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     or p_from > p_to then
    raise exception 'the KPI months must be YYYY-MM, from <= to'
      using errcode = '22023';
  end if;
  select w.currency_code, coalesce(nullif(w.timezone, ''), 'UTC') into v_currency, v_tz
    from public.workspaces w where w.id = p_workspace_id;
  v_now_month := to_char(now() at time zone v_tz, 'YYYY-MM');
  return jsonb_build_object(
    'currency', upper(coalesce(v_currency, '')), 'timezone', v_tz,
    'current', v_now_month between p_from and p_to);
end
$fn$;
revoke execute on function public.kpi_overview_scope(uuid, text, text, text) from public, anon, authenticated;

create or replace function public.kpi_memberships_current(
  p_workspace_id uuid, p_from text, p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_scope jsonb := public.kpi_overview_scope(
    p_workspace_id, 'people.active_memberships_current', p_from, p_to);
  v_count int;
begin
  select count(*) into v_count from public.members m
   where m.workspace_id = p_workspace_id and m.status = 'active';
  return jsonb_build_object(
    'kpi', 'people.active_memberships_current', 'version', 1,
    'from', p_from, 'to', p_to,
    'value', v_count, 'count', v_count, 'currency', '',
    'quality', case when (v_scope ->> 'current')::boolean then '[]'::jsonb
                    else '["not_recorded"]'::jsonb end,
    'reasons', case when (v_scope ->> 'current')::boolean then '[]'::jsonb
                    else '["current_state"]'::jsonb end,
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_memberships_current(uuid, text, text) from public, anon;
grant execute on function public.kpi_memberships_current(uuid, text, text) to authenticated;

create or replace function public.kpi_overdue_receivables(
  p_workspace_id uuid, p_from text, p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_scope jsonb := public.kpi_overview_scope(
    p_workspace_id, 'sales.overdue_receivables', p_from, p_to);
  v_currency text := v_scope ->> 'currency';
  v_amount bigint; v_count int; v_unknown int; v_held int; v_mixed boolean;
  v_quality text[] := '{}'; v_reasons text[] := '{}';
begin
  with states as (
    select s.state
      from public.invoices i
      cross join lateral public.invoice_dunning_state_core(i.id, now()) s(state)
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and i.kind <> 'settlement' and i.total_cents > 0
  )
  select coalesce(sum((state ->> 'collectible_cents')::bigint) filter (
           where state ->> 'phase' = 'overdue' and state ->> 'hold' is null), 0),
         count(*) filter (where state ->> 'phase' = 'overdue' and state ->> 'hold' is null),
         count(*) filter (where state ->> 'phase' = 'unknown_maturity'),
         count(*) filter (where state ->> 'phase' = 'overdue' and state ->> 'hold' is not null),
         coalesce(bool_or(state ->> 'phase' = 'overdue'
                          and upper(state ->> 'currency') <> v_currency), false)
    into v_amount, v_count, v_unknown, v_held, v_mixed
    from states;
  if v_mixed then
    v_quality := v_quality || 'unavailable'::text;
    v_reasons := v_reasons || 'currency_mix'::text;
  end if;
  if not (v_scope ->> 'current')::boolean then
    v_quality := v_quality || 'not_recorded'::text;
    v_reasons := v_reasons || 'current_state'::text;
  end if;
  return jsonb_build_object(
    'kpi', 'sales.overdue_receivables', 'version', 1,
    'from', p_from, 'to', p_to, 'currency', v_currency,
    'value', case when v_mixed then null else v_amount::text end,
    'count', v_count, 'unknown_due_count', v_unknown, 'held_count', v_held,
    'quality', to_jsonb(v_quality), 'reasons', to_jsonb(v_reasons),
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_overdue_receivables(uuid, text, text) from public, anon;
grant execute on function public.kpi_overdue_receivables(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(536);
