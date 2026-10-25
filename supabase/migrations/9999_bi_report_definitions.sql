-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 9999 (#2579 C2) -- a saved report is written safely and read within the
-- reader's rights. The table, its RLS and its list RPC are 0350's; the v2
-- shape is 0512's; the v1 versions are 0586's.
--
--   Retry. bi_view_save takes p_request_id (default null: the old clients'
--       call is unchanged). The same request with the same write, by the
--       same person, answers that write again and makes no second revision;
--       the same request id with another write is refused (22023). The id is
--       remembered on the row (last_request_id + the write's digest).
--   Conflicts. Unchanged rule, now said once more: every update names the
--       revision it read; a stale one is 40001 and writes nothing.
--   Sharing. A team view (and the team default, and deleting one) is written
--       by someone who reads analytics AND holds workspaceSettings or
--       designDocuments (bi_views_team_writer); the existing team writers keep
--       their right.
--   Scope. A definition names questions, and a reader only receives the
--       questions they may ask: bi_view_json hands each reader the definition
--       with every figure they may not read taken out (its id with it) and the
--       count of what was withheld. A writer may only save figures they may
--       read, at their current version (0A000 otherwise, never a silent
--       substitution), and may not save over a view holding figures they
--       cannot read (42501: they did not see them; they copy it instead).
--   Filters. A filter names a registered dimension (bi_report_dimensions);
--       page and visual filters only narrow the report's (and the page's): a
--       positive filter naming a value the level above does not admit is an
--       invalid combination (22023), never read as an override.
--   Limits. bi.report_max_pages / _visuals / _bytes are settings of the space
--       whose registry maxima (4, 24, 65536) are the platform guards that
--       bi_report_valid keeps; a report over the space's value is refused.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('bi.report_max_pages', 'int', '4'::jsonb, 1, 4, 'pages', 'kpi', array['workspace'], 'workspaceSettings', null, true, null, 'bi_view_save (#2579)', 'The most pages one saved report may hold in this space. The platform never stores more than 4; a report over the limit is refused when it is saved, never cut.'),
('bi.report_max_visuals', 'int', '24'::jsonb, 1, 24, 'cards', 'kpi', array['workspace'], 'workspaceSettings', null, true, null, 'bi_view_save (#2579)', 'The most cards (figures, tables, texts) one saved report may hold over all its pages. The platform never stores more than 24; a report over the limit is refused when it is saved, never cut.'),
('bi.report_max_bytes', 'int', '65536'::jsonb, 4096, 65536, 'bytes', 'kpi', array['workspace'], 'workspaceSettings', null, true, null, 'bi_view_save (#2579)', 'The largest saved report definition in this space, in bytes of its stored text. The platform never stores more than 65536; a definition holds questions, never figures, so this bounds names, titles and texts.')
on conflict (key) do nothing;
-- END GENERATED SEED

alter table public.bi_views add column if not exists last_request_id uuid;
alter table public.bi_views add column if not exists last_request_digest text;
create unique index if not exists bi_views_last_request
  on public.bi_views (workspace_id, last_request_id) where last_request_id is not null;

-- The dimensions a report filter or a visual's grouping may name: the KPI
-- catalogue's (bi_report_dimensions_test holds it equal to the Dart one).
create or replace function public.bi_report_dimensions()
returns text[] language sql immutable set search_path = public as $fn$
  select array['level', 'resource']::text[];
$fn$;
revoke execute on function public.bi_report_dimensions() from public, anon;

create or replace function public.bi_report_filters_valid(p jsonb)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  f jsonb;
begin
  if p is null or p = 'null'::jsonb then return true; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) > 12 then return false; end if;
  for f in select e from jsonb_array_elements(p) e loop
    if not coalesce(
         jsonb_typeof(f) = 'object'
         and not exists (select 1 from jsonb_object_keys(f) k
                          where k not in ('dimension', 'operator', 'value'))
         and jsonb_typeof(f -> 'dimension') = 'string'
         and (f ->> 'dimension') = any (public.bi_report_dimensions())
         and (f ->> 'operator') in ('eq', 'neq', 'in')
         and jsonb_typeof(f -> 'value') = 'string'
         and char_length(f ->> 'value') <= 64, false) then
      return false;
    end if;
  end loop;
  return true;
end;
$fn$;
revoke execute on function public.bi_report_filters_valid(jsonb) from public, anon;

-- Whether every filter of p_lower only narrows p_higher: a positive filter
-- (eq, in) names only values a positive higher filter of its dimension
-- admits, and none a higher neq excludes. An `in` lists its values with
-- commas.
create or replace function public.bi_report_filters_narrow(p_higher jsonb, p_lower jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select not exists (
    select 1
      from jsonb_array_elements(coalesce(nullif(p_lower, 'null'::jsonb), '[]'::jsonb)) l
      join jsonb_array_elements(coalesce(nullif(p_higher, 'null'::jsonb), '[]'::jsonb)) h
        on h ->> 'dimension' = l ->> 'dimension'
     where l ->> 'operator' in ('eq', 'in')
       and case when h ->> 'operator' = 'neq'
                then (h ->> 'value') = any (
                       case when l ->> 'operator' = 'in' then string_to_array(l ->> 'value', ',')
                            else array[l ->> 'value'] end)
                else not (
                       case when l ->> 'operator' = 'in' then string_to_array(l ->> 'value', ',')
                            else array[l ->> 'value'] end
                       <@
                       case when h ->> 'operator' = 'in' then string_to_array(h ->> 'value', ',')
                            else array[h ->> 'value'] end) end);
$fn$;
revoke execute on function public.bi_report_filters_narrow(jsonb, jsonb) from public, anon;

-- 0512's shape, with registered dimensions and narrowing filters.
create or replace function public.bi_report_valid(p jsonb)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  v_page jsonb;
  v_vis jsonb;
  v_ids text[] := '{}';
  v_orders int[];
  v_visuals int := 0;
  v_period jsonb;
  v_style jsonb;
  v_type text;
  v_above jsonb;
begin
  v_period := p -> 'period';
  v_style := coalesce(p -> 'printStyle', 'null'::jsonb);
  if not coalesce(
       jsonb_typeof(p) = 'object'
       and octet_length(p::text) <= 65536
       and p -> 'v' = '2'::jsonb
       and not exists (select 1 from jsonb_object_keys(p) k
                        where k not in ('v', 'reportFilters', 'period', 'pages', 'printStyle'))
       and public.bi_report_filters_valid(p -> 'reportFilters')
       and jsonb_typeof(p -> 'pages') = 'array'
       and jsonb_array_length(p -> 'pages') between 1 and 4
       and jsonb_typeof(v_period) = 'object'
       and (v_period ->> 'grain') in ('month', 'quarter', 'year')
       and (
         (v_period ->> 'mode' = 'relative'
          and not exists (select 1 from jsonb_object_keys(v_period) k
                           where k not in ('mode', 'grain', 'offset'))
          and jsonb_typeof(v_period -> 'offset') = 'number'
          and (v_period ->> 'offset') ~ '^-?[0-9]{1,3}$')
         or
         (v_period ->> 'mode' = 'fixed'
          and not exists (select 1 from jsonb_object_keys(v_period) k
                           where k not in ('mode', 'grain', 'at'))
          and jsonb_typeof(v_period -> 'at') = 'string'
          and (v_period ->> 'at') ~ case v_period ->> 'grain'
                when 'month' then '^2[0-9]{3}-(0[1-9]|1[0-2])$'
                when 'quarter' then '^2[0-9]{3}-Q[1-4]$'
                else '^2[0-9]{3}$' end))
       and (v_style = 'null'::jsonb or (
         jsonb_typeof(v_style) = 'object'
         and not exists (select 1 from jsonb_object_keys(v_style) k
                          where k not in ('paper', 'orientation', 'showSources'))
         and coalesce(v_style ->> 'paper', 'A4') in ('A4', 'Letter')
         and coalesce(v_style ->> 'orientation', 'portrait') in ('portrait', 'landscape')
         and coalesce(jsonb_typeof(v_style -> 'showSources'), 'boolean') = 'boolean')),
       false) then
    return false;
  end if;

  for v_page in select e from jsonb_array_elements(p -> 'pages') e loop
    if not coalesce(
         jsonb_typeof(v_page) = 'object'
         and not exists (select 1 from jsonb_object_keys(v_page) k
                          where k not in ('id', 'title', 'filters', 'visuals'))
         and jsonb_typeof(v_page -> 'id') = 'string'
         and (v_page ->> 'id') ~ '^[a-z0-9][a-z0-9_-]{0,31}$'
         and jsonb_typeof(v_page -> 'title') = 'string'
         and char_length(v_page ->> 'title') between 1 and 80
         and public.bi_report_filters_valid(v_page -> 'filters')
         and public.bi_report_filters_narrow(p -> 'reportFilters', v_page -> 'filters')
         and jsonb_typeof(coalesce(v_page -> 'visuals', '[]'::jsonb)) = 'array'
         and not ((v_page ->> 'id') = any (v_ids)), false) then
      return false;
    end if;
    v_ids := v_ids || (v_page ->> 'id');
    v_orders := '{}';
    v_above := coalesce(nullif(p -> 'reportFilters', 'null'::jsonb), '[]'::jsonb)
            || coalesce(nullif(v_page -> 'filters', 'null'::jsonb), '[]'::jsonb);
    for v_vis in select e from jsonb_array_elements(coalesce(v_page -> 'visuals', '[]'::jsonb)) e loop
      v_visuals := v_visuals + 1;
      v_type := v_vis ->> 'type';
      if v_visuals > 24 or not coalesce(
           jsonb_typeof(v_vis) = 'object'
           and not exists (select 1 from jsonb_object_keys(v_vis) k
                            where k not in ('id', 'type', 'metricId', 'metricVersion', 'dimension',
                                            'filters', 'sort', 'format', 'layout', 'interaction',
                                            'drill', 'text'))
           and jsonb_typeof(v_vis -> 'id') = 'string'
           and (v_vis ->> 'id') ~ '^[a-z0-9][a-z0-9_-]{0,31}$'
           and not ((v_vis ->> 'id') = any (v_ids))
           and v_type in ('kpi', 'line', 'bar', 'stackedBar', 'table', 'text')
           -- a text carries no metric; every other visual has one
           and ((v_type = 'text') = (coalesce(v_vis -> 'metricId', 'null'::jsonb) = 'null'::jsonb))
           and (coalesce(v_vis -> 'metricId', 'null'::jsonb) = 'null'::jsonb or (
                  jsonb_typeof(v_vis -> 'metricId') = 'string'
                  and (v_vis ->> 'metricId') ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
                  and char_length(v_vis ->> 'metricId') <= 64))
           and jsonb_typeof(v_vis -> 'metricVersion') = 'number'
           and (v_vis ->> 'metricVersion') ~ '^[0-9]{1,2}$'
           and (v_vis ->> 'metricVersion')::int between 1 and 99
           and (coalesce(v_vis -> 'dimension', 'null'::jsonb) = 'null'::jsonb or (
                  jsonb_typeof(v_vis -> 'dimension') = 'string'
                  and (v_vis ->> 'dimension') = any (public.bi_report_dimensions())))
           and public.bi_report_filters_valid(v_vis -> 'filters')
           and public.bi_report_filters_narrow(v_above, v_vis -> 'filters')
           and coalesce(v_vis ->> 'sort', 'natural') in ('natural', 'value_desc', 'value_asc')
           and coalesce(v_vis ->> 'format', 'auto') in ('auto', 'number', 'percent', 'currency')
           and coalesce(v_vis ->> 'interaction', 'filter') in ('filter', 'none')
           and (coalesce(v_vis -> 'drill', 'null'::jsonb) = 'null'::jsonb or (
                  jsonb_typeof(v_vis -> 'drill') = 'string'
                  and (v_vis ->> 'drill') ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
                  and char_length(v_vis ->> 'drill') <= 64))
           -- plain content only, and only on a text visual
           and (coalesce(v_vis -> 'text', 'null'::jsonb) = 'null'::jsonb
                  and v_type <> 'text'
                or jsonb_typeof(v_vis -> 'text') = 'string'
                  and v_type = 'text'
                  and char_length(v_vis ->> 'text') <= 500)
           and jsonb_typeof(v_vis -> 'layout') = 'object'
           and not exists (select 1 from jsonb_object_keys(v_vis -> 'layout') k
                            where k not in ('order', 'span', 'height'))
           and (v_vis -> 'layout' ->> 'order') ~ '^[0-9]{1,3}$'
           and (v_vis -> 'layout' ->> 'order')::int <= 255
           and (v_vis -> 'layout' ->> 'span') ~ '^[0-9]{1,2}$'
           and (v_vis -> 'layout' ->> 'span')::int between 1 and 12
           and (v_vis -> 'layout' ->> 'height') ~ '^[0-9]{1,2}$'
           and (v_vis -> 'layout' ->> 'height')::int between 1 and 12
           and not (((v_vis -> 'layout' ->> 'order')::int) = any (v_orders)), false) then
        return false;
      end if;
      v_ids := v_ids || (v_vis ->> 'id');
      v_orders := v_orders || ((v_vis -> 'layout' ->> 'order')::int);
    end loop;
  end loop;
  return true;
exception when others then
  return false;
end;
$fn$;
revoke execute on function public.bi_report_valid(jsonb) from public, anon;

-- The metric ids a stored definition names: a question's cards and the
-- versions it recorded, or every visual of every page of a report.
create or replace function public.bi_definition_metrics(p jsonb)
returns setof text language sql immutable set search_path = public as $fn$
  select c #>> '{}'
    from jsonb_array_elements(case when p -> 'v' = '1'::jsonb and jsonb_typeof(p -> 'cards') = 'array'
                                   then p -> 'cards' else '[]'::jsonb end) c
  union
  select k
    from jsonb_object_keys(case when p -> 'v' = '1'::jsonb and jsonb_typeof(p -> 'metrics') = 'object'
                                then p -> 'metrics' else '{}'::jsonb end) k
  union
  select v ->> 'metricId'
    from jsonb_array_elements(case when p -> 'v' = '2'::jsonb and jsonb_typeof(p -> 'pages') = 'array'
                                   then p -> 'pages' else '[]'::jsonb end) pg,
         jsonb_array_elements(case when jsonb_typeof(pg -> 'visuals') = 'array'
                                   then pg -> 'visuals' else '[]'::jsonb end) v
   where jsonb_typeof(v -> 'metricId') = 'string';
$fn$;
revoke execute on function public.bi_definition_metrics(jsonb) from public, anon, authenticated;

-- Whether the caller may read p_metric in the workspace now: every right
-- the KPI registry lists for it. An unknown metric is never readable.
create or replace function public.bi_metric_readable(p_workspace_id uuid, p_metric text)
returns boolean language sql stable set search_path = public as $fn$
  select coalesce((
    select bool_and(public.has_permission(p_workspace_id, perm))
      from jsonb_array_elements_text(public.kpi_registry() -> p_metric -> 'permissions') perm), false);
$fn$;
revoke execute on function public.bi_metric_readable(uuid, text) from public, anon, authenticated;

-- p as the caller may receive it: every figure they may not read is taken
-- out (its id and saved version with it). Pages, titles, texts and order
-- stay; nothing is renamed or substituted.
create or replace function public.bi_definition_for_reader(p_workspace_id uuid, p jsonb)
returns jsonb language plpgsql stable set search_path = public as $fn$
begin
  if not exists (select 1 from public.bi_definition_metrics(p) m
                  where not public.bi_metric_readable(p_workspace_id, m)) then
    return p;
  end if;
  if p -> 'v' = '1'::jsonb then
    return p
      || case when p ? 'cards' then jsonb_build_object('cards', coalesce((
             select jsonb_agg(c order by o)
               from jsonb_array_elements(p -> 'cards') with ordinality x(c, o)
              where public.bi_metric_readable(p_workspace_id, c #>> '{}')), '[]'::jsonb))
              else '{}'::jsonb end
      || case when p ? 'metrics' then jsonb_build_object('metrics', coalesce((
             select jsonb_object_agg(e.key, e.value)
               from jsonb_each(p -> 'metrics') e
              where public.bi_metric_readable(p_workspace_id, e.key)), '{}'::jsonb))
              else '{}'::jsonb end;
  end if;
  return p || jsonb_build_object('pages', (
    select jsonb_agg(pg || jsonb_build_object('visuals', coalesce((
             select jsonb_agg(v order by vo)
               from jsonb_array_elements(coalesce(pg -> 'visuals', '[]'::jsonb)) with ordinality y(v, vo)
              where coalesce(jsonb_typeof(v -> 'metricId'), 'null') <> 'string'
                 or public.bi_metric_readable(p_workspace_id, v ->> 'metricId')), '[]'::jsonb))
           order by po)
      from jsonb_array_elements(p -> 'pages') with ordinality x(pg, po)));
end;
$fn$;
revoke execute on function public.bi_definition_for_reader(uuid, jsonb) from public, anon, authenticated;

-- 0350's row, with the definition as the caller may receive it and the count
-- of the figures withheld from them.
create or replace function public.bi_view_json(v public.bi_views)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object(
    'id', v.id, 'scope', v.scope, 'name', v.name,
    'definition', public.bi_definition_for_reader(v.workspace_id, v.definition),
    'withheld', (select count(*) from public.bi_definition_metrics(v.definition) m
                  where not public.bi_metric_readable(v.workspace_id, m)),
    'is_default', v.is_default, 'revision', v.revision,
    'mine', v.user_id = auth.uid());
$fn$;
revoke execute on function public.bi_view_json(public.bi_views) from public, anon, authenticated;

-- Who writes the team's views and its default: an analytics reader who
-- manages the workspace or designs its documents.
create or replace function public.bi_views_team_writer(p_workspace_id uuid)
returns boolean language sql stable set search_path = public as $fn$
  select public.has_permission(p_workspace_id, 'viewAnalytics')
     and (public.has_permission(p_workspace_id, 'workspaceSettings')
          or public.has_permission(p_workspace_id, 'designDocuments'));
$fn$;
revoke execute on function public.bi_views_team_writer(uuid) from public, anon, authenticated;

drop function if exists public.bi_view_save(uuid, uuid, text, text, jsonb, int);

create or replace function public.bi_view_save(
  p_workspace_id uuid, p_id uuid, p_scope text, p_name text, p_definition jsonb,
  p_expected_revision int, p_request_id uuid default null
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.bi_views;
  v_digest text;
  v_metric text;
  v_known jsonb;
begin
  perform public.bi_views_gate(p_workspace_id);
  -- The same request, by the same person, with the same write, is answered
  -- once more; the same id with another write is refused.
  v_digest := md5(jsonb_build_array(auth.uid(), p_id, p_scope, btrim(coalesce(p_name, '')),
                                    p_definition, p_expected_revision)::text);
  if p_request_id is not null then
    select * into v from public.bi_views
     where workspace_id = p_workspace_id and last_request_id = p_request_id for update;
    if v.id is not null then
      if v.last_request_digest is distinct from v_digest then
        raise exception 'this request already saved something else' using errcode = '22023';
      end if;
      return public.bi_view_json(v);
    end if;
  end if;
  if p_scope is null or p_scope not in ('private', 'workspace') then
    raise exception 'a view is private or the workspace''s' using errcode = '22023';
  end if;
  if p_scope = 'workspace' and not public.bi_views_team_writer(p_workspace_id) then
    raise exception 'only someone who manages the workspace or designs its documents shares a view'
      using errcode = '42501';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'a view has a name of 1 to 80 characters' using errcode = '22023';
  end if;
  if not public.bi_definition_valid(p_definition) then
    raise exception 'the view definition is not a valid analysis definition' using errcode = '22023';
  end if;
  if p_definition -> 'v' = '2'::jsonb then
    -- A report is written only while the designer is on in this workspace,
    -- within the space's limits (the platform guards are bi_report_valid's).
    if not public.feature_effective(p_workspace_id, 'biReportDesigner') then
      raise exception 'the report designer is off in this workspace' using errcode = '0A000';
    end if;
    if jsonb_array_length(p_definition -> 'pages')
         > coalesce((public.setting_value(p_workspace_id, 'bi.report_max_pages') #>> '{}')::int, 4)
       or (select count(*) from jsonb_array_elements(p_definition -> 'pages') pg,
                                jsonb_array_elements(coalesce(pg -> 'visuals', '[]'::jsonb)) x)
         > coalesce((public.setting_value(p_workspace_id, 'bi.report_max_visuals') #>> '{}')::int, 24)
       or octet_length(p_definition::text)
         > coalesce((public.setting_value(p_workspace_id, 'bi.report_max_bytes') #>> '{}')::int, 65536) then
      raise exception 'the report is over this space''s limits' using errcode = '22023';
    end if;
    if not exists (select 1 from jsonb_object_keys(public.kpi_registry()) k
                    where public.bi_metric_readable(p_workspace_id, k)) then
      raise exception 'a report needs a figure its author may read' using errcode = '42501';
    end if;
  end if;
  -- Every figure: registered, at its current version, readable by the writer.
  for v_metric in select m from public.bi_definition_metrics(p_definition) m loop
    v_known := public.kpi_registry() -> v_metric;
    if v_known is null then
      raise exception 'unknown metric %', v_metric using errcode = '22023';
    end if;
    if (p_definition -> 'v' = '1'::jsonb
        and coalesce((p_definition -> 'metrics' ->> v_metric)::int, 1) <> (v_known ->> 'version')::int)
       or (p_definition -> 'v' = '2'::jsonb and exists (
             select 1 from jsonb_array_elements(p_definition -> 'pages') pg,
                           jsonb_array_elements(coalesce(pg -> 'visuals', '[]'::jsonb)) x
              where x ->> 'metricId' = v_metric
                and (x ->> 'metricVersion')::int <> (v_known ->> 'version')::int)) then
      raise exception 'metric % is at another version here', v_metric using errcode = '0A000';
    end if;
    if not public.bi_metric_readable(p_workspace_id, v_metric) then
      raise exception 'a view holds only figures its writer may read' using errcode = '42501';
    end if;
  end loop;
  if p_id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale view' using errcode = '40001';
    end if;
    insert into public.bi_views (workspace_id, user_id, scope, name, definition,
                                 last_request_id, last_request_digest)
    values (p_workspace_id, auth.uid(), p_scope, btrim(p_name), p_definition,
            p_request_id, case when p_request_id is not null then v_digest end)
    returning * into v;
  else
    select * into v from public.bi_views
     where id = p_id and workspace_id = p_workspace_id for update;
    if v.id is null
       or (v.scope = 'private' and v.user_id <> auth.uid())
       or (v.scope = 'workspace' and not public.bi_views_team_writer(p_workspace_id)) then
      raise exception 'not a view you may change' using errcode = '42501';
    end if;
    if v.scope <> p_scope then
      raise exception 'a view keeps its scope; save a copy instead' using errcode = '22023';
    end if;
    -- A writer who was not shown every figure cannot keep the others.
    if exists (select 1 from public.bi_definition_metrics(v.definition) m
                where not public.bi_metric_readable(p_workspace_id, m)) then
      raise exception 'this view holds figures you may not read; save a copy instead'
        using errcode = '42501';
    end if;
    if coalesce(p_expected_revision, -1) <> v.revision then
      raise exception 'stale view: someone saved it since you read it' using errcode = '40001';
    end if;
    -- An older writer never erases a report it cannot read.
    if v.definition -> 'v' = '2'::jsonb and p_definition -> 'v' <> '2'::jsonb then
      raise exception 'this view is a report; a version-1 writer cannot overwrite it'
        using errcode = '0A000';
    end if;
    update public.bi_views
       set name = btrim(p_name), definition = p_definition, revision = v.revision + 1,
           last_request_id = p_request_id,
           last_request_digest = case when p_request_id is not null then v_digest end
     where id = v.id
     returning * into v;
  end if;
  return public.bi_view_json(v);
end;
$fn$;
revoke execute on function public.bi_view_save(uuid, uuid, text, text, jsonb, int, uuid) from public, anon;
grant execute on function public.bi_view_save(uuid, uuid, text, text, jsonb, int, uuid) to authenticated;

-- 0350's delete: a team view by a team writer.
create or replace function public.bi_view_delete(p_workspace_id uuid, p_id uuid, p_expected_revision int)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.bi_views;
begin
  perform public.bi_views_gate(p_workspace_id);
  select * into v from public.bi_views
   where id = p_id and workspace_id = p_workspace_id for update;
  if v.id is null
     or (v.scope = 'private' and v.user_id <> auth.uid())
     or (v.scope = 'workspace' and not public.bi_views_team_writer(p_workspace_id)) then
    raise exception 'not a view you may delete' using errcode = '42501';
  end if;
  if coalesce(p_expected_revision, -1) <> v.revision then
    raise exception 'stale view: someone saved it since you read it' using errcode = '40001';
  end if;
  delete from public.bi_views where id = v.id;
end;
$fn$;
revoke execute on function public.bi_view_delete(uuid, uuid, int) from public, anon;
grant execute on function public.bi_view_delete(uuid, uuid, int) to authenticated;

-- 0350's defaults: the team default by a team writer.
create or replace function public.bi_view_set_default(p_workspace_id uuid, p_scope text, p_id uuid)
returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.bi_views_gate(p_workspace_id);
  if p_scope is null or p_scope not in ('private', 'workspace') then
    raise exception 'a default is mine or the workspace''s' using errcode = '22023';
  end if;
  if p_scope = 'workspace' and not public.bi_views_team_writer(p_workspace_id) then
    raise exception 'only someone who may share views sets the team''s default view'
      using errcode = '42501';
  end if;
  if p_id is not null and not exists (
       select 1 from public.bi_views v
        where v.id = p_id and v.workspace_id = p_workspace_id and v.scope = p_scope
          and (p_scope = 'workspace' or v.user_id = auth.uid())) then
    raise exception 'not a view you may make the default' using errcode = '42501';
  end if;
  update public.bi_views set is_default = false
   where workspace_id = p_workspace_id and scope = p_scope and is_default
     and (p_scope = 'workspace' or user_id = auth.uid())
     and id is distinct from p_id;
  if p_id is not null then
    update public.bi_views set is_default = true where id = p_id and not is_default;
  end if;
end;
$fn$;
revoke execute on function public.bi_view_set_default(uuid, text, uuid) from public, anon;
grant execute on function public.bi_view_set_default(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
