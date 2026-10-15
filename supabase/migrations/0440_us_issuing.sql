-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0440 (#2362) -- DesKilo issues for a seller in the United States.
--
-- The gate (`seller_country_unsupported`) opens for the United States now that
-- the pieces are in (0434, 0435, 0439): net prices with the tax of the site's postal
-- code added per jurisdiction, taxability per kind and state, the customer's
-- exemption certificate, and the summary of a period. The gate is a ROW
-- (ADR 0041): `issuing_gate` / US says `supported` and `tax_system` =
-- `sales_tax`, which is all it takes -- `create_invoice` and
-- `invoice_essentials_missing` read the row. The United States has no VAT: no
-- VAT regime, no VAT number, no EN 16931, no reverse charge, no national
-- channel. Tax in a currency other than the dollar is refused
-- (`vat_national_currency`): the state returns are in dollars and the app
-- converts nothing.
--
-- What the row does NOT do: ship a rate. An invoice for a seller whose site
-- has no `sales_tax` row for its ZIP code, or whose line kind has no
-- `taxability` row in the state, is refused by name until the platform
-- administrator enters them (sales-tax rates change by jurisdiction
-- constantly). Issued documents are untouched.

-- The seed.
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('issuing_gate', 'US', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"USD","tax_system":"sales_tax"}'::jsonb, '#2362: the United States has no VAT; a seller issues in sales-tax mode (net prices, the tax of the site''s ZIP code from sales_tax rows, taxability per state from taxability rows, exemption certificates) and files with each state''s portal; the app files nothing', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(440);
