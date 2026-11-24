// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4424 -- a placeholder named `quantity`, `amount`, `count` or `number` that
// is typed String hides from every number check: whatever the call site hands
// in is printed. Its description says it arrives formatted (`formatted`: the
// call site used AppFormat), or that it is no number at all (`reference`: an
// invoice number, a code). The messages written before this check are listed
// in docs/design/ARB_FORMATTED_PLACEHOLDER_BASELINE.txt as "key placeholder";
// the file only shrinks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _names = {'quantity', 'amount', 'count', 'number'};
const _baselinePath = 'docs/design/ARB_FORMATTED_PLACEHOLDER_BASELINE.txt';

/// "key placeholder" for each text placeholder of [en] that says nothing of how it arrives.
Set<String> unsaidPlaceholders(Map<String, dynamic> en) => {
  for (final MapEntry(:key, :value) in en.entries)
    if (key.startsWith('@') && key != '@@locale' && value is Map)
      for (final MapEntry(key: name, value: meta)
          in ((value['placeholders'] as Map?) ?? const {}).entries)
        if (_names.contains(name) &&
            (meta is! Map ||
                meta['type'] == null ||
                meta['type'] == 'String') &&
            !RegExp(
              r'\b(formatted|reference)\b',
              caseSensitive: false,
            ).hasMatch('${value['description'] ?? ''}'))
          '${key.substring(1)} $name',
};

void main() {
  test('the check sees a text amount that says nothing of how it arrives', () {
    Map<String, dynamic> one(String description, {String type = 'String'}) => {
      'k': '{amount}',
      '@k': {
        'description': description,
        'placeholders': {
          'amount': {'type': type},
        },
      },
    };
    expect(unsaidPlaceholders(one('a total')), {'k amount'});
    expect(
      unsaidPlaceholders(one('a total; amount arrives formatted')),
      isEmpty,
    );
    expect(unsaidPlaceholders(one('the invoice reference')), isEmpty);
    expect(unsaidPlaceholders(one('a total', type: 'int')), isEmpty);
  });

  test('no new text placeholder of a number says nothing of how it arrives, and the list only shrinks', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final found = unsaidPlaceholders(en);
    final baseline = {
      for (final l in File(_baselinePath).readAsLinesSync())
        if (l.trim().isNotEmpty && !l.startsWith('#')) l.trim(),
    };
    expect(
      found.difference(baseline),
      isEmpty,
      reason:
          'say in the description that it arrives formatted, or is a reference',
    );
    expect(
      baseline.difference(found),
      isEmpty,
      reason: 'described since, or gone: drop it from $_baselinePath',
    );
  });
}
