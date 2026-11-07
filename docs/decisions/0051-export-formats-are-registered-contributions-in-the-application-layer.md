# ADR 0051 — Export formats are registered contributions in the application layer

**Status:** accepted · **Date:** 2026-11-07 · **Refs:** #3328, #3334, #3376, ADR 0050

## Context
The accounting export dispatched per format in the presentation layer (23
`case`s in `AccountingExportRun`) and chose its sources from five hard-coded
format-id sets in `AccountingExportSource`. #3334 asked for the formats to be
registered contributions that declare their sources, in the jurisdiction API
package, with `AccountingSourceSnapshot` as input.

## Decision
1. **In the application layer, not in the API package.** `AccountingSourceSnapshot`
   imports `Invoice`, `LedgerEntry`, `BookProfile`, `ExpenseRepartition`,
   `VatTaxPoint` and the data readers: it is the money domain. A contribution
   taking it as input cannot live in a package that depends on nothing of the
   application, and packaging the money domain is a separate piece of work.
   Only the posted formats consume `AccountingInterchangeV1` (which imports
   `fiscal_year` and `posting`); packaging those is #3376.
2. **One registry, declared sources.** `AccountingExportContribution` is a
   stable format id (unchanged) and its `SourceRequirements` (where the postings
   come from, whether they name accounts and parties, whether opening balances
   are read, whether the format is the year archive). `installedAccountingExports`
   replaces the five id sets; the host reads one snapshot for the requirements of
   the format it was asked for.
3. **The registry is pinned to the targets registry.** A test requires the
   registered ids to be exactly the file formats of `accountingTargets`, so a
   format added in one place without the other fails the build. What each format
   reads stays pinned by the parity goldens of `test/parity/golden/exports`.
4. **No behaviour change.** Format ids, defaults, availability, RPC names and
   the bytes of every export are unchanged; the goldens are the proof.

## Consequences
The dispatch in `AccountingExportRun` and the generated registries follow in the
next steps of #3334 (dispatch through the registry, with a lint that counts the
format-id branches of the presentation layer at zero; one list for the SQL and
TS registries, with a drift test). The package placement the issue first wanted
waits for the money domain to be packaged (#3376).
