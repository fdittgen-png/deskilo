// SPDX-License-Identifier: 0BSD
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
}
