# ADR 0015 — VAT: what the review found, what changed, what is filed

**Status:** accepted · **Date:** 2026-09-05

## Context

The owner asked for a review of the VAT implementation against the EU
rules (Council Directive 2006/112/EC, EN 16931), fixes for the gaps, and
a VAT report of every position for a month or a chosen period (#878).
The review covered the regime gate (`not_subject | exempt |
vat_registered` → categories O / E / S), the VAT-inclusive split and the
per-rate breakdown frozen at issue (0072), the rate catalogue, the
periodic declarations (0107), the e-invoice exports (CII / UBL, FEC,
SAF-T) and their readiness rules, chronology and immutability.

## Findings

1. **Category at issue is right; the pilot's O-vs-E is history, not a
   bug.** The seller party is frozen with its regime at issue
   (`parties.seller.vat_regime`); the exports read the frozen party. An
   association that switched from *not subject* to *exempt* keeps its
   earlier invoices in category O — as it must: a document states the
   regime of its day. Changing the regime affects future invoices only.
2. **BR-E-10 was enforceable but the mention was the owner's alone.** An
   exempt seller needs a VATEX code or an exemption text; only France
   had a code (`VATEX-FR-FRANCHISE`), every other country depended on
   free text nobody defaulted. **Changed:** `defaultExemptionMention`
   supplies the member state's statutory wording (FR art. 293 B CGI,
   DE § 19 UStG, AT § 6 Abs. 1 Z 27, ES franquicia, IT L. 190/2014,
   BE art. 56bis, NL KOR, LU art. 57, a Directive fallback; and the
   out-of-scope wording for category O) whenever the owner wrote none.
3. **Buyer VAT ids were stored, never checked.** A typo reaches the
   platform, which bounces the e-invoice. **Changed:** `looksLikeEuVatId`
   (VIES syntax per member state) — a non-blocking readiness gap. A VIES
   lookup is #895.
4. **Rates.** The catalogue has no date-effectivity; a change mid-period
   is the owner's edit, and every issued document keeps the rate it was
   issued with (frozen `vat_totals`). Rounding is per line, identical in
   SQL and Dart (pinned by test) — art. 230 lets member states accept
   either. Documented, unchanged.
5. **Declarations** map FR (CA3 boxes 08/09/9B/11/14/05) and DE (UStVA
   Kz 81/86/…); other countries print generic rate lines. Unchanged.
6. **Credit notes do not reverse VAT.** The breakdown counts charges
   only; a negative document (an *avoir* where credits exceed charges)
   shows the charges' VAT and a negative total — money moved, not VAT
   reversed. Compliant until a VAT-bearing charge is ever cancelled;
   then art. 219 wants a document that reverses the VAT and references
   the original. **Filed as #894** (a `credit_note` kind).
7. **Reverse charge / intra-EU B2B** (category AE/K, art. 196) is not
   modelled: every positive rate is S and prices are VAT-inclusive for
   every buyer. **Filed as #895.**
8. **Cash-basis exigibility.** Declarations aggregate invoices by issue
   date; French services owe VAT on payment (CGI 269-2-c) unless the
   seller opted for *débits*, and the subscription is billed ahead of
   its month (#802). **Filed as #896** (a workspace setting and
   payment-based declaration lines).
9. **Chronology and immutability** hold: continuous numbering per
   workspace, `invoices_no_mutation`, corrections by voiding and
   reissuing, settlements referencing their sources.

## Decision

Ship the safe corrections now (2, 3) with the **VAT report** — a
registered report kind `vat`, one position per document and rate from
the frozen `vat_totals` (pre-0072 documents derive their single
zero-rated entry as the documents do), subtotals per rate and category,
period totals, the reversed original beside a correcting document; as
the letter (quick view / save / share, designable like every kind) and
as a semicolon CSV for the accountant, from the declarations screen for
the selected month or quarter. Everything that changes how documents or
declarations are **computed** (6, 7, 8) is filed, not slipped in.

## Consequences

- Exempt sellers print a statutory mention out of the box; the owner's
  own text still wins.
- The e-invoice sheet warns on a malformed customer VAT id but does not
  block: the id may be right and the table incomplete.
- The wiki carries the checklist (§11a) so the next review starts from
  this one.
