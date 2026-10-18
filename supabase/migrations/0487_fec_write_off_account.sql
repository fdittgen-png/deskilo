-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0487 (#2365, defect 7a) -- the FEC books what an owner gave up of an invoice
-- on the French account 654 "Pertes sur créances irrécouvrables": one new
-- `account_map` row of the tax reference store (`fec/write_off`), read by the
-- FEC builder like the other accounts of its row set.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'FR', 'fec/write_off', '1900-01-01', '{"format":"fec","role":"write_off","account":"654000","label":"Pertes sur créances irrécouvrables"}'::jsonb, 'Plan comptable général 654: a receivable the business gives up as irrecoverable is a loss, booked at the gross amount it was owed; the VAT regularisation, if the conditions of art. 272 CGI are met, is left to the accountant (the FEC export, #2365)', true)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(487);
