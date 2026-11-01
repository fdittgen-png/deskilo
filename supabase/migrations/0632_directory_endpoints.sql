-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two rows of the settings registry; no function, no table)
--
-- 0632 (#2488, S5 of #2483) -- the discovery map's tile server and the
-- directory's address lookup are platform settings, so the operator of a
-- self-hosted installation points them at their own services without a
-- rebuild: directory.tile_url_template and directory.geocoder_url, whose
-- defaults are the public services the app used until now. Precedence in
-- the app: a stored platform value, then the build's own --dart-define,
-- then this default; a stored value that is not a public https endpoint is
-- ignored (the app parses it; this registry checks the length only).

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('directory.geocoder_url', 'text', '"https://photon.komoot.io/api/"'::jsonb, null, 512, 'url', 'region', array['platform'], 'workspaceSettings', null, true, null, 'PhotonDirectoryGeocoder (#2488): Photon public instance', 'The address-lookup service (Photon API) that places a published workspace address on the discovery map. An https address on the public internet, without credentials, query or fragment. Empty or invalid: the address this app build was given, else this default.'),
('directory.tile_url_template', 'text', '"https://tile.openstreetmap.org/{z}/{x}/{y}.png"'::jsonb, null, 512, 'url template', 'region', array['platform'], 'workspaceSettings', null, true, null, 'DirectoryMap (#2488): OpenStreetMap standard tiles', 'The tile server the discovery map is drawn from, as a template with {z}, {x} and {y} (and optionally {s} for a subdomain). An https address on the public internet, without credentials or fragment. Empty or invalid: the template this app build was given, else this default. Changing the host asks each person again before the map loads.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(632);
