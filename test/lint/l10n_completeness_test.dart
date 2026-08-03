// SPDX-License-Identifier: 0BSD
//
// Every label exists in every language (#412 follow-up, owner rule):
// the aggregated ARBs must carry IDENTICAL key sets across all five
// locales. build_arb.dart already fails when a key lacks an _en
// fragment; this is the reverse guard — a key added to en but forgotten
// in de/es/fr/it would silently fall back to English at runtime.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const locales = ['en', 'de', 'es', 'fr', 'it'];

Set<String> _keys(String locale) {
  final map = json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
      as Map<String, dynamic>;
  return map.keys.where((k) => !k.startsWith('@')).toSet()..remove('@@locale');
}

void main() {
  test('all five locales carry exactly the same message keys', () {
    final en = _keys('en');
    for (final locale in locales.skip(1)) {
      final other = _keys(locale);
      expect(en.difference(other), isEmpty,
          reason: 'keys missing in $locale — add them to the '
              '_fragments/*_$locale.arb files and rebuild');
      expect(other.difference(en), isEmpty,
          reason: 'keys in $locale that en does not have — the merge '
              'should have refused this');
    }
  });
}
