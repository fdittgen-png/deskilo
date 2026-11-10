// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3563 -- a field that names master data (a country, a currency, a time zone,
// a locale, a language) is a lookup, never free text. Counted by the field's
// IDENTITY -- its ValueKey, `fieldKey` or controller key -- not its label,
// which is localized and drifts: an AppTextField / TextField / TextFormField
// whose identity matches is a free-text master-data field. Ceiling 0; a field
// that only OPENS a lookup (read-only, a picker behind it) is allow-listed
// with its reason.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Identities that may stay a text field, with why.
const Map<String, String> _allowed = {
  'workspaceSettingsTimezone':
      'read-only: tapping it opens the time-zone picker (#711)',
  'timezone-search': 'the search box of the time-zone picker itself',
  'onboarding-currency':
      'typed text validated against the supported list (isKnownCurrency, '
      'onboardingCurrencyUnknown); found by this ratchet, not in the four of '
      '#3563 -- becomes the CurrencyField with the onboarding rework',
  'onboarding-timezone':
      'typed text validated against the IANA database (workspaceTimezoneUnknown); '
      'found by this ratchet, not in the four of #3563 -- becomes the picker '
      'with the onboarding rework',
};

final _master = RegExp(
  'country|currency|timezone|zone|locale|language',
  caseSensitive: false,
);
final _widget = RegExp(r'\b(?:AppTextField|TextFormField|TextField)\(');
final _identity = RegExp(
  r'''(?:ValueKey|Key)(?:<String>)?\('([^']+)'\)|fieldKey:\s*'([^']+)'|fields?\['([^']+)'\]''',
);

/// The identities named inside the widget call whose `(` is at [open].
Iterable<String> _identitiesAt(String text, int open) {
  var depth = 0;
  var end = open;
  for (; end < text.length; end++) {
    if (text[end] == '(') depth++;
    if (text[end] == ')' && --depth == 0) break;
  }
  return [
    for (final m in _identity.allMatches(text.substring(open, end)))
      m.group(1) ?? m.group(2) ?? m.group(3)!,
  ];
}

void main() {
  test('no free-text field names master data (ceiling 0, two-sided)', () {
    final found = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final text = file.readAsStringSync();
      for (final m in _widget.allMatches(text)) {
        final ids = _identitiesAt(text, m.end - 1).toList();
        if (ids.any(_master.hasMatch)) {
          final id = ids.firstWhere(_master.hasMatch);
          if (!_allowed.containsKey(id)) found.add('${file.path}: $id');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'use CountryField / CurrencyField (lib/core/ui) so nobody '
          'guesses a code (#3563):\n${found.join('\n')}',
    );
    for (final id in _allowed.keys) {
      final still = handWrittenDartFiles('lib').any(
        (f) => File(f.path).readAsStringSync().contains(id),
      );
      expect(still, isTrue, reason: '$id no longer exists: drop its entry');
    }
  });
}
