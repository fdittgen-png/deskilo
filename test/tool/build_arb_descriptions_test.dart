// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3486 — build_arb refuses an English key without `@key.description`, and a
// recorded key that has one now: the list of undescribed keys only shrinks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../helpers/tool_process.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('build_arb'));
  tearDown(() => root.deleteSync(recursive: true));

  Future<ProcessResult> build(
    Map<String, Object?> english, {
    List<String> recorded = const [],
  }) async {
    final fragments = Directory('${root.path}/fragments')..createSync();
    final out = Directory('${root.path}/out')..createSync();
    for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
      File('${fragments.path}/fixture_$locale.arb').writeAsStringSync(
        jsonEncode(locale == 'en'
            ? english
            : {for (final k in english.keys) if (!k.startsWith('@')) k: 'x'}),
      );
    }
    final list = File('${root.path}/undescribed.txt')
      ..writeAsStringSync('# recorded\n${recorded.join('\n')}\n');
    return runTool('tool/build_arb.dart', [
      '--fragments',
      fragments.path,
      '--out',
      out.path,
      '--undescribed',
      list.path,
    ]);
  }

  test('a described key builds', () async {
    final r = await build({
      'greeting': 'Hello',
      '@greeting': {'description': 'The home screen greeting.'},
    });
    expect(r.exitCode, 0, reason: '${r.stderr}');
  });

  test('a new key without a description fails the build', () async {
    final r = await build({'greeting': 'Hello'});
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('"greeting" has no @greeting.description'));
  });

  test('a recorded key builds until it is described, then must leave the list',
      () async {
    expect((await build({'greeting': 'Hello'}, recorded: ['greeting'])).exitCode,
        0);
    final described = await build({
      'greeting': 'Hello',
      '@greeting': {'description': 'The home screen greeting.'},
    }, recorded: ['greeting']);
    expect(described.exitCode, isNot(0));
    expect('${described.stderr}', contains('remove it from'));
  });
}
