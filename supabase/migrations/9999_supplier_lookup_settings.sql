-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2863 -- the supplier lookup's wait and quota are settings of the
-- server, not numbers in the edge function.
--
--   purchase.supplier_lookup_timeout_seconds   3..30 seconds, platform, default 15
--       how long `supplier-lookup` waits for the registry (VIES) to answer.
--   purchase.supplier_lookup_per_minute        1..120 requests, platform, default 20
--       how many lookups one caller may make per minute.
--
-- The function reads both with the caller's own token through
-- `setting_value(workspace, key)`; nothing else changes.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('purchase.supplier_lookup_timeout_seconds', 'duration', '15'::jsonb, 3, 30, 'seconds', 'billing', array['platform'], 'workspaceSettings', null, true, null, 'supplier-lookup (#2863)', 'Seconds the server waits for a company registry (VIES) to answer one supplier lookup before the lookup counts as timed out. The person keeps what they typed and may retry or go on by hand.'),
('purchase.supplier_lookup_per_minute', 'int', '20'::jsonb, 1, 120, 'requests', 'billing', array['platform'], 'workspaceSettings', null, true, null, 'supplier-lookup (#2863)', 'The most supplier lookups one person may make per minute on this server. A lookup over the limit is answered as throttled, nothing is sent to the registry, and the person may retry a minute later.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(9999);
