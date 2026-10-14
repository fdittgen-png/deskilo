// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 (C1 of #2476) -- the VAT code may not grow a tax literal. Rates,
// thresholds, country-keyed branches and country lists are REFERENCE DATA
// (the `tax_reference` store, migration 0427), not Dart or SQL: this ratchet
// counts them in the VAT files and fails when the count differs from the
// allow-list -- #2481 (C5) took the ceilings to zero: a literal is either
// moved to the store or listed, with its reason, in
// `test/lint/tax_literals_allowed.txt`; a literal that is not listed fails.
//
// The files named here are the VAT files; a literal that is not a business
// value (an EN 16931 code, a UI size) is not counted by these patterns.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _rule = 'tax_literals (#2476)';

String ratchetNote(String what, List<String> lines) =>
    '$_rule: $what.\nA tax value is a `tax_reference` row (docs/AGENT_RULES.md); '
    'if this is not one (an EN 16931 code, a UI example), add it to '
    'test/lint/tax_literals_allowed.txt with the reason:\n${lines.join('\n')}';

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

final _sqlKinds = [
  LiteralKind('country lists', RegExp(r"'[A-Z]{2}'\s*,\s*'[A-Z]{2}'\s*,\s*'[A-Z]{2}'")),
  LiteralKind('country-keyed branches', RegExp(r"\bwhen\s+'[A-Z]{2}'\s+then", caseSensitive: false)),
  LiteralKind('percent values', RegExp(r'\bvat_percent\s*(?:=|:=)\s*\d')),
];

/// One finding: the kind, the file and the trimmed code line it sits on.
typedef _Finding = ({String kind, String path, String line});

/// Every literal in the VAT files, with the line it is on.
List<_Finding> _findings() {
  final out = <_Finding>[];
  for (final file in filesUnder(_dartRoots)) {
    final text = codeLines(file).join('\n');
    for (final kind in _kinds) {
      for (final m in kind.pattern.allMatches(text)) {
        final start = text.lastIndexOf('\n', m.start) + 1;
        final end = text.indexOf('\n', m.end);
        out.add((
          kind: kind.name,
          path: file.path,
          line: text.substring(start, end < 0 ? text.length : end).trim(),
        ));
      }
    }
  }
  return out;
}

/// `path :: code line :: count :: reason` per line of the allow-list.
Map<String, ({int count, String reason})> _allowed() {
  final out = <String, ({int count, String reason})>{};
  for (final raw in File('test/lint/tax_literals_allowed.txt').readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(' :: ');
    expect(parts.length, 4, reason: 'path :: code line :: count :: reason -- $raw');
    expect(parts[3].trim(), isNotEmpty, reason: 'every entry says why: $raw');
    out['${parts[0]} :: ${parts[1]}'] =
        (count: int.parse(parts[2]), reason: parts[3]);
  }
  return out;
}

void main() {
  final found = <String, int>{};
  for (final f in _findings()) {
    found.update('${f.path} :: ${f.line}', (n) => n + 1, ifAbsent: () => 1);
  }

  test('no tax literal in the VAT files outside the reviewed allow-list', () {
    if (Platform.environment['TAX_LITERALS_PRINT'] == '1') {
      for (final e in found.entries) {
        stdout.writeln('${e.key} :: ${e.value} :: TODO');
      }
    }
    final allowed = _allowed();
    final fresh = [
      for (final e in found.entries)
        if ((allowed[e.key]?.count ?? 0) < e.value) '${e.value}  ${e.key}',
    ];
    expect(
      fresh,
      isEmpty,
      reason: ratchetNote('a tax literal outside the allow-list', fresh),
    );
  });

  test('every allow-list entry is still in the code, as many times as it says', () {
    final stale = [
      for (final e in _allowed().entries)
        if ((found[e.key] ?? 0) != e.value.count) e.key,
    ];
    expect(
      stale,
      isEmpty,
      reason: '$_rule: the line moved or went -- delete or correct its entry in '
          'test/lint/tax_literals_allowed.txt:\n${stale.join('\n')}',
    );
  });

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
