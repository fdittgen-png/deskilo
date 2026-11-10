// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3486 — a word that means the same in every context is one key. Counted:
// an English value under three keys or more whose translations are identical
// in fr, de, es and it in every copy makes all but one of those keys
// redundant. Context-varied words ("Name", "Open", "Active": gender and
// number agree differently) are not counted: their translations differ. The
// ceiling is the measure recorded when the test was written; it only falls.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 188 when recorded (#3541); 225 once #3543 gave each dictionary entry its
// own key (setup steps, export columns, report parts reuse common words).
// The consolidation of #3486 lowers it.
const _redundantCeiling = 0;

/// Keys that stay distinct although another key says the same word: each is
/// named as a string by code that is not a getter call (a registry, the
/// lexicon, a guide builder), so renaming it would break that reader.
const Map<String, String> _namedByCode = {
  'featureAccountingPeriodsTitle': 'composed from the feature name in tool/build_process_catalogue.dart (\'feature\' + Name + \'Title\')',
  'planReserveButton': 'named as a string in lib/core/l10n/lexicon_defaults.dart',
};

Map<String, Object?> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

void main() {
  test('redundant keys of an identically translated word only fall', () {
    final en = _arb('en');
    final targets = {for (final l in ['fr', 'de', 'es', 'it']) l: _arb(l)};
    final byValue = <String, List<String>>{};
    for (final MapEntry(:key, :value) in en.entries) {
      if (key.startsWith('@') || value is! String) continue;
      if (_namedByCode.containsKey(key)) continue;
      byValue.putIfAbsent(value, () => []).add(key);
    }
    var redundant = 0;
    final worst = <String>[];
    for (final MapEntry(key: value, value: keys) in byValue.entries) {
      if (keys.length < 3) continue;
      final identical = targets.values
          .every((arb) => {for (final k in keys) arb[k]}.length == 1);
      if (!identical) continue;
      redundant += keys.length - 1;
      worst.add('"$value" ×${keys.length}');
    }
    expect(redundant, lessThanOrEqualTo(_redundantCeiling),
        reason: 'a word translated the same everywhere gets one key (#3486); '
            'reuse the existing one: ${worst.take(10).join(', ')}');
    expect(redundant, _redundantCeiling,
        reason: 'record the win: lower _redundantCeiling to $redundant');
  });
}
