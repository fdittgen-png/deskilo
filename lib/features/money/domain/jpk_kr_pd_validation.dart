// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — Refuse the Polish profile unless its mandatory source facts are
// explicit. XSD conformance does not establish statutory completeness.
import '../../../core/time/date_text.dart';
import 'fiscal_year.dart';
import 'jpk_kr_pd_countries.dart';
import 'jpk_kr_pd_facts.dart';
import 'jpk_kr_pd_gap.dart';
import 'jpk_kr_pd_limits.dart';
import 'jpk_kr_pd_markers.dart';
import 'jpk_kr_pd_offices.dart';
import 'posting.dart';

class JpkKrPdRequest {
  const JpkKrPdRequest({
    required this.period,
    required this.opening,
    required this.postings,
    required this.accountNames,
    this.parties = const {},
    required this.currency,
    required this.createdAt,
    this.facts,
  });
  final FiscalYear period;
  final List<Posting> opening;
  final List<Posting> postings;
  final Map<String, String> accountNames;
  final Map<String, PostingParty> parties;
  final String currency;
  final DateTime createdAt;
  final JpkKrPdFacts? facts;
}

/// Every returned gap names a missing or contradictory source fact.
List<JpkKrPdGap> jpkKrPdGaps(JpkKrPdRequest r) {
  final gaps = <JpkKrPdGap>{};
  void gap(JpkKrPdGapCode code, {JpkKrPdField? field, String subject = '', int limit = 0}) =>
      gaps.add(JpkKrPdGap(code, field: field, subject: subject, limit: limit));
  if (r.currency.trim().toUpperCase() != 'PLN') {
    gap(JpkKrPdGapCode.currencyNotPln);
  }
  if (r.postings.isEmpty) gap(JpkKrPdGapCode.noPostings);
  if (r.period.to.isBefore(r.period.from)) gap(JpkKrPdGapCode.invalidYear);
  final facts = r.facts;
  if (facts == null) {
    return [...gaps, ..._missingFactSections];
  }
  void needFact(JpkKrPdField field, String value, [String subject = '']) {
    if (value.trim().isEmpty) gap(JpkKrPdGapCode.missing, field: field, subject: subject);
  }

  if (!facts.journalSequenceVerified) {
    gap(JpkKrPdGapCode.journalSequenceUnverified);
  }
  if (facts.taxYear.to.isBefore(facts.taxYear.from)) {
    gap(JpkKrPdGapCode.taxYear);
  }
  if (!facts.otherEntityCategory) {
    gap(JpkKrPdGapCode.entityCategory);
  }
  if (facts.addressCountry != 'PL') {
    gap(JpkKrPdGapCode.addressCountry);
  }
  needFact(JpkKrPdField.nip, facts.nip);
  if (!RegExp(r'^[1-9]((\d[1-9])|([1-9]\d))\d{7}$').hasMatch(facts.nip)) {
    gap(JpkKrPdGapCode.nipFormat);
  }
  needFact(JpkKrPdField.legalName, facts.legalName);
  needFact(JpkKrPdField.voivodeship, facts.voivodeship);
  needFact(JpkKrPdField.county, facts.county);
  needFact(JpkKrPdField.municipality, facts.municipality);
  needFact(JpkKrPdField.buildingNumber, facts.buildingNumber);
  needFact(JpkKrPdField.city, facts.city);
  needFact(JpkKrPdField.postalCode, facts.postalCode);
  needFact(JpkKrPdField.taxOfficeCode, facts.taxOfficeCode);
  gaps.addAll(_addressLengthGaps(facts));
  if (!jpkKrPdOffices.contains(facts.taxOfficeCode)) {
    gap(JpkKrPdGapCode.invalidOffice);
  }
  if (facts.submissionPurpose != 1 && facts.submissionPurpose != 2) {
    gap(JpkKrPdGapCode.purpose);
  }
  if (facts.incomeTaxAdjustments.length != 8 ||
      facts.incomeTaxAdjustments.any((amount) => amount.currency != 'PLN')) {
    gap(JpkKrPdGapCode.reconciliation);
  }
  final accounts = <String>{...r.accountNames.keys};
  for (final posting in r.opening) {
    if (isoDay(posting.date).compareTo(isoDay(r.period.from)) >= 0) {
      gap(JpkKrPdGapCode.openingOutside, subject: posting.documentNumber);
    }
  }
  for (final posting in [...r.opening, ...r.postings]) {
    final debit = posting.lines.fold(
      BigInt.zero,
      (n, line) => n + BigInt.from(line.debit.minor),
    );
    final credit = posting.lines.fold(
      BigInt.zero,
      (n, line) => n + BigInt.from(line.credit.minor),
    );
    if (posting.lines.isEmpty || debit != credit) {
      gap(JpkKrPdGapCode.unbalanced, subject: posting.documentNumber);
    }
    for (final line in posting.lines) {
      accounts.add(line.accountCode);
      if (line.debit.minor < 0 ||
          line.credit.minor < 0 ||
          ((line.debit.minor == 0) == (line.credit.minor == 0))) {
        gap(JpkKrPdGapCode.invalidDebitCredit, subject: posting.documentNumber);
      }
      if (line.original != null) {
        gap(JpkKrPdGapCode.foreignLine, subject: posting.documentNumber);
      }
      if (line.debit.currency != 'PLN' || line.credit.currency != 'PLN') {
        gap(JpkKrPdGapCode.postingCurrency, subject: posting.documentNumber);
      }
    }
  }
  for (final account in accounts) {
    needFact(JpkKrPdField.accountName, r.accountNames[account] ?? '', account);
    if (account.length > jpkKrPdTextLength ||
        (r.accountNames[account]?.length ?? 0) > jpkKrPdTextLength) {
      gap(JpkKrPdGapCode.tooLong, field: JpkKrPdField.accountIdentifier, subject: account, limit: jpkKrPdTextLength);
    }
    final detail = facts.accountFacts[account];
    if (detail != null) {
      final balances = [
        detail.openingDebit,
        detail.openingCredit,
        detail.closingDebit,
        detail.closingCredit,
      ];
      if (balances.any((v) => v.currency != 'PLN' || v.minor < 0)) {
        gap(JpkKrPdGapCode.accountBalances, subject: account);
      }
      BigInt net(Iterable<Posting> postings) {
        var value = BigInt.zero;
        for (final posting in postings) {
          for (final line in posting.lines) {
            if (line.accountCode == account) {
              value +=
                  BigInt.from(line.debit.minor) -
                  BigInt.from(line.credit.minor);
            }
          }
        }
        return value;
      }

      final opening =
          BigInt.from(detail.openingDebit.minor) -
          BigInt.from(detail.openingCredit.minor);
      final closing =
          BigInt.from(detail.closingDebit.minor) -
          BigInt.from(detail.closingCredit.minor);
      if (opening != net(r.opening)) {
        gap(JpkKrPdGapCode.openingMismatch, subject: account);
      }
      if (closing != opening + net(r.postings)) {
        gap(JpkKrPdGapCode.closingMismatch, subject: account);
      }
    }
    needFact(JpkKrPdField.accountParent, detail?.parent ?? '', account);
    if ((detail?.parent.length ?? 0) > jpkKrPdTextLength) {
      gap(JpkKrPdGapCode.tooLong, field: JpkKrPdField.accountParent, subject: account, limit: jpkKrPdTextLength);
    }
    needFact(JpkKrPdField.accountMarker, detail?.reportingMarker ?? '', account);
    if (detail != null && !jpkKrPdMarkers.contains(detail.reportingMarker)) {
      gap(JpkKrPdGapCode.invalidMarker, subject: account);
    }
  }
  if (facts.entries.length != r.postings.length) {
    gap(JpkKrPdGapCode.journalEvidence);
  }
  final maxMinor = BigInt.from(10).pow(jpkKrPdAmountDigits) - BigInt.one;
  var allDebit = BigInt.zero, allCredit = BigInt.zero;
  for (final account in accounts) {
    var debit = BigInt.zero, credit = BigInt.zero;
    for (final posting in r.postings) {
      for (final line in posting.lines) {
        if (line.accountCode == account) {
          debit += BigInt.from(line.debit.minor);
          credit += BigInt.from(line.credit.minor);
        }
      }
    }
    allDebit += debit;
    allCredit += credit;
    if (debit.abs() > maxMinor || credit.abs() > maxMinor) {
      gap(JpkKrPdGapCode.turnoverPrecision, subject: account);
    }
  }
  if (allDebit.abs() > maxMinor || allCredit.abs() > maxMinor) {
    gap(JpkKrPdGapCode.totalsPrecision);
  }
  var documentsTotal = BigInt.zero;
  for (final entry in facts.entries) {
    documentsTotal += BigInt.from(entry.documentAmount.minor);
  }
  if (documentsTotal.abs() > maxMinor) {
    gap(JpkKrPdGapCode.documentTotalPrecision);
  }
  final partyCodes = <String>{};
  final referencedPartyCodes = {
    for (final entry in facts.entries)
      if (entry.counterpartyCode != null) entry.counterpartyCode!,
  };
  for (final party in facts.counterparties) {
    if (!referencedPartyCodes.contains(party.code)) {
      gap(JpkKrPdGapCode.unreferencedCounterparty, subject: party.code);
    }
    if (party.country != null && !jpkKrPdCountries.contains(party.country)) {
      gap(JpkKrPdGapCode.invalidCounterpartyCountry, subject: party.code);
    }
    if (party.taxId != null &&
        (party.taxId!.trim().isEmpty || party.taxId!.length > jpkKrPdTaxIdLength)) {
      gap(JpkKrPdGapCode.invalidCounterpartyTaxId, subject: party.code);
    }
    if (party.code.length > jpkKrPdTextLength) {
      gap(JpkKrPdGapCode.tooLong, field: JpkKrPdField.counterpartyCode, subject: party.code, limit: jpkKrPdTextLength);
    }
    if (party.code.trim().isEmpty || !partyCodes.add(party.code)) {
      gap(JpkKrPdGapCode.counterpartyCodeInvalid);
    }
  }
  final numbers = <String>{};
  final lineNumbers = <String>{};
  for (var i = 0; i < r.postings.length && i < facts.entries.length; i++) {
    final posting = r.postings[i];
    final entry = facts.entries[i];
    final name = posting.documentNumber;
    if (entry.documentId != posting.documentId) {
      gap(JpkKrPdGapCode.journalSourceMismatch, subject: name);
    }
    if (!r.period.contains(posting.date)) {
      gap(JpkKrPdGapCode.postingOutside, subject: name);
    }
    if (!r.period.contains(entry.bookingDate)) {
      gap(JpkKrPdGapCode.bookingOutside, subject: name);
    }
    if (entry.documentAmount.currency != 'PLN') {
      gap(JpkKrPdGapCode.documentAmount, subject: name);
    }
    if (i > 0 &&
        isoDay(entry.bookingDate)
                .compareTo(isoDay(facts.entries[i - 1].bookingDate)) <
            0) {
      gap(JpkKrPdGapCode.chronology, subject: name);
    }
    needFact(JpkKrPdField.journalNumber, entry.journalNumber, name);
    if (!numbers.add('${entry.journalName}\u0000${entry.journalNumber}')) {
      gap(JpkKrPdGapCode.duplicateJournalNumber, subject: entry.journalNumber);
    }
    needFact(JpkKrPdField.journalName, entry.journalName, name);
    needFact(JpkKrPdField.documentNumber, posting.documentNumber, name);
    needFact(JpkKrPdField.documentType, entry.documentType, name);
    needFact(JpkKrPdField.responsiblePerson, entry.responsiblePerson, name);
    needFact(JpkKrPdField.journalDescription, entry.description, name);
    if (entry.lineDescriptions.length != posting.lines.length ||
        entry.lineDescriptions.any((line) => line.trim().isEmpty)) {
      gap(JpkKrPdGapCode.lineDescriptions, subject: name);
    }
    if (entry.lineNumbers.length != posting.lines.length ||
        entry.lineNumbers.any((number) => number.trim().isEmpty) ||
        entry.lineNumbers.toSet().length != entry.lineNumbers.length) {
      gap(JpkKrPdGapCode.lineNumbers, subject: name);
    }
    if (r.parties.containsKey(posting.documentId) &&
        (entry.counterpartyCode?.trim().isEmpty ?? true)) {
      gap(JpkKrPdGapCode.counterpartyCode, subject: name);
    }
    final sourceParty = r.parties[posting.documentId];
    if (sourceParty == null && entry.counterpartyCode != null) {
      gap(JpkKrPdGapCode.counterpartySourceMissing, subject: name);
    }
    if (sourceParty != null && entry.counterpartyCode != null) {
      final matching = facts.counterparties.where(
        (p) => p.code == entry.counterpartyCode,
      );
      if (matching.isNotEmpty &&
          (matching.first.sourceKind != sourceParty.kind ||
              matching.first.sourceNumber != sourceParty.number)) {
        gap(JpkKrPdGapCode.counterpartySourceMismatch, subject: name);
      }
    }
    if (entry.counterpartyCode != null &&
        !partyCodes.contains(entry.counterpartyCode)) {
      gap(JpkKrPdGapCode.counterpartyUnknown, subject: entry.counterpartyCode!);
    }
    final texts = [
      entry.journalNumber,
      entry.journalName,
      posting.documentNumber,
      entry.documentType,
      entry.responsiblePerson,
      ...entry.lineNumbers,
    ];
    gaps.addAll(_journalTextGaps(entry, texts, name));
    if (entry.ksefNumber != null &&
        entry.ksefNumber!.isNotEmpty &&
        !RegExp(
          r'^([1-9]((\d[1-9])|([1-9]\d))\d{7}|M\d{9}|[A-Z]{3}\d{7})-(20[2-9][0-9]|2[1-9][0-9]{2}|[3-9][0-9]{3})(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])-([0-9A-F]{6})-?([0-9A-F]{6})-([0-9A-F]{2})$',
        ).hasMatch(entry.ksefNumber!)) {
      gap(JpkKrPdGapCode.invalidKsef, subject: name);
    }
    for (final lineNumber in entry.lineNumbers) {
      if (!lineNumbers.add('${entry.journalName}\u0000$lineNumber')) {
        gap(JpkKrPdGapCode.duplicateLineNumber, subject: '${entry.journalName} / $lineNumber');
      }
    }
    if (entry.ksefRequired && (entry.ksefNumber?.trim().isEmpty ?? true)) {
      gap(JpkKrPdGapCode.ksefMissing, subject: name);
    }
  }
  return List.unmodifiable(gaps);
}

