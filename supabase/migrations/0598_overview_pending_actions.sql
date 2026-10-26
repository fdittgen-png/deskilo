-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0598 (#2580) -- what waits on a decision of the space, as a registered
-- figure of the overview:
--
--   operations.pending_actions_current  the requests the space's validators
--       have not decided (events still `pending`) and the people asking to
--       join (memberships still `pending`), counted now. The space's own
--       figure, not one person's list: the overview's "Needs attention"
--       list stays the reader's, and this count says how much waits in the
--       whole space. viewAnalytics, behind `workspaceOverview`, a signed-in
--       person, not a delegated assistant (kpi_overview_scope, 0536). A
--       period that is not the current month gets today's value with
--       `not_recorded` / `current_state`: no history is kept. Reading
--       changes nothing: no expiry sweep runs here.
--
--   kpi_registry()  restated whole with the figure (kpi_registry_sql_test
--       holds it equal to the Dart catalogue).

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"operations.pending_actions_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.kpi_pending_actions_current(
  p_workspace_id uuid, p_from text, p_to text
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_scope jsonb := public.kpi_overview_scope(
    p_workspace_id, 'operations.pending_actions_current', p_from, p_to);
  v_requests int;
  v_joins int;
begin
  -- What waits on a decision of the space now: the requests its validators
  -- have not decided, and the people asking to join. Read as they stand;
  -- nothing is expired or swept by reading.
  select count(*) into v_requests from public.events e
   where e.workspace_id = p_workspace_id and e.status = 'pending';
  select count(*) into v_joins from public.members m
   where m.workspace_id = p_workspace_id and m.status = 'pending';
  return jsonb_build_object(
    'kpi', 'operations.pending_actions_current', 'version', 1,
    'from', p_from, 'to', p_to,
    'value', v_requests + v_joins, 'count', v_requests + v_joins,
    'currency', '',
    'quality', case when (v_scope ->> 'current')::boolean then '[]'::jsonb
                    else '["not_recorded"]'::jsonb end,
    'reasons', case when (v_scope ->> 'current')::boolean then '[]'::jsonb
                    else '["current_state"]'::jsonb end,
    'computed_at', now());
end
$fn$;
revoke execute on function public.kpi_pending_actions_current(uuid, text, text) from public, anon;
grant execute on function public.kpi_pending_actions_current(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(598);
