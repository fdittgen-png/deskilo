// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3651 -- a number in a sentence gets its plural: "1 days" reads wrong in
// every language. A message with an integer placeholder outside an ICU plural
// is refused unless its description says the number is not a count; the
// existing ones are the baseline in docs/design/PLURAL_BASELINE.txt, which
// only shrinks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words of a description that say the number is not a count of things.
final _notACount = RegExp(
  r'not a count|a year|a version|a room number|a line number|a column|an index|a position|a limit',
  caseSensitive: false,
);

Set<String> _offenders(Map<String, dynamic> arb, {bool honourReason = true}) {
  final out = <String>{};
  for (final MapEntry(:key, :value) in arb.entries) {
    if (key.startsWith('@') || value is! String) continue;
    final meta = (arb['@$key'] as Map?) ?? const {};
    final placeholders = (meta['placeholders'] as Map?) ?? const {};
    final hasInt = placeholders.values.any(
      (p) => p is Map && (p['type'] == 'int' || p['type'] == 'num'),
    );
    if (!hasInt || value.contains('plural,')) continue;
    if (honourReason && _notACount.hasMatch('${meta['description']}')) continue;
    out.add(key);
  }
  return out;
}

void main() {
  final arb =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  final baseline = {
    for (final l in File('docs/design/PLURAL_BASELINE.txt').readAsLinesSync())
      if (l.trim().isNotEmpty && !l.startsWith('#')) l.trim(),
  };

  test('no new message carries an integer outside a plural (#3651)', () {
    final fresh = _offenders(arb).difference(baseline);
    expect(
      fresh,
      isEmpty,
      reason:
          'A count in a sentence is an ICU plural in all five languages '
          '({n, plural, =1{…} other{…}}). If the number is not a count (a '
          'year, a version, a room or line number), say so in the '
          "message's description.\n${fresh.join('\n')}",
    );
  });

  test('the baseline only shrinks: a converted message leaves it', () {
    final stale = baseline.difference(_offenders(arb, honourReason: false));
    expect(
      stale,
      isEmpty,
      reason:
          'These are plurals now (or gone): delete their lines from '
          'docs/design/PLURAL_BASELINE.txt.\n${stale.join('\n')}',
    );
  });

  test('the check can fail: a planted message is found', () {
    final planted = {
      'x': '{days} days',
      '@x': {
        'description': 'planted',
        'placeholders': {
          'days': {'type': 'int'},
        },
      },
      'y': '{n, plural, =1{1 day} other{{n} days}}',
      '@y': {
        'description': 'planted',
        'placeholders': {
          'n': {'type': 'int'},
        },
      },
      'z': 'Column {n}',
      '@z': {
        'description': 'a column number, not a count',
        'placeholders': {
          'n': {'type': 'int'},
        },
      },
    };
    expect(_offenders(planted), {'x'});
  });
}
