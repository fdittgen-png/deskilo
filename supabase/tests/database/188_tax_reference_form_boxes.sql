-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2480 (C4 of #2476, 0432): the `form_box` domain. The seeded rated boxes of
-- the four forms are rows with the shape the app reads; the shape check
-- refuses a box that selects nothing, a group nobody knows, a group both
-- taken and excluded, a percent in place of a group, and an unknown key.
-- Rolled back.
begin;
select plan(9);

select is((select count(*)::int from public.tax_reference where domain = 'form_box'), 15,
          'the fifteen rated boxes of the UStVA, CA3, Modelo 303 and MWST are rows');
select is((select value -> 'groups' ->> 0 from public.tax_reference
            where domain = 'form_box' and country = 'DE' and key = 'ustva/Kz 81'), 'standard',
          'Kz 81 takes the standard group');
select is((select value -> 'exclude_groups' from public.tax_reference
            where domain = 'form_box' and country = 'FR' and key = 'ca3/14'),
          '["standard","intermediate","reduced","super_reduced"]'::jsonb,
          'CA3 line 14 takes every group but the four named ones');

select ok(public.tax_reference_valid('form_box', '{"label":"Box","groups":["standard"]}'::jsonb)
          and public.tax_reference_valid('form_box', '{"label":"Box","exclude_groups":["standard","reduced"]}'::jsonb)
          and public.tax_reference_valid('form_box', '{"label":"Box","groups":["reduced"],"exclude_groups":["standard"]}'::jsonb),
          'a box takes groups, or all but some');
select ok(not public.tax_reference_valid('form_box', '{"label":"Box"}'::jsonb)
          and not public.tax_reference_valid('form_box', '{"label":"Box","groups":[]}'::jsonb),
          'a box that selects nothing is refused');
select ok(not public.tax_reference_valid('form_box', '{"label":"Box","groups":["lottery"]}'::jsonb)
          and not public.tax_reference_valid('form_box', '{"label":"Box","groups":[19]}'::jsonb)
          and not public.tax_reference_valid('form_box', '{"label":"Box","groups":"standard"}'::jsonb),
          'an unknown group, a number and a string in place of a list are refused');
select ok(not public.tax_reference_valid('form_box', '{"label":"Box","groups":["standard"],"exclude_groups":["standard"]}'::jsonb),
          'a group both taken and excluded is refused');
select ok(not public.tax_reference_valid('form_box', '{"label":"","groups":["standard"]}'::jsonb)
          and not public.tax_reference_valid('form_box', '{"groups":["standard"]}'::jsonb)
          and not public.tax_reference_valid('form_box', '{"label":"Box","groups":["standard"],"percent":19}'::jsonb),
          'a blank or missing label and a key the shape does not know are refused');
select throws_ok($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('form_box', 'DE', 'ustva/Kz 99', '2030-01-01', '{"label":"x","groups":["standard","lottery"]}', 'test', false)$$,
  '23514', null, 'the table refuses a form_box row of a wrong shape');

select * from finish();
rollback;
