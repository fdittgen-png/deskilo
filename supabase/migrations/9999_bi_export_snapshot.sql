-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 9999 (#2581) -- a report is printed and exported from one authorised
-- snapshot.
--
--   Print layout. bi_report_valid (restated whole from 0588) accepts the
--       saved print layout of a report: paper, orientation, margins
--       (narrow | normal | wide), a typed header and footer line (plain text,
--       one line, at most 120 characters), page breaks and the sources list.
--       Nothing else: no HTML, script, SQL or binding.
--   Export. bi_export_snapshot_v1(workspace, requests, report, revision,
--       format) answers the figures of one export, once. It checks, at that
--       moment and on its own: a signed-in person who is not a delegated
--       assistant, who reads the analytics AND may export data (42501); the
--       format (pdf | csv | xlsx, 22023) and its feature (pdfExport for a PDF,
--       dataExport for the data files; 0A000 when off); the size (more
--       requests than the space's batch limit is 54000, never a cut file);
--       every requested metric registered (22023) and readable by the caller
--       under its own rights (42501); and, for a saved report, that the
--       caller may read it, at the revision named (40001 otherwise), and asks
--       only figures it holds as this reader receives it (42501). The
--       figures come from the existing query authority (bi_query_batch_v1:
--       one statement, one snapshot); the answer carries the workspace, the
--       format and a SHA-256 digest of the figures.
--   Evidence. Every answered export appends one row to bi_export_evidence:
--       who, which workspace, report and revision, the format, a fingerprint
--       of the requests, the digest of the figures, their count and time.
--       Never a figure, a name or a filter value. Append-only; no client
--       reads or writes it directly.

-- 0588's shape, with the print layout of a report: margins, a typed header
-- and footer line, page breaks.
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
                          where k not in ('paper', 'orientation', 'showSources', 'margin',
                                          'header', 'footer', 'pageBreaks'))
         and coalesce(v_style ->> 'paper', 'A4') in ('A4', 'Letter')
         and coalesce(v_style ->> 'orientation', 'portrait') in ('portrait', 'landscape')
         and coalesce(jsonb_typeof(v_style -> 'showSources'), 'boolean') = 'boolean'
         and coalesce(v_style ->> 'margin', 'normal') in ('narrow', 'normal', 'wide')
         -- a typed line: plain text on one line, at most 120 characters
         and coalesce(jsonb_typeof(v_style -> 'header'), 'string') = 'string'
         and char_length(coalesce(v_style ->> 'header', '')) <= 120
         and coalesce(v_style ->> 'header', '') !~ '[\x01-\x1f\x7f]'
         and coalesce(jsonb_typeof(v_style -> 'footer'), 'string') = 'string'
         and char_length(coalesce(v_style ->> 'footer', '')) <= 120
         and coalesce(v_style ->> 'footer', '') !~ '[\x01-\x1f\x7f]'
         and coalesce(jsonb_typeof(v_style -> 'pageBreaks'), 'boolean') = 'boolean')),
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

create table if not exists public.bi_export_evidence (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  report_id uuid,
  report_revision integer,
  format text not null check (format in ('pdf', 'csv', 'xlsx')),
  filter_fingerprint text not null,
  result_hash text not null,
  requests integer not null check (requests >= 1),
  computed_at timestamptz not null
);
select public.ensure_system_columns('bi_export_evidence');
create index if not exists bi_export_evidence_workspace_idx
  on public.bi_export_evidence (workspace_id, computed_at desc);
create index if not exists bi_export_evidence_user_idx on public.bi_export_evidence (user_id);
alter table public.bi_export_evidence enable row level security;
revoke all on table public.bi_export_evidence from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.bi_export_evidence;
create policy mcp_delegated_deny on public.bi_export_evidence
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- Nothing edits a row; the one change allowed is the account's own erasure
-- (user_id set to null by its foreign key). A workspace's rows go with it.
create or replace function public.bi_export_evidence_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.user_id is null
     and row(new.id, new.workspace_id, new.report_id, new.report_revision, new.format,
             new.filter_fingerprint, new.result_hash, new.requests, new.computed_at)
         is not distinct from
         row(old.id, old.workspace_id, old.report_id, old.report_revision, old.format,
             old.filter_fingerprint, old.result_hash, old.requests, old.computed_at) then
    return new;
  end if;
  raise exception 'the export evidence is append-only';
