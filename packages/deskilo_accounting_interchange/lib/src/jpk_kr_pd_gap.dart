// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3380 — what the Polish profile refuses, as data. A gap is a code, the
// schema field it is about, the thing it names (a document or an account) and
// the limit where there is one; the presentation words it through the ARB
// catalogue in every language. No sentence is built here.

/// The schema field a gap is about.
enum JpkKrPdField {
  nip,
  legalName,
  voivodeship,
  county,
  municipality,
  buildingNumber,
  city,
  postalCode,
  street,
  taxOfficeCode,
  accountName,
  accountParent,
  accountMarker,
  journalNumber,
  journalName,
  documentNumber,
  documentType,
  responsiblePerson,
  journalDescription,
  accountIdentifier,
  journalText,
  counterpartyCode,
}

/// Why the Polish profile refuses. The ARB message `jpkKrPdGap` has one
/// branch per value.
enum JpkKrPdGapCode {
  currencyNotPln,
  noPostings,
  invalidYear,
  sectionEntity,
  sectionOffice,
  sectionAccounts,
  sectionJournal,
  sectionSource,
  sectionKsef,
  sectionReconciliation,
  journalSequenceUnverified,
  taxYear,
  entityCategory,
  addressCountry,
  nipFormat,
  missing,
  tooLong,
  invalidOffice,
  purpose,
  reconciliation,
  openingOutside,
  unbalanced,
  invalidDebitCredit,
  foreignLine,
  postingCurrency,
  accountBalances,
  openingMismatch,
  closingMismatch,
  invalidMarker,
  journalEvidence,
  turnoverPrecision,
  totalsPrecision,
  documentTotalPrecision,
  unreferencedCounterparty,
  invalidCounterpartyCountry,
  invalidCounterpartyTaxId,
  counterpartyCodeInvalid,
  journalSourceMismatch,
  postingOutside,
  bookingOutside,
  documentAmount,
  chronology,
  duplicateJournalNumber,
  lineDescriptions,
  lineNumbers,
  counterpartyCode,
  counterpartySourceMissing,
  counterpartySourceMismatch,
  counterpartyUnknown,
  invalidKsef,
  duplicateLineNumber,
  ksefMissing,
}

/// One refusal. Value equality, so a gap found twice is one gap.
final class JpkKrPdGap {
  const JpkKrPdGap(this.code, {this.field, this.subject = '', this.limit = 0});

  final JpkKrPdGapCode code;

  /// The schema field, when the gap is about one.
  final JpkKrPdField? field;

  /// What it names: a document number, an account code, a counterparty.
  final String subject;

  /// The schema's maximum, for [JpkKrPdGapCode.tooLong]; otherwise 0.
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is JpkKrPdGap &&
      other.code == code &&
      other.field == field &&
      other.subject == subject &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(code, field, subject, limit);

  @override
  String toString() => 'JpkKrPdGap($code, $field, $subject, $limit)';
}
