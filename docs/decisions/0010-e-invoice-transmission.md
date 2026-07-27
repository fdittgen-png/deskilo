# ADR 0010 — E-invoice: produce the document here, let a service provider transmit it

**Status:** accepted · **Date:** 2026-07-27 · **Extends** the invoicing chain 0060–0068 (immutable derived invoices) with migration 0069 (legal identity)

## Context

DesKilo exports an EN 16931 invoice as UBL 2.1 XML. Two questions were open:

1. **Was the file even valid?** No. `BR-CO-26` is a fatal rule — the seller must carry at least one identifier (BT-29 seller id, BT-30 legal registration id, BT-31 VAT id) — and the app stored none, so every exported file failed validation. The tax coding was also a guess: category `O` (outside the scope of VAT) *forbids* a seller tax identifier (`BR-O-02`), while a small operator under a national exemption belongs in category `E`, which *requires* one plus an exemption reason (`BR-E-02`, `BR-E-10`). Missing too: the invoiced period as a period (BT-73/74), the payment account (BT-84), and any guard against exporting a month whose lines are all credits (`BR-16`).

2. **How does the file reach the recipient?** Sharing an XML through the phone's share sheet answers "where do I send this?" with silence. In the EU the answer is one of four transport models, per country:

   | Model | Countries (2026) | Who moves the file |
   |---|---|---|
   | Peppol | BE (B2B mandate), public buyers EU-wide (2014/55/EU) | an **access point** |
   | Accredited platform | FR (*plateforme agréée*, ex-PDP) | a **registered private platform**, which also reports to the tax administration |
   | Clearance | IT (SdI), PL (KSeF), RO (e-Factura/SPV) | the **national platform**, which receives the invoice first |
   | No imposed channel | DE today, most others | e-mail, a portal, or Peppol by agreement |

## Decision

### 1. DesKilo produces the document; it does not become a network node

The app will **not** become a Peppol access point or a French *plateforme agréée*. Both are accredited roles with certificate management, SMP/SML registration, uptime commitments, mandatory interoperability testing and per-country legal obligations (a PA additionally reports transaction data to the DGFiP). That is a compliance company, not a feature of a coworking app — and it would contradict the project's "tracking, not processing" line, the same reason payments are recorded rather than executed (ADR 0006).

The unit of work DesKilo owns is the **semantically correct EN 16931 document**. Every access point and platform accepts EN 16931 UBL or CII and maps it to the national CIUS itself (FatturaPA, FA(3), CIUS-RO, XRechnung, Peppol BIS). Getting the *semantics* right is what makes the file usable everywhere; getting the *syntax* right for 27 countries is what providers sell.

### 2. Three delivery paths, in order of cost to the user

1. **Export today (implemented).** Download or share the XML from the invoice's detail sheet, with a sheet that first states — for the workspace's own country — which channel business customers expect, whether a platform sits in the path, and which channel public buyers use (`e_invoice_routing.dart`). Where the domestic mandate runs on a national syntax (IT, PL, RO), the sheet says plainly that this file is not the one that platform accepts.
2. **Provider integration (designed, not built).** An optional, per-workspace connection to one aggregator with a single REST API covering both Peppol and the clearance networks (Storecove, Unifiedpost, Pagero/Thomson Reuters, EDICOM and e-invoice.be are the current candidates; pay-per-document pricing starts around €0.18–0.30). It reuses the shape the payment providers already established: credentials in the deny-all `payment_credentials`-style table, an owner-only settings screen, and an **edge function** (`send-e-invoice`) that posts the UBL plus the recipient's routing identifier and stores the provider's document id and status on `invoice_transmissions`. The client never holds the API key. Blocked on: a provider account, and a member-level field for the customer's Peppol/routing id.
3. **Factur-X hybrid PDF (recommended next).** The `pdf` package already ships `PdfaAttachedFile`, `PdfaFacturxRdf` and a PDF/A colour profile, so the existing invoice PDF can carry the machine-readable invoice inside it. This is what French and German small businesses actually exchange, it needs no network at all, and it degrades gracefully — a human sees a PDF, a machine finds the XML. Cost: a CII (UN/CEFACT) builder beside the UBL one, since Factur-X embeds CII, plus PDF/A-3 conformance that can only be verified with an external validator (veraPDF, Mustang, FNFE).

### 3. The seller's legal identity is declared, not guessed (migration 0069)

- `workspaces` gains `vat_regime` (`not_subject` | `exempt` | `vat_registered`), `vat_id`, `legal_id`, `tax_exemption_reason`, and structured `street`/`city`/`postal_code`.
- The **regime drives the mapping**: `not_subject` → category `O` with `VATEX-EU-O`, identified by BT-30 and carrying no tax scheme; `exempt` → category `E` with rate 0, BT-31 and a reason (`VATEX-FR-FRANCHISE` in France, free text elsewhere); `vat_registered` → **the export refuses**, because the app does not price VAT per position and a zero-VAT declaration from a VAT-charging seller is a false statement, not a rounding error.
- `profiles` gains `country_code` (BT-55 is mandatory and defaulting it to the workspace's country silently mis-declares a foreign customer) and `vat_id` (BT-48).
- `invoices` gains a `parties` jsonb **snapshot**, part of the signed content: an issued document keeps saying what it said, even after the workspace changes regime.

### 4. Refuse before exporting, and say why

`checkEInvoiceReadiness` runs the fatal rules the app can decide locally and the sheet reports them in the owner's words — "the company registration number is missing", not "BR-CO-26" — with a direct route to the screen that fixes them. Non-fatal profile gaps (city, post code) warn without blocking. A file that a receiving platform will silently reject is worse than no file.

## Consequences

- Every invoice issued after 0069 is self-contained and, with the identity filled in, passes the fatal EN 16931 rules. Pre-0069 invoices borrow the workspace's current identity (same legal entity) — documented as a bridge, not a rewrite.
- VAT-charging workspaces get no XML until per-position VAT exists. That is a real limitation, stated in-app and in the guides.
- Peppol BIS additionally requires an electronic address for **both** parties (`PEPPOL-EN16931-R010/R020`); private members have none, so the app emits the plain EN 16931 profile and leaves CIUS mapping to the provider. Nothing in the schema blocks adding routing ids later.
- Transmission timelines are deliberately absent from the code (`e_invoice_routing.dart` carries channels and syntaxes only): mandate calendars slip every year, and a wrong date shipped in an app is worse than no date.
