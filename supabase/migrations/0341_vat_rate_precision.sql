-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0341 (#1870) -- a tax rate is stored exactly.
--
-- vat_rates.percent and ledger_entries.vat_percent were numeric(5,2):
-- two decimals. Quebec's QST is 9.975 % and the combined GST+QST rate
-- 14.975 %; numeric(5,2) stored them as 9.98 and 14.98, and a rate
-- written that way is a different rate (CAD 1000.00 gives 99.80 of QST,
-- not 99.75). Both columns become numeric(9,6): six decimals, values
-- below 1000, enough for every published rate and its future versions.
-- Widening keeps every stored value unchanged; nothing is recomputed,
-- no issued invoice or ledger row is touched beyond its storage type,
-- and the existing 0 <= percent < 100 checks stay.

alter table public.vat_rates
  alter column percent type numeric(9,6);
alter table public.ledger_entries
  alter column vat_percent type numeric(9,6);

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(341);
