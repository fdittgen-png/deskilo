// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — the server's field registry IS the Dart one.
//
// `inspect_workspace_template` reads `public.template_field_registry()`
// for every disposition it reports, and the client shows the Dart
// registry. The SQL is generated from the Dart
// (`dart run tool/build_template_field_registry_sql.dart`); this test
// requires the latest migration defining the function to carry exactly
// that JSON, and names the field that drifted.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/template_field_registry_sql.dart';
import 'package:flutter_test/flutter_test.dart';

const _definition =
    'create or replace function public.template_field_registry()';

({String file, List<dynamic> registry})? _latest() {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files.reversed) {
    final sql = f.readAsStringSync();
    final at = sql.indexOf(_definition);
    if (at < 0) continue;
    final open = sql.indexOf(r'$json$', at) + r'$json$'.length;
    final close = sql.indexOf(r'$json$::jsonb', open);
    return (
      file: f.uri.pathSegments.last,
      registry: jsonDecode(sql.substring(open, close)) as List<dynamic>,
    );
  }
  return null;
}

void main() {
  test('the latest template_field_registry() is the generated one', () {
    final latest = _latest();
    expect(latest, isNotNull,
        reason: 'no migration defines public.template_field_registry()');
    final expected = jsonDecode(templateFieldRegistryJson()) as List<dynamic>;
    final stored = {
      for (final r in latest!.registry) (r as Map)['id'] as String: jsonEncode(r),
    };
    final drift = <String>[
      for (final r in expected)
        if (!stored.containsKey((r as Map)['id']))
          '${r['id']}: missing in ${latest.file}'
        else if (stored[r['id']] != jsonEncode(r))
          '${r['id']}: differs in ${latest.file}',
      for (final id in stored.keys)
        if (!expected.any((r) => (r as Map)['id'] == id))
          '$id: in SQL, no longer in the Dart registry',
    ];
    expect(drift, isEmpty,
        reason: 'run `dart run tool/build_template_field_registry_sql.dart` '
            'and carry the output in a new migration:\n  ${drift.join('\n  ')}');
  });
}
