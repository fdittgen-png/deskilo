-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2487 / 0457 (S4 of #2483, second checkpoint): the readiness recent-export
-- window and the four query-range guardrails are registry settings the SQL
-- reads. Real roles (authenticated through the writer); every scene proves
-- today's behaviour first, then the changed value.
--   A the rows, their defaults and the guardrails' read-only flag
--   B readiness: an export 100 days old is stale at 90, recent at a workspace
--     window of 120, stale again at 7 for an export 10 days old; bounds refuse
--   C the guardrails: the bound is accepted, one past it refused with the
--     unchanged sentence; nobody can change a guardrail
begin;
select plan(29);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$f$;

-- The refusal text of a setting write as [p_user]; '' when it was saved.
create function pg_temp.write_error(p_user uuid, p_ws uuid, p_key text, p_value text) returns text
language plpgsql as $f$
begin
  perform pg_temp.act_as(p_user);
  perform public.set_setting(p_ws, p_key, p_value::jsonb, 'test');
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$f$;

-- A field of the recovery section, as the owner reads it.
create function pg_temp.recovery(p_key text) returns text language plpgsql as $f$
declare v text;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-000024870001');
  select e.value->>p_key into v
    from jsonb_array_elements(public.workspace_readiness(current_setting('t.ws')::uuid)) e
   where e.value->>'section' = 'recovery';
  reset role;
  return v;
end;
$f$;

-- The refusal text of a call as the owner; '' when it was answered.
create function pg_temp.refusal(p_sql text) returns text language plpgsql as $f$
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-000024870001');
  execute p_sql;
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$f$;

-- An assistant read of [p_days] days from now, as the owner; its refusal code.
create function pg_temp.mcp_code(p_days int) returns text language plpgsql as $f$
declare v text;
begin
  perform pg_temp.act_as('00000000-0000-4000-8000-000024870001');
  v := public.mcp_read_v1(current_setting('t.ws')::uuid,
    (select m from public.members m where m.workspace_id = current_setting('t.ws')::uuid
        and m.user_id = '00000000-0000-4000-8000-000024870001'),
    'list_my_reservations',
    jsonb_build_object('from', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'to', to_char((now() + make_interval(days => p_days)) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))->>'code';
  reset role;
  return coalesce(v, '');
end;
$f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-00002487' || lpad(i::text, 4, '0'))::uuid,
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@range-settings.test', '', now(), now(), now()
  from generate_series(1, 2) i;
-- 1 owner of the workspace, 2 the platform owner.
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-000024870002');

select pg_temp.act_as('00000000-0000-4000-8000-000024870001');
select set_config('t.ws', public.create_workspace('Range settings', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.record_workspace_export(current_setting('t.ws')::uuid, repeat('ab', 32), 3);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true, "invoicing": true, "workspaceStatus": true}'
 where id = current_setting('t.ws')::uuid;
-- The facade calls mcp_read_v1 as its owner; the test grants the owner the same.
grant execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) to authenticated;
update public.workspace_recovery_evidence set recorded_at = now() - interval '100 days'
 where workspace_id = current_setting('t.ws')::uuid;

-- A: the rows
select is((select count(*)::int from public.setting_definitions where key in (
  'readiness.recent_export_days', 'mcp.read_range_days', 'calendar.range_days',
  'kpi.capacity_range_days', 'kpi.finance_range_months')), 5, 'the five rows exist');
select is(concat_ws('/', public.setting_value(null, 'readiness.recent_export_days'),
  public.setting_value(null, 'mcp.read_range_days'), public.setting_value(null, 'calendar.range_days'),
  public.setting_value(null, 'kpi.capacity_range_days'), public.setting_value(null, 'kpi.finance_range_months')),
  '90/31/400/400/23', 'the defaults are today''s values');
select is((select scopes from public.setting_definitions where key = 'readiness.recent_export_days'),
  array['platform', 'workspace'], 'the export window is set per platform and per workspace');
select is((select count(*)::int from public.setting_definitions
            where key in ('mcp.read_range_days', 'calendar.range_days', 'kpi.capacity_range_days', 'kpi.finance_range_months')
              and not editable and scopes = array['platform']), 4,
  'the four guardrails are platform-only and read-only');

-- B: the readiness window
select is(pg_temp.recovery('reason'), 'stale_export', 'golden: an export 100 days old is stale at the default 90');
select is(pg_temp.recovery('state'), 'unverified', 'and recovery stays unverified');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870001', current_setting('t.ws')::uuid, 'readiness.recent_export_days', '120'), '',
  'the owner sets 120 days for the workspace');
select is(pg_temp.recovery('reason'), 'recent_export', 'the same export is now recent, at once');
select is(pg_temp.recovery('state'), 'ready', 'and recovery is ready');
update public.workspace_recovery_evidence set recorded_at = now() - interval '10 days'
 where workspace_id = current_setting('t.ws')::uuid;
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870001', current_setting('t.ws')::uuid, 'readiness.recent_export_days', '7'), '',
  'the owner shortens it to 7 days');
