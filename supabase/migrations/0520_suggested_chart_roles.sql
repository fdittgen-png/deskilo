-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0520 (#2365) -- the suggested chart covers every role the posting engine
-- books: suppliers, deductible input tax, the written-off rest of a
-- receivable, and the per-rate tax and revenue accounts of the French and
-- German charts (`vat_output:reduced`, `revenue:reduced`, ...). New
-- `account_map` rows of the tax reference store, UNCONFIRMED until an
-- accountant has checked them; taking the suggested chart maps each to its
-- role (`book_chart.dart`).

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', '*', 'coa/06-suppliers', '1900-01-01', '{"format":"coa","role":"suppliers","account":"2000","label":"Accounts payable"}'::jsonb, 'a generic chart numbering (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', '*', 'coa/07-vat_input', '1900-01-01', '{"format":"coa","role":"vat_input","account":"1300","label":"Input tax recoverable"}'::jsonb, 'a generic chart numbering (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', '*', 'coa/08-write_off', '1900-01-01', '{"format":"coa","role":"write_off","account":"6900","label":"Bad debts"}'::jsonb, 'a generic chart numbering (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'DE', 'coa/06-suppliers', '1900-01-01', '{"format":"coa","role":"suppliers","account":"70000","label":"Kreditoren"}'::jsonb, 'DATEV SKR03 creditor range (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'DE', 'coa/07-vat_input', '1900-01-01', '{"format":"coa","role":"vat_input","account":"1576","label":"Abziehbare Vorsteuer 19 %"}'::jsonb, 'DATEV SKR03 1576 (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'DE', 'coa/08-write_off', '1900-01-01', '{"format":"coa","role":"write_off","account":"2400","label":"Forderungsverluste"}'::jsonb, 'DATEV SKR03 2400, as the DATEV export books it (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'DE', 'coa/09-revenue_reduced', '1900-01-01', '{"format":"coa","role":"revenue:reduced","account":"8300","label":"Erlöse 7 % USt"}'::jsonb, 'DATEV SKR03 8300 (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'DE', 'coa/10-vat_reduced', '1900-01-01', '{"format":"coa","role":"vat_output:reduced","account":"1771","label":"Umsatzsteuer 7 %"}'::jsonb, 'DATEV SKR03 1771 (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'DE', 'coa/11-vat_input_reduced', '1900-01-01', '{"format":"coa","role":"vat_input:reduced","account":"1571","label":"Abziehbare Vorsteuer 7 %"}'::jsonb, 'DATEV SKR03 1571 (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'FR', 'coa/06-suppliers', '1900-01-01', '{"format":"coa","role":"suppliers","account":"401000","label":"Fournisseurs"}'::jsonb, 'PCG 401 Fournisseurs (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'FR', 'coa/07-vat_input', '1900-01-01', '{"format":"coa","role":"vat_input","account":"445660","label":"TVA déductible sur autres biens et services"}'::jsonb, 'PCG 44566 (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'FR', 'coa/08-write_off', '1900-01-01', '{"format":"coa","role":"write_off","account":"654000","label":"Pertes sur créances irrécouvrables"}'::jsonb, 'PCG 654, as the FEC export books it (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'FR', 'coa/09-vat_intermediate', '1900-01-01', '{"format":"coa","role":"vat_output:intermediate","account":"445712","label":"TVA collectée 10 %"}'::jsonb, 'PCG 44571 subdivided per rate (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false),
('account_map', 'FR', 'coa/10-vat_reduced', '1900-01-01', '{"format":"coa","role":"vat_output:reduced","account":"445713","label":"TVA collectée 5,5 %"}'::jsonb, 'PCG 44571 subdivided per rate (#2365: the suggested chart covers every role the posting engine books); not yet confirmed by an accountant', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(520);
