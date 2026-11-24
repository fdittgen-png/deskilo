-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3732 / 0946: the support window of older apps is a setting of the installation (platform scope),
-- default 30 days, 1..365, read through the one resolver; never a number in a function.
begin;
select plan(8);

select is((select type from public.setting_definitions where key = 'apps.support_window_days'),
  'int', 'the support window is registered as an integer');
select is((select default_value from public.setting_definitions where key = 'apps.support_window_days'),
  '30'::jsonb, 'its default is 30 days');
select is((select (min_value, max_value)::text from public.setting_definitions where key = 'apps.support_window_days'),
  '(1,365)', 'it is bounded to 1..365');
select is((select unit from public.setting_definitions where key = 'apps.support_window_days'),
  'days', 'its unit is days');
select is((select scopes from public.setting_definitions where key = 'apps.support_window_days'),
  array['platform'], 'it belongs to the installation, not to a workspace');
select ok((select editable from public.setting_definitions where key = 'apps.support_window_days'),
  'the operator may change it');
select is(public.setting_value(null, 'apps.support_window_days'), '30'::jsonb,
  'the resolver answers the default when the installation set none');
select ok(public.deskilo_schema_version() >= 946, 'the version marker reaches 0946');

select * from finish();
rollback;
