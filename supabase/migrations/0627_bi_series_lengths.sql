-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (three rows of the settings registry; no function, no table)
--
-- 0627 (#2578 BI B1) -- how far back an evolution looks is the workspace's
-- setting, not a literal of the app: bi.series_months (13, a year and the
-- same month a year ago), bi.series_quarters (9) and bi.series_years (5),
-- the lengths the app used until now. The client reads them; the batch's
-- own bounds (bi.batch_max_requests, bi.batch_time_budget_ms) still cap
-- what one read may ask for.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('bi.series_months', 'int', '13'::jsonb, 2, 60, 'months', 'kpi', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'biModuleSeries (#2578)', 'How many months a monthly evolution looks back over, the current one included: 13 is a year and the same month a year ago.'),
('bi.series_quarters', 'int', '9'::jsonb, 2, 40, 'quarters', 'kpi', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'biModuleSeries (#2578)', 'How many quarters a quarterly evolution looks back over, the current one included: 9 is two years and the same quarter two years ago.'),
('bi.series_years', 'int', '5'::jsonb, 2, 20, 'years', 'kpi', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'biModuleSeries (#2578)', 'How many years a yearly evolution looks back over, the current one included.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(627);
