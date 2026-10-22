<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# The accounting exports, country by country

What this app hands an accountant or an auditor, what each file claims
about itself, and — the part that keeps the registry honest — **what
each supported country actually mandates that we do not produce.**

The app bills in **32 countries**: EU27 plus CH, NO, GB, CA and US
(`CountryCatalog`). Two of them get a file made to a published national
spec. Every one of them gets at least one exchange format, and
`accounting_standards_test.dart` fails if that ever stops being true.

## What a claim means

`FormatClaim` in `accounting_format.dart` is the whole design:

| claim | meaning |
|---|---|
| `regulatory` | a named authority asks for this file, produced to their published spec and to the scope that spec defines for a system like this one |
| `exchange` | an accountant's software reads it and a **person** reviews and posts what it contains — no authority is being told anything |
| `subset` | the shape is real, the file is deliberately partial, and it says so in its own header |

A wrong `regulatory` is not a bug, it is a false statement to a tax
authority. Widening one needs the authority's own spec in hand.

## What is produced

| format | claim | countries | verified by |
|---|---|---|---|
| FEC | regulatory | FR | balance per entry and file-wide, 18 columns in order, chronological, no BOM, `DateLet` on every lettered row, a written-off rest on 654 lettered with its invoice |
| SAF-T (PT), `TaxAccountingBasis` **F** | regulatory | PT | declared invoicing-only, `SoftwareCertificateNumber` 0 |
| DATEV EXTF Buchungsstapel | exchange | DE, AT | 31-field header (SKR in field 27, fiscal-year start from the book profile), first 20 fields per row, Belegfeld 1 cut at 36 and Buchungstext at 60, positive amounts + S/H, DDMM, `Festschreibung` 0, **UTF-8 BOM**, a written-off rest on SKR03 2400 |
| Sage 50 audit trail | exchange | GB, IE | a written-off rest is an SC to 8100 without tax |
| Swiss booking journal (KMU accounts, Ziffer per row) | exchange | CH | Not a native Banana or bexio template: neither publishes its column specification. |
| SAF-T, invoicing subset | subset | everywhere | `GeneralLedgerEntries` omitted unless the owner maps accounts; then sales cycle only, every transaction balances, credit notes reverse the sale, netted cash is posted, a written-off rest to the mapped loss account, in the sales journal (none mapped, none posted) |
| Accountant CSV | exchange | everywhere | |
| Audit trail | exchange | everywhere | called a trail, never an "audit file"; write-offs are events, a credit note shows its signed value |
| Archive bundle | exchange | everywhere | a fiscal year as one zip |

## The target registry

