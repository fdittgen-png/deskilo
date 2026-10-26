<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# The accounting exports, country by country

What this app hands an accountant or an auditor, what each file claims
about itself, and — the part that keeps the registry honest — **what
each supported country actually mandates that we do not produce.**

The app bills in **32 countries**: EU27 plus CH, NO, GB, CA and US
(`CountryCatalog`). Four of them get a file made to a published national
spec (FR, PT, and since #2379 NO and LU from a local book). Every one of them gets at least one exchange format, and
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
| DATEV EXTF Buchungsstapel | exchange | DE, AT | a zip (#2375): one Buchungsstapel per calendar month and journal (sales; every booking that moves the bank) of the workspace's calendar, at most 99 999 rows each, 125 fields per row (format 700, version 13), each under its month's header (SKR in field 27, fiscal-year start from the book profile — refused when the sites' profiles disagree — Bezeichnung cut at 30, `Festschreibung` 1 when the month lies in a closed period, else 0); every customer row on the member's Debitor: the first Debitor the person enters plus the counter of the member number read through the space's member series (`M-2026-0007` is counter 7), in DATEV's range for the Sachkontenlänge entered (10000–69999 for four); KOST1 = the document's site, else the cost centre entered; Beleginfo Rechnungsnummer/Belegdatum/Fälligkeit; when chosen, Beleglink `BEDI "<invoice id>"` to the voucher PDF/A-3 in `belege/`; EU-Land u. UStID on a reverse charge; each rate on its automatic account without a key, a non-automatic revenue account with the rate group's BU-Schlüssel (`account_map` `datev/tax:<group>`, refused with the rate named while no such row exists); the Debitoren-Stammdaten (category 16) name every Debitor used; a Belegfeld 1 or KOST1 longer than 36 is refused, never cut; Buchungstext cut at 60, positive amounts + S/H, DDMM, **UTF-8 BOM**, a written-off rest on SKR03 2400. Berater-/Mandantennummer, the Sachkontenlänge and the currency (euros only) are checked before anything is written. The DATEV online services (Buchungsdatenservice, Rechnungsdatenservice 1.0, Belegbilderservice) are decided targets that need a DATEV marketplace partnership and the client's SmartLogin; none exists. |
| GoBD data handover (Z3) | subset | DE | a zip (#2375): `index.xml` valid against the published `gdpdu-01-08-2002.dtd` (shipped beside it), one header-less UTF-8 CSV per table with every column, key and join described (invoices, lines, tax amounts, payments, instalments, write-offs, member ledger, shared costs, purchase documents and lines, customers, tax rates with their versions, number sequences, audit trail, vouchers), each invoice's e-invoice XML and PDF/A-3 in `belege/`, and the Verfahrensdokumentation (server schema version, number sequences, retention clocks). Says in its own index that it is DesKilo's sub-ledger, not the complete books. |
| Sage 50 audit trail | exchange | GB, IE | a written-off rest is an SC to 8100 without tax |
| Swiss booking journal (KMU accounts, Ziffer per row) | exchange | CH | Not a native Banana or bexio template: neither publishes its column specification. |
| SAF-T Financial (NO) | regulatory | NO | #2379, a local book's postings only: valid against Skatteetaten's `Norwegian_SAF-T_Financial_Schema_v_1.30.xsd` (shipped under `test/fixtures/saft/`, read in CI by `tool/saft/validate.sh`); every account with its opening and closing balance of the fiscal year, its GroupingCategory and GroupingCode from the `saf_t/<role>` row of NO; customers and suppliers by their sub-ledger numbers with a BalanceAccount per collective account; the tax table with each rate version in force and its StandardTaxCode from the `saf_t/tax:<direction>:<group>` row; one transaction per posting, every line naming its SourceDocumentID, TaxInformation on the tax lines. An account or tax code without its row, a missing company or contact field, a party without its number, or an identifier longer than the schema allows refuses the file and is named. |
| FAIA (LU) | regulatory | LU | #2379, the same tree to the FAIA 2.01 schema (`FAIA_v_2.01_full.xsd`): StandardAccountID from the `saf_t/<role>` row of LU, the contact's telephone and every party's postal address required (refused, named, otherwise), one AccountID per party. |
| SAF-T with the general ledger | exchange | everywhere | #2379, the same tree in the OECD 2.0 namespace without national restriction; the OECD publishes its XSD only inside its 2010 guidance, so the file is read against Luxembourg's publication of the same tree. |
| SAF-T, invoicing subset | subset | everywhere | `GeneralLedgerEntries` omitted unless the owner maps accounts; then sales cycle only, every transaction balances, credit notes reverse the sale, netted cash is posted, a written-off rest to the mapped loss account, in the sales journal (none mapped, none posted) |
| Accountant CSV | exchange | everywhere | format 3 (#2378): `tax_components` holds each invoice's taxes as frozen at issue (JSON, integer minor units; a total stored without components is marked `"split": false`), then one column per tax key of the period — `GST`, `HST`, `QST`, `PST` (Canada), `state_tax` / `local_tax` (US sales tax), `VAT <rate>` (an un-split total) — each the sum of its components |
| Audit trail | exchange | everywhere | called a trail, never an "audit file"; write-offs are events, a credit note shows its signed value |
| Archive bundle | exchange | everywhere | a fiscal year as one zip; `vat-account.csv` (#2378, the VAT account of UK VAT Regulations 1995 reg. 32) when the year has prepared or filed returns: per period output and input tax, corrections of earlier periods apart, payable = box 1 and allowable = box 4 of the return |

## The SAF-T Financial chart map (#2379)

The national codes a SAF-T Financial file states are `account_map` rows of
the tax reference store, format `saf_t`, edited on the tax reference screen:

| key | country | field | meaning |
|---|---|---|---|
| `saf_t/<role>` (or `saf_t/<role>:<qualifier>`, which wins) | NO | `account`, `label` | the GroupingCode and its GroupingCategory (næringsspesifikasjon) of the accounts that role books to |
| `saf_t/tax:<output\|input>:<group>` | NO | `tax_code` | the StandardTaxCode of that rate group, output or input |
| `saf_t/<role>` | LU | `account` | the StandardAccountID (PCN 2020) |

Migration 9999 (renumbered at push) seeds them unconfirmed, with their
source: Norway for every posting role and the three rate groups, Luxembourg
for the customers, suppliers, bank, revenue, VAT and expenses roles. A role
or rate group without its row refuses the file and is named; an accountant
corrects a row on the screen, never in the file. The FAIA shape (Luxembourg,
and the OECD file read against the FAIA schema) also requires the postal
address of the company and of every party, and the contact's telephone;
every field is checked against its schema length and refused, never cut,
when longer.

## The FEC as an import contract (#2376)

French importers (Pennylane, Sage 100, Cegid, EBP) take over a client's
entries from a FEC, so a local book's FEC is written for import as well as
for the audit:

- **Fiscal year.** The FEC covers the fiscal year of the book profile that
  holds the export's latest document (start month and day from the
  profile), and is named `<SIREN>FEC<closing day>.txt`. A year whose days
  are not all inside closed book periods is **provisional**: the person is
  told, and the archive names it `PROVISOIRE-…`. The FEC itself never
  carries a comment: its first record is the 18 field names.
- **Auxiliary accounts.** A customers or suppliers line keeps the collective
  in `CompteNum` and names its party in `CompAuxNum` / `CompAuxLib`: the
  collective's root and the member's or supplier's number in capitals
  (`411M0001`, `40117`), at most 13 characters after the root (the `fec`
  target's customer id rule). A party without a usable number stops the
  file and is named.
- **Currency.** An entry in another currency than the book's would be
  written in the book's currency at the document's recorded rate, the
  original in `Montantdevise` / `Idevise`. No rate is recorded with a
  document yet, so such an entry stops the file and is named.
- **Contract check.** Before the file is saved, `fec_import_contract.dart`
  checks its bytes: UTF-8 without BOM, the header first, 18 tab-separated
  fields, `0,00` amounts with one side per line, every entry balanced, one
  date and piece per entry number, dates inside the year, `ValidDate` not
  after the closing day, an auxiliary account on every third-party line,
  `EcritureLet` with `DateLet` and each letter balanced on its third-party
  account, `Montantdevise` with `Idevise`, accounts known to the chart. A
  file that breaks it is not saved, and the rule is named.
- **Archive.** A French archive carries the year's FEC under its own name
  and `fec-manifest.txt` (status, fiscal year, sha256, the contract result
  and the scope: the entries DesKilo posts, not the company FEC while other
  books live elsewhere). A closed year's FEC is logged once in the export
  log; a later archive must carry the same bytes, or it is not made.
  The archive of a calendar year carries the FEC of every fiscal year it
  overlaps up to its latest document: with a year from 1 October, the
  2026 archive holds the year closed on 30 September 2026 (final) and the
  one running since 1 October (provisional), so every entry its register
  lists is in one of its FECs; the manifest qualifies each, oldest first.
  One changed closed year stops the archive, and nothing is logged.
- **Books in the app.** The general ledger, the trial balance (general and
  auxiliary) and the journals with their summary print from the same
  postings, as report kinds of the designer.

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
| `gobd` | BMF · GoBD Datenträgerüberlassung (Z3) · Beschreibungsstandard, gdpdu-01-08-2002.dtd | file | documents | DE | locallyValidated | GDPdU Beschreibungsstandard 1.1, gdpdu-01-08-2002.dtd |
| `datev_buchungsdatenservice` | DATEV · Buchungsdatenservice · DATEVconnect online, Marktplatz-Partnerschaft und SmartLogin | api | journal | AT, DE | specificationNeeded | not named yet |
| `datev_rechnungsdatenservice` | DATEV · Rechnungsdatenservice 1.0 · DATEVconnect online, Marktplatz-Partnerschaft und SmartLogin | api | documents | AT, DE | specificationNeeded | not named yet |
| `datev_belegbilderservice` | DATEV · Belegbilderservice · DATEVconnect online, Marktplatz-Partnerschaft und SmartLogin | api | documents | AT, DE | specificationNeeded | not named yet |
| `sage50` | Sage · Sage 50 Accounts · audit trail CSV | file | documents | GB, IE | implemented | not named yet |
| `ch_kmu` | KMU-Kontenrahmen · Swiss booking journal · CSV, Ziffer per row | file | journal | CH | implemented | not named yet |
| `saft_no` | Skatteetaten · SAF-T Financial · 1.30 | file | journal | NO | locallyValidated | Skatteetaten SAF-T Financial 1.30, Norwegian_SAF-T_Financial_Schema_v_1.30.xsd |
| `faia_lu` | Administration de l'enregistrement · FAIA · 2.01 | file | journal | LU | locallyValidated | AED FAIA 2.01, FAIA_v_2.01_full.xsd |
| `denmark_registered_system` | Erhvervsstyrelsen · Registered digital bookkeeping system · Bogføringsloven 2022 | api | documents | DK | specificationNeeded | not named yet |
| `saft_dk` | Erhvervsstyrelsen · SAF-T DK · standard export with the standard chart mapping | file | journal | DK | specificationNeeded | not named yet |
| `economic_api` | Visma · e-conomic · REST API | api | documents | DK | specificationNeeded | not named yet |
| `dinero_api` | Visma · Dinero · API | api | documents | DK | specificationNeeded | not named yet |
| `billy_api` | Billy · Billy · API v2 | api | documents | DK | specificationNeeded | not named yet |
| `saft_oecd_full` | OECD · SAF-T · 2.0, general ledger from the posting engine | file | journal | everywhere | implemented | OECD SAF-T 2.0 guidance (2010), read against FAIA_v_2.01_full.xsd |
| `saft` | OECD · SAF-T · 2.0, ledger omitted | file | documents | everywhere | implemented | OECD SAF-T, ledger omitted on purpose |
| `accountant_csv` | DesKilo · Accountant CSV · format 3 | file | documents | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `generic_journal_csv` | DesKilo · Generic journal CSV · compute_postings | file | journal | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `general_ledger` | DesKilo · General ledger · PDF from compute_postings | file | journal | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `trial_balance` | DesKilo · Trial balance · general and auxiliary, PDF from compute_postings | file | journal | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `journals` | DesKilo · Journals · per journal and summary, PDF from compute_postings | file | journal | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `audit_trail` | DesKilo · Audit trail · CSV | file | documents | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `bundle` | DesKilo · Fiscal-year archive · PDF/A-3 bundle | file | documents | everywhere | implemented | DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md |
| `pennylane_api` | Pennylane · Pennylane · API v2 | api | documents | FR | implemented | Pennylane API v2, customer_invoices import and ledger_entries |
| `cegid_quadra_ascii` | Cegid · Quadra · ASCII import | file | journal | FR | specificationNeeded | not named yet |
| `ebp_import` | EBP · Comptabilité · import of entries | file | journal | FR | specificationNeeded | not named yet |
| `quickbooks_online_us` | Intuit · QuickBooks Online · Accounting API v3, US realm | api | documents | US | implemented | QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry |
| `quickbooks_online_ca` | Intuit · QuickBooks Online · Accounting API v3, CA realm | api | documents | CA | implemented | QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry |
| `quickbooks_online_gb` | Intuit · QuickBooks Online · Accounting API v3, GB realm | api | documents | GB | implemented | QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry |
<!-- END GENERATED TARGETS -->

Write-offs are posted **gross**, as a loss, on the day they were given up:
the VAT correction (bad debt relief, e.g. art. 272 CGI, §17 UStG, Sage's relief
claim) has its own conditions and stays with the accountant. The loss accounts
are `account_map` rows of the tax reference store (FR 654000 confirmed; DE 2400
and GB 8100 unconfirmed until an accountant has checked the chart in use).

## Connections, mappings and transfers (#2370)

An API target is reached through a **connection**: one per issuer and target
(`accounting_connections`), its state (`pending`, `connected`, `expired`,
`revoked`, `error`) shown on the *Accounting systems* sheet under the
`accountingConnectors` flag (child of `accountingBook`). No secret is in a
table: the pasted API token (`set_accounting_token_v1`) or the OAuth tokens of
a sign-in (the `accounting-connect` edge function: authorisation, the target's
redirect checked against a state kept in Vault, the code exchange, refresh) are
Vault secrets `accounting:<connection>:<key>`, resolved for the service role
only (`accounting_credentials_resolved`). Revoking forgets them and keeps the
mappings and the deliveries. A connection's remote company cannot change once
a delivery or a mapping names it; switching company is a new connection.

**Mappings** (`accounting_maps`, one table, `map_kind` account | tax | party |
item) name each key of the books on the target: a book role with its qualifier
(`revenue:standard`), a tax component key
`scheme|authority|treatment|rate|version` (`VAT|FR|taxed|20|2014`), a member,
site or supplier by id, a revenue role. A delivery that needs a key with no
mapping is blocked with the key named, and nothing is sent; no default code is
ever put in its place (`_shared/accounting_delivery.ts`, `missingMappings`).

**Deliveries** (`accounting_deliveries`): one row per stable identity — the
connection (or the file target and the issuer), the document event kind, the
document and the event day. The idempotency key is the sha256 of that identity,
stored before anything is sent; no profile revision or mapping change makes a
new one. For an API target the delivery kit runs: prepare; block on an
unmapped key; a send whose outcome is unknown (`sent`, `conflict`) is read back
first — exactly one matching remote document acknowledges it, a disagreeing one
or several are a `conflict` for a person — and only then create; an
acknowledged delivery asked again with its digest is a no-op, with another
digest it is refused (a correction, never a second create). For a file target
the generic journal records each document event it carried with the sha256 of
its own rows (`record_file_deliveries_v1`), pointing at the `book_exports` row
of the file: the same books delivered again change nothing, a changed document
follows the newer file.

The **Transfers** list (`accounting_transfers_v1`) is the digital-link evidence
of a year: every file handed out whose period overlaps it, with its sha256, who
made it, when and the documents it carried, and every document delivered to a
connection with the target's answer (remote number, draft or posted, attempts,
error).

**Delivering** (`accounting-connect`, action `deliver`, `deliver.ts`): a billing
manager delivers a year to a connected connection from the Transfers list
("Deliver *year* to *target*"), the app asking one calendar month per run, and
sends one document again from its line ("Deliver again"). What leaves is the
posting engine's answer to the caller (`compute_postings`, viewFinances), never
a body the client sent: one posting per document event, its digest the sha256
of its event, day, document and lines by role and amount (a changed mapping is
not a changed document). A period the engine cannot post (its blockers) sends
nothing; the target first checks the company (`prepare`) and a refusal sends
nothing either. An OAuth token about to expire is refreshed before the run. The
adapters sit flat in `_shared/` because only that directory deploys beside a
function:

- `pennylane_api` (`accounting_pennylane.ts`, `pennylaneLedger`): every posting
  a balanced ledger entry in the company's journal of the posting's code (VE,
  BQ, HA, OD), each line on the ledger account its role is mapped to
  (`account` mapping, remote id = the Pennylane ledger account id), its
  external reference the delivery's idempotency key, read back by it.
- `quickbooks_online_us`, `_ca`, `_gb` (`accounting_quickbooks.ts`,
  `quickbooksOnline`, #2371): signed in to the installation's Intuit
  application (`realmId` is the remote company). Before a run and after the
  sign-in the realm's `CompanyInfo.Country` must be the target's and
  `Preferences.SalesFormsPrefs.CustomTxnNumbers` on, or nothing is sent. An
  invoice is an `Invoice`, a credit note a `CreditMemo` (`DocNumber` = the
  legal number, one `SalesItemLine` per revenue line on the `item` mapping of
  its role, the customer found by "name (member number)" or created), a
  receipt a `Payment` linked to the invoice of its number, every other event
  a balanced `JournalEntry`. Every call names `minorversion=70`, every create
  a `requestid` (the idempotency key's first 50 characters) and carries the
  key in `PrivateNote`. Tax: QuickBooks is never the tax authority of an
  issued document. A US realm gets `TAX`/`NON` per line and the document's
  tax as the override `TxnTaxDetail {TxnTaxCodeRef, TotalTax}`
  (`TxnTaxCodeRef` = the `account vat_output:<group>` mapping); a CA or GB
  line carries the realm tax code its rate group is mapped to
  (`account vat_output:<group>`, a zero-rated group too). The total and tax
  QuickBooks books are compared with the document: a difference, a
  `SyncToken` other than the first (an edit in QuickBooks) or the number
  held by a document DesKilo did not deliver is a `conflict`; nothing is
  ever updated or created over it. Not yet: the `Attachable` PDF, `Bill` for
  purchases (they go as journal entries), two `TaxLine`s per GST+QST code in
  the readback (the postings carry one tax line per rate group), the
  journal CSV file target and the change webhook. The live exchange is NOT
  RUN: it needs an Intuit developer application and a sandbox company per
  country.

## What each country mandates that this app does not produce

**This table is a map of known absences, not a compliance statement.**
These regimes change on published timetables and several are mid-rollout;
confirm the current position with the workspace's own accountant before
relying on any row. What the table is for is making sure no absence is an
oversight.

Every format below marked *ledger* mandates `GeneralLedgerEntries` or its
equivalent. A space that keeps a **local book** (#2365) has those
postings, and #2379 writes them for NO and LU; each further country needs
its own profile (schema, code lists, chart map). A space without a local
book keeps invoices, payments and a running member account, not a
double-entry ledger (ADR 0022), and no exporting closes that.

| country | obligation we do not meet | why |
|---|---|---|
| DE | GoBD handover of the COMPLETE books for a Betriebsprüfung | ledger; the GoBD export (#2375) hands over DesKilo's sub-ledger in the descriptor-file form and says so |
| AT | §§131/132 BAO data provision | ledger; no profile yet |
| PT | SAF-T accounting variants (`TaxAccountingBasis` C / I); certified-software obligation above the threshold | ledger; certification is a separate obligation the file cannot satisfy |
| NO | SAF-T Financial on demand, for a space without a local book | ledger; with one, `saft_no` (#2379) |
| LU | FAIA, for a space without a local book | ledger; with one, `faia_lu` (#2379) |
| PL | JPK_KR (books) | ledger; no profile yet (JPK_KR_PD schema and chart segments) |
| RO | SAF-T D406 | ledger; no profile yet |
| LT | i.SAF / SAF-T | ledger; no profile yet |
| BG | SAF-T (phased introduction) | ledger |
| ES | SII, and the certified-billing-software regime | real-time reporting and certification, not a file |
| IT | FatturaPA through SdI | e-invoicing transport — see below |
| HU | Online Számla real-time invoice reporting | real-time reporting |
| GR | myDATA | real-time reporting |
| DK | digital bookkeeping act, registered systems | system registration, not a file: the export sheet says so and names the two routes (a registered system such as e-conomic, Dinero or Billy; its SAF-T DK standard export); `denmark_registered_system`, `saft_dk` and the three systems are decided targets, none reachable (#2379) |
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
- every DATEV row has 125 fields, a positive amount, an `S` flag, a
  four-digit `Belegdatum`, and never posts an account against itself;
- the two files reconcile on revenue;
- a file for one fiscal year holds that year's invoices, ledger entries and repartitions only, and the export screen cuts them before DATEV, whose Belegdatum has no year, can re-date them (#2365);
- every SAF-T ledger transaction balances, credit notes included, and its header totals are the sums of its lines (#2365);
- a ledger expense netted on an invoice is booked once (purchases), never also as money in on the bank (#2365);
- every supported country is offered something, and `regulatory` is
  claimed only for FR, PT, NO and LU, never for DK;
- `saf_t_financial_test.dart` (#2379), over the seeded year with a fiscal
  year from 1 April: debits equal credits and the stated totals, every
  transaction balances and names its source document, the customers are
  the sub-ledger numbers, each account closes at its opening plus the year,
  each tax line's code is in the dated tax table; an unmapped account or
  tax code, a missing contact, telephone, party or postal address is named.
  `tool/saft/validate.sh` reads its samples against the shipped schemas.
