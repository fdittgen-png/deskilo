// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3730 (compatibility K3) — an app reads what it does not know. Wherever a
// value from a server becomes a type (the domain and data layers of lib/
// and every package that reads a server contract), a value this build does
// not know is read as an explicit unknown that keeps the raw text and
// allows no action. Two spellings break that:
//
// - `Enum.values.byName(…)` throws: one widened value fails the whole list
//   (#1148). It is refused outright in this scope (`wire_enum_test.dart`
//   holds the data layer since #1148; this extends it to the domain and the
//   packages).
// - A fallback to a KNOWN value (`firstWhere(…, orElse: () => draft)`,
//   `asNameMap()[raw] ?? Kind.full`, `enumOr(…, Known.x, area: …)`) does not
//   throw, but gives a future value the meaning of a known one: an unknown
//   purchase order state read as an editable draft, an unknown invoice kind
//   as a full invoice. Those left are counted, and the count only falls:
//   the next parser converted lowers it, a new one is a defect. A fallback
//   to `unknown`, `none` or `null` is the rule, and passes.
//
// `wire_switch_throw_test.dart` counts the third spelling (a `switch` or an
// `orElse` that throws). Each detector is proven on planted text below, so
// a lint that matches nothing cannot pass by accident.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Known-state fallbacks left in the scope (the ledger of #3730: 53 when
/// it was measured, before the purchase order state, the invoice kind and
/// the statement movement became unknowns). Lower it when a parser is
/// converted; never raise it.
const int _knownStateFallbacks = 50;

/// `byName` sites in the scope that read no server value, each with why.
const _byNameKept = <String, String>{
  'lib/features/workspace/domain/member_note_refs.dart':
      'the token pattern admits only the four space kinds: an unknown kind '
      'never matches and stays plain text',
};

/// The fallbacks that keep a value's meaning safe: an explicit unknown or
/// none, or no value at all.
const _safeFallbacks = {'unknown', 'none', 'null', 'unreadable'};

/// Where a value from a server becomes a type: the domain and data layers
/// of lib/ (demo data excluded), and the packages' libraries.
bool inScope(String path) {
  final p = path.replaceAll('\\', '/');
  if (p.contains('lib/core/demo/')) return false;
  if (p.startsWith('packages/') || p.contains('/packages/')) {
    return p.contains('/lib/');
  }
  return p.contains('/data/') || p.contains('/domain/');
}

/// `Enum.values.byName(` on a line that is not a comment.
bool readsByName(String line) =>
    !line.trimLeft().startsWith('//') && line.contains('.values.byName(');

final _orElseKnown = RegExp(
  r'values\s*\.firstWhere\((?:(?!values\s*\.firstWhere\().){0,240}?'
  r'orElse:\s*\(\)\s*=>\s*([\w.]+)',
  dotAll: true,
);
final _nameMapKnown = RegExp(
  r'asNameMap\(\)\[.{0,120}?\]\s*\?\?\s*([\w.]+)',
  dotAll: true,
);
final _enumOrKnown = RegExp(
  r'enumOr\(\s*[\w.]+\s*,.{0,240}?,\s*([\w.]+),\s*area:',
  dotAll: true,
);

/// The fallbacks in [source] that read an unknown value as a known one,
/// each as the fallback's text.
List<String> knownStateFallbacks(String source) {
  final code = source
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
  return [
    for (final pattern in [_orElseKnown, _nameMapKnown, _enumOrKnown])
      for (final m in pattern.allMatches(code))
        if (!_safeFallbacks.contains(m.group(1)!.split('.').last) &&
            m.group(1) != 'throw')
          m.group(1)!,
  ];
}

List<File> _scope() => [
  ...handWrittenDartFiles('lib').where((f) => inScope(f.path)),
  for (final package in directoryNames('packages'))
    if (directoryAt('packages/$package/lib').existsSync())
      ...handWrittenDartFiles('packages/$package/lib'),
];

void main() {
  group('the detectors, on planted text', () {
    test('a byName over a server value is found', () {
      expect(
        readsByName("type: AccountType.values.byName(r.string('t')),"),
        isTrue,
      );
      expect(readsByName('// AccountType.values.byName(raw) throws'), isFalse);
      expect(
        readsByName('for (final t in AccountType.values) t.name'),
        isFalse,
      );
    });

    test('a fallback to a known state is found, an unknown one passes', () {
      expect(
        knownStateFallbacks('''
  static S of(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => draft);
  static K fromWire(String? raw) =>
      K.values.asNameMap()[raw ?? ''] ?? K.full;
  final o = enumOr(Origin.values, row['origin'] as String?, Origin.manual,
      area: 'money');
'''),
        ['draft', 'K.full', 'Origin.manual'],
      );
      expect(
        knownStateFallbacks('''
  static S of(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => unknown);
  static K? fromWire(String? raw) => K.values.asNameMap()[raw] ?? K.none;
  final o = enumOr(Origin.values, raw, Origin.unknown, area: 'money');
  final local = Mode.values.firstWhere((m) => m.index == 2);
'''),
        isEmpty,
      );
    });

    test('a planted domain file is in scope and is red', () {
      final fixture = createTemporaryFixture('unknown_wire');
      final dir = temporaryFixtureDirectory(fixture, 'domain')..createSync();
      final planted = File('${dir.path}/planted.dart')
        ..writeAsStringSync(
          "final k = AccountType.values.byName(row['account_type']);\n"
          'final s = values.firstWhere((s) => s.wire == w, '
          'orElse: () => draft);\n',
        );
      try {
        expect(inScope(planted.path), isTrue);
        expect(scanLines([planted], readsByName), hasLength(1));
        expect(knownStateFallbacks(planted.readAsStringSync()), ['draft']);
      } finally {
        fixture.directory.deleteSync(recursive: true);
      }
      expect(inScope('lib/features/money/presentation/x.dart'), isFalse);
      expect(inScope('lib/core/demo/data/x.dart'), isFalse);
      expect(inScope('packages/deskilo_invoice_model/lib/src/x.dart'), isTrue);
      expect(inScope('packages/deskilo_invoice_model/test/x.dart'), isFalse);
    });
  });

  test('no server value becomes an enum through byName', () {
    final hits = [
      for (final hit in scanLines(_scope(), readsByName))
        if (!_byNameKept.keys.any(
          (file) => hit.replaceAll('\\', '/').contains(file),
        ))
          hit,
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'read it through enumOr(values, raw, Kind.unknown, area: …) '
          '(lib/core/data/enum_wire.dart) or a firstWhere whose orElse is '
          'the unknown:\n${hits.join('\n')}',
    );
  });

  test('fallbacks to a known state only get fewer', () {
    final hits = [
      for (final file in _scope())
        for (final fallback in knownStateFallbacks(file.readAsStringSync()))
          '${file.path}: $fallback',
    ];
    expect(
      hits.length,
      lessThanOrEqualTo(_knownStateFallbacks),
      reason:
          'a value this app does not know is read as an explicit unknown '
          'that keeps its raw text and allows no action, never as a known '
          'state:\n${hits.join('\n')}',
    );
    expect(
      hits.length,
      _knownStateFallbacks,
      reason:
          'a parser was converted: lower _knownStateFallbacks to '
          '${hits.length}',
    );
  });
}
