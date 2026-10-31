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
| Sage 50 audit trail | exchange | GB | #2373: the 18 columns of Sage 50's template (`Type` … `Fund`), CRLF, DD/MM/YYYY, Exchange Rate 1, Extra Reference the row's month; for a local book written from its postings on the book's chart (SI/SC one row per revenue line with its tax, SR/SP the bank line, PI/PC per expense line with its recoverable input tax, PP, every other event one JD/JC per line at T9), otherwise from the documents on the nominal codes confirmed at export (SI/SC per VAT breakdown line, SR/SP, a written-off rest JD 8100 / JC 1100); the code of each rate line from its rate group (`sage/tax_*` rows: T1 standard, T5 reduced, T0 zero, T2 exempt, T9 out of scope) or, untaxed, its category (T22 a service to a business in another EU member state, with its Country of VAT, `sage/tax_eu_services`; T20 a domestic reverse charge, `sage/tax_reverse_charge`; goods to another member state (K) have no code: the app sells none); the Account Reference the member or supplier number in capitals without separators, at most 8; refused, every reason named and nothing written: a party without such a number, output tax waiting on `vat_pending`, an amount in another currency than the base currency, a rate group Sage has no code for (or untaxed lines of several categories), a Reference over 30 or a nominal code over 8 characters. Details are cut at 60. Department `0` (sites carry no number yet). Two consequences of T9 the accountant re-codes in Sage: an untaxed supplier bill line (a zero-rated purchase among them) lands on T9, not T0, because the posting names no treatment; and a member's receipt and its reimbursement are journals (JD/JC at T9), so their recoverable input VAT never reaches Sage's VAT return. Offered in Great Britain only: the `sage/*` rows are the UK product's code table; the Irish rows are a follow-up of #2373. |
| Swiss booking journal (`ch_kmu`) | exchange | CH | a local book's postings (#2377), one row per leg pair on the issuer's KMU chart, the tax line folded into its base: gross amount, MWST code of the rate group (`account_map` `ch_kmu/tax:<group>`, `input:<group>`, `asset:<group>`; refused with the group named while none exists), the VAT amount and account, the Ziffer of the MWST-Abrechnung read from the effective method's form (303/313/343, 220/221/230, 400/405); the QR reference (QRR or SCOR) of a receivable's invoice; a converted line's original amount and currency; the customer or supplier number; UTF-8 BOM, `;`, `dd.MM.yyyy`, CRLF. No local book, no journal; an unmapped role is named. |
| Banana Accounting+ transactions (`banana_transactions`) | exchange | CH | the same rows under Banana's column names (`Date, Doc, Description, AccountDebit, AccountCredit, Amount, VatCode`), tab separated, ISO dates, the amount gross: Banana splits the tax by the VatCode, which must be a code of the Banana file's VAT table |
| SAF-T Financial (NO) | regulatory | NO | #2379, a local book's postings only: valid against Skatteetaten's `Norwegian_SAF-T_Financial_Schema_v_1.30.xsd` (shipped under `test/fixtures/saft/`, read in CI by `tool/saft/validate.sh`); every account with its opening and closing balance of the fiscal year, its GroupingCategory and GroupingCode from the `saf_t/<role>` row of NO; customers and suppliers by their sub-ledger numbers with a BalanceAccount per collective account; the tax table with each rate version in force and its StandardTaxCode from the `saf_t/tax:<direction>:<group>` row; one transaction per posting, every line naming its SourceDocumentID, TaxInformation on the tax lines. An account or tax code without its row, a missing company or contact field, a party without its number, or an identifier longer than the schema allows refuses the file and is named. |
| FAIA (LU) | regulatory | LU | #2379, the same tree to the FAIA 2.01 schema (`FAIA_v_2.01_full.xsd`): StandardAccountID from the `saf_t/<role>` row of LU, the contact's telephone and every party's postal address required (refused, named, otherwise), one AccountID per party. |
| SAF-T with the general ledger | exchange | everywhere | #2379, the same tree in the OECD 2.0 namespace without national restriction; the OECD publishes its XSD only inside its 2010 guidance, so the file is read against Luxembourg's publication of the same tree. |
| SAF-T, invoicing subset | subset | everywhere | `GeneralLedgerEntries` omitted unless the owner maps accounts; then sales cycle only, every transaction balances, credit notes reverse the sale, netted cash is posted, a written-off rest to the mapped loss account, in the sales journal (none mapped, none posted) |
| Accountant CSV | exchange | everywhere | format 3 (#2378): `tax_components` holds each invoice's taxes as frozen at issue (JSON, integer minor units; a total stored without components is marked `"split": false`), then one column per tax key of the period — `GST`, `HST`, `QST`, `PST` (Canada), `state_tax` / `local_tax` (US sales tax), `VAT <rate>` (an un-split total) — each the sum of its components; its `report.json` quotes the year's Transfers list (#2378: every file with its sha256 and the documents it carried, every connection delivery with its digest and status) while the accounting systems are on |
| Audit trail | exchange | everywhere | called a trail, never an "audit file"; write-offs are events, a credit note shows its signed value |
| Archive bundle | exchange | everywhere | a fiscal year as one zip; `vat-account.csv` (#2378, the VAT account of UK VAT Regulations 1995 reg. 32) when the year has prepared or filed returns: per period output and input tax, corrections of earlier periods apart, payable = box 1 and allowable = box 4 of the return; `manifest.csv` (#2377) names every member with its SHA-256 and size, and the downloaded archive is logged with its digest, the server's time and the person who made it; a Swiss archive carries `verfahrensdokumentation.md` (GeBüV art. 4); a GB, IE, CA or US archive carries the readable handover (#2378): the GoBD tables under `tables/` (no German index, no DTD) and `tables/README.txt`, which describes every table and column in English with the file format, and states where the records are kept: the country the installation's operator declared (platform setting `records.hosting_country`, never inferred; nothing declared is said as such) and, for a Canadian space not declared in Canada, the ETA s.286 / ITA s.230 rule and its CRA authorisation reference (workspace setting `records.cra_authorisation_reference`), which the accounting settings show beside the retention clocks |

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

## Switzerland (#2377)

- **Journal and Banana.** Both layouts are the postings of the local book,
  read once (the rows above). The MWST codes are Banana's standard codes of
  the Swiss VAT table, unconfirmed reference rows (format `ch_kmu`) valid
  for the 2024 rates, from 2024-01-01 to 2028-01-01, where the planned rates
  begin: a posting after that refuses its code, named, until confirmed codes
  exist. A fiduciary whose VAT table names them otherwise changes them in the
  tax reference editor. A book on collected consideration codes the sale on
  its own row; the release of its pending tax lands on the rate's Ziffer,
  uncoded, so Banana never taxes the tax again. The output tax of every rate is booked on 2200: the
  code carries the rate, the Ziffer of each row ties it to the return.
- **KMU chart.** The suggested chart maps every role the engine books: 1100,
  1020, 3400 (3401 reduced and accommodation, 3402 exempt letting), 2200,
  1170, 2000, 3805, 6500; 2201 and 6000 are offered unmapped. A role or an
  account the chart lists twice is mapped to its first account.
- **bexio.** `bexio_api` delivers through the delivery kit: an invoice as a
  `kb_invoice` with its legal number as `document_nr` and the kit's
  idempotency key as `api_reference`, positions net with the `tax_id` and
  `account_id` the connection maps, then issued; a credit note as a
  `kb_credit_voucher`; a receipt as a payment on its invoice, found by
  number. A company connects with a personal access token or by signing in
  (`auth.bexio.com`). The Accounting systems sheet says no document is sent
  yet: the delivery runner does not dispatch to the adapter. The live exchange is not run: it needs a bexio test
  company and a token or a registered app.
- **The other products.** Abacus (AbaConnect, licensed per interface), Sage 50
  Extra / Sage Start, Infoniqa ONE, Klara and Run my Accounts are catalogued
  as `specificationNeeded`; the Swiss journal is their working route.
- **GeBüV.** The Swiss archive is refused, said, while the space keeps no
  export log (neither the book periods nor the accounting systems are on): the
  log is the evidence its procedures document states. Art. 3/9: every export and the archive download (once handed out) are logged with their
  SHA-256, the server's time and the actor; the archive's manifest names
  every member's digest and each issued document carries the fingerprint the
  server verifies (`register.csv`). Art. 4: the procedures document travels in
  the Swiss archive. Art. 8: the audit trail lists every file handed out
  (`export`, `archive`) with actor and time. Art. 10: the procedures document
  names the recovery evidence of a completed workspace export (0301).
  Retention is the country's `retention` rows: ten years from the end of the
  fiscal year.

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
| `sage50` | Sage · Sage 50 Accounts · audit trail CSV | file | documents | GB | implemented | not named yet |
| `ch_kmu` | KMU-Kontenrahmen · Swiss booking journal · CSV from compute_postings, MWST code and Ziffer per row | file | journal | CH | implemented | not named yet |
| `banana_transactions` | Banana · Banana Accounting+ · import of transactions, tab-separated text | file | journal | CH | implemented | Banana Accounting+ import of transactions, column names of the Transactions table |
| `bexio_api` | bexio · bexio · API 2.0 (kb_invoice, kb_credit_voucher) | api | documents | CH | implemented | bexio API 2.0, kb_invoice and kb_credit_voucher |
| `abacus_abaconnect` | Abacus · Abacus Finanzbuchhaltung · AbaConnect XML, licensed per interface | file | journal | CH | specificationNeeded | not named yet |
| `sage50_extra_ch` | Sage · Sage 50 Extra / Sage Start (CH) · text import of Buchungen | file | journal | CH | specificationNeeded | not named yet |
| `infoniqa_one` | Infoniqa · Infoniqa ONE · API | api | documents | CH | specificationNeeded | not named yet |
| `klara` | Klara · Klara Business · API | api | documents | CH | specificationNeeded | not named yet |
| `run_my_accounts` | Run my Accounts · Run my Accounts · API | api | documents | CH | specificationNeeded | not named yet |
| `saft_no` | Skatteetaten · SAF-T Financial · 1.30 | file | journal | NO | locallyValidated | Skatteetaten SAF-T Financial 1.30, Norwegian_SAF-T_Financial_Schema_v_1.30.xsd |
| `faia_lu` | Administration de l'enregistrement · FAIA · 2.01 | file | journal | LU | locallyValidated | AED FAIA 2.01, FAIA_v_2.01_full.xsd |
| `denmark_registered_system` | Erhvervsstyrelsen · Registered digital bookkeeping system · Bogføringsloven 2022 | api | documents | DK | specificationNeeded | not named yet |
| `saft_dk` | Erhvervsstyrelsen · SAF-T DK · 2.1 | file | journal | DK | locallyValidated | Erhvervsstyrelsen SAF-T Financial 2.1, Danish_SAF-T_Financial_Schema_v_2_1.xsd |
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
| `pennylane_api` | Pennylane · Pennylane · API v2 | api | journal | FR | implemented | Pennylane API v2, ledger_entries and journals |
| `cegid_quadra_ascii` | Cegid · Quadra · ASCII import | file | journal | FR | specificationNeeded | not named yet |
| `ebp_import` | EBP · Comptabilité · import of entries | file | journal | FR | specificationNeeded | not named yet |
| `quickbooks_online_us` | Intuit · QuickBooks Online · Accounting API v3, US realm | api | documents | US | implemented | QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry |
| `quickbooks_online_ca` | Intuit · QuickBooks Online · Accounting API v3, CA realm | api | documents | CA | implemented | QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry |
| `quickbooks_online_gb` | Intuit · QuickBooks Online · Accounting API v3, GB realm | api | documents | GB | implemented | QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry |
| `sage_business_cloud_gb` | Sage · Sage Business Cloud Accounting · API v3.1, UK business | api | documents | GB | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage_business_cloud_ie` | Sage · Sage Business Cloud Accounting · API v3.1, Irish business | api | documents | IE | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage_business_cloud_ca` | Sage · Sage Business Cloud Accounting · API v3.1, Canadian business | api | documents | CA | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage_business_cloud_us` | Sage · Sage Business Cloud Accounting · API v3.1, US business | api | documents | US | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage_business_cloud_fr` | Sage · Sage Business Cloud Accounting · API v3.1, French business | api | documents | FR | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage_business_cloud_de` | Sage · Sage Business Cloud Accounting · API v3.1, German business | api | documents | DE | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage_business_cloud_es` | Sage · Sage Business Cloud Accounting · API v3.1, Spanish business | api | documents | ES | implemented | Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals |
| `sage100_fr` | Sage · Sage 100 Comptabilité · import of the FEC | file | journal | FR | implemented | imports the FEC (target fec): DGFiP fichiers standards des écritures comptables |
| `sage50_fr` | Sage · Sage 50 (ex Ciel Compta) · import of the FEC | file | journal | FR | implemented | imports the FEC (target fec): DGFiP fichiers standards des écritures comptables |
| `sage_de` | Sage · Sage 50 / Sage 100 (KHK, Office Line) · import of a DATEV EXTF Buchungsstapel | file | journal | AT, DE | implemented | imports DATEV (target datev): EXTF 700 Buchungsstapel |
| `sage50_ca` | Sage · Sage 50 Accounting (Canada) · .IMP sales invoices and general journal | file | documents | CA | specificationNeeded | not named yet |
| `sage200` | Sage · Sage 200 · import of transactions | file | journal | GB, IE | specificationNeeded | not named yet |
| `sage_intacct` | Sage · Sage Intacct · journal import templates and XML API | api | journal | CA, GB, US | specificationNeeded | not named yet |
| `xero_gb` | Xero · Xero · Accounting API 2.0, UK organisation | api | documents | GB | implemented | Xero Accounting API 2.0: Invoices ACCREC, CreditNotes ACCRECCREDIT with Allocations, Payments, ManualJournals, TaxRates |
| `xero_ca` | Xero · Xero · Accounting API 2.0, Canadian organisation | api | documents | CA | implemented | Xero Accounting API 2.0: Invoices ACCREC, CreditNotes ACCRECCREDIT with Allocations, Payments, ManualJournals, TaxRates |
| `xero_us` | Xero · Xero · Accounting API 2.0, US organisation | api | documents | US | implemented | Xero Accounting API 2.0: Invoices ACCREC, CreditNotes ACCRECCREDIT with Allocations, Payments, ManualJournals, TaxRates |
| `xero_eu` | Xero · Xero · Accounting API 2.0, EU organisation | api | documents | EU members | implemented | Xero Accounting API 2.0: Invoices ACCREC, CreditNotes ACCRECCREDIT with Allocations, Payments, ManualJournals, TaxRates |
| `business_central_de` | Microsoft · Dynamics 365 Business Central · API v2.0, German localisation | api | documents | DE | implemented | Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups |
| `business_central_fr` | Microsoft · Dynamics 365 Business Central · API v2.0, French localisation | api | documents | FR | implemented | Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups |
| `business_central_ch` | Microsoft · Dynamics 365 Business Central · API v2.0, Swiss localisation | api | documents | CH | implemented | Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups |
| `business_central_gb` | Microsoft · Dynamics 365 Business Central · API v2.0, UK localisation | api | documents | GB | implemented | Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups |
| `business_central_us` | Microsoft · Dynamics 365 Business Central · API v2.0, US localisation | api | documents | US | implemented | Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups |
| `business_central_ca` | Microsoft · Dynamics 365 Business Central · API v2.0, Canadian localisation | api | documents | CA | implemented | Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups |
<!-- END GENERATED TARGETS -->

Write-offs are posted **gross**, as a loss, on the day they were given up:
the VAT correction (bad debt relief, e.g. art. 272 CGI, §17 UStG, Sage's relief
claim) has its own conditions and stays with the accountant. The loss accounts
are `account_map` rows of the tax reference store (FR 654000 confirmed; DE 2400
and GB 8100 unconfirmed until an accountant has checked the chart in use).

## Sage (#2373)

"Sage" is a family of unrelated products, so each edition is its own target
(`accounting_targets_sage.dart`):

- **Sage 50 Accounts (UK)** writes its own audit trail (`sage50`, above). Sage 50 Ireland waits for its own `sage/*` rows (IE): its rates (13.5 %, 9 %) are not the UK table's.
- **Sage Business Cloud Accounting**, one target per region
  (`sage_business_cloud_gb`, `_ie`, `_ca`, `_us`, `_fr`, `_de`, `_es`):
  signed in to (OAuth 2.0, one Sage application of the installation; the
  sign-in binds the one business it reaches) and delivered through the kit
  (`_shared/accounting_sage.ts`): an invoice as a `sales_invoice` and a credit
  note as a `sales_credit_note` with the legal number as `reference`, one line
  per revenue line on the mapped ledger account (`account revenue:<group>`)
  with the mapped tax rate (`item vat_output:<group>`) and the document's own
  tax; a credit note names the invoice it corrects (`original_invoice_id`)
  and is allocated to it; a receipt (CUSTOMER_RECEIPT) and a refund
  (CUSTOMER_REFUND) as a `contact_payment` allocated to their document on the
  bank account of the ledger account `account bank` names; every other event
  a balanced `journal`. The document a credit note, a receipt or a refund
  refers to is read first: when it is not in Sage nothing is written, not
  even a contact. The business's country and base currency, its tax rates,
  ledger accounts and bank accounts are read before a run; a document in
  another currency, deferred tax (`vat_pending`), a ledger account or tax
  rate the business does not hold, and a party number longer than Sage's
  8-character contact reference are refused by name. The live exchange is
  NOT RUN: it needs a Sage developer application and a trial business.
- **Sage 100 Comptabilité and Sage 50 (ex Ciel) in France** import the FEC
  (`sage100_fr`, `sage50_fr`); **Sage 50 / Sage 100 (KHK, Office Line) in
  Germany and Austria** import DATEV (`sage_de`). They write nothing of
  their own; the export sheet names them above the file they take.
- **Sage 50 Canada** (`sage50_ca`): the tagged `.IMP` sales-invoice import
  and the general-journal `.txt` are documented only in Sage's own knowledge
  base, so the target is `specificationNeeded` until that layout is in hand
  and a company file can import a fixture. **Sage 200** and **Sage Intacct**
  are `specificationNeeded` too.

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
nothing either. An OAuth token expiring within one function budget is
refreshed before the run, and the adapter is given that token only. A
delivery prepared before (an earlier run, or one running now) is read back
before any create. A receipt or a refund is delivered under a name-based id of
its invoice, day, amount and rank among equal ones of that day, so two
payments of one invoice on one day are two deliveries. A year asked month by
month that stops in one month names it and what the months before delivered. The
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
  (`TxnTaxCodeRef` = the `item vat_output:<group>` mapping); a CA or GB
  line carries the realm tax code its rate group is mapped to
  (`item vat_output:<group>`, a zero-rated group too). The tax code is an
  `item` mapping because `account vat_output:<group>` is the tax account a
  journal entry's tax line posts to, and a `tax` mapping is keyed by a tax
  component while the postings carry rate groups. The total and tax
  QuickBooks books are compared with the document: a difference, a
  `SyncToken` other than the first (an edit in QuickBooks) or the number
  held by a document DesKilo did not deliver is a `conflict`; nothing is
  ever updated or created over it. Not yet: the `Attachable` PDF, `Bill` for
  purchases (they go as journal entries), two `TaxLine`s per GST+QST code in
  the readback (the postings carry one tax line per rate group), the
  journal CSV file target and the change webhook. The live exchange is NOT
  RUN: it needs an Intuit developer application and a sandbox company per
  country.
- `xero_gb`, `xero_ca`, `xero_us`, `xero_eu` (`accounting_xero.ts`,
  `xeroAccounting`, #2372): signed in to the installation's Xero application.
  The redirect names no organisation: the one the sign-in authorised is read
  from `GET /connections` by the access token's `authentication_event_id`;
  none or several are refused, and a connection signed in again keeps its
  organisation. Every call names it (`xero-tenant-id`). Before a run and
  after the sign-in `Organisation.CountryCode` must be the target's (GB, CA,
  US; for `xero_eu` an EU member state of the tax reference,
  `is_eu_country`), and the organisation's `TaxRates` and `Accounts` are
  read. An invoice is an `ACCREC` invoice, a credit note an `ACCRECCREDIT`
  credit note: the legal number as `InvoiceNumber`/`CreditNoteNumber`, the
  period as `Reference`, `LineAmountTypes Exclusive`, `Status AUTHORISED`,
  one line per revenue line on the `account` mapping of its role with the
  `TaxType` of the `item vat_output:<group>` mapping and the document's tax
  of that group as `TaxAmount`; the contact is found by `ContactNumber` (the
  member number) or created as "name (number)". A credit note is then
  allocated to the invoice it corrects (`replaces_number`, read as the
  caller) for what that invoice still owes. A receipt is a `Payment` against
  the invoice of its number on a bank account or one that takes payments;
  every other event a balanced `POSTED` manual journal. Every write is a PUT
  (Xero's PUT only creates) with `Idempotency-Key`; a payment carries the
  key in `Reference`, a journal in `Narration`. A mapped `TaxType` the
  organisation does not hold, or one its account's class does not admit
  (`CanApplyTo<Class>`), fails the document with the key named before
  anything is sent. The readback compares `Total`, `TotalTax` and
  `AmountDue`/`RemainingCredit`; a different amount, a draft, a number held
  for another contact or an unallocated credit note after a lost answer is
  a `conflict`. `AUTHORISED` is decided, not configured: the app's document
  is issued, and a Xero draft is not a posted sale (the drafts route is the
  sales-invoice CSV template, still to come). A call refused for Xero's call
  limits (429) stops the run's remaining calls; the next run continues. A
  document in another currency than the organisation's `BaseCurrency` is
  refused (Xero would put its own day rate in place of the document's), and
  so is one with tax due on receipt (`vat_pending` carries no rate group to
  put on a line). A credit note whose invoice is not in Xero yet is refused
  before anything is created. One organisation keeps one workspace's books:
  the contact is the member number alone. Not
  yet: the PDF as an attachment (no server copy of the PDF), the contact's
  `TaxNumber` (the parties carry none), `ACCPAY` bills (purchases go as
  manual journals), `TrackingCategories` for the site, batches of 50, the
  change webhook and the `xero_invoice_csv` file target. The live exchange
  is NOT RUN: it needs a Xero developer application and a demo organisation
  per region.
- `business_central_de`, `_fr`, `_ch`, `_gb`, `_us`, `_ca`
  (`accounting_business_central.ts`, `businessCentral`, #2374): Microsoft
  Dynamics 365 Business Central API v2.0, one target per localisation. The
  connection is a token connection: the company's administrator registers a
  Microsoft Entra application for the tenant, adds it in Business Central
  under *Microsoft Entra Applications* with a permission set limited to
  sales documents, customer payments and journals, and the billing manager
  enters its client id and secret (kept as one Vault secret,
  `client-id:secret`) with the company as `tenant/environment/company id`
  (`business_central_connection.dart`; the adapter's `COMPANY_ADDRESS`). A
  token is asked for each run with those client credentials
  (`client_credentials`, scope `https://api.businesscentral.dynamics.com/.default`).
  The company is named by its id, never by its name, and an environment
  (production or a sandbox) is its own connection; the remote company cannot
  change once the connection delivered (`set_accounting_token_v1`, DKA02).
  Before a run the company must exist in the environment, its
  `companyInformation.countryRegionCode` must be the target's localisation
  and its `currencyCode` names the only currency sent; its `accounts`,
  `bankAccounts`, `taxGroups`, `journals` and `customerPaymentJournals` are
  read. An invoice is a `salesInvoice`, a credit note a `salesCreditMemo`
  (one deep insert with its lines): `externalDocumentNumber` = the legal
  number, one `Account` line per revenue line on the `account
  revenue:<group>` mapping, net, with the `taxCode` of the `item
  vat_output:<group>` mapping (the VAT product posting group, or the tax
  group in the US and Canada); the customer is found by `number` (the member
  number, at most 20 characters) or created, never in the US or Canada where
  its tax area is the localisation's. A credit memo names its posted
  invoice (`invoiceId`). A receipt is a `customerPayment` applied to the
  posted invoice (`appliesToInvoiceId`) in the customer payment journal of
  the posting's journal code (BQ); every other event balanced `journalLines`
  (one `$batch` with `Isolation: snapshot`) in the general journal of the
  posting's code (OD, BQ, HA), a customer's or supplier's line on the
  `Customer`/`Vendor` of the party's number, the bank's on the bank account
  `account bank` names. A payment and a journal carry `DK` + the start of
  the idempotency key as `documentNumber`, by which the journal (before
  posting) and the G/L entries (after) are read back. **Draft and post are
  two steps** (the kit's step 5): a create is a draft whose id and ETag are
  recorded `sent`; it is then posted (`Microsoft.NAV.post`, `If-Match` the
  ETag; `postAndSend` is never called). The application's permission set is
  the allowance: a refused post leaves the delivery `sent` with its draft,
  never acknowledged, and the next run posts the same draft; a post with no
  answer is read back by the legal number, never created again; a draft
  whose ETag changed since its delivery is a `conflict` and is not posted. A
  journal is posted whole, so one holding lines this delivery did not write
  is refused. Business Central's read-back totals (`totalAmountExcludingTax`,
  `totalTaxAmount`, `totalAmountIncludingTax`) must equal the document's to
  the cent, otherwise `conflict` and the draft stays unposted; a credit memo
  that was not applied, or still owes beside an invoice that still owes, is
  a `conflict`. A number held for another customer is a `conflict`. Refused
  by name before anything is sent: another currency, deferred tax
  (`vat_pending`), a tax code or account the company does not hold, an
  external number over 35 or a customer number over 20 characters, a credit
  note or receipt whose invoice is not posted. Not yet: the PDF as an
  attachment, dimensions for the site, Dynamics 365 Finance (another
  product) and the General Journal "Edit in Excel" file target
  `business_central_journal_xlsx`. The live exchange is NOT RUN: it needs an
  Entra application registration and a Business Central sandbox per
  localisation (DE, FR, GB, US first).

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
