-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2481 (C5 of #2476, 0433): the `account_map` domain. The charts, the FEC
-- row and the Sage rows are seeded with the values the exporters used to
-- carry; the shape check refuses a row that names neither an account nor a
-- tax code, an unknown format, a blank role and a key the shape does not know.
-- Rolled back.
begin;
select plan(9);

select is((select count(*)::int from public.tax_reference where domain = 'account_map'), 79,
          'eleven charts, the FEC rows and the Sage rows are seeded');
select is((select value ->> 'account' from public.tax_reference
            where domain = 'account_map' and country = 'FR' and key = 'coa/04-vat'), '445710',
          'the French chart books the collected VAT on 445710');
select is((select value ->> 'account' from public.tax_reference
            where domain = 'account_map' and country = 'FR' and key = 'fec/vat_pending'), '445740',
          'the FEC pending VAT account');
select is((select value ->> 'account' from public.tax_reference
            where domain = 'account_map' and country = 'DE' and key = 'coa/00-chart'), 'SKR03',
          'the German chart header names SKR03');
select is((select string_agg(value ->> 'tax_code', ',' order by key) from public.tax_reference
            where domain = 'account_map' and country = 'GB' and key like 'sage/tax\_%'),
          'T2,T9,T5,T1,T0', 'the Sage VAT codes');
select ok(public.tax_reference_valid('account_map', '{"format":"coa","role":"bank","account":"512000","label":"Banques"}'::jsonb)
          and public.tax_reference_valid('account_map', '{"format":"sage","role":"tax_zero","tax_code":"T0"}'::jsonb),
          'an account row and a tax code row are valid');
select ok(not public.tax_reference_valid('account_map', '{"format":"sage","role":"tax_zero"}'::jsonb)
          and not public.tax_reference_valid('account_map', '{"format":"sage","role":"x","account":""}'::jsonb),
          'a row with neither an account nor a tax code is refused');
select ok(not public.tax_reference_valid('account_map', '{"format":"ledger","role":"bank","account":"1"}'::jsonb)
          and not public.tax_reference_valid('account_map', '{"format":"coa","role":" ","account":"1"}'::jsonb)
          and not public.tax_reference_valid('account_map', '{"format":"coa","role":"bank","account":"1","percent":19}'::jsonb),
          'an unknown format, a blank role and an unknown key are refused');
select throws_ok($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('account_map', 'FR', 'fec/x', '2030-01-01', '{"format":"fec","role":"x"}', 'test', false)$$,
  '23514', null, 'the table refuses an account_map row of a wrong shape');

select * from finish();
rollback;
