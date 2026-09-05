# ADR 0017 — When VAT falls due: one setting, one apportionment, two readers

**Status:** accepted · **Date:** 2026-09-05

## Context

The VAT review (#878, ADR 0015) recorded three limits. Two are closed
(#894 credit notes, #895 reverse charge, ADR 0016). The third is this
one: every declaration was built from **issue dates**, as if the tax
always fell due when the document was written.

That is only one of the two regimes European law recognises. Under
Directive 2006/112/EC art. 66 a member state may let the tax become
chargeable on receipt of the price, and several do so by default for
services: France puts services on *les encaissements* unless the seller
opts for *les débits* (CGI art. 269-2-c), Germany offers
*Ist-Versteuerung* (§ 20 UStG), Italy *IVA per cassa*, Spain the
*criterio de caja*. A coworking space that bills services and is paid
weeks later was therefore declaring — and paying — tax it did not yet
owe, and its accountant's report agreed with the wrong figure.

## Decision

**The basis is a declared choice, not a guess.** `invoice_legal` gains
`vat_exigibility`, `'invoice'` (the previous behaviour) or `'payment'`,
asked on *Legal identity* and only of a VAT-registered workspace — a
seller that charges no tax has no moment at which one falls due. It is
not inferred from the country: the seller's option is theirs to state,
and a wrong inference would misfile a return.

**A payment is apportioned across the document's rates, once.** A
customer pays a document, not a rate. `paymentSharesByRate` splits what
was received in proportion to what each rate weighs in the invoice, and
gives the rounding remainder to the widest rate so the shares add up to
exactly the amount received. A part payment therefore carries part of
every rate, which is how the authorities apportion one.

**The declaration and the accountant's report read the same function.**
On the cash basis `computeVatDeclarationLinesOnPayment` and
`buildVatReport(matches: …)` both call `paymentSharesByRate`, and a
report position becomes a payment dated the day it was matched. Two
computations of the same period could disagree by a cent and nobody
would know which to file; one computation cannot.

**Everything that shows a period says which period it is.** The invoice
prints the statutory mention (`vat_exigibility_mention` — « TVA
acquittée sur les encaissements / sur les débits », and its equivalent
in the seller's country), the declarations screen carries a banner, the
declaration PDF opens its disclaimer with the basis, and the VAT report
letter prints `vat_basis_note`. A figure whose basis is unstated is a
figure the reader has to guess at.

## Consequences

- Switching the basis re-scopes every declaration generated afterwards.
  Declarations already stored keep the figures they froze, as they must.
- The cash basis needs payment matches to be recorded; a workspace that
  never registers payments would declare nothing. That is truthful —
  nothing has been received as far as the app knows — and the invoice
  basis remains the default for exactly that reason.
- No migration: the setting rides in the existing `invoice_legal` jsonb
  and every computation is client-side. `create_invoice` is untouched.

## Alternatives rejected

- **Infer the basis from the country and the kind of supply.** It would
  be right most of the time in France and wrong for every seller who
  opted the other way, with no screen explaining the difference.
- **Declare on payments but keep the report on issue dates.** The
  accountant would reconcile two documents that describe different
  periods, which is the failure this decision exists to prevent.
- **Freeze the basis on each invoice.** The basis is a property of the
  seller's return, not of a document; a workspace that switches would
  end up with periods that are neither one basis nor the other.
