# ADR 0051 — Export formats are declared where they are defined

**Status:** accepted · **Date:** 2026-11-07 · **Refs:** #3328, #3334, #3376, ADR 0050

## Context
The accounting export dispatched per format in the presentation layer (23
`case`s in `AccountingExportRun`) and chose its sources from five hard-coded
format-id sets in `AccountingExportSource`. #3334 asked for the formats to be
registered contributions that declare their sources, in the jurisdiction API
package, with `AccountingSourceSnapshot` as input.

## Decision
1. **In the money domain, not in the API package.** `AccountingSourceSnapshot`
   imports `Invoice`, `LedgerEntry`, `BookProfile`, `ExpenseRepartition`,
   `VatTaxPoint` and the data readers: it is the money domain. A contribution
   taking it as input cannot live in a package that depends on nothing of the
   application, and packaging the money domain is a separate piece of work.
   Only the posted formats consume `AccountingInterchangeV1` (which imports
   `fiscal_year` and `posting`); packaging those is #3376.
2. **One list, declared where the format is defined.** The formats are the file
   formats of `accountingTargets`. A format declares, next to its id, claim and
   extension, the writer family the export run dispatches on (`ExportKind`,
   switched exhaustively: the run names no format id) and the sources it reads
   (`SourceRequirements`: where the postings come from, whether they name
   accounts and parties, whether opening balances are read, whether it is the
   year archive). `exportFormats` and `sourcesOf` read that list; the five id
   sets of `AccountingExportSource` and the first, separate registry (PR A) are
   gone, so a format id is typed in exactly one place.
3. **Nothing to generate.** No SQL or TS file holds a list of export format ids:
   `book_exports.format_id` is free text with a length check; the SQL `format`
   values of the account maps (`coa`, `fec`, `datev`, `sage`, `saf_t`, `ch_kmu`)
   are chart-of-account formats, a different namespace; the Edge functions name
   no export format. A generator for a list that does not exist would be a
   second list. If the server ever validates export format ids, it generates
   from `exportFormats` the way `accounting_target_registry_sql` does for targets.
4. **No behaviour change.** Format ids, defaults, availability, RPC names and
   the bytes of every export are unchanged; the goldens are the proof.

## Consequences
A new format is its definition (id, claim, extension, family, sources) and a
target that offers it; the run needs an edit only for a NEW writer family, and
the compiler asks for it. The package placement the issue first wanted waits
for the money domain to be packaged (#3376). What each format reads stays pinned
by the parity goldens of `test/parity/golden/exports`.
