// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #977 — the instance bundle the wizard installs must never lag the
// migrations or the functions: a new migration without a rebuilt bundle
// would leave a freshly created instance one step behind the app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_instance.dart';
import 'lint_sources.dart';

void main() {
  test('assets/instance/bundle.json equals a fresh build '
      '(run: dart run tool/build_instance.dart)', () {
    final fresh = encodeInstanceBundle(buildInstanceBundle('.'));
    final onDisk = File('assets/instance/bundle.json').readAsStringSync();
    expect(onDisk.trimRight(), fresh.trimRight(),
        reason: 'stale bundle — run: dart run tool/build_instance.dart');
    final decoded = jsonDecode(onDisk) as Map<String, dynamic>;
    final schema = decoded['schema'] as List;
    expect(schema.length, sqlFiles('supabase/migrations').length);
    expect((schema.first as Map)['name'], startsWith('0001_'));
    final functions = decoded['functions'] as List;
    expect(functions.map((f) => (f as Map)['slug']),
        containsAll(functionVerifyJwt.keys),
        reason: 'every function of the repository is in the bundle');
    for (final f in functions) {
      expect(functionVerifyJwt.containsKey((f as Map)['slug']), isTrue,
          reason: 'a new function must say whether it verifies the JWT');
    }
  });

  test('#1137 — every function carries the shared modules, path-named', () {
    final decoded = jsonDecode(
        File('assets/instance/bundle.json').readAsStringSync()) as Map;
    final shared = filesWithExtension('supabase/functions/_shared', '.ts')
        .map((f) => '_shared/${f.uri.pathSegments.last}')
        .toSet();
    expect(shared, isNotEmpty, reason: 'money.ts lives there');
    for (final f in decoded['functions'] as List) {
      final slug = (f as Map)['slug'] as String;
      final names = (f['files'] as List).map((x) => (x as Map)['name']).toSet();
      expect(names, contains('$slug/index.ts'),
          reason: '$slug: the entrypoint is path-named under its slug');
      expect(names.containsAll(shared), isTrue,
          reason: '$slug must carry _shared/* or its imports fail on deploy');
    }
  });

  test('#3329 — nested modules reach the bundle and every relative import '
      'of a bundled file resolves inside it', () {
    final fixture = createTemporaryFixture('bundle_nested');
    final tmp = fixture.directory;
    addTearDown(() => tmp.deleteSync(recursive: true));
    void put(String path, String body) {
      File('${tmp.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(body);
    }

    put('supabase/migrations/0001_x.sql', 'select 1;');
    put('supabase/functions/_shared/jurisdiction/fr/rules.ts', 'export {};');
    put('supabase/functions/_shared/money.ts',
        "import './jurisdiction/fr/rules.ts';");
    put('supabase/functions/demo/index.ts',
        "import './parts/deep/part.ts';\nimport '../_shared/money.ts';");
    put('supabase/functions/demo/parts/deep/part.ts', 'export {};');
    put('supabase/functions/demo/parts/deep/part_test.ts', 'export {};');

    final fn =
        (buildInstanceBundle(tmp.path)['functions'] as List).single as Map;
    final names = {for (final x in fn['files'] as List) (x as Map)['name']};
    expect(
        names,
        containsAll([
          'demo/index.ts',
          'demo/parts/deep/part.ts',
          '_shared/money.ts',
          '_shared/jurisdiction/fr/rules.ts',
        ]));
    expect(names, isNot(contains('demo/parts/deep/part_test.ts')));
    expect(_unresolvedImports([fn]), isEmpty);
  });

  test('#3329 — the real bundle resolves every relative import too', () {
    final decoded = jsonDecode(
        File('assets/instance/bundle.json').readAsStringSync()) as Map;
    expect(_unresolvedImports(decoded['functions'] as List), isEmpty);
  });

  test('#1314 — every migration can run inside the one request that records '
      'it', () {
    final offenders = <String>[];
    for (final file in sqlFiles('supabase/migrations')) {
      final name = file.uri.pathSegments.last;
      // A comment may name what it forbids.
      final sql = file.readAsStringSync().split('\n').map((line) {
        final comment = line.indexOf('--');
        return comment < 0 ? line : line.substring(0, comment);
      }).join('\n');
      if (RegExp(r'^\s*(begin|commit|rollback)\s*;',
              multiLine: true, caseSensitive: false)
          .hasMatch(sql)) {
        offenders.add('$name: explicit transaction control');
      }
      if (RegExp(r'\bconcurrently\b', caseSensitive: false).hasMatch(sql)) {
        offenders.add('$name: CONCURRENTLY');
      }
      if (RegExp(r'alter\s+type\s+\S+\s+add\s+value', caseSensitive: false)
          .hasMatch(sql)) {
        offenders.add('$name: ALTER TYPE … ADD VALUE');
      }
    }
    expect(offenders, isEmpty,
        reason: 'the installer sends each migration together with its record '
            'in ONE request, which runs as one transaction '
            '(InstanceBuilder.recordedMigrationSql). A statement that cannot '
            'run inside a transaction needs its own request, recorded in a '
            'second one.');
  });
}

final _importRe = RegExp(
    r'''(?:import|export)\s+(?:[^'";]*?from\s+)?['"](\.[^'"]+)['"]''');

/// `slug: file -> import` for every relative import a bundled file makes
/// that no file of the same function's bundle answers.
List<String> _unresolvedImports(List<Object?> functions) {
  final missing = <String>[];
  for (final fn in functions) {
    final files = (fn as Map)['files'] as List;
    final names = {for (final x in files) (x as Map)['name']};
    for (final f in files) {
      final from = (f as Map)['name'] as String;
      for (final m in _importRe.allMatches(f['content'] as String)) {
        final parts = from.split('/')..removeLast();
        for (final seg in m.group(1)!.split('/')) {
          if (seg == '..') {
            parts.removeLast();
          } else if (seg != '.') {
            parts.add(seg);
          }
        }
        if (!names.contains(parts.join('/'))) {
          missing.add('${fn['slug']}: $from -> ${m.group(1)}');
        }
      }
    }
  }
  return missing;
}
