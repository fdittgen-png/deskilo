-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0488 (#2365, defect 7a) -- the DATEV export books what an owner gave up of an
-- invoice on SKR03 2400 "Forderungsverluste": one new `account_map` row of the
-- tax reference store (`datev/write_off`, DE), UNCONFIRMED until a tax adviser
-- has checked the account of the plan in use.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'DE', 'datev/write_off', '1900-01-01', '{"format":"datev","role":"write_off","account":"2400","label":"Forderungsverluste"}'::jsonb, 'DATEV SKR03 2400 Forderungsverluste (übliche Umsatzsteuersätze): a receivable the business gives up is booked to the loss account at its gross amount; the VAT correction (§17 UStG) is left to the tax adviser (the DATEV export, #2365). Account number from the SKR03 plan, not yet confirmed by a tax adviser', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(488);
