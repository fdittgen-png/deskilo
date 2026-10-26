-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two rows of the settings registry; no function, table or policy)
--
-- 9999 (#2378) -- where a space's records are kept, as far as anyone has
-- declared it:
--
--   records.hosting_country               text, platform, default ''
--       the country (ISO 3166-1 alpha-2) where this installation keeps its
--       database and backups, as its operator declares it from the hosting
--       contract. Empty means not declared, and the app then states no
--       location: a region the app was built with is no evidence.
--   records.cra_authorisation_reference   text, workspace, default ''
--       the reference of the CRA authorisation that lets a Canadian
--       business keep its records outside Canada (ETA s.286, ITA s.230).
--
-- The accounting settings show both; a Canadian space whose records are
-- not declared in Canada sees the notice, and its archive's README states
-- the location. Nothing on the server reads them yet.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('records.cra_authorisation_reference', 'text', '""'::jsonb, null, null, '', 'records', array['workspace'], 'manageBilling', null, true, null, 'records location (#2378): ETA s.286, ITA s.230', 'The reference of the CRA authorisation that lets a Canadian business keep its records outside Canada. Empty means none is recorded; the app then says the records are kept outside Canada without one.'),
('records.hosting_country', 'text', '""'::jsonb, null, null, '', 'records', array['platform'], 'workspaceSettings', null, true, null, 'records location (#2378): the operator''s declaration', 'The country (ISO 3166-1 alpha-2, e.g. CA or DE) where this installation keeps its database and backups, as its operator declares it from the hosting contract. Empty, or anything that is not a two-letter code, means not declared: the app then states no location.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(9999);
