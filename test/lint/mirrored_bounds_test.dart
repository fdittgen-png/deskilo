// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4419 -- a limit that lives on the server and in the app cannot differ between them, and a new
// copy cannot be added without saying where its source is. `_mirrors` pairs a Dart constant with
// the SQL that is its source (the latest migration that states it); each pair is compared. A
// numeric constant in a `*Limits` class, or named like a bound (`max…Length`, `…MaxBytes`, `…Limit`), that
// has no row below and no `// not-mirrored: <why>` on its line or the line above is counted;
// the count only falls (a row or a marker takes a constant out of it).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// One Dart constant and the SQL it mirrors: the constant [name] of [dartFile] is compared with the number
/// [sql] captures in group 1, read in the latest migration that matches it.
class Mirror {
  const Mirror(this.label, this.dartFile, this.name, this.sql, {this.migration});
  final String label;
  /// The migration (its number, `0089`) the bound is read in; null: the latest one that matches [sql].
  final String? migration;
  final String dartFile;
  final String name;
  final String sql;

  RegExp get dart => RegExp('const\\s+(?:int|double|num)\\s+$name\\s*=\\s*([0-9]+);');
}

const _service = 'lib/features/money/domain/service_item.dart';
const _drawer = 'lib/features/money/domain/till_drawer_rules.dart';

const _mirrors = <Mirror>[
  Mirror('MemberNoteRules.maxLength (0089)', 'lib/features/workspace/domain/member_note.dart', 'maxLength',
      r'length\(btrim\(body\)\) between 1 and (\d+)', migration: '0089'),
  Mirror('StatusTextRules.maxLength (0029)', 'lib/features/profile/domain/profile.dart', 'maxLength',
      r'char_length\(status_text\) <= (\d+)'),
  Mirror('ServiceLimits.minMinutes (0711)', _service, 'minMinutes', r'duration_minutes between (\d+) and \d+'),
  Mirror('ServiceLimits.maxMinutes (0711)', _service, 'maxMinutes', r'duration_minutes between \d+ and (\d+)'),
  Mirror('ServiceLimits.descriptionMaxLength (0711)', _service, 'descriptionMaxLength', r'char_length\(description\) <= (\d+)'),
  Mirror('ServiceLimits.categoryMaxLength (0711)', _service, 'categoryMaxLength', r'char_length\(category\) between 1 and (\d+)'),
  Mirror('kTillNameMaxLength (0907)', _drawer, 'kTillNameMaxLength', r'name text not null check \(char_length\(btrim\(name\)\) between 1 and (\d+)\)',
      migration: '0907'),
  Mirror('kDrawerReasonMaxLength (0907)', _drawer, 'kDrawerReasonMaxLength',
      r'difference_reason is null or char_length\(difference_reason\) <= (\d+)', migration: '0907'),
];

/// RATCHET: numeric bound constants of `lib/` with no mirror row and no `// not-mirrored:` marker.
/// Only falls: give a constant its row (its SQL source), or the marker with the reason it has none.
const _unlistedBudget = 11;

final _bound = RegExp(
  r'^\s*(?:static\s+)?const\s+(?:int|double|num)\s+(\w+)\s*=\s*([0-9][0-9_.]*);',
);
// a bound is a count the server may also check: a length, a size in bytes or rows, a number of lines, items or
// pages, a quantity, a span of minutes or days (a width or a scale of the screen is the app's own)
final _boundName = RegExp(
  r'((^max|Max).*(Length|Chars|Bytes|Rows|Count|Lines|Items|Entries|Pages|Minutes|Days|Quantity|Size)|Limits?$|Limit[A-Z0-9])',
);
final _limitsClass = RegExp(r'^(?:abstract final |final |abstract )?class \w*Limits\b');

/// The `(name, line)` of the bound-like numeric constants of [source] without a marker.
List<(String, int)> unlistedBounds(String source) {
  final lines = source.split('\n');
  final out = <(String, int)>[];
  var inLimits = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_limitsClass.hasMatch(line)) inLimits = true;
    if (inLimits && line == '}') inLimits = false;
    final m = _bound.firstMatch(line);
    if (m == null) continue;
    if (!inLimits && !_boundName.hasMatch(m.group(1)!)) continue;
    final marked = line.contains('not-mirrored:') ||
        (i > 0 && lines[i - 1].contains('not-mirrored:'));
    if (!marked) out.add((m.group(1)!, i + 1));
  }
  return out;
}

int _number(String text, Pattern pattern, String what) {
  final m = pattern.matchAsPrefix(text) ?? pattern.allMatches(text).firstOrNull;
  expect(m, isNotNull, reason: '$what: the pattern $pattern finds nothing');
  return int.parse(m!.group(1)!);
}

void main() {
  test('a bound constant with no row and no marker is seen', () {
    expect(unlistedBounds('abstract final class FooLimits {\n  static const int cap = 5;\n}\n'), [('cap', 2)]);
    expect(unlistedBounds('const int maxRows = 100;'), [('maxRows', 1)]);
    expect(unlistedBounds('// not-mirrored: a UI choice\nconst int maxRows = 100;'), isEmpty);
    expect(unlistedBounds('const int maxRows = 100; // not-mirrored: a UI choice'), isEmpty);
    expect(unlistedBounds('const int pageSize = 20;'), isEmpty);
    expect(unlistedBounds('class Other {\n  static const int cap = 5;\n}'), isEmpty);
  });

  test('every mirrored bound equals its SQL source', () {
    final all = sqlFiles('supabase/migrations').reversed.toList();
    for (final m in _mirrors) {
      final migrations = m.migration == null
          ? all
          : all.where((f) => f.uri.pathSegments.last.startsWith('${m.migration}_')).toList();
      final dart = _number(File(m.dartFile).readAsStringSync(), m.dart, m.label);
      File? source;
      for (final f in migrations) {
        if (RegExp(m.sql).hasMatch(f.readAsStringSync())) {
          source = f;
          break;
        }
      }
      expect(source, isNotNull, reason: '${m.label}: no migration states ${m.sql}');
      final sql = _number(source!.readAsStringSync(), RegExp(m.sql), m.label);
      expect(dart, sql, reason: '${m.label}: Dart $dart, SQL $sql (${source.uri.pathSegments.last})');
    }
  });

  test('a mirror row names a constant that exists', () {
    for (final m in _mirrors) {
      expect(m.dart.hasMatch(File(m.dartFile).readAsStringSync()), isTrue, reason: m.label);
    }
  });

  test('the unlisted bound constants only fall', () {
    var unlisted = 0;
    final shown = <String>[];
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll('\\', '/');
      for (final (name, line) in unlistedBounds(f.readAsStringSync())) {
        if (_mirrors.any((m) => m.dartFile == path && m.name == name)) continue;
        unlisted++;
        if (shown.length < 25) shown.add('$path:$line $name');
      }
    }
    expect(unlisted, lessThanOrEqualTo(_unlistedBudget), reason: 'give it a row or a // not-mirrored: marker:\n${shown.join('\n')}');
    expect(unlisted, _unlistedBudget, reason: 'it fell: lower _unlistedBudget to $unlisted');
  });
}
