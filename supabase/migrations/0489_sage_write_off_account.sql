-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0489 (#2365, defect 7a) -- the Sage 50 export clears what an owner gave up of
-- an invoice with a sales credit to Sage's own "Bad Debt Write Off" nominal
-- (8100): one new `account_map` row of the tax reference store
-- (`sage/write_off`, GB), UNCONFIRMED until an accountant has checked the
-- nominal of the chart in use.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'GB', 'sage/write_off', '1900-01-01', '{"format":"sage","role":"write_off","account":"8100","label":"Bad Debt Write Off"}'::jsonb, 'Sage 50 shipped chart of accounts, nominal 8100 Bad Debt Write Off: a sales credit against the customer posted to it clears the debtor at the gross amount (T9); VAT bad debt relief is claimed separately by the accountant (the Sage export, #2365). Account number from Sage''s standard chart, not yet confirmed by an accountant', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(489);
