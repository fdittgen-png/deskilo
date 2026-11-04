-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #2578: a batch is refused whole when the caller may not read one of its
-- metrics, whatever the clock says. The reader's own refusal (42501) came
-- from inside the loop, behind the time budget: once the budget was spent, a
-- metric the caller may not read was answered "over budget" (54000) instead
-- of refusing the batch, so a slow page turned an analyst's refusal into a
-- page with gaps. Found by the performance proof (check B13, 60 requests on
-- 601,344 reservations). The rights are now checked for every distinct metric
-- before the first figure is computed, with the registry's own permissions
-- (kpi_readable); the readers keep their own checks.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.bi_query_batch_v1(uuid,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  -- Read after the batch's own checks, so they answer first.$a$,
    $a$  -- The caller's rights come first, for every metric the batch names: a
  -- refusal never depends on how far the time budget got.
  for v_metric in
    select distinct e ->> 'metric_id'
      from jsonb_array_elements(p_requests) e
     where e ->> 'metric_id' in ('capacity.seat_utilisation', 'finance.invoiced', 'finance.collected')
  loop
    if public.mcp_is_delegated() or not public.kpi_readable(p_workspace_id, v_metric) then
      raise exception 'not allowed to read the % figures of this workspace', v_metric
        using errcode = '42501';
    end if;
  end loop;
  -- Read after the batch's own checks, so they answer first.$a$);
  if v_def is null then raise exception '0663: bi_query_batch_v1 anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(663);
