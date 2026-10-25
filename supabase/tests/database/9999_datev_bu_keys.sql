-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2375 / 9999: the DATEV BU-Schlüssel of each German rate group. A sale
-- booked to a revenue account that is not automatic carries the key of its
-- rate: 3 for the standard rate, 2 for the reduced one. The rows resolve
-- through the store's reader on any day, pass the account_map shape check,
-- and every German rate in force has its group's key. Rolled back.
begin;
select plan(6);

-- The reader answers a signed-in caller only; no row is written here.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002375","role":"authenticated"}', true);

select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'DE', '2026-06-01')
            where key = 'datev/tax:standard'), '3',
          'the standard rate''s BU-Schlüssel is 3');
select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'DE', '2026-06-01')
            where key = 'datev/tax:reduced'), '2',
          'the reduced rate''s BU-Schlüssel is 2');
select is((select string_agg(value ->> 'role', ',' order by key) from public.tax_reference
            where domain = 'account_map' and country = 'DE' and key like 'datev/tax:%'),
          'tax:reduced,tax:standard', 'the two rows carry their role and no chart suffix');
select ok((select bool_and(public.tax_reference_valid('account_map', value) and not value ? 'account')
             from public.tax_reference
            where domain = 'account_map' and country = 'DE' and key like 'datev/tax:%'),
          'both rows are valid tax-code rows that name no account');
select is((select count(*)::int
             from public.tax_reference('rate', 'DE', '2026-06-01') r
            where not exists (select 1 from public.tax_reference('account_map', 'DE', '2026-06-01') m
                               where m.key = 'datev/tax:' || (r.value ->> 'group'))), 0,
          'every German rate in force resolves to its group''s BU-Schlüssel');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and country = 'DE' and key like 'datev/tax:%' and confirmed), 0,
          'the keys stay unconfirmed until a tax adviser has checked them');

select * from finish();
rollback;
