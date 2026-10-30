-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one row of the settings registry; no table, no function, no policy)
--
-- 0610 (#3098, PERF-1 of the performance audit) -- when coming back to the
-- app re-reads everything it shows:
--
--   presence.resync_after_away_minutes    duration, platform + workspace, default 2
--       minutes the app must have been out of sight (background, hidden
--       tab, sleeping kiosk) before a resume resyncs. A focus change
--       (inactive -> resumed, every alt-tab on web) never resyncs; a lost
--       live connection always does, through the channel supervisor.
--
-- Only the client reads it. An app on an older server keeps the registry
-- default it was built with.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('presence.resync_after_away_minutes', 'duration', '2'::jsonb, 1, 1440, 'minutes', 'presence', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'ResumeResyncObserver (#3098)', 'Minutes the app must have been out of sight (in the background, a hidden tab, a sleeping kiosk) before it re-reads everything it shows when it comes back. A focus change never re-reads; a lost live connection always does, whatever this value.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(610);
