// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 (C1 of #2476) -- the VAT code may not grow a tax literal. Rates,
// thresholds, country-keyed branches and country lists are REFERENCE DATA
// (the `tax_reference` store, migration 0427), not Dart or SQL: this ratchet
// counts them in the VAT files and fails when the count differs from the
// ceiling -- up is a defect, down must be recorded. Each checkpoint (C2..C5)
// lowers it; the last pins it at zero outside seed files and tests.
//
// The files named here are the VAT files; a literal that is not a business
// value (an EN 16931 code, a UI size) is not counted by these patterns.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _rule = 'tax_literals (#2476)';

/// The VAT files: money, core/vat -- the seed tool and tests are outside.
const _dartRoots = ['lib/features/money', 'lib/core/vat'];

/// A migration whose number is above this one is counted too: a function
/// body added after the store may not carry a tax literal. Earlier ones are
/// history; the store's own seed (0427) is the one place values live.
const _firstCountedMigration = 428;

final _kinds = [
  // `percent: 19`, `rates: {19, 7}` and a rate written into a string.
  LiteralKind('percent values',
      RegExp(r"percent:\s*\d|rates:\s*\{\s*\d|'[^'\n]*\d\s?%[^'\n]*'")),
  // `'FR' =>`, `'DE' || 'AT' =>`, `case 'FR':`
  LiteralKind('country-keyed branches',
      RegExp(r"'[A-Z]{2}'(?:\s*\|\|\s*'[A-Z]{2}')*\s*=>|\bcase\s+'[A-Z]{2}'\s*:")),
  // `'FR': ...` as an entry of a country-keyed map.
  LiteralKind('country-keyed map entries',
      RegExp(r"^\s*'[A-Z]{2}'\s*:", multiLine: true)),
  // three or more country codes in a row: a set, a list, an array.
  LiteralKind(
      'country lists',
      RegExp(
          r"'[A-Z]{2}'\s*,\s*'[A-Z]{2}'\s*,\s*'[A-Z]{2}'(?!\s*,\s*'[A-Z]{2}')"
          r"|(?<!'[A-Z]{2}',[ \t]*\n)^[ \t]*'[A-Z]{2}',[ \t]*\n[ \t]*'[A-Z]{2}',[ \t]*\n[ \t]*'[A-Z]{2}'",
          multiLine: true)),
];

/// The ceilings: today's counts. They only go down.
const _ceilings = <String, int>{
  'percent values': 16,
  'country-keyed branches': 30,
  'country-keyed map entries': 11,
  'country lists': 2,
};

final _sqlKinds = [
  LiteralKind('country lists', RegExp(r"'[A-Z]{2}'\s*,\s*'[A-Z]{2}'\s*,\s*'[A-Z]{2}'")),
  LiteralKind('country-keyed branches', RegExp(r"\bwhen\s+'[A-Z]{2}'\s+then", caseSensitive: false)),
  LiteralKind('percent values', RegExp(r'\bvat_percent\s*(?:=|:=)\s*\d')),
];

void main() {
  final dart = countLiterals(filesUnder(_dartRoots), _kinds);

  for (final kind in _kinds) {
    test('${kind.name} in the VAT files stay at their ceiling', () {
      final perFile = dart[kind.name]!;
      final actual = total(perFile);
      expect(
        actual,
        _ceilings[kind.name],
        reason: ratchetMessage(
          rule: _rule,
          kind: kind.name,
          ceiling: _ceilings[kind.name]!,
          actual: actual,
          perFile: perFile,
        ),
      );
    });
  }

  test('a migration after the store carries no tax literal in its SQL', () {
    final files = filesUnder(['supabase/migrations'], suffix: '.sql').where((f) {
      final n = int.tryParse(f.uri.pathSegments.last.split('_').first) ?? 0;
      return n >= _firstCountedMigration;
    });
    final sql = countLiterals(files, _sqlKinds, comment: '--', skip: anchoredOldText);
    for (final kind in _sqlKinds) {
      expect(total(sql[kind.name]!), 0,
          reason: '$_rule: "${kind.name}" in a migration after the store: '
              '${sql[kind.name]!.keys.join(', ')}');
    }
  });

  test('the ratchet counts what it claims to', () {
    final probe = File('${Directory.systemTemp.path}/tax_literals_probe.dart')
      ..writeAsStringSync("""
const a = {'AT', 'BE', 'BG'};
final b = switch (c) { 'FR' || 'DE' => 1, _ => 0 };
const d = (percent: 19);
// 'IT' => commented out, percent: 7
""");
    addTearDown(probe.deleteSync);
    final n = countLiterals([probe], _kinds);
    expect(total(n['country lists']!), 1);
    expect(total(n['country-keyed branches']!), 1);
    expect(total(n['percent values']!), 1);
  });
}
