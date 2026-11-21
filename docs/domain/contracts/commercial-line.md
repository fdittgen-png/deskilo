<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Commercial line — what a new line states exactly, and what a reader that cannot read it may never say

## Baseline

- Refs: #4162 (X1: versioned measurement and supply facts), #4155 (v2.2), #4165 (the first producer, standalone invoices), #4161 (the shared exact quantity), #3727 (old readers)
- Canonical sources: `packages/deskilo_invoice_model/lib/src/commercial_line_snapshot.dart` (the one decoder), `commercial_line_facts.dart` and `commercial_decimal.dart` beside it (the frozen facts, the exact decimal), `packages/deskilo_invoice_model/lib/src/invoice_line_commercial.dart` (what a reader may say), `packages/deskilo_invoice_model/lib/src/invoice_line_snapshot.dart` (where it is read), `packages/deskilo_money_kernel/lib/src/accounting_amount.dart` (the exact decimal)
- Delivered by checkpoint X1.A: the version 1 contract, its decoder and its readers; by X1.B: the structured invoice (CII, UBL). No producer writes the member yet (#4165 does); a legacy line, and the legacy monthly invoice, never carry it.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| legacy line | a line of the monthly derivation: an integer `quantity` and an amount | none of its own; its position and kind |
| commercial line | a line issued under this contract: its facts are the optional `commercial` member of the line snapshot, version 1 | `line_id`, immutable, scoped to the seller; never a position, a label, an item id or a movement id |
| source reference | the commitment or document a line comes from, and its frozen source line: a quote line behind an invoice line, the original line behind a correction | `{kind, id, revision, line_id}`; the kinds `quote`, `commitment` and `invoice` are acted on, any other is kept readable |
| quantity | the entered quantity, an exact decimal | canonical text, at most six fractional and twelve integer digits |
| unit | what the quantity counts, frozen at issue | `{code, un_ece_code, label}`; the reviewed UN/ECE code is what a structured invoice needs |
| unit price | the entered price, not a total divided after rounding | `{amount, currency, basis, base_quantity}`; `basis` is `net` or `gross` |
| supply | what the line supplies, for the tax rules | `property`, `general` or `goods`; goods never inherits the immovable-property rule |
| authoritative amounts | the server's result in the issuer currency's minor units | `{currency, net_minor, tax_minor, gross_minor}` as text; net plus tax is gross |

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| How many commercial members does a line carry? | none or one | none is a legacy line, read as it always was |
| How many versions does a decoder read? | exactly one, version 1 | any other version is kept as raw facts |
| For one correction line, how many source lines? | exactly one, an `invoice` source | the correction has its own `line_id` and may carry a negative quantity; an ordinary line may not |
| Does the legacy integer `quantity` still mean something on a commercial line? | no | readers print the exact quantity and never the integer; the integer is only the old field's default |

## States and transitions

Declared states: `legacy`, `readable`, `unsupported`.

A line is `legacy` while it has no `commercial` member. A reader decides the other two by what it can interpret; the line itself never changes.

| from | event | guard | to | effects |
|---|---|---|---|---|
| `legacy` | read | no `commercial` member | `legacy` | the integer quantity and amounts, unchanged |
| (none) | read, version 1 | every fact present, exact and consistent | `readable` | the facts of the line, quantity as canonical text |
| (none) | read, another version, an unknown supply kind, or a fact that is missing, inexact or inconsistent | any of them | `unsupported` | the raw facts stay readable; no quantity is defaulted, nothing is issued, corrected, stocked out or exported from the line |

## Invariants

| invariant | enforcement |
|---|---|
| a quantity or a price never goes through a binary float or `toInt()` | `parseCommercialDecimal` reads plain decimal text with the kernel's exact decimal; more than six fractional digits is refused, never rounded |
| a quantity is positive, bounded, and negative only on a correction | `parseCommercialDecimal` and the `invoice` source rule of the decoder |
| a reader never prints a default quantity for a measured line | `InvoiceLine.quantityText`: the exact text, the raw text of an unsupported line, or nothing; never the integer |
| the structured invoice states a commercial line exactly, or refuses it | CII and UBL write the exact quantity, the reviewed UN/ECE unit code, the entered net unit price with its base quantity and the frozen net (`structuredCommercialLine`); a line the reader cannot interpret, a unit without its code, a source kind not acted on, a correction, a credit note, a price entered gross or a currency other than the invoice's is refused (`CommercialOutputBlocked`), never defaulted to `C62` or an integer. The national profiles (SdI, KSeF) and the SAF-T book refuse every commercial line until their own checkpoint |
| unknown facts authorise nothing | `commercialFactsReadable` is false while a line is `unsupported`; a unit without its UN/ECE code or a source kind not acted on makes the line not `exportable` |
| the amounts are the server's | the decoder reads them as minor units from text, within what JSON carries exactly, and refuses a line whose net plus tax is not its gross; no reader recomputes them |
| a legacy line is unchanged | no `commercial` member: `invoiceLineFromSnapshot` is what it was |

## Processing

Reading only. `invoiceLineFromSnapshot` passes the `commercial` member to `commercialLineFromSnapshot`, which never throws. The document data (`report_data.dart`) prints the exact quantity with its unit and the entered unit price, and prints nothing for a line it cannot read. A producer (#4165) writes the member through the supported versioned command; this checkpoint adds no write.

Not delivered, and stated so: the server-side validation of a commercial line, the correction's use of the source line (so corrections and credit notes stay refused in the structured invoice), the structured output of the national profiles and the SAF-T book, a rule that derives the structured net price from a gross entered one, and the compatibility gate of old readers (#3727).

## Evidence

- `packages/deskilo_invoice_model/test/commercial_line_snapshot_test.dart`: legacy lines unchanged; 1.5 h and 0.750000 kg round trip; the six-decimal boundary; zero, negative, malformed and overflow; amounts that do not add up; zero- and three-decimal currencies; an unknown version and supply kind kept readable; a reader that prints no default quantity; future source kinds; a correction's source.
- `test/features/money/commercial_line_consumers_test.dart`: a printed line states its exact quantity, unit and entered price; a legacy line prints as before; an unsupported line prints no default; a structured invoice refuses a commercial line.
- `test/features/money/commercial_structured_test.dart`: CII and UBL state 0.75 kg as `0.75` with `KGM`, the entered net price and the frozen net, with a base quantity when the price is quoted for more than one; the totals agree; every case that cannot be stated is refused; a legacy line stays `C62` and its integer; the national profiles refuse a commercial line.
- `test/features/money/einvoice_samples_test.dart` writes a measured-line sample in both syntaxes, validated by KoSIT in CI (`tool/einvoice/validate.sh`).
- Not tested yet, for want of a producer: the same fractional line end to end from the editor through the PDF and the structured invoice (with #4165), and the old-reader compatibility fixture (#3727).
