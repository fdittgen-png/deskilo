// SPDX-License-Identifier: MIT
//
// HARD RULE #4: every locale must carry every key that exists in the
// canonical English ARB. Fails CI when a locale is missing keys (or carries
// keys English does not have, which usually means a typo or a stale key).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const supportedLocales = ['en', 'fr', 'de', 'es', 'it'];

Set<String> keysOf(String locale) {
  final file = File('lib/l10n/app_$locale.arb');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing aggregated ARB for "$locale" — '
        'run: dart run tool/build_arb.dart',
  );
  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return map.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  test('every locale has exactly the canonical English key set', () {
    final canonical = keysOf('en');
    expect(canonical, isNotEmpty);

    for (final locale in supportedLocales.where((l) => l != 'en')) {
      final keys = keysOf(locale);
      final missing = canonical.difference(keys);
      final extra = keys.difference(canonical);
      expect(
        missing,
        isEmpty,
        reason: '"$locale" is missing keys present in app_en.arb: $missing',
      );
      expect(
        extra,
        isEmpty,
        reason: '"$locale" has keys absent from app_en.arb: $extra',
      );
    }
  });

  test('fragment files exist for every locale of every feature prefix', () {
    final fragments = Directory('lib/l10n/_fragments')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.arb'))
        .toList();
    final prefixes = fragments
        .map((n) => n.replaceAll(RegExp(r'_[a-z]{2}\.arb$'), ''))
        .toSet();

    for (final prefix in prefixes) {
      for (final locale in supportedLocales) {
        expect(
          fragments,
          contains('${prefix}_$locale.arb'),
          reason: 'Fragment "$prefix" lacks locale "$locale" — every new key '
              'ships in all ${supportedLocales.length} locales in the same PR '
              '(HARD RULE #1).',
        );
      }
    }
  });
}
