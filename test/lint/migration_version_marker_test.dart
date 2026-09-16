// SPDX-License-Identifier: 0BSD
//
// #1312 — every migration after the marker's introduction says which
// version it makes the schema, and what kind of change it is.
//
// The version an instance runs used to be a COUNT of recorded migration
// rows against a floor of 200. The dev project records 227 rows for 225
// files, with timestamp versions and names that are not the file names;
// a wizard-built instance before #1314 recorded none. A count is not a
// version.
//
// 0226 made the schema carry its own: `public.deskilo_schema_version()`,
// written by `set_deskilo_schema_version(NNNN)` INSIDE each migration, so
// it is true however the SQL arrived — CLI, MCP, the wizard, a `psql`
// restore — and it rolls back with the migration it describes. That only
// holds if no migration forgets the line, so this test is the contract:
//
//   * the LAST statement of every migration from 0226 on is
//     `select public.set_deskilo_schema_version(NNNN);` with the file's own
//     number — a copied line naming the previous file would leave the
//     instance one version behind forever and nobody would see it;
//   * the line under the licence is `-- risk: additive | transforming |
//     destructive`, so an operator upgrading a customer instance knows what
//     they are about to run; `destructive` names the backup to take first.
import 'dart:io';

import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

/// The migration that introduced the marker. Files before it predate the
/// contract; the marker's first value covers them.
const int markerIntroducedAt = 226;

final _fileName = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');
final _marker = RegExp(
  r'select\s+public\.set_deskilo_schema_version\((\d+)\)\s*;\s*$',
  caseSensitive: false,
);
final _risk = RegExp(r'^-- risk: (additive|transforming|destructive)\s*$');

/// Why [sql], the text of migration [number], breaks the contract — or
/// null when it keeps it.
String? markerProblem(int number, String sql) {
  final trimmed = _stripTrailingComments(sql);
  final match = _marker.firstMatch(trimmed);
  if (match == null) {
    return 'does not end with select public.set_deskilo_schema_version('
        '$number);';
  }
  final named = int.parse(match.group(1)!);
  if (named != number) {
    return 'ends with set_deskilo_schema_version($named), but it is '
        'migration $number';
  }
  return null;
}

/// Why the header of [sql] carries no valid risk tag — or null.
String? riskProblem(String sql) {
  final lines = sql.split('\n');
  if (lines.length < 2 || !_risk.hasMatch(lines[1])) {
    return 'line 2 must be "-- risk: additive | transforming | destructive"';
  }
  if (lines[1].contains('destructive') &&
      !sql.toLowerCase().contains('backup')) {
    return 'is tagged destructive and never names the backup to take first';
  }
  return null;
}

/// A trailing comment after the marker would still leave it the last
/// statement; blank lines and `--` lines at the end are not statements.
String _stripTrailingComments(String sql) {
  final lines = sql.trimRight().split('\n');
  while (lines.isNotEmpty &&
      (lines.last.trim().isEmpty || lines.last.trim().startsWith('--'))) {
    lines.removeLast();
  }
  return lines.join('\n');
}

List<(int, File)> _migrationsFrom(int first) {
  final out = <(int, File)>[];
  for (final f in Directory('supabase/migrations').listSync().whereType<File>()) {
    final m = _fileName.firstMatch(f.uri.pathSegments.last);
    if (m == null) continue;
    final n = int.parse(m.group(1)!);
    if (n >= first) out.add((n, f));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

void main() {
  test('the introducing migration exists and sets its own number', () {
    final intro = _migrationsFrom(markerIntroducedAt).first;
    expect(intro.$1, markerIntroducedAt);
    final sql = intro.$2.readAsStringSync();
    expect(sql, contains('create table if not exists public.deskilo_schema_version'));
    expect(sql, contains('security invoker'));
    expect(markerProblem(intro.$1, sql), isNull);
  });

  test('the app requires exactly the last migration it ships', () {
    // A migration merged without raising `requiredSchemaVersion` would
    // let this build run on a server missing it — the failure the gate
    // exists to prevent, one file late.
    final last = _migrationsFrom(markerIntroducedAt).last.$1;
    expect(requiredSchemaVersion, last,
        reason: 'supabase/migrations ends at $last; set requiredSchemaVersion '
            'in lib/core/instance/schema_compatibility.dart to $last');
  });

  test('every migration from the marker on ends with its own version', () {
    final offenders = [
      for (final (n, f) in _migrationsFrom(markerIntroducedAt))
        if (markerProblem(n, f.readAsStringSync()) case final p?)
          '${f.uri.pathSegments.last}: $p',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every migration from the marker on carries a risk tag', () {
    final offenders = [
      for (final (_, f) in _migrationsFrom(markerIntroducedAt))
        if (riskProblem(f.readAsStringSync()) case final p?)
          '${f.uri.pathSegments.last}: $p',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  group('the rule is capable of failing', () {
    const good = '-- SPDX-License-Identifier: 0BSD\n'
        '-- risk: additive\n'
        'create table t (id int);\n'
        'select public.set_deskilo_schema_version(230);\n';

    test('a well-formed migration passes', () {
      expect(markerProblem(230, good), isNull);
      expect(riskProblem(good), isNull);
    });

    test('a missing marker is refused', () {
      expect(markerProblem(230, good.replaceAll(RegExp(r'select public.*\n'), '')),
          contains('does not end'));
    });

    test('a marker copied from the previous file is refused', () {
      expect(markerProblem(231, good), contains('but it is migration 231'));
    });

    test('a marker followed by more SQL is not the last statement', () {
      expect(markerProblem(230, '${good}grant select on t to anon;\n'),
          contains('does not end'));
    });

    test('trailing comments after the marker are fine', () {
      expect(markerProblem(230, '$good\n-- done\n\n'), isNull);
    });

    test('a missing or unknown risk tag is refused', () {
      expect(riskProblem(good.replaceFirst('-- risk: additive\n', '')),
          isNotNull);
      expect(riskProblem(good.replaceFirst('additive', 'harmless')), isNotNull);
    });

    test('destructive without a backup paragraph is refused', () {
      expect(riskProblem(good.replaceFirst('additive', 'destructive')),
          contains('backup'));
      expect(
          riskProblem('${good.replaceFirst('additive', 'destructive')}'
              '-- Take a backup first: supabase db dump.\n'),
          isNull);
    });
  });
}
