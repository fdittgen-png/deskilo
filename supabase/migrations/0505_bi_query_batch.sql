-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0505 (#2578, C1) -- one read for many figures.
--
-- A BI card asked the server one KPI per period and per group: thirteen
-- periods of a series, a total and its levels were as many round trips, each
-- on its own snapshot, so a booking made in between could make the total and
-- its groups contradict each other. `bi_query_batch_v1` answers a list of
-- requests in one call. Every request is answered by the EXISTING KPI function
-- of its metric (nothing is recomputed here); the batch is STABLE, so every
-- answer reads the snapshot of the one calling statement. A request that
-- fails on its own (an unknown level, a period too long) is reported as that
-- request's failure and leaves the others intact; a refusal of the reader (no
-- right, flag off) refuses the whole batch, never a quiet gap.
--
--   {request_key, metric_id: capacity.seat_utilisation, from, to, level_id?}
--   {request_key, metric_id: finance.invoiced | finance.collected,
--    from_month, to_month}                          (YYYY-MM, both inclusive)
--
-- At most 60 requests; no SQL, formula, table or column is accepted.

create or replace function public.bi_query_batch_v1(p_workspace_id uuid, p_requests jsonb)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  r jsonb;
  v_out jsonb := '[]'::jsonb;
  v_res jsonb;
  v_metric text;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if p_requests is null or jsonb_typeof(p_requests) <> 'array'
     or jsonb_array_length(p_requests) not between 1 and 60 then
    raise exception 'a batch has between 1 and 60 requests' using errcode = '22023';
  end if;
  for r in select * from jsonb_array_elements(p_requests) loop
    v_metric := r ->> 'metric_id';
    begin
      if v_metric = 'capacity.seat_utilisation' then
        v_res := public.kpi_seat_capacity(
          p_workspace_id, (r ->> 'from')::timestamptz, (r ->> 'to')::timestamptz,
          nullif(r ->> 'level_id', '')::uuid);
      elsif v_metric in ('finance.invoiced', 'finance.collected') then
        v_res := public.kpi_finance_summary(p_workspace_id, r ->> 'from_month', r ->> 'to_month');
      else
        raise exception 'unsupported metric' using errcode = '0A000';
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'request_key', r ->> 'request_key', 'metric_id', v_metric, 'metric_version', 1,
        'ok', true, 'result', v_res));
    exception when others then
      -- The reader's own refusal refuses the batch: no quiet gaps.
      if sqlstate = '42501' then raise; end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'request_key', r ->> 'request_key', 'metric_id', v_metric, 'ok', false,
        'code', sqlstate, 'message', left(sqlerrm, 200)));
    end;
  end loop;
  return jsonb_build_object('computed_at', now(), 'results', v_out);
end;
$fn$;
revoke execute on function public.bi_query_batch_v1(uuid, jsonb) from public, anon;
grant execute on function public.bi_query_batch_v1(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(505);
