-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4416 -- an error the app recorded may reach the person's own installation, never a third party.
--
--   public.trace_reports        insert-only: one redacted error report per row (app version, schema, platform, the
--                               failure's type and code, the scrubbed stack). No typed value, token, e-mail or name
--                               is ever a column; the app redacts the stack as the support bundle does.
--   submit_trace_report_v1      the one way in. A signed-in person only, never an assistant's delegated session
--                               (DKN01). A malformed device id, too large or over the person's hourly budget is an
--                               answer ('malformed', 'too_large', 'rate_limited'), not an error: the app drops it.
--                               The budget is the signed-in person's (created_by_user), never the device id's: the
--                               app names the device, so a made-up id per report must not reset it.
--   instance_trace_reports_v1   the one way out: the installation's operator reads the newest reports. A business
--                               member never sees them.
--   The one refusal carries a code the app maps: DKN01 (nobody signed in, or an assistant's session).
--   trace.reports_per_hour      0..600 per person and hour (0 turns reports off), platform scope, default 20.
--   trace.report_max_bytes      1024..262144 bytes per report, default 16384.
--   trace.report_retention_days 1..365 days, default 30; older reports are deleted when a new one arrives.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('trace.reports_per_hour', 'int', '20'::jsonb, 0, 600, 'per hour', 'diagnostics', array['platform'], 'workspaceSettings', null, true, null, 'error reports (#4416)', 'How many error reports one signed-in person may send to this installation in an hour, from all their devices together. Further reports in that hour are dropped, never queued or retried. 0 turns error reports off for everybody.'),
('trace.report_max_bytes', 'int', '16384'::jsonb, 1024, 262144, 'bytes', 'diagnostics', array['platform'], 'workspaceSettings', null, true, null, 'error reports (#4416)', 'The largest error report this installation accepts: its type, code, versions and the redacted stack together. A larger report is dropped; the app cuts its stack to fit before it sends.'),
('trace.report_retention_days', 'int', '30'::jsonb, 1, 365, 'days', 'diagnostics', array['platform'], 'workspaceSettings', null, true, null, 'error reports (#4416)', 'How many days this installation keeps an error report. Older reports are deleted when a new one arrives.')
on conflict (key) do nothing;
-- END GENERATED SEED

create table if not exists public.trace_reports (
  id uuid primary key default gen_random_uuid(),
  reported_at timestamptz not null default now(),
  device_id text not null check (device_id ~ '^[A-Za-z0-9_-]{8,64}$'),
  app_version text not null check (char_length(app_version) between 1 and 40),
  schema_version integer check (schema_version >= 0),
  platform text not null check (char_length(platform) between 1 and 40),
  failure_type text not null check (char_length(failure_type) between 1 and 120),
  failure_code text check (char_length(failure_code) <= 80),
  stack text not null default ''
);
select public.ensure_system_columns('trace_reports');
create index if not exists trace_reports_sender_time on public.trace_reports (created_by_user, reported_at desc);
create index if not exists trace_reports_time on public.trace_reports (reported_at);

alter table public.trace_reports enable row level security;
-- No select, insert, update or delete policy: the two definer functions below are the only doors.
drop policy if exists mcp_delegated_deny on public.trace_reports;
create policy mcp_delegated_deny on public.trace_reports as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke all on public.trace_reports from public, anon, authenticated;

create or replace function public.submit_trace_report_v1(
  p_device_id text,
  p_app_version text,
  p_schema_version integer,
  p_platform text,
  p_failure_type text,
  p_failure_code text,
  p_stack text
) returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_per_hour integer := (public.setting_value(null, 'trace.reports_per_hour') #>> '{}')::integer;
  v_max_bytes integer := (public.setting_value(null, 'trace.report_max_bytes') #>> '{}')::integer;
  v_keep_days integer := (public.setting_value(null, 'trace.report_retention_days') #>> '{}')::integer;
  v_recent integer;
begin
  if auth.uid() is null then
    raise exception 'sign in to send an error report' using errcode = 'DKN01';
  end if;
  if public.mcp_is_delegated() then
    raise exception 'an assistant''s session sends no error report' using errcode = 'DKN01';
  end if;
  if p_device_id is null or p_device_id !~ '^[A-Za-z0-9_-]{8,64}$' then
    return 'malformed';
  end if;
  if octet_length(coalesce(p_app_version, '') || coalesce(p_platform, '') || coalesce(p_failure_type, '')
       || coalesce(p_failure_code, '') || coalesce(p_stack, '')) > v_max_bytes then
    return 'too_large';
  end if;
  -- One person's reports are counted one at a time: two at once never both slip under the budget.
  perform pg_advisory_xact_lock(hashtextextended('trace_reports:' || auth.uid()::text, 0));
  select count(*) into v_recent from public.trace_reports
   where created_by_user = auth.uid() and reported_at > now() - make_interval(hours => 1);
  if v_recent >= v_per_hour then
    return 'rate_limited';
  end if;
  delete from public.trace_reports where reported_at < now() - make_interval(days => v_keep_days);
  insert into public.trace_reports (device_id, app_version, schema_version, platform, failure_type, failure_code, stack)
  values (p_device_id, p_app_version, p_schema_version, p_platform, p_failure_type, nullif(p_failure_code, ''),
          coalesce(p_stack, ''));
  return 'stored';
end;
$fn$;
revoke execute on function public.submit_trace_report_v1(text, text, integer, text, text, text, text) from public, anon;
grant execute on function public.submit_trace_report_v1(text, text, integer, text, text, text, text) to authenticated;

create or replace function public.instance_trace_reports_v1(p_limit integer, p_before timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.instance_operator_require(false);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', r.id, 'reported_at', r.reported_at, 'device_id', r.device_id,
             'app_version', r.app_version, 'schema_version', r.schema_version, 'platform', r.platform,
             'failure_type', r.failure_type, 'failure_code', r.failure_code, 'stack', r.stack)
           order by r.reported_at desc)
      from (select * from public.trace_reports
             where p_before is null or reported_at < p_before
             order by reported_at desc
             limit greatest(coalesce(p_limit, 1), 1)) r), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.instance_trace_reports_v1(integer, timestamptz) from public, anon;
grant execute on function public.instance_trace_reports_v1(integer, timestamptz) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(956);