Every file and connection target is a descriptor in `accounting_format.dart`
(`AccountingTarget`, #2370): its countries, what it receives, how it is
reached and how far it is qualified. The table below is generated from it;
`accounting_coverage_test.dart` fails when the two disagree.

<!-- BEGIN GENERATED TARGETS (dart run tool/build_accounting_coverage.dart) -->
| target | product | transport | payload | countries | qualification | specification |
|---|---|---|---|---|---|---|
| `fec` | DGFiP · FEC · BIC/IS, art. A47 A-1 LPF | file | journal | FR | locallyValidated | DGFiP fichiers standards des écritures comptables |
| `fr_ereporting` | DGFiP · e-reporting · flows 10.1-10.4 | file | documents | FR | implemented | DGFiP e-reporting flows 10.1-10.4 (structure only) |
| `saft_pt` | Autoridade Tributária · SAF-T (PT) · 1.04_01, TaxAccountingBasis F | file | documents | PT | locallyValidated | SAF-T PT, TaxAccountingBasis F |
| `datev` | DATEV · Rechnungswesen · EXTF 700 Buchungsstapel | file | journal | AT, DE | locallyValidated | not named yet |
| `sage50` | Sage · Sage 50 Accounts · audit trail CSV | file | documents | GB, IE | implemented | not named yet |
| `ch_kmu` | KMU-Kontenrahmen · Swiss booking journal · CSV, Ziffer per row | file | journal | CH | implemented | not named yet |
| `saft` | OECD · SAF-T · 2.0, ledger omitted | file | documents | everywhere | implemented | OECD SAF-T, ledger omitted on purpose |
| `accountant_csv` | DesKilo · Accountant CSV · format 2 | file | documents | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `generic_journal_csv` | DesKilo · Generic journal CSV · compute_postings | file | journal | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `audit_trail` | DesKilo · Audit trail · CSV | file | documents | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `bundle` | DesKilo · Fiscal-year archive · PDF/A-3 bundle | file | documents | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
<!-- END GENERATED TARGETS -->

Write-offs are posted **gross**, as a loss, on the day they were given up:
the VAT correction (bad debt relief, e.g. art. 272 CGI, §17 UStG, Sage's relief
claim) has its own conditions and stays with the accountant. The loss accounts
are `account_map` rows of the tax reference store (FR 654000 confirmed; DE 2400
and GB 8100 unconfirmed until an accountant has checked the chart in use).

## What each country mandates that this app does not produce

**This table is a map of known absences, not a compliance statement.**
These regimes change on published timetables and several are mid-rollout;
confirm the current position with the workspace's own accountant before
relying on any row. What the table is for is making sure no absence is an
oversight.

The single reason most of these cannot be produced is the same one, and
it is a data-model fact rather than a formatting one: **DesKilo keeps
invoices, payments and a running member account — not a double-entry
general ledger over a chart of accounts** (ADR 0022). Every format below
marked *ledger* mandates `GeneralLedgerEntries` or its equivalent. No
amount of exporting closes that.

| country | obligation we do not meet | why |
|---|---|---|
| DE | GoBD machine-readable handover for a Betriebsprüfung (the descriptor-file form) | ledger; DATEV covers the accountant, not the auditor |
| AT | §§131/132 BAO data provision | ledger |
| PT | SAF-T accounting variants (`TaxAccountingBasis` C / I); certified-software obligation above the threshold | ledger; certification is a separate obligation the file cannot satisfy |
| NO | SAF-T Financial on demand | ledger |
| LU | FAIA | ledger |
| PL | JPK_KR (books) | ledger |
| RO | SAF-T D406 | ledger |
| LT | i.SAF / SAF-T | ledger |
| BG | SAF-T (phased introduction) | ledger |
| ES | SII, and the certified-billing-software regime | real-time reporting and certification, not a file |
| IT | FatturaPA through SdI | e-invoicing transport — see below |
| HU | Online Számla real-time invoice reporting | real-time reporting |
| GR | myDATA | real-time reporting |
| DK | digital bookkeeping act, registered systems | system registration, not a file |
| HR, SI, SK, CZ | cash-register fiscalisation | point-of-sale regimes; a coworking invoicing monthly is usually out of scope, but confirm |
| CH, GB, IE, SE, FI, NL, BE, EE, LV, CY, MT, CA, US | no standing accounting-export mandate known | the exchange formats are the answer |

**E-invoicing is a separate axis and is largely covered.** Factur-X /
Chorus Pro, UBL, and the customer-delivery path exist
(`invoice_ubl.dart`, `einvoice_gateway.dart`, ADRs 0015–0017). The table
above is about *accounting* exports; do not read a row there as saying
the country's e-invoicing is unhandled.

## The two defects this audit found

Recorded because both were structurally perfect files that were wrong
anyway, and both had passing tests beside them.

**DATEV was written as UTF-8 with no byte-order mark.** DATEV reads an
unmarked file as Windows-1252, so "Bürogemeinschaft München" imported as
"BÃ¼rogemeinschaft MÃ¼nchen" — in the accountant's books, silently,
with nothing anywhere reporting an error. Fixed with the BOM rather than
by transcoding: a Munich coworking bills members called Kowalczyk and
Škoda, and Windows-1252 cannot spell the second one.

**DATEV booked the invoice BALANCE as revenue.** An invoice may net
payments the member already made during the month: 300 charged, 120
already paid, 180 left. It booked the 180 as revenue and the 120 nowhere
at all — so revenue was understated by every euro anyone paid mid-month,
the bank was short by the same, and the VAT base under it followed. The
FEC had always split these correctly, which is what made the divergence
findable: the two exports are now reconciled against each other in the
suite.

## What the tests hold

`test/features/money/accounting_standards_test.dart`, over a year
containing several VAT rates on one document, a credit note, a netted
payment, a matched payment, reverse charge and an amount that does not
divide cleanly:

- every FEC entry balances, and so does the file;
- each entry is one journal, one date, one document;
- reverse charge collects no VAT — nothing reaches 44571;
- rows are chronological, and a sale precedes the cash that settled it;
- the FEC carries no BOM and DATEV carries one;
- every DATEV row has 20 fields, a positive amount, an `S` flag, a
  four-digit `Belegdatum`, and never posts an account against itself;
- the two files reconcile on revenue;
- a file for one fiscal year holds that year's invoices, ledger entries and repartitions only, and the export screen cuts them before DATEV, whose Belegdatum has no year, can re-date them (#2365);
- every SAF-T ledger transaction balances, credit notes included, and its header totals are the sums of its lines (#2365);
- a ledger expense netted on an invoice is booked once (purchases), never also as money in on the bank (#2365);
- every supported country is offered something, and `regulatory` is
  claimed only for FR and PT.
