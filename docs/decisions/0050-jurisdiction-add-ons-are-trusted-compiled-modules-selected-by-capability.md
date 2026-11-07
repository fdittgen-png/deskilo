# ADR 0050 — Jurisdiction add-ons are trusted compiled modules selected by capability

**Status:** accepted · **Date:** 2026-11-07 · **Refs:** #3328, #3331, #3332, #3333, ADR 0043, ADR 0049

## Context
Country-specific VAT filing code was spread through `lib/features/money` as
switches on a country code. A regulatory change in one country touched shared
money code, and no country could be retired cleanly (#3328). The epic extracts
each country behind a small contract and keeps the core responsible for
permissions, financial records, document history and delivery state.

## Decision
1. **Trusted, compiled, static.** An add-on is a Dart package under
   `packages/deskilo_jurisdiction_<cc>/`, compiled into the build and listed in
   `installedVatFilings`. No plugin is downloaded at run time; the list is the
   composition, and it is reviewed like code.
2. **Selected by capability.** The host asks `resolveCapability(operation,
   legalContext, installed)` for the add-on providing `vat_filing.<CC>` for the
   workspace's country (ADR 0043). An unknown, missing or conflicting
   jurisdiction, or an add-on written against another contract version, is an
   explicit refusal (`RefusalKind`) — never a fallback country. The resolver
   carries no text; the screen words the refusal.
3. **One contract, contract types only.** `deskilo_jurisdiction_api` exports the
   descriptor, the immutable `FilingContext`, the `VatFilingContribution`
   (`validate` to stable issue codes, `build` to a `GeneratedArtifact` with
   bytes, media type, file name, SHA-256 and provenance). Helpers shared by
   several add-ons and the application live in `deskilo_jurisdiction_standards`.
   A lint pins both surfaces and the dependency rules: an add-on depends on the
   contract and the standards package (and `xml` where it writes XML), nothing
   else, and reads no clock, network or repository.
4. **Four version dimensions, each data.** The *contract version* (breaking
   changes to the contract types, ADR 0049), the *implementation version* (what
   the add-on writes: bumped in the same commit as the parity goldens), the
   *format version* (the authority's schema or layout year) and the *rule
   revision* (the tax-reference snapshot the host fills the boxes from; it is an
   input of the context, not of the package). The first three travel with every
   artifact as provenance. Recording the rule revision in the artifact is not
   done yet.
5. **No behaviour change during extraction.** The bytes, file names, encodings,
   refusals and their order are pinned by golden files outside the code that
   moved (`test/parity/`): a one-character change to any writer fails the suite,
   and an extraction ships with no golden diff.
6. **The host keeps what is not the add-on's.** Source loading, authorization,
   dialogs, file saving, tracing and export logging stay in the application. The
   add-on validates and writes.

## Demonstrated
Seven add-ons (DE, FR, GB, CH, CA, ES, IT) run through the resolver and the
contract; the central country switch is deleted. A country that exists only in a
test is registered in a test composition and saved through the host's own seam
without an edit to the money feature; the production composition refuses it.

## Consequences
A sixth country's file needs a package, a registration in the composition,
reference data (`form_box` rows) and evidence. What a screen still names per
country is presentation, not a decision about the file: the label of the button
and the dialog that asks the facts a country's file needs (a Steuernummer, a
declarant, the Spanish facts). A descriptor-carried label and fact list would
remove that last edit; it is left for when a second country needs it.
