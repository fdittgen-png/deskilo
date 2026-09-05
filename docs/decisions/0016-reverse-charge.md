# ADR 0016 — Intra-EU B2B: the customer's tax, and the price stays the tariff

**Status:** accepted · **Date:** 2026-09-05

## Context

The VAT review (#878, ADR 0015) found that reverse charge was not
modelled: every positive rate was category S whoever the buyer was, so a
VAT-registered workspace invoicing a business in another member state
charged French (or German…) VAT on a supply the customer must
self-assess (Council Directive 2006/112/EC art. 196). EN 16931 has a
category for it — **AE**, with `VATEX-EU-AE` — and the invoice must
carry a mention saying why no tax is charged.

## Decision

**The rule, in one place and mirrored.** A supply is reverse-charged
when the seller is `vat_registered`, both countries are member states,
they differ, the buyer holds a VAT identifier, and the workspace has not
opted out. It lives in `create_invoice` (migration 0157, so the frozen
document states it) and in `reverseChargeApplies` (Dart, for previews
and checks); the SQL twin is pinned by test.

**The price is the tariff.** No tax is added and none is extracted: the
amount billed IS the taxable base of the reverse-charged supply, the
lines are zero-rated and the breakdown is one AE entry with net = gross.
A customer abroad therefore pays the same number as a customer at home,
and the seller keeps what the tariff says — the alternative (extracting
the domestic VAT out of the tariff so the foreigner pays less) makes the
same seat cost two different prices depending on the buyer's passport,
which is a commercial decision, not a tax one.

**The document says why.** `reverseChargeMention(sellerCountry)` prints
the statutory sentence in the seller's language, citing art. 196, and it
WINS over the seller's own exemption text: the two describe different
regimes. The e-invoice carries category AE and `VATEX-EU-AE`; the
readiness check refuses to send without the customer's VAT identifier
(BT-48) — it is what proves the tax is theirs.

**An opt-out, not an opt-in.** A workspace that never invoices
businesses abroad turns it off on the Legal identity screen; everyone
else is compliant without touching a setting.

## Consequences

- Declarations: an AE entry is zero-rated, so it lands in the untaxed
  bucket (FR CA3 box 05, DE Kz 21 territory) with the other zero rates.
  Naming the intra-EU services line precisely, and the recapitulative
  statement (DEB/DES) that goes with it, stay out of scope.
- A VIES lookup is not performed: the identifier is checked for its
  member state's SHAPE only (#878). A workspace that needs the online
  proof keeps its own record.
- A rate change between a charge and its reversal is still the owner's
  business (#894).
