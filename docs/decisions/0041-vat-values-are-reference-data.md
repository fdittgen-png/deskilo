# ADR 0041 — VAT values are reference data

**Status:** accepted · **Date:** 2026-10-13 · **Refs:** #2476, #2477, #2478, #2479, #2480, #2481

## Context
Rates, thresholds, tax points, exemption texts, VAT id patterns, the EU
member set, issuing gates, the e-invoicing mandate calendar, the rated boxes
of the return forms and the accounts and tax codes of the exports were
written in Dart and, for the rules the server decides, again in SQL. A change
of law was a release, and the two copies drifted (#2476 measured nine kinds).

## Decision
1. **A tax value is a `tax_reference` row**: `domain`, `country` (or `*`),
   `key`, `valid_from`/`valid_to`, a `value` whose shape is checked in SQL by
   `tax_reference_valid`, its `source` and a `confirmed` flag. Platform-wide,
   read by every member, written by the platform administrator through RPCs
   that version (a change closes the old row, never edits it). Ten domains:
   `rate`, `eu_member`, `exemption_text`, `vat_id_pattern`, `threshold`,
   `tax_point`, `mandate`, `issuing_gate`, `form_box`, `account_map`.
2. **Delivery:** the RPC for the app, the bundled copy
   (`assets/instance/tax_reference.json`) for self-hosted and F-Droid builds,
   the table itself for SQL. SQL is the single source of the rules the server
   decides; Dart reads the same rows. No Dart/SQL twin remains for these.
3. **Snapshots, not lookups.** A domain function takes a `TaxReferenceSet`
   (the installed one by default, the one passed in for a document or a test);
   it never reads a clock or the store itself. An unavailable installation is a
   typed failure, never another installation's value or a blank.
4. **History is frozen.** A row version applies from its date. A period reads
   the version in force at its end (a form box: the latest on or before it, the
   earliest for an older period); an issued document keeps the values it was
   issued with. Each consumer has a test: change the data, regenerate nothing,
   compare.
5. **What stays in code:** arithmetic and rounding, the fixed codes of a
   standard (EN 16931 / UNCL5305), the structure of a document, and the
   *structure* of a form: which boxes exist and how they total. A rated box
   selects by category and fiscal group, never by a percent.
6. **Export defaults** are `account_map` rows: the country's suggested chart
   (`coa/NN-<role>`, its `coa/00-chart` header), what a format asks beyond the
   chart (`fec/vat_pending`) and the Sage nominal accounts and VAT codes. The
   FEC and DATEV defaults ARE the French and German charts, so the preview and
   the export cannot disagree. The workspace's own chart stays its
   `book_profile`; an account given at export time wins over any row.
7. **The ratchet is an allow-list.** `test/lint/tax_literals_test.dart` fails
   on any percent, country-keyed branch, country-keyed map entry or country
   list in the VAT files that is not listed, with its reason, in
   `test/lint/tax_literals_allowed.txt`, and on an entry that no longer matches
   the code. Seed migrations and tests are outside it.

## Confirming and withdrawing (#2565)
Confirming is the one update a version ever receives: it sets `confirmed` and may
complete the source, it changes no value. A planned version (in the future,
unconfirmed) can be withdrawn when the change does not come into force: it is
deleted, its predecessor is open again, and the act is audited with the full
row. A version in force or confirmed is history and is only superseded.

## Consequences
- A change of law is a data change by the platform administrator; the next
  invoice, return or export uses it.
- A new country is a data task plus the little code that is not a value.
- The allow-list is the honest remainder: standards' codes, UI wording and
  capabilities (which national channel or filing file the app can write). Two
  tax values are on it with their issue (#2539).
- A PR that adds a tax literal fails the lint; it adds a row, not a constant.
