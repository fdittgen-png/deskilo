-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (setting_value_problem restated whole, a text row's max_value now bounds
-- its length; two rows of the settings registry; no table, no policy)
--
-- 0606 (#2378) -- where a space's records are kept, as far as anyone has
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
--
-- Review of #3059: the hosting country is a choice over the countries the
-- app knows (plus '' for not declared), so "Germany" is refused by
-- set_setting as not one of the choices; the CRA reference is bounded at
-- 64 characters -- the registry's first text rows, and `setting_value_problem`
-- (0428) ignored min/max for text. Restated whole: a text value longer than
-- max_value is refused ("longer than N characters"); every other branch is
-- 0428's. A reference recorded on a non-Canadian space is kept and ignored.

create or replace function public.setting_value_problem(
  p_type text, p_value jsonb, p_min numeric, p_max numeric, p_floor numeric, p_choices jsonb)
returns text language plpgsql immutable set search_path = public as $fn$
declare
  v_n numeric;
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then return 'a value is required'; end if;
  case p_type
    when 'int', 'duration' then
      if jsonb_typeof(p_value) <> 'number' then return 'a whole number is required'; end if;
      v_n := (p_value #>> '{}')::numeric;
      if v_n <> trunc(v_n) then return 'a whole number is required'; end if;
      if p_floor is not null and v_n < p_floor then return format('below the security floor of %s', p_floor); end if;
      if p_min is not null and v_n < p_min then return format('below the minimum of %s', p_min); end if;
      if p_max is not null and v_n > p_max then return format('above the maximum of %s', p_max); end if;
    when 'bool' then
      if jsonb_typeof(p_value) <> 'boolean' then return 'true or false is required'; end if;
    when 'text' then
      if jsonb_typeof(p_value) <> 'string' then return 'text is required'; end if;
      if p_max is not null and length(p_value #>> '{}') > p_max then
        return format('longer than %s characters', p_max);
      end if;
    when 'enum' then
      if jsonb_typeof(p_value) <> 'string' or p_choices is null or not (p_choices @> to_jsonb(p_value #>> '{}')) then
        return 'not one of the choices';
      end if;
    else
      return 'unknown type';
  end case;
  return null;
end;
$fn$;
revoke execute on function public.setting_value_problem(text, jsonb, numeric, numeric, numeric, jsonb) from public, anon, authenticated;

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('records.cra_authorisation_reference', 'text', '""'::jsonb, null, 64, '', 'records', array['workspace'], 'manageBilling', null, true, null, 'records location (#2378): ETA s.286, ITA s.230', 'The reference of the CRA authorisation that lets a Canadian business keep its records outside Canada. Empty means none is recorded; the app then says the records are kept outside Canada without one.'),
('records.hosting_country', 'enum', '""'::jsonb, null, null, '', 'records', array['platform'], 'workspaceSettings', null, true, '["","AT","BE","CY","DE","EE","ES","FI","FR","GR","HR","IE","IT","LT","LU","LV","MT","NL","PT","SI","SK","BG","CZ","DK","HU","PL","RO","SE","CH","NO","GB","US","CA"]'::jsonb, 'records location (#2378): the operator''s declaration', 'The country (ISO 3166-1 alpha-2) where this installation keeps its database and backups, as its operator declares it from the hosting contract: one of the countries the app knows, or empty. Empty means not declared: the app then states no location.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(606);
