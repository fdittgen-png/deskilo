// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4429 -- a message that reads exactly as in English in another language is
// either the same word there (a brand, a product, a standard, an international
// word: "Status", "Total", "IBAN") or a translation never made. The ones that
// exist are listed per language in docs/design/ARB_IDENTICAL_BASELINE.txt as
// "language key", the reviewed allowance; a new identical message must be
// translated or listed with care, and one translated since leaves the list.
// Only messages with a real word count: four letters or more outside the
// placeholders.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['de', 'fr', 'es', 'it'];
const _baselinePath = 'docs/design/ARB_IDENTICAL_BASELINE.txt';

/// Whether [text] holds a word of four letters or more outside its placeholders.
bool hasRealWord(String text) {
  var t = text;
  for (var i = 0; i < 4; i++) {
    t = t.replaceAll(RegExp(r'\{[^{}]*\}'), ' ');
  }
  return RegExp(r'\p{L}{4,}', unicode: true).hasMatch(t);
}

/// Every message of [arbs] that a language left as in English, as "language key".
Set<String> identicalToEnglish(Map<String, Map<String, dynamic>> arbs) {
  final en = arbs['en']!;
  return {
    for (final lang in _languages)
      for (final MapEntry(:key, :value) in en.entries)
        if (!key.startsWith('@') &&
            value is String &&
            arbs[lang]![key] == value &&
            hasRealWord(value))
          '$lang $key',
  };
}

void main() {
  test('the check sees a message left in English and not a code', () {
    expect(hasRealWord('Barcode (optional)'), isTrue);
    expect(hasRealWord('{count} · {date}'), isFalse);
    expect(hasRealWord('KSeF'), isTrue);
    expect(hasRealWord('PDF'), isFalse);
  });

  test('every message left as in English is a reviewed one, and the list only shrinks', () {
    final arbs = {
      for (final l in ['en', ..._languages])
        l: jsonDecode(
          File('lib/l10n/app_$l.arb').readAsStringSync(),
        ) as Map<String, dynamic>,
    };
    final found = identicalToEnglish(arbs);
    final baseline = {
      for (final l in File(_baselinePath).readAsLinesSync())
        if (l.trim().isNotEmpty && !l.startsWith('#')) l.trim(),
    };
    expect(
      found.difference(baseline),
      isEmpty,
      reason: 'translate it, or list it in $_baselinePath with care',
    );
    expect(
      baseline.difference(found),
      isEmpty,
      reason: 'translated since, or gone: drop it from $_baselinePath',
    );
    // the report, per language
    for (final lang in _languages) {
      final n = found.where((f) => f.startsWith('$lang ')).length;
      printOnFailure('$lang: $n messages read as in English');
    }
  });
}
