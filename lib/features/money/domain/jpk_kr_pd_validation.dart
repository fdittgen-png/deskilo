// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — Refuse the Polish profile unless its mandatory source facts are
// explicit. XSD conformance does not establish statutory completeness.
import '../../../core/time/date_text.dart';
import 'fiscal_year.dart';
import 'jpk_kr_pd_countries.dart';
import 'jpk_kr_pd_facts.dart';
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

/// Every returned message names a missing or contradictory source fact.
List<String> jpkKrPdGaps(JpkKrPdRequest r) {
  final gaps = <String>{};
  if (r.currency.trim().toUpperCase() != 'PLN') {
    gaps.add('Functional currency must be PLN');
  }
  if (r.postings.isEmpty) gaps.add('Dziennik requires posted entries');
  if (r.period.to.isBefore(r.period.from)) gaps.add('Invalid reporting year');
  final facts = r.facts;
  if (facts == null) {
    return [
      ...gaps,
      'Polish entity and address',
      'Tax office and submission purpose',
      'Account parent, Polish reporting markers and source balances',
      'Journal sequence and responsible person',
      'Source document and booking dates, amount and line details',
      'KSeF applicability and identifier',
      'Income-tax reconciliation K_1–K_8',
    ];
  }
  void needFact(String name, String value) {
    if (value.trim().isEmpty) gaps.add(name);
  }

  if (!facts.journalSequenceVerified) {
    gaps.add('Verified source journal sequence');
  }
  if (facts.taxYear.to.isBefore(facts.taxYear.from)) {
    gaps.add('Income-tax year');
  }
  if (!facts.otherEntityCategory) {
    gaps.add('Unsupported Polish reporting entity category');
  }
  if (facts.addressCountry != 'PL') {
    gaps.add('Unsupported Polish entity address country');
  }
  needFact('NIP', facts.nip);
  if (!RegExp(r'^[1-9]((\d[1-9])|([1-9]\d))\d{7}$').hasMatch(facts.nip)) {
    gaps.add('NIP must have 10 digits');
  }
  needFact('Legal name', facts.legalName);
  needFact('Voivodeship', facts.voivodeship);
  needFact('County', facts.county);
  needFact('Municipality', facts.municipality);
  needFact('Building number', facts.buildingNumber);
  needFact('City', facts.city);
  needFact('Postal code', facts.postalCode);
  needFact('Tax office code', facts.taxOfficeCode);
  for (final field in <(String, String, int)>[
    ('Legal name', facts.legalName, 240),
    ('Voivodeship', facts.voivodeship, 36),
    ('County', facts.county, 36),
    ('Municipality', facts.municipality, 36),
    ('Building number', facts.buildingNumber, 9),
    ('City', facts.city, 56),
    ('Postal code', facts.postalCode, 8),
    ('Street', facts.street, 65),
  ]) {
    if (field.$2.length > field.$3) {
      gaps.add('${field.$1} exceeds schema length');
    }
  }
  if (!jpkKrPdOffices.contains(facts.taxOfficeCode)) {
    gaps.add('Invalid tax office code');
  }
  if (facts.submissionPurpose != 1 && facts.submissionPurpose != 2) {
    gaps.add('Submission purpose must be 1 or 2');
  }
  if (facts.incomeTaxAdjustments.length != 8 ||
      facts.incomeTaxAdjustments.any((amount) => amount.currency != 'PLN')) {
    gaps.add('Income-tax reconciliation K_1–K_8 in PLN');
  }
  final accounts = <String>{...r.accountNames.keys};
  for (final posting in r.opening) {
    if (isoDay(posting.date).compareTo(isoDay(r.period.from)) >= 0) {
      gaps.add(
        'Opening posting outside opening period ${posting.documentNumber}',
      );
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
      gaps.add('Unbalanced posting ${posting.documentNumber}');
    }
    for (final line in posting.lines) {
      accounts.add(line.accountCode);
      if (line.debit.minor < 0 ||
          line.credit.minor < 0 ||
          ((line.debit.minor == 0) == (line.credit.minor == 0))) {
        gaps.add('Invalid debit or credit ${posting.documentNumber}');
      }
      if (line.original != null) {
        gaps.add('Foreign-currency line ${posting.documentNumber}');
      }
      if (line.debit.currency != 'PLN' || line.credit.currency != 'PLN') {
        gaps.add('Posting currency ${posting.documentNumber}');
      }
    }
  }
  for (final account in accounts) {
    needFact('Account name $account', r.accountNames[account] ?? '');
    if (account.length > 256 || (r.accountNames[account]?.length ?? 0) > 256) {
      gaps.add('Account identifier or name exceeds schema length $account');
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
        gaps.add('Account balances $account');
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
        gaps.add('Opening balance mismatch $account');
      }
      if (closing != opening + net(r.postings)) {
        gaps.add('Closing balance mismatch $account');
      }
    }
    needFact('Account parent $account', detail?.parent ?? '');
    if ((detail?.parent.length ?? 0) > 256) {
      gaps.add('Account parent exceeds schema length $account');
    }
    needFact(
      'Polish account marker $account',
      detail?.reportingMarker ?? '',
    );
    if (detail != null && !jpkKrPdMarkers.contains(detail.reportingMarker)) {
      gaps.add('Invalid Polish account marker $account');
    }
  }
  if (facts.entries.length != r.postings.length) {
    gaps.add('Journal evidence for every posting');
  }
  final maxMinor = BigInt.parse('999999999999999999');
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
      gaps.add('Account turnover exceeds schema precision $account');
    }
  }
  if (allDebit.abs() > maxMinor || allCredit.abs() > maxMinor) {
    gaps.add('Journal totals exceed schema precision');
  }
  var documentsTotal = BigInt.zero;
  for (final entry in facts.entries) {
    documentsTotal += BigInt.from(entry.documentAmount.minor);
  }
  if (documentsTotal.abs() > maxMinor) {
    gaps.add('Document total exceeds schema precision');
  }
  final partyCodes = <String>{};
  final referencedPartyCodes = {
    for (final entry in facts.entries)
      if (entry.counterpartyCode != null) entry.counterpartyCode!,
  };
  for (final party in facts.counterparties) {
    if (!referencedPartyCodes.contains(party.code)) {
      gaps.add('Unreferenced counterparty ${party.code}');
    }
    if (party.country != null && !jpkKrPdCountries.contains(party.country)) {
      gaps.add('Invalid counterparty country ${party.code}');
    }
    if (party.taxId != null &&
        (party.taxId!.trim().isEmpty || party.taxId!.length > 50)) {
      gaps.add('Invalid counterparty tax ID ${party.code}');
    }
    if (party.code.length > 256) {
      gaps.add('Counterparty code exceeds schema length');
    }
    if (party.code.trim().isEmpty || !partyCodes.add(party.code)) {
      gaps.add('Missing or duplicate counterparty code');
    }
  }
  final numbers = <String>{};
  final lineNumbers = <String>{};
  for (var i = 0; i < r.postings.length && i < facts.entries.length; i++) {
    final posting = r.postings[i];
    final entry = facts.entries[i];
    final name = posting.documentNumber;
    if (entry.documentId != posting.documentId) {
      gaps.add('Journal source mismatch $name');
    }
    if (!r.period.contains(posting.date)) {
      gaps.add('Posting outside reporting year $name');
    }
    if (!r.period.contains(entry.bookingDate)) {
      gaps.add('Booking outside reporting year $name');
    }
    if (entry.documentAmount.currency != 'PLN') {
      gaps.add('Document amount $name');
    }
    if (i > 0 &&
        isoDay(entry.bookingDate)
                .compareTo(isoDay(facts.entries[i - 1].bookingDate)) <
            0) {
      gaps.add('Journal chronology $name');
    }
    needFact('Journal number $name', entry.journalNumber);
    if (!numbers.add('${entry.journalName}\u0000${entry.journalNumber}')) {
      gaps.add('Duplicate journal number ${entry.journalNumber}');
    }
    needFact('Journal name $name', entry.journalName);
    needFact('Document number $name', posting.documentNumber);
    needFact('Document type $name', entry.documentType);
    needFact('Responsible person $name', entry.responsiblePerson);
    needFact('Journal description $name', entry.description);
    if (entry.lineDescriptions.length != posting.lines.length ||
        entry.lineDescriptions.any((line) => line.trim().isEmpty)) {
      gaps.add('Line descriptions $name');
    }
    if (entry.lineNumbers.length != posting.lines.length ||
        entry.lineNumbers.any((number) => number.trim().isEmpty) ||
        entry.lineNumbers.toSet().length != entry.lineNumbers.length) {
      gaps.add('Line numbers $name');
    }
    if (r.parties.containsKey(posting.documentId) &&
        (entry.counterpartyCode?.trim().isEmpty ?? true)) {
      gaps.add('Counterparty code $name');
    }
    final sourceParty = r.parties[posting.documentId];
    if (sourceParty == null && entry.counterpartyCode != null) {
      gaps.add('Counterparty source missing $name');
    }
    if (sourceParty != null && entry.counterpartyCode != null) {
      final matching = facts.counterparties.where(
        (p) => p.code == entry.counterpartyCode,
      );
      if (matching.isNotEmpty &&
          (matching.first.sourceKind != sourceParty.kind ||
              matching.first.sourceNumber != sourceParty.number)) {
        gaps.add('Counterparty source mismatch $name');
      }
    }
    if (entry.counterpartyCode != null &&
        !partyCodes.contains(entry.counterpartyCode)) {
      gaps.add('Counterparty ${entry.counterpartyCode}');
    }
    final texts = [
      entry.journalNumber,
      entry.journalName,
      posting.documentNumber,
      entry.documentType,
      entry.responsiblePerson,
      ...entry.lineNumbers,
    ];
    if (texts.any((value) => value.length > 256) ||
        entry.description.length > 512 ||
        entry.lineDescriptions.any((value) => value.length > 512)) {
      gaps.add('Journal text exceeds schema length $name');
    }
    if (entry.ksefNumber != null &&
        entry.ksefNumber!.isNotEmpty &&
        !RegExp(
          r'^([1-9]((\d[1-9])|([1-9]\d))\d{7}|M\d{9}|[A-Z]{3}\d{7})-(20[2-9][0-9]|2[1-9][0-9]{2}|[3-9][0-9]{3})(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])-([0-9A-F]{6})-?([0-9A-F]{6})-([0-9A-F]{2})$',
        ).hasMatch(entry.ksefNumber!)) {
      gaps.add('Invalid KSeF identifier $name');
    }
    for (final lineNumber in entry.lineNumbers) {
      if (!lineNumbers.add('${entry.journalName}\u0000$lineNumber')) {
        gaps.add('Duplicate line number $lineNumber in ${entry.journalName}');
      }
    }
    if (entry.ksefRequired && (entry.ksefNumber?.trim().isEmpty ?? true)) {
      gaps.add('KSeF identifier $name');
    }
  }
  return List.unmodifiable(gaps);
}
