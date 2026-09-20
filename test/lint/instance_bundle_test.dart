// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #977 — the instance bundle the wizard installs must never lag the
// migrations or the functions: a new migration without a rebuilt bundle
// would leave a freshly created instance one step behind the app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_instance.dart';

void main() {
  test('assets/instance/bundle.json equals a fresh build '
      '(run: dart run tool/build_instance.dart)', () {
    final fresh = encodeInstanceBundle(buildInstanceBundle('.'));
    final onDisk = File('assets/instance/bundle.json').readAsStringSync();
    expect(onDisk.trimRight(), fresh.trimRight(),
        reason: 'stale bundle — run: dart run tool/build_instance.dart');
    final decoded = jsonDecode(onDisk) as Map<String, dynamic>;
    final schema = decoded['schema'] as List;
    expect(schema.length,
        Directory('supabase/migrations').listSync().whereType<File>().length);
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
    final shared = Directory('supabase/functions/_shared')
        .listSync()
        .whereType<File>()
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

  test('#1314 — every migration can run inside the one request that records '
      'it', () {
    final offenders = <String>[];
    for (final file in Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))) {
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
