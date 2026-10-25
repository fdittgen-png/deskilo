// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the FEC as an import contract: the rules a French importer
// (Pennylane, Sage 100, Cegid, EBP) applies to a FEC before it takes the
// entries, checked on the file's own bytes, independently of the code
// that wrote them. The arrêté's field order and the DGFiP's reader come
// first: the first record is the field-name header, nothing precedes it,
// and a qualification never goes inside the file.
//
// What is checked:
//   * encoding — UTF-8 without a byte-order mark;
//   * header — the first record is exactly the 18 field names, in order,
//     tab-separated; every record has 18 fields;
//   * amounts — Debit and Credit are `0,00`-shaped, never negative, and
//     exactly one of them is non-zero;
//   * balance — every entry (JournalCode, EcritureNum) balances;
//   * identity — an entry number names one entry: one date and one piece
//     per (JournalCode, EcritureNum), however many lines it has;
//   * dates — EcritureDate inside the fiscal year, ValidDate on or after
//     it and not after the closing date;
//   * third parties — every line on a third-party collective names its
//     auxiliary account and label;
//   * lettering — EcritureLet and DateLet together, one DateLet per letter,
//     and a letter's lines balance on its third-party account;
//   * currency — Montantdevise and Idevise together, Idevise a three-letter
//     code;
//   * accounts — every CompteNum is known to the chart, when one is given.
import 'dart:convert';

import '../../../core/time/date_text.dart';
import 'fec.dart';
import 'fiscal_year.dart';

/// One rule of the import contract.
enum FecRule {
  encoding,
  header,
  amounts,
  balance,
  identity,
  dates,
  thirdParty,
  lettering,
  currency,
  accounts,
}

/// A record that breaks [rule]; [line] is 1-based, the header being 1.
class FecFinding {
  const FecFinding(this.rule, this.line, this.detail);
  final FecRule rule;
  final int line;
  final String detail;

  @override
  String toString() => '${rule.name} (line $line): $detail';
}

/// What the check of one file found: nothing when the contract holds.
class FecContractReport {
  const FecContractReport(this.findings, {required this.records});
  final List<FecFinding> findings;

  /// The entry lines checked, the header apart.
  final int records;

  bool get passed => findings.isEmpty;

  /// The rules that failed, in contract order.
  List<FecRule> get failedRules => [
    for (final r in FecRule.values)
      if (findings.any((f) => f.rule == r)) r,
  ];
}

const _bom = [0xEF, 0xBB, 0xBF];
final _amount = RegExp(r'^\d+,\d{2}$');
final _day = RegExp(r'^\d{8}$');
final _currency = RegExp(r'^[A-Z]{3}$');

/// Checks [bytes], a FEC of [year], against the import contract.
/// [thirdPartyAccounts] are the collective accounts whose lines must name
/// an auxiliary account (the chart's customers and suppliers accounts);
/// [knownAccounts], when given, every account the chart holds.
FecContractReport checkFecImportContract(
  List<int> bytes, {
  required FiscalYear year,
  required Set<String> thirdPartyAccounts,
  Set<String>? knownAccounts,
}) {
  final findings = <FecFinding>[];
  if (bytes.length >= 3 &&
      bytes[0] == _bom[0] &&
      bytes[1] == _bom[1] &&
      bytes[2] == _bom[2]) {
    findings.add(const FecFinding(FecRule.encoding, 1, 'byte-order mark'));
  }
  final text = utf8.decode(bytes, allowMalformed: true);
  if (!_sameBytes(utf8.encode(text), bytes)) {
    findings.add(const FecFinding(FecRule.encoding, 1, 'not UTF-8'));
    return FecContractReport(findings, records: 0);
  }
  final lines = text.split(RegExp(r'\r?\n'));
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty ||
      lines.first.replaceFirst('﻿', '') != fecColumns.join('\t')) {
    findings.add(
      const FecFinding(
        FecRule.header,
        1,
        'the first record is not the 18 field names',
      ),
    );
    return FecContractReport(findings, records: lines.length);
  }
  final check = _Checker(
    year: year,
    thirdPartyAccounts: thirdPartyAccounts,
    knownAccounts: knownAccounts,
    findings: findings,
  );
  for (var i = 1; i < lines.length; i++) {
    final fields = lines[i].split('\t');
    if (fields.length != fecColumns.length) {
      findings.add(
        FecFinding(FecRule.header, i + 1, '${fields.length} fields, not 18'),
      );
      if (fields.length > 2) check.malformed.add('${fields[0]}|${fields[2]}');
      continue;
    }
    check.record(i + 1, Map.fromIterables(fecColumns, fields));
  }
  check.finish();
  return FecContractReport(findings, records: lines.length - 1);
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _cents(String amount) => int.parse(amount.replaceAll(',', ''));

class _Checker {
  _Checker({
    required this.year,
    required this.thirdPartyAccounts,
    required this.knownAccounts,
    required this.findings,
  });

