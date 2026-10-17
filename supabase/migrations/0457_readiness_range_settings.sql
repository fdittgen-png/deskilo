-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0457 (#2487, S4 of #2483, second checkpoint) -- the readiness "recent
-- export" window and the four query-range guardrails are registry settings
-- that the SQL reads; defaults are today's values exactly.
--
--   readiness.recent_export_days   90 days, 7..365 (platform, workspace)
--   mcp.read_range_days            31 days   (read-only guardrail)
--   calendar.range_days            400 days  (read-only guardrail)
--   kpi.capacity_range_days        400 days  (read-only guardrail)
--   kpi.finance_range_months       23 months (read-only guardrail)
--
-- The four guardrails are platform-owned technical bounds on a query, not a
-- per-workspace permission to scan more: editable = false, platform scope,
-- and a note that says so. Their refusal texts name the registry value, so
-- the sentence stays true if the platform ever moves it. At the defaults
-- every refusal text and every result is byte-identical to before.
--
-- Not here (owner decisions, #2487): vat.vies_evidence_days and the MCP
-- notice read-state purge scope. Nothing is purged and no retention rule
-- changes: the legally constrained periods are #2571's.

-- ── the registry rows ────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('readiness.recent_export_days', 'duration', '90'::jsonb, 7, 365, 'days', 'readiness', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'workspace_readiness (0301, 0399)', 'Days an export the app recorded still counts as recent evidence that recovery works. Older than this, recovery reads as unverified.'),
('mcp.read_range_days', 'int', '31'::jsonb, 1, 93, 'days', 'security', array['platform'], 'workspaceSettings', null, false, null, 'mcp_read_v1 (0275, 0411)', 'Guardrail: the longest window one assistant read may ask for. A platform-owned bound on the query, not a permission to scan more.'),
('calendar.range_days', 'int', '400'::jsonb, 1, 800, 'days', 'booking', array['platform'], 'workspaceSettings', null, false, null, 'calendar_items (0133, 0428, 0452)', 'Guardrail: the longest range one calendar request may ask for. A platform-owned bound on the query.'),
('kpi.capacity_range_days', 'int', '400'::jsonb, 1, 800, 'days', 'kpi', array['platform'], 'workspaceSettings', null, false, null, 'kpi_seat_capacity (0333, 0336)', 'Guardrail: the longest period one capacity figure may cover. A platform-owned bound on the query.'),
('kpi.finance_range_months', 'int', '23'::jsonb, 1, 59, 'months', 'kpi', array['platform'], 'workspaceSettings', null, false, null, 'kpi_finance_summary (0351, 0398)', 'Guardrail: months beyond the first that one finance figure may span (23 means 24 months in all). A platform-owned bound on the query.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the anchored-patch helpers (session-local) ───────────────────────────
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

-- Patch a function's live definition: every anchor must be present exactly once.
create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  v_next text;
  v_pattern text;
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if position(p_old[i] in v_def) > 0 then
      if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
        raise exception '0457: anchor % occurs more than once in %', i, p_proc;
      end if;
    else
      v_pattern := regexp_replace(btrim(p_old[i], E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
      v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
      if (select count(*) from regexp_matches(v_def, v_pattern, 'g')) <> 1 then
        raise exception '0457: anchor % not found exactly once in %', i, p_proc;
      end if;
    end if;
    v_next := pg_temp.anchor_replace(v_def, p_old[i], p_new[i]);
    if v_next is null or v_next = v_def then
      raise exception '0457: anchor % did not change %', i, p_proc;
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public;


-- ── workspace_readiness: the recent-export window of its workspace ────────
select pg_temp.patch_function('public.workspace_readiness(uuid)'::regprocedure,
  array[$a$v_export >= now() - interval '90 days'$a$],
  array[$a$v_export >= now() - make_interval(days => (public.setting_value(p_workspace_id, 'readiness.recent_export_days') #>> '{}')::int)$a$]);

-- ── the four range guardrails (platform value) ────────────────────────────
select pg_temp.patch_function('public.mcp_read_v1(uuid, members, text, jsonb)'::regprocedure,
  array[$a$v_to - v_from > interval '31 days'$a$],
  array[$a$v_to - v_from > make_interval(days => (public.setting_value(null, 'mcp.read_range_days') #>> '{}')::int)$a$]);

select pg_temp.patch_function('public.calendar_items(uuid, timestamptz, timestamptz, text[], uuid)'::regprocedure,
  array[
    $a$p_to - p_from > interval '400 days'$a$,
    $a$calendar range must be positive and at most 400 days';$a$],
  array[
    $a$p_to - p_from > make_interval(days => (public.setting_value(null, 'calendar.range_days') #>> '{}')::int)$a$,
    $a$calendar range must be positive and at most % days', (public.setting_value(null, 'calendar.range_days') #>> '{}')::int;$a$]);

select pg_temp.patch_function('public.kpi_seat_capacity(uuid, timestamptz, timestamptz, uuid)'::regprocedure,
  array[
    $a$p_to - p_from > interval '400 days'$a$,
    $a$from < to, at most 400 days'$a$],
  array[
    $a$p_to - p_from > make_interval(days => (public.setting_value(null, 'kpi.capacity_range_days') #>> '{}')::int)$a$,
    $a$from < to, at most % days', (public.setting_value(null, 'kpi.capacity_range_days') #>> '{}')::int$a$]);

select pg_temp.patch_function('public.kpi_finance_summary(uuid, text, text)'::regprocedure,
  array[
    $a$+ interval '23 months'$a$,
    $a$from <= to, at most 24 months'$a$],
  array[
    $a$+ make_interval(months => (public.setting_value(null, 'kpi.finance_range_months') #>> '{}')::int)$a$,
    $a$from <= to, at most % months', (public.setting_value(null, 'kpi.finance_range_months') #>> '{}')::int + 1$a$]);

select public.set_deskilo_schema_version(457);
