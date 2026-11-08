// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — supplementary JPK_KR_PD facts the frozen posting model does not
// carry. These are supplied, never inferred from an export operator, an
// account number, or a zero-valued tax reconciliation.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// A chart account's explicit Polish reporting classification.
class JpkAccountFact {
  const JpkAccountFact({
    required this.parent,
    required this.reportingMarker,
    required this.openingDebit,
    required this.openingCredit,
    required this.closingDebit,
    required this.closingCredit,
  });
  final String parent;
  final String reportingMarker;

  /// Source-book debit and credit balances, not guessed from a net.
  final AccountingAmount openingDebit;
  final AccountingAmount openingCredit;
  final AccountingAmount closingDebit;
  final AccountingAmount closingCredit;
}

/// The source-book evidence for one posting, in the same order as postings.
class JpkEntryFact {
  const JpkEntryFact({
    required this.documentId,
    required this.journalNumber,
    required this.journalName,
    required this.documentType,
    required this.eventDate,
    required this.documentDate,
    required this.bookingDate,
    required this.documentAmount,
    required this.responsiblePerson,
    required this.description,
    required this.lineDescriptions,
    required this.lineNumbers,
    required this.ksefRequired,
    this.ksefNumber,
    this.counterpartyCode,
  });
  final String documentId;
  final String journalNumber;
  final String journalName;
  final String documentType;
  final DateTime eventDate;
  final DateTime documentDate;

  /// The source-book entry date, not inferred from the transaction date.
  final DateTime bookingDate;

  /// The amount shown on the source accounting evidence.
  final AccountingAmount documentAmount;
  final String responsiblePerson;
  final String description;
  final List<String> lineDescriptions;
  final List<String> lineNumbers;
  final bool ksefRequired;
  final String? ksefNumber;
  final String? counterpartyCode;
}

class JpkCounterpartyFact {
  const JpkCounterpartyFact({
    required this.code,
    required this.sourceKind,
    required this.sourceNumber,
    this.country,
    this.taxId,
  });
  final String code;
  final String sourceKind;
  final String sourceNumber;
  final String? country;
  final String? taxId;
}

/// Explicit identity, location, chart and income-tax reconciliation facts.
/// No field defaults to a fabricated value; absent data is a named refusal.
class JpkKrPdFacts {
  const JpkKrPdFacts({
    required this.otherEntityCategory,
    required this.journalSequenceVerified,
    required this.taxYear,
    required this.addressCountry,
    required this.nip,
    required this.legalName,
    required this.voivodeship,
    required this.county,
    required this.municipality,
    required this.buildingNumber,
    required this.city,
    required this.postalCode,
    required this.taxOfficeCode,
    required this.submissionPurpose,
    required this.accountFacts,
    required this.entries,
    required this.counterparties,
    required this.incomeTaxAdjustments,
    this.street = '',
  });

  /// The declared ZOiS7 entity category; other categories are unsupported.
  final bool otherEntityCategory;

  /// A source-book confirmation, never inferred from sorted postings.
  final bool journalSequenceVerified;
  final FiscalYear taxYear;

  /// This writer currently supports only a verified Polish address.
  final String addressCountry;
  final String nip;
  final String legalName;
  final String voivodeship;
  final String county;
  final String municipality;
  final String buildingNumber;
  final String city;
  final String postalCode;
  final String taxOfficeCode;
  final int submissionPurpose;
  final Map<String, JpkAccountFact> accountFacts;
  final List<JpkEntryFact> entries;
  final List<JpkCounterpartyFact> counterparties;

  /// K_1 through K_8, explicit PLN values in schema order.
  final List<AccountingAmount> incomeTaxAdjustments;
  final String street;
}
