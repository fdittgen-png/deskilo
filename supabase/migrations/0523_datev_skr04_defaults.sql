-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0523 (#2365, DATEV 3b) -- the SKR04 plan: when the DATEV export names the
-- chart SKR04, its defaults are the plan's own accounts (Erlöse 4400 / 4300,
-- Bank 1800, Umsatzsteuer 3806, sonstige Aufwendungen 6300,
-- Forderungsverluste 6936), never the SKR03 numbers under an SKR04 header.
-- New `account_map` rows of the tax reference store (`datev/<role>@SKR04`,
-- DE), UNCONFIRMED until a tax adviser has checked them.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'DE', 'datev/bank@SKR04', '1900-01-01', '{"format":"datev","role":"bank@SKR04","account":"1800","label":"Bank"}'::jsonb, 'DATEV SKR04 1800 Bank: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/customers@SKR04', '1900-01-01', '{"format":"datev","role":"customers@SKR04","account":"10000","label":"Debitoren"}'::jsonb, 'DATEV SKR04 10000 Debitoren: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/expenses@SKR04', '1900-01-01', '{"format":"datev","role":"expenses@SKR04","account":"6300","label":"Sonstige betriebliche Aufwendungen"}'::jsonb, 'DATEV SKR04 6300 Sonstige betriebliche Aufwendungen: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/revenue:reduced@SKR04', '1900-01-01', '{"format":"datev","role":"revenue:reduced@SKR04","account":"4300","label":"Erlöse 7 % USt"}'::jsonb, 'DATEV SKR04 4300 Erlöse 7 % USt: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/revenue@SKR04', '1900-01-01', '{"format":"datev","role":"revenue@SKR04","account":"4400","label":"Erlöse 19 % USt"}'::jsonb, 'DATEV SKR04 4400 Erlöse 19 % USt: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/vat@SKR04', '1900-01-01', '{"format":"datev","role":"vat@SKR04","account":"3806","label":"Umsatzsteuer 19 %"}'::jsonb, 'DATEV SKR04 3806 Umsatzsteuer 19 %: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false),
('account_map', 'DE', 'datev/write_off@SKR04', '1900-01-01', '{"format":"datev","role":"write_off@SKR04","account":"6936","label":"Forderungsverluste"}'::jsonb, 'DATEV SKR04 6936 Forderungsverluste: the DATEV export''s default when the chart named is SKR04 (#2365). Not yet confirmed by a tax adviser', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(523);
