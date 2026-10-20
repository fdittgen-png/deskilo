-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0512 (#2579 C1) -- a saved Web-BI view may be a REPORT (definition version 2).
--
-- 0350 stores a view as `{v:1, query, cards}`. Version 2 is a bounded declarative
-- document: `{v:2, reportFilters, period, pages:[{id,title,filters,visuals:[...]}],
-- printStyle}`. It holds questions, never answers or privileges: no figures, SQL,
-- formulas, links or HTML; text is plain content shown escaped. At most 4 pages,
-- 24 visuals, 64 KB; unique ids and reading orders; a 12-column discrete grid.
--
-- The writer is the same `bi_view_save`, with two version rules:
--   * a v2 definition is stored only while `biReportDesigner` is effective in the
--     workspace (0A000 otherwise); reading a stored report needs only the reader's
--     current analytics rights;
--   * a v1 definition never overwrites a stored v2 one (0A000): an older client that
--     cannot read a report must not erase what it does not understand.
-- Everything else (viewAnalytics, ownership, workspaceSettings for team views, the
-- revision check) is unchanged. The table, its policies and the other RPCs are 0350's.

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
         and (f ->> 'dimension') ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
         and char_length(f ->> 'dimension') <= 64
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
  v_grain text;
  v_type text;
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
         and jsonb_typeof(coalesce(v_page -> 'visuals', '[]'::jsonb)) = 'array'
         and not ((v_page ->> 'id') = any (v_ids)), false) then
      return false;
    end if;
    v_ids := v_ids || (v_page ->> 'id');
    v_orders := '{}';
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
                  and (v_vis ->> 'dimension') ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'
                  and char_length(v_vis ->> 'dimension') <= 64))
           and public.bi_report_filters_valid(v_vis -> 'filters')
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

-- v1 as in 0350 (2 KB, three keys), or a v2 report.
create or replace function public.bi_definition_valid(p jsonb)
returns boolean language sql immutable set search_path = public as $fn$
  select p is not null
     and jsonb_typeof(p) = 'object'
     and case p -> 'v'
           when '2'::jsonb then public.bi_report_valid(p)
           when '1'::jsonb then
                octet_length(p::text) <= 2048
            and not exists (select 1 from jsonb_object_keys(p) k where k not in ('v', 'query', 'cards'))
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
           else false end;
$fn$;
revoke execute on function public.bi_definition_valid(jsonb) from public, anon;

create or replace function public.bi_view_save(
  p_workspace_id uuid, p_id uuid, p_scope text, p_name text, p_definition jsonb,
  p_expected_revision int
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v public.bi_views;
begin
  perform public.bi_views_gate(p_workspace_id);
  if p_scope is null or p_scope not in ('private', 'workspace') then
    raise exception 'a view is private or the workspace''s' using errcode = '22023';
  end if;
  if p_scope = 'workspace' and not public.has_permission(p_workspace_id, 'workspaceSettings') then
    raise exception 'only someone who manages the workspace shares a view with it'
      using errcode = '42501';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'a view has a name of 1 to 80 characters' using errcode = '22023';
  end if;
  if not public.bi_definition_valid(p_definition) then
    raise exception 'the view definition is not a valid analysis definition' using errcode = '22023';
  end if;
  -- A report is written only while the designer is on in this workspace.
  if p_definition -> 'v' = '2'::jsonb
     and not public.feature_effective(p_workspace_id, 'biReportDesigner') then
    raise exception 'the report designer is off in this workspace' using errcode = '0A000';
  end if;
  if p_id is null then
    if coalesce(p_expected_revision, -1) <> 0 then
      raise exception 'stale view' using errcode = '40001';
    end if;
    insert into public.bi_views (workspace_id, user_id, scope, name, definition)
    values (p_workspace_id, auth.uid(), p_scope, btrim(p_name), p_definition)
    returning * into v;
  else
    select * into v from public.bi_views
     where id = p_id and workspace_id = p_workspace_id for update;
    if v.id is null
       or (v.scope = 'private' and v.user_id <> auth.uid())
       or (v.scope = 'workspace'
           and not public.has_permission(p_workspace_id, 'workspaceSettings')) then
      raise exception 'not a view you may change' using errcode = '42501';
    end if;
    if v.scope <> p_scope then
      raise exception 'a view keeps its scope; save a copy instead' using errcode = '22023';
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
       set name = btrim(p_name), definition = p_definition, revision = v.revision + 1
     where id = v.id
     returning * into v;
  end if;
  return public.bi_view_json(v);
end;
$fn$;
revoke execute on function public.bi_view_save(uuid, uuid, text, text, jsonb, int) from public, anon;
grant execute on function public.bi_view_save(uuid, uuid, text, text, jsonb, int) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(512);
