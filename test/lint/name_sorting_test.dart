// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3488 -- a name list is sorted with `compareNames` (lib/core/text), not
// with Dart's UTF-16 `compareTo`, which puts every accented initial after Z.
// Counted, not listed: the ceiling is 0 and a hit names its file.
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

final _kinds = [
    LiteralKind(
      'lower-cased compareTo',
      RegExp(r'toLowerCase\(\)\s*\.compareTo\('),
    ),
    // #3654 -- the multi-line and the map-lookup shapes.
    LiteralKind(
      'person-name compareTo',
      RegExp(r'\.(memberName|fullName|displayName|firstName|lastName)\s*\.compareTo\('),
    ),
    LiteralKind(
      'name lookup compareTo',
      RegExp(r"names\[[^\]]+\]\s*\?\?\s*''\)\s*\.compareTo\("),
    ),
    LiteralKind(
      'name compareTo',
      RegExp(r'\.(name|title|label|displayName)\.compareTo\('),
    ),
  // #3654 -- a call's result compared (`localizedName(l10n, a)\n.compareTo(`).
  LiteralKind(
    'name call compareTo',
    RegExp(r'\b\w*[Nn]ame\w*\([^()]*\)\s*\.compareTo\('),
  ),
];

void main() {
  test('no client-side name sort uses compareTo on a name', () {
    final files = filesUnder(['lib'])
        .where((f) => !f.path.startsWith('lib/core/text/'));
    final kinds = _kinds;
    final counted = countLiterals(files, kinds);
    for (final k in kinds) {
      final perFile = counted[k.name]!;
      expect(
        total(perFile),
        0,
        reason: ratchetMessage(
          rule: 'name sorting (#3488): use compareNames from lib/core/text/collation.dart',
          kind: k.name,
          ceiling: 0,
          actual: total(perFile),
          perFile: perFile,
        ),
      );
    }
  });

  test('the patterns see a split receiver and a wrapped call (#3654)', () {
    const planted = [
      "a.memberName\n    .toLowerCase()\n    .compareTo(b.memberName)",
      "(names[a.id] ?? '')\n    .compareTo(names[b.id] ?? '')",
      "localizedCountryName(\n  l10n,\n  a,\n).compareTo(x)",
      "localizedCountryName(l10n, a)\n    .compareTo(x)",
    ];
    for (final text in planted) {
      expect(
        _kinds.any((k) => k.pattern.hasMatch(text)),
        isTrue,
        reason: text,
      );
    }
    expect(_kinds.any((k) => k.pattern.hasMatch('a.id.compareTo(b.id)')), isFalse);
  });
}
