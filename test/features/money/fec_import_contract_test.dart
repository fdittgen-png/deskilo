// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the FEC as an import contract. The committed goldens of the
// seeded fiscal year are replayed through the rules a French importer
// applies (fec_import_contract.dart), and each rule is shown to fire on a
// copy of the posted golden that breaks it — one change per case, so no
// other rule answers for it.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/fec_import_contract.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'test/features/money/goldens/seeded_year';

/// The seeded fiscal year of the local book: 1 October to 30 September.
final _year = FiscalYear(DateTime(2025, 10), DateTime(2026, 9, 30));
const _thirdParties = {'411000', '401000'};

String _golden(String name) => File('$_dir/$name').readAsStringSync();

FecContractReport _check(String text, {Set<String>? known, List<int>? bytes}) =>
    checkFecImportContract(
      bytes ?? utf8.encode(text),
      year: _year,
      thirdPartyAccounts: _thirdParties,
      knownAccounts: known,
    );

/// The posted golden with [field] of the first line matching [where]
/// replaced by [value].
String _with(
  String field,
  String value, {
  required bool Function(Map<String, String> row) where,
}) {
  final lines = _golden('fec_local_book.txt').split('\r\n');
  final head = lines.first.split('\t');
  var done = false;
  return [
    lines.first,
    for (final line in lines.skip(1))
      () {
        final row = Map.fromIterables(head, line.split('\t'));
        if (done || !where(row)) return line;
        done = true;
        row[field] = value;
        return head.map((h) => row[h]).join('\t');
      }(),
  ].join('\r\n');
}

void main() {
  test('the posted golden keeps every rule, chart included', () {
    final report = _check(
      _golden('fec_local_book.txt'),
      known: {
        '411000', '512000', '401000', '706000', '445711', '445713', //
        '445660', '445740', '606000', '654000',
      },
    );
    expect(report.findings, isEmpty);
    expect(
      report.records,
      _golden('fec_local_book.txt').trim().split('\r\n').length - 1,
    );
  });

  // The FEC written from the documents (no local book) letters a whole
  // invoice group, settled or not: INV-1 is lettered 30.00 short of its
  // expense credit and INV-2 with 80.00 still open. The contract names it;
  // the posted FEC of a local book is the one that replaces it.
  test('the document-based golden of the calendar year is held to the same '
      'rules, and its open letters are named', () {
    for (final name in ['fec.txt', 'bundle/fec.txt']) {
      final report = checkFecImportContract(
        utf8.encode(_golden(name)),
        year: FiscalYear.calendar(2026),
        thirdPartyAccounts: {'411000'},
      );
      expect(report.failedRules, [FecRule.lettering], reason: name);
      expect(report.findings.map((f) => f.detail), [
        'letter INV-1 does not balance',
        'letter INV-2 does not balance',
      ], reason: name);
    }
  });

  final cases = <String, (FecRule, String Function())>{
    'a byte-order mark': (
      FecRule.encoding,
      () => '﻿${_golden('fec_local_book.txt')}',
    ),
    'a comment before the header': (
      FecRule.header,
      () => '# provisoire\r\n${_golden('fec_local_book.txt')}',
    ),
    'a record of 17 fields': (
      FecRule.header,
      () {
        final lines = _golden('fec_local_book.txt').split('\r\n');
        lines[1] = lines[1].substring(0, lines[1].lastIndexOf('\t'));
        return lines.join('\r\n');
      },
    ),
    'a debit and a credit on one line': (
      FecRule.amounts,
      () => _with('Credit', '1,00', where: (r) => r['Debit'] != '0,00'),
    ),
    'a negative amount': (
      FecRule.amounts,
      () => _with('Debit', '-225,50', where: (r) => r['Debit'] == '225,50'),
    ),
    'an entry that does not balance': (
      FecRule.balance,
      () => _with('Credit', '99,00', where: (r) => r['Credit'] == '100,00'),
    ),
    // Every line of VE-INV-2 renumbered: each entry still balances.
    'one number for two entries': (
      FecRule.identity,
      () =>
          _golden('fec_local_book.txt')
              .replaceAll('\tVE-INV-2\t', '\tVE-INV-1\t'),
    ),
    // Both lines of BQ-INV-5, a day before the year opens.
    'a date outside the fiscal year': (
      FecRule.dates,
      () =>
          _golden('fec_local_book.txt')
              .replaceAll('\tBQ-INV-5\t20260810\t', '\tBQ-INV-5\t20250930\t'),
    ),
    'a ValidDate after the closing day': (
      FecRule.dates,
      () => _with('ValidDate', '20261002', where: (r) => true),
    ),
    'a receivable without its auxiliary account': (
      FecRule.thirdParty,
      () => _with('CompAuxNum', '', where: (r) => r['CompteNum'] == '411000'),
    ),
    'a letter without its DateLet': (
      FecRule.lettering,
      () => _with('DateLet', '', where: (r) => r['EcritureLet'] == 'INV-3'),
    ),
    'a letter with two DateLet': (
      FecRule.lettering,
      () => _with(
        'DateLet',
        '20260524',
        where: (r) => r['EcritureLet'] == 'INV-3',
      ),
    ),
    'a currency amount without its currency': (
      FecRule.currency,
      () => _with('Montantdevise', '10,00', where: (r) => true),
    ),
  };

  for (final MapEntry(key: name, value: (rule, text)) in cases.entries) {
    test('$name breaks the $rule rule, and only it', () {
      final report = _check(text());
      expect(report.passed, isFalse, reason: name);
      expect(report.failedRules, [rule], reason: '$name: ${report.findings}');
    });
  }

  test('ISO-8859-15 bytes are not the UTF-8 the contract reads', () {
    final bytes = latin1.encode('JournalCode\tOpérations');
    final report = _check('', bytes: bytes);
    expect(report.failedRules, [FecRule.encoding]);
  });

  test('an account the chart does not hold is named', () {
    final report = _check(
      _golden('fec_local_book.txt'),
      known: {'411000', '512000'},
    );
    expect(report.failedRules, [FecRule.accounts]);
  });
}
