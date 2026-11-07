# ADR 0049 — The filing context carries the filled form boxes

**Status:** accepted · **Date:** 2026-11-07 · **Refs:** #3328, #3331, #3332, #3333

## Context
A jurisdiction add-on writes a return as a file. The boxes of that return are
data the application fills from its installed tax reference (`vatFormBoxes`: the
`form_box` rows, the fiscal groups of each rate, the rounding of each form). An
add-on in its own package may not import the application, so it cannot call
`vatFormBoxes`, and it must not read a global tax reference: a file would then
depend on whatever snapshot was installed when it was written, not on its input.
The French extraction (#3332) hit this first; the Canadian one (#3333) needs a
second form beside the first (the Quebec FPZ-500 beside the federal GST34).

## Decision
1. **The host fills, the add-on writes.** `FilingContext.boxes` carries the
   filled boxes of the country's return (`FilingBox`: code, label, base and tax
   in cents, which of the two exist, and the cell keys of the filing file).
   `FilingContext.extraBoxes` carries the boxes of a second form filed beside
   the first, by the form's name. The host fills both in `filingContextOf`, from
   the installed tax reference or from an explicit snapshot.
2. **The contract version moves to 2.** The change is additive, but an add-on
   written against version 1 cannot read what it now needs; `contractVersion` is
   declared by every add-on and the resolver refuses a mismatch
   (`RefusalKind.contractMismatch`). A lint pins every installed add-on to the
   current version.
3. **The add-on reads its input only.** Given the same context it writes the same
   bytes, whatever tax reference is installed; the A/B/A test (two snapshots, the
   first installed again) pins it. The arithmetic of the boxes (rounding, totals,
   groups) stays where the tax reference lives, in the application.
4. **Lists and maps in the context are read-only**, and a `ValidatedFiling` is
   not trusted: `build` validates again and refuses a filing its own `validate`
   would not issue.
5. **The contract exports contract types only.** Helpers more than one add-on
   uses (a CSV cell, the reading of a period, date spellings, registration
   numbers) live in `deskilo_jurisdiction_standards`, a neutral package with no
   dependency; the application uses it too. A change to a CSV cell is never a
   change to the contract. A lint pins the contract's exports.

## Consequences
A country whose return needs another form adds a named entry to `extraBoxes`
and a host fill; no add-on reaches for data it was not given. The cost is one
projection of the boxes per filing, and a context larger than the declaration it
came from. The GB add-on exports the nine MTD box helpers and the application's
`mtd_boxes.dart` delegates to them, so the file and the MTD submission read one
copy.
