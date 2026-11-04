-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0690 (#2379) -- the accounts Austria's SAF-T AT 1.01 states, as
-- `account_map` rows of the tax reference store, UNCONFIRMED until an
-- accountant has checked them:
--   * `saf_t/<role>` of AT: the account of the österreichischer
--     Einheitskontenrahmen (`account`, AccountID_oeEKR) and its name
--     (`label`, AccountDescription_oeEKR), as the BMF lists them in its
--     Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, pinned under
--     test/fixtures/saft/saft_at/), for the accounts a posting role books to.
--   * Revenue by rate group (`revenue:standard` 4000 Erlöse 20 %,
--     `revenue:reduced` 4010 Erlöse 10 %): the BMF's list keeps revenue per
--     rate. It has no account for the 13 % rate, the cash discount or the
--     write-off of a receivable at an unknown rate, so those roles carry no
--     row: a file that books them is refused with them named, never a guess.
-- No function, invoice or filed period is touched.

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'AT', 'saf_t/bank', '1900-01-01', '{"format":"saf_t","role":"bank","account":"2800","label":"Guthaben bei Kreditinstituten (Bankguthaben)"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (2800 Guthaben bei Kreditinstituten (Bankguthaben))', false),
('account_map', 'AT', 'saf_t/clearing', '1900-01-01', '{"format":"saf_t","role":"clearing","account":"2885","label":"Schwebende Geldbewegungen"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (2885 Schwebende Geldbewegungen)', false),
('account_map', 'AT', 'saf_t/customers', '1900-01-01', '{"format":"saf_t","role":"customers","account":"2000","label":"Forderungen aus Lieferungen und Leistungen Inland"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (2000 Forderungen aus Lieferungen und Leistungen Inland)', false),
('account_map', 'AT', 'saf_t/deposits', '1900-01-01', '{"format":"saf_t","role":"deposits","account":"2584","label":"Kautionen"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (2584 Kautionen)', false),
('account_map', 'AT', 'saf_t/expenses', '1900-01-01', '{"format":"saf_t","role":"expenses","account":"5700","label":"Fremdleistungen"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (5700 Fremdleistungen)', false),
('account_map', 'AT', 'saf_t/fees', '1900-01-01', '{"format":"saf_t","role":"fees","account":"7790","label":"Spesen des Geldverkehrs"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (7790 Spesen des Geldverkehrs)', false),
('account_map', 'AT', 'saf_t/fixed_assets', '1900-01-01', '{"format":"saf_t","role":"fixed_assets","account":"660","label":"Andere Betriebs- und Geschäftsausstattung"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (660 Andere Betriebs- und Geschäftsausstattung)', false),
('account_map', 'AT', 'saf_t/prepayments', '1900-01-01', '{"format":"saf_t","role":"prepayments","account":"2900","label":"Aktive Rechnungsabgrenzungsposten"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (2900 Aktive Rechnungsabgrenzungsposten)', false),
('account_map', 'AT', 'saf_t/revenue:reduced', '1900-01-01', '{"format":"saf_t","role":"revenue:reduced","account":"4010","label":"Erlöse 10 %"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (4010 Erlöse 10 %)', false),
('account_map', 'AT', 'saf_t/revenue:standard', '1900-01-01', '{"format":"saf_t","role":"revenue:standard","account":"4000","label":"Erlöse 20 %"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (4000 Erlöse 20 %)', false),
('account_map', 'AT', 'saf_t/stock', '1900-01-01', '{"format":"saf_t","role":"stock","account":"1600","label":"Waren"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (1600 Waren)', false),
('account_map', 'AT', 'saf_t/suppliers', '1900-01-01', '{"format":"saf_t","role":"suppliers","account":"3300","label":"Lieferverbindlichkeiten Inland"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (3300 Lieferverbindlichkeiten Inland)', false),
('account_map', 'AT', 'saf_t/vat_input', '1900-01-01', '{"format":"saf_t","role":"vat_input","account":"2500","label":"Vorsteuer, Forderungen aus der Abgabenverrechnung"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (2500 Vorsteuer, Forderungen aus der Abgabenverrechnung)', false),
('account_map', 'AT', 'saf_t/vat_output', '1900-01-01', '{"format":"saf_t","role":"vat_output","account":"3500","label":"Umsatzsteuer, Verbindlichkeiten aus Steuern"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (3500 Umsatzsteuer, Verbindlichkeiten aus Steuern)', false),
('account_map', 'AT', 'saf_t/vat_pending', '1900-01-01', '{"format":"saf_t","role":"vat_pending","account":"3510","label":"Noch nicht geschuldete USt"}'::jsonb, 'BMF Kontenrahmen für SAF-T (EKR_fuer_SAF-T.csv, bmf.gv.at Standard Audit File-Tax, downloaded 2026-11-04): the account of the österreichischer Einheitskontenrahmen a SAF-T AT file states (AccountID_oeEKR) for the accounts of this role (3510 Noch nicht geschuldete USt)', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(690);
