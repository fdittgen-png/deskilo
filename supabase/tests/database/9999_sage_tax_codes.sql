-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2373 / 9999: the Sage 50 UK codes of the reverse charge. A service to a
-- business in another EU member state is T22, the domestic reverse charge
-- T20; both are valid sage rows that name no account, in force today,
-- unconfirmed; goods to another member state (T4) have no row. Rolled back.
begin;
select plan(6);

-- The reader answers a signed-in caller only; no row is written here.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002373","role":"authenticated"}', true);

select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'GB', '2026-06-01')
            where key = 'sage/tax_eu_services'), 'T22',
          'a service to a business in another EU member state is coded T22');
select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'GB', '2026-06-01')
            where key = 'sage/tax_reverse_charge'), 'T20',
          'the domestic reverse charge is coded T20');
select ok((select bool_and(public.tax_reference_valid('account_map', value) and not value ? 'account')
             from public.tax_reference
            where domain = 'account_map' and country = 'GB'
              and key in ('sage/tax_eu_services', 'sage/tax_reverse_charge')),
          'both are valid sage tax-code rows that name no account');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and country = 'GB'
              and key in ('sage/tax_eu_services', 'sage/tax_reverse_charge') and confirmed), 0,
          'they stay unconfirmed until an accountant has checked them');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and key = 'sage/tax_eu_goods'), 0,
          'goods to another member state have no code: the app sells none');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and country = 'GB' and key like 'sage/%'), 11,
          'the Sage 50 UK rows: three nominal codes, the write-off nominal and seven tax codes');

select * from finish();
rollback;
