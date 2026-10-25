-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 9999 (#2578) -- every figure says what it is.
--
--   kpi_registry()      the server's copy of the KPI catalogue now also
--       carries each metric's unit, aggregation, date basis and coverage
--       (kpi_registry_sql_test holds it equal to the Dart catalogue).
--   bi_query_batch_v1   every answer, a failed one too, names the metric's
--       version, unit, date basis and coverage from that registry instead
--       of a literal version. A request may name the version its client
--       reads; another one is that request's own 0A000, so an older client
--       never shows a figure whose meaning changed under the same name.
--       The limit stays bi_batch_limit (0509); the reader's refusal still
--       refuses the whole batch.
--   bi_definition_valid a v1 saved view may record the metric version each
--       card was saved with ({id: 1..99}, at most 20, beside the 2 KB of the
--       question itself). A view without it was saved when every metric
--       was at version 1, and stays valid.
--
-- Nothing is recomputed: the figures are the existing KPI functions'.

create or replace function public.kpi_registry()
returns jsonb
language sql immutable set search_path = public as $registry$
  select '{"capacity.seat_utilisation":{"version":1,"unit":"percent","aggregation":"ratio_of_sums","date_basis":"reservation_time","coverage":"recorded_history","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"finance.invoiced":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.collected":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_matched_at","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.ap_outstanding":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.member_reimbursements_due":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.pending_reviews":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"cash.recorded_outflows":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"payment_reported_paid","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.operating_costs":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.acquisitions":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.recorded_contribution":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"assets.book_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"book_value_period","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.contribution_after_depreciation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"invoice_month","coverage":"confirmed_values","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.unbilled_commitments":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"occurrence_due","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"finance.cost_allocation":{"version":1,"unit":"currency_minor","aggregation":"sum","date_basis":"document_date","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"purchases.forecast_outflows":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"period_end","coverage":"current_records","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]},"people.active_memberships_current":{"version":1,"unit":"count","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"aggregate_operational","permissions":["viewAnalytics"]},"sales.overdue_receivables":{"version":1,"unit":"currency_minor","aggregation":"last_at_cutoff","date_basis":"current_state","coverage":"current_state_only","disclosure":"financial","permissions":["viewAnalytics","viewFinances"]}}'::jsonb
$registry$;
revoke execute on function public.kpi_registry() from public, anon;
grant execute on function public.kpi_registry() to authenticated;

create or replace function public.bi_query_batch_v1(p_workspace_id uuid, p_requests jsonb)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  r jsonb;
  v_out jsonb := '[]'::jsonb;
  v_res jsonb;
  v_metric text;
  v_def jsonb;
  v_meta jsonb;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if p_requests is null or jsonb_typeof(p_requests) <> 'array'
     or jsonb_array_length(p_requests) not between 1 and public.bi_batch_limit(p_workspace_id) then
    raise exception 'a batch has between 1 and % requests', public.bi_batch_limit(p_workspace_id)
      using errcode = '22023';
  end if;
  for r in select * from jsonb_array_elements(p_requests) loop
    v_metric := r ->> 'metric_id';
    -- Only the metrics this batch answers; their descriptor is the registry's.
    v_def := case when v_metric in ('capacity.seat_utilisation', 'finance.invoiced', 'finance.collected')
                  then public.kpi_registry() -> v_metric end;
    v_meta := jsonb_build_object('request_key', r ->> 'request_key', 'metric_id', v_metric)
      || case when v_def is null then '{}'::jsonb
              else jsonb_build_object('metric_version', v_def -> 'version', 'unit', v_def -> 'unit',
                                      'date_basis', v_def -> 'date_basis', 'coverage', v_def -> 'coverage') end;
    begin
      if v_def is null then
        raise exception 'unsupported metric' using errcode = '0A000';
      end if;
      if r ? 'metric_version' and r -> 'metric_version' <> v_def -> 'version' then
        raise exception 'this metric is at another version here' using errcode = '0A000';
      end if;
      if v_metric = 'capacity.seat_utilisation' then
        v_res := public.kpi_seat_capacity(
          p_workspace_id, (r ->> 'from')::timestamptz, (r ->> 'to')::timestamptz,
          nullif(r ->> 'level_id', '')::uuid);
      else
        v_res := public.kpi_finance_summary(p_workspace_id, r ->> 'from_month', r ->> 'to_month');
      end if;
      v_out := v_out || jsonb_build_array(v_meta || jsonb_build_object('ok', true, 'result', v_res));
    exception when others then
      -- The reader's own refusal refuses the batch: no quiet gaps.
      if sqlstate = '42501' then raise; end if;
      v_out := v_out || jsonb_build_array(v_meta || jsonb_build_object(
        'ok', false, 'code', sqlstate, 'message', left(sqlerrm, 200)));
    end;
  end loop;
  return jsonb_build_object('computed_at', now(), 'results', v_out);
end;
$fn$;
revoke execute on function public.bi_query_batch_v1(uuid, jsonb) from public, anon;
grant execute on function public.bi_query_batch_v1(uuid, jsonb) to authenticated;

create or replace function public.bi_definition_valid(p jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select p is not null
     and jsonb_typeof(p) = 'object'
     and case p -> 'v'
           when '2'::jsonb then public.bi_report_valid(p)
           when '1'::jsonb then
                octet_length((p - 'metrics')::text) <= 2048
            and not exists (select 1 from jsonb_object_keys(p) k where k not in ('v', 'query', 'cards', 'metrics'))
            and jsonb_typeof(coalesce(p -> 'query', '{}'::jsonb)) = 'object'
            and not exists (
              select 1 from jsonb_each(coalesce(p -> 'query', '{}'::jsonb)) e
               where e.key not in ('grain', 'at', 'cmp', 'by', 'sort', 'view')
                  or jsonb_typeof(e.value) <> 'string'
                  or char_length(e.value #>> '{}') > 32)
            and jsonb_typeof(coalesce(p -> 'cards', '[]'::jsonb)) = 'array'
            and jsonb_array_length(coalesce(p -> 'cards', '[]'::jsonb)) <= 20
            and not exists (
              select 1 from jsonb_array_elements(coalesce(p -> 'cards', '[]'::jsonb)) c
               where jsonb_typeof(c) <> 'string'
                  or (c #>> '{}') !~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
                  or char_length(c #>> '{}') > 64)
            and jsonb_typeof(coalesce(p -> 'metrics', '{}'::jsonb)) = 'object'
            and (select count(*) from jsonb_object_keys(coalesce(p -> 'metrics', '{}'::jsonb))) <= 20
            and not exists (
              select 1 from jsonb_each(coalesce(p -> 'metrics', '{}'::jsonb)) m
               where m.key !~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
                  or char_length(m.key) > 64
                  or jsonb_typeof(m.value) <> 'number'
                  or (m.value #>> '{}') !~ '^[1-9][0-9]?$')
           else false end;
$fn$;
revoke execute on function public.bi_definition_valid(jsonb) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
