-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (three rows of the settings registry; no function, no table)
--
-- 0633 (#2488, S5 of #2483) -- the currency, country and format locale a
-- screen falls back to when no workspace or device says anything are
-- platform settings, not constants of the app: locale.default_currency
-- (EUR), locale.default_country (FR) and locale.default_locale (en_US),
-- the values the app used until now. They are display and creation
-- defaults only: a missing issuer country or money currency is never
-- filled in from them.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('locale.default_currency', 'enum', '"EUR"'::jsonb, null, null, '', 'region', array['platform'], 'workspaceSettings', null, true, '["EUR","BGN","CZK","DKK","HUF","PLN","RON","SEK","CHF","NOK","GBP","USD","CAD"]'::jsonb, 'AppFormat fallback (#2488)', 'The currency a screen shows amounts in when no workspace is connected yet, and the one a new workspace starts from before a country is chosen. It never stands in for a missing financial fact: an invoice without its workspace currency is refused, not issued in this one.'),
('locale.default_country', 'enum', '"FR"'::jsonb, null, null, '', 'region', array['platform'], 'workspaceSettings', null, true, '["AT","BE","CY","DE","EE","ES","FI","FR","GR","HR","IE","IT","LT","LU","LV","MT","NL","PT","SI","SK","BG","CZ","DK","HU","PL","RO","SE","CH","NO","GB","US","CA"]'::jsonb, 'initialCountryFor (#2488)', 'The country a new workspace starts from when the device reports neither a known region nor a language the catalogue maps. A suggestion the person can change; it never decides an issuer country, tax or invoice.'),
('locale.default_locale', 'enum', '"en_US"'::jsonb, null, null, '', 'region', array['platform'], 'workspaceSettings', null, true, '["de_DE","de_AT","de_CH","en_GB","en_US","en_CA","en_IE","en_AU","es_ES","es_MX","fr_FR","fr_BE","fr_CA","fr_CH","it_IT","it_CH","nl_NL","nl_BE","pt_PT","pl_PL","sv_SE","da_DK","nb_NO","fi_FI","cs_CZ","hu_HU","ro_RO","el_GR","ja_JP"]'::jsonb, 'AppFormat fallback (#2488)', 'The number, date and clock format used before a member or a workspace has chosen one (a screen with no connection yet). A member''s own format preference always wins.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(633);
