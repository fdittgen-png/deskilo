-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one row of the settings registry; bi_batch_time_budget_ms added;
-- bi_query_batch_v1 restated whole from 0586 with a time bound)
--
-- 0620 (#2578 BI B1) -- every report read is bounded in rows AND time. The
-- batch was bounded in requests (bi.batch_max_requests, 0508) and each
-- figure in its window; nothing bounded the time a full batch could take,
-- so a slow page waited for the server's request timeout and lost every
-- figure. Now bi.batch_time_budget_ms (default 4000, below the 8 s request
-- timeout): figures not reached within it are answered as over budget
-- (54000), each named; the ones computed stand. One snapshot as before.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('bi.batch_time_budget_ms', 'int', '4000'::jsonb, 500, 7000, 'milliseconds', 'kpi', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'bi_query_batch_v1 (#2578)', 'How long one report read may compute before the figures it has not reached yet are answered as timed out, so a page shows what it has instead of waiting for the server to give up. Keep it below the server request timeout.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- Member only, like bi_batch_limit (0509): a stranger's batch is refused
-- by the batch's own checks, never by reading another space's setting.
create or replace function public.bi_batch_time_budget_ms(p_workspace_id uuid)
returns int language sql stable security definer set search_path = public as $fn$
  select case when public.is_member_of(p_workspace_id)
              then coalesce((public.setting_value(p_workspace_id, 'bi.batch_time_budget_ms') #>> '{}')::int, 4000)
              else 4000 end;
$fn$;
revoke execute on function public.bi_batch_time_budget_ms(uuid) from public, anon, authenticated;

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
  v_started timestamptz := clock_timestamp();
  v_budget interval;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if p_requests is null or jsonb_typeof(p_requests) <> 'array'
     or jsonb_array_length(p_requests) not between 1 and public.bi_batch_limit(p_workspace_id) then
    raise exception 'a batch has between 1 and % requests', public.bi_batch_limit(p_workspace_id)
      using errcode = '22023';
  end if;
  -- Read after the batch's own checks, so they answer first.
  v_budget := make_interval(secs => public.bi_batch_time_budget_ms(p_workspace_id) / 1000.0);
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
      -- #2578 -- the time bound: once the batch has computed for its budget,
      -- the figures not reached yet are answered as over budget (54000; a
      -- handler never catches 57014), each named, so the page shows what it has
      -- and never waits for the server's request timeout to drop the read.
      if clock_timestamp() - v_started > v_budget then
        raise exception 'over the batch time budget' using errcode = '54000';
      end if;
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

select public.set_deskilo_schema_version(620);
