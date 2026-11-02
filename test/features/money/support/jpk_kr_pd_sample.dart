// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic Polish fixture facts; never real taxpayer data.
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_facts.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_validation.dart';
import 'package:deskilo/features/money/domain/posting.dart';

final jpkSampleDay = DateTime.utc(2026);
final jpkSamplePosting = Posting(
  journal: PostingJournal.sales,
  date: jpkSampleDay,
  kind: PostingKind.invoice,
  documentId: 'doc',
  documentNumber: 'INV-1',
  lines: [
    PostingLine(
      role: BookRole.customers,
      accountCode: '100',
      debit: AccountingAmount('PLN', 100),
      credit: AccountingAmount('PLN', 0),
    ),
    PostingLine(
      role: BookRole.revenue,
      accountCode: '200',
      debit: AccountingAmount('PLN', 0),
      credit: AccountingAmount('PLN', 100),
    ),
  ],
);

JpkKrPdFacts jpkSampleFacts({
  String responsible = 'Auditor',
  String marker = 'INNE',
  bool ksefRequired = false,
  int documentMinor = 100,
  int closingDebitMinor = 100,
  bool journalSequenceVerified = true,
  String entryDocumentId = 'doc',
  String taxOfficeCode = '0202',
  List<String> lineNumbers = const ['1', '2'],
  String? counterpartyCode,
  List<JpkCounterpartyFact> counterparties = const [],
}) => JpkKrPdFacts(
  otherEntityCategory: true,
  journalSequenceVerified: journalSequenceVerified,
  taxYear: FiscalYear.calendar(2026),
  addressCountry: 'PL',
  nip: '1234563218',
  legalName: 'Synthetic company',
  voivodeship: 'Mazowieckie',
  county: 'Warszawa',
  municipality: 'Warszawa',
  buildingNumber: '1',
  city: 'Warszawa',
  postalCode: '00-001',
  taxOfficeCode: taxOfficeCode,
  submissionPurpose: 1,
  accountFacts: {
    '100': JpkAccountFact(
      parent: '1',
      reportingMarker: marker,
      openingDebit: AccountingAmount('PLN', 0),
      openingCredit: AccountingAmount('PLN', 0),
      closingDebit: AccountingAmount('PLN', closingDebitMinor),
      closingCredit: AccountingAmount('PLN', 0),
    ),
    '200': JpkAccountFact(
      parent: '2',
      reportingMarker: 'INNE',
      openingDebit: AccountingAmount('PLN', 0),
      openingCredit: AccountingAmount('PLN', 0),
      closingDebit: AccountingAmount('PLN', 0),
      closingCredit: AccountingAmount('PLN', 100),
    ),
  },
  entries: [
    JpkEntryFact(
      documentId: entryDocumentId,
      journalNumber: '1',
      journalName: 'Sales',
      documentType: 'Invoice',
      eventDate: jpkSampleDay,
      documentDate: jpkSampleDay,
      bookingDate: jpkSampleDay,
      documentAmount: AccountingAmount('PLN', documentMinor),
      responsiblePerson: responsible,
      description: 'Synthetic sale',
      lineDescriptions: const ['Receivable', 'Revenue'],
      lineNumbers: lineNumbers,
      ksefRequired: ksefRequired,
      counterpartyCode: counterpartyCode,
    ),
  ],
  counterparties: counterparties,
  incomeTaxAdjustments: List.generate(8, (_) => AccountingAmount('PLN', 0)),
);
JpkKrPdRequest jpkSampleRequest(
  JpkKrPdFacts? facts, {
  Map<String, PostingParty> parties = const {},
}) => JpkKrPdRequest(
  period: FiscalYear.calendar(2026),
  opening: const [],
  postings: [jpkSamplePosting],
  accountNames: const {'100': 'Receivable', '200': 'Revenue'},
  parties: parties,
  currency: 'PLN',
  createdAt: DateTime.utc(2026, 12, 31, 12),
  facts: facts,
);