end;
$fn$;
revoke execute on function public.bi_export_evidence_append_only() from public, anon, authenticated;
drop trigger if exists bi_export_evidence_append_only on public.bi_export_evidence;
create trigger bi_export_evidence_append_only
  before update on public.bi_export_evidence
  for each row execute function public.bi_export_evidence_append_only();

create or replace function public.bi_export_snapshot_v1(
  p_workspace_id uuid, p_requests jsonb, p_report_id uuid, p_report_revision int, p_format text
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_view public.bi_views;
  v_allowed text[];
  v_metric text;
  v_limit int;
  v_answer jsonb;
  v_hash text;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not public.has_permission(p_workspace_id, 'viewAnalytics')
     or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who reads this workspace''s analytics and may export its data exports them'
      using errcode = '42501';
  end if;
  if p_format is null or p_format not in ('pdf', 'csv', 'xlsx') then
    raise exception 'an export is a pdf, a csv or a workbook' using errcode = '22023';
  end if;
  if not public.feature_effective(p_workspace_id,
                                  case when p_format = 'pdf' then 'pdfExport' else 'dataExport' end) then
    raise exception 'this export is switched off in this workspace' using errcode = '0A000';
  end if;
  if p_requests is null or jsonb_typeof(p_requests) <> 'array' or jsonb_array_length(p_requests) < 1 then
    raise exception 'an export asks at least one figure' using errcode = '22023';
  end if;
  v_limit := public.bi_batch_limit(p_workspace_id);
  if jsonb_array_length(p_requests) > v_limit then
    raise exception 'an export carries at most % figures; narrow the report', v_limit
      using errcode = '54000';
  end if;
  -- A saved report: one the caller may read, at the revision they opened,
  -- asking only the figures it holds as this reader receives it.
  if p_report_id is not null then
    select * into v_view from public.bi_views
     where id = p_report_id and workspace_id = p_workspace_id
       and (scope = 'workspace' or user_id = auth.uid());
    if v_view.id is null then
      raise exception 'not a report you may read here' using errcode = '42501';
    end if;
    if p_report_revision is distinct from v_view.revision then
      raise exception 'stale report: it was saved again since you opened it' using errcode = '40001';
    end if;
    v_allowed := array(select public.bi_definition_metrics(
                   public.bi_definition_for_reader(p_workspace_id, v_view.definition)));
  end if;
  for v_metric in select distinct coalesce(case when jsonb_typeof(r) = 'object' then r ->> 'metric_id' end, '')
                    from jsonb_array_elements(p_requests) r loop
    if public.kpi_registry() -> v_metric is null then
      raise exception 'an export asks registered figures only' using errcode = '22023';
    end if;
    if not public.bi_metric_readable(p_workspace_id, v_metric) then
      raise exception 'an export holds only figures its reader may read' using errcode = '42501';
    end if;
    if p_report_id is not null and not (v_metric = any (v_allowed)) then
      raise exception 'an export of a report asks only that report''s figures' using errcode = '42501';
    end if;
  end loop;
  -- The existing query authority answers; a refusal of the reader refuses
  -- the whole export.
  v_answer := public.bi_query_batch_v1(p_workspace_id, p_requests);
  v_hash := encode(sha256(convert_to((v_answer -> 'results')::text, 'UTF8')), 'hex');
  insert into public.bi_export_evidence (workspace_id, user_id, report_id, report_revision, format,
                                         filter_fingerprint, result_hash, requests, computed_at)
  values (p_workspace_id, auth.uid(), p_report_id, v_view.revision, p_format,
          md5(p_requests::text), v_hash, jsonb_array_length(p_requests),
          (v_answer ->> 'computed_at')::timestamptz);
  return v_answer || jsonb_build_object(
    'workspace_id', p_workspace_id, 'format', p_format, 'hash', v_hash,
    'report_id', p_report_id, 'report_revision', v_view.revision);
end;
$fn$;
revoke execute on function public.bi_export_snapshot_v1(uuid, jsonb, uuid, int, text) from public, anon;
grant execute on function public.bi_export_snapshot_v1(uuid, jsonb, uuid, int, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(9999);