select is(pg_temp.recovery('reason'), 'stale_export', 'an export 10 days old is stale at 7');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870002', null, 'readiness.recent_export_days', '200'), '',
  'the platform owner sets 200 days');
select is(pg_temp.recovery('reason'), 'stale_export', 'the workspace''s own 7 still wins over the platform value');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870002', null, 'readiness.recent_export_days', '6') like '%is refused%',
  'a window of 6 days is refused');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870002', null, 'readiness.recent_export_days', '366') like '%is refused%',
  'a window past a year is refused');
select is(public.setting_value(null, 'readiness.recent_export_days'), '200'::jsonb,
  'the refusals left the stored platform value as it was');

-- C: the guardrails
select is(pg_temp.refusal(format($q$select public.calendar_items(%L, now(), now() + interval '400 days', null, null)$q$, current_setting('t.ws'))), '',
  'golden: a calendar range of exactly 400 days is answered');
select is(pg_temp.refusal(format($q$select public.calendar_items(%L, now(), now() + interval '401 days', null, null)$q$, current_setting('t.ws'))),
  'calendar range must be positive and at most 400 days', 'one more day is refused with the same sentence');
select is(pg_temp.refusal(format($q$select public.kpi_seat_capacity(%L, now() - interval '400 days', now(), null)$q$, current_setting('t.ws'))) like '%at most 400 days',
  false, 'a capacity period of exactly 400 days passes the range check');
select is(pg_temp.refusal(format($q$select public.kpi_seat_capacity(%L, now() - interval '401 days', now(), null)$q$, current_setting('t.ws'))),
  'the KPI period must be [from, to) with from < to, at most 400 days', 'one more day is refused with the same sentence');
select is(pg_temp.refusal(format($q$select public.kpi_finance_summary(%L, '2024-01', '2025-12')$q$, current_setting('t.ws'))) like '%at most 24 months',
  false, 'a finance span of 24 months passes the range check');
select is(pg_temp.refusal(format($q$select public.kpi_finance_summary(%L, '2024-01', '2026-01')$q$, current_setting('t.ws'))),
  'the KPI months must be YYYY-MM, from <= to, at most 24 months', '25 months are refused with the same sentence');
select is(pg_temp.mcp_code(31), '', 'golden: an assistant read over exactly 31 days is answered');
select is(pg_temp.mcp_code(32), 'window', 'a read over 32 days is refused as a window');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870002', null, 'calendar.range_days', '500') like '%guardrail%',
  'a platform owner cannot change the calendar guardrail');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870001', current_setting('t.ws')::uuid, 'kpi.capacity_range_days', '500') <> '',
  'nor can a workspace owner change the capacity guardrail');
select is(concat_ws('/', public.setting_value(null, 'mcp.read_range_days'), public.setting_value(null, 'calendar.range_days'),
  public.setting_value(null, 'kpi.capacity_range_days'), public.setting_value(null, 'kpi.finance_range_months')),
  '31/400/400/23', 'readback: the guardrails are unchanged');
select is((select count(*)::int from public.setting_values
            where key in ('mcp.read_range_days', 'calendar.range_days', 'kpi.capacity_range_days', 'kpi.finance_range_months')), 0,
  'and no value row exists for any of them');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870001', current_setting('t.ws')::uuid, 'readiness.recent_export_days', '90'), '',
  'control: the editable export window still saves');

select * from finish();
rollback;
