-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2379 / 0597: the standard codes a SAF-T Financial file states. Norway's
-- `saf_t/<role>` rows carry a GroupingCode and its GroupingCategory, its
-- `saf_t/tax:<output|input>:<group>` rows a StandardTaxCode for every rate
-- group in force, Luxembourg's `saf_t/<role>` rows a StandardAccountID. The
-- rows resolve through the store's reader on any day, pass the account_map
-- shape check and stay unconfirmed. Rolled back.
begin;
select plan(7);

-- The reader answers a signed-in caller only; no row is written here.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000002379","role":"authenticated"}', true);

select is((select value ->> 'account' || '/' || (value ->> 'label')
             from public.tax_reference('account_map', 'NO', '2026-06-01')
            where key = 'saf_t/customers'), '1500/balanseverdiForOmloepsmiddel',
          'a Norwegian customers account groups under 1500');
select is((select value ->> 'tax_code' from public.tax_reference('account_map', 'NO', '2026-06-01')
            where key = 'saf_t/tax:output:standard'), '3',
          'the Norwegian standard rate''s output code is 3');
select is((select count(*)::int
             from public.tax_reference('rate', 'NO', '2026-06-01') r, (values ('output'), ('input')) d(dir)
            where not exists (select 1 from public.tax_reference('account_map', 'NO', '2026-06-01') m
                               where m.key = 'saf_t/tax:' || d.dir || ':' || (r.value ->> 'group'))), 0,
          'every Norwegian rate in force has its output and input code');
select is((select value ->> 'account' from public.tax_reference('account_map', 'LU', '2026-06-01')
            where key = 'saf_t/revenue'), '703',
          'Luxembourg''s revenue is the PCN''s 703');
select ok((select bool_and(public.tax_reference_valid('account_map', value)
                           and value ->> 'format' = 'saf_t'
                           and value ->> 'role' = substr(key, 7))
             from public.tax_reference
            where domain = 'account_map' and key like 'saf\_t/%'),
          'every row is a valid saf_t row whose role is its key');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and key like 'saf\_t/%' and country not in ('NO', 'LU', 'RO')), 0,
          'only Norway, Luxembourg and Romania (0626) carry SAF-T standard codes');
select is((select count(*)::int from public.tax_reference
            where domain = 'account_map' and key like 'saf\_t/%' and confirmed), 0,
          'the codes stay unconfirmed until an accountant has checked them');

select * from finish();
rollback;