  final FiscalYear year;
  final Set<String> thirdPartyAccounts;
  final Set<String>? knownAccounts;
  final List<FecFinding> findings;

  final _balance = <String, int>{};

  /// Entries with a record that could not be read: their balance is not
  /// judged, the record's own finding says what is wrong.
  final malformed = <String>{};
  final _firstLine = <String, int>{};
  final _identity = <String, String>{};
  final _letterDate = <String, String>{};
  final _letterBalance = <String, int>{};
  final _letterLine = <String, int>{};

  void _add(FecRule rule, int line, String detail) =>
      findings.add(FecFinding(rule, line, detail));

  bool _inYear(String day) =>
      _day.hasMatch(day) &&
      day.compareTo(ymd(year.from)) >= 0 &&
      day.compareTo(ymd(year.to)) <= 0;

  void record(int line, Map<String, String> r) {
    final entry = '${r['JournalCode']}|${r['EcritureNum']}';
    final amounts = _amounts(line, r);
    if (amounts == null) malformed.add(entry);
    _balance[entry] = (_balance[entry] ?? 0) + (amounts ?? 0);
    _firstLine.putIfAbsent(entry, () => line);
    final identity = '${r['EcritureDate']}|${r['PieceRef']}';
    if ((_identity[entry] ??= identity) != identity) {
      _add(FecRule.identity, line, '${r['EcritureNum']} names two entries');
    }
    _dates(line, r);
    _thirdParty(line, r);
    _lettering(line, r, amounts);
    _currencyPair(line, r);
    if (knownAccounts case final known? when !known.contains(r['CompteNum'])) {
      _add(FecRule.accounts, line, 'unknown account ${r['CompteNum']}');
    }
  }

  /// Debit minus credit, or null when the amounts are malformed.
  int? _amounts(int line, Map<String, String> r) {
    final debit = r['Debit']!;
    final credit = r['Credit']!;
    if (!_amount.hasMatch(debit) || !_amount.hasMatch(credit)) {
      _add(FecRule.amounts, line, 'amount "$debit" / "$credit"');
      return null;
    }
    final d = _cents(debit);
    final c = _cents(credit);
    if ((d == 0) == (c == 0)) {
      _add(FecRule.amounts, line, 'one of Debit and Credit, not both or none');
      return null;
    }
    return d - c;
  }

  void _dates(int line, Map<String, String> r) {
    final date = r['EcritureDate']!;
    final valid = r['ValidDate']!;
    if (!_inYear(date)) {
      _add(FecRule.dates, line, 'EcritureDate $date outside the year');
    }
    if (!_day.hasMatch(valid) ||
        valid.compareTo(date) < 0 ||
        valid.compareTo(ymd(year.to)) > 0) {
      _add(FecRule.dates, line, 'ValidDate $valid');
    }
  }

  void _thirdParty(int line, Map<String, String> r) {
    if (!thirdPartyAccounts.contains(r['CompteNum'])) return;
    if (r['CompAuxNum']!.isEmpty || r['CompAuxLib']!.isEmpty) {
      _add(
        FecRule.thirdParty,
        line,
        '${r['CompteNum']} without its auxiliary account',
      );
    }
  }

  void _lettering(int line, Map<String, String> r, int? amount) {
    final letter = r['EcritureLet']!;
    final date = r['DateLet']!;
    if (letter.isEmpty != date.isEmpty) {
      _add(FecRule.lettering, line, 'EcritureLet and DateLet go together');
      return;
    }
    if (letter.isEmpty) return;
    final key = '${r['CompteNum']}|${r['CompAuxNum']}|$letter';
    if ((_letterDate[key] ??= date) != date || !_day.hasMatch(date)) {
      _add(FecRule.lettering, line, 'letter $letter has two DateLet');
    }
    // A letter settles a third party's account: its lines there balance.
    if (!thirdPartyAccounts.contains(r['CompteNum'])) return;
    _letterBalance[key] = (_letterBalance[key] ?? 0) + (amount ?? 0);
    _letterLine.putIfAbsent(key, () => line);
  }

  void _currencyPair(int line, Map<String, String> r) {
    final amount = r['Montantdevise']!;
    final code = r['Idevise']!;
    if (amount.isEmpty && code.isEmpty) return;
    if (!_amount.hasMatch(amount.replaceFirst('-', '')) ||
        !_currency.hasMatch(code)) {
      _add(FecRule.currency, line, 'Montantdevise "$amount" / Idevise "$code"');
    }
  }

  void finish() {
    for (final MapEntry(:key, :value) in _balance.entries) {
      if (value != 0 && !malformed.contains(key)) {
        _add(
          FecRule.balance,
          _firstLine[key]!,
          '${key.split('|').last} is off by $value',
        );
      }
    }
    for (final MapEntry(:key, :value) in _letterBalance.entries) {
      if (value != 0) {
        _add(
          FecRule.lettering,
          _letterLine[key]!,
          'letter ${key.split('|').last} does not balance',
        );
      }
    }
  }
}
