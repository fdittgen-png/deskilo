// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3658 — no currency is ever a default in the app either. The platform's
// default currency (`locale.default_currency`) is offered once, when a
// business is created, and nowhere else: an amount is in the currency of its
// business or its record. This counts every use of it in lib/ outside the
// places named here with their reason; the list only shrinks.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _allowed = <String, String>{
  'lib/core/settings/region_defaults.dart':
      'the currency offered when a business is created',
  'lib/core/i18n/workspace_currency.dart':
      'the decimal grain of input helpers before a business is installed; '
      'never a displayed amount',
};

void main() {
  test('the platform\'s default currency is used only where it is stated', () {
    final found = <String>[];
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll(r'\', '/');
      if (_allowed.containsKey(path)) continue;
      final lines = File(f.path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('localeDefaultCurrency')) {
          found.add('$path:${i + 1}');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason:
          'an amount is in the currency of its business or its record; '
          'a missing one reads "Currency unavailable" (#3658)',
    );
  });
}
