-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #3732 (K5) -- the support window is a setting of the installation, never a number in code.
--
--   apps.support_window_days   1..365 days, platform scope, default 30. How many days an app version stays
--       accepted after a newer one is available on the slowest channel the installation is distributed through.
--       The app floor (deskilo_app_floor(), 0900) is raised in a migration of its own only once this window has
--       passed since the newer app became available everywhere: widen the server, make the app available, wait
--       the window, then end the old contract. Read with setting_value(null, 'apps.support_window_days').

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('apps.support_window_days', 'int', '30'::jsonb, 1, 365, 'days', 'compatibility', array['platform'], 'workspaceSettings', null, true, null, 'support window (#3732)', 'How many days an app version stays accepted after a newer one is available on the slowest channel this installation is distributed through. The oldest app accepted (the app floor) is raised only once this many days have passed since the newer app became available everywhere: widen the server, make the app available, wait the window, then end the old contract.')
on conflict (key) do nothing;
-- END GENERATED SEED

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(946);
