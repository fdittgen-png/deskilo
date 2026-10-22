-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0522 (#2365, DATEV 3b) -- the DATEV export books a reduced-rate position to
-- its automatic revenue account, SKR03 8300 "Erlöse 7 % USt", instead of the
-- 19 % account 8400: one new `account_map` row of the tax reference store
-- (`datev/revenue:reduced`, DE), UNCONFIRMED until a tax adviser has checked
-- the account of the plan in use.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'DE', 'datev/revenue:reduced', '1900-01-01', '{"format":"datev","role":"revenue:reduced","account":"8300","label":"Erlöse 7 % USt"}'::jsonb, 'DATEV SKR03 8300 Erlöse 7 % USt, an automatic account: DATEV derives the reduced tax from it, so a 7 % position is never booked with the 19 % gross to 8400 (the DATEV export, #2365). Not yet confirmed by a tax adviser', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(522);
