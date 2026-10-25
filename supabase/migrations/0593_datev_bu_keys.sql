-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0593 (#2375, DATEV) -- a sale booked to a revenue account that is not one
-- of DATEV's automatic accounts carries the BU-Schlüssel of its rate, so
-- DATEV computes the tax: two new `account_map` rows of the tax reference
-- store, `datev/tax:standard` (BU-Schlüssel 3, Umsatzsteuer 19 %) and
-- `datev/tax:reduced` (BU-Schlüssel 2, Umsatzsteuer 7 %), DE. The key does
-- not depend on the chart, so SKR04 reads the same rows. UNCONFIRMED until a
-- tax adviser has checked them. Without them the export refuses such an
-- account and names the rate.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'DE', 'datev/tax:reduced', '1900-01-01', '{"format":"datev","role":"tax:reduced","tax_code":"2","label":"Umsatzsteuer 7 %"}'::jsonb, 'DATEV BU-Schlüssel 2 (Umsatzsteuer 7 %): a 7 % sale booked to a revenue account that is not automatic carries this key, so DATEV computes the reduced tax; the key is the same in SKR03 and SKR04 (the DATEV export, #2375). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/tax:standard', '1900-01-01', '{"format":"datev","role":"tax:standard","tax_code":"3","label":"Umsatzsteuer 19 %"}'::jsonb, 'DATEV BU-Schlüssel 3 (Umsatzsteuer 19 %): a 19 % sale booked to a revenue account that is not automatic carries this key, so DATEV computes the standard tax; the key is the same in SKR03 and SKR04 (the DATEV export, #2375). Not yet confirmed by a tax adviser', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(593);