/// The sections a refusal names when no Polish facts were supplied at all.
const _missingFactSections = <JpkKrPdGap>[
  JpkKrPdGap(JpkKrPdGapCode.sectionEntity),
  JpkKrPdGap(JpkKrPdGapCode.sectionOffice),
  JpkKrPdGap(JpkKrPdGapCode.sectionAccounts),
  JpkKrPdGap(JpkKrPdGapCode.sectionJournal),
  JpkKrPdGap(JpkKrPdGapCode.sectionSource),
  JpkKrPdGap(JpkKrPdGapCode.sectionKsef),
  JpkKrPdGap(JpkKrPdGapCode.sectionReconciliation),
];

/// The entity fields longer than the schema allows (never cut).
Iterable<JpkKrPdGap> _addressLengthGaps(JpkKrPdFacts facts) sync* {
  for (final (field, value, limit) in <(JpkKrPdField, String, int)>[
    (JpkKrPdField.legalName, facts.legalName, jpkKrPdLegalNameLength),
    (JpkKrPdField.voivodeship, facts.voivodeship, jpkKrPdAdminUnitLength),
    (JpkKrPdField.county, facts.county, jpkKrPdAdminUnitLength),
    (JpkKrPdField.municipality, facts.municipality, jpkKrPdAdminUnitLength),
    (
      JpkKrPdField.buildingNumber,
      facts.buildingNumber,
      jpkKrPdBuildingNumberLength,
    ),
    (JpkKrPdField.city, facts.city, jpkKrPdCityLength),
    (JpkKrPdField.postalCode, facts.postalCode, jpkKrPdPostalCodeLength),
    (JpkKrPdField.street, facts.street, jpkKrPdStreetLength),
  ]) {
    if (value.length > limit) {
      yield JpkKrPdGap(JpkKrPdGapCode.tooLong, field: field, limit: limit);
    }
  }
}

/// The journal identifiers and descriptions of [entry] longer than the schema.
Iterable<JpkKrPdGap> _journalTextGaps(
  JpkEntryFact entry,
  List<String> texts,
  String name,
) sync* {
  if (texts.any((value) => value.length > jpkKrPdTextLength)) {
    yield JpkKrPdGap(
      JpkKrPdGapCode.tooLong,
      field: JpkKrPdField.journalText,
      subject: name,
      limit: jpkKrPdTextLength,
    );
  }
  if (entry.description.length > jpkKrPdLongTextLength ||
      entry.lineDescriptions.any((v) => v.length > jpkKrPdLongTextLength)) {
    yield JpkKrPdGap(
      JpkKrPdGapCode.tooLong,
      field: JpkKrPdField.journalDescription,
      subject: name,
      limit: jpkKrPdLongTextLength,
    );
  }
}
