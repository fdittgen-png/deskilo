// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1558 / #1566 — a backslash before a `$` that is followed by a name
// is a string interpolation that was switched off, and the compiler
// cannot tell you.
//
// Both bugs were the same keystroke. The push connector wrote
// `'fcm:\$token'`, so every installation registered the nine literal
// characters `fcm:$token`; the send-push function stripped the prefix
// and handed FCM the string `$token`, and no notification could reach a
// device. The demo dataset wrote `'demo-seat-\$i'` and `'A\${i + 1}'`,
// so three seats shared one id and one label — one resource wearing
// three chairs, which no amount of booking could separate. Neither is
// caught by the analyzer: an escaped dollar is a perfectly valid
// string, and both files compiled, shipped and ran for months.
//
// The rule is deliberately the SHAPE of the mistake rather than every
// escaped dollar, because a literal `$` is sometimes exactly right:
// `RegExp('^$pattern\$')` anchors at the end of a line, and a currency
// symbol is a dollar sign. What is never right is escaping a dollar
// that is followed by an identifier or a `{` — there is nothing to
// escape there, only an interpolation the author meant to happen.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Where an escaped dollar reads as an interpolation and is not one.
const Map<String, String> _exempt = {
  'lib/features/workspace/domain/feature_registry_sql.dart':
      "Postgres dollar-quoting: \$registry\$ delimits the function body",
  // 2026-09-25 #1655 — the same generator shape for the field registry.
  'lib/features/workspace/domain/template_field_registry_sql.dart':
      "Postgres dollar-quoting: \$registry\$ and \$json\$ delimit the body and its literal",
};

/// `\$` immediately followed by what an interpolation starts with.
final RegExp _looksLikeInterpolation = RegExp(r'\\\$[A-Za-z_{]');

void main() {
  test('no escaped dollar stands where an interpolation was meant', () {
    final offenders = scanLines(
      handWrittenDartFilesIn(['lib', 'packages'])
          .where((f) => !_exempt.containsKey(f.path)),
      _looksLikeInterpolation.hasMatch,
    );
    expect(
      offenders,
      isEmpty,
      reason: 'drop the backslash: `\\\$name` in a Dart string emits the '
          'characters `\$name`, not the value of `name`. Every seat gets '
          'the same id, every device the same endpoint. If this one '
          'really must print a dollar followed by a name — a SQL '
          'dollar-quote, say — add the file to _exempt with the '
          'reason:\n${offenders.join('\n')}',
    );
  });

  test('the rule matches the shape, not every dollar', () {
    expect(_looksLikeInterpolation.hasMatch(r"'fcm:\$token'"), isTrue);
    expect(_looksLikeInterpolation.hasMatch(r"'A\${i + 1}'"), isTrue);
    // A line anchor and a lone currency sign are literal dollars with
    // nothing to interpolate, and stay legal.
    expect(_looksLikeInterpolation.hasMatch(r"RegExp('^$p\$')"), isFalse);
    expect(_looksLikeInterpolation.hasMatch(r"'\$ 12.00'"), isFalse);
  });
}
