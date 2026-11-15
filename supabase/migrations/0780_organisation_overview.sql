-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one function)
--
-- #4007 (decision 0052, point 6) -- the houses of an organisation side by
-- side, each in its own currency, never added.
--
-- organisation_overview_v1(organisation, from, to) lists every house of the
-- organisation the caller is a member of (a development twin is not a
-- house of its own): its name, country, currency and time zone. Where the
-- caller may read that house's figures (the house's own analysis rights:
-- viewAnalytics and viewFinances), it gives exactly the figures the house's
-- own analysis shows, under the same names, from the same functions
-- (kpi_finance_summary, kpi_overdue_receivables): what it invoiced and
-- collected in the period (`kind: period`, with its months) and what is
-- overdue today (`kind: state`, with its as-of time). Nothing is computed
-- here that the house's page does not show. A house whose figures
-- the caller may not read is listed without them and says why
-- (`not_permitted`, or `not_enabled` when its analysis is off).
--
-- Totals are per currency: nothing is converted and nothing is added
-- across currencies. A total says when it is incomplete (a house of that
-- currency without figures, or a figure the house marks unavailable).
--
-- Someone who is a member of no house of the organisation reads nothing;
-- an assistant's token is refused; the head's `organisation` feature gates
-- the page.

create or replace function public.organisation_overview_v1(p_organisation uuid, p_from text, p_to text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_head uuid;
  v_house record;
  v_houses jsonb := '[]'::jsonb;
  v_totals jsonb := '{}'::jsonb;
  v_fin jsonb;
  v_overdue jsonb;
  v_figures jsonb;
  v_withheld text;
  v_total jsonb;
  v_incomplete boolean;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'only a person reads an organisation''s figures' using errcode = '42501';
  end if;
  select o.head_workspace_id into v_head from public.organisations o where o.id = p_organisation;
  if v_head is null or not exists (
       select 1 from public.workspaces w
        where w.organisation_id = p_organisation and public.is_member_of(w.id)) then
    raise exception 'only a member of a business of this organisation reads it' using errcode = '42501';
  end if;
  perform public.organisation_feature_check(v_head);

  for v_house in
    select w.id, w.name, upper(w.country_code) as country, upper(w.currency_code) as currency,
           coalesce(nullif(w.timezone, ''), 'UTC') as zone, w.id = v_head as is_head
      from public.workspaces w
     where w.organisation_id = p_organisation
       and public.is_member_of(w.id)
       and not (w.pair_id is not null and w.environment <> 'prod')
     order by w.id = v_head desc, lower(w.name), w.id
  loop
    v_fin := null; v_overdue := null; v_figures := null; v_withheld := null;
    if not (public.kpi_readable(v_house.id, 'finance.invoiced')
            and public.kpi_readable(v_house.id, 'finance.collected')
            and public.kpi_readable(v_house.id, 'sales.overdue_receivables')) then
      v_withheld := 'not_permitted';
    else
      if public.feature_effective(v_house.id, 'workspaceStatus') then
        v_fin := public.kpi_finance_summary(v_house.id, p_from, p_to);
      end if;
      if public.feature_effective(v_house.id, 'workspaceOverview') then
        v_overdue := public.kpi_overdue_receivables(v_house.id, p_from, p_to);
      end if;
      if v_fin is null and v_overdue is null then
        v_withheld := 'not_enabled';
      else
        -- each figure as the house's own analysis gives it: a period figure
        -- for the months asked, or a state as of when it was read
        v_figures := jsonb_build_object(
          'invoiced', case when v_fin is not null then jsonb_build_object(
            'minor', v_fin->'invoiced_minor', 'kind', 'period', 'from', p_from, 'to', p_to) end,
          'collected', case when v_fin is not null then jsonb_build_object(
            'minor', v_fin->'collected_minor', 'kind', 'period', 'from', p_from, 'to', p_to) end,
          'overdue', case when v_overdue is not null then jsonb_build_object(
            'minor', v_overdue->'value', 'kind', 'state', 'as_of', v_overdue->'computed_at') end,
          'quality', coalesce(v_fin->'quality', '[]'::jsonb) || coalesce(v_overdue->'quality', '[]'::jsonb),
          'reasons', coalesce(v_fin->'reasons', '[]'::jsonb) || coalesce(v_overdue->'reasons', '[]'::jsonb));
      end if;
    end if;
    v_houses := v_houses || jsonb_build_array(jsonb_build_object(
      'workspace_id', v_house.id, 'name', v_house.name, 'country', v_house.country,
      'currency', v_house.currency, 'zone', v_house.zone, 'is_head', v_house.is_head,
      'figures', v_figures, 'withheld', v_withheld));

    -- the total of this house's currency, never of another
    v_total := coalesce(v_totals->v_house.currency, jsonb_build_object(
      'currency', v_house.currency, 'houses', 0, 'invoiced', 0, 'collected', 0,
      'overdue', 0, 'incomplete', false));
    v_incomplete := v_figures is null
      or v_figures->'invoiced'->'minor' is null or v_figures->'invoiced'->'minor' = 'null'::jsonb
      or v_figures->'overdue'->'minor' is null or v_figures->'overdue'->'minor' = 'null'::jsonb
      or (v_figures->'quality') ? 'unavailable';
    v_total := v_total || jsonb_build_object(
      'houses', (v_total->>'houses')::int + 1,
      'invoiced', (v_total->>'invoiced')::bigint
        + case when (v_figures->'quality') ? 'unavailable' then 0
               else coalesce((v_figures->'invoiced'->>'minor')::bigint, 0) end,
      'collected', (v_total->>'collected')::bigint
        + case when (v_figures->'quality') ? 'unavailable' then 0
               else coalesce((v_figures->'collected'->>'minor')::bigint, 0) end,
      'overdue', (v_total->>'overdue')::bigint + coalesce((v_figures->'overdue'->>'minor')::bigint, 0),
      'incomplete', (v_total->>'incomplete')::boolean or v_incomplete);
    v_totals := v_totals || jsonb_build_object(v_house.currency, v_total);
  end loop;

  return jsonb_build_object(
    'organisation_id', p_organisation, 'from', p_from, 'to', p_to,
    'houses', v_houses,
    'totals', coalesce((select jsonb_agg(
                 t.value || jsonb_build_object(
                   'invoiced', jsonb_build_object('minor', t.value->>'invoiced', 'kind', 'period', 'from', p_from, 'to', p_to),
                   'collected', jsonb_build_object('minor', t.value->>'collected', 'kind', 'period', 'from', p_from, 'to', p_to),
                   'overdue', jsonb_build_object('minor', t.value->>'overdue', 'kind', 'state'))
                 order by t.key)
               from jsonb_each(v_totals) t), '[]'::jsonb),
    'computed_at', now());
end;
$fn$;
revoke execute on function public.organisation_overview_v1(uuid, text, text) from public, anon;
grant execute on function public.organisation_overview_v1(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(780);
