-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2377 / 9999: the Swiss journal's reference rows. Every taxed Swiss rate
-- group in force has its MWST code for output tax, input tax and the input
-- tax of an investment; the shape check knows the `ch_kmu` format and still
-- refuses one it does not know; the KMU chart names the accounts the
-- posting engine books; nothing is confirmed. Rolled back.
begin;
select plan(9);

-- The reader answers a signed-in caller only; no row is written here.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002377","role":"authenticated"}', true);

select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'CH', '2026-06-01')
            where key = 'ch_kmu/tax:standard'), 'V81',
          'the normal rate''s sales are coded V81');
select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'CH', '2026-06-01')
            where key = 'ch_kmu/asset:intermediate'), 'I38',
          'an investment''s input tax at the accommodation rate is coded I38');
select is((select count(*)::int
             from public.tax_reference('rate', 'CH', '2026-06-01') r
             cross join unnest(array['tax', 'input', 'asset']) as k(kind)
            where r.value ->> 'category' = 'S'
              and not exists (select 1 from public.tax_reference('account_map', 'CH', '2026-06-01') m
                               where m.key = 'ch_kmu/' || k.kind || ':' || (r.value ->> 'group'))), 0,
          'every taxed Swiss rate in force has its code for sales, input tax and investments');
select is((select count(*)::int from public.tax_reference('account_map', 'CH', '2023-12-31')
            where key like 'ch_kmu/%'), 0,
          'no code before the rates of 2024 it names');
select ok((select bool_and(public.tax_reference_valid('account_map', value) and not value ? 'account')
             from public.tax_reference
            where domain = 'account_map' and country = 'CH' and key like 'ch_kmu/%'),
          'every code row is a valid tax-code row that names no account');
select ok(not public.tax_reference_valid('account_map',
            '{"format":"nope","role":"tax:standard","tax_code":"V81"}'::jsonb),
          'a format the shape check does not know is still refused');
select is((select string_agg(value ->> 'role' || '=' || (value ->> 'account'), ',' order by key)
             from public.tax_reference
            where domain = 'account_map' and country = 'CH'
              and key in ('coa/09-vat_input', 'coa/10-suppliers', 'coa/11-write_off', 'coa/15-revenue_exempt')),
          'vat_input=1170,suppliers=2000,write_off=3805,revenue:exempt=3402',
          'the KMU chart names the accounts the posting engine books');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and country = 'CH'
              and (key like 'ch_kmu/%' or key >= 'coa/09') and confirmed), 0,
          'the rows stay unconfirmed until a fiduciary has checked them');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and country = 'CH' and key like 'ch_kmu/%'), 9,
          'three rate groups, each for sales, input tax and investments');

select * from finish();
rollback;
