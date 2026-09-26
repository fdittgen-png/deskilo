// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1614 — every Edge function is classified, and the class is enforced in
// its source: a user-facing or system function refuses a delegated (MCP)
// token before its first privileged client; a webhook never takes a
// bearer token as its authority. A new function without a row fails here,
// so it cannot ship unclassified.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = (jsonDecode(File('supabase/functions/exposure.json').readAsStringSync())
      as Map<String, dynamic>)['functions'] as Map<String, dynamic>;
  final functions = Directory('supabase/functions')
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .where((n) => !n.startsWith('_'))
      .toSet();

  test('the manifest names exactly the functions that exist', () {
    expect(manifest.keys.toSet(), functions);
  });

  test('user-facing and system functions refuse a delegated token first', () {
    for (final entry in manifest.entries) {
      final cls = (entry.value as Map)['class'];
      if (cls != 'user_facing' && cls != 'system') continue;
      final source = File('supabase/functions/${entry.key}/index.ts').readAsStringSync();
      final guard = source.indexOf('refuseDelegated(req');
      expect(guard, greaterThan(0), reason: '${entry.key} never refuses a delegated token');
      final serve = source.indexOf('Deno.serve(');
      final body = source.substring(serve);
      final firstPrivileged = [
        body.indexOf('createClient('),
        body.indexOf('.rpc('),
        body.indexOf('.from('),
        body.indexOf('fetch('),
      ].where((i) => i >= 0).fold<int>(body.length, (a, b) => a < b ? a : b);
      expect(body.indexOf('refuseDelegated(req'), lessThan(firstPrivileged),
          reason: '${entry.key} refuses the delegated token only after privileged work');
    }
  });

  test('webhooks never use a bearer token as their authority', () {
    for (final entry in manifest.entries) {
      if ((entry.value as Map)['class'] != 'webhook') continue;
      final source = File('supabase/functions/${entry.key}/index.ts').readAsStringSync();
      expect(source, isNot(contains('auth.getUser(')), reason: entry.key);
    }
  });
}
