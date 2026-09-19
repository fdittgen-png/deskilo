// SPDX-License-Identifier: 0BSD
//
// #1334 — the repository's size, measured rather than remembered.
//
// `docs/PROJECT_OVERVIEW.md` carried a "Current scale" table written by
// hand: 73 migrations, 21 features, 944 ARB keys, 1 013 test cases. By
// the time anybody read it again the repository held 251 migrations and
// 3 426 keys, and every one of those numbers was wrong — silently, in a
// document a new reader trusts to orient themselves.
//
// A number in prose rots. This measures each one instead, and the
// overview names the command rather than the answer, so the table can
// never disagree with the repository again.
//
// The counts are printed and never committed. That is the same decision
// the test inventory made and for the same reason: a committed count
// changes in every pull request that adds a file, so any two such pull
// requests conflict on that line.
import 'dart:convert';
import 'dart:io';

/// One measured row of the scale table.
class Measure {
  const Measure(this.name, this.value, this.how);

  /// What is counted, as the table says it.
  final String name;

  final int value;

  /// Where the answer comes from, so a surprising number can be checked.
  final String how;
}

List<File> _dartFiles(String dir, {required bool generated}) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) =>
          generated ||
          (!f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart')))
      .toList();
}

int _countIn(String dir, String suffix) {
  final d = Directory(dir);
  if (!d.existsSync()) return 0;
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith(suffix))
      .length;
}

/// Every measure, in the order the overview lists them.
List<Measure> measures({String root = '.'}) {
  final lib = _dartFiles('$root/lib', generated: false);
  final libAll = _dartFiles('$root/lib', generated: true);

  final arb = File('$root/lib/l10n/app_en.arb');
  final keys = arb.existsSync()
      ? (jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>)
          .keys
          .where((k) => !k.startsWith('@'))
          .length
      : 0;

  final fragments = Directory('$root/lib/l10n/_fragments');
  final groups = fragments.existsSync()
      ? fragments
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_en.arb'))
          .length
      : 0;

  final migrations = Directory('$root/supabase/migrations');
  final migrationFiles = migrations.existsSync()
      ? (migrations
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  final router = File('$root/lib/app/router.dart');
  final routes = router.existsSync()
      ? RegExp(r'\bGoRoute\(').allMatches(router.readAsStringSync()).length
      : 0;

  final featureEnum = File(
      '$root/lib/features/workspace/domain/workspace_feature.dart');
  final features = featureEnum.existsSync()
      ? _enumValues(featureEnum.readAsStringSync(), 'WorkspaceFeature')
      : 0;

  return [
    Measure('Dart source files (`lib/`, hand-written)', lib.length,
        'lib/**/*.dart minus .g.dart and .freezed.dart'),
    Measure('Generated Dart files (`lib/`)', libAll.length - lib.length,
        '.g.dart and .freezed.dart under lib/'),
    Measure('Test files (`test/` + `supabase/tests/database/`)',
        _countIn('$root/test', '_test.dart') +
            _countIn('$root/supabase/tests/database', '.sql'),
        'the same set `tool/test_inventory.dart` classifies'),
    Measure('SQL migrations in the repo', migrationFiles.length,
        'supabase/migrations/*.sql'),
    Measure('Supabase Edge Functions',
        _edgeFunctions('$root/supabase/functions'), 'supabase/functions/*/'),
    Measure('ARB translation keys per locale', keys,
        'lib/l10n/app_en.arb, ignoring the @ metadata'),
    Measure('ARB fragment groups', groups, 'lib/l10n/_fragments/*_en.arb'),
    Measure('go_router routes', routes, 'GoRoute( in lib/app/router.dart'),
    Measure('Toggleable per-workspace features', features,
        'the WorkspaceFeature enum'),
    Measure('GitHub Actions workflows', _countIn('$root/.github/workflows', '.yml'),
        '.github/workflows/*.yml'),
  ];
}

/// The values of `enum <name>`, counted from its own body only: the
/// manifest below it names every one of them a second time, and the
/// pin in `feature_registry_test` is the number this must agree with.
int _enumValues(String source, String name) {
  final start = source.indexOf('enum $name {');
  if (start < 0) return 0;
  final end = source.indexOf('\n}', start);
  final body = source.substring(start, end < 0 ? source.length : end);
  // The last value ends in `;` rather than `,` when the enum has members
  // of its own, which this one does (`dbKey`).
  return RegExp(r'^\s{2}([a-z][A-Za-z0-9]*)\s*[,;]\s*$', multiLine: true)
      .allMatches(body)
      .length;
}

int _edgeFunctions(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return 0;
  return d.listSync().whereType<Directory>().length;
}

/// The table, as the overview would print it.
String render(List<Measure> all) {
  final b = StringBuffer()
    ..writeln('| Metric | Value | Measured from |')
    ..writeln('|---|---:|---|');
  for (final m in all) {
    b.writeln('| ${m.name} | ${m.value} | ${m.how} |');
  }
  return b.toString();
}
