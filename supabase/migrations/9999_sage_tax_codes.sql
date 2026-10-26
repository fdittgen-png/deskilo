-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two rows of the tax reference store; no function, table or policy)
--
-- 9999 (#2373, Sage 50 UK) -- two `account_map` rows of the tax reference
-- store, GB, UNCONFIRMED until an accountant has checked them: the Sage 50
-- VAT codes of the reverse charge, beside the five rate codes of 0433.
--
--   * `sage/tax_eu_services` T22: a service to a VAT-registered business in
--     another EU member state (EN 16931 category AE, the customer abroad);
--   * `sage/tax_reverse_charge` T20: the domestic reverse charge (category
--     AE, the customer at home).
--
-- A company's own VAT code table may number them otherwise: the rows are
-- edited on the tax reference screen, never in the file. Goods to another
-- member state (T4) get no row: the app sells none.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'GB', 'sage/tax_eu_services', '1900-01-01', '{"format":"sage","role":"tax_eu_services","tax_code":"T22","label":"Sales of services to VAT-registered customers in the EU"}'::jsonb, 'Sage 50 Accounts UK default VAT code table: T22 sales of services to VAT-registered customers in the EU; the Sage export writes it on a sales row of an untaxed line of EN 16931 category AE whose customer is in another EU member state (#2373). A company''s own VAT code table may number it otherwise. Not yet confirmed by an accountant', false),
('account_map', 'GB', 'sage/tax_reverse_charge', '1900-01-01', '{"format":"sage","role":"tax_reverse_charge","tax_code":"T20","label":"Domestic reverse charge"}'::jsonb, 'Sage 50 Accounts UK default VAT code table: T20 domestic reverse charge; the Sage export writes it on a sales row of an untaxed line of EN 16931 category AE whose customer is in the seller''s country (#2373). A company''s own VAT code table may number it otherwise. Not yet confirmed by an accountant', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(9999);
